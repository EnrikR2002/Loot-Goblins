-- One frame of boat physics. Shared, because it runs on whichever machine owns the hull:
-- the server for empty and AI boats, and the driver's own client for the boat they are
-- steering (so the wheel answers at once instead of a network round trip later). The server
-- still owns hull health, sinking, boost cooldowns and the rules; it watches a driven boat and
-- takes it back if it does something the physics here could not have done (Boats.lua).
--
-- Forces, all applied as impulses on the hull:
--   buoyancy   springs at six points under the hull, pushing up toward the wave surface
--              (Sea.waveAt), so boats rise, pitch and roll with the swell and can leave it
--   thrust     along the hull while it is wet, with a punchy launch and a real brake
--   keel       turns sideways motion into forward motion instead of braking it (arcade drift)
--   steering   a target yaw rate, sharp when slow and wider at top speed, plus a bank
--   drift      hold the drift key in a turn: the keel lets go, the boat swings round fast, and
--              a held slide charges a burst of speed that fires when you release it
--   air        a little steering in the air, and a burst for a clean, straight landing
--
-- `boat` is a plain table (BoatSim.new lists the fields). `input` is { throttle, steer, drift }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Twister = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Twister"))

local BoatSim = {}

-- V9 TRICKS. A trick is not a force: while one runs, the hull's orientation is written outright from its
-- heading when the trick began and how far through the trick it is, so it always ends exactly level and
-- pointing the way it started, however it was spun. Position and velocity stay physics. Each entry:
-- the rotation at progress 0..1 (in the hull's own frame, after its starting heading).
local TAU = math.pi * 2
local function ease(p)
	return p * p * (3 - 2 * p)
end
BoatSim.TRICKS = {
	spin = function(p, side)
		return CFrame.Angles(0, TAU * ease(p) * side, 0)
	end,
	spin2 = function(p, side)
		return CFrame.Angles(0, 2 * TAU * ease(p) * side, 0)
	end,
	roll = function(p, side)
		return CFrame.Angles(0, 0, -TAU * ease(p) * side)
	end,
	backflip = function(p)
		return CFrame.Angles(TAU * ease(p), 0, 0)
	end,
	frontflip = function(p)
		return CFrame.Angles(-TAU * ease(p), 0, 0)
	end,
	corkscrew = function(p, side)
		local e = ease(p)
		return CFrame.Angles(0, TAU * e * side, 0) * CFrame.Angles(0, 0, -TAU * e * side)
	end,
}
-- How long each takes (Config.TRICK.TIME by family).
local TRICK_FAMILY = {
	spin = "spin",
	spin2 = "corkscrew",
	roll = "roll",
	backflip = "flip",
	frontflip = "flip",
	corkscrew = "corkscrew",
}

-- Buoyancy points under a hull: three rows, two columns.
function BoatSim.points(spec)
	local size = spec.size
	local points = {}
	for _, z in ipairs({ -0.38, 0, 0.38 }) do
		for _, x in ipairs({ -0.3, 0.3 }) do
			table.insert(points, Vector3.new(x * size.X, -size.Y / 2, z * size.Z))
		end
	end
	return points
end

-- The simulation's own state for one hull. The server's boat tables carry these fields too.
function BoatSim.new(hull, spec)
	return {
		hull = hull,
		spec = spec,
		points = BoatSim.points(spec),
		buoyScale = 1, -- Fades to 0 while a wreck goes under.
		moored = false,
		sinking = false,
		payload = 0, -- Weight of the loot aboard.
		boostUntil = 0,
		miniUntil = 0, -- A drift or landing burst is running.
		driftCharge = 0,
		waterDrag = 0, -- Measured each step: how hard Terrain water is slowing this hull.
		predicted = nil, -- Where our own forces alone would have put its velocity by now.
		airTime = 0,
		flippedFor = 0,
		gateAt = {},
		jumpReadyAt = 0,
		wasBoosting = false,
		grounded = false, -- On land (or a beach): the ground, not the water, is holding the hull.
		out = {},
		-- V9
		trick = nil, -- The trick running now: { kind, side, startedAt, duration, base (CFrame: heading only) }.
		tricksDone = 0, -- Tricks finished since the hull left the water.
		gatePosition = nil, -- Where the hull was at the last gate check (hoops are swept from there).
		twistedAt = -math.huge, -- When a tornado last held it.
		twisterIgnoreUntil = 0, -- After bailing out of a funnel, it lets go for a moment.
	}
end

-- Starts a trick if the hull is in the air and free. kind: a key of BoatSim.TRICKS; side: 1 or -1.
-- Returns true if it started.
function BoatSim.startTrick(boat, kind, side, t)
	local hull = boat.hull
	if boat.trick or boat.sinking or boat.moored or not BoatSim.TRICKS[kind] then
		return false
	end
	local position = hull.Position
	if boat.out.wet ~= 0 or boat.grounded then
		return false
	end
	if position.Y - Sea.waveAt(position.X, position.Z, t) < Config.TRICK.MIN_HEIGHT then
		return false
	end
	local look = hull.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
	boat.trick = {
		kind = kind,
		side = side or 1,
		startedAt = t,
		duration = Config.TRICK.TIME[TRICK_FAMILY[kind]] or 0.6,
		base = CFrame.lookAt(Vector3.zero, flat),
	}
	return true
end

-- V7: on land the hull drives slowly instead of being shoved (Config.BOAT_LAND_*), and a jump needs
-- something under the hull.
local function groundParams(boat)
	local params = boat.rayParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		params.FilterDescendantsInstances = { boat.hull.Parent }
		boat.rayParams = params
	end
	return params
end

-- Steps the boat. Returns boat.out: { wet, speed, forwardSpeed, slip, boosting, drifting,
-- charge, level, event, jumped, grounded }. event is "mini1" / "mini2" (a drift burst), "landing"
-- (a clean one) or "splash" (any other landing), for effects only. input.jump is one frame of the
-- jump key; jumped says the hull left the water (or the ground) this step.
function BoatSim.step(boat, input, dt, t)
	local hull = boat.hull
	local spec = boat.spec
	local size = spec.size
	local cf = hull.CFrame
	local position = cf.Position
	local velocity = hull.AssemblyLinearVelocity
	local spin = hull.AssemblyAngularVelocity
	local mass = hull.AssemblyMass
	local up = cf.UpVector
	local out = boat.out
	out.event = nil

	-- Buoyancy: spring + damper at each point under the surface.
	local count = #boat.points
	local k = mass * workspace.Gravity / (count * spec.draft)
	local c = Config.BOAT_BUOY_DAMPING * math.sqrt(k * mass / count)
	local submerged = 0
	local scale = boat.buoyScale
	for _, point in ipairs(boat.points) do
		local world = cf:PointToWorldSpace(point)
		local depth = Sea.waveAt(world.X, world.Z, t) - world.Y
		if depth > 0 then
			submerged += 1
			depth = math.min(depth, spec.draft * 2.6)
			local pointVelocity = velocity + spin:Cross(world - position)
			local force = (k * depth - c * pointVelocity.Y) * scale
			if force > 0 then
				hull:ApplyImpulseAtPosition(Vector3.new(0, force * dt, 0), world)
			end
		end
	end
	local wet = submerged / count

	-- Is the ground holding the hull up (a beach, an island, a dock)? Only asked when the water is not.
	local grounded = false
	if wet < 0.5 and not boat.sinking then
		local hit = workspace:Raycast(position, Vector3.new(0, -(size.Y / 2 + 2.2), 0), groundParams(boat))
		grounded = hit ~= nil and hit.Normal.Y >= Config.BOAT_LAND_SLOPE
	end
	boat.grounded = grounded and wet < 0.2
	grounded = boat.grounded

	-- V9: a tornado. Its funnel lifts the hull in a spiral and throws it out at the top; the jump key bails out.
	local twist, twistState = nil, nil
	if t >= boat.twisterIgnoreUntil and not boat.sinking then
		twist, twistState = Twister.accel(position, velocity, t, workspace.Gravity)
	end
	out.twister = twistState
	if twist then
		boat.twistedAt = t
		hull:ApplyImpulse(twist * mass * dt)
		if input.jump == true and t >= boat.jumpReadyAt then
			local bail = Twister.bail(position, cf.LookVector, t)
			if bail then
				boat.jumpReadyAt = t + Config.BOAT_JUMP_COOLDOWN
				boat.twisterIgnoreUntil = t + Config.TWISTER.IGNORE
				hull.AssemblyLinearVelocity = bail + Vector3.new(velocity.X, 0, velocity.Z) * 0.25
				out.event = "bail"
				input.jump = false
			end
		end
	end

	local throttle, steer = input.throttle or 0, input.steer or 0
	local sinking = boat.sinking
	if boat.moored or sinking then
		throttle, steer = 0, 0
	end
	local boosting = t < boat.boostUntil
	local mini = t < boat.miniUntil
	-- The moment a boost starts it kicks (a hoop's own kick marks wasBoosting, so it is not doubled).
	if boosting and not boat.wasBoosting and wet > 0.3 and not sinking then
		hull:ApplyImpulse(Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit * Config.BOAT_BOOST_PUNCH * mass)
		out.punched = true
	end
	boat.wasBoosting = boosting

	-- Horizontal motion relative to the water's own flow.
	local flowX, flowZ = Sea.currentAt(position.X, position.Z)
	local flow = Vector3.new(flowX, 0, flowZ) * wet
	local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	forward = forward.Magnitude > 0.05 and forward.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local relative = horizontal - flow
	local forwardSpeed = relative:Dot(forward)
	local lateralSpeed = relative:Dot(right)
	local speedMag = relative.Magnitude
	local speedAbs = math.abs(forwardSpeed)
	local slip = speedMag > 1 and math.abs(lateralSpeed) / speedMag or 0

	-- Drift. While the key is held the keel lets go; an actual slide (steering, at speed, in
	-- the water) charges a burst that fires when the key is released.
	-- A hop from a charged drift lets the burst go (the key is treated as released).
	local jumpNow = input.jump == true
		and t >= boat.jumpReadyAt
		and not boat.moored
		and not sinking
		and (wet > 0.3 or grounded)
	local wantDrift = input.drift == true
		and not boat.moored
		and not sinking
		and not (jumpNow and boat.driftCharge >= Config.BOAT_DRIFT_CHARGE[1])
	local loose = wantDrift and wet > 0.2 and speedMag > spec.maxSpeed * Config.BOAT_DRIFT_MIN_SPEED
	local level = 0
	if wantDrift then
		if loose and math.abs(steer) > 0.2 then
			boat.driftCharge = math.min(boat.driftCharge + dt * (0.35 + slip * 1.2), Config.BOAT_DRIFT_CHARGE[2] + 0.4)
		elseif not loose then
			boat.driftCharge = math.max(0, boat.driftCharge - dt * 1.5)
		end
	end
	if boat.driftCharge >= Config.BOAT_DRIFT_CHARGE[2] then
		level = 2
	elseif boat.driftCharge >= Config.BOAT_DRIFT_CHARGE[1] then
		level = 1
	end
	if not wantDrift and boat.driftCharge > 0 then
		boat.driftCharge = 0
		if level > 0 and wet > 0.2 then
			boat.miniUntil = t + Config.BOAT_MINI_TIME[level]
			hull:ApplyImpulse(forward * Config.BOAT_MINI_KICK[level] * mass)
			mini = true
			out.event = level == 2 and "mini2" or "mini1"
		end
		level = 0
	end

	local payloadFactor = math.max(0.55, 1 - Config.BOAT_PAYLOAD_DRAG * boat.payload)
	local accel = spec.accel * payloadFactor * (boosting and Config.BOAT_BOOST_THRUST or 1)
	local topSpeed = spec.maxSpeed
		* payloadFactor
		* (boosting and Config.BOAT_BOOST_MULT or 1)
		* (mini and Config.BOAT_MINI_MULT or 1)
	if grounded then
		-- On land: a slow, heavy drive. A boost or a burst does not raise it.
		accel = spec.accel * payloadFactor * Config.BOAT_LAND_THRUST
		topSpeed = spec.maxSpeed * payloadFactor * Config.BOAT_LAND_SPEED
	end
	local drive
	if throttle >= 0 then
		if forwardSpeed < -4 then
			drive = throttle * accel * Config.BOAT_BRAKE
		else
			-- A punchy launch: extra shove from a standstill that fades out by half speed.
			drive = throttle
				* accel
				* (1 + Config.BOAT_LAUNCH_PUNCH * math.clamp(1 - speedAbs / (topSpeed * 0.5), 0, 1))
		end
	else
		drive = throttle * accel * (forwardSpeed > 4 and Config.BOAT_BRAKE or Config.BOAT_REVERSE)
	end
	-- The prop only bites while the stern is wet: a hull cannot drive across an island. Out of
	-- the water the crew can only shove it along slowly, either way, so a boat run up a beach
	-- can always be worked back to the sea and nobody is stranded.
	if wet < 0.15 then
		if grounded then
			drive = throttle >= 0 and throttle * accel or throttle * accel * Config.BOAT_REVERSE * 2
		else
			drive = speedAbs < Config.BOAT_BEACH_SPEED and throttle * spec.accel * Config.BOAT_BEACH_SHOVE or 0
		end
	else
		drive *= math.min(1, wet * 2.2)
	end
	-- Drag sets the top speed under power. Off the throttle a hull coasts a long way (S is
	-- the brake), so momentum is something you carry through a manoeuvre.
	local dragForward = accel / topSpeed * (0.25 + 0.75 * wet) * (throttle == 0 and Config.BOAT_COAST_DRAG or 1)
	if grounded then
		-- Wheels-in-mud drag: the full rate (no easing for being out of the water), and heavy off the throttle.
		dragForward = accel / topSpeed * (throttle == 0 and Config.BOAT_LAND_COAST or 1)
	end
	-- Roblox's own Terrain water also drags on the hull, by an amount that depends on the hull
	-- and that this code does not control. So measure it: whatever slowed the hull along its
	-- length since the last step, beyond what these forces did, is the water (or a collision,
	-- which the cap and the smoothing keep out). Under power the engine cancels it, so maxSpeed
	-- in Config is the speed the boat really reaches, on any hull and at any frame rate.
	if boat.predicted and throttle > 0 and wet > 0.5 and forwardSpeed > 5 then
		local slowed = (boat.predicted - horizontal):Dot(forward) / dt
		boat.waterDrag += (math.clamp(slowed, 0, spec.accel * 0.35) - boat.waterDrag) * math.min(1, dt * 4)
		drive += boat.waterDrag
	else
		boat.waterDrag *= 1 - math.min(1, dt * 2)
	end

	-- The keel turns the boat's motion toward where it points instead of braking it
	-- (arcade drift): the faster you slide sideways, the more speed you shed. A drift, and the
	-- burst that follows one, shed far less: sliding on purpose is not a mistake.
	local grip = spec.grip * (loose and spec.driftGrip or 1)
	local redirected = relative
	local traction = math.max(wet, grounded and 0.55 or 0)
	if speedMag > 1 and traction > 0 then
		local keel = math.min(1, grip * math.max(traction, 0.15) * dt)
		local aligned = forward * (forwardSpeed >= 0 and 1 or -1) * speedMag
		redirected = relative:Lerp(aligned, keel)
		local loss = (loose or mini) and Config.BOAT_DRIFT_SLIP_LOSS or Config.BOAT_SLIP_LOSS
		local kept = redirected.Magnitude > 0.01 and (speedMag * (1 - loss * slip * keel)) / redirected.Magnitude or 1
		redirected *= kept
	end
	local forwardNow = redirected:Dot(forward)
	local acceleration = (redirected - relative) / dt + forward * (drive - forwardNow * dragForward)
	if boat.moored then
		acceleration = (-relative * 2.6 + flow * 0.1) * math.max(wet, 0.2)
	end
	if sinking then
		acceleration *= 0.4
	end
	hull:ApplyImpulse(acceleration * mass * dt)
	boat.predicted = horizontal + Vector3.new(acceleration.X, 0, acceleration.Z) * dt

	-- Steering: aim for a yaw rate. Sharp when slow, wider at top speed, sharper again in a
	-- drift, and a little control in the air to line up a landing.
	local authority = math.clamp(speedAbs / 12, 0.25, 1) / (1 + speedAbs / spec.turnFade)
	if loose then
		authority *= spec.driftTurn
	end
	local control = wet > 0 and math.max(wet, 0.3) or (grounded and Config.BOAT_LAND_TURN or Config.BOAT_AIR_CONTROL)
	local yawRate = spec.turn * authority * control
	if loose and speedMag > 1 and lateralSpeed * steer < 0 then
		-- In a drift the hull swings quickly out to a slide angle and then holds it (turning
		-- only as fast as its path curves), instead of spinning like a top. Steer the other way
		-- and it swings straight back.
		local angle = math.atan2(math.abs(lateralSpeed), math.max(forwardSpeed, 0.01))
		local hold = math.clamp(
			(angle - Config.BOAT_DRIFT_ANGLE[1]) / (Config.BOAT_DRIFT_ANGLE[2] - Config.BOAT_DRIFT_ANGLE[1]),
			0,
			1
		)
		yawRate = yawRate * (1 - hold) + grip * math.sin(math.min(angle, math.pi / 2)) * hold
	end
	local yawTarget = -steer * yawRate * (forwardSpeed >= -1 and 1 or -1)
	if loose and math.abs(steer) > 0.2 then
		-- Full lock while the drift key is held, even on an analogue stick.
		yawTarget = -math.sign(steer) * yawRate
	end
	if twistState == "inside" then
		yawTarget += 2.4 -- Round and round with the funnel.
	end
	local trick = boat.trick
	if trick then
		-- V9: a trick owns the hull's orientation (see BoatSim.TRICKS). A hull that touches the water mid-trick
		-- comes down level anyway: a sketchy landing, never a capsized boat.
		local progress = (t - trick.startedAt) / trick.duration
		local landed = wet > 0.25 or grounded or sinking
		local rotation
		if landed or progress >= 1 then
			rotation = trick.base
			boat.trick = nil
			if landed then
				boat.tricksDone = 0
				boat.sketchy = true
				out.event = "sketchy"
			else
				boat.tricksDone += 1
				out.event = "trick"
				out.trick = trick.kind
				out.tricks = boat.tricksDone
			end
		else
			rotation = trick.base * BoatSim.TRICKS[trick.kind](progress, trick.side)
		end
		hull.CFrame = CFrame.new(position) * rotation
		hull.AssemblyAngularVelocity = Vector3.zero
	else
		local yawNow = spin:Dot(up)
		local yawInertia = mass * (size.X * size.X + size.Z * size.Z) / 12
		hull:ApplyAngularImpulse(up * (yawTarget - yawNow) * math.min(1, dt * Config.BOAT_YAW_SNAP) * yawInertia)

		-- Bank into the turn (harder in a drift) and stay upright.
		local rollInertia = mass * (size.X * size.X + size.Y * size.Y) / 12
		local lean = steer * spec.lean * math.clamp(speedAbs / (spec.maxSpeed * 0.6), 0, 1) * wet * (loose and 1.5 or 1)
		local tilt = up:Cross(Vector3.yAxis)
		local flatSpin = spin - up * yawNow
		local righting = 14 * (0.55 + 0.45 * wet)
		hull:ApplyAngularImpulse(
			(cf.LookVector * lean + tilt * righting - flatSpin * 2.2 * (0.4 + wet)) * rollInertia * dt
		)
	end

	-- The hop. (After the forces, so the spring does not eat it.)
	out.jumped = false
	out.super = nil
	if jumpNow then
		boat.jumpReadyAt = t + Config.BOAT_JUMP_COOLDOWN
		-- The faster the hull, the bigger the jump: a hop below BOAT_SUPER_MIN, a super jump above it.
		local super = 0
		if not grounded and speedMag > Config.BOAT_SUPER_MIN then
			super = math.clamp(
				(speedMag - Config.BOAT_SUPER_MIN) / (Config.BOAT_SUPER_FULL - Config.BOAT_SUPER_MIN),
				0.15,
				1
			)
		end
		local jumpSpeed = Config.BOAT_JUMP_SPEED + super * (Config.BOAT_SUPER_SPEED - Config.BOAT_JUMP_SPEED)
		hull:ApplyImpulse(Vector3.new(0, jumpSpeed * mass, 0))
		if super > 0 then
			-- Bow up, for the look of it (and so the stern meets the water first).
			local pitchInertia = mass * (size.Y * size.Y + size.Z * size.Z) / 12
			hull:ApplyAngularImpulse(cf.RightVector * super * Config.BOAT_SUPER_PITCH * pitchInertia)
			out.super = super
		end
		boat.hopOnly = super == 0 -- a plain hop earns no landing burst
		out.jumped = true
	end

	-- Air time, and a burst for landing clean (upright, pointing the way you travel).
	if wet <= 0 and not grounded then
		boat.airTime += dt
	elseif grounded then
		-- Down on land: a thump, never a burst.
		if boat.airTime >= Config.BOAT_AIR_MIN then
			out.event = out.event or "splash"
		end
		boat.airTime = 0
		boat.hopOnly = false
		boat.tricksDone = 0
		boat.sketchy = false
	elseif wet >= 0.3 then
		if boat.airTime >= Config.BOAT_AIR_MIN then
			-- A burst needs a real flight (a ramp, a boosted hop), not a plain hop from rest. A hop with a
			-- trick in it is a real flight (V9).
			local tricks = boat.tricksDone
			local clean = up.Y > 0.8 and slip < 0.3 and forwardSpeed > spec.maxSpeed * 0.4 and not sinking
			if clean and tricks > 0 and not boat.sketchy then
				local paid = math.min(tricks, Config.TRICK.MAX_PAID)
				boat.miniUntil = math.max(boat.miniUntil, t + Config.BOAT_MINI_TIME[2])
				hull:ApplyImpulse(forward * (Config.BOAT_LANDING_KICK + Config.TRICK.KICK * paid) * mass)
				out.event = "trickland"
				out.tricks = tricks
			elseif clean and boat.airTime >= Config.BOAT_LANDING_AIR and not boat.hopOnly and not boat.sketchy then
				boat.miniUntil = math.max(boat.miniUntil, t + Config.BOAT_MINI_TIME[1])
				hull:ApplyImpulse(forward * Config.BOAT_LANDING_KICK * mass)
				out.event = "landing"
			else
				out.event = out.event or "splash"
			end
			boat.hopOnly = false
		end
		boat.airTime = 0
		boat.tricksDone = 0
		boat.sketchy = false
	end

	-- Capsized (or nearly) for a moment: the hull pops back upright where it lies, with a hop,
	-- so no one is ever stuck under a boat. (A push is not enough: an upside-down hull has no
	-- buoyancy points in the water and simply sits there.)
	if up.Y < 0.3 and not boat.trick then
		boat.flippedFor += dt
		if boat.flippedFor > Config.BOAT_FLIP_TIME then
			boat.flippedFor = 0
			local at = position + Vector3.new(0, 2.5, 0)
			hull.CFrame = CFrame.lookAt(at, at + forward)
			hull.AssemblyAngularVelocity = Vector3.zero
			hull.AssemblyLinearVelocity = Vector3.new(velocity.X * 0.6, 14, velocity.Z * 0.6)
			out.event = "splash"
		end
	else
		boat.flippedFor = 0
	end

	out.wet = wet
	out.grounded = grounded
	out.speed = horizontal.Magnitude
	out.forwardSpeed = forwardSpeed
	out.slip = slip
	out.boosting = boosting
	out.drifting = loose
	out.charge = boat.driftCharge
	out.level = level
	return out
end

-- Boost hoops give a burst of speed; kicker ramps launch a fast boat into the air.
-- gates: { { x, y, z, r, kind = "boost" | "kick", dx, dz, cy } }. Returns the kind of the gate the
-- boat just went through, or nil. With apply = false it only detects (the server does that for
-- a boat someone else is simulating, to show the effect and allow the speed).
--
-- V9: FORGIVING, SWEPT DETECTION. V8 asked whether the hull's middle was inside a circle round the hoop on
-- the frame it was checked. At 240 studs/s a hull moves 4 to 24 studs a frame (60 to 10 frames a second), so
-- a boat could step clean over a hoop it went through, and one that clipped a hoop's edge with half its hull
-- got nothing. Now the hull is swept from where it was at the last check to where it is now: a hoop counts if
-- that path crosses the hoop's plane within the hoop's radius plus half the hull's width (plus
-- BOAT_HOOP_REACH), or if the hull ends a frame with its own length across the plane (a glancing touch). Height
-- counts too, so a boat that jumps through a hoop gets it and one that jumps clean over it does not.
local function hoopPass(gate, from, to, halfLength, halfWidth, halfHeight)
	local nx, nz = gate.dx, gate.dz
	local cy = gate.cy or 5
	local a0 = (from.X - gate.x) * nx + (from.Z - gate.z) * nz
	local a1 = (to.X - gate.x) * nx + (to.Z - gate.z) * nz
	local hit
	if (a0 <= 0 and a1 >= 0) or (a0 >= 0 and a1 <= 0) then
		local span = a0 - a1
		hit = math.abs(span) > 1e-6 and from:Lerp(to, a0 / span) or to
	elseif math.min(math.abs(a0), math.abs(a1)) < halfLength * Config.BOAT_HOOP_DEPTH then
		hit = math.abs(a0) < math.abs(a1) and from or to
	else
		return false
	end
	local along = (hit.X - gate.x) * nx + (hit.Z - gate.z) * nz
	local lx, lz = hit.X - gate.x - nx * along, hit.Z - gate.z - nz * along
	local ly = hit.Y - cy
	-- Across, the hull's half-width counts; up and down, only its half-height (a boat flying over a hoop
	-- does not get it).
	local across = (lx * lx + lz * lz) / (gate.r + halfWidth + Config.BOAT_HOOP_REACH) ^ 2
	local vertical = (ly * ly) / (gate.r + halfHeight + Config.BOAT_HOOP_REACH) ^ 2
	return across + vertical < 1
end

-- A kicker ramp: the hull's path passes over its middle.
local function rampPass(gate, from, to)
	local seg = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local rel = Vector3.new(gate.x - from.X, 0, gate.z - from.Z)
	local lengthSq = seg:Dot(seg)
	local k = lengthSq > 1e-6 and math.clamp(rel:Dot(seg) / lengthSq, 0, 1) or 1
	local closest = Vector3.new(from.X + seg.X * k, 0, from.Z + seg.Z * k)
	local y = from.Y + (to.Y - from.Y) * k
	return (closest - Vector3.new(gate.x, 0, gate.z)).Magnitude < gate.r and math.abs(y - gate.y) < 14
end

function BoatSim.gate(boat, gates, t, apply)
	local hull = boat.hull
	local position = hull.Position
	local from = boat.gatePosition
	boat.gatePosition = position
	if not from or (from - position).Magnitude > 90 then
		from = position -- (a teleport, a respawn: nothing to sweep)
	end
	local size = boat.spec.size
	local halfLength, halfWidth = size.Z * 0.5, size.X * 0.5
	for index, gate in ipairs(gates) do
		-- A cheap first test: is the gate anywhere near this frame's path?
		local mx, mz = (from.X + position.X) * 0.5 - gate.x, (from.Z + position.Z) * 0.5 - gate.z
		local near = gate.r + halfLength + (from - position).Magnitude * 0.5 + 6
		if mx * mx + mz * mz < near * near and t - (boat.gateAt[index] or -10) > 1.5 then
			local velocity = hull.AssemblyLinearVelocity
			if gate.kind == "boost" and hoopPass(gate, from, position, halfLength, halfWidth, size.Y * 0.5) then
				boat.gateAt[index] = t
				boat.boostUntil = math.max(boat.boostUntil, t + Config.BOAT_HOOP_TIME)
				boat.wasBoosting = true -- the hoop's own kick is enough: no second punch from the boost it starts
				-- A CHAIN: each hoop taken within BOAT_CHAIN_WINDOW of the last kicks a little harder,
				-- up to a cap, so holding a line through a run is worth more than clipping one hoop.
				boat.chain = (t - (boat.chainAt or -math.huge) <= Config.BOAT_CHAIN_WINDOW) and (boat.chain or 0) + 1
					or 1
				boat.chainAt = t
				if apply then
					-- A hoop on a sea lane (gate.both) pushes whichever way the boat is already going.
					local way = 1
					if gate.both and velocity.X * gate.dx + velocity.Z * gate.dz < 0 then
						way = -1
					end
					local links = math.min(boat.chain - 1, Config.BOAT_CHAIN_MAX)
					local kick = Config.BOAT_HOOP_KICK + links * Config.BOAT_CHAIN_KICK
					-- A kick never takes the hull past a ceiling: its boosted top speed, plus a little
					-- for each link of the chain. Without it five hoops and a current reached 257
					-- studs/s: unreadable, and faster than the server's speed check allows.
					local ceiling = boat.spec.maxSpeed * Config.BOAT_BOOST_MULT + links * Config.BOAT_CHAIN_TOP
					local already = (velocity.X * gate.dx + velocity.Z * gate.dz) * way
					kick = math.clamp(ceiling - already, 0, kick)
					hull:ApplyImpulse(Vector3.new(gate.dx, 0, gate.dz) * way * hull.AssemblyMass * kick)
				end
				return "boost"
			elseif
				gate.kind == "kick"
				and rampPass(gate, from, position)
				and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.BOAT_KICK_MIN_SPEED
			then
				boat.gateAt[index] = t
				if apply then
					-- V9: the faster you hit a ramp, the higher it throws you.
					local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
					local up = math.min(
						Config.BOAT_KICK_MAX,
						Config.BOAT_KICK_SPEED + (speed - Config.BOAT_KICK_MIN_SPEED) * Config.BOAT_KICK_PER_SPEED
					)
					hull.AssemblyLinearVelocity = Vector3.new(velocity.X * 1.08, up, velocity.Z * 1.08)
					-- The plank's own push tips the bow up; at V9's kick that turned a jump into a backflip and a
					-- capsized landing (measured: upright 1.0 to -0.68 in the air). The ramp throws the boat
					-- level: no pitch or roll spin, only the turn it already had.
					local upAxis = hull.CFrame.UpVector
					local spin = hull.AssemblyAngularVelocity
					hull.AssemblyAngularVelocity = upAxis * spin:Dot(upAxis)
				end
				return "kick"
			end
		end
	end
	return nil
end

return BoatSim

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

local BoatSim = {}

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
		out = {},
	}
end

-- Steps the boat. Returns boat.out: { wet, speed, forwardSpeed, slip, boosting, drifting,
-- charge, level, event }. event is "mini1" / "mini2" (a drift burst), "landing" (a clean one)
-- or "splash" (any other landing), for effects only.
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

	local throttle, steer = input.throttle or 0, input.steer or 0
	local sinking = boat.sinking
	if boat.moored or sinking then
		throttle, steer = 0, 0
	end
	local boosting = t < boat.boostUntil
	local mini = t < boat.miniUntil

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
	local wantDrift = input.drift == true and not boat.moored and not sinking
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
		drive = speedAbs < Config.BOAT_BEACH_SPEED and throttle * spec.accel * Config.BOAT_BEACH_SHOVE or 0
	else
		drive *= math.min(1, wet * 2.2)
	end
	-- Drag sets the top speed under power. Off the throttle a hull coasts a long way (S is
	-- the brake), so momentum is something you carry through a manoeuvre.
	local dragForward = accel / topSpeed * (0.25 + 0.75 * wet) * (throttle == 0 and Config.BOAT_COAST_DRAG or 1)
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
	if speedMag > 1 and wet > 0 then
		local keel = math.min(1, grip * math.max(wet, 0.15) * dt)
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
	local control = wet > 0 and math.max(wet, 0.3) or Config.BOAT_AIR_CONTROL
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
	local yawNow = spin:Dot(up)
	local yawInertia = mass * (size.X * size.X + size.Z * size.Z) / 12
	hull:ApplyAngularImpulse(up * (yawTarget - yawNow) * math.min(1, dt * Config.BOAT_YAW_SNAP) * yawInertia)

	-- Bank into the turn (harder in a drift) and stay upright.
	local rollInertia = mass * (size.X * size.X + size.Y * size.Y) / 12
	local lean = steer * spec.lean * math.clamp(speedAbs / (spec.maxSpeed * 0.6), 0, 1) * wet * (loose and 1.5 or 1)
	local tilt = up:Cross(Vector3.yAxis)
	local flatSpin = spin - up * yawNow
	local righting = 14 * (0.55 + 0.45 * wet)
	hull:ApplyAngularImpulse((cf.LookVector * lean + tilt * righting - flatSpin * 2.2 * (0.4 + wet)) * rollInertia * dt)

	-- Air time, and a burst for landing clean (upright, pointing the way you travel).
	if wet <= 0 then
		boat.airTime += dt
	elseif wet >= 0.3 then
		if boat.airTime >= Config.BOAT_AIR_MIN then
			if up.Y > 0.8 and slip < 0.3 and forwardSpeed > spec.maxSpeed * 0.4 and not sinking then
				boat.miniUntil = math.max(boat.miniUntil, t + Config.BOAT_MINI_TIME[1])
				hull:ApplyImpulse(forward * Config.BOAT_LANDING_KICK * mass)
				out.event = "landing"
			else
				out.event = "splash"
			end
		end
		boat.airTime = 0
	end

	-- Capsized (or nearly) for a moment: the hull pops back upright where it lies, with a hop,
	-- so no one is ever stuck under a boat. (A push is not enough: an upside-down hull has no
	-- buoyancy points in the water and simply sits there.)
	if up.Y < 0.3 then
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
-- gates: { { x, y, z, r, kind = "boost" | "kick", dx, dz } }. Returns the kind of the gate the
-- boat just went through, or nil. With apply = false it only detects (the server does that for
-- a boat someone else is simulating, to show the effect and allow the speed).
function BoatSim.gate(boat, gates, t, apply)
	local hull = boat.hull
	local position = hull.Position
	for index, gate in ipairs(gates) do
		local dx, dz = position.X - gate.x, position.Z - gate.z
		if
			dx * dx + dz * dz < gate.r * gate.r
			and math.abs(position.Y - gate.y) < 14
			and t - (boat.gateAt[index] or -10) > 1.5
		then
			local velocity = hull.AssemblyLinearVelocity
			if gate.kind == "boost" then
				boat.gateAt[index] = t
				boat.boostUntil = math.max(boat.boostUntil, t + Config.BOAT_HOOP_TIME)
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
			elseif Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.BOAT_KICK_MIN_SPEED then
				boat.gateAt[index] = t
				if apply then
					hull.AssemblyLinearVelocity =
						Vector3.new(velocity.X * 1.08, Config.BOAT_KICK_SPEED, velocity.Z * 1.08)
				end
				return "kick"
			end
		end
	end
	return nil
end

return BoatSim

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
	-- V13.1: not a trick the driver does: the Guardian's launch throws the boat end over end the whole way up and
	-- down (BoatSim.tumble). Whole turns on every axis, so it finishes level; a hull that lands early is levelled.
	tumble = function(p, side)
		return CFrame.Angles(2 * TAU * p, TAU * p * side, TAU * p * side)
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
		-- V13: a Reefhopper's tricks are quicker (trickSpeed), so more of them fit in one jump.
		duration = (Config.TRICK.TIME[TRICK_FAMILY[kind]] or 0.6) / (boat.spec.trickSpeed or 1),
		base = CFrame.lookAt(Vector3.zero, flat),
	}
	return true
end

-- V13.1: thrown end over end for `seconds` (the Guardian's launch: server/Pursuit.lua forms.Temple). Unlike a trick
-- it starts from the water, ignores what is running, and pays nothing when it ends (it was not the driver's doing).
function BoatSim.tumble(boat, seconds, side, t)
	if boat.sinking or boat.moored then
		return false
	end
	local look = boat.hull.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
	boat.trick = {
		kind = "tumble",
		side = side or 1,
		startedAt = t,
		duration = math.max(0.5, seconds),
		base = CFrame.lookAt(Vector3.zero, flat),
		tumble = true,
	}
	boat.tricksDone = 0
	return true
end

-- V13.2: CHAINS. One rope on a hull at a time, applied by whichever machine simulates it (so a chained rival's own
-- client drags it, the way a shove is applied there). boat.tether = {
--   kind      "swing"  the Anchorjack round its anchor on a rock or the sea bed (R again, or `untilAt`, lets go: a sling)
--             "snag"   the Anchorjack chained to a rival's hull it caught
--             "towed"  a rival chained to the Anchorjack that caught it (sent to the rival's client by the server)
--             "reel"   the Corsair reeled in toward a rival's hull its hook bit
--             "zip"    the Corsair reeled toward a rock its hook bit (no boat in reach)
--   point     Vector3, a fixed end;  or part, a BasePart that moves (a hull)
--   length    the rope's length (swing, snag, towed): it only ever pulls when taut
--   untilAt   server time it lets go
-- }
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function BoatSim.attach(boat, kind, target, t)
	if type(target) ~= "table" then
		return false
	end
	local A = Config.BOAT_ABILITIES[kind]
	local here = flat(boat.hull.Position)
	local part = typeof(target.part) == "Instance" and target.part:IsA("BasePart") and target.part or nil
	local point = typeof(target.point) == "Vector3" and flat(target.point) or nil
	if not part and not point then
		return false
	end
	local other = part and flat(part.Position) or point
	local gap = (other - here).Magnitude
	if kind == "anchor" then
		if part then
			boat.tether = {
				kind = "snag",
				part = part,
				length = math.max(A.snagMin, gap * A.snagSlack),
				untilAt = t + A.snag,
			}
		else
			boat.tether = {
				kind = "swing",
				point = point,
				length = math.max(A.swingMin, gap),
				untilAt = t + A.swing,
			}
		end
	elseif kind == "hook" then
		boat.tether = {
			kind = part and "reel" or "zip",
			part = part,
			point = point,
			untilAt = t + A.reelTime,
			startGap = gap,
		}
	end
	return true
end

-- Lets a hull's chain go. A swing let go is a SLINGSHOT: a kick along the way it was swinging.
function BoatSim.release(boat, t, sling)
	local tether = boat.tether
	if not tether then
		return nil
	end
	boat.tether = nil
	if sling and tether.kind == "swing" then
		local hull = boat.hull
		local v = flat(hull.AssemblyLinearVelocity)
		if v.Magnitude > 4 then
			hull:ApplyImpulse(v.Unit * Config.BOAT_ABILITIES.anchor.sling * hull.AssemblyMass)
		end
		boat.boostUntil = math.max(boat.boostUntil, t + 1)
		boat.wasBoosting = true
		return "sling"
	end
	return tether.kind
end

-- One step of the chain: returns a yaw rate to add (a swinging hull turns its bow round with the swing), or 0.
local function applyTether(boat, dt, t)
	local tether = boat.tether
	if not tether then
		return 0
	end
	local hull = boat.hull
	if t >= tether.untilAt or (tether.part and not tether.part.Parent) or boat.sinking then
		boat.justReleased = BoatSim.release(boat, t, true)
		return 0
	end
	local mass = hull.AssemblyMass
	local here = flat(hull.Position)
	local endAt = tether.part and flat(tether.part.Position) or tether.point
	local endVelocity = tether.part and flat(tether.part.AssemblyLinearVelocity) or Vector3.zero
	local offset = here - endAt
	local distance = offset.Magnitude
	if distance < 0.5 then
		return 0
	end
	local n = offset / distance
	local velocity = flat(hull.AssemblyLinearVelocity)
	local relative = velocity - endVelocity
	if tether.kind == "reel" or tether.kind == "zip" then
		-- Reeled in: close on the target at its own speed plus the reel's, whatever the hull was doing.
		local A = Config.BOAT_ABILITIES.hook
		local want = endVelocity - n * A.reel
		if tether.kind == "zip" then
			want = -n * (A.reel + 50)
		end
		local blend = math.min(1, dt * 5)
		hull:ApplyImpulse((want - velocity) * blend * mass)
		if distance < (tether.kind == "zip" and 30 or A.board * 0.8) then
			boat.tether = nil -- arrived (the server decides whether it was a boarding)
			boat.justReleased = "arrived"
		end
		-- Point the bow at it.
		local look = flat(hull.CFrame.LookVector)
		look = look.Magnitude > 0.05 and look.Unit or n
		local cross = look:Cross(-n).Y
		return math.clamp(cross * 4, -2.5, 2.5) -- (a positive yaw rate turns the bow anticlockwise, seen from above)
	end
	-- A rope: nothing until it is taut, then the part of the motion that would stretch it is taken away (and a
	-- little more, to pull the hull back in), so the hull swings round the end instead of leaving it.
	local over = distance - tether.length
	if over > 0 then
		local A = Config.BOAT_ABILITIES.anchor
		local outward = relative:Dot(n)
		local correction = Vector3.zero
		if outward > 0 then
			correction -= n * outward * math.min(1, dt * A.strength * 2)
		end
		correction -= n * math.min(over, 30) * math.min(1, dt * A.strength) * 3
		hull:ApplyImpulse(correction * mass)
	end
	if tether.kind == "swing" then
		-- The bow follows the swing: turn at the rate the hull goes round the anchor.
		local tangential = relative - n * relative:Dot(n)
		local around = n:Cross(tangential).Y -- the sign of the way round
		return math.clamp(tangential.Magnitude / math.max(distance, 10), 0, 3.2) * (around >= 0 and 1 or -1)
	end
	return 0
end

-- V13: can the class ability be used right now (the stunt key on the water)? The same test runs inside step().
function BoatSim.abilityReady(boat, t)
	local spec = boat.spec
	local A = spec.ability and Config.BOAT_ABILITIES[spec.ability]
	return A ~= nil
		and t >= (boat.abilityReadyAt or 0)
		and not boat.moored
		and not boat.sinking
		and ((boat.out.wet or 0) > 0.3 or boat.grounded == true)
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
	out.ability = nil
	out.released = nil
	out.airhop = nil

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
				bail *= spec.twisterBail or 1 -- V13: the Stormrunner is thrown much farther
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

	-- V13: THE CLASS ABILITY (the stunt key on the water, Config.BOAT_ABILITIES). This is only the physical part, played
	-- on whichever machine simulates the hull; server/BoatAbilities.lua owns the cooldown, fires anything the server
	-- owns (a cannon volley, a tornado, a ghost decoy) and tells the anti-cheat what to allow.
	local A = spec.ability and Config.BOAT_ABILITIES[spec.ability]
	-- V13.2: the stunt key while your own anchor holds lets it go (a swing lets go as a slingshot).
	if input.ability == true and boat.tether and (boat.tether.kind == "swing" or boat.tether.kind == "snag") then
		out.released = BoatSim.release(boat, t, true)
		input.ability = false
	end
	if
		input.ability == true
		and A
		and t >= (boat.abilityReadyAt or 0)
		and not boat.moored
		and not sinking
		and (wet > 0.3 or grounded)
	then
		local kind = spec.ability
		local ahead = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		ahead = ahead.Magnitude > 0.05 and ahead.Unit or Vector3.new(0, 0, -1)
		if kind == "nitro" then
			boat.nitroUntil = t + A.time
			hull:ApplyImpulse(ahead * A.kick * mass)
			-- V13.2: the escape artist breaks free: any chain, hook or tow on this hull lets go.
			boat.tether = nil
		elseif kind == "rally" then
			-- V13.2, the Cutter's horn: it surges itself (the server surges the boats round it).
			boat.boostUntil = math.max(boat.boostUntil, t + A.boost)
			boat.wasBoosting = true
			hull:ApplyImpulse(ahead * 12 * mass)
		elseif kind == "breaker" then
			-- V13.2, the Wavebreaker: the slam lifts it onto its own crest and surges it the way it steers.
			local right = Vector3.new(-ahead.Z, 0, ahead.X)
			local way = (ahead + right * math.clamp(steer, -1, 1) * 0.8).Unit
			local v = hull.AssemblyLinearVelocity
			hull.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, A.ride), v.Z) + way * A.surge
			boat.boostUntil = math.max(boat.boostUntil, t + A.boost)
			boat.wasBoosting = true
			boat.hopOnly = true
		elseif kind == "anchor" or kind == "hook" then
			-- V13.2: the Anchorjack's anchor and the Corsair's boarding hook. Where they went was decided before the key
			-- reached the physics (client/BoatDrive.aimAbility, or server/BoatAbilities for a server-run hull):
			-- input.target = { point = Vector3 } (a rock, the sea bed) or { part = a rival's hull }.
			BoatSim.attach(boat, kind, input.target, t)
		elseif kind == "spring" then
			local v = hull.AssemblyLinearVelocity
			if grounded then
				hull:ApplyImpulse(Vector3.new(0, A.up * 0.45 * mass, 0)) -- on a beach it is only a bounce
			else
				hull.AssemblyLinearVelocity = Vector3.new(v.X * A.keep, A.up, v.Z * A.keep)
			end
			boat.hopOnly = false -- a real flight: a clean landing from it pays the burst
			boat.airHopped = false
			boat.jumpReadyAt = t + 0.35
		elseif kind == "slip" then
			local right = Vector3.new(-ahead.Z, 0, ahead.X)
			local side = steer < -0.2 and -1 or (steer > 0.2 and 1 or (boat.slipSide or 1))
			boat.slipSide = -side -- going straight, the slips alternate sides
			hull:ApplyImpulse(right * side * A.side * mass)
			boat.slipUntil = t + 0.45
		elseif kind == "plow" then
			boat.plowUntil = t + A.time
			hull:ApplyImpulse(ahead * 16 * mass)
		elseif kind == "twister" then
			-- Its own new tornado lets the Stormrunner go for a moment: it was summoned to catch what follows, and
			-- a Stormrunner that had slowed down was swallowed by it in the first playtest.
			boat.twisterIgnoreUntil = math.max(boat.twisterIgnoreUntil, t + (A.grace or 5))
		end
		boat.abilityReadyAt = t + A.cooldown
		out.ability = kind
	end
	local nitro = t < (boat.nitroUntil or 0)
	local plowing = t < (boat.plowUntil or 0)
	-- V13, the Stormrunner's sails: faster in a storm cell or near a tornado.
	local stormy = false
	if spec.stormSails then
		stormy = Sea.stormAt(position.X, position.Z) > 0.2 or Twister.find(position, t, 9) ~= nil
	end
	boat.stormy = stormy

	-- Horizontal motion relative to the water's own flow. V13.2: a Wavebreaker is carried harder by moving water (a
	-- rogue wave's push, a whirlpool's swirl: Sea.chaosFlow), so it surfs farther.
	local flowX, flowZ = Sea.currentAt(position.X, position.Z, t)
	if spec.surfer then
		local cx, cz = Sea.chaosFlow(position.X, position.Z, t)
		flowX += cx * (spec.surfer - 1)
		flowZ += cz * (spec.surfer - 1)
	end
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
	if nitro then
		local N = Config.BOAT_ABILITIES.nitro
		accel = spec.accel * payloadFactor * N.thrust
		topSpeed = spec.maxSpeed * payloadFactor * N.mult * (mini and Config.BOAT_MINI_MULT or 1)
	end
	if plowing then
		local R = Config.BOAT_ABILITIES.plow
		accel *= R.thrust
		topSpeed *= R.top
	end
	if stormy then
		accel *= spec.stormSails
		topSpeed *= spec.stormSails
	end
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
	-- V13: during a Wraith's slip the keel lets go for a moment, so the sideways dash is not straightened out at once.
	local grip = spec.grip * (loose and spec.driftGrip or 1) * (t < (boat.slipUntil or 0) and 0.12 or 1)
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
	-- V13.2: a chain (the Anchorjack's anchor, a Corsair's hook, a tow). Its pull is not water drag: the drag measurement
	-- skips the next step.
	local swingYaw = 0
	if boat.tether then
		swingYaw = applyTether(boat, dt, t)
		boat.predicted = nil
	end
	out.tethered = boat.tether and boat.tether.kind or nil
	if boat.justReleased then
		out.released = out.released or boat.justReleased
		boat.justReleased = nil
	end

	-- Steering: aim for a yaw rate. Sharp when slow, wider at top speed, sharper again in a
	-- drift, and a little control in the air to line up a landing.
	local authority = math.clamp(speedAbs / 12, 0.25, 1) / (1 + speedAbs / spec.turnFade)
	if loose then
		authority *= spec.driftTurn
	end
	local control = wet > 0 and math.max(wet, 0.3)
		or (grounded and Config.BOAT_LAND_TURN or (spec.airControl or Config.BOAT_AIR_CONTROL))
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
	if twistState == "inside" and not spec.twisterBail then
		yawTarget += 2.4 -- Round and round with the funnel. (V13: a Stormrunner holds its heading: aim the bail-out.)
	end
	if swingYaw ~= 0 then
		-- V13.2: swinging round an anchor, or reeled toward a hook, the bow comes round with it (steering still adds).
		yawTarget = swingYaw - steer * yawRate * 0.5
	end
	local trick = boat.trick
	if trick then
		-- V9: a trick owns the hull's orientation (see BoatSim.TRICKS). A hull that touches the water mid-trick
		-- comes down level anyway: a sketchy landing, never a capsized boat.
		local progress = (t - trick.startedAt) / trick.duration
		-- (V13.1: a tumble starts on the water, so it only counts as landed once it has been up a moment.)
		local landed = (wet > 0.25 or grounded or sinking) and not (trick.tumble and progress < 0.25)
		local rotation
		if landed or progress >= 1 then
			rotation = trick.base
			boat.trick = nil
			if trick.tumble then
				-- Thrown, not a trick: no callout, no burst, no penalty.
				boat.tricksDone = 0
			elseif landed then
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
		local righting = 14 * (0.55 + 0.45 * wet) * (spec.righting or 1)
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
		local jumpSpeed = (Config.BOAT_JUMP_SPEED + super * (Config.BOAT_SUPER_SPEED - Config.BOAT_JUMP_SPEED))
			* (spec.jumpMult or 1)
		hull:ApplyImpulse(Vector3.new(0, jumpSpeed * mass, 0))
		if super > 0 then
			-- Bow up, for the look of it (and so the stern meets the water first).
			local pitchInertia = mass * (size.Y * size.Y + size.Z * size.Z) / 12
			hull:ApplyAngularImpulse(cf.RightVector * super * Config.BOAT_SUPER_PITCH * pitchInertia)
			out.super = super
		end
		boat.hopOnly = super == 0 -- a plain hop earns no landing burst
		out.jumped = true
	elseif
		-- V13: the Reefhopper hops once more in the air (SPACE), once per flight.
		input.jump == true
		and spec.airHop
		and wet <= 0
		and not grounded
		and not boat.airHopped
		and boat.airTime > 0.12
		and t >= boat.jumpReadyAt
		and not sinking
	then
		local v = hull.AssemblyLinearVelocity
		hull.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, Config.BOAT_ABILITIES.spring.airHop), v.Z)
		boat.airHopped = true
		boat.hopOnly = false
		boat.jumpReadyAt = t + 0.3
		out.jumped = true
		out.airhop = true
	end

	-- Air time, and a burst for landing clean (upright, pointing the way you travel).
	if wet <= 0 and not grounded then
		boat.airTime += dt
	elseif grounded then
		-- Down on land: a thump, never a burst.
		if boat.airTime >= Config.BOAT_AIR_MIN then
			out.event = out.event or "splash"
			out.airTime = boat.airTime -- V12: for effects only (a long fall lands harder)
		end
		boat.airTime = 0
		boat.hopOnly = false
		boat.tricksDone = 0
		boat.sketchy = false
		boat.airHopped = false
	elseif wet >= 0.3 then
		boat.airHopped = false
		if boat.airTime >= Config.BOAT_AIR_MIN then
			out.airTime = boat.airTime -- V12: for effects only (a long fall lands harder)
			-- A burst needs a real flight (a ramp, a boosted hop), not a plain hop from rest. A hop with a
			-- trick in it is a real flight (V9).
			local tricks = boat.tricksDone
			local clean = up.Y > 0.8 and slip < 0.3 and forwardSpeed > spec.maxSpeed * 0.4 and not sinking
			if clean and tricks > 0 and not boat.sketchy then
				local paid = math.min(tricks, Config.TRICK.MAX_PAID)
				boat.miniUntil = math.max(boat.miniUntil, t + Config.BOAT_MINI_TIME[2])
				hull:ApplyImpulse(
					forward * (Config.BOAT_LANDING_KICK + Config.TRICK.KICK * paid) * (spec.landKick or 1) * mass
				)
				out.event = "trickland"
				out.tricks = tricks
			elseif clean and boat.airTime >= Config.BOAT_LANDING_AIR and not boat.hopOnly and not boat.sketchy then
				boat.miniUntil = math.max(boat.miniUntil, t + Config.BOAT_MINI_TIME[1])
				hull:ApplyImpulse(forward * Config.BOAT_LANDING_KICK * (spec.landKick or 1) * mass)
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

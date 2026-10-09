-- Physics boats. Each hull is a real unanchored part that the server owns, so every
-- player sees the same boat, it collides with rocks and shores, and it can leave the
-- water and land again. Forces come from three places:
--
--   buoyancy   spring impulses at points along the hull, pushing up toward the wave
--              surface from Sea.waveAt (so boats rise, fall, pitch and roll with swell)
--   thrust     W/S from the Driver seat (or an AI) along the hull, only while the hull
--              is in the water; drag toward the water's own flow makes currents push you
--   steering   a target yaw rate; steering also banks the boat into the turn
--
-- Crashes are measured as a sudden speed change the forces did not cause. Hull health
-- drops, and a wrecked boat ejects everyone aboard, goes under, and comes back at its
-- dock after BOAT_RESPAWN_TIME. Empty boats drift with the sea unless someone drops
-- anchor, and boats far from every player are frozen so the physics stays cheap.
--
-- Boarding uses a prompt on the hull (E). R drops or raises the anchor. Shift (client)
-- boosts. The server validates all of it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Sea = require(script.Parent.Sea)

local Boats = {}
Boats.list = {}
Boats.Sunk = Util.signal() -- (boat, cause)

local WOOD = Color3.fromRGB(110, 72, 44)
local TRIM = {
	Color3.fromRGB(255, 210, 75),
	Color3.fromRGB(110, 220, 255),
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(140, 255, 120),
	Color3.fromRGB(220, 140, 255),
}

local refs
local gates = {} -- Boost hoops and kicker ramps from the map (refs.boostGates).
local weightOf = {}
local lastIndex = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Building -------------------------------------------------------------------------
local function detail(model, hull, name, size, offset, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.CFrame = hull.CFrame * offset
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function makeSeat(model, hull, class, name, offset)
	local seat = Instance.new(class)
	seat.Name = name
	seat.Size = Vector3.new(3.4, 0.8, 3.4)
	seat.CFrame = hull.CFrame * offset
	seat.Color = Color3.fromRGB(60, 60, 70)
	seat.Material = Enum.Material.Fabric
	seat.CanCollide = false
	seat.Massless = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = seat
	weld.Parent = seat
	seat.Parent = model
	return seat
end

local function buildVisuals(spec, typeName, model, hull, trim)
	local size = spec.size
	local top = size.Y / 2
	local bow = -size.Z / 2
	-- A pointed prow made of two angled planks.
	for _, side in ipairs({ -1, 1 }) do
		detail(
			model,
			hull,
			"Prow",
			Vector3.new(size.X * 0.62, size.Y * 0.9, size.Z * 0.3),
			CFrame.new(side * size.X * 0.2, -0.1, bow - size.Z * 0.08) * CFrame.Angles(0, -side * math.rad(27), 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
	detail(
		model,
		hull,
		"Rail",
		Vector3.new(size.X + 0.4, 0.5, size.Z * 0.8),
		CFrame.new(0, top + 0.15, size.Z * 0.04),
		Color3.fromRGB(80, 52, 32),
		Enum.Material.Wood
	).Transparency =
		1
	if typeName == "skiff" then
		detail(model, hull, "Mast", Vector3.new(0.7, 12, 0.7), CFrame.new(0, top + 6, -2), Color3.fromRGB(88, 58, 36))
		detail(
			model,
			hull,
			"Sail",
			Vector3.new(0.25, 8.5, 7),
			CFrame.new(0, top + 7, 1.2),
			Color3.fromRGB(240, 235, 215),
			Enum.Material.Fabric
		)
		detail(
			model,
			hull,
			"Flag",
			Vector3.new(0.3, 2.4, 3.6),
			CFrame.new(0, top + 12.4, -0.2),
			trim,
			Enum.Material.Fabric
		)
	elseif typeName == "cutter" then
		for _, z in ipairs({ -6, 6 }) do
			detail(
				model,
				hull,
				"Mast",
				Vector3.new(0.9, 18, 0.9),
				CFrame.new(0, top + 9, z),
				Color3.fromRGB(88, 58, 36)
			)
			detail(
				model,
				hull,
				"Sail",
				Vector3.new(0.3, 12, 10),
				CFrame.new(0, top + 10, z + 0.6),
				Color3.fromRGB(240, 235, 215),
				Enum.Material.Fabric
			)
		end
		detail(model, hull, "Flag", Vector3.new(0.3, 3, 5), CFrame.new(0, top + 18.5, -6), trim, Enum.Material.Fabric)
		detail(
			model,
			hull,
			"Cabin",
			Vector3.new(8, 3, 7),
			CFrame.new(0, top + 1.5, size.Z / 2 - 5),
			WOOD,
			Enum.Material.WoodPlanks
		)
	else
		-- Patrol ship: dark hull, red sails, a cabin and a lantern.
		hull.Color = Color3.fromRGB(55, 45, 55)
		for _, z in ipairs({ -9, 4 }) do
			detail(
				model,
				hull,
				"Mast",
				Vector3.new(1.1, 24, 1.1),
				CFrame.new(0, top + 12, z),
				Color3.fromRGB(50, 40, 40)
			)
			detail(
				model,
				hull,
				"Sail",
				Vector3.new(0.3, 15, 13),
				CFrame.new(0, top + 12, z + 0.7),
				Color3.fromRGB(170, 35, 40),
				Enum.Material.Fabric
			)
		end
		detail(
			model,
			hull,
			"Cabin",
			Vector3.new(11, 5, 10),
			CFrame.new(0, top + 2.5, size.Z / 2 - 7),
			Color3.fromRGB(70, 55, 60),
			Enum.Material.WoodPlanks
		)
		local lamp = detail(
			model,
			hull,
			"Lantern",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(0, top + 6.4, size.Z / 2 - 7),
			Color3.fromRGB(255, 90, 60),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 90, 60)
		light.Range = 30
		light.Parent = lamp
	end
end

local function buildBoat(spawn)
	lastIndex += 1
	local typeName = spawn.type or "skiff"
	local spec = Config.BOAT_TYPES[typeName]
	local size = spec.size
	local trim = TRIM[(lastIndex - 1) % #TRIM + 1]
	-- The hull's center sits a little above water: half its height minus the draft.
	local home = CFrame.new(spawn.cf.X, size.Y / 2 - spec.draft, spawn.cf.Z) * spawn.cf.Rotation

	local model = Instance.new("Model")
	model.Name = spec.name .. lastIndex
	model:SetAttribute("BoatType", typeName)
	model:SetAttribute("Health", spec.health)
	model:SetAttribute("MaxHealth", spec.health)
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = size
	hull.CFrame = home
	hull.Color = WOOD
	hull.Material = Enum.Material.WoodPlanks
	hull.TopSurface = Enum.SurfaceType.Smooth
	hull.BottomSurface = Enum.SurfaceType.Smooth
	hull.CustomPhysicalProperties = PhysicalProperties.new(spec.density, 0.3, 0.2, 1, 1)
	hull.Parent = model
	model.PrimaryPart = hull
	buildVisuals(spec, typeName, model, hull, trim)

	local boat = {
		model = model,
		hull = hull,
		spec = spec,
		typeName = typeName,
		home = home,
		homeSpawn = spawn,
		seats = {},
		state = "float", -- "float" | "sunk" (wreck going under) | "gone" (waiting to respawn)
		health = spec.health,
		moored = false,
		asleep = false,
		boostUntil = 0,
		boostReadyAt = 0,
		buoyScale = 1,
		lastVelocity = Vector3.zero,
		lastAccel = Vector3.zero,
		lastImpactFx = 0,
		nextSleepCheck = 0,
		sunkAt = 0,
		respawnAt = 0,
		payload = 0,
		input = nil, -- { throttle, steer, boost }: an AI drives with this instead of a seat
		gateAt = {},
	}

	-- Buoyancy points under the hull: three rows, two columns.
	boat.points = {}
	for _, z in ipairs({ -0.38, 0, 0.38 }) do
		for _, x in ipairs({ -0.3, 0.3 }) do
			table.insert(boat.points, Vector3.new(x * size.X, -size.Y / 2, z * size.Z))
		end
	end

	if spec.passengers > 0 or typeName ~= "navy" then
		local seatY = size.Y / 2 + 0.7
		boat.driver = makeSeat(model, hull, "VehicleSeat", "Driver", CFrame.new(0, seatY, size.Z / 2 - 4))
		boat.driver.MaxSpeed = 0
		boat.driver.Torque = 0
		table.insert(boat.seats, boat.driver)
		local spots = {}
		if typeName == "skiff" then
			spots = { Vector3.new(0, seatY, 2) }
		elseif typeName == "cutter" then
			spots = { Vector3.new(-3.4, seatY, 2), Vector3.new(3.4, seatY, 2), Vector3.new(0, seatY, -3) }
		end
		for i, spot in ipairs(spots) do
			table.insert(boat.seats, makeSeat(model, hull, "Seat", "Passenger" .. i, CFrame.new(spot)))
		end
	end

	-- Boarding prompt (E) on the hull, and an anchor winch at the stern (R).
	if not spawn.ai then
		local board = Instance.new("ProximityPrompt")
		board.Name = "BoardPrompt"
		board.ObjectText = spec.name
		board.ActionText = "Board"
		board.HoldDuration = 0
		board.MaxActivationDistance = math.max(12, size.Z * 0.45)
		board.RequiresLineOfSight = false
		board.KeyboardKeyCode = Enum.KeyCode.E
		board.Parent = hull
		board.Triggered:Connect(function(player)
			Boats.board(boat, player)
		end)

		local winch = detail(
			model,
			hull,
			"Anchor",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(size.X * 0.32, size.Y / 2 + 0.6, size.Z / 2 - 1.2),
			Color3.fromRGB(70, 70, 80),
			Enum.Material.Metal
		)
		local anchorPrompt = Instance.new("ProximityPrompt")
		anchorPrompt.Name = "AnchorPrompt"
		anchorPrompt.ObjectText = "Anchor"
		anchorPrompt.ActionText = "Drop anchor"
		anchorPrompt.HoldDuration = 0.4
		anchorPrompt.MaxActivationDistance = 10
		anchorPrompt.RequiresLineOfSight = false
		anchorPrompt.KeyboardKeyCode = Enum.KeyCode.R
		anchorPrompt.Parent = winch
		boat.anchorPrompt = anchorPrompt
		anchorPrompt.Triggered:Connect(function(player)
			Boats.toggleAnchor(boat, player)
		end)
	end

	model.Parent = refs.folders.structures
	pcall(function()
		hull:SetNetworkOwner(nil)
	end)
	return boat
end

-- Occupants ------------------------------------------------------------------------
local function occupants(boat)
	local list = {}
	for _, seat in ipairs(boat.seats) do
		local humanoid = seat.Occupant
		if humanoid then
			local player = Players:GetPlayerFromCharacter(humanoid.Parent)
			table.insert(list, { player = player, humanoid = humanoid, seat = seat })
		end
	end
	return list
end

local function eject(boat)
	for _, entry in ipairs(occupants(boat)) do
		local weld = entry.seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		entry.humanoid.Sit = false
		local root = entry.humanoid.Parent and entry.humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = boat.hull.AssemblyLinearVelocity + Vector3.new(0, 30, 0)
		end
	end
end

function Boats.board(boat, player)
	if boat.state ~= "float" then
		return
	end
	local root, humanoid = Util.aliveRoot(player)
	if not root or humanoid.SeatPart then
		return
	end
	if (root.Position - boat.hull.Position).Magnitude > boat.spec.size.Z * 0.45 + 12 then
		return
	end
	for _, seat in ipairs(boat.seats) do
		if not seat.Occupant then
			seat:Sit(humanoid)
			return
		end
	end
	Net.toast(player, "This boat is full")
end

function Boats.toggleAnchor(boat, player)
	if boat.state ~= "float" then
		return
	end
	boat.moored = not boat.moored
	boat.model:SetAttribute("Moored", boat.moored)
	if boat.anchorPrompt then
		boat.anchorPrompt.ActionText = boat.moored and "Raise anchor" or "Drop anchor"
	end
	Net.toast(player, boat.moored and "Anchor down - the boat holds here" or "Anchor up")
end

-- The driver pressed Shift: a burst of speed, then a cooldown.
function Boats.boost(player)
	local _, humanoid = Util.aliveRoot(player)
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return
	end
	for _, boat in ipairs(Boats.list) do
		if boat.driver == seat and boat.state == "float" and not boat.moored then
			local t = now()
			if t >= boat.boostReadyAt then
				boat.boostUntil = t + Config.BOAT_BOOST_TIME
				boat.boostReadyAt = t + Config.BOAT_BOOST_COOLDOWN
				boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
				boat.model:SetAttribute("BoostReadyAt", boat.boostReadyAt)
				Net.broadcast("BoatBoost", { position = boat.hull.Position, boatName = boat.model.Name })
			end
			return
		end
	end
end

-- Damage and sinking ---------------------------------------------------------------
local function sink(boat, cause)
	boat.state = "sunk"
	boat.sunkAt = now()
	eject(boat)
	boat.moored = false
	boat.input = boat.input and { throttle = 0, steer = 0 } or nil
	Net.feed(
		"A " .. boat.spec.name:lower() .. " was wrecked" .. (cause and (" by " .. cause) or "") .. "!",
		Color3.fromRGB(255, 140, 90)
	)
	Net.broadcast("BoatSunk", { position = boat.hull.Position })
	Boats.Sunk:Fire(boat, cause)
end

function Boats.damage(boat, amount, cause)
	if boat.state ~= "float" or amount <= 0 then
		return
	end
	boat.health = math.max(0, boat.health - amount)
	boat.model:SetAttribute("Health", math.floor(boat.health))
	if boat.health <= 0 then
		sink(boat, cause)
	end
end

-- The boat a part belongs to, if any.
function Boats.boatOf(part)
	for _, boat in ipairs(Boats.list) do
		if part:IsDescendantOf(boat.model) then
			return boat
		end
	end
	return nil
end

-- An explosion or hit near boats: damage and shove each one in range.
function Boats.hitAt(position, radius, damage, push, cause, except)
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" and boat ~= except then
			local offset = boat.hull.Position - position
			local distance = offset.Magnitude
			if distance < radius + boat.spec.size.Z * 0.4 then
				local falloff = math.clamp(1 - distance / (radius + boat.spec.size.Z * 0.4), 0.25, 1)
				Boats.damage(boat, damage * falloff, cause)
				if boat.asleep then
					boat.hull.Anchored = false
					boat.asleep = false
				end
				local away = offset.Magnitude > 0.1 and offset.Unit or Vector3.yAxis
				boat.hull:ApplyImpulse((away * push + Vector3.new(0, push * 0.5, 0)) * falloff * boat.hull.AssemblyMass)
			end
		end
	end
end

-- Physics ---------------------------------------------------------------------------
local function payloadWeight(boat)
	local total = 0
	for _, entry in ipairs(occupants(boat)) do
		local id = entry.player and entry.player:GetAttribute("CarryingLoot")
		if id then
			total += weightOf[id] or 1
		end
	end
	return total
end

local function step(boat, dt, t)
	local hull = boat.hull
	local spec = boat.spec
	local size = spec.size
	local cf = hull.CFrame
	local position = cf.Position
	local velocity = hull.AssemblyLinearVelocity
	local spin = hull.AssemblyAngularVelocity
	local mass = hull.AssemblyMass
	local gravity = workspace.Gravity
	local up = cf.UpVector

	-- Buoyancy: spring + damper at each point under the surface.
	local count = #boat.points
	local k = mass * gravity / (count * spec.draft)
	local c = 0.85 * math.sqrt(k * mass / count)
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

	-- Input.
	local throttle, steer, wantBoost = 0, 0, false
	if boat.input then
		throttle, steer, wantBoost = boat.input.throttle, boat.input.steer, boat.input.boost == true
	elseif boat.driver and boat.driver.Occupant then
		throttle, steer = boat.driver.ThrottleFloat, boat.driver.SteerFloat
	end
	if wantBoost and t >= boat.boostReadyAt then
		boat.boostUntil = t + Config.BOAT_BOOST_TIME
		boat.boostReadyAt = t + Config.BOAT_BOOST_COOLDOWN
	end
	local boosting = t < boat.boostUntil
	local sinking = boat.state ~= "float"
	if boat.moored or sinking then
		throttle, steer = 0, 0
	end

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

	local payloadFactor = math.max(0.5, 1 - Config.BOAT_PAYLOAD_DRAG * boat.payload)
	local accel = spec.accel * payloadFactor * (boosting and Config.BOAT_BOOST_THRUST or 1)
	local topSpeed = spec.maxSpeed * payloadFactor * (boosting and Config.BOAT_BOOST_MULT or 1)
	local drive = throttle >= 0 and throttle * accel or throttle * accel * Config.BOAT_REVERSE
	-- The prop only bites while the stern is wet; a beached hull can still be shoved off.
	local bite = math.max(math.min(1, wet * 1.6), 0.25)
	drive *= bite
	local dragForward = accel / topSpeed

	-- The keel turns the boat's motion toward where it points instead of braking it
	-- (arcade drift): the faster you slide sideways, the more speed you shed.
	local speedMag = relative.Magnitude
	local redirected = relative
	if speedMag > 1 then
		local keel = math.min(1, spec.grip * math.max(wet, 0.15) * dt)
		local aligned = forward * (forwardSpeed >= 0 and 1 or -1) * speedMag
		redirected = relative:Lerp(aligned, keel)
		local slip = math.abs(lateralSpeed) / speedMag
		local kept = redirected.Magnitude > 0.01 and (speedMag * (1 - 0.5 * slip * keel)) / redirected.Magnitude or 1
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

	-- Steering: aim for a yaw rate. Nimble when slow, wider at top speed, and the boat
	-- banks into the turn.
	local speedFraction = math.clamp(math.abs(forwardSpeed) / 18, 0.3, 1) / (1 + math.abs(forwardSpeed) / 95)
	speedFraction *= math.max(wet, 0.1)
	local yawTarget = -steer * spec.turn * speedFraction * (forwardSpeed >= -1 and 1 or -1)
	local yawNow = spin:Dot(up)
	local yawInertia = mass * (size.X * size.X + size.Z * size.Z) / 12
	hull:ApplyAngularImpulse(up * (yawTarget - yawNow) * math.min(1, dt * 5) * yawInertia)

	local rollInertia = mass * (size.X * size.X + size.Y * size.Y) / 12
	local lean = steer * spec.lean * math.clamp(math.abs(forwardSpeed) / 45, 0, 1) * wet
	local tilt = up:Cross(Vector3.yAxis)
	local flat = spin - up * yawNow
	local righting = 14 * (0.35 + 0.65 * wet)
	hull:ApplyAngularImpulse((cf.LookVector * lean + tilt * righting - flat * 2.2 * (0.4 + wet)) * rollInertia * dt)

	-- Crashes: a speed change that our own forces did not cause.
	local expected = boat.lastVelocity + boat.lastAccel * dt
	local flatNow = Vector3.new(velocity.X, 0, velocity.Z)
	local flatExpected = Vector3.new(expected.X, 0, expected.Z)
	local surprise = (flatNow - flatExpected).Magnitude
	if surprise > Config.BOAT_IMPACT_MIN and boat.state == "float" and t >= (boat.impactGraceUntil or 0) then
		local power = surprise - Config.BOAT_IMPACT_MIN
		boat.impactGraceUntil = t + Config.BOAT_IMPACT_GRACE
		Boats.damage(boat, math.min(power * Config.BOAT_IMPACT_DAMAGE, spec.health * Config.BOAT_IMPACT_CAP), "a crash")
		if t - boat.lastImpactFx > 0.4 then
			boat.lastImpactFx = t
			Net.broadcast("BoatImpact", { position = position, power = math.min(1, power / 40) })
		end
	end
	boat.lastVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	boat.lastAccel = acceleration

	-- Capsized (or nearly): flip back upright with a hop, so no one is ever stuck.
	if up.Y < 0.25 then
		boat.flippedFor = (boat.flippedFor or 0) + dt
		if boat.flippedFor > 1.2 then
			boat.flippedFor = 0
			hull:ApplyAngularImpulse(forward * (up.Y < 0 and 1 or -1) * rollInertia * 3.2)
			hull:ApplyImpulse(Vector3.new(0, mass * 22, 0))
		end
	else
		boat.flippedFor = 0
	end

	-- HUD numbers, in steps so they replicate calmly.
	local speed = math.floor(horizontal.Magnitude + 0.5)
	if boat.model:GetAttribute("Speed") ~= speed then
		boat.model:SetAttribute("Speed", speed)
	end
	return boosting
end

-- Boost hoops give a burst of speed; kickers launch a fast boat into the air.
local function checkGates(boat, t)
	local hull = boat.hull
	local position = hull.Position
	for _, gate in ipairs(gates) do
		local dx, dz = position.X - gate.position.X, position.Z - gate.position.Z
		if
			dx * dx + dz * dz < gate.radius * gate.radius
			and math.abs(position.Y - gate.position.Y) < 14
			and t - (boat.gateAt[gate] or -10) > 1.5
		then
			local velocity = hull.AssemblyLinearVelocity
			local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if gate.kind == "boost" then
				boat.gateAt[gate] = t
				boat.boostUntil = t + 2
				boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
				hull:ApplyImpulse(gate.direction * hull.AssemblyMass * 26)
				Net.broadcast("GatePass", { position = position, kind = "boost" })
			elseif flatSpeed > 22 then
				boat.gateAt[gate] = t
				hull.AssemblyLinearVelocity = Vector3.new(velocity.X * 1.12, Config.BOAT_KICK_SPEED, velocity.Z * 1.12)
				Net.broadcast("GatePass", { position = position, kind = "kick" })
			end
		end
	end
end

local function respawn(boat)
	local hull = boat.hull
	boat.state = "float"
	boat.health = boat.spec.health
	boat.moored = false
	boat.buoyScale = 1
	boat.boostUntil = 0
	boat.boostReadyAt = 0
	boat.asleep = false
	boat.lastVelocity = Vector3.zero
	boat.lastAccel = Vector3.zero
	boat.payload = 0
	boat.model:SetAttribute("Health", boat.health)
	boat.model:SetAttribute("Moored", false)
	boat.model:SetAttribute("BoostEndsAt", nil)
	boat.model:SetAttribute("BoostReadyAt", nil)
	if boat.anchorPrompt then
		boat.anchorPrompt.ActionText = "Drop anchor"
	end
	hull.Anchored = false
	hull.CanCollide = true
	boat.model.Parent = refs.folders.structures
	boat.model:PivotTo(boat.home)
	hull.AssemblyLinearVelocity = Vector3.zero
	hull.AssemblyAngularVelocity = Vector3.zero
	pcall(function()
		hull:SetNetworkOwner(nil)
	end)
end

function Boats.build(worldRefs)
	refs = worldRefs
	gates = refs.boostGates or {}
	for _, def in ipairs(Config.LOOT) do
		weightOf[def.id] = def.weight or 1
	end
	for _, spawn in ipairs(refs.boatSpawns) do
		-- Spawns are { cf, type } or a bare CFrame.
		local entry = typeof(spawn) == "CFrame" and { cf = spawn, type = "skiff" } or spawn
		table.insert(Boats.list, buildBoat(entry))
	end
end

-- An AI-driven boat (Navy). Returns the boat; set boat.input each frame to steer it.
function Boats.spawnAI(typeName, cframe)
	local boat = buildBoat({ cf = cframe, type = typeName, ai = true })
	boat.input = { throttle = 0, steer = 0, boost = false }
	boat.ai = true
	table.insert(Boats.list, boat)
	return boat
end

function Boats.remove(boat)
	for i, other in ipairs(Boats.list) do
		if other == boat then
			table.remove(Boats.list, i)
			break
		end
	end
	eject(boat)
	boat.model:Destroy()
	boat.state = "gone"
end

function Boats.tick(dt)
	local t = now()
	-- Player positions, once per frame, for the sleep check.
	local positions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = Util.aliveRoot(player)
		if root then
			table.insert(positions, root.Position)
		end
	end

	-- A copy, because a sunk AI boat removes itself from the list.
	for _, boat in ipairs(table.clone(Boats.list)) do
		local hull = boat.hull
		if boat.state == "gone" then
			if t >= boat.respawnAt and not boat.ai then
				respawn(boat)
			end
		elseif boat.state == "sunk" then
			-- Going under: buoyancy fades, then the wreck vanishes until it respawns.
			local progress = (t - boat.sunkAt) / Config.BOAT_SINK_TIME
			boat.buoyScale = math.max(0, 1 - progress * 1.4)
			if progress >= 1 then
				if boat.ai then
					Boats.remove(boat)
					continue
				end
				boat.state = "gone"
				boat.respawnAt = t + Config.BOAT_RESPAWN_TIME
				boat.model.Parent = nil
			else
				step(boat, dt, t)
			end
		else
			-- Sleep check: an empty boat nobody is near stays frozen.
			if t >= boat.nextSleepCheck then
				boat.nextSleepCheck = t + 0.5
				local occupied = #occupants(boat) > 0 or boat.ai == true
				local near = occupied
				if not near then
					local p = hull.Position
					for _, other in ipairs(positions) do
						if (other - p).Magnitude < Config.BOAT_SLEEP_DISTANCE then
							near = true
							break
						end
					end
				end
				if near and boat.asleep then
					boat.asleep = false
					hull.Anchored = false
					pcall(function()
						hull:SetNetworkOwner(nil)
					end)
				elseif not near and not boat.asleep then
					boat.asleep = true
					hull.AssemblyLinearVelocity = Vector3.zero
					hull.AssemblyAngularVelocity = Vector3.zero
					hull.Anchored = true
				end
				boat.payload = payloadWeight(boat)
				boat.model:SetAttribute("Payload", boat.payload)
			end
			if not boat.asleep then
				step(boat, dt, t)
				checkGates(boat, t)
				-- Fell out of the world? Put it back at its dock.
				if hull.Position.Y < Config.BOUNDS_MIN.Y - 5 then
					respawn(boat)
				end
			end
		end
	end
end

function Boats.reset()
	for _, boat in ipairs(table.clone(Boats.list)) do
		if boat.ai then
			Boats.remove(boat)
		else
			eject(boat)
			respawn(boat)
		end
	end
end

return Boats

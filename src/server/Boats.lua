-- Physics boats. Each hull is a real unanchored part: it collides with rocks, shores and
-- other boats, and it can leave the water and land again. The forces themselves live in
-- shared/BoatSim.lua, because they run on whichever machine owns the hull:
--
--   an empty or AI boat   the server simulates it
--   a driven boat         the driver's client simulates it (Config.BOAT_CLIENT_PHYSICS), so
--                         steering answers at once instead of a network round trip later
--
-- The server stays in charge of everything that matters. It owns hull health, crashes,
-- sinking, boost cooldowns, anchors and who may sit where. It watches a driven hull every
-- frame, and if the boat goes faster or higher than BoatSim could have made it, or jumps from
-- place to place, the server takes the hull back and drives it itself for a few seconds.
--
-- Crashes are measured by the server on every hull the same way: a change of velocity, over a
-- tenth of a second, that the boat's own engine and keel cannot explain. Dragging a hull fast
-- over sand or rock scrapes it. A hull left alone patches itself slowly. A wrecked boat ejects
-- everyone aboard, goes under, and comes back at its dock after BOAT_RESPAWN_TIME. Empty boats
-- drift with the sea unless someone drops anchor, and boats far from every player are frozen
-- so the physics stays cheap.
--
-- Boarding uses a prompt on the hull (E). R drops or raises the anchor. Shift boosts and C
-- drifts (client). The server validates all of it.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local BoatSim = require(Shared:WaitForChild("BoatSim"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Sea = require(script.Parent.Sea)
local SeaNav = require(script.Parent.SeaNav)

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
-- Smooth hulls: a boat that runs up a beach slides a boat-length or two instead of stopping
-- dead, and one that hits a low sandbar fast enough skims over it.
local HULL_FRICTION = 0.3

local refs
local gates = {} -- Boost hoops and kicker ramps from the map, as plain tables (BoatSim.gate).
local weightOf = {}
local lastIndex = 0
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true

local IDLE = { throttle = 0, steer = 0, drift = false }
local seatInput = { throttle = 0, steer = 0, drift = false }

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
	seat.CanTouch = false -- No sitting by accident: the boarding prompt (E) is the only way in.
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
	hull.CustomPhysicalProperties = PhysicalProperties.new(spec.density, HULL_FRICTION, 0.15, 100, 1)
	hull.Parent = model
	model.PrimaryPart = hull
	buildVisuals(spec, typeName, model, hull, trim)

	-- The bow's underside slopes up, so a hull that meets a beach rides up onto it instead of
	-- hitting it like a wall. (An upside-down wedge in front of the hull box.) Players' boats
	-- only: an AI ship that overshoots should bump the shore, not climb the island.
	if not spawn.ai then
		local skidLength = size.Z * 0.3
		local skid = Instance.new("WedgePart")
		skid.Name = "BowSkid"
		skid.Size = Vector3.new(size.X * 0.92, size.Y, skidLength)
		skid.CFrame = home * CFrame.new(0, 0, -size.Z / 2 - skidLength / 2) * CFrame.Angles(0, 0, math.pi)
		skid.Transparency = 1
		skid.CanTouch = false
		skid.Massless = true
		skid.CustomPhysicalProperties = PhysicalProperties.new(spec.density, HULL_FRICTION, 0.15, 100, 1)
		local skidWeld = Instance.new("WeldConstraint")
		skidWeld.Part0 = hull
		skidWeld.Part1 = skid
		skidWeld.Parent = skid
		skid.Parent = model
	end

	-- BoatSim's fields (points, boostUntil, driftCharge...) plus the server's own.
	local boat = BoatSim.new(hull, spec)
	boat.model = model
	boat.typeName = typeName
	boat.home = home
	boat.homeSpawn = spawn
	boat.seats = {}
	boat.state = "float" -- "float" | "sunk" (wreck going under) | "gone" (waiting to respawn)
	boat.health = spec.health
	boat.asleep = false
	boat.boostReadyAt = 0
	boat.nextSleepCheck = 0
	boat.sunkAt = 0
	boat.respawnAt = 0
	boat.input = nil -- { throttle, steer, boost }: an AI drives with this instead of a seat
	boat.pilot = nil -- The player whose client is simulating this hull right now.
	boat.driftHeld = false -- The driver's drift key, when the server is the one simulating.
	boat.reclaimUntil = 0 -- The server keeps the hull until then after catching it misbehaving.
	boat.strikes = 0
	boat.history = {} -- Recent { t, v } samples, for measuring crashes.
	boat.crash = nil -- A crash being measured: { untilTime, peak }.
	boat.impactGraceUntil = 0
	boat.lastImpactFx = 0
	boat.lastDamageAt = -math.huge
	boat.scrape = 0

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
		board.MaxActivationDistance = math.max(14, size.Z * 0.5)
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

local function driverOf(boat)
	local humanoid = boat.driver and boat.driver.Occupant
	return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) or nil
end

-- The boat this player is driving, if any.
function Boats.drivenBy(player)
	local _, humanoid = Util.aliveRoot(player)
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return nil
	end
	for _, boat in ipairs(Boats.list) do
		if boat.driver == seat then
			return boat
		end
	end
	return nil
end

-- Hands the hull's physics to a player's client, or back to the server (nil).
local function setPilot(boat, player)
	if boat.pilot == player then
		return
	end
	boat.pilot = player
	boat.model:SetAttribute("Pilot", player and player.UserId or nil)
	pcall(function()
		boat.hull:SetNetworkOwner(player)
	end)
	-- A different machine is simulating now: start the watching and the drift from scratch.
	table.clear(boat.history)
	boat.crash = nil
	boat.strikes = 0
	boat.lastPosition = nil
	boat.driftCharge = 0
	boat.driftHeld = false
	boat.predicted = nil
	boat.waterDrag = 0
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

-- reach: how far from the hull the player may be (default: beside it; a grapple reaches farther).
function Boats.board(boat, player, reach)
	if boat.state ~= "float" then
		return
	end
	local root, humanoid = Util.aliveRoot(player)
	if not root or humanoid.SeatPart then
		return
	end
	-- Generous: a boat worth boarding is often moving.
	if (root.Position - boat.hull.Position).Magnitude > (reach or boat.spec.size.Z * 0.5 + 16) then
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

-- The driver pressed Shift: a burst of speed, then a cooldown. (The driver's client starts its
-- own burst at once and this confirms it; the speed check below uses this clock, not theirs.)
function Boats.boost(player)
	local boat = Boats.drivenBy(player)
	if not boat or boat.state ~= "float" or boat.moored then
		return
	end
	local t = now()
	if t >= boat.boostReadyAt then
		boat.boostUntil = t + Config.BOAT_BOOST_TIME
		boat.boostReadyAt = t + Config.BOAT_BOOST_COOLDOWN
		boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
		boat.model:SetAttribute("BoostReadyAt", boat.boostReadyAt)
		Net.broadcast("BoatBoost", { position = boat.hull.Position, userId = player.UserId })
	end
end

-- The driver's drift key. Only matters while the server is the one simulating their boat.
function Boats.setDrift(player, held)
	local boat = Boats.drivenBy(player)
	if boat then
		boat.driftHeld = held == true
	end
end

-- The driver's client says its boat did something worth showing (a drift burst, a landing).
-- It is only an effect for the other players, so the check is light.
function Boats.relayFx(player, kind)
	local boat = Boats.drivenBy(player)
	if not boat or boat.pilot ~= player then
		return
	end
	local t = now()
	if t - (boat.lastFxAt or 0) < 0.3 then
		return
	end
	boat.lastFxAt = t
	Net.broadcast("BoatFx", { kind = kind, position = boat.hull.Position, userId = player.UserId })
end

-- Damage and sinking ---------------------------------------------------------------
local function sink(boat, cause)
	boat.state = "sunk"
	boat.sinking = true
	boat.sunkAt = now()
	setPilot(boat, nil)
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
	boat.lastDamageAt = now()
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

-- Pushes a hull: adds `velocity` to its motion (and `spin` to its rotation). A hull simulated
-- by its driver's client cannot be pushed from here, so the push is sent to that client.
function Boats.shove(boat, velocity, spin)
	if boat.state == "gone" then
		return
	end
	if boat.asleep then
		boat.hull.Anchored = false
		boat.asleep = false
	end
	-- A push we caused is not a crash.
	boat.impactGraceUntil = math.max(boat.impactGraceUntil, now() + 0.5)
	boat.crash = nil
	if boat.pilot then
		Net.send(boat.pilot, "BoatPush", { hull = boat.hull, velocity = velocity, spin = spin })
	else
		local hull = boat.hull
		hull:ApplyImpulse(velocity * hull.AssemblyMass)
		if spin then
			hull:ApplyAngularImpulse(spin * hull.AssemblyMass * 20)
		end
	end
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
				local away = offset.Magnitude > 0.1 and offset.Unit or Vector3.yAxis
				Boats.shove(boat, (away * push + Vector3.new(0, push * 0.5, 0)) * falloff)
			end
		end
	end
end

-- Watching the hulls ------------------------------------------------------------------
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

-- The other hull closest to this one, if it is close enough to have been what we hit.
local function collidedWith(boat)
	local best, bestDistance
	for _, other in ipairs(Boats.list) do
		if other ~= boat and other.state == "float" then
			local distance = (other.hull.Position - boat.hull.Position).Magnitude
			local reach = (boat.spec.size.Z + other.spec.size.Z) * 0.62 + 6
			if distance < reach and (not bestDistance or distance < bestDistance) then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- Crashes and scrapes, measured the same way whoever simulates the hull. A crash is a change
-- of velocity over BOAT_IMPACT_WINDOW that the boat's own engine and keel cannot explain.
local function watchHull(boat, dt, t)
	local hull = boat.hull
	local spec = boat.spec
	local velocity = hull.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local history = boat.history
	table.insert(history, { t = t, v = flat })
	while #history > 2 and history[2].t <= t - Config.BOAT_IMPACT_WINDOW do
		table.remove(history, 1)
	end
	local old = history[1]
	local span = t - old.t
	if boat.state ~= "float" then
		return
	end

	if span >= Config.BOAT_IMPACT_WINDOW * 0.5 and t >= boat.impactGraceUntil then
		local change = (flat - old.v).Magnitude
		-- What the engine (boosting, braking) and the keel (snapping out of a drift) can do in
		-- that time. Their pushes are spread over many frames; a collision lands in one or two,
		-- which is why the window is short.
		local explained = (spec.accel * Config.BOAT_BOOST_THRUST * 1.1 + spec.grip * old.v.Magnitude * 0.85) * span
		local surprise = change - explained
		local crash = boat.crash
		if crash then
			crash.peak = math.max(crash.peak, surprise)
		elseif surprise > Config.BOAT_IMPACT_MIN then
			-- Keep measuring for one more window: the hit is still happening.
			boat.crash = { untilTime = t + Config.BOAT_IMPACT_WINDOW, peak = surprise }
		end
	end
	local crash = boat.crash
	if crash and t >= crash.untilTime then
		boat.crash = nil
		boat.impactGraceUntil = t + Config.BOAT_IMPACT_GRACE
		local power = crash.peak - Config.BOAT_IMPACT_MIN
		local other = collidedWith(boat)
		local damage = power * Config.BOAT_IMPACT_DAMAGE * spec.crashTaken * (other and other.spec.ramPower or 1)
		local cause = other and ("a collision with a " .. other.spec.name:lower()) or "a crash"
		if t - boat.lastImpactFx > 0.4 then
			boat.lastImpactFx = t
			Net.broadcast("BoatImpact", { position = hull.Position, power = math.min(1, power / 60) })
		end
		Boats.damage(boat, math.min(damage, spec.health * Config.BOAT_IMPACT_CAP), cause)
		if boat.state ~= "float" then
			return
		end
	end

	-- Scraping: the hull is out of the water, sitting on something, and still moving fast.
	local position = hull.Position
	local keelY = position.Y - spec.size.Y / 2
	if flat.Magnitude > Config.BOAT_SCRAPE_SPEED and keelY > Sea.waveAt(position.X, position.Z, t) - 0.5 then
		local hit = workspace:Raycast(position, Vector3.new(0, -(spec.size.Y / 2 + 1.4), 0), groundParams)
		if hit then
			boat.scrape += Config.BOAT_SCRAPE_DAMAGE * spec.crashTaken * dt
			if boat.scrape >= 4 then
				local amount = boat.scrape
				boat.scrape = 0
				if t - boat.lastImpactFx > 0.35 then
					boat.lastImpactFx = t
					Net.broadcast("BoatImpact", { position = position, power = 0.25, scrape = true })
				end
				Boats.damage(boat, amount, "running aground")
			end
		end
	end
end

-- A driven hull is simulated by its driver's client. Roblox lets that client move the hull any
-- way it likes, so check each frame that it only did what BoatSim could have done: no faster
-- than the boat can go, not hanging in the sky, not jumping from place to place. A boat that
-- breaks the rules for BOAT_STRIKE_TIME is taken back and driven by the server for a while.
local function police(boat, dt, t)
	local hull = boat.hull
	local spec = boat.spec
	local position = hull.Position
	local velocity = hull.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local boosted = t < boat.boostUntil + 2.5 -- A burst takes a moment to bleed off.
	local allowed = spec.maxSpeed * (boosted and Config.BOAT_BOOST_MULT or 1) * Config.BOAT_SPEED_SLACK
		+ Config.BOAT_SPEED_MARGIN
	local broken = position.X ~= position.X or speed ~= speed or math.abs(position.Y) > 5000
	-- Updates from the driver arrive in bursts on a bad connection, so a jump is judged
	-- against the time since the hull last moved here, not against one frame.
	local last = boat.lastPosition
	local jumped = false
	if last == nil then
		boat.lastPosition, boat.lastMovedAt = position, t
	elseif position ~= last then
		local elapsed = math.max(t - (boat.lastMovedAt or t), dt)
		jumped = (position - last).Magnitude > (allowed + 80) * elapsed * 2 + 15
		boat.lastPosition, boat.lastMovedAt = position, t
	end
	local over = speed > allowed
	local flying = position.Y - Sea.waveAt(position.X, position.Z, t) > Config.BOAT_MAX_ALTITUDE
	if broken or jumped then
		boat.strikes = Config.BOAT_STRIKE_TIME
	elseif over or flying then
		boat.strikes += dt
	else
		boat.strikes = math.max(0, boat.strikes - dt * 0.5)
		boat.lastGood = hull.CFrame
	end
	if boat.strikes < Config.BOAT_STRIKE_TIME then
		return
	end
	local driver = boat.pilot
	boat.reclaimUntil = t + Config.BOAT_RECLAIM_TIME
	setPilot(boat, nil)
	if broken or jumped or flying then
		-- It was somewhere it could not be: back to where it last behaved, at rest.
		if boat.lastGood then
			boat.model:PivotTo(boat.lastGood)
		end
		hull.AssemblyLinearVelocity = Vector3.zero
		hull.AssemblyAngularVelocity = Vector3.zero
	else
		-- Only too fast: slow it to its limit and carry on. If the check was wrong (a current
		-- and a burst and lag all at once), an honest driver barely notices.
		hull.AssemblyLinearVelocity = velocity * math.min(1, allowed / math.max(speed, 1))
	end
	warn(
		string.format(
			"[Boats] took %s back from %s (speed %.0f / %.0f, jumped %s, flying %s)",
			boat.model.Name,
			driver and driver.Name or "?",
			speed,
			allowed,
			tostring(jumped),
			tostring(flying)
		)
	)
	if driver then
		Net.toast(driver, "Your boat was reset: it moved in a way the server could not explain.")
	end
end

-- Puts a hull somewhere, at rest. The server takes the hull first and keeps it for a moment: a
-- hull simulated by its driver's client would be dragged straight back by that client's next
-- update (and then caught as a teleport).
function Boats.place(boat, cframe)
	local hull = boat.hull
	local t = now()
	setPilot(boat, nil)
	boat.reclaimUntil = math.max(boat.reclaimUntil, t + 0.5)
	boat.impactGraceUntil = math.max(boat.impactGraceUntil, t + 1)
	table.clear(boat.history)
	boat.crash = nil
	boat.lastPosition = nil
	boat.model:PivotTo(cframe)
	hull.AssemblyLinearVelocity = Vector3.zero
	hull.AssemblyAngularVelocity = Vector3.zero
end

local function respawn(boat)
	local hull = boat.hull
	setPilot(boat, nil)
	boat.state = "float"
	boat.sinking = false
	boat.health = boat.spec.health
	boat.moored = false
	boat.buoyScale = 1
	boat.boostUntil = 0
	boat.boostReadyAt = 0
	boat.miniUntil = 0
	boat.driftCharge = 0
	boat.airTime = 0
	boat.asleep = false
	boat.payload = 0
	boat.scrape = 0
	boat.reclaimUntil = 0
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
	pcall(function()
		hull:SetNetworkOwner(nil)
	end)
	Boats.place(boat, boat.home)
end

function Boats.build(worldRefs)
	refs = worldRefs
	groundParams.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	gates = {}
	for _, gate in ipairs(refs.boostGates or {}) do
		table.insert(gates, {
			x = gate.position.X,
			y = gate.position.Y,
			z = gate.position.Z,
			r = gate.radius,
			kind = gate.kind,
			dx = gate.direction.X,
			dz = gate.direction.Z,
			both = gate.both or nil,
		})
	end
	for _, def in ipairs(Config.LOOT) do
		weightOf[def.id] = def.weight or 1
	end
	for _, spawn in ipairs(refs.boatSpawns) do
		-- Spawns are { cf, type } or a bare CFrame.
		local entry = typeof(spawn) == "CFrame" and { cf = spawn, type = "skiff" } or spawn
		table.insert(Boats.list, buildBoat(entry))
	end

	-- What a driver's client needs to float its own boat on the same sea: the currents, the
	-- shelter map and the gates. It never changes, so it is sent once.
	local old = ReplicatedStorage:FindFirstChild("LootGoblinsSea")
	if old then
		old:Destroy()
	end
	local data = Sea.export(SeaNav.shelterGrid())
	data.gates = gates
	local value = Instance.new("StringValue")
	value.Name = "LootGoblinsSea"
	value.Value = HttpService:JSONEncode(data)
	value.Parent = ReplicatedStorage
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

-- Runs the physics for a hull the server is simulating, and the map's gates.
local function simulate(boat, dt, t)
	local input = boat.input
	if input then
		if input.boost and t >= boat.boostReadyAt then
			boat.boostUntil = t + Config.BOAT_BOOST_TIME
			boat.boostReadyAt = t + Config.BOAT_BOOST_COOLDOWN
		end
	elseif boat.driver and boat.driver.Occupant then
		input = seatInput
		input.throttle, input.steer, input.drift = boat.driver.ThrottleFloat, boat.driver.SteerFloat, boat.driftHeld
	else
		input = IDLE
	end
	local out = BoatSim.step(boat, input, dt, t)
	if out.event and out.event ~= "splash" then
		Net.broadcast("BoatFx", { kind = out.event, position = boat.hull.Position })
	end
end

function Boats.tick(dt)
	local t = now()
	dt = math.min(dt, Config.BOAT_MAX_STEP)
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
				BoatSim.step(boat, IDLE, dt, t)
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
					table.clear(boat.history)
					pcall(function()
						hull:SetNetworkOwner(nil)
					end)
				elseif not near and not boat.asleep then
					boat.asleep = true
					hull.AssemblyLinearVelocity = Vector3.zero
					hull.AssemblyAngularVelocity = Vector3.zero
					hull.Anchored = true
				end
				local payload = payloadWeight(boat)
				if payload ~= boat.payload then
					boat.payload = payload
					boat.model:SetAttribute("Payload", payload)
				end
			end
			if not boat.asleep then
				-- Who simulates this hull right now?
				local driver = nil
				if Config.BOAT_CLIENT_PHYSICS and not boat.ai and t >= boat.reclaimUntil then
					driver = driverOf(boat)
				end
				setPilot(boat, driver)
				if boat.pilot then
					police(boat, dt, t)
				else
					simulate(boat, dt, t)
				end
				-- Gates: the simulating machine does the physics; everyone gets the effect.
				local kind = BoatSim.gate(boat, gates, t, boat.pilot == nil)
				if kind then
					-- The gate's own kick is not a crash.
					boat.impactGraceUntil = math.max(boat.impactGraceUntil, t + 0.4)
					boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
					Net.broadcast("GatePass", {
						position = hull.Position,
						kind = kind,
						userId = boat.pilot and boat.pilot.UserId or nil,
					})
				end
				watchHull(boat, dt, t)
				-- A hull left alone patches itself.
				if
					boat.state == "float"
					and boat.health < boat.spec.health
					and t - boat.lastDamageAt > Config.BOAT_REPAIR_DELAY
				then
					local before = math.floor(boat.health)
					boat.health = math.min(boat.spec.health, boat.health + Config.BOAT_REPAIR_RATE * dt)
					if math.floor(boat.health) ~= before then
						boat.model:SetAttribute("Health", math.floor(boat.health))
					end
				end
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

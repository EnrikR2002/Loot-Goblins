-- The skyship: every raid starts on a flying pirate ship hung 540 studs over the middle of the sea.
-- Goblins stand on the deck (or walk out along its wings), climb into a cannon (E), LOOK at where
-- they want to come down and fire. The raid clock runs from the first second; the window is short
-- (Config.SKYSHIP.WINDOW) and anyone still aboard when it ends is fired off automatically, at the
-- island they chose on the map or a near one.
--
-- V8: the ship only owns the ship. Its twelve cannons are LAUNCHERS (server/Flight.lua), the same
-- thing an island catapult is, so the aiming, the flight, the bounces and the landings are one system.
-- What is here: the hull, the deck spots, the wings you can walk on, the window, and what happens to
-- a goblin who walks off the edge (a free dive) or who is still aboard at the end (fired off).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Dive = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Dive"))
local Landing = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Landing"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Flight = require(script.Parent.Flight)

local Skyship = {}

local S = Config.SKYSHIP
local D = Config.DIVE

local model
local shipCFrame
local cannons = {}
local deckSpawns = {}
local aboard = {} -- player -> { spot, autoFor }: goblins who are the ship's business (on deck or in a cannon)
local chosen = {} -- player -> island id picked on the map
local opensAt, endsAt = 0, 0
local boardedFor = 0 -- a counter: a straggler is only auto-fired once per window
local landing = {} -- V12: island id -> where a goblin who picks it comes down (see findLandings)

local HULL_GROUP = Flight.HULL_GROUP

local function now()
	return workspace:GetServerTimeNow()
end

-- Building the ship -----------------------------------------------------------------------------
local WOOD = Color3.fromRGB(150, 98, 58)
local WOOD_LIGHT = Color3.fromRGB(184, 128, 76)
local DARK_WOOD = Color3.fromRGB(88, 56, 36)
local SAIL = Color3.fromRGB(246, 236, 210)
local TRIM = Color3.fromRGB(255, 196, 46)
local RED = Color3.fromRGB(214, 58, 48)

local function part(name, size, cf, color, material, collide, shape)
	local p = Instance.new(shape or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = shipCFrame * cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildCannon(index, x, z, outward)
	local base = part("CannonBase" .. index, Vector3.new(7, 2.4, 9), CFrame.new(x, 2.2, z), DARK_WOOD)
	local yaw = outward > 0 and math.rad(-90) or math.rad(90) -- the barrel's default heading: out over the side
	local baseCF = shipCFrame * CFrame.new(x, 4.6, z) * CFrame.Angles(0, yaw, 0)
	local barrel = Instance.new("Part")
	barrel.Name = "Cannon" .. index
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(11, 4.6, 4.6)
	barrel.Color = Color3.fromRGB(52, 54, 62)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CanTouch = false
	barrel.TopSurface = Enum.SurfaceType.Smooth
	barrel.BottomSurface = Enum.SurfaceType.Smooth
	-- The cylinder's axis is its X: aim X along the launch direction.
	local function aim(direction)
		local from = baseCF.Position
		barrel.CFrame = CFrame.lookAt(from, from + direction) * CFrame.Angles(0, math.rad(90), 0)
	end
	local out = (shipCFrame.RightVector * outward)
	local rest = (out + Vector3.new(0, 0.55, 0)).Unit
	aim(rest)
	barrel.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "CannonRing" .. index
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1, 5.4, 5.4)
	ring.Color = TRIM
	ring.Material = Enum.Material.Metal
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.Parent = model
	local function setRing()
		ring.CFrame = barrel.CFrame * CFrame.new(4.1, 0, 0)
	end
	setRing()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LoadPrompt"
	prompt.ObjectText = "Launch cannon"
	prompt.ActionText = "Climb in"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = barrel
	local cannon = Flight.addLauncher({
		kind = "cannon",
		index = index,
		barrel = barrel,
		ring = ring,
		base = base,
		prompt = prompt,
		from = baseCF.Position,
		speed = D.CANNON_SPEED,
		elevation = D.CANNON_ELEVATION,
		-- With nobody aiming it: a point on the sea, out over its own side.
		rest = Vector3.new(baseCF.Position.X + out.X * 900, 0, baseCF.Position.Z + out.Z * 900),
		exit = baseCF.Position + Vector3.new(0, 1.5, 0) - out * 7,
		back = "aboard",
		-- Climbing in with an island picked on the map: it starts pointed there.
		restFor = function(player)
			return chosen[player] and Skyship.landingFor(chosen[player]) or nil
		end,
		aim = function(direction)
			aim(direction)
			setRing()
		end,
		fired = function(_direction)
			barrel.CFrame = barrel.CFrame * CFrame.new(-2, 0, 0)
			task.delay(0.35, function()
				aim(rest)
				setRing()
			end)
		end,
		-- V9: climb in and aim any time you are aboard (the intermission too); it fires from the bell.
		ready = function(player)
			return aboard[player] ~= nil
		end,
		canFire = function(_player)
			local t = now()
			if workspace:GetAttribute("RaidPhase") ~= "raid" or opensAt <= 0 or t < opensAt then
				local left = opensAt > 0 and math.max(1, math.ceil(opensAt - t)) or 0
				return false,
					left > 0 and ("The cannons fire at the bell: " .. left .. "...") or "The cannons fire at the bell."
			end
			return true
		end,
	})
	cannon.restDirection = rest
	table.insert(cannons, cannon)
end

-- V10: the dressing that makes it the GOLDEN GOBLIN (docs/ART_DIRECTION.md). A rounded hull in three tiers of
-- planking with a gold stripe, a curved prow with a golden goblin figurehead and a bowsprit, a jib, striped
-- sails, rigging, a crow's nest and a pennant, glowing stern windows and lanterns, and two propellers (the
-- clients spin them). Every piece here is decoration: non-colliding and not hit by rays, so the deck, the
-- wings, the cannons and the aim are exactly what they were.
local function line(name, a, b, width, color)
	local mid = (a + b) / 2
	local p = part(
		name,
		Vector3.new(width, width, (b - a).Magnitude),
		CFrame.lookAt(mid, b),
		color,
		Enum.Material.Wood,
		false
	)
	p.CastShadow = false
	return p
end

local function dressShip()
	local B = S.BEAM
	for _, side in ipairs({ -1, 1 }) do
		-- The hull's belly: three tiers of planking curving in toward the keel.
		part(
			"HullSide",
			Vector3.new(2.6, 7, 116),
			CFrame.new(side * 22.4, -2.8, 0) * CFrame.Angles(0, 0, side * math.rad(-14)),
			WOOD_LIGHT,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullSide",
			Vector3.new(2.6, 7, 108),
			CFrame.new(side * 19.2, -8.8, 1) * CFrame.Angles(0, 0, side * math.rad(-32)),
			WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullSide",
			Vector3.new(2.6, 6, 96),
			CFrame.new(side * 14.6, -13.6, 2) * CFrame.Angles(0, 0, side * math.rad(-50)),
			DARK_WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullStripe",
			Vector3.new(0.7, 1.4, 117),
			CFrame.new(side * 23.5, -0.9, 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		-- The prow: two panels closing to a point under the bow.
		part(
			"BowHull",
			Vector3.new(2.6, 11, 36),
			CFrame.new(side * 8.4, -4.5, -84) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(-14)),
			WOOD_LIGHT,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"BowStripe",
			Vector3.new(0.7, 1.4, 36),
			CFrame.new(side * 9.9, -0.9, -84) * CFrame.Angles(0, side * math.rad(-25), 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		-- Stern lanterns on the quarterdeck's corners.
		part(
			"SternPost",
			Vector3.new(0.9, 7, 0.9),
			CFrame.new(side * 20.5, 10.5, 86),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)
		local lamp = part(
			"SternLamp",
			Vector3.new(2, 2, 2),
			CFrame.new(side * 20.5, 14.6, 86),
			Color3.fromRGB(255, 206, 120),
			Enum.Material.Neon,
			false
		)
		lamp.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Range = 34
		light.Brightness = 1.4
		light.Parent = lamp
	end
	-- The figurehead: a golden goblin leaning out over the clouds, ears back.
	local head = part("FigureHead", Vector3.new(6, 6, 6), CFrame.new(0, -0.5, -101), TRIM, Enum.Material.Metal, false)
	head.Shape = Enum.PartType.Ball
	part(
		"FigureBody",
		Vector3.new(5, 6, 4),
		CFrame.new(0, -5, -99) * CFrame.Angles(math.rad(-20), 0, 0),
		TRIM,
		Enum.Material.Metal,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		part(
			"FigureEar",
			Vector3.new(0.8, 3, 5),
			CFrame.new(side * 3.6, 1.2, -99.5)
				* CFrame.Angles(math.rad(-25), side * math.rad(-30), side * math.rad(-35)),
			TRIM,
			Enum.Material.Metal,
			false
		)
		local eye = part(
			"FigureEye",
			Vector3.new(1, 1, 1),
			CFrame.new(side * 1.4, 0.4, -103.8),
			Color3.fromRGB(110, 255, 210),
			Enum.Material.Neon,
			false
		)
		eye.Shape = Enum.PartType.Ball
	end
	-- Bowsprit and jib.
	part(
		"Bowsprit",
		Vector3.new(1.8, 1.8, 36),
		CFrame.new(0, 8, -106) * CFrame.Angles(math.rad(20), 0, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	local jib =
		part("Jib", Vector3.new(0.5, 40, 66), CFrame.new(0, 25, -76), SAIL, Enum.Material.Fabric, false, "WedgePart")
	jib.Transparency = 0.04
	-- Sails: a red band and a gold hem on each; a crow's nest and a pennant on the mainmast.
	for i, z in ipairs({ -42, -4, 40 }) do
		local height = i == 2 and 96 or 78
		part(
			"SailBand",
			Vector3.new(B * 1.3 + 0.2, height * 0.07, 0.9),
			CFrame.new(0, height * 0.6, z - 0.8),
			RED,
			Enum.Material.Fabric,
			false
		)
		part(
			"SailHem",
			Vector3.new(B * 1.3 + 0.2, 1.2, 0.9),
			CFrame.new(0, height * 0.27, z - 0.8),
			TRIM,
			Enum.Material.Fabric,
			false
		)
		-- Rigging from the masthead down to the rails, fore and aft on both sides.
		for _, side in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -16, 14 }) do
				line(
					"Rigging",
					Vector3.new(0, height - 2, z),
					Vector3.new(side * (B / 2 - 1), 3, z + dz),
					0.3,
					DARK_WOOD
				)
			end
		end
	end
	local nest = part(
		"CrowsNest",
		Vector3.new(2, 8, 8),
		CFrame.new(0, 80, -4) * CFrame.Angles(0, 0, math.rad(90)),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	nest.Shape = Enum.PartType.Cylinder
	part("Pennant", Vector3.new(0.3, 3.4, 20), CFrame.new(0, 99, 6), TRIM, Enum.Material.Fabric, false)
	part("PennantTip", Vector3.new(0.3, 2.4, 6), CFrame.new(0, 99, 18.5), RED, Enum.Material.Fabric, false)
	-- Glowing stern windows.
	for _, x in ipairs({ -14, -7, 0, 7, 14 }) do
		part(
			"SternWindow",
			Vector3.new(3.4, 4, 0.4),
			CFrame.new(x, 11.5, 89.2),
			Color3.fromRGB(255, 214, 130),
			Enum.Material.Neon,
			false
		)
	end
	-- Two propellers under the stern. The server only builds them; every client spins its own (Skyship.lua).
	for _, side in ipairs({ -1, 1 }) do
		local hub = part(
			"PropellerHub",
			Vector3.new(4, 3, 3),
			CFrame.new(side * 15, -7, 93) * CFrame.Angles(0, math.rad(90), 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		hub.Shape = Enum.PartType.Cylinder
		hub:SetAttribute("Spin", side)
		for k = 0, 2 do
			local blade = part(
				"PropellerBlade",
				Vector3.new(2.4, 12, 0.8),
				CFrame.new(side * 15, -7, 94.5)
					* CFrame.Angles(0, 0, math.rad(k * 120))
					* CFrame.new(0, 6, 0)
					* CFrame.Angles(0, math.rad(20), 0),
				DARK_WOOD,
				Enum.Material.Wood,
				false
			)
			blade:SetAttribute("Spin", side)
		end
	end
end

-- V11: Madame Ragwort's wardrobe, a tailor's stall on the quarterdeck where every raid begins, so a goblin waiting for
-- the cannons sees the shop. Decoration only (nothing here is solid or hit by rays); its prompt opens the wardrobe on
-- the client (client/Shop.lua listens for prompts with the OpensWardrobe attribute).
local function buildWardrobe()
	local x, z = -13, 72
	local SKIN = Color3.fromRGB(126, 184, 72)
	local function ball(name, size, cf, color, material)
		local p = part(name, size, cf, color, material or Enum.Material.SmoothPlastic, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	part(
		"WardrobeCounter",
		Vector3.new(8, 3, 2.4),
		CFrame.new(x, 8.5, z - 2),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks,
		false
	)
	part(
		"WardrobeCounterTop",
		Vector3.new(8.6, 0.4, 2.8),
		CFrame.new(x, 10.2, z - 2),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	for _, px in ipairs({ -3.8, 3.8 }) do
		for _, pz in ipairs({ -3.2, 3.6 }) do
			part(
				"WardrobePost",
				Vector3.new(0.5, 7.4, 0.5),
				CFrame.new(x + px, 10.7, z + pz),
				DARK_WOOD,
				Enum.Material.Wood,
				false
			)
		end
	end
	for i = 0, 4 do
		part(
			"WardrobeAwning",
			Vector3.new(1.8, 0.3, 8.2),
			CFrame.new(x - 3.6 + i * 1.8, 14.6, z + 0.2) * CFrame.Angles(math.rad(14), 0, 0),
			i % 2 == 0 and RED or Color3.fromRGB(246, 240, 226),
			Enum.Material.Fabric,
			false
		)
	end
	-- The tailor: a stout goblin in spectacles with a tape measure round her neck.
	ball(
		"RagwortBody",
		Vector3.new(2.4, 2.8, 1.9),
		CFrame.new(x, 11.4, z + 0.4),
		Color3.fromRGB(150, 70, 140),
		Enum.Material.Fabric
	)
	ball("RagwortHead", Vector3.new(1.7, 1.6, 1.6), CFrame.new(x, 13.4, z + 0.3), SKIN)
	ball("RagwortNose", Vector3.new(0.5, 0.5, 0.9), CFrame.new(x, 13.3, z - 0.6), SKIN)
	ball("RagwortBun", Vector3.new(1.1, 1, 1.1), CFrame.new(x, 14.4, z + 0.6), Color3.fromRGB(196, 196, 214))
	part(
		"RagwortTape",
		Vector3.new(0.25, 2.2, 0.08),
		CFrame.new(x - 0.45, 12.3, z - 0.55),
		Color3.fromRGB(255, 214, 60),
		Enum.Material.Fabric,
		false
	)
	part(
		"RagwortTape",
		Vector3.new(0.25, 2.2, 0.08),
		CFrame.new(x + 0.45, 12.3, z - 0.55),
		Color3.fromRGB(255, 214, 60),
		Enum.Material.Fabric,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		local ear = part(
			"RagwortEar",
			Vector3.new(0.25, 0.7, 1.4),
			CFrame.new(x + side * 1.15, 13.6, z + 0.4)
				* CFrame.Angles(0, math.rad(180 + side * -20), side * math.rad(-62)),
			SKIN,
			Enum.Material.SmoothPlastic,
			false,
			"WedgePart"
		)
		ear.CastShadow = false
		local lens = part(
			"RagwortLens",
			Vector3.new(0.08, 0.42, 0.42),
			CFrame.new(x + side * 0.32, 13.65, z - 0.52) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(220, 240, 255),
			Enum.Material.Glass,
			false
		)
		lens.Shape = Enum.PartType.Cylinder
		lens.Transparency = 0.35
		ball("RagwortHand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + side * 1.3, 10.9, z - 0.9), SKIN)
	end
	-- Stock on the counter and a rack: hats, a folded coat, a little boat flag.
	local tricorn = part(
		"StockHat",
		Vector3.new(1.5, 0.5, 1.5),
		CFrame.new(x - 2.4, 10.7, z - 2.2),
		Color3.fromRGB(40, 32, 38),
		Enum.Material.Fabric,
		false
	)
	tricorn.Shape = Enum.PartType.Cylinder
	tricorn.CFrame = shipCFrame * CFrame.new(x - 2.4, 10.7, z - 2.2) * CFrame.Angles(0, 0, math.rad(90))
	part(
		"StockCoat",
		Vector3.new(1.8, 0.5, 1.2),
		CFrame.new(x + 2.2, 10.65, z - 2.1),
		Color3.fromRGB(176, 36, 40),
		Enum.Material.Fabric,
		false
	)
	ball("StockCrown", Vector3.new(0.9, 0.6, 0.9), CFrame.new(x + 2.2, 11.1, z - 2.1), TRIM, Enum.Material.Metal)
	part("RackPole", Vector3.new(0.35, 7, 0.35), CFrame.new(x + 6.2, 10.5, z + 1), DARK_WOOD, Enum.Material.Wood, false)
	part(
		"RackArm",
		Vector3.new(2.6, 0.25, 0.25),
		CFrame.new(x + 6.2, 13.6, z + 1),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	part(
		"RackCape",
		Vector3.new(1.6, 3, 0.15),
		CFrame.new(x + 5.5, 12, z + 1.1),
		Color3.fromRGB(70, 110, 200),
		Enum.Material.Fabric,
		false
	)
	part(
		"RackSack",
		Vector3.new(1.2, 1.5, 1),
		CFrame.new(x + 7, 12.4, z + 1.1),
		Color3.fromRGB(178, 142, 92),
		Enum.Material.Fabric,
		false
	)
	-- The sign.
	local board = part(
		"WardrobeSign",
		Vector3.new(8.4, 1.8, 0.3),
		CFrame.new(x, 16.3, z - 3.6),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = board
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.Text = "WARDROBE"
	signLabel.TextColor3 = TRIM
	signLabel.TextScaled = true
	signLabel.Parent = signGui
	-- The prompt: walk up and press E (or tap it).
	local promptPart = part("WardrobePrompt", Vector3.new(6, 4, 1), CFrame.new(x, 9.5, z - 3.4), TRIM, nil, false)
	promptPart.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WardrobePrompt"
	prompt.ObjectText = "Madame Ragwort's Wardrobe"
	prompt.ActionText = "Shop and dress up"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensWardrobe", true)
	prompt.Parent = promptPart
end

-- V12: where a goblin who picks an island comes down. Through V11 a pick (the map, the ship's own auto-fire)
-- aimed at the island's middle at sea level, which is often water: the throw came down in the sea beside the
-- island and skipped three times on past it (measured: 390 studs beyond Pebble Isle's treasure). Now each
-- island has one spot: dry, level, open ground (no roof, no lava) as near its treasure as there is, looked for
-- first on the ship's side so the arc comes in over the sea. Every machine reads the same spot (published on
-- the generated folder as `Land_<id>`), so the map's pick, the cannon's first aim, the beam and the auto-fire
-- agree. Aiming by hand is unchanged: a goblin can still look anywhere and land anywhere.
local function insideLava(position, zones)
	for _, zone in ipairs(zones or {}) do
		local p = zone.part
		if p and p.Parent then
			local localPos = p.CFrame:PointToObjectSpace(position)
			local half = p.Size / 2 + Vector3.new(6, 6, 6)
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- From high in the sky, so a spot under an overhang, a cave roof or a building is never chosen.
local SKY = 900
local function findLandings(worldRefs)
	if not worldRefs or not worldRefs.lootSpots then
		return
	end
	local folders = worldRefs.folders
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, folders.ground, folders.structures }
	params.IgnoreWater = false
	for id in pairs(Config.ISLAND_INFO) do
		local spot
		for _, def in ipairs(Config.LOOT) do
			if def.island == id and worldRefs.lootSpots[def.id] then
				spot = worldRefs.lootSpots[def.id].Position
				break
			end
		end
		-- V12: an island whose treasure is under a roof (Crystal Isle's Heart) names where to aim instead.
		local hint = spot and worldRefs.landingHints and worldRefs.landingHints[id]
		if hint then
			spot = hint
		end
		if spot then
			local function good(point, pass)
				local hit = workspace:Raycast(Vector3.new(point.X, SKY, point.Z), Vector3.new(0, -SKY - 100, 0), params)
				return hit
					and Landing.acceptable({
						y = hit.Position.Y,
						normalY = hit.Normal.Y,
						water = hit.Material == Enum.Material.Water,
						structure = hit.Instance:IsDescendantOf(folders.structures),
						lava = insideLava(hit.Position, worldRefs.lavaZones),
					}, spot.Y, pass.sea)
					and hit.Position
			end
			local found
			for _, pass in ipairs(Landing.PASSES) do
				local points = Landing.candidates(spot, shipCFrame.Position)
				if hint then
					table.insert(points, 1, hint) -- the hint itself first
				end
				for _, point in ipairs(points) do
					local at = good(point, pass)
					if at then
						-- V12: dry ground all round it, and no water just before it on the way in (a throw comes down
						-- a little short): slopes, rocks and roofs are fine there, the sea and lava are not.
						local apron = true
						local around = Landing.apron(point, pass.apron)
						for _, back in ipairs(Landing.approach(point, shipCFrame.Position, pass.approach)) do
							table.insert(around, back)
						end
						for _, other in ipairs(around) do
							local hit = workspace:Raycast(
								Vector3.new(other.X, SKY, other.Z),
								Vector3.new(0, -SKY - 100, 0),
								params
							)
							if
								not hit
								or hit.Material == Enum.Material.Water
								or hit.Position.Y < spot.Y - Landing.BELOW
								or insideLava(hit.Position, worldRefs.lavaZones)
							then
								apron = false
								break
							end
						end
						if apron then
							found = at
							break
						end
					end
				end
				if found then
					break
				end
			end
			landing[id] = found or spot
			folders.root:SetAttribute("Land_" .. id, landing[id])
		end
	end
end

-- Where a pick of island `id` comes down: its landing spot, or (an island with no treasure) its middle.
function Skyship.landingFor(id)
	local island = id and Archipelago.byId[id]
	if not island then
		return nil
	end
	return landing[id] or Vector3.new(island.x, 0, island.z)
end

function Skyship.build(worldRefs)
	local old = workspace:FindFirstChild("LootGoblinsGenerated")
	local landmarks = old and old:FindFirstChild("Landmarks") or workspace
	shipCFrame = CFrame.new(S.POSITION)
	model = Instance.new("Model")
	model.Name = "Skyship"

	-- The deck, bow and stern.
	part("Deck", Vector3.new(S.BEAM, 2, 118), CFrame.new(0, 0, 0), WOOD)
	part("BowDeck", Vector3.new(S.BEAM * 0.62, 2, 22), CFrame.new(0, 0, -70), WOOD)
	part("BowTip", Vector3.new(S.BEAM * 0.3, 2, 18), CFrame.new(0, 0, -89), WOOD)
	part("QuarterDeck", Vector3.new(S.BEAM, 2, 30), CFrame.new(0, 6, 72), WOOD)
	part("QuarterStep", Vector3.new(S.BEAM, 6, 2), CFrame.new(0, 3, 56), DARK_WOOD)
	part("QuarterRamp", Vector3.new(14, 2, 16), CFrame.new(0, 3, 50) * CFrame.Angles(math.rad(22), 0, 0), WOOD)
	part("SternWall", Vector3.new(S.BEAM + 2, 14, 2), CFrame.new(0, 13, 88), DARK_WOOD)
	-- The hull under it: shapes only, nothing to bump into, narrower than the deck so a goblin who
	-- hops the rail falls clear of it.
	part("Keel", Vector3.new(S.BEAM * 0.55, 14, 128), CFrame.new(0, -8, 4), DARK_WOOD, nil, false)
	part("KeelBow", Vector3.new(S.BEAM * 0.3, 10, 24), CFrame.new(0, -6, -76), DARK_WOOD, nil, false)
	part("HullBand", Vector3.new(S.BEAM * 0.8, 2, 124), CFrame.new(0, -1.2, 2), TRIM, Enum.Material.Metal, false)
	-- The rails: low walls along both sides with the cannons set into them.
	for _, side in ipairs({ -1, 1 }) do
		-- V8: a gate amidships on each side opens onto the wing.
		part("Rail", Vector3.new(1, 4, 52), CFrame.new(side * (S.BEAM / 2 - 0.5), 3, -32), DARK_WOOD)
		part("Rail", Vector3.new(1, 4, 52), CFrame.new(side * (S.BEAM / 2 - 0.5), 3, 32), DARK_WOOD)
		for _, z in ipairs({ -6, 6 }) do
			part(
				"GatePost",
				Vector3.new(1.6, 7, 1.6),
				CFrame.new(side * (S.BEAM / 2 - 0.5), 4.5, z),
				TRIM,
				Enum.Material.Metal
			)
		end
		part(
			"RailBow",
			Vector3.new(1, 4, 26),
			CFrame.new(side * 7, 3, -76) * CFrame.Angles(0, side * math.rad(-24), 0),
			DARK_WOOD
		)
	end
	-- Three masts, their yards and sails; a figurehead.
	for i, z in ipairs({ -42, -4, 40 }) do
		local height = i == 2 and 96 or 78
		local mast = part(
			"Mast" .. i,
			Vector3.new(height, 3.2, 3.2),
			CFrame.new(0, 1 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			DARK_WOOD,
			nil,
			false,
			"Part"
		)
		mast.Shape = Enum.PartType.Cylinder
		local yard =
			part("Yard" .. i, Vector3.new(S.BEAM * 1.5, 1.8, 1.8), CFrame.new(0, height - 6, z), DARK_WOOD, nil, false)
		yard.Shape = Enum.PartType.Cylinder
		yard.CFrame = shipCFrame * CFrame.new(0, height - 6, z) * CFrame.Angles(0, 0, 0)
		local sail = part(
			"Sail" .. i,
			Vector3.new(S.BEAM * 1.3, height * 0.5, 0.8),
			CFrame.new(0, height * 0.52, z - 0.8),
			SAIL,
			Enum.Material.Fabric,
			false
		)
		sail.Transparency = 0.04
		local emblem = part(
			"Emblem" .. i,
			Vector3.new(0.9, 11, 11),
			CFrame.new(0, height * 0.52, z - 1.4),
			Color3.fromRGB(30, 30, 38),
			Enum.Material.Fabric,
			false
		)
		emblem.Shape = Enum.PartType.Cylinder
		emblem.CFrame = shipCFrame * CFrame.new(0, height * 0.52, z - 1.4) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- Wings and lift. V8: the wings are DECK. Each one is a broad canvas-and-spar platform level with
	-- the main deck at the gate and rising a little toward its tip, where a diving board sticks out
	-- over nothing. Walk out, look down at the whole sea, and step off (a free dive) or go back for a
	-- cannon. Nothing rails them in: falling off a wing is a way off the ship, not an accident.
	local WING_SPAN, WING_RISE = 40, math.rad(8)
	for _, side in ipairs({ -1, 1 }) do
		local lift = CFrame.Angles(0, 0, side * WING_RISE)
		local midX = side * (S.BEAM / 2 + WING_SPAN / 2 * math.cos(WING_RISE))
		local midY = 0.4 + WING_SPAN / 2 * math.sin(WING_RISE)
		local wing =
			part("Wing", Vector3.new(WING_SPAN, 1.2, 64), CFrame.new(midX, midY, 2) * lift, SAIL, Enum.Material.Fabric)
		wing.Transparency = 0.05
		for _, z in ipairs({ -30, -9, 13, 34 }) do
			part(
				"WingSpar",
				Vector3.new(WING_SPAN + 2, 1.6, 2),
				CFrame.new(midX, midY - 0.2, z) * lift,
				TRIM,
				Enum.Material.Metal
			)
		end
		-- The walkway from the gate to the tip, in planks, and the board beyond it.
		part(
			"WingWalk",
			Vector3.new(WING_SPAN, 0.5, 9),
			CFrame.new(midX, midY + 0.75, 0) * lift,
			WOOD,
			Enum.Material.WoodPlanks
		)
		local tipX = side * (S.BEAM / 2 + WING_SPAN * math.cos(WING_RISE))
		local tipY = 0.4 + WING_SPAN * math.sin(WING_RISE)
		part(
			"DivingBoard",
			Vector3.new(16, 0.8, 5),
			CFrame.new(tipX + side * 7, tipY + 0.9, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		local lantern = part(
			"WingLantern",
			Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(tipX + side * 14.5, tipY + 2.6, 0),
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon,
			false
		)
		lantern.Shape = Enum.PartType.Ball
	end
	local glow = part(
		"Belly",
		Vector3.new(26, 4, 70),
		CFrame.new(0, -15.5, 4),
		Color3.fromRGB(120, 230, 255),
		Enum.Material.Neon,
		false
	)
	glow.Transparency = 0.25
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 26) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.Rate = 14
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = glow
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(150, 235, 255)
	lamp.Range = 40
	lamp.Brightness = 2
	lamp.Parent = glow

	-- Cannons: six a side, set into the rails.
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -50, -30, -10, 10, 30, 50 }) do
			index += 1
			buildCannon(index, side * (S.BEAM / 2 - 5), z, side)
		end
	end
	-- A sign, the way it is in a game: what this is.
	local sign = part("Sign", Vector3.new(26, 7, 1), CFrame.new(0, 12, 86), DARK_WOOD, Enum.Material.WoodPlanks, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "THE GOLDEN GOBLIN"
	label.TextColor3 = TRIM
	label.TextScaled = true
	label.Parent = gui

	dressShip()
	buildWardrobe()

	-- Where goblins stand when they arrive: a loose grid on the main deck.
	for row = 0, 5 do
		for col = 0, 5 do
			table.insert(deckSpawns, shipCFrame * CFrame.new(-10 + col * 4, 4.4, -22 + row * 7))
		end
	end
	model.PrimaryPart = model:FindFirstChild("Deck")
	model.Parent = landmarks
	-- Everything on the ship is in the Landmarks folder, which streams as persistent, so it is in
	-- view from the first frame wherever the goblin is.
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
			p.CollisionGroup = HULL_GROUP
		end
	end
	for _, c in ipairs(cannons) do
		c.barrel.CastShadow = true
	end
	findLandings(worldRefs)
end

-- Goblins ---------------------------------------------------------------------------------------
-- Put a goblin on the deck. `since` (optional) keeps the time of the first attempt when this is a retry.
function Skyship.board(player, since)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return
	end
	Flight.forget(player)
	Poltergoblin.finish(player, "cancel")
	local seat = humanoid.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	local i = (#Players:GetPlayers() > 0 and (player.UserId % #deckSpawns) or 0) + 1
	local spot = deckSpawns[i]
	-- Spread: find a spot nobody is standing on.
	for step = 0, #deckSpawns - 1 do
		local candidate = deckSpawns[(i + step - 1) % #deckSpawns + 1]
		local taken = false
		for other, entry in pairs(aboard) do
			if other ~= player and entry.spot == candidate then
				taken = true
				break
			end
		end
		if not taken then
			spot = candidate
			break
		end
	end
	-- boardedAt: a goblin who was at a boat's wheel a moment ago is still held in that seat on their own
	-- client, and the move to the deck can be undone by it (a test saw one put aboard, snap back to the sea
	-- and "dive" into the seabed). The tick below puts them aboard again until it takes.
	aboard[player] = { spot = spot, boardedAt = since or now() }
	-- V12: a goblin who arrives late in the window (a join, a respawn) still gets MIN_DECK seconds on the deck.
	local by = math.max(endsAt, (since or now()) + S.MIN_DECK)
	player:SetAttribute("LaunchBy", workspace:GetAttribute("RaidPhase") == "raid" and endsAt > 0 and by or nil)
	root.Anchored = false
	humanoid.PlatformStand = false
	root.CFrame = spot * CFrame.Angles(0, math.rad(180), 0)
	root.AssemblyLinearVelocity = Vector3.zero
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", "aboard")
end

-- `keepAboard` (V9, at the raid's start): leave goblins who are already on the ship where they are (one may
-- be sitting in a cannon, aimed and waiting for the bell).
function Skyship.boardAll(keepAboard)
	for _, player in ipairs(Players:GetPlayers()) do
		if not (keepAboard and aboard[player]) then
			Skyship.board(player)
		end
	end
end

local function boardingTime()
	return workspace:GetAttribute("RaidPhase") == "intermission" or now() < endsAt
end

-- V11: is this goblin the ship's business (on the deck or in a cannon)? Pets may be changed aboard.
function Skyship.isAboard(player)
	return aboard[player] ~= nil
end

function Skyship.isDeploying()
	return now() < endsAt
end

-- A character just spawned (first load, or a respawn): aboard if the ship is still in port.
function Skyship.onCharacter(player)
	Flight.forget(player)
	aboard[player] = nil
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", nil)
	if boardingTime() and model then
		task.defer(function()
			if player.Parent then
				Skyship.board(player)
			end
		end)
	end
end

function Skyship.forget(player)
	Flight.forget(player)
	aboard[player] = nil
	chosen[player] = nil
end

-- The raid clock has started: unlock the cannons and open the window.
function Skyship.open()
	local t = now()
	opensAt = t + S.COUNTDOWN
	endsAt = t + S.WINDOW
	workspace:SetAttribute("DeployOpensAt", opensAt)
	workspace:SetAttribute("DeployEndsAt", endsAt)
	boardedFor += 1
	for player in pairs(aboard) do
		player:SetAttribute("LaunchBy", endsAt)
	end
	Net.broadcast("DeployOpen", { opensAt = opensAt, endsAt = endsAt })
end

function Skyship.reset()
	Flight.reset()
	for player in pairs(aboard) do
		player:SetAttribute("LaunchBy", nil)
	end
	table.clear(aboard)
	opensAt, endsAt = 0, 0
	workspace:SetAttribute("DeployOpensAt", nil)
	workspace:SetAttribute("DeployEndsAt", nil)
end

-- V9: during the intermission the bell's time is already known, so a goblin can climb in, aim, and watch the
-- countdown to it.
function Skyship.preopen(at)
	opensAt = at
	workspace:SetAttribute("DeployOpensAt", at)
end

-- The island a goblin picked on the map is where the ship fires them if they are still aboard at the end, and
-- where their cannon points when they climb in (they can look anywhere from there): Skyship.landingFor.
local function defaultDestination()
	local pool = {}
	for id, info in pairs(Config.ISLAND_INFO) do
		if info.major and info.tier <= 2 then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool[math.random(#pool)] or "Cross"
end

function Skyship.choose(player, id)
	if typeof(id) ~= "string" or not Config.ISLAND_INFO[id] or not Archipelago.byId[id] then
		return
	end
	chosen[player] = id
	player:SetAttribute("DeployDest", id)
end

-- Each frame ---------------------------------------------------------------------------------------------
function Skyship.tick(_dt)
	if not model then
		return
	end
	local t = now()
	local raiding = endsAt > 0 and workspace:GetAttribute("RaidPhase") == "raid"
	for player, entry in pairs(aboard) do
		-- V12: each goblin's own deadline: the window, or MIN_DECK after they came aboard if that is later.
		local windowOver = raiding and t >= math.max(endsAt, entry.boardedAt + S.MIN_DECK)
		local root = Util.aliveRoot(player)
		local phase = Flight.phaseOf(player)
		if not root or not player.Parent or phase == "diving" or phase == "embedded" then
			aboard[player] = nil -- gone, or thrown: the flight has them now
		elseif phase == "loaded" then
			if windowOver then
				Flight.fire(player)
			end
		elseif phase == nil then
			local onShip = shipCFrame:PointToObjectSpace(root.Position)
			if onShip.Y < -9 and t - entry.boardedAt < 2 then
				-- Only just put aboard and already far below: the move did not take (see Skyship.board). Again.
				Skyship.board(player, entry.boardedAt)
			elseif onShip.Y < -9 and t >= opensAt then
				-- Over the side, or off the end of a wing: a free dive from where they are.
				aboard[player] = nil
				Flight.launch(player, root.AssemblyLinearVelocity, nil)
			elseif onShip.Y < -40 then
				-- before the cannons unlock: put them back (nobody falls off before the bell)
				Skyship.board(player)
			elseif windowOver and entry.autoFor ~= boardedFor then
				-- The window is over: the ship fires the straggler at their island from where they stand.
				entry.autoFor = boardedFor
				local id = chosen[player] or player:GetAttribute("DeployDest") or defaultDestination()
				local target = Skyship.landingFor(id) or Vector3.new(0, 0, 380)
				aboard[player] = nil
				Flight.launch(player, (Dive.solve(root.Position, target, D.CANNON_ELEVATION, D.CANNON_SPEED)), nil)
				Net.toast(player, "The ship fires you off at " .. Archipelago.byId[id].name .. "!")
			end
		end
	end
	-- the window is over for everybody: tidy the attribute so the HUD can let go of it
	if raiding and t >= endsAt + 1 and workspace:GetAttribute("DeployEndsAt") then
		if next(aboard) == nil then
			workspace:SetAttribute("DeployEndsAt", nil)
			workspace:SetAttribute("DeployOpensAt", nil)
		end
	end
end

function Skyship.model()
	return model
end

function Skyship.cannonCount()
	return #cannons
end

-- For tests: the cannon table.
function Skyship.cannonAt(index)
	return cannons[index]
end

return Skyship

-- Builds the whole map at runtime from Terrain and parts. The repository stays
-- the only source of truth; Edit mode shows an empty sky until Play.
--
-- Layout (north is -Z). The big islands sit about 700 studs apart across open
-- sea, so boats are the way to travel and every escape is a real journey.
--
--                          SUN TEMPLE (mesa, idol, guardian)
--                                 \ zipline
--                                  \            TWIN STACKS
--   SHIPWRECK SHOALS        CROSSROADS RUINS     (islet)       CRYSTAL ISLE
--   (atoll, galleon, chest) (acropolis, lighthouse lens)       (spire, heart)
--                 GULL ROCK                    SMUGGLER'S COVE
--                 (islet) \ zipline             (islet)
--                          GOBLIN COVE (spawn, the Hoard, 4 boats)
--
-- Every island has a dock with a boat. Gameplay modules only use the
-- references returned in World.refs.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local World = {}

local SEA_Y = 0
local HOME = Vector3.new(0, 6, 650)
local HOARD = Vector3.new(0, 6.75, 730)
local CROSS = Vector3.new(0, 10, 0) -- The lower ruins.
local ACROPOLIS = Vector3.new(-20, 42, -20) -- The raised plateau in the middle of the ruins.
local ACROPOLIS_R = 80
local LIGHTHOUSE = Vector3.new(30, 42, -70)
local TEMPLE = Vector3.new(0, 8, -720) -- The jungle around the mesa.
local MESA_Y = 56
local MESA_R = 115
local ZIGGURAT = Vector3.new(0, MESA_Y, -740)
local CRYSTAL = Vector3.new(720, 0, -40)
local SHOALS = Vector3.new(-700, 0, 20)
local GULL_ROCK = Vector3.new(-360, 0, 400)
local SMUGGLER = Vector3.new(380, 4, 380)
local TWIN_STACK = Vector3.new(370, 48, -320) -- The taller stack's top.

local STONE = Color3.fromRGB(150, 145, 140)
local DARK_STONE = Color3.fromRGB(85, 80, 90)
local SANDSTONE = Color3.fromRGB(226, 190, 122)
local WOOD = Color3.fromRGB(120, 80, 48)
local DARK_WOOD = Color3.fromRGB(78, 52, 34)
local GOLD = Color3.fromRGB(255, 200, 40)
local WARD_COLOR = Color3.fromRGB(190, 110, 255)
local CRYSTAL_COLORS = { Color3.fromRGB(215, 110, 255), Color3.fromRGB(110, 230, 255) }
local CAVE_GLOW = Color3.fromRGB(120, 255, 200)

local Kit = require(script.Parent.WorldKit)
local Sea = require(script.Parent.Sea)
local Islands = require(script.Parent.Islands)
local IslandsFar = require(script.Parent.IslandsFar)
local terrain = Kit.terrain
local folders = Kit.folders
local refs = Kit.refs
World.refs = refs

-- Helpers live in WorldKit.lua; alias the ones this file uses.
local folder = Kit.folder
local ground = Kit.ground
local structure = Kit.structure
local decor = Kit.decor
local neon = Kit.neon
local cylinder = Kit.cylinder
local plank = Kit.plank
local flatDirection = Kit.flatDirection
local compass = Kit.compass
local ladder = Kit.ladder
local fillColumn = Kit.fillColumn
local island = Kit.island
local mesa = Kit.mesa
local cliffRamp = Kit.cliffRamp
local tunnel = Kit.tunnel
local groundY = Kit.groundY
local palm = Kit.palm
local palmRing = Kit.palmRing
local rockPile = Kit.rockPile
local pointLight = Kit.pointLight
local brazier = Kit.brazier
local glow = Kit.glow
local skyBeam = Kit.skyBeam
local sign = Kit.sign
local islandSign = Kit.islandSign
local totem = Kit.totem
local dock = Kit.dock
local ropeBridge = Kit.ropeBridge
local deck = Kit.deck

-- Ocean, sky and lighting -------------------------------------------------------
local function buildEnvironment()
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(35, 150, 185)
	terrain.WaterTransparency = 0.45
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.6
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 186, 78))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(238, 216, 160))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 120, 118))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(72, 60, 96))

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.GlobalShadows = true
	-- Thin enough haze that the next island is a silhouette on the horizon.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.13
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 222, 255)
	atmosphere.Decay = Color3.fromRGB(110, 140, 180)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	local midX, midZ = (min.X + max.X) / 2, (min.Z + max.Z) / 2
	local spanX, spanZ = max.X - min.X, max.Z - min.Z

	-- Sea floor. The water itself is poured in last, into every gap below sea level.
	terrain:FillBlock(CFrame.new(midX, -34, midZ), Vector3.new(spanX + 80, 12, spanZ + 80), Enum.Material.Sand)

	-- Invisible walls keep swimmers, boats and thrown loot inside the map. A part can't
	-- pass 2048 studs, so long walls are several parts.
	local function wall(size, center)
		local p = Util.part("BoundaryWall", size, CFrame.new(center), Color3.new(1, 1, 1), nil, folders.structures)
		p.Transparency = 1
		p.CanQuery = false
	end
	local function segments(length)
		local count = math.ceil(length / 2000)
		return count, length / count
	end
	local countZ, pieceZ = segments(spanZ)
	for i = 0, countZ - 1 do
		local z = min.Z + pieceZ * (i + 0.5)
		wall(Vector3.new(4, 800, pieceZ + 2), Vector3.new(min.X, 300, z))
		wall(Vector3.new(4, 800, pieceZ + 2), Vector3.new(max.X, 300, z))
	end
	local countX, pieceX = segments(spanX)
	for i = 0, countX - 1 do
		local x = min.X + pieceX * (i + 0.5)
		wall(Vector3.new(pieceX + 2, 800, 4), Vector3.new(x, 300, min.Z))
		wall(Vector3.new(pieceX + 2, 800, 4), Vector3.new(x, 300, max.Z))
	end

	-- The far sea: flat slabs around the playable map so the horizon is water, not sky.
	-- (Only outside the walls; inside, the real Terrain water shows the sea floor.)
	local reach = 4096
	local tile = 2048
	local function slab(cx, cz, sx, sz)
		local p = Util.part(
			"FarSea",
			Vector3.new(sx, 1, sz),
			CFrame.new(cx, -0.9, cz),
			Color3.fromRGB(52, 150, 188),
			Enum.Material.SmoothPlastic,
			folders.decor
		)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Reflectance = 0.12
	end
	local function strip(x0, x1, z0, z1)
		local nx, ny = math.ceil((x1 - x0) / tile), math.ceil((z1 - z0) / tile)
		local w, h = (x1 - x0) / nx, (z1 - z0) / ny
		for i = 0, nx - 1 do
			for j = 0, ny - 1 do
				slab(x0 + w * (i + 0.5), z0 + h * (j + 0.5), w, h)
			end
		end
	end
	strip(min.X - reach, min.X, min.Z - reach, max.Z + reach)
	strip(max.X, max.X + reach, min.Z - reach, max.Z + reach)
	strip(min.X, max.X, min.Z - reach, min.Z)
	strip(min.X, max.X, max.Z, max.Z + reach)
end

local function pourSea()
	-- In tiles: one huge ReplaceMaterial region could pass the engine's size limit.
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	local tile = 512
	for x = min.X - 40, max.X + 40, tile do
		for z = min.Z - 40, max.Z + 40, tile do
			local region = Region3.new(Vector3.new(x, -28, z), Vector3.new(x + tile, SEA_Y, z + tile)):ExpandToGrid(4)
			terrain:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
		end
	end
end

-- Home is a playground: nothing to unlock, just things to bounce on, shoot at and launch off while you
-- wait for friends or plan the next run. None of it can hurt anyone.
local function buildHomeToys()
	-- Bounce pads: a quick way up onto the hideout hill and a way to learn the launch feel.
	for _, spot in ipairs({ { -40, 590 }, { 40, 590 }, { -112, 650 }, { 112, 650 } }) do
		World.launchPad(Vector3.new(spot[1], 6.4, spot[2]), Vector3.new(0, 100, 0))
	end

	-- The practice range: a free cannon on the north-west shore and rafts to hit in the cove. Hold E
	-- to fire where you aim. (Cannonballs are real, so don't point it at friends.)
	local cannonAt = Vector3.new(-85, 6.2, 530)
	ground(
		"PracticeStand",
		Vector3.new(12, 1, 12),
		CFrame.new(cannonAt + Vector3.new(0, -0.3, 0)),
		STONE,
		Enum.Material.Cobblestone
	)
	Kit.cannon(cannonAt + Vector3.new(0, 0.2, 0), Vector3.new(-85, 0, 300), "Practice cannon")
	local board = structure(
		"PracticeSign",
		Vector3.new(0.6, 5, 9),
		CFrame.new(cannonAt + Vector3.new(-7, 2.5, 4)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	sign(board, "TARGET PRACTICE: E to fire", GOLD, Vector3.new(0, 5, 0), 180)
	refs.targets = {}
	for _, spot in ipairs({ { -85, 430 }, { -48, 392 }, { -125, 398 } }) do
		local raft = structure(
			"TargetRaft",
			Vector3.new(11, 1, 11),
			CFrame.new(spot[1], 0.4, spot[2]),
			WOOD,
			Enum.Material.WoodPlanks
		)
		table.insert(refs.targets, raft)
		local face = CFrame.new(spot[1], 6.4, spot[2]) * CFrame.Angles(0, 0, math.rad(90))
		for i, color in ipairs({
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(220, 50, 50),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(220, 50, 50),
		}) do
			local ring = decor(
				"Bullseye",
				Vector3.new(0.3 + i * 0.05, 10 - i * 2.3, 10 - i * 2.3),
				face * CFrame.new(0, -i * 0.04, 0),
				color,
				Enum.Material.SmoothPlastic,
				true
			)
			ring.Shape = Enum.PartType.Cylinder
		end
		structure(
			"TargetPost",
			Vector3.new(0.8, 6, 0.8),
			CFrame.new(spot[1], 3.4, spot[2] + 0.3),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end

	-- Kegs and a couple of barrels by the docks.
	table.insert(refs.kegCrates, Kit.kegCrate(Vector3.new(-52, 6, 522)))
	table.insert(refs.kegCrates, Kit.kegCrate(Vector3.new(52, 6, 522)))
	table.insert(refs.barrels, Kit.barrel(Vector3.new(-100, 6, 538)))
	table.insert(refs.barrels, Kit.barrel(Vector3.new(-96, 6, 543)))

	-- The harbor jump: a ramp in the channel between the docks. Hit it at speed.
	-- The ramp starts below the hull's keel so a boat rides up it instead of hitting its edge.
	local rampFoot, rampTop = Vector3.new(0, -3.2, 424), Vector3.new(0, 5.4, 388)
	plank(
		"HarborRamp",
		rampFoot,
		rampTop,
		16,
		2,
		Color3.fromRGB(255, 170, 90),
		Enum.Material.Slate,
		folders.structures,
		4
	)
	table.insert(
		refs.boostGates,
		{ position = Vector3.new(0, 2, 404), radius = 12, kind = "kick", direction = Vector3.new(0, 0, -1) }
	)
	neon(decor("JumpArrow", Vector3.new(10, 0.3, 2.4), CFrame.new(0, 5.8, 392), Color3.fromRGB(255, 220, 90)))
	local jump = decor("JumpSign", Vector3.new(1, 1, 1), CFrame.new(0, 14, 400), Color3.new(1, 1, 1), nil)
	jump.Transparency = 1
	sign(jump, "HARBOR JUMP: go fast!", Color3.fromRGB(255, 220, 90), Vector3.zero, 260)
end

-- Goblin Cove (home) ---------------------------------------------------------------
local function buildHome()
	island(HOME, 175, 160, Enum.Material.Rock, Enum.Material.Grass)
	-- The hideout hill behind the Hoard. Round hills are walkable all the way up.
	terrain:FillBall(Vector3.new(0, 0, 792), 46, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-48, -4, 772), 30, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(50, -6, 770), 28, Enum.Material.Rock)

	-- The Hoard: carry loot into the gold ring to bank it.
	local dais = cylinder(
		"Hoard",
		12,
		1,
		HOARD - Vector3.new(0, 0.5, 0),
		Color3.fromRGB(120, 90, 40),
		Enum.Material.Cobblestone,
		folders.ground
	)
	local ring = cylinder(
		"HoardRing",
		Config.BANK_RADIUS,
		0.2,
		HOARD + Vector3.new(0, 0.1, 0),
		GOLD,
		Enum.Material.Neon,
		folders.decor
	)
	ring.Transparency = 0.6
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	for i = 1, 14 do
		local angle = i * 2.4
		local r = 2 + (i % 5) * 1.1
		local size = 1.2 + (i % 4) * 0.7
		local ball = decor(
			"HoardGold",
			Vector3.new(size, size, size),
			CFrame.new(HOARD + Vector3.new(math.cos(angle) * r, size / 2, 6 + math.sin(angle) * r * 0.6)),
			GOLD,
			Enum.Material.Metal
		)
		ball.Shape = Enum.PartType.Ball
	end
	pointLight(dais, GOLD, 30, 2)
	sign(dais, "THE HOARD", GOLD, Vector3.new(0, 12, 6), 400)
	skyBeam("HoardBeacon", HOARD, GOLD, 6)
	refs.hoard = { position = HOARD, part = dais }
	-- With streaming on, far parts come and go; this invisible persistent marker keeps the Hoard's
	-- position (and the waypoint over it) available to every client at any distance.
	local marker = Instance.new("Model")
	marker.Name = "HoardMarker"
	marker.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local anchor = Util.part("Hoard", Vector3.new(1, 1, 1), CFrame.new(HOARD), GOLD, nil, marker)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	marker.PrimaryPart = anchor
	marker.Parent = folders.landmarks

	-- The hideout door and eyes, so the hill reads as home.
	decor("HideoutDoor", Vector3.new(8, 10, 1), CFrame.new(0, 10, 747), DARK_WOOD, Enum.Material.WoodPlanks, true)
	for _, x in ipairs({ -6, 6 }) do
		neon(decor("HideoutEye", Vector3.new(3, 2, 1), CFrame.new(x, 24, 752.5), Color3.fromRGB(120, 255, 90)))
	end

	-- A lookout on the hilltop with a crow's nest: scout the light pillars from home.
	local top = Vector3.new(0, 46, 792)
	deck("Lookout", top, 14)
	structure(
		"LookoutMast",
		Vector3.new(1.5, 22, 1.5),
		CFrame.new(top + Vector3.new(0, 12, 0)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	deck("CrowsNest", top + Vector3.new(0, 21.5, 0), 8)
	ladder("LookoutLadder", top + Vector3.new(0, 1, 5), 22)

	-- The ward: no Poltergoblin and no Guardian inside this ring.
	local segments = 48
	for i = 1, segments do
		local a0 = (i - 1) / segments * math.pi * 2
		local a1 = i / segments * math.pi * 2
		local p0 = HOARD + Vector3.new(math.cos(a0), 0, math.sin(a0)) * Config.WARD_RADIUS
		local p1 = HOARD + Vector3.new(math.cos(a1), 0, math.sin(a1)) * Config.WARD_RADIUS
		local mid = (p0 + p1) / 2
		local y = groundY(mid.X, mid.Z, HOARD.Y) + 0.15
		local seg = decor(
			"WardRing",
			Vector3.new(0.8, 0.3, (p1 - p0).Magnitude),
			CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(p1.X, y, p1.Z)),
			WARD_COLOR,
			Enum.Material.Neon
		)
		seg.Transparency = 0.35
	end

	-- Spawn. A short force field stops instant spawn kills, not carrying.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HomeSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 6.6, 690)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Color = Color3.fromRGB(230, 230, 230)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = folders.ground
	refs.spawn = spawn
	refs.homePoints = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		table.insert(refs.homePoints, CFrame.new(math.cos(a) * 9, 10, 690 + math.sin(a) * 9))
	end

	-- Two docks on the north shore, four boats: one each, plus a spare to fight over.
	for _, x in ipairs({ -30, 30 }) do
		dock(Vector3.new(x, 0, 490), Vector3.new(x, 0, 428), { -1, 1 })
	end

	-- Goblin huts for cover and character.
	local huts = {
		{ -70, 640, 20 },
		{ 70, 628, -25 },
		{ -60, 580, 60 },
		{ 66, 700, 10 },
		{ -96, 700, -10 },
		{ 100, 590, 30 },
	}
	for _, h in ipairs(huts) do
		local base = CFrame.new(h[1], 6, h[2]) * CFrame.Angles(0, math.rad(h[3]), 0)
		structure(
			"Hut",
			Vector3.new(12, 9, 12),
			base * CFrame.new(0, 4.5, 0),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.WoodPlanks
		)
		structure(
			"HutRoof",
			Vector3.new(15, 1.5, 15),
			base * CFrame.new(0, 9.75, 0),
			Color3.fromRGB(170, 60, 50),
			Enum.Material.Fabric
		)
		decor("HutDoor", Vector3.new(4, 6, 0.4), base * CFrame.new(0, 3, -6.1), DARK_WOOD, Enum.Material.Wood)
	end
	palmRing(HOME, 128, 14, 200, { Vector3.new(-30, 0, 500), Vector3.new(30, 0, 500), Vector3.new(-115, 0, 612) })
	buildHomeToys()
end

-- Crossroads Ruins: lower town, the acropolis above it, the Lighthouse ----------------
local function buildCrossroads()
	island(CROSS, 195, 180, Enum.Material.Rock, Enum.Material.Grass)
	mesa(ACROPOLIS, ACROPOLIS_R, 4, ACROPOLIS.Y, Enum.Material.Rock, Enum.Material.Grass)
	islandSign(ACROPOLIS + Vector3.new(0, 40, 0), "CROSSROADS RUINS")

	-- Grand stairs up the south cliff of the acropolis.
	local stairFoot = Vector3.new(ACROPOLIS.X, CROSS.Y, 131)
	local stairTop = Vector3.new(ACROPOLIS.X, ACROPOLIS.Y, ACROPOLIS.Z + ACROPOLIS_R + 1)
	plank("GrandStairs", stairFoot, stairTop, 16, 2, STONE, Enum.Material.Cobblestone, folders.ground, 4)
	local stairDirection = (stairTop - stairFoot).Unit
	for i = 1, 17 do
		local p = stairFoot:Lerp(stairTop, i / 18)
		decor(
			"StairStripe",
			Vector3.new(16, 0.1, 0.6),
			CFrame.lookAt(p, p + stairDirection) * CFrame.new(0, 0.06, 0),
			DARK_STONE,
			Enum.Material.Cobblestone
		)
	end
	-- A rock ramp around the east side, and a launch pad at the foot of the west cliff.
	cliffRamp(ACROPOLIS, ACROPOLIS_R, 330, CROSS.Y, ACROPOLIS.Y, 72, -1, 12)
	World.launchPad(Vector3.new(ACROPOLIS.X - ACROPOLIS_R - 8, CROSS.Y + 0.2, ACROPOLIS.Z + 10), Vector3.new(0, 128, 0))

	-- The undercroft: a tunnel right through the acropolis, with a ladder shaft up into it.
	tunnel(Vector3.new(ACROPOLIS.X, CROSS.Y, 75), Vector3.new(ACROPOLIS.X, CROSS.Y, -115), 12, 11)
	terrain:FillCylinder(CFrame.new(ACROPOLIS.X, 31, 20), 26, 4, Enum.Material.Air)
	ladder("UndercroftLadder", Vector3.new(ACROPOLIS.X + 2.9, CROSS.Y, 20), 34)
	for _, z in ipairs({ 50, 10, -30, -70 }) do
		glow(Vector3.new(ACROPOLIS.X - 5.6, CROSS.Y + 5, z), CAVE_GLOW, 18)
	end

	-- The acropolis: a plaza ringed by columns, some broken.
	cylinder("Plaza", 16, 0.6, ACROPOLIS + Vector3.new(0, 0.2, 0), STONE, Enum.Material.Cobblestone, folders.ground)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		local pos = ACROPOLIS + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)
		local height = (i % 3 == 0) and 7 or 18
		if i == 6 then
			local fallen = cylinder(
				"FallenColumn",
				1.8,
				18,
				pos + Vector3.new(0, 1.8, 0),
				STONE,
				Enum.Material.Marble,
				folders.structures
			)
			fallen.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, a, 0)
		else
			cylinder(
				"Column",
				1.8,
				height,
				pos + Vector3.new(0, height / 2, 0),
				STONE,
				Enum.Material.Marble,
				folders.structures
			)
		end
	end

	-- Broken walls on both levels: cover from grapples and totems.
	local walls = {
		-- x, z, width, height, depth, yaw, base y
		{ 40, 70, 2, 10, 22, 0, CROSS.Y },
		{ -70, 95, 18, 8, 2, 0, CROSS.Y },
		{ 60, 135, 16, 12, 2, 20, CROSS.Y },
		{ 20, 150, 14, 6, 2, 0, CROSS.Y },
		{ 110, 40, 2, 9, 16, 0, CROSS.Y },
		{ -110, -60, 2, 14, 12, -15, CROSS.Y },
		{ 90, -90, 12, 7, 2, 35, CROSS.Y },
		{ -60, -50, 14, 8, 2, 10, ACROPOLIS.Y },
		{ 10, 20, 2, 10, 14, 0, ACROPOLIS.Y },
		{ -70, 10, 2, 7, 12, 25, ACROPOLIS.Y },
	}
	for _, w in ipairs(walls) do
		local cf = CFrame.new(w[1], w[7] + w[4] / 2 - 0.5, w[2]) * CFrame.Angles(0, math.rad(w[6]), 0)
		structure("RuinWall", Vector3.new(w[3], w[4], w[5]), cf, STONE, Enum.Material.Brick)
		structure(
			"RuinTop",
			Vector3.new(math.max(w[3] * 0.5, 2), 2, math.max(w[5] * 0.5, 2)),
			cf * CFrame.new(w[3] * 0.15, w[4] / 2 + 0.6, 0),
			STONE,
			Enum.Material.Brick
		)
	end

	-- A broken aqueduct: a narrow high walkway from the west knoll up to the acropolis rim.
	local aqueductOut = compass(200)
	local knoll = Vector3.new(ACROPOLIS.X, 0, ACROPOLIS.Z) + aqueductOut * 128
	terrain:FillBall(Vector3.new(knoll.X, 6, knoll.Z), 24, Enum.Material.Rock)
	local aqueductLow = Vector3.new(knoll.X, 30, knoll.Z) - aqueductOut * 4
	local aqueductHigh = Vector3.new(ACROPOLIS.X, ACROPOLIS.Y, ACROPOLIS.Z) + aqueductOut * (ACROPOLIS_R - 2)
	plank("Aqueduct", aqueductLow, aqueductHigh, 6, 3, STONE, Enum.Material.Brick, folders.ground)
	for i = 1, 3 do
		local p = aqueductLow:Lerp(aqueductHigh, i / 4)
		structure(
			"AqueductArch",
			Vector3.new(5, p.Y - CROSS.Y - 3, 5),
			CFrame.new(p.X, (p.Y + CROSS.Y - 3) / 2, p.Z),
			STONE,
			Enum.Material.Brick
		)
	end

	-- The old harbor: roofless stone houses by the south dock, to duck into.
	for _, house in ipairs({ { 85, 105, 15 }, { 115, 70, -20 }, { -40, 160, 30 } }) do
		local base = CFrame.new(house[1], CROSS.Y, house[2]) * CFrame.Angles(0, math.rad(house[3]), 0)
		local houseWalls = {
			{ Vector3.new(16, 9, 1.5), CFrame.new(0, 4.5, -7.5) },
			{ Vector3.new(1.5, 9, 16), CFrame.new(-7.5, 4.5, 0) },
			{ Vector3.new(1.5, 6, 16), CFrame.new(7.5, 3, 0) },
			{ Vector3.new(5, 9, 1.5), CFrame.new(-5.5, 4.5, 7.5) },
			{ Vector3.new(5, 9, 1.5), CFrame.new(5.5, 4.5, 7.5) },
		}
		for _, w in ipairs(houseWalls) do
			structure("HouseWall", w[1], base * w[2], STONE, Enum.Material.Brick)
		end
	end

	-- East knoll with a ruined watchtower and a ladder.
	local eastKnoll = Vector3.new(130, 0, -10)
	terrain:FillBall(Vector3.new(eastKnoll.X, 2, eastKnoll.Z), 22, Enum.Material.Rock)
	ground(
		"Watchtower",
		Vector3.new(9, 22, 9),
		CFrame.new(eastKnoll.X, 24 + 11, eastKnoll.Z),
		STONE,
		Enum.Material.Brick
	)
	ladder("WatchtowerLadder", Vector3.new(eastKnoll.X - 5.5, 22, eastKnoll.Z), 26)

	-- Ruined tower on the lower west side: a sniper perch reached by a launch pad.
	local towerPos = Vector3.new(-120, CROSS.Y, 70)
	ground(
		"RuinTower",
		Vector3.new(10, 30, 10),
		CFrame.new(towerPos + Vector3.new(0, 15, 0)),
		STONE,
		Enum.Material.Brick
	)
	for _, offset in ipairs({
		Vector3.new(4, 0, 4),
		Vector3.new(-4, 0, 4),
		Vector3.new(4, 0, -4),
		Vector3.new(-4, 0, -4),
	}) do
		structure(
			"Merlon",
			Vector3.new(2, 2.5, 2),
			CFrame.new(towerPos + offset + Vector3.new(0, 31.25, 0)),
			STONE,
			Enum.Material.Brick
		)
	end
	World.launchPad(towerPos + Vector3.new(0, 0.2, 10.5), Vector3.new(0, 125, 0))

	-- Lighthouse on the acropolis rim: an exposed spiral climb to the Lens, high over the sea.
	local stripes = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(210, 50, 50) }
	local segments = 7
	for i = 0, segments - 1 do
		cylinder(
			"LighthouseTower",
			8,
			10,
			LIGHTHOUSE + Vector3.new(0, 5 + i * 10, 0),
			stripes[i % 2 + 1],
			Enum.Material.SmoothPlastic,
			folders.structures
		)
	end
	local topY = LIGHTHOUSE.Y + segments * 10 + 2
	cylinder(
		"LighthouseTop",
		9,
		2,
		Vector3.new(LIGHTHOUSE.X, topY - 1, LIGHTHOUSE.Z),
		STONE,
		Enum.Material.Concrete,
		folders.ground
	)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		structure(
			"LanternPost",
			Vector3.new(0.8, 8, 0.8),
			CFrame.new(LIGHTHOUSE.X + math.cos(a) * 7, topY + 4, LIGHTHOUSE.Z + math.sin(a) * 7),
			DARK_STONE,
			Enum.Material.Metal
		)
	end
	cylinder(
		"LanternRoof",
		9,
		1,
		Vector3.new(LIGHTHOUSE.X, topY + 8.5, LIGHTHOUSE.Z),
		stripes[2],
		Enum.Material.SmoothPlastic,
		folders.structures
	)
	local lamp = neon(
		decor(
			"Lamp",
			Vector3.new(3, 3, 3),
			CFrame.new(LIGHTHOUSE.X, topY + 10.5, LIGHTHOUSE.Z),
			Color3.fromRGB(255, 240, 160)
		)
	)
	lamp.Shape = Enum.PartType.Ball
	pointLight(lamp, Color3.fromRGB(255, 240, 160), 50, 2)
	refs.lighthouseLamp = lamp
	local bell = decor(
		"Bell",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(LIGHTHOUSE.X + 4, topY + 6.5, LIGHTHOUSE.Z),
		GOLD,
		Enum.Material.Metal
	)
	bell.Shape = Enum.PartType.Ball
	ground(
		"LensPedestal",
		Vector3.new(2.4, 2.5, 2.4),
		CFrame.new(LIGHTHOUSE.X, topY + 1.25, LIGHTHOUSE.Z),
		DARK_STONE,
		Enum.Material.Slate
	)
	refs.lootSpots.Lens = CFrame.new(LIGHTHOUSE.X, topY + 2.5 + 2.2, LIGHTHOUSE.Z)

	-- Spiral ramp: 4 turns from the acropolis (facing the plaza) to the top.
	local turns, perTurn, radius = 4, 24, 12
	local steps = turns * perTurn
	local startY, endY = LIGHTHOUSE.Y + 0.5, topY
	local function spiralPoint(i)
		local a = math.pi + i / perTurn * math.pi * 2
		local y = startY + (endY - startY) * i / steps
		return Vector3.new(LIGHTHOUSE.X + math.cos(a) * radius, y, LIGHTHOUSE.Z + math.sin(a) * radius)
	end
	for i = 0, steps - 1 do
		plank(
			"LighthouseRamp",
			spiralPoint(i),
			spiralPoint(i + 1),
			6,
			1,
			Color3.fromRGB(150, 110, 70),
			Enum.Material.WoodPlanks,
			folders.ground,
			0.6
		)
	end

	totem("LighthouseTotem", Vector3.new(5, ACROPOLIS.Y, -45), LIGHTHOUSE)
	totem("RuinsTotem", Vector3.new(75, CROSS.Y, 150), Vector3.new(40, CROSS.Y, 200))

	-- The temple zipline lands at a gate on the north rim.
	for _, x in ipairs({ -27, -13 }) do
		structure(
			"GatePillar",
			Vector3.new(3, 15, 3),
			CFrame.new(x, ACROPOLIS.Y + 7.5, -84),
			SANDSTONE,
			Enum.Material.Sandstone
		)
	end
	structure(
		"GateLintel",
		Vector3.new(17, 3, 3.4),
		CFrame.new(-20, ACROPOLIS.Y + 16.5, -84),
		SANDSTONE,
		Enum.Material.Sandstone
	)

	-- One boat waits at the south dock.
	dock(Vector3.new(40, 0, 182), Vector3.new(40, 0, 245), { 1 })

	palmRing(CROSS, 150, 16, 10, {
		Vector3.new(40, 0, 182),
		Vector3.new(-20, 0, 131),
		Vector3.new(-120, 0, 80),
		Vector3.new(-40, 0, 160),
		Vector3.new(85, 0, 105),
		Vector3.new(115, 0, 70),
		knoll,
		eastKnoll,
	})
	for _, p in ipairs({ { 30, 100, 4 }, { -90, 30, 6 }, { 100, -60, 5 }, { -40, 150, 5 } }) do
		rockPile(Vector3.new(p[1], CROSS.Y + p[3] / 3, p[2]), Vector3.new(p[3], p[3] * 0.8, p[3] * 1.2))
	end
end

-- Sun Temple (Golden Idol, Guardian) ------------------------------------------------
local function buildTemple()
	local c = TEMPLE
	island(c, 215, 200, Enum.Material.Rock, Enum.Material.Grass)
	-- The temple stands on a cliff-walled mesa high above the jungle.
	mesa(c, MESA_R, 0, MESA_Y, Enum.Material.Rock, Enum.Material.Grass)
	islandSign(Vector3.new(0, 130, -740), "SUN TEMPLE", Color3.fromRGB(255, 220, 120))

	-- Serpent Ridge hides the sea cave: a tunnel from the west waterline that
	-- climbs inside the mountain and comes out in the temple courtyard.
	for _, hill in ipairs({ { -252, 26 }, { -228, 28 }, { -202, 32 }, { -174, 40 }, { -140, 48 }, { -105, 52 } }) do
		terrain:FillBall(Vector3.new(hill[1], 0, -660), hill[2], Enum.Material.Rock)
	end
	terrain:FillBall(Vector3.new(-160, 16, -630), 26, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-125, 20, -690), 30, Enum.Material.Rock)
	tunnel(Vector3.new(-272, 1, -660), Vector3.new(-150, 1, -660), 12, 11)
	tunnel(Vector3.new(-152, 1, -660), Vector3.new(-40, MESA_Y, -660), 12, 11)
	for i, x in ipairs({ -240, -195, -150, -110, -75 }) do
		local floorY = x < -150 and 1 or 1 + (x + 152) / 112 * (MESA_Y - 1)
		glow(Vector3.new(x, floorY + 5, -660 + (i % 2 == 0 and 5.6 or -5.6)), CAVE_GLOW, 18)
	end

	-- The pilgrim ramp climbs the south cliff to the courtyard. The east cliff has ladders.
	cliffRamp(c, MESA_R, 90, c.Y, MESA_Y, 110, 1, 12)
	for _, z in ipairs({ -730, -712 }) do
		ladder("CliffLadder", Vector3.new(math.sqrt(MESA_R ^ 2 - (z - c.Z) ^ 2) + 1.3, c.Y, z), MESA_Y - c.Y + 2)
	end

	-- The ziggurat.
	local tiers = { { 80, 10 }, { 60, 10 }, { 42, 10 }, { 24, 8 } }
	local y = MESA_Y
	for i, tier in ipairs(tiers) do
		ground(
			"ZigguratTier" .. i,
			Vector3.new(tier[1], tier[2], tier[1]),
			CFrame.new(ZIGGURAT.X, y + tier[2] / 2, ZIGGURAT.Z),
			SANDSTONE,
			Enum.Material.Sandstone
		)
		y += tier[2]
	end
	local topY = y -- 94
	ground("Altar", Vector3.new(6, 2, 6), CFrame.new(ZIGGURAT.X, topY + 1, ZIGGURAT.Z), DARK_STONE, Enum.Material.Slate)
	refs.lootSpots.Idol = CFrame.new(ZIGGURAT.X, topY + 2 + 2.3, ZIGGURAT.Z)

	-- Grand stairs straight up the south face. The boulder rolls down these.
	local stairBottom = Vector3.new(0, MESA_Y + 0.2, ZIGGURAT.Z + 68)
	local stairTop = Vector3.new(0, topY, ZIGGURAT.Z + tiers[4][1] / 2)
	plank(
		"TempleStairs",
		stairBottom,
		stairTop,
		14,
		2,
		Color3.fromRGB(205, 170, 105),
		Enum.Material.Sandstone,
		folders.ground,
		2
	)
	local stairDirection = (stairTop - stairBottom).Unit
	for i = 1, 20 do
		local p = stairBottom:Lerp(stairTop, i / 21)
		local stripe = decor(
			"StairStripe",
			Vector3.new(14, 0.1, 0.5),
			CFrame.lookAt(p, p + stairDirection) * CFrame.new(0, 0.06, 0),
			Color3.fromRGB(150, 120, 75),
			Enum.Material.Sandstone
		)
		stripe.CanCollide = false
	end
	-- Just below the top of the stairs, so it misses the thief at the altar.
	refs.boulderStart = CFrame.new(0, topY, ZIGGURAT.Z + 22)
	refs.boulderDirection = Vector3.new(0, 0, 1)
	brazier(Vector3.new(-10, MESA_Y, ZIGGURAT.Z + 70))
	brazier(Vector3.new(10, MESA_Y, ZIGGURAT.Z + 70))

	-- Side climbs: one block per tier up the east and west faces (one jump each).
	for _, sideSign in ipairs({ 1, -1 }) do
		local base = MESA_Y
		for i, tier in ipairs(tiers) do
			local stepTop = base + tier[2] - 4.5
			if i > 1 then
				stepTop = base + tier[2] - 4
			end
			local x = (tier[1] / 2 + 3) * sideSign
			ground(
				"ClimbStep",
				Vector3.new(5, stepTop - base, 5),
				CFrame.new(x, (base + stepTop) / 2, ZIGGURAT.Z),
				Color3.fromRGB(190, 155, 95),
				Enum.Material.Sandstone
			)
			base += tier[2]
		end
	end

	-- The courtyard gate at the top of the pilgrim ramp.
	for _, x in ipairs({ -9, 9 }) do
		structure(
			"TempleGate",
			Vector3.new(3, 18, 3),
			CFrame.new(x, MESA_Y + 9, c.Z + MESA_R - 10),
			SANDSTONE,
			Enum.Material.Sandstone
		)
	end
	structure(
		"TempleGateLintel",
		Vector3.new(21, 3, 3.4),
		CFrame.new(0, MESA_Y + 19.5, c.Z + MESA_R - 10),
		SANDSTONE,
		Enum.Material.Sandstone
	)

	-- The Guardian sleeps on the north side of the mesa.
	local lair = Vector3.new(0, MESA_Y, -805)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		structure(
			"LairStone",
			Vector3.new(3, 9, 3),
			CFrame.new(lair + Vector3.new(math.cos(a) * 14, 4.5, math.sin(a) * 14)) * CFrame.Angles(0, a, 0.1),
			DARK_STONE,
			Enum.Material.Slate
		)
	end
	refs.guardianLair = CFrame.lookAt(lair, Vector3.new(ZIGGURAT.X, MESA_Y, ZIGGURAT.Z))
	refs.templeCenter = c

	totem("TempleTotemWest", Vector3.new(-32, MESA_Y, -668), Vector3.new(0, MESA_Y, -620))
	totem("TempleTotemEast", Vector3.new(32, MESA_Y, -668), Vector3.new(0, MESA_Y, -620))
	totem("JungleTotem", Vector3.new(130, c.Y, -578), Vector3.new(60, c.Y, -540))

	-- The Sun Spire on the south-east rim: a zipline all the way to the Crossroads.
	local spire = Vector3.new(75, MESA_Y, -655)
	local deckY = MESA_Y + 24
	deck("SpireDeck", Vector3.new(spire.X, deckY - 1, spire.Z), 12)
	for _, o in ipairs({
		Vector3.new(5.5, 0, 5.5),
		Vector3.new(-5.5, 0, 5.5),
		Vector3.new(5.5, 0, -5.5),
		Vector3.new(-5.5, 0, -5.5),
	}) do
		structure(
			"SpirePost",
			Vector3.new(1, deckY - MESA_Y, 1),
			CFrame.new(spire + o + Vector3.new(0, (deckY - MESA_Y) / 2, 0)),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	ladder("SpireLadder", spire + Vector3.new(-7, 0, 0), deckY - MESA_Y + 2)
	World.zipline(
		"TempleZipline",
		Vector3.new(spire.X, deckY + 7, spire.Z),
		Vector3.new(ACROPOLIS.X, ACROPOLIS.Y + 7, -92)
	)

	-- A waterfall down the north-east cliff, just for looks.
	local fallOut = compass(305)
	local fallTop = Vector3.new(c.X, MESA_Y, c.Z) + fallOut * (MESA_R + 0.6)
	local fall = decor(
		"Waterfall",
		Vector3.new(12, MESA_Y - c.Y, 1),
		CFrame.lookAt(
			fallTop - Vector3.new(0, (MESA_Y - c.Y) / 2, 0),
			fallTop - Vector3.new(0, (MESA_Y - c.Y) / 2, 0) + fallOut
		),
		Color3.fromRGB(150, 215, 255),
		Enum.Material.Glass
	)
	fall.Transparency = 0.35
	decor(
		"Stream",
		Vector3.new(8, 0.2, 40),
		CFrame.lookAt(fallTop - fallOut * 20 + Vector3.new(0, 0.1, 0), fallTop + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(110, 190, 240),
		Enum.Material.Glass
	).Transparency =
		0.3

	-- One boat waits at the south dock.
	dock(Vector3.new(25, 0, -512), Vector3.new(25, 0, -450), { 1 })

	palmRing(c, 165, 22, 0, {
		Vector3.new(25, 0, -512),
		Vector3.new(110, 0, -600),
		Vector3.new(55, 0, -600),
		Vector3.new(-200, 0, -660),
		Vector3.new(130, 0, -578),
		Vector3.new(118, 0, -721),
	})
	for _, p in ipairs({ { -150, -760 }, { 140, -680 }, { -60, -880 }, { 90, -860 } }) do
		structure(
			"JungleRuin",
			Vector3.new(4, 12, 4),
			CFrame.new(p[1], c.Y + 5, p[2]) * CFrame.Angles(0, p[1] % 2, 0.15),
			SANDSTONE,
			Enum.Material.Sandstone
		)
	end
end

-- Crystal Isle (Crystal Heart) --------------------------------------------------------
-- A terraced basalt spire. Ramps spiral up from shelf to shelf; a tunnel runs
-- through the base past the Heart's chamber; a launch shaft shoots up the middle.
local function buildCrystalIsle()
	local c = CRYSTAL
	fillColumn(c.X, c.Z, -30, 1.5, 175, Enum.Material.Sand)
	local shelves = { { 150, 20 }, { 110, 50 }, { 80, 85 }, { 50, 115 }, { 25, 135 } }
	for _, s in ipairs(shelves) do
		fillColumn(c.X, c.Z, -30, s[2], s[1], Enum.Material.Basalt)
	end
	islandSign(Vector3.new(c.X, 160, c.Z), "CRYSTAL ISLE", CRYSTAL_COLORS[1])

	-- Ramps from each shelf to the next, working round the spire.
	local ramps = {
		-- arrives at (degrees), from shelf y, cliff radius, to y, length
		{ 250, 1.5, 150, 20, 50 },
		{ 300, 20, 110, 50, 75 },
		{ 30, 50, 80, 85, 58 },
		{ 120, 85, 50, 115, 50 },
		{ 215, 115, 25, 135, 33 },
	}
	for _, r in ipairs(ramps) do
		cliffRamp(c, r[3], r[1], r[2], r[4], r[5], -1, r[3] < 60 and 9 or 11, Enum.Material.Basalt)
	end

	-- The tunnel straight through, a domed chamber in the middle, a shaft to the 115 shelf.
	tunnel(Vector3.new(c.X - 185, 2, c.Z), Vector3.new(c.X + 185, 2, c.Z), 12, 12)
	terrain:FillBall(Vector3.new(c.X, 12, c.Z), 18, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, -2, c.Z), Vector3.new(44, 8, 44), Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(c.X + 35, 62, c.Z), 120, 6, Enum.Material.Air)
	World.launchPad(Vector3.new(c.X + 35, 2.2, c.Z), Vector3.new(0, 218, 0))

	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local pos = Vector3.new(c.X + math.cos(a) * 14, 3.5 + (i % 3), c.Z + math.sin(a) * 14)
		local shard = neon(
			decor(
				"Crystal",
				Vector3.new(1.8, 6 + (i % 3) * 2, 1.8),
				CFrame.new(pos) * CFrame.Angles(math.cos(a) * 0.5, 0, math.sin(a) * 0.5),
				CRYSTAL_COLORS[i % 2 + 1]
			),
			0.15
		)
		if i % 2 == 0 then
			pointLight(shard, CRYSTAL_COLORS[i % 2 + 1], 18, 1.2)
		end
	end
	for _, dx in ipairs({ -150, -110, -70, -40, 50, 80, 120, 150 }) do
		for _, dz in ipairs({ -5, 5 }) do
			local shard = neon(
				decor(
					"TunnelCrystal",
					Vector3.new(1, 3, 1),
					CFrame.new(c.X + dx, 3, c.Z + dz) * CFrame.Angles(0, 0, 0.3),
					CRYSTAL_COLORS[1]
				),
				0.2
			)
			pointLight(shard, CRYSTAL_COLORS[1], 12, 0.8)
		end
	end
	-- Big crystals along the shelf rims and on the crown.
	for k, s in ipairs(shelves) do
		local count = k == #shelves and 5 or 6
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2 + k * 0.7
			local r = k == #shelves and s[1] * 0.5 or s[1] - 4
			local pos = Vector3.new(c.X + math.cos(a) * r, s[2] + 5, c.Z + math.sin(a) * r)
			neon(
				decor(
					"ShelfCrystal",
					Vector3.new(3, 12 + (i % 2) * 6, 3),
					CFrame.new(pos) * CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35),
					CRYSTAL_COLORS[(i + k) % 2 + 1],
					Enum.Material.Neon,
					true
				),
				0.1
			)
		end
	end

	ground("HeartPedestal", Vector3.new(3, 3, 3), CFrame.new(c.X, 3.5, c.Z + 8), DARK_STONE, Enum.Material.Slate)
	refs.lootSpots.Heart = CFrame.new(c.X, 5 + 1.9, c.Z + 8)

	-- Cave-in: a rock plug that seals the west half of the tunnel (the side facing home).
	refs.caveIn = {
		plug = CFrame.new(c.X - 28, 8, c.Z),
		plugSize = Vector3.new(10, 12.5, 12.5),
		rockMin = Vector3.new(c.X - 48, 11, c.Z - 4),
		rockMax = Vector3.new(c.X - 20, 12, c.Z + 4),
	}

	totem("CrystalTotemWest", Vector3.new(c.X - 168, 1.5, c.Z - 24), Vector3.new(c.X - 260, 1.5, c.Z))
	totem("CrystalTotemEast", Vector3.new(c.X + 168, 1.5, c.Z + 24), Vector3.new(c.X + 260, 1.5, c.Z))
	local shelfTotem = c + compass(150) * 96
	totem("CrystalTotemShelf", Vector3.new(shelfTotem.X, 50, shelfTotem.Z), Vector3.new(c.X - 300, 50, c.Z + 200))

	-- The Leap: a broken stone bridge off the 85 shelf to the Needle, where a
	-- zipline runs to Twin Stacks. The gap needs a sprint jump, so carriers can't make it.
	local toTwin = flatDirection(c, TWIN_STACK)
	local p0 = Vector3.new(c.X, 85, c.Z) + toTwin * 76
	local p1 = Vector3.new(c.X, 80, c.Z) + toTwin * 120
	local p2 = Vector3.new(c.X, 75, c.Z) + toTwin * 135
	local p3 = Vector3.new(c.X, 75, c.Z) + toTwin * 150
	local leapColor = Color3.fromRGB(110, 100, 120)
	plank("Leap", p0, p1, 7, 2, leapColor, Enum.Material.Slate, folders.ground)
	plank("LeapLanding", p2, p3, 7, 2, leapColor, Enum.Material.Slate, folders.ground)
	local mid = p0:Lerp(p1, 0.55)
	structure(
		"LeapPillar",
		Vector3.new(4, mid.Y - 52, 4),
		CFrame.new(mid.X, (mid.Y + 50) / 2 - 1.5, mid.Z),
		leapColor,
		Enum.Material.Slate
	)
	local needle = Vector3.new(c.X, 0, c.Z) + toTwin * 154
	fillColumn(needle.X, needle.Z, -30, 75, 8, Enum.Material.Basalt)
	deck("NeedleDeck", Vector3.new(needle.X, 74.5, needle.Z), 12)
	local gapSign =
		decor("GapSign", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p1 + Vector3.new(0, 4, 0)), Color3.new(1, 1, 1), nil)
	gapSign.Transparency = 1
	sign(
		gapSign,
		"GAP! SPRINT TO CLEAR IT (too heavy with loot)",
		Color3.fromRGB(255, 220, 120),
		Vector3.new(0, 2, 0),
		140
	)
	World.zipline("CrystalZipline", Vector3.new(needle.X, 82, needle.Z), TWIN_STACK + Vector3.new(0, 7, 0))

	-- One boat waits at the west-south-west dock.
	local dockOut = compass(160)
	dock(c + dockOut * 165, c + dockOut * 228, { -1 })

	palmRing(c, 160, 14, 5, {
		c + dockOut * 165,
		c + compass(180) * 160,
		c + compass(0) * 160,
		c + compass(250) * 160,
		needle,
		c + compass(168) * 160,
	})
end

-- Shipwreck Shoals (Captain's Chest) --------------------------------------------------
-- An atoll: wadeable shallows in a ring, a lagoon in the middle, a galleon run
-- aground on a sandbank, and sea stacks linked by rope bridges.
local function buildShoals()
	local c = SHOALS
	fillColumn(c.X, c.Z, -30, -1, 185, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(c.X - 10, -6, c.Z - 10), 10, 118, Enum.Material.Air)
	-- A channel through the reef on the south-east, deep enough for boats.
	local channelOut = compass(55)
	local channelFrom = Vector3.new(c.X, -6, c.Z) + channelOut * 80
	local channelTo = Vector3.new(c.X, -6, c.Z) + channelOut * 205
	terrain:FillBlock(
		CFrame.lookAt((channelFrom + channelTo) / 2, channelTo),
		Vector3.new(36, 10, (channelTo - channelFrom).Magnitude),
		Enum.Material.Air
	)
	fillColumn(c.X, c.Z, -30, 2, 42, Enum.Material.Sand)
	islandSign(Vector3.new(c.X, 85, c.Z), "SHIPWRECK SHOALS", Color3.fromRGB(255, 190, 120))

	-- The landing on the east shore, with the dock and a boat.
	local landing = Vector3.new(-590, 5, 30)
	island(landing, 48, 38, Enum.Material.Sand, Enum.Material.Grass)
	dock(Vector3.new(-548, 0, 30), Vector3.new(-470, 0, 30), { 1 })

	-- The galleon: three decks, a hole in the hull, climbable masts and a crow's nest.
	local hull = CFrame.new(c.X, 2, c.Z) * CFrame.Angles(0, math.rad(25), 0) * CFrame.Angles(0, 0, math.rad(6))
	local wood = Color3.fromRGB(95, 66, 44)
	local pieces = {
		-- name, size, offset, walkable
		{ "WreckFloor", Vector3.new(22, 1, 70), CFrame.new(0, 0.5, 0), true },
		{ "WreckPort", Vector3.new(1, 24, 70), CFrame.new(-11, 12.5, 0) },
		{ "WreckStarboard", Vector3.new(1, 24, 28), CFrame.new(11, 12.5, -21) },
		{ "WreckStarboard", Vector3.new(1, 24, 28), CFrame.new(11, 12.5, 21) },
		{ "WreckHoleTop", Vector3.new(1, 16, 14), CFrame.new(11, 16.5, 0) },
		{ "WreckBow", Vector3.new(22, 24, 1), CFrame.new(0, 12.5, -35) },
		{ "WreckStern", Vector3.new(22, 32, 1), CFrame.new(0, 16.5, 35) },
		{ "WreckGunDeck", Vector3.new(22, 1, 26), CFrame.new(0, 10.5, -22), true },
		{ "WreckGunDeck", Vector3.new(22, 1, 26), CFrame.new(0, 10.5, 22), true },
		{ "WreckTopDeck", Vector3.new(22, 1, 24), CFrame.new(0, 24.5, -23), true },
		{ "WreckTopDeck", Vector3.new(22, 1, 24), CFrame.new(0, 24.5, 23), true },
		{ "WreckCabin", Vector3.new(22, 8, 16), CFrame.new(0, 29, 27), true },
		{ "WreckNest", Vector3.new(8, 1, 8), CFrame.new(0, 62.5, 10), true },
		{ "WreckForeNest", Vector3.new(6, 1, 6), CFrame.new(0, 60.5, -10), true },
	}
	for _, piece in ipairs(pieces) do
		Util.part(
			piece[1],
			piece[2],
			hull * piece[3],
			wood,
			Enum.Material.WoodPlanks,
			piece[4] and folders.ground or folders.structures
		)
	end
	-- Ladders between decks, and the masts (climb them like ladders).
	local function hullLadder(name, offset, height)
		local truss = ladder(name, Vector3.zero, height)
		truss.CFrame = hull * CFrame.new(offset + Vector3.new(0, truss.Size.Y / 2, 0))
	end
	hullLadder("HoldLadder", Vector3.new(-8, 1, 10), 10)
	hullLadder("DeckLadder", Vector3.new(8, 11, -12), 14)
	hullLadder("CabinLadder", Vector3.new(-8, 25, 18), 8)
	hullLadder("ForeMast", Vector3.new(0, 25, -14), 36)
	hullLadder("MainMast", Vector3.new(0, 25, 6), 38)
	for _, sail in ipairs({ { -14, 44, 14 }, { 6, 48, 18 } }) do
		decor(
			"Sail",
			Vector3.new(16, sail[3], 0.3),
			hull * CFrame.new(0, sail[2], sail[1] + 1.5),
			Color3.fromRGB(220, 210, 190),
			Enum.Material.Fabric
		)
	end
	-- A broken mast leaning on the hull doubles as a ramp onto the top deck.
	plank(
		"WreckMast",
		(hull * CFrame.new(-34, 0, -20)).Position,
		(hull * CFrame.new(-11.5, 24.8, -20)).Position,
		3.5,
		1,
		Color3.fromRGB(80, 56, 38),
		Enum.Material.Wood,
		folders.ground
	)
	-- A plank up from the sandbank into the hole in the hull.
	plank(
		"WreckStep",
		(hull * CFrame.new(19, -1.5, 0)).Position,
		(hull * CFrame.new(10.5, 1, 0)).Position,
		8,
		1,
		Color3.fromRGB(80, 56, 38),
		Enum.Material.WoodPlanks,
		folders.ground
	)
	for _, z in ipairs({ -20, 20 }) do
		local lantern = neon(decor("Lantern", Vector3.new(0.8, 1.2, 0.8), hull * CFrame.new(0, 8, z), GOLD))
		pointLight(lantern, Color3.fromRGB(255, 190, 110), 20, 1.2)
	end
	refs.lootSpots.Chest = hull * CFrame.new(0, 1 + 1.6, 0)

	-- The wreck's cannon on the stern cabin: a totem that also fires the Chest's barrage.
	local cannonBase = (hull * CFrame.new(0, 33, 27)).Position
	local model = Instance.new("Model")
	model.Name = "WreckCannon"
	local aim = CFrame.lookAt(cannonBase, Vector3.new(-480, cannonBase.Y, 40))
	Util.part("Carriage", Vector3.new(4, 2, 5), aim * CFrame.new(0, 1, 0), DARK_WOOD, Enum.Material.Wood, model)
	local barrel = Util.part(
		"Barrel",
		Vector3.new(6, 2.4, 2.4),
		aim * CFrame.new(0, 2.6, -1) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.Metal,
		model
	)
	barrel.Shape = Enum.PartType.Cylinder
	local muzzle = Util.part(
		"Eye",
		Vector3.new(1.4, 1.4, 0.6),
		aim * CFrame.new(0, 2.6, -4.2),
		Color3.fromRGB(90, 30, 30),
		Enum.Material.Neon,
		model
	)
	muzzle.CanCollide = false
	model.PrimaryPart = muzzle
	model.Parent = folders.structures
	table.insert(refs.totems, { model = model, eye = muzzle, kind = "cannon" })
	refs.wreckCannon = refs.totems[#refs.totems]

	-- Sea stacks on the far side of the lagoon, joined by rope bridges up high.
	local stacks = {
		{ Vector3.new(-790, 0, -70), 13, 50 },
		{ Vector3.new(-835, 0, 15), 12, 66 },
		{ Vector3.new(-790, 0, 110), 12, 46 },
	}
	for _, s in ipairs(stacks) do
		local p, r, h = s[1], s[2], s[3]
		fillColumn(p.X, p.Z, -30, 1.5, r + 10, Enum.Material.Sand)
		fillColumn(p.X, p.Z, -30, h, r, Enum.Material.Rock)
		deck("StackDeck", Vector3.new(p.X, h, p.Z), 14)
		palm(p.X + r + 5, p.Z + 4, 1.5, 15)
	end
	local a, b, s3 = stacks[1], stacks[2], stacks[3]
	ladder("StackLadder", a[1] + Vector3.new(a[2] + 1, 1.5, 0), a[3])
	local function edge(from, to, r, h)
		return Vector3.new(from.X, h + 1, from.Z) + flatDirection(from, to) * (r - 2)
	end
	ropeBridge("StackBridge", edge(a[1], b[1], a[2], a[3]), edge(b[1], a[1], b[2], b[3]), 4)
	ropeBridge("StackBridge", edge(b[1], s3[1], b[2], b[3]), edge(s3[1], b[1], s3[2], s3[3]), 4)
	World.zipline("WreckZipline", Vector3.new(b[1].X, b[3] + 10, b[1].Z), (hull * CFrame.new(0, 31, -22)).Position)
	totem("LagoonTotem", Vector3.new(s3[1].X, s3[3] + 1, s3[1].Z), Vector3.new(c.X, s3[3], c.Z))

	for _, p in ipairs({ { -600, 0 }, { -575, 60 }, { -615, 55 }, { -560, 5 } }) do
		palm(p[1], p[2])
	end
end

-- The islets: rest stops and landmarks between the big islands ----------------------
local function buildIslets()
	-- Gull Rock: a sea pinnacle with a ladder and a long zipline down to Goblin Cove.
	local g = GULL_ROCK
	fillColumn(g.X, g.Z, -30, 1.5, 34, Enum.Material.Sand)
	fillColumn(g.X, g.Z, -30, 66, 16, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(g.X + 9, 18, g.Z + 7), 17, Enum.Material.Rock)
	deck("GullDeck", Vector3.new(g.X, 66, g.Z), 14)
	ladder("GullLadder", Vector3.new(g.X, 1.5, g.Z - 17), 66)
	World.zipline("GullZipline", Vector3.new(g.X, 76, g.Z), Vector3.new(-115, 13, 612))
	islandSign(Vector3.new(g.X, 92, g.Z), "GULL ROCK")
	palm(g.X - 20, g.Z + 14, 1.5, 14)

	-- Smuggler's Cove: a low islet with a spare boat and a rock arch boats can sail through.
	local s = SMUGGLER
	island(s, 46, 36, Enum.Material.Rock, Enum.Material.Grass)
	for _, z in ipairs({ s.Z - 35, s.Z + 20 }) do
		fillColumn(s.X - 58, z, -30, 32, 7, Enum.Material.Rock)
	end
	terrain:FillBlock(CFrame.new(s.X - 58, 29, s.Z - 7.5), Vector3.new(12, 8, 70), Enum.Material.Rock)
	dock(Vector3.new(s.X, 0, s.Z - 40), Vector3.new(s.X, 0, s.Z - 102), { 1 })
	local hut = CFrame.new(s.X + 8, s.Y, s.Z + 6) * CFrame.Angles(0, math.rad(15), 0)
	structure(
		"Hut",
		Vector3.new(12, 9, 12),
		hut * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.WoodPlanks
	)
	structure(
		"HutRoof",
		Vector3.new(15, 1.5, 15),
		hut * CFrame.new(0, 9.75, 0),
		Color3.fromRGB(60, 60, 70),
		Enum.Material.Fabric
	)
	palm(s.X - 18, s.Z + 12)
	palm(s.X + 22, s.Z - 14)
	islandSign(Vector3.new(s.X, 34, s.Z), "SMUGGLER'S COVE")

	-- Twin Stacks: two sea stacks and a rope bridge. The Crystal Isle zipline lands here.
	local t = TWIN_STACK
	local small = Vector3.new(t.X + 34, 36, t.Z - 32)
	fillColumn(t.X + 15, t.Z - 15, -30, 1.5, 40, Enum.Material.Sand)
	fillColumn(t.X, t.Z, -30, t.Y, 13, Enum.Material.Rock)
	fillColumn(small.X, small.Z, -30, small.Y, 10, Enum.Material.Rock)
	deck("TwinDeck", t, 14)
	deck("TwinDeckSmall", small, 10)
	ladder("TwinLadder", Vector3.new(t.X - 14, 1.5, t.Z), t.Y)
	ladder("TwinLadderSmall", Vector3.new(small.X + 11, 1.5, small.Z), small.Y)
	ropeBridge(
		"TwinBridge",
		Vector3.new(t.X, t.Y + 1, t.Z) + flatDirection(t, small) * 11,
		Vector3.new(small.X, small.Y + 1, small.Z) + flatDirection(small, t) * 8,
		3
	)
	islandSign(Vector3.new(t.X, 72, t.Z), "TWIN STACKS")
	palm(t.X + 30, t.Z + 10, 1.5, 12)
end

-- Traversal toys (the client drives these) -------------------------------------------
World.launchPad = Kit.launchPad
World.zipline = Kit.zipline

-- Currents you can read: a river in the sea with chevrons pointing downstream. Boats carried along
-- it gain speed; sailing against it costs. They are the sea's own shortcuts and traps.
local function buildStream(name, a, b, halfWidth, speed)
	Sea.addStream(name, a, b, halfWidth, speed)
	local direction = flatDirection(a, b)
	local length = (b - a).Magnitude
	local right = Vector3.new(-direction.Z, 0, direction.X)
	for d = 20, length - 10, 46 do
		local center = a + direction * d
		for _, side in ipairs({ -1, 1 }) do
			local arm = center - direction * 5 + right * side * 6
			local chevron = decor(
				"StreamChevron",
				Vector3.new(1.4, 0.2, 14),
				CFrame.lookAt(Vector3.new(arm.X, 0.35, arm.Z), Vector3.new(center.X, 0.35, center.Z))
					* CFrame.new(0, 0, 0),
				Color3.fromRGB(235, 248, 255),
				Enum.Material.Neon
			)
			chevron.Transparency = 0.5
			chevron.CastShadow = false
		end
	end
	local holder = decor(
		"StreamSign",
		Vector3.new(1, 1, 1),
		CFrame.new(a:Lerp(b, 0.5) + Vector3.new(0, 18, 0)),
		Color3.new(1, 1, 1),
		nil
	)
	holder.Transparency = 1
	sign(holder, name, Color3.fromRGB(190, 235, 255), Vector3.zero, 420)
end

local function buildStreams()
	-- The Rushing Strait: the channel between Shipwreck Shoals and Crossroads runs east, fast.
	buildStream("RUSHING STRAIT >", Vector3.new(-505, 0, 90), Vector3.new(-215, 0, 90), 42, 24)
	-- The Home Stream: the open water between Crossroads and Goblin Cove flows toward home. Treasure
	-- runs ride it back; outbound boats fight it.
	buildStream("HOME STREAM v", Vector3.new(-95, 0, 215), Vector3.new(-95, 0, 465), 40, 17)
end

-- Build ----------------------------------------------------------------------
function World.build()
	local old = workspace:FindFirstChild("LootGoblinsGenerated")
	if old then
		old:Destroy()
	end
	folders.root = folder("LootGoblinsGenerated", nil)
	folders.ground = folder("Ground", folders.root)
	folders.structures = folder("Structures", folders.root)
	folders.decor = folder("Decor", folders.root)
	folders.launchPads = folder("LaunchPads", folders.root)
	folders.ziplines = folder("Ziplines", folders.root)
	folders.loot = folder("Loot", folders.root)
	folders.threats = folder("Threats", folders.root)
	folders.fx = folder("Effects", folders.root)
	folders.bodies = folder("SpiritBodies", folders.root)
	folders.landmarks = folder("Landmarks", folders.root)
	refs.folders = folders
	refs.totems = {}
	refs.lootSpots = {}
	refs.boatSpawns = {}
	-- Data for the mechanism modules: the builders only describe, they never run logic.
	refs.spinners = {}
	refs.breakables = {}
	refs.barrels = {}
	refs.kegCrates = {}
	refs.cannons = {}
	refs.levers = {}
	refs.gates = {}
	refs.geysers = {}
	refs.lavaZones = {}
	refs.boostGates = {}
	refs.bounceFans = {}
	refs.navyBases = {}
	refs.troubleSites = {}
	refs.targets = {}
	folders.root.Parent = workspace

	table.clear(Sea.streams)
	table.clear(Sea.whirls)
	buildEnvironment()
	buildHome()
	buildCrossroads()
	buildTemple()
	buildCrystalIsle()
	buildShoals()
	buildIslets()
	Islands.build()
	IslandsFar.build()
	buildStreams()
	pourSea()
	return refs
end

return World

-- Builds the whole map at runtime from Terrain and parts. The repository stays
-- the only source of truth; Edit mode shows an empty sky until Play.
--
-- Layout (north is -Z):
--
--                    SUN TEMPLE (idol, guardian)
--                         | rope bridge   \ zipline
--   SHIPWRECK SHOALS -- CROSSROADS RUINS --- stepping stones -- CRYSTAL ISLE
--   (chest)    \         (lighthouse lens)                    (crystal heart)
--         sandbar \         | long bridge                    / ridge + sandbar
--                    GOBLIN COVE (spawn, the Hoard, boats)
--
-- Gameplay modules only use the references returned in World.refs.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local World = {}

local SEA_Y = 0
local HOME = Vector3.new(0, 6, 210)
local CROSS = Vector3.new(0, 10, -20)
local TEMPLE = Vector3.new(0, 14, -265)
local CRYSTAL = Vector3.new(175, 20, 70)
local SHOALS = Vector3.new(-150, 2, 90)
local HOARD = Vector3.new(0, 6.75, 262)
local LIGHTHOUSE = Vector3.new(58, 10, -28)
local ZIGGURAT = Vector3.new(0, 14, -275)

local STONE = Color3.fromRGB(150, 145, 140)
local DARK_STONE = Color3.fromRGB(85, 80, 90)
local SANDSTONE = Color3.fromRGB(226, 190, 122)
local WOOD = Color3.fromRGB(120, 80, 48)
local DARK_WOOD = Color3.fromRGB(78, 52, 34)
local GOLD = Color3.fromRGB(255, 200, 40)
local WARD_COLOR = Color3.fromRGB(190, 110, 255)

local terrain = workspace.Terrain
local folders: { [string]: Folder } = {}
local refs: { [string]: any } = {}
World.refs = refs

-- Helpers --------------------------------------------------------------------
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Walkable parts go in Ground (the Guardian walks on Ground and Terrain only).
local function ground(name, size, cframe, color, material)
	return Util.part(name, size, cframe, color, material, folders.ground)
end

local function structure(name, size, cframe, color, material)
	return Util.part(name, size, cframe, color, material, folders.structures)
end

-- Decoration never blocks shots or the mouse.
local function decor(name, size, cframe, color, material, collide)
	local p = Util.part(name, size, cframe, color, material, folders.decor)
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	return p
end

local function neon(p, transparency)
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0
	p.CastShadow = false
	return p
end

-- Cylinder parts run along X; this stands one upright.
local function upright(position)
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function cylinder(name, radius, height, position, color, material, parent)
	local p = Util.part(name, Vector3.new(height, radius * 2, radius * 2), upright(position), color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A straight plank whose top surface runs from a to b. Used for ramps, bridges
-- and the lighthouse spiral, so slopes never depend on wedge orientation.
local function plank(name, a, b, width, thickness, color, material, parent, overlap)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude + (overlap or 0)
	local cframe = CFrame.lookAt(mid, b) * CFrame.new(0, -thickness / 2, 0)
	return Util.part(name, Vector3.new(width, thickness, length), cframe, color, material, parent)
end

local function flatDirection(from, to)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return d.Unit
end

-- Terrain shapes. Heights are absolute world Y.
local function fillColumn(x, z, bottomY, topY, radius, material)
	terrain:FillCylinder(CFrame.new(x, (bottomY + topY) / 2, z), topY - bottomY, radius, material)
end

-- A flat-topped island: sand beach ring, body, and a top layer.
local function island(center, beachRadius, topRadius, bodyMaterial, topMaterial)
	fillColumn(center.X, center.Z, -30, 1.5, beachRadius, Enum.Material.Sand)
	fillColumn(center.X, center.Z, -30, center.Y - 2, topRadius, bodyMaterial)
	fillColumn(center.X, center.Z, center.Y - 4, center.Y, topRadius - 1, topMaterial)
end

-- A shallow sand path between two points. Its top sits 1 stud under the sea,
-- so it can be waded (slowly) instead of swum.
local function sandbar(from, to, width)
	local mid = (from + to) / 2
	local length = Util.flatDistance(from, to) + 6
	local cframe = CFrame.lookAt(Vector3.new(mid.X, -2.5, mid.Z), Vector3.new(to.X, -2.5, to.Z))
	terrain:FillBlock(cframe, Vector3.new(width, 3, length), Enum.Material.Sand)
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.IgnoreWater = true

local function groundY(x, z, default)
	terrainOnly.FilterDescendantsInstances = { terrain, folders.ground }
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrainOnly)
	return hit and hit.Position.Y or default
end

local function palm(x, z, y, lean)
	y = y or groundY(x, z, 6)
	local base = Vector3.new(x, y, z)
	local tilt = CFrame.Angles(math.rad(lean or 8), math.rad((x * 7 + z * 3) % 360), 0)
	local trunkTop = base + (CFrame.new(base) * tilt).UpVector * 14
	local trunk = plank("PalmTrunk", base, trunkTop, 1.4, 1.4, Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
	trunk.Parent = folders.structures
	for i = 0, 4 do
		local yaw = math.rad(i * 72)
		local frond = CFrame.new(trunkTop) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.6, -3.2)
		decor(
			"PalmFrond",
			Vector3.new(2.4, 0.3, 7),
			frond * CFrame.Angles(math.rad(-18), 0, 0),
			Color3.fromRGB(60, 170, 70),
			Enum.Material.Grass
		)
	end
end

local function rockPile(position, size)
	structure(
		"Rock",
		size,
		CFrame.new(position) * CFrame.Angles(0.3, position.X % 3, 0.2),
		DARK_STONE,
		Enum.Material.Slate
	)
end

local function brazier(position)
	cylinder("Brazier", 1.8, 3, position + Vector3.new(0, 1.5, 0), DARK_STONE, Enum.Material.Slate, folders.structures)
	local flame = decor(
		"BrazierFlame",
		Vector3.new(1, 1, 1),
		CFrame.new(position + Vector3.new(0, 3.5, 0)),
		GOLD,
		Enum.Material.Neon
	)
	flame.Transparency = 1
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = flame
end

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Parent = parent
	return light
end

-- A light pillar from a point up into the sky. Landmarks you can find from anywhere.
local function skyBeam(name, position, color, width)
	local bottom = Instance.new("Attachment")
	bottom.Name = name .. "Bottom"
	bottom.Position = position
	bottom.Parent = terrain
	local top = Instance.new("Attachment")
	top.Name = name .. "Top"
	top.Position = position + Vector3.new(0, 320, 0)
	top.Parent = terrain
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(color)
	beam.Width0 = width
	beam.Width1 = width
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = bottom
	return beam
end

local function sign(parent, text, color, studsOffset, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(260, 46)
	gui.StudsOffsetWorldSpace = studsOffset or Vector3.new(0, 6, 0)
	gui.MaxDistance = maxDistance or 260
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = parent
	return gui
end

-- Stone watcher. Threats animates the eye and fires from it.
local function totem(name, position, faceToward)
	local model = Instance.new("Model")
	model.Name = name
	local look = CFrame.lookAt(position, Vector3.new(faceToward.X, position.Y, faceToward.Z))
	Util.part("Base", Vector3.new(5, 2, 5), look * CFrame.new(0, 1, 0), DARK_STONE, Enum.Material.Slate, model)
	Util.part("Body", Vector3.new(3.4, 9, 3.4), look * CFrame.new(0, 6.5, 0), STONE, Enum.Material.Cobblestone, model)
	Util.part("Brow", Vector3.new(4.4, 1, 4.4), look * CFrame.new(0, 9.4, 0), DARK_STONE, Enum.Material.Slate, model)
	Util.part("Cap", Vector3.new(3, 1.6, 3), look * CFrame.new(0, 11.7, 0), DARK_STONE, Enum.Material.Slate, model)
	local eye = Util.part(
		"Eye",
		Vector3.new(1.6, 1.2, 0.6),
		look * CFrame.new(0, 8.3, -1.8),
		Color3.fromRGB(90, 30, 30),
		Enum.Material.Neon,
		model
	)
	eye.CanCollide = false
	model.PrimaryPart = eye
	model.Parent = folders.structures
	table.insert(refs.totems, { model = model, eye = eye, kind = "totem" })
	return model
end

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
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 222, 255)
	atmosphere.Decay = Color3.fromRGB(110, 140, 180)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	-- Sea floor. The water itself is poured in last, into every gap below sea level.
	terrain:FillBlock(CFrame.new(15, -34, -30), Vector3.new(840, 12, 1080), Enum.Material.Sand)

	-- Invisible walls keep swimmers and thrown loot near the islands.
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	local midX, midZ = (min.X + max.X) / 2, (min.Z + max.Z) / 2
	local spanX, spanZ = max.X - min.X, max.Z - min.Z
	local walls = {
		{ Vector3.new(4, 400, spanZ), Vector3.new(min.X, 150, midZ) },
		{ Vector3.new(4, 400, spanZ), Vector3.new(max.X, 150, midZ) },
		{ Vector3.new(spanX, 400, 4), Vector3.new(midX, 150, min.Z) },
		{ Vector3.new(spanX, 400, 4), Vector3.new(midX, 150, max.Z) },
	}
	for _, wall in ipairs(walls) do
		local p = Util.part("BoundaryWall", wall[1], CFrame.new(wall[2]), Color3.new(1, 1, 1), nil, folders.structures)
		p.Transparency = 1
		p.CanQuery = false
	end
end

local function pourSea()
	local region = Region3.new(Vector3.new(-400, -28, -560), Vector3.new(440, SEA_Y, 520)):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
end

-- Goblin Cove (home) ---------------------------------------------------------------
local function buildHome()
	island(HOME, 100, 86, Enum.Material.Rock, Enum.Material.Grass)
	-- The hideout hill behind the Hoard.
	terrain:FillBall(Vector3.new(0, 0, 302), 26, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-30, -4, 290), 16, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(32, -6, 288), 15, Enum.Material.Rock)

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
	skyBeam("HoardBeacon", HOARD, GOLD, 5)
	refs.hoard = { position = HOARD, part = dais }

	-- The hideout door and eyes, so the hill reads as home.
	decor("HideoutDoor", Vector3.new(8, 10, 1), CFrame.new(0, 10, 277.5), DARK_WOOD, Enum.Material.WoodPlanks, true)
	for _, x in ipairs({ -6, 6 }) do
		neon(decor("HideoutEye", Vector3.new(3, 2, 1), CFrame.new(x, 20, 279), Color3.fromRGB(120, 255, 90)))
	end

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
	spawn.CFrame = CFrame.new(0, 6.6, 222)
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
		table.insert(refs.homePoints, CFrame.new(0 + math.cos(a) * 9, 10, 222 + math.sin(a) * 9))
	end

	-- Docks and boats on the north shore.
	for _, x in ipairs({ -22, 22 }) do
		ground("Dock", Vector3.new(8, 1, 42), CFrame.new(x, 2, 104), WOOD, Enum.Material.WoodPlanks)
		for _, z in ipairs({ 86, 100, 114 }) do
			for _, side in ipairs({ -3.5, 3.5 }) do
				cylinder(
					"DockPost",
					0.6,
					10,
					Vector3.new(x + side, -2.5, z),
					DARK_WOOD,
					Enum.Material.Wood,
					folders.structures
				)
			end
		end
	end
	refs.boatSpawns = {
		CFrame.new(-35, 0.8, 100),
		CFrame.new(35, 0.8, 100),
	}

	-- Goblin huts for cover and character.
	local huts = { { -46, 205, 20 }, { 46, 200, -25 }, { -42, 160, 60 }, { 40, 245, 10 } }
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

	for _, p in ipairs({ { -70, 190 }, { 72, 230 }, { -60, 262 }, { 64, 280 }, { -80, 236 }, { 20, 300 } }) do
		palm(p[1], p[2])
	end
end

-- Long Bridge (home <-> crossroads) ------------------------------------------------
local function buildLongBridge()
	local a = Vector3.new(0, 6.6, 130)
	local b = Vector3.new(0, 10.6, 48)
	plank("LongBridge", a, b, 10, 1.2, WOOD, Enum.Material.WoodPlanks, folders.ground)
	for _, side in ipairs({ -5.2, 5.2 }) do
		plank(
			"BridgeCurb",
			a + Vector3.new(side, 0.6, 0),
			b + Vector3.new(side, 0.6, 0),
			0.6,
			0.6,
			DARK_WOOD,
			Enum.Material.Wood,
			folders.structures
		)
	end
	for _, z in ipairs({ 112, 89, 66 }) do
		local t = (z - a.Z) / (b.Z - a.Z)
		local y = a.Y + (b.Y - a.Y) * t
		for _, side in ipairs({ -4, 4 }) do
			cylinder(
				"BridgePillar",
				1,
				y + 12,
				Vector3.new(side, (y - 12) / 2 - 1, z),
				DARK_WOOD,
				Enum.Material.Wood,
				folders.structures
			)
		end
	end
end

-- Crossroads Ruins and the Lighthouse ----------------------------------------------
local function buildCrossroads()
	island(CROSS, 84, 72, Enum.Material.Rock, Enum.Material.Grass)

	cylinder("Plaza", 18, 0.6, CROSS + Vector3.new(0, 0.2, 0), STONE, Enum.Material.Cobblestone, folders.ground)

	-- Broken walls: cover from grapples and totems.
	local walls = {
		{ -30, -5, 2, 10, 22, 0 },
		{ -22, -42, 18, 8, 2, 0 },
		{ 26, 8, 16, 12, 2, 20 },
		{ -8, 24, 14, 6, 2, 0 },
		{ 16, -56, 2, 9, 16, 0 },
		{ -48, -28, 2, 14, 12, -15 },
		{ 30, -40, 12, 7, 2, 35 },
	}
	for _, w in ipairs(walls) do
		local cf = CFrame.new(w[1], CROSS.Y + w[4] / 2 - 0.5, w[2]) * CFrame.Angles(0, math.rad(w[6]), 0)
		structure("RuinWall", Vector3.new(w[3], w[4], w[5]), cf, STONE, Enum.Material.Brick)
		-- A broken lump on top so it doesn't look like a box.
		structure(
			"RuinTop",
			Vector3.new(math.max(w[3] * 0.5, 2), 2, math.max(w[5] * 0.5, 2)),
			cf * CFrame.new(w[3] * 0.15, w[4] / 2 + 0.6, 0),
			STONE,
			Enum.Material.Brick
		)
	end

	-- Columns around the plaza, a few broken or fallen.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		local pos = CROSS + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24)
		local height = (i % 3 == 0) and 7 or 16
		if i == 5 then
			local fallen = cylinder(
				"FallenColumn",
				1.6,
				16,
				pos + Vector3.new(0, 1.6, 0),
				STONE,
				Enum.Material.Marble,
				folders.structures
			)
			fallen.CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, a, 0)
		else
			cylinder(
				"Column",
				1.6,
				height,
				pos + Vector3.new(0, height / 2, 0),
				STONE,
				Enum.Material.Marble,
				folders.structures
			)
		end
	end

	-- Ruined tower: a sniper perch reached by a launch pad.
	local towerPos = Vector3.new(-38, CROSS.Y, -60)
	ground(
		"RuinTower",
		Vector3.new(10, 26, 10),
		CFrame.new(towerPos + Vector3.new(0, 13, 0)),
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
			CFrame.new(towerPos + offset + Vector3.new(0, 27.25, 0)),
			STONE,
			Enum.Material.Brick
		)
	end
	World.launchPad(towerPos + Vector3.new(0, 0.2, 10.5), Vector3.new(0, 118, 0))

	-- Lighthouse: an exposed spiral climb to the Lens, with a long fall into the sea.
	local stripes = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(210, 50, 50) }
	for i = 0, 5 do
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
	local topY = LIGHTHOUSE.Y + 62
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
	pointLight(lamp, Color3.fromRGB(255, 240, 160), 40, 2)
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

	-- Spiral ramp: 3 turns from the ground (facing the plaza) to the top.
	local turns, perTurn, radius = 3, 24, 12
	local steps = turns * perTurn
	local startY, endY = CROSS.Y + 0.5, topY
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

	totem("LighthouseTotem", Vector3.new(36, CROSS.Y, -2), LIGHTHOUSE)

	-- North gate to the rope bridge.
	for _, x in ipairs({ -7, 7 }) do
		structure(
			"GatePillar",
			Vector3.new(3, 15, 3),
			CFrame.new(x, CROSS.Y + 7, -86),
			SANDSTONE,
			Enum.Material.Sandstone
		)
	end
	structure(
		"GateLintel",
		Vector3.new(17, 3, 3.4),
		CFrame.new(0, CROSS.Y + 16, -86),
		SANDSTONE,
		Enum.Material.Sandstone
	)

	for _, p in ipairs({ { -60, 10 }, { -20, 40 }, { 45, 30 }, { -55, -55 }, { 60, 20 } }) do
		palm(p[1], p[2])
	end
	for _, p in ipairs({ { 10, 30, 4 }, { -50, 0, 6 }, { 50, -60, 5 } }) do
		rockPile(Vector3.new(p[1], CROSS.Y + p[3] / 3, p[2]), Vector3.new(p[3], p[3] * 0.8, p[3] * 1.2))
	end
end

-- Rope bridge (crossroads <-> temple). Narrow, no rails: easy to get knocked off.
local function buildRopeBridge()
	local a = Vector3.new(0, CROSS.Y + 0.6, -90)
	local b = Vector3.new(0, TEMPLE.Y + 0.6, -182)
	local pieces = 22
	local function point(t)
		local p = a:Lerp(b, t)
		return p - Vector3.new(0, 3 * math.sin(math.pi * t), 0)
	end
	for i = 0, pieces - 1 do
		plank(
			"RopeBridge",
			point(i / pieces),
			point((i + 1) / pieces),
			6,
			0.6,
			Color3.fromRGB(165, 125, 80),
			Enum.Material.WoodPlanks,
			folders.ground,
			0.3
		)
	end
	for _, side in ipairs({ -3.2, 3.2 }) do
		for i = 0, pieces - 1 do
			local p0 = point(i / pieces) + Vector3.new(side, 3, 0)
			local p1 = point((i + 1) / pieces) + Vector3.new(side, 3, 0)
			local rope =
				plank("Rope", p0, p1, 0.25, 0.25, Color3.fromRGB(200, 170, 110), Enum.Material.Fabric, folders.decor)
			rope.CanCollide = false
			rope.CanQuery = false
		end
	end
	for _, z in ipairs({ a.Z, b.Z }) do
		for _, side in ipairs({ -3.2, 3.2 }) do
			local y = z == a.Z and a.Y or b.Y
			structure("RopePost", Vector3.new(0.8, 4, 0.8), CFrame.new(side, y + 1.5, z), DARK_WOOD, Enum.Material.Wood)
		end
	end
end

-- Sun Temple (Golden Idol, Guardian) ------------------------------------------------
local function buildTemple()
	fillColumn(TEMPLE.X, TEMPLE.Z, -30, TEMPLE.Y - 2, 92, Enum.Material.Rock)
	fillColumn(TEMPLE.X, TEMPLE.Z, TEMPLE.Y - 4, TEMPLE.Y, 88, Enum.Material.Grass)
	-- A rocky mound hides the sea cave that climbs into the courtyard from the west.
	terrain:FillBall(Vector3.new(-62, 10, -250), 22, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(60, 8, -320), 18, Enum.Material.Rock)
	local caveFrom = Vector3.new(-90, 4, -250)
	local caveTo = Vector3.new(-36, 19, -250)
	terrain:FillBlock(
		CFrame.lookAt((caveFrom + caveTo) / 2, caveTo),
		Vector3.new(12, 10, (caveTo - caveFrom).Magnitude + 6),
		Enum.Material.Air
	)
	terrain:FillBlock(CFrame.new(-99, -1.5, -250), Vector3.new(14, 5, 18), Enum.Material.Sand)
	for _, z in ipairs({ -256, -244 }) do
		local torch = decor(
			"CaveGlow",
			Vector3.new(0.6, 0.6, 0.6),
			CFrame.new(-70, 9, z),
			Color3.fromRGB(120, 255, 200),
			Enum.Material.Neon
		)
		pointLight(torch, Color3.fromRGB(120, 255, 200), 14, 1)
	end

	-- The ziggurat.
	local tiers = { { 64, 8 }, { 48, 8 }, { 32, 8 }, { 18, 6 } }
	local y = TEMPLE.Y
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
	local topY = y -- 44
	ground("Altar", Vector3.new(6, 2, 6), CFrame.new(ZIGGURAT.X, topY + 1, ZIGGURAT.Z), DARK_STONE, Enum.Material.Slate)
	refs.lootSpots.Idol = CFrame.new(ZIGGURAT.X, topY + 2 + 2.3, ZIGGURAT.Z)

	-- Grand stairs straight up the south face. The boulder rolls down these.
	local stairBottom = Vector3.new(0, TEMPLE.Y + 0.2, -222)
	local stairTop = Vector3.new(0, topY, -266)
	plank(
		"TempleStairs",
		stairBottom,
		stairTop,
		12,
		2,
		Color3.fromRGB(205, 170, 105),
		Enum.Material.Sandstone,
		folders.ground
	)
	local stairDirection = (stairTop - stairBottom).Unit
	for i = 1, 14 do
		local p = stairBottom:Lerp(stairTop, i / 15)
		local stripe = decor(
			"StairStripe",
			Vector3.new(12, 0.1, 0.5),
			CFrame.lookAt(p, p + stairDirection) * CFrame.new(0, 0.06, 0),
			Color3.fromRGB(150, 120, 75),
			Enum.Material.Sandstone
		)
		stripe.CanCollide = false
	end
	-- Just below the top of the stairs, so it misses the thief at the altar.
	refs.boulderStart = CFrame.new(0, 46, -258)
	refs.boulderDirection = Vector3.new(0, 0, 1)
	brazier(Vector3.new(-9, TEMPLE.Y, -221))
	brazier(Vector3.new(9, TEMPLE.Y, -221))

	-- Side climbs: stepping blocks up the east and west faces.
	local steps = { { 35, 16, 6, 4 }, { 26.5, 24, 5, 4 }, { 18.5, 32, 5, 4 }, { 11, 39.5, 4, 3 } }
	for _, sideSign in ipairs({ 1, -1 }) do
		for _, s in ipairs(steps) do
			ground(
				"ClimbStep",
				Vector3.new(s[3], s[4], s[3]),
				CFrame.new(s[1] * sideSign, s[2], -262),
				Color3.fromRGB(190, 155, 95),
				Enum.Material.Sandstone
			)
		end
	end

	-- South gate where the rope bridge arrives.
	for _, x in ipairs({ -7, 7 }) do
		structure(
			"TempleGate",
			Vector3.new(3, 16, 3),
			CFrame.new(x, TEMPLE.Y + 8, -188),
			SANDSTONE,
			Enum.Material.Sandstone
		)
	end
	structure(
		"TempleGateLintel",
		Vector3.new(17, 3, 3.4),
		CFrame.new(0, TEMPLE.Y + 17.5, -188),
		SANDSTONE,
		Enum.Material.Sandstone
	)

	-- The Guardian sleeps on the north side.
	local lair = Vector3.new(0, TEMPLE.Y, -330)
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
	refs.guardianLair = CFrame.lookAt(lair, Vector3.new(ZIGGURAT.X, TEMPLE.Y, ZIGGURAT.Z))
	refs.templeCenter = TEMPLE

	totem("TempleTotemWest", Vector3.new(-28, TEMPLE.Y, -222), Vector3.new(0, TEMPLE.Y, -195))
	totem("TempleTotemEast", Vector3.new(28, TEMPLE.Y, -222), Vector3.new(0, TEMPLE.Y, -195))

	-- Zipline tower on the south-east cliff: a fast, exposed way off the island.
	local towerBase = Vector3.new(60, TEMPLE.Y, -205)
	local deckY = TEMPLE.Y + 18
	ground(
		"ZipDeck",
		Vector3.new(12, 1, 12),
		CFrame.new(towerBase.X, deckY - 0.5, towerBase.Z),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for _, o in ipairs({
		Vector3.new(5.5, 0, 5.5),
		Vector3.new(-5.5, 0, 5.5),
		Vector3.new(5.5, 0, -5.5),
		Vector3.new(-5.5, 0, -5.5),
	}) do
		structure(
			"ZipPost",
			Vector3.new(1, deckY - TEMPLE.Y, 1),
			CFrame.new(towerBase + o + Vector3.new(0, (deckY - TEMPLE.Y) / 2, 0)),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	local ladder = Instance.new("TrussPart")
	ladder.Name = "ZipLadder"
	ladder.Size = Vector3.new(2, deckY - TEMPLE.Y, 2)
	ladder.CFrame = CFrame.new(towerBase.X - 7, (TEMPLE.Y + deckY) / 2, towerBase.Z)
	ladder.Anchored = true
	ladder.Color = DARK_WOOD
	ladder.Parent = folders.structures
	World.zipline("TempleZipline", Vector3.new(towerBase.X, deckY + 7, towerBase.Z), Vector3.new(38, CROSS.Y + 7, -62))

	for _, p in ipairs({ { -55, -215 }, { 70, -250 }, { -60, -310 }, { 40, -338 }, { -40, -192 } }) do
		palm(p[1], p[2])
	end
end

-- Crystal Isle (Crystal Heart) --------------------------------------------------------
local function buildCrystalIsle()
	local c = CRYSTAL
	fillColumn(c.X, c.Z, -30, 1.5, 66, Enum.Material.Sand)
	fillColumn(c.X, c.Z, -30, c.Y, 56, Enum.Material.Basalt)
	terrain:FillBall(Vector3.new(c.X, 8, c.Z), 36, Enum.Material.Basalt)
	-- Tunnel straight through, a domed chamber in the middle, a shaft to the summit.
	terrain:FillBlock(CFrame.new(c.X, 8, c.Z), Vector3.new(128, 12, 12), Enum.Material.Air)
	terrain:FillBall(Vector3.new(c.X, 12, c.Z), 15, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, -1, c.Z), Vector3.new(34, 6, 34), Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(c.X, 36, c.Z), 22, 5, Enum.Material.Air)

	local crystalColors = { Color3.fromRGB(215, 110, 255), Color3.fromRGB(110, 230, 255) }
	-- Crystals in the chamber and along the tunnel.
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local pos = Vector3.new(c.X + math.cos(a) * 11.5, 3.5 + (i % 3), c.Z + math.sin(a) * 11.5)
		local shard = neon(
			decor(
				"Crystal",
				Vector3.new(1.6, 6 + (i % 3) * 2, 1.6),
				CFrame.new(pos) * CFrame.Angles(math.cos(a) * 0.5, 0, math.sin(a) * 0.5),
				crystalColors[i % 2 + 1]
			),
			0.15
		)
		if i % 2 == 0 then
			pointLight(shard, crystalColors[i % 2 + 1], 16, 1.2)
		end
	end
	for _, x in ipairs({ 128, 142, 208, 222 }) do
		for _, z in ipairs({ c.Z - 5, c.Z + 5 }) do
			local shard = neon(
				decor(
					"TunnelCrystal",
					Vector3.new(1, 3, 1),
					CFrame.new(x, 3, z) * CFrame.Angles(0, 0, 0.3),
					crystalColors[1]
				),
				0.2
			)
			pointLight(shard, crystalColors[1], 12, 0.8)
		end
	end
	-- Big crystals on the summit, around (not over) the shaft.
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local pos = Vector3.new(c.X + math.cos(a) * 12, 42, c.Z + math.sin(a) * 12)
		neon(
			decor(
				"SummitCrystal",
				Vector3.new(3, 14, 3),
				CFrame.new(pos) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4),
				crystalColors[i % 2 + 1],
				Enum.Material.Neon,
				true
			),
			0.1
		)
	end

	ground("HeartPedestal", Vector3.new(3, 3, 3), CFrame.new(c.X, 3.5, c.Z + 8), DARK_STONE, Enum.Material.Slate)
	refs.lootSpots.Heart = CFrame.new(c.X, 5 + 1.9, c.Z + 8)
	World.launchPad(Vector3.new(c.X, 2.2, c.Z), Vector3.new(0, 140, 0))

	-- Cave-in: a rock plug that seals the west half of the tunnel.
	refs.caveIn = {
		plug = CFrame.new(c.X - 25, 8, c.Z),
		plugSize = Vector3.new(10, 12.5, 12.5),
		rockMin = Vector3.new(c.X - 45, 11, c.Z - 4),
		rockMax = Vector3.new(c.X - 12, 12, c.Z + 4),
	}

	totem("CrystalTotemWest", Vector3.new(114, 1.5, 54), Vector3.new(80, 1.5, 40))
	totem("CrystalTotemEast", Vector3.new(236, 1.5, 86), Vector3.new(260, 1.5, 120))

	-- The ridge: a fast way home from the cliff top. Its gap is too wide to
	-- jump while carrying loot, so carriers drop to the sandbar below.
	local toHome = flatDirection(c, HOME)
	local ridgeStart = Vector3.new(c.X, c.Y, c.Z) + toHome * 50
	local gapStart = ridgeStart + toHome * 55 + Vector3.new(0, -8, 0)
	local gapEnd = gapStart + toHome * 11 + Vector3.new(0, -5.5, 0)
	local homeEdge = Vector3.new(HOME.X, HOME.Y, HOME.Z) - toHome * 84
	plank("Ridge", ridgeStart, gapStart, 9, 3, Color3.fromRGB(110, 100, 120), Enum.Material.Slate, folders.ground)
	plank("RidgeLanding", gapEnd, homeEdge, 9, 3, Color3.fromRGB(110, 100, 120), Enum.Material.Slate, folders.ground)
	for i = 1, 3 do
		local p = ridgeStart:Lerp(gapStart, i / 4)
		structure(
			"RidgePillar",
			Vector3.new(4, p.Y + 6, 4),
			CFrame.new(p.X, (p.Y - 6) / 2 - 1.6, p.Z),
			Color3.fromRGB(90, 80, 100),
			Enum.Material.Slate
		)
	end
	local gapSign = decor(
		"GapSign",
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(gapStart + Vector3.new(0, 4, 0)),
		Color3.new(1, 1, 1),
		nil
	)
	gapSign.Transparency = 1
	sign(gapSign, "GAP! (too heavy with loot)", Color3.fromRGB(255, 220, 120), Vector3.new(0, 2, 0), 120)
	sandbar(Vector3.new(c.X, 0, c.Z) + toHome * 62, Vector3.new(HOME.X, 0, HOME.Z) - toHome * 96, 16)

	for _, p in ipairs({ { 120, 100 }, { 226, 34 }, { 150, 125 }, { 205, 120 } }) do
		palm(p[1], p[2], 1.5, 14)
	end
end

-- Stepping stones (crossroads <-> crystal isle) ----------------------------------------
local function buildSteppingStones()
	local mouth = Vector3.new(CRYSTAL.X - 66, 0, CRYSTAL.Z)
	local dir = flatDirection(CROSS, mouth)
	local start = Vector3.new(CROSS.X, 0, CROSS.Z) + dir * 84
	for i = 0, 3 do
		local center = start + dir * (9.5 + i * 13.5)
		cylinder(
			"SteppingStone",
			3,
			13,
			Vector3.new(center.X, -3.5, center.Z),
			Color3.fromRGB(110, 105, 100),
			Enum.Material.Slate,
			folders.ground
		)
	end
end

-- Shipwreck Shoals (Captain's Chest) --------------------------------------------------
local function buildShoals()
	fillColumn(SHOALS.X, SHOALS.Z, -30, SHOALS.Y, 30, Enum.Material.Sand)
	terrain:FillBall(Vector3.new(-175, -8, 60), 12, Enum.Material.Sand)
	terrain:FillBall(Vector3.new(-120, -9, 130), 10, Enum.Material.Sand)
	local toHome = flatDirection(SHOALS, HOME)
	sandbar(Vector3.new(SHOALS.X, 0, SHOALS.Z) + toHome * 26, Vector3.new(HOME.X, 0, HOME.Z) - toHome * 96, 18)
	local toCross = flatDirection(SHOALS, CROSS)
	sandbar(Vector3.new(SHOALS.X, 0, SHOALS.Z) + toCross * 26, Vector3.new(CROSS.X, 0, CROSS.Z) - toCross * 80, 16)

	-- The wreck: a tilted hull with a hole in its side and an open deck.
	local hull = CFrame.new(-152, SHOALS.Y, 88) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(0, 0, math.rad(10))
	local wood = Color3.fromRGB(95, 66, 44)
	local pieces = {
		{ "WreckFloor", Vector3.new(16, 1, 44), CFrame.new(0, 0.5, 0), true },
		{ "WreckPort", Vector3.new(1, 10, 44), CFrame.new(-8, 5.5, 0) },
		{ "WreckStarboard", Vector3.new(1, 10, 16), CFrame.new(8, 5.5, -14) },
		{ "WreckStarboard", Vector3.new(1, 10, 16), CFrame.new(8, 5.5, 14) },
		{ "WreckHoleTop", Vector3.new(1, 2.5, 12), CFrame.new(8, 9.25, 0) },
		{ "WreckBow", Vector3.new(16, 10, 1), CFrame.new(0, 5.5, -22) },
		{ "WreckStern", Vector3.new(16, 12, 1), CFrame.new(0, 6.5, 22) },
		{ "WreckDeck", Vector3.new(16, 1, 12), CFrame.new(0, 10.5, -16), true },
		{ "WreckDeck", Vector3.new(16, 1, 12), CFrame.new(0, 10.5, 16), true },
		{ "WreckCabin", Vector3.new(16, 6, 10), CFrame.new(0, 14, 17), true },
	}
	for _, piece in ipairs(pieces) do
		local p = Util.part(
			piece[1],
			piece[2],
			hull * piece[3],
			wood,
			Enum.Material.WoodPlanks,
			piece[4] and folders.ground or folders.structures
		)
		p.Color = wood
	end
	-- A broken mast leaning on the hull doubles as a ramp onto the deck.
	plank(
		"WreckMast",
		(hull * CFrame.new(-20, -1.5, -14)).Position,
		(hull * CFrame.new(-7.5, 11, -14)).Position,
		3,
		1,
		Color3.fromRGB(80, 56, 38),
		Enum.Material.Wood,
		folders.ground
	)
	decor(
		"WreckSail",
		Vector3.new(0.3, 9, 12),
		hull * CFrame.new(-14, 4, 6) * CFrame.Angles(0, 0, math.rad(-40)),
		Color3.fromRGB(220, 210, 190),
		Enum.Material.Fabric
	)
	refs.lootSpots.Chest = hull * CFrame.new(0, 1 + 1.6, 0)

	-- The wreck's cannon: a totem that also fires the Chest's barrage.
	local cannonBase = (hull * CFrame.new(0, 17, 17)).Position
	local model = Instance.new("Model")
	model.Name = "WreckCannon"
	local aim = CFrame.lookAt(cannonBase, Vector3.new(-100, cannonBase.Y, 130))
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

	for _, p in ipairs({ { -170, 105 }, { -135, 70 }, { -160, 64 } }) do
		palm(p[1], p[2], SHOALS.Y, 18)
	end
end

-- Traversal toys (the client drives these) -------------------------------------------
-- A launch pad throws whoever touches it. Launch is a velocity; keep it mostly
-- vertical, because air control eats sideways speed.
function World.launchPad(position, launch)
	local pad = Util.part(
		"LaunchPad",
		Vector3.new(0.6, 7, 7),
		upright(position),
		Color3.fromRGB(110, 255, 120),
		Enum.Material.Neon,
		folders.launchPads
	)
	pad.Shape = Enum.PartType.Cylinder
	pad:SetAttribute("Launch", launch)
	local arrow = decor(
		"PadArrow",
		Vector3.new(1, 3, 1),
		CFrame.new(position + Vector3.new(0, 2.5, 0)),
		Color3.fromRGB(200, 255, 200),
		Enum.Material.Neon
	)
	arrow.Transparency = 0.4
	return pad
end

-- A one-way zipline. The prompt sits at the start; the client does the ride.
function World.zipline(name, from, to)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("ZipFrom", from)
	model:SetAttribute("ZipTo", to)
	local startPost =
		Util.part("Start", Vector3.new(1.2, 1.2, 1.2), CFrame.new(from), DARK_WOOD, Enum.Material.Wood, model)
	startPost.CanCollide = false
	Util.part("End", Vector3.new(1.2, 1.2, 1.2), CFrame.new(to), DARK_WOOD, Enum.Material.Wood, model).CanCollide =
		false
	local cable = plank("Cable", from, to, 0.2, 0.2, Color3.fromRGB(40, 40, 40), Enum.Material.Metal, model)
	cable.CanCollide = false
	cable.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZiplinePrompt"
	prompt.ActionText = "RIDE"
	prompt.ObjectText = "Zipline"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = startPost
	model.Parent = folders.ziplines
	return model
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
	refs.folders = folders
	refs.totems = {}
	refs.lootSpots = {}
	folders.root.Parent = workspace

	buildEnvironment()
	buildHome()
	buildLongBridge()
	buildCrossroads()
	buildRopeBridge()
	buildTemple()
	buildCrystalIsle()
	buildSteppingStones()
	buildShoals()
	pourSea()
	return refs
end

return World

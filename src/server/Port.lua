-- The Goblin Port (V13): the harbour town where goblins spend the time between raids.
--
-- It stands on its own island far south of the archipelago (Config.PORT.CENTER), out of streaming range of the raid,
-- and nothing of a raid reaches it (shared/Lobby.inPort is what every raid system asks). What is here:
--
--   THE PLAZA        where you arrive: the Golden Goblin fountain, two bounce pads, lamps, market stalls
--   THE BOARDING DOCK  north: a pier to the moored airship. Walk up its gangplank and you are READY; when every
--                    goblin in the Port is aboard it, the next raid starts in a few seconds instead of waiting
--   THE SHIPYARD     west: every boat class on its slipway (look at one to open the showroom on it)
--   THE MENAGERIE    east: four pens where pets of every kind wander (the client brings them to life)
--   THE WARDROBE     south: Madame Ragwort's shop, with mannequins in her window
--   THE SPYGLASS     north-east: a tower with a telescope: watch the raid from here
--   THE PODIUM       south-west: the last raid's winners stand on it when they come home, and a dressed statue of
--                    the champion stays until the next raid crowns someone else
--
-- The server builds it once (Port.build), moves goblins into it (Port.arrive), counts who is ready, keeps the
-- champion's statue, and owns spectating (Port.spectate): which raider a spectator watches and where the server
-- streams the world to them (Player.ReplicationFocus). The round itself is Raid.lua's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Palette = require(Shared:WaitForChild("Palette"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Flight = require(script.Parent.Flight)
local Poltergoblin = require(script.Parent.Poltergoblin)

local Port = {}

local P = Config.PORT
local C = P.CENTER
local rgb = Color3.fromRGB

local refs
local core -- persistent model: floors, the plank, the podium, the boards (always on every client)
local town -- streamed model: everything else
local spawnPoints = {}
local nextSpawn = 0
local podiumSpots = {} -- 1st, 2nd, 3rd: CFrames to stand on
local readyBox -- { cframe, size }: the airship's deck
local statue -- the champion's dressed mannequin
local statueLabel
local spectators = {} -- spectator -> target player
local arriving = {} -- player -> token (a later arrival cancels an earlier one's retries)

local WOOD, WOOD_LIGHT, WOOD_DARK = Palette.WOOD, Palette.WOOD_LIGHT, Palette.WOOD_DARK
local GOLD, STONE, STONE_DARK = Palette.GOLD, Palette.STONE, Palette.STONE_DARK
local CANVAS, ROPE = Palette.CANVAS, Palette.ROPE
local RED, TEAL, PURPLE = rgb(214, 58, 48), rgb(64, 200, 196), rgb(150, 70, 140)
local SKIN = Palette.GOBLIN
local SMOOTH, PLANKS, M_WOOD, FABRIC, METAL, NEON, COBBLE, SLATE, GLASS =
	Enum.Material.SmoothPlastic,
	Enum.Material.WoodPlanks,
	Enum.Material.Wood,
	Enum.Material.Fabric,
	Enum.Material.Metal,
	Enum.Material.Neon,
	Enum.Material.Cobblestone,
	Enum.Material.Slate,
	Enum.Material.Glass

local function now()
	return workspace:GetServerTimeNow()
end

-- Building helpers ------------------------------------------------------------------------------------------------------
-- Positions are relative to the Port's centre (north is -Z, like the sea); y is height above the water.
local function at(x, y, z)
	return CFrame.new(C.X + x, y, C.Z + z)
end

-- opts: collide (default true for floors/structures), shape, transparency, parent, ball/cyl/wedge, shadow
local function part(name, size, cf, color, material, opts)
	opts = opts or {}
	local p = Instance.new(opts.wedge and "WedgePart" or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CanQuery = opts.collide ~= false
	p.CanTouch = opts.touch == true
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.ball then
		p.Shape = Enum.PartType.Ball
	elseif opts.cyl then
		p.Shape = Enum.PartType.Cylinder
	end
	if opts.egg then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Transparency = opts.transparency or 0
	p.Parent = opts.parent or town
	return p
end

-- Decoration: never solid, never hit by rays.
local function deco(name, size, cf, color, material, opts)
	opts = opts or {}
	opts.collide = false
	return part(name, size, cf, color, material, opts)
end

-- A floor: solid, in the persistent model (a goblin teleported here never arrives before the ground does).
local function floor(name, size, cf, color, material)
	return part(name, size, cf, color, material, { parent = core })
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function upright(cf)
	return cf * UPRIGHT
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

-- A plank sign with big painted letters (SurfaceGui on both faces).
local function board(name, size, cf, text, textColor, back, parent)
	local p = part(name, size, cf, back or WOOD_DARK, PLANKS, { parent = parent or town, collide = false })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face" .. face.Name
		gui.Face = face
		gui.LightInfluence = 0.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = p
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextColor3 = textColor or GOLD
		label.TextScaled = true
		label.TextStrokeColor3 = rgb(40, 24, 14)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.08, 0), UDim.new(0.08, 0)
		pad.Parent = label
	end
	return p
end

-- A prompt on an invisible pad. attributes: { OpensWardrobe = "...", PortAction = "..." }.
local function prompt(name, cf, objectText, actionText, attributes, distance)
	local pad = deco(name, Vector3.new(4, 4, 4), cf, GOLD, SMOOTH, { transparency = 1, parent = core })
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name .. "Prompt"
	pp.ObjectText = objectText
	pp.ActionText = actionText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = distance or 12
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	for key, value in pairs(attributes or {}) do
		pp:SetAttribute(key, value)
	end
	pp.Parent = pad
	return pp, pad
end

-- A little goblin shopkeeper (the same chunky style as Madame Ragwort on the skyship).
local function shopkeeper(name, cf, coat, hat)
	local function ball(n, size, offset, color, material)
		return deco(name .. n, size, cf * offset, color, material or SMOOTH, { egg = true, shadow = false })
	end
	ball("Body", Vector3.new(2.6, 3, 2), CFrame.new(0, 1.6, 0), coat, FABRIC)
	ball("Head", Vector3.new(1.8, 1.7, 1.7), CFrame.new(0, 3.7, 0), SKIN)
	ball("Nose", Vector3.new(0.55, 0.55, 1), CFrame.new(0, 3.6, -0.95), SKIN)
	for _, side in ipairs({ -1, 1 }) do
		deco(
			name .. "Ear",
			Vector3.new(0.25, 0.7, 1.5),
			cf * CFrame.new(side * 1.2, 3.9, 0.1) * CFrame.Angles(0, math.rad(180 + side * -20), side * math.rad(-62)),
			SKIN,
			SMOOTH,
			{ wedge = true, shadow = false }
		)
		ball("Eye", Vector3.new(0.32, 0.32, 0.2), CFrame.new(side * 0.36, 3.95, -0.78), rgb(30, 26, 30))
		ball("Hand", Vector3.new(0.65, 0.65, 0.65), CFrame.new(side * 1.45, 1.6, -0.6), SKIN)
	end
	if hat == "tricorn" then
		deco(
			name .. "Hat",
			Vector3.new(0.6, 2.4, 2.4),
			upright(cf * CFrame.new(0, 4.55, 0)),
			rgb(40, 32, 38),
			FABRIC,
			{ cyl = true }
		)
	elseif hat == "bun" then
		ball("Bun", Vector3.new(1.2, 1.1, 1.2), CFrame.new(0, 4.7, 0.3), rgb(196, 196, 214))
	elseif hat == "cap" then
		deco(name .. "Cap", Vector3.new(2, 0.5, 2.2), cf * CFrame.new(0, 4.5, -0.1), TEAL, FABRIC)
		deco(name .. "Peak", Vector3.new(1.6, 0.2, 1), cf * CFrame.new(0, 4.3, -1.2), TEAL, FABRIC)
	elseif hat == "goggles" then
		for _, side in ipairs({ -1, 1 }) do
			deco(
				name .. "Goggle",
				Vector3.new(0.3, 0.6, 0.6),
				upright(cf * CFrame.new(side * 0.4, 4.0, -0.75) * CFrame.Angles(0, math.rad(90), 0)),
				rgb(200, 150, 60),
				METAL,
				{ cyl = true }
			)
		end
	end
end

local function lamp(x, z, height)
	height = height or 9
	part("LampPost", Vector3.new(0.7, height, 0.7), at(x, 6 + height / 2, z), WOOD_DARK, M_WOOD)
	deco("LampArm", Vector3.new(0.4, 0.4, 2.4), at(x, 6 + height - 0.4, z - 1), WOOD_DARK, M_WOOD)
	local glass = deco(
		"LampGlass",
		Vector3.new(1.4, 1.8, 1.4),
		at(x, 6 + height - 1.6, z - 2),
		rgb(255, 214, 130),
		NEON,
		{ shadow = false }
	)
	deco("LampCap", Vector3.new(1.8, 0.4, 1.8), at(x, 6 + height - 0.55, z - 2), WOOD_DARK, METAL)
	light(glass, rgb(255, 196, 120), 22, 1.2)
end

local function crate(x, y, z, size, turn)
	local s = size or 3
	part(
		"Crate",
		Vector3.new(s, s, s),
		at(x, y + s / 2, z) * CFrame.Angles(0, math.rad(turn or 0), 0),
		WOOD_LIGHT,
		PLANKS
	)
	deco(
		"CrateBand",
		Vector3.new(s + 0.08, s * 0.16, s + 0.08),
		at(x, y + s / 2, z) * CFrame.Angles(0, math.rad(turn or 0), 0),
		WOOD_DARK,
		M_WOOD
	)
end

local function barrel(x, y, z)
	part("Barrel", Vector3.new(3.2, 2.6, 2.6), upright(at(x, y + 1.6, z)), WOOD, PLANKS, { cyl = true })
	for _, dy in ipairs({ -0.9, 0.9 }) do
		deco(
			"BarrelHoop",
			Vector3.new(0.25, 2.75, 2.75),
			upright(at(x, y + 1.6 + dy, z)),
			STONE_DARK,
			METAL,
			{ cyl = true, shadow = false }
		)
	end
end

-- A string of triangle flags between two points.
local function bunting(a, b, colors)
	local count = math.max(3, math.floor((b - a).Magnitude / 3.2))
	local sag = 3
	for i = 0, count - 1 do
		local f = (i + 0.5) / count
		local p = a:Lerp(b, f) - Vector3.new(0, math.sin(f * math.pi) * sag, 0)
		local dir = (b - a).Unit
		deco(
			"Pennant",
			Vector3.new(0.1, 1.5, 1.2),
			CFrame.lookAt(p, p + Vector3.new(dir.Z, 0, -dir.X)) * CFrame.Angles(0, math.rad(90), math.rad(180)),
			colors[(i % #colors) + 1],
			FABRIC,
			{ wedge = true, shadow = false }
		)
	end
	local mid = (a + b) / 2 - Vector3.new(0, sag * 0.6, 0)
	deco("BuntingLine", Vector3.new(0.12, 0.12, (b - a).Magnitude), CFrame.lookAt(mid, b), ROPE, FABRIC)
end

-- Terrain: a basin of sea with a sand-and-grass island in it ------------------------------------------------------------
local function buildTerrain()
	local T = workspace.Terrain
	local half = 900
	T:FillBlock(CFrame.new(C + Vector3.new(0, -34, 0)), Vector3.new(half * 2, 12, half * 2), Enum.Material.Mud)
	-- The island: a flat grassy top on a sand skirt, with a few lobes so its coast is not a circle.
	local lobes = {
		{ 0, 60, 205, 172 },
		{ -95, 130, 90, 74 },
		{ 110, 120, 96, 78 },
		{ 130, -10, 80, 66 },
		{ -130, -30, 74, 62 },
		{ 30, 205, 70, 56 },
	}
	for _, lobe in ipairs(lobes) do
		local x, z, sand, grass = lobe[1], lobe[2], lobe[3], lobe[4]
		T:FillCylinder(CFrame.new(C.X + x, -15, C.Z + z), 30, sand, Enum.Material.Sand)
		T:FillCylinder(CFrame.new(C.X + x, -13.5, C.Z + z), 33, grass, Enum.Material.Grass)
	end
	-- The water: poured into every gap below the surface, in tiles (one huge region could pass the engine's limit).
	local tile = 512
	for x = -half, half - 1, tile do
		for z = -half, half - 1, tile do
			local region = Region3.new(
				Vector3.new(C.X + x, -28, C.Z + z),
				Vector3.new(C.X + math.min(x + tile, half), 0, C.Z + math.min(z + tile, half))
			)
			T:ReplaceMaterial(region:ExpandToGrid(4), 4, Enum.Material.Air, Enum.Material.Water)
		end
	end
end

-- The plaza, the fountain, the bounce pads -------------------------------------------------------------------------------
local function buildPlaza()
	floor("Plaza", Vector3.new(1.2, 128, 128), upright(at(0, 5.4, 0)), rgb(196, 182, 160), COBBLE).Shape =
		Enum.PartType.Cylinder
	deco(
		"PlazaRing",
		Vector3.new(1.3, 130, 130),
		upright(at(0, 5.38, 0)),
		rgb(150, 132, 112),
		COBBLE,
		{ cyl = true, shadow = false }
	)
	-- A star of paler stone underfoot pointing at the four doors.
	for i = 0, 3 do
		deco(
			"PlazaPath",
			Vector3.new(10, 0.1, 124),
			at(0, 6.06, 0) * CFrame.Angles(0, math.rad(i * 45), 0),
			rgb(226, 212, 186),
			COBBLE,
			{ shadow = false }
		)
	end
	-- The fountain: a round basin with the Golden Goblin holding a chest over his head, coins spilling out.
	part("FountainRim", Vector3.new(3, 26, 26), upright(at(0, 7, 0)), STONE, COBBLE, { cyl = true })
	deco(
		"FountainWater",
		Vector3.new(0.4, 23, 23),
		upright(at(0, 8.4, 0)),
		rgb(80, 190, 220),
		GLASS,
		{ cyl = true, transparency = 0.35, shadow = false }
	)
	part("FountainPlinth", Vector3.new(6, 6, 6), upright(at(0, 11, 0)), STONE_DARK, SLATE, { cyl = true })
	local gold = { 255, 200, 60 }
	local G = rgb(gold[1], gold[2], gold[3])
	deco("StatueLegs", Vector3.new(2.6, 3.4, 1.6), at(0, 15.6, 0), G, METAL, { egg = true })
	deco("StatueBody", Vector3.new(3.6, 4.4, 2.8), at(0, 18.8, 0), G, METAL, { egg = true })
	deco("StatueHead", Vector3.new(3.2, 3, 3), at(0, 22.4, -0.2), G, METAL, { egg = true })
	deco("StatueNose", Vector3.new(1, 1, 1.9), at(0, 22.2, -1.9), G, METAL, { egg = true })
	for _, side in ipairs({ -1, 1 }) do
		deco(
			"StatueEar",
			Vector3.new(0.5, 1.4, 3.2),
			at(side * 2.1, 22.9, 0) * CFrame.Angles(0, math.rad(180 + side * -20), side * math.rad(-60)),
			G,
			METAL,
			{ wedge = true }
		)
		deco(
			"StatueArm",
			Vector3.new(1, 4.2, 1),
			at(side * 1.9, 22, 0) * CFrame.Angles(0, 0, side * math.rad(-18)),
			G,
			METAL,
			{ egg = true }
		)
		local eye = deco(
			"StatueEye",
			Vector3.new(0.5, 0.5, 0.3),
			at(side * 0.6, 22.8, -1.4),
			rgb(110, 255, 210),
			NEON,
			{ egg = true, shadow = false }
		)
		eye.CastShadow = false
	end
	deco("StatueChest", Vector3.new(4.4, 2.6, 3), at(0, 25.6, 0), WOOD, PLANKS)
	deco(
		"StatueChestLid",
		Vector3.new(4.5, 1.2, 3.1),
		at(0, 27.2, 0.4) * CFrame.Angles(math.rad(-25), 0, 0),
		WOOD,
		PLANKS
	)
	for i = 1, 7 do
		local a = i * 0.9
		deco(
			"StatueCoin",
			Vector3.new(0.9, 0.9, 0.9),
			at(math.cos(a) * 1.4, 27.6 + (i % 3) * 0.4, math.sin(a) * 0.9),
			G,
			METAL,
			{ ball = true, shadow = false }
		)
	end
	local spray = deco("FountainSpray", Vector3.new(1, 1, 1), at(0, 9, 0), G, SMOOTH, { transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rgb(255, 230, 140), rgb(170, 230, 255))
	emitter.Size = NumberSequence.new(0.6, 0.1)
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.Speed = NumberRange.new(10, 16)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Acceleration = Vector3.new(0, -24, 0)
	emitter.Rate = 18
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.6
	emitter.Parent = spray
	light(spray, rgb(255, 210, 120), 26, 1.4)

	-- Bounce pads: two big mushroom-cap trampolines either side of the fountain (the client launches you).
	for _, side in ipairs({ -1, 1 }) do
		local x, z = side * 42, 18
		part("PadStalk", Vector3.new(2.4, 3, 3), upright(at(x, 7.2, z)), CANVAS, SMOOTH, { cyl = true })
		local pad = Instance.new("Part")
		pad.Name = "LaunchPad"
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(0.8, 9, 9)
		pad.CFrame = upright(at(x, 8.8, z))
		pad.Color = side < 0 and RED or TEAL
		pad.Material = SMOOTH
		pad.Anchored = true
		pad.CanCollide = true
		pad:SetAttribute("Launch", Vector3.new(0, 118, 0))
		pad.Parent = refs.folders.launchPads
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			deco(
				"PadSpot",
				Vector3.new(0.2, 1.4, 1.4),
				upright(at(x + math.cos(a) * 2.8, 9.25, z + math.sin(a) * 2.8)),
				rgb(255, 250, 236),
				SMOOTH,
				{ cyl = true, shadow = false }
			)
		end
	end

	-- Where goblins arrive: two rings round the fountain, facing the boarding dock (north).
	for ring, radius in ipairs({ 24, 32 }) do
		local count = ring == 1 and 10 or 14
		for i = 0, count - 1 do
			local a = (i + (ring == 1 and 0 or 0.5)) / count * math.pi * 2
			local x, z = math.cos(a) * radius, math.sin(a) * radius
			table.insert(spawnPoints, at(x, 9.5, z)) -- facing north, toward the boarding dock
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PortSpawn"
	spawn.Size = Vector3.new(14, 0.4, 14)
	spawn.CFrame = at(0, 6.2, 30)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = core

	-- Lamps round the edge, bunting between them, a few stalls.
	local lamps = {}
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local x, z = math.cos(a) * 60, math.sin(a) * 60
		lamp(x, z, 10)
		table.insert(lamps, Vector3.new(C.X + x, 6 + 9.6, C.Z + z))
	end
	local colors = { RED, GOLD, TEAL, rgb(255, 250, 236), PURPLE }
	for i = 1, #lamps do
		bunting(lamps[i], lamps[i % #lamps + 1], colors)
	end
	local stalls = {
		{ -40, -40, 45, "MAPS", rgb(232, 210, 160) },
		{ 40, 42, -135, "FISH", rgb(120, 200, 230) },
		{ -42, 30, 135, "SNACKS", rgb(255, 170, 90) },
	}
	for _, s in ipairs(stalls) do
		local base = at(s[1], 6, s[2]) * CFrame.Angles(0, math.rad(s[3]), 0)
		part("StallCounter", Vector3.new(8, 3, 3), base * CFrame.new(0, 1.5, 0), WOOD_LIGHT, PLANKS)
		for _, px in ipairs({ -3.8, 3.8 }) do
			deco("StallPost", Vector3.new(0.5, 7, 0.5), base * CFrame.new(px, 3.5, 1.2), WOOD_DARK, M_WOOD)
		end
		for k = 0, 4 do
			deco(
				"StallAwning",
				Vector3.new(1.75, 0.3, 4.4),
				base * CFrame.new(-3.5 + k * 1.75, 7.2, 0.4) * CFrame.Angles(math.rad(12), 0, 0),
				k % 2 == 0 and RED or rgb(250, 244, 230),
				FABRIC
			)
		end
		board("StallSign", Vector3.new(6, 1.4, 0.3), base * CFrame.new(0, 8.3, -1.6), s[4], s[5])
		for k = 0, 3 do
			deco(
				"StallGoods",
				Vector3.new(1.1, 1.1, 1.1),
				base * CFrame.new(-2.6 + k * 1.7, 3.5, 0),
				s[5]:Lerp(rgb(255, 255, 255), (k % 2) * 0.3),
				SMOOTH,
				{ egg = true }
			)
		end
	end
	crate(-52, 6, -18, 3, 20)
	crate(-49, 6, -21, 2.4, 50)
	barrel(52, 6, 18)
	barrel(55, 6, 14)
	crate(50, 6, -46, 3, 10)
end

-- An arch over a street out of the plaza, with a painted sign.
local function arch(x, z, yaw, text, color)
	local base = at(x, 6, z) * CFrame.Angles(0, math.rad(yaw), 0)
	for _, side in ipairs({ -1, 1 }) do
		part("ArchPost", Vector3.new(1.6, 14, 1.6), base * CFrame.new(side * 9, 7, 0), WOOD_DARK, M_WOOD)
		deco("ArchCap", Vector3.new(2.2, 1, 2.2), base * CFrame.new(side * 9, 14.4, 0), GOLD, METAL)
	end
	deco("ArchBeam", Vector3.new(20, 1.2, 1.2), base * CFrame.new(0, 13.2, 0), WOOD_DARK, M_WOOD)
	board("ArchSign", Vector3.new(16, 3.2, 0.4), base * CFrame.new(0, 15.6, 0), text, color)
end

-- The boarding dock and the moored airship (north) -------------------------------------------------------------------------
local function buildDeparture()
	-- The pier: from the plaza's edge out over the water.
	floor("BoardingPier", Vector3.new(20, 1.4, 120), at(0, 5.3, -118), WOOD_LIGHT, PLANKS)
	for z = -66, -172, -12 do
		for _, side in ipairs({ -1, 1 }) do
			part("PierPost", Vector3.new(1.6, 14, 1.6), at(side * 10.2, -1, z), WOOD_DARK, M_WOOD)
			deco("PierRope", Vector3.new(0.3, 0.3, 12), at(side * 10.2, 7.6, z - 6), ROPE, FABRIC, { shadow = false })
		end
	end
	for i = 0, 4 do
		lamp(i % 2 == 0 and -10.5 or 10.5, -80 - i * 22, 8)
	end
	-- The boarding platform and the gangplank up to the airship's deck.
	floor("BoardingPlatform", Vector3.new(34, 1.4, 26), at(0, 5.3, -188), WOOD, PLANKS)
	local foot, top = Vector3.new(C.X, 6, C.Z - 200), Vector3.new(C.X, 22, C.Z - 238)
	local mid = (foot + top) / 2
	local gangplank = floor(
		"Gangplank",
		Vector3.new(9, 0.8, (top - foot).Magnitude + 1),
		CFrame.lookAt(mid, top) * CFrame.new(0, -0.4, 0),
		WOOD_LIGHT,
		PLANKS
	)
	gangplank:SetAttribute("Gangplank", true)
	for _, side in ipairs({ -1, 1 }) do
		deco(
			"GangRail",
			Vector3.new(0.4, 0.4, (top - foot).Magnitude),
			CFrame.lookAt(mid, top) * CFrame.new(side * 4.4, 3, 0),
			ROPE,
			FABRIC
		)
	end
	-- The airship: a little round-bellied launch with a gold stripe, a striped balloon and propellers. Its deck is
	-- the READY zone.
	local deckCF = at(0, 21.4, -262)
	floor("AirshipDeck", Vector3.new(26, 1.2, 44), deckCF, WOOD, PLANKS)
	readyBox = { cframe = deckCF * CFrame.new(0, 5, 0), size = Vector3.new(28, 12, 46) }
	for _, side in ipairs({ -1, 1 }) do
		part("AirshipRail", Vector3.new(1, 3, 44), deckCF * CFrame.new(side * 12.6, 2, 0), WOOD_DARK, M_WOOD)
		deco(
			"AirshipHull",
			Vector3.new(2.4, 7, 46),
			deckCF * CFrame.new(side * 11.6, -3.4, 0) * CFrame.Angles(0, 0, side * math.rad(-22)),
			WOOD_LIGHT,
			PLANKS
		)
		deco("AirshipStripe", Vector3.new(0.6, 1.2, 46), deckCF * CFrame.new(side * 13.2, -1, 0), GOLD, METAL)
		-- Propellers at the stern (the far end: the gangplank comes aboard over the bow).
		deco(
			"AirshipProp",
			Vector3.new(1.6, 9, 1),
			deckCF * CFrame.new(side * 9, -4, -23.5) * CFrame.Angles(0, 0, math.rad(30)),
			WOOD_DARK,
			M_WOOD
		)
	end
	floor("AirshipBow", Vector3.new(26, 1.2, 4), deckCF * CFrame.new(0, 0, 24), WOOD, PLANKS)
	part("AirshipStern", Vector3.new(26, 6, 1.2), deckCF * CFrame.new(0, 3, -22.4), WOOD_DARK, PLANKS)
	deco("AirshipKeel", Vector3.new(14, 6, 40), deckCF * CFrame.new(0, -6, 0), WOOD_DARK, PLANKS, { egg = true })
	-- The balloon: a long striped envelope on ropes.
	local balloonCF = deckCF * CFrame.new(0, 26, 0)
	deco("Balloon", Vector3.new(24, 20, 48), balloonCF, rgb(244, 232, 204), FABRIC, { egg = true })
	for k = -2, 2 do
		deco(
			"BalloonStripe",
			Vector3.new(24.3, 20.3, 3),
			balloonCF * CFrame.new(0, 0, k * 9),
			k % 2 == 0 and RED or GOLD,
			FABRIC,
			{ egg = true }
		)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local a = deckCF * CFrame.new(sx * 11, 1, sz * 18)
			local b = balloonCF * CFrame.new(sx * 8, -8, sz * 16)
			local m = (a.Position + b.Position) / 2
			deco(
				"BalloonRope",
				Vector3.new(0.3, 0.3, (b.Position - a.Position).Magnitude),
				CFrame.lookAt(m, b.Position),
				ROPE,
				FABRIC,
				{ shadow = false }
			)
		end
	end
	board(
		"AirshipName",
		Vector3.new(20, 3, 0.4),
		deckCF * CFrame.new(0, 7.4, -22.2),
		"THE LITTLE GOBLIN",
		GOLD,
		WOOD_DARK,
		core
	)
	-- The ready ring on the deck and a lantern on each corner.
	-- (Painted, not neon: a 20-stud neon disc bloomed into a blinding yellow floor in the first playtest.)
	local ring = deco(
		"ReadyRing",
		Vector3.new(0.3, 20, 20),
		upright(deckCF * CFrame.new(0, 0.7, 0)),
		GOLD,
		SMOOTH,
		{ cyl = true, transparency = 0.6, shadow = false, parent = core }
	)
	ring.Name = "ReadyRing"
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local l = deco(
				"AirshipLantern",
				Vector3.new(1.4, 1.8, 1.4),
				deckCF * CFrame.new(sx * 12, 4.5, sz * 20),
				rgb(255, 214, 130),
				NEON,
				{ shadow = false }
			)
			light(l, rgb(255, 196, 120), 18, 1)
		end
	end
	-- The departures board at the start of the pier: the client writes the countdown on it.
	local boardPart = board(
		"DepartureBoard",
		Vector3.new(18, 7, 0.6),
		at(0, 16, -66) * CFrame.Angles(0, math.rad(180), 0),
		"TO THE SKYSHIP",
		GOLD,
		rgb(40, 26, 18),
		core
	)
	boardPart.Name = "DepartureBoard"
	for _, side in ipairs({ -1, 1 }) do
		part("BoardPost", Vector3.new(1.2, 13, 1.2), at(side * 9.4, 12, -66), WOOD_DARK, M_WOOD)
	end
	-- Join the raid that is running (enabled by Port.tick while late entry is open).
	local join = prompt("JoinRaid", at(0, 8, -72), "The skyship", "Join the raid", { PortAction = "join" }, 14)
	join.Enabled = false
	Port.joinPrompt = join
	local aboard = prompt("Board", at(0, 8, -186), "The Little Goblin", "Get ready (walk aboard)", nil, 10)
	aboard.Enabled = false -- information only: walking up the plank is what counts
end

-- The shipyard (west): one slipway per boat class ------------------------------------------------------------------------
local function buildShipyard(displayModel)
	arch(-64, 0, 90, "SHIPYARD", rgb(150, 230, 255))
	floor("ShipyardQuay", Vector3.new(56, 1.4, 228), at(-112, 5.3, 24), WOOD_LIGHT, PLANKS)
	shopkeeper("Rivet", at(-100, 6.2, -14) * CFrame.Angles(0, math.rad(-90), 0), rgb(70, 110, 160), "goggles")
	local slots = {}
	for i, entry in ipairs(Config.BOAT_CLASSES) do
		local z = -78 + (i - 1) * 30
		-- The slipway: a ramp down into the lagoon, rails, and a cradle the boat rests on.
		local foot, top = Vector3.new(C.X - 206, -6, C.Z + z), Vector3.new(C.X - 138, 5.4, C.Z + z)
		local mid = (foot + top) / 2
		part(
			"Slipway",
			Vector3.new(16, 1.2, (top - foot).Magnitude),
			CFrame.lookAt(mid, foot) * CFrame.new(0, -0.6, 0),
			rgb(150, 120, 90),
			PLANKS
		)
		for _, side in ipairs({ -1, 1 }) do
			deco(
				"SlipRail",
				Vector3.new(0.8, 0.8, (top - foot).Magnitude),
				CFrame.lookAt(mid, foot) * CFrame.new(side * 6, 0.3, 0),
				STONE_DARK,
				METAL
			)
		end
		local spec = Config.BOAT_TYPES[entry.id]
		local cradle = at(-162, 4.2 + spec.size.Y / 2 - spec.draft * 0.25, z) * CFrame.Angles(0, math.rad(90), 0)
		table.insert(slots, { id = entry.id, cframe = cradle })
		-- Two chocks between the slipway and the hull, so the boat sits on something.
		for _, along in ipairs({ -spec.size.Z * 0.28, spec.size.Z * 0.28 }) do
			local chock = cradle * CFrame.new(0, -spec.size.Y / 2, along)
			local slipY = 5.4 - ((C.X - 138) - chock.Position.X) / 68 * 11.4
			local height = math.max(0.6, chock.Position.Y - slipY)
			deco(
				"Chock",
				Vector3.new(spec.size.X * 0.7, height, 2),
				CFrame.new(chock.Position.X, slipY + height / 2, chock.Position.Z),
				WOOD_DARK,
				M_WOOD
			)
		end
		if displayModel then
			local model = displayModel(entry.id)
			if model then
				model:PivotTo(cradle)
				model.Name = "Display_" .. entry.id
				-- Its hull is solid, so a goblin can climb aboard a display boat and stand at the wheel.
				local hull = model:FindFirstChild("Hull")
				if hull then
					hull.CanCollide = true
					hull.CanQuery = true
				end
				model.Parent = town
			end
		end
		-- The class's board on a post at the quay end.
		local post = at(-128, 6, z + 10)
		part("SlipPost", Vector3.new(1, 10, 1), post * CFrame.new(0, 5, 0), WOOD_DARK, M_WOOD)
		board(
			"ClassBoard",
			Vector3.new(9, 3.2, 0.4),
			post * CFrame.new(0, 9.4, 0) * CFrame.Angles(0, math.rad(90), 0),
			string.upper(spec.name) .. "\n" .. entry.role,
			i <= 2 and rgb(150, 255, 160) or GOLD
		)
		prompt(
			"LookAt_" .. entry.id,
			at(-124, 8, z),
			spec.name,
			"Look at it",
			{ OpensWardrobe = "boat:" .. entry.id },
			14
		)
	end
	-- A crane over the yard, and a stack of timber.
	part("CraneMast", Vector3.new(2, 34, 2), at(-100, 23, 118), WOOD_DARK, M_WOOD)
	deco(
		"CraneJib",
		Vector3.new(1.6, 1.6, 40),
		at(-100, 39, 100) * CFrame.Angles(math.rad(-8), 0, 0),
		WOOD_DARK,
		M_WOOD
	)
	deco("CraneHook", Vector3.new(0.3, 16, 0.3), at(-100, 30, 82), ROPE, FABRIC)
	deco("CraneLoad", Vector3.new(4, 3, 4), at(-100, 21, 82), WOOD_LIGHT, PLANKS)
	for k = 0, 4 do
		part(
			"Timber",
			Vector3.new(1.4, 1.4, 14),
			at(-88 + k * 1.5, 6.7 + (k % 2) * 1.4, 112),
			WOOD,
			M_WOOD,
			{ collide = true }
		)
	end
	core:SetAttribute(
		"Slipways",
		game:GetService("HttpService"):JSONEncode((function()
			local out = {}
			for _, s in ipairs(slots) do
				local p = s.cframe.Position
				table.insert(out, { id = s.id, x = p.X, y = p.Y, z = p.Z })
			end
			return out
		end)())
	)
end

-- The menagerie (east): four themed pens, filled with pets by every client --------------------------------------------------
local PENS = {
	{ theme = "ocean", x = 112, z = -42, color = rgb(80, 190, 230) },
	{ theme = "pirate", x = 150, z = -42, color = rgb(214, 150, 70) },
	{ theme = "magic", x = 112, z = 34, color = rgb(186, 120, 255) },
	{ theme = "island", x = 150, z = 34, color = rgb(120, 214, 110) },
}
local PEN_SIZE = 32
local PEN_NAMES = { ocean = "OCEAN", pirate = "PIRATE", magic = "MAGIC", island = "ISLAND" }

local function buildMenagerie()
	arch(64, 0, -90, "PET MENAGERIE", rgb(255, 196, 220))
	floor("MenageriePath", Vector3.new(80, 1.2, 14), at(108, 5.4, -4), rgb(214, 196, 160), COBBLE)
	-- The keeper's pavilion.
	local pav = at(84, 6, -4) * CFrame.Angles(0, math.rad(90), 0) -- its front (-Z) faces the plaza (west)
	part("PetCounter", Vector3.new(12, 3.2, 3), pav * CFrame.new(0, 1.6, -3), WOOD_LIGHT, PLANKS)
	for _, px in ipairs({ -6, 6 }) do
		for _, pz in ipairs({ -4.5, 3 }) do
			part("PavilionPost", Vector3.new(0.7, 10, 0.7), pav * CFrame.new(px, 5, pz), WOOD_DARK, M_WOOD)
		end
	end
	for k = 0, 6 do
		deco(
			"PavilionAwning",
			Vector3.new(1.85, 0.3, 9.6),
			pav * CFrame.new(-5.5 + k * 1.85, 10.4, -0.6) * CFrame.Angles(math.rad(10), 0, 0),
			k % 2 == 0 and rgb(255, 150, 190) or rgb(250, 244, 230),
			FABRIC
		)
	end
	board(
		"PetSign",
		Vector3.new(12, 2.2, 0.4),
		pav * CFrame.new(0, 12.2, -5.2),
		"MOTHER MOSSBACK'S PETS",
		rgb(255, 214, 230)
	)
	shopkeeper("Mossback", pav * CFrame.new(0, 0.2, 0.2), rgb(96, 150, 84), "bun")
	prompt(
		"PetShop",
		pav * CFrame.new(0, 2, -5),
		"Mother Mossback's Pets",
		"Adopt a pet",
		{ OpensWardrobe = "pet" },
		14
	)
	-- The pens: a low fence, a themed floor and props. The pets themselves are drawn by every client (client/PortLife).
	local pens = {}
	for _, pen in ipairs(PENS) do
		local base = at(pen.x, 6, pen.z)
		local s = PEN_SIZE
		local floorColor = ({
			ocean = rgb(232, 214, 168),
			pirate = WOOD_LIGHT,
			magic = rgb(100, 82, 130),
			island = rgb(222, 194, 140),
		})[pen.theme]
		floor(
			"PenFloor",
			Vector3.new(s, 0.6, s),
			base * CFrame.new(0, -0.1, 0),
			floorColor,
			pen.theme == "pirate" and PLANKS or SMOOTH
		)
		for _, side in ipairs({ -1, 1 }) do
			for axis = 0, 1 do
				local offset = axis == 0 and CFrame.new(side * s / 2, 1.2, 0) or CFrame.new(0, 1.2, side * s / 2)
				local size = axis == 0 and Vector3.new(0.5, 0.4, s) or Vector3.new(s, 0.4, 0.5)
				-- the side facing the path is open (a gate), so goblins walk in among the pets
				local open = axis == 1 and ((pen.z < 0 and side == 1) or (pen.z > 0 and side == -1))
				if not open then
					part("PenRail", size, base * offset, WOOD_DARK, M_WOOD)
					part("PenRailLow", size, base * offset * CFrame.new(0, -0.8, 0), WOOD_DARK, M_WOOD)
				end
			end
		end
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				part(
					"PenPost",
					Vector3.new(0.8, 3, 0.8),
					base * CFrame.new(cx * s / 2, 1.1, cz * s / 2),
					WOOD_DARK,
					M_WOOD
				)
			end
		end
		board(
			"PenSign",
			Vector3.new(8, 1.8, 0.3),
			base * CFrame.new(0, 3.2, (pen.z < 0 and 1 or -1) * (s / 2 + 0.3)),
			PEN_NAMES[pen.theme],
			pen.color
		)
		-- Theme props.
		if pen.theme == "ocean" then
			deco(
				"Pool",
				Vector3.new(0.4, 16, 16),
				upright(base * CFrame.new(-4, 0.3, -4)),
				rgb(80, 190, 230),
				GLASS,
				{ cyl = true, transparency = 0.25 }
			)
			for k = 0, 4 do
				deco(
					"PoolRock",
					Vector3.new(2.6, 1.8, 2.2),
					base * CFrame.new(-4 + math.cos(k * 1.3) * 8.6, 0.6, -4 + math.sin(k * 1.3) * 8.6),
					Palette.ROCK_LIGHT,
					SLATE,
					{ egg = true }
				)
			end
		elseif pen.theme == "pirate" then
			crate(pen.x - 10, 6, pen.z - 9, 3, 15)
			crate(pen.x - 8, 9, pen.z - 9, 2.2, 40)
			barrel(pen.x + 10, 6, pen.z + 9)
			deco("PenFlagPole", Vector3.new(0.4, 9, 0.4), base * CFrame.new(10, 4.5, -10), WOOD_DARK, M_WOOD)
			deco("PenFlag", Vector3.new(0.2, 2.4, 3.6), base * CFrame.new(10, 8, -8.2), rgb(30, 28, 34), FABRIC)
		elseif pen.theme == "magic" then
			for k = 0, 5 do
				local crystal = deco(
					"PenCrystal",
					Vector3.new(1.2, 3 + (k % 3), 1.2),
					base * CFrame.new(math.cos(k) * 11, 1.6, math.sin(k) * 11) * CFrame.Angles(0.2, k, 0.3),
					k % 2 == 0 and Palette.CRYSTAL or Palette.CRYSTAL_CYAN,
					NEON,
					{ transparency = 0.15, shadow = false }
				)
				if k % 2 == 0 then
					light(crystal, crystal.Color, 10, 0.8)
				end
			end
		else
			deco(
				"PenSand",
				Vector3.new(0.3, 14, 14),
				upright(base * CFrame.new(4, 0.25, 4)),
				Palette.SAND,
				SMOOTH,
				{ cyl = true }
			)
			for k = 0, 2 do
				deco(
					"PenStone",
					Vector3.new(2.4, 1.6, 2),
					base * CFrame.new(-8 + k * 5, 0.6, 9),
					Palette.ROCK,
					SLATE,
					{ egg = true }
				)
			end
		end
		table.insert(pens, { theme = pen.theme, x = C.X + pen.x, y = 6.3, z = C.Z + pen.z, size = s - 4 })
	end
	core:SetAttribute("Pens", game:GetService("HttpService"):JSONEncode(pens))
end

-- The wardrobe (south): Madame Ragwort's shop, with mannequins in the window ------------------------------------------------
local WINDOW_LOOKS = {
	{ hat = "hat_captain", outfit = "outfit_captain", face = "face_beard" },
	{ hat = "hat_crown", outfit = "outfit_royal", eyes = "eyes_monocle", back = "back_cape" },
	{ hat = "hat_feather", outfit = "outfit_formal", eyes = "eyes_shades", skin = "skin_violet" },
}

local function mannequinOn(cf, look, parent)
	local model = Wardrobe.mannequin()
	Wardrobe.dress(model, Catalog.withDefaults(look))
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	-- Stand it with its feet on cf (the parts are anchored, so a pivot moves the whole dressed figure).
	local pivot = model:GetPivot()
	local offset = pivot.Position - Vector3.new(box.Position.X, bottom, box.Position.Z)
	model:PivotTo(CFrame.new(cf.Position + offset) * cf.Rotation)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.Parent = parent or town
	return model
end

local function buildWardrobe()
	arch(0, 64, 0, "WARDROBE", rgb(255, 214, 120))
	local base = at(0, 6, 112)
	-- The house: plaster walls, timber frame, a red roof, a big shop window facing the plaza.
	part("ShopFloor", Vector3.new(34, 1, 24), base * CFrame.new(0, 0, 0), WOOD, PLANKS)
	part("ShopBack", Vector3.new(34, 18, 1.2), base * CFrame.new(0, 9, 11.4), rgb(244, 232, 204), SMOOTH)
	for _, side in ipairs({ -1, 1 }) do
		part("ShopSide", Vector3.new(1.2, 18, 24), base * CFrame.new(side * 16.4, 9, 0), rgb(244, 232, 204), SMOOTH)
		deco("ShopBeam", Vector3.new(1.4, 18.2, 1.4), base * CFrame.new(side * 16.6, 9, -11.6), WOOD_DARK, M_WOOD)
	end
	part("ShopFront", Vector3.new(34, 6, 1.2), base * CFrame.new(0, 15, -11.4), rgb(244, 232, 204), SMOOTH)
	deco("ShopFrontBeam", Vector3.new(34.4, 1.2, 1.4), base * CFrame.new(0, 12, -11.6), WOOD_DARK, M_WOOD)
	deco(
		"ShopWindow",
		Vector3.new(30, 10, 0.4),
		base * CFrame.new(0, 6.5, -11.2),
		rgb(190, 230, 255),
		GLASS,
		{ transparency = 0.7 }
	)
	for _, side in ipairs({ -1, 1 }) do
		deco(
			"Roof",
			Vector3.new(36, 1.4, 16),
			base * CFrame.new(0, 21, side * 6.4) * CFrame.Angles(side * math.rad(28), 0, 0),
			rgb(196, 70, 54),
			SLATE
		)
	end
	deco("Chimney", Vector3.new(3, 8, 3), base * CFrame.new(11, 24, 4), STONE, COBBLE)
	board("WardrobeSign", Vector3.new(26, 4, 0.5), base * CFrame.new(0, 17.2, -12.4), "MADAME RAGWORT'S WARDROBE", GOLD)
	-- A striped awning over the counter out front.
	for k = 0, 9 do
		deco(
			"ShopAwning",
			Vector3.new(3.4, 0.3, 7),
			base * CFrame.new(-15.3 + k * 3.4, 11.4, -14.6) * CFrame.Angles(math.rad(16), 0, 0),
			k % 2 == 0 and PURPLE or rgb(250, 244, 230),
			FABRIC
		)
	end
	part("ShopCounter", Vector3.new(12, 3.2, 3), base * CFrame.new(0, 2.1, -17), WOOD_LIGHT, PLANKS)
	shopkeeper("Ragwort", base * CFrame.new(0, 0.5, -14.5), PURPLE, "bun")
	prompt(
		"Wardrobe",
		base * CFrame.new(0, 3, -19),
		"Madame Ragwort's Wardrobe",
		"Shop and dress up",
		{ OpensWardrobe = "goblin" },
		14
	)
	-- The window: three goblins dressed in some of the best things she sells, on little plinths.
	for i, look in ipairs(WINDOW_LOOKS) do
		local x = -10 + (i - 1) * 10
		part("Plinth", Vector3.new(3.4, 1.2, 3.4), base * CFrame.new(x, 1.1, -6), STONE, COBBLE)
		mannequinOn(base * CFrame.new(x, 1.7, -6), look) -- facing out of the window, at the plaza
	end
	-- Racks of hats and coats either side.
	for _, side in ipairs({ -1, 1 }) do
		local rack = base * CFrame.new(side * 22, 0, -6)
		part("Rack", Vector3.new(0.5, 7, 0.5), rack * CFrame.new(0, 3.5, 0), WOOD_DARK, M_WOOD)
		deco("RackArm", Vector3.new(4, 0.3, 0.3), rack * CFrame.new(0, 6.6, 0), WOOD_DARK, M_WOOD)
		for k = -1, 1 do
			deco(
				"RackCoat",
				Vector3.new(1.2, 2.8, 0.2),
				rack * CFrame.new(k * 1.3, 5, 0),
				({ RED, TEAL, rgb(70, 110, 200) })[k + 2],
				FABRIC
			)
		end
	end
end

-- The podium (south-west) and the champion's statue ------------------------------------------------------------------------
local function buildPodium()
	local base = at(-56, 6, 52) * CFrame.Angles(0, math.rad(-45), 0) -- its front (-Z) faces the fountain
	local steps = { { 0, 6, 1 }, { -7, 4, 2 }, { 7, 2.5, 3 } }
	for _, s in ipairs(steps) do
		local x, h, place = s[1], s[2], s[3]
		local color = place == 1 and GOLD or (place == 2 and rgb(210, 214, 224) or rgb(214, 140, 80))
		floor("Podium" .. place, Vector3.new(6.6, h, 6.6), base * CFrame.new(x, h / 2, 0), color, METAL)
		board(
			"PodiumNumber",
			Vector3.new(3, 2, 0.2),
			base * CFrame.new(x, h / 2, -3.42),
			tostring(place),
			rgb(255, 255, 255),
			color
		)
		podiumSpots[place] = base * CFrame.new(x, h + 3.2, 0) -- facing the plaza
	end
	-- Behind it: the champion's plinth and statue, and a banner.
	local plinth = base * CFrame.new(0, 0, 9)
	part("ChampionPlinth", Vector3.new(7, 9, 7), plinth * CFrame.new(0, 4.5, 0), STONE_DARK, SLATE, { parent = core })
	deco("ChampionTrim", Vector3.new(7.4, 0.8, 7.4), plinth * CFrame.new(0, 9, 0), GOLD, METAL, { parent = core })
	Port.statueSpot = plinth * CFrame.new(0, 9.4, 0)
	local banner = board(
		"ChampionBanner",
		Vector3.new(14, 3.4, 0.4),
		plinth * CFrame.new(0, 19.5, 1.4),
		"NO CHAMPION YET",
		GOLD,
		rgb(110, 44, 150),
		core
	)
	statueLabel = banner
	for _, side in ipairs({ -1, 1 }) do
		part("BannerPole", Vector3.new(0.6, 21, 0.6), plinth * CFrame.new(side * 7.4, 10.5, 1.4), WOOD_DARK, M_WOOD)
	end
end

-- The Spyglass (north-east): a tower with a telescope, where goblins watch the raid ----------------------------------------
local function buildSpyglass()
	-- Its front (-Z) faces the plaza (south-west of it); the telescope on top points north, at the raid.
	local base = at(70, 6, -70) * CFrame.Angles(0, math.rad(135), 0)
	local axis = at(70, 6, -70)
	-- The tower goes down into the ground, so it stands on the island whatever the ground's exact height.
	part("TowerBase", Vector3.new(50, 18, 18), upright(axis * CFrame.new(0, 7, 0)), STONE, COBBLE, { cyl = true })
	for k = 0, 2 do
		deco(
			"TowerBand",
			Vector3.new(1, 18.6, 18.6),
			upright(axis * CFrame.new(0, 2 + k * 11, 0)),
			STONE_DARK,
			SLATE,
			{ cyl = true }
		)
	end
	part("TowerDeck", Vector3.new(1.4, 26, 26), upright(axis * CFrame.new(0, 32.7, 0)), WOOD, PLANKS, { cyl = true })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		deco(
			"TowerMerlon",
			Vector3.new(2.6, 2.4, 1.4),
			axis * CFrame.new(math.cos(a) * 12.4, 34.6, math.sin(a) * 12.4) * CFrame.Angles(0, -a, 0),
			STONE,
			COBBLE
		)
	end
	-- The great brass telescope (world north is -Z), tilted a little up at the horizon.
	local mount = axis * CFrame.new(0, 35, 0) * CFrame.Angles(math.rad(12), 0, 0)
	deco("ScopeStand", Vector3.new(1.4, 5, 1.4), axis * CFrame.new(0, 35.8, 0), WOOD_DARK, M_WOOD)
	deco(
		"Scope",
		Vector3.new(16, 3, 3),
		mount * CFrame.new(0, 3, -4) * CFrame.Angles(0, math.rad(90), 0),
		rgb(214, 160, 60),
		METAL,
		{ cyl = true }
	)
	deco(
		"ScopeLens",
		Vector3.new(0.6, 3.6, 3.6),
		mount * CFrame.new(0, 3, -12.2) * CFrame.Angles(0, math.rad(90), 0),
		rgb(190, 240, 255),
		NEON,
		{ cyl = true, shadow = false }
	)
	deco(
		"ScopeEye",
		Vector3.new(2, 1.8, 1.8),
		mount * CFrame.new(0, 3, 4.6) * CFrame.Angles(0, math.rad(90), 0),
		rgb(150, 110, 50),
		METAL,
		{ cyl = true }
	)
	board(
		"SpyglassSign",
		Vector3.new(12, 2.6, 0.4),
		base * CFrame.new(0, 12, -9.4),
		"THE SPYGLASS",
		rgb(150, 230, 255),
		rgb(36, 46, 70),
		core
	).Name =
		"SpyglassSign"
	shopkeeper(
		"Squint",
		base * CFrame.new(5.5, 0.2, -11.5) * CFrame.Angles(0, math.rad(20), 0),
		rgb(36, 62, 120),
		"tricorn"
	)
	part("TowerDoor", Vector3.new(6, 9, 1), base * CFrame.new(0, 4.5, -8.9), WOOD_DARK, PLANKS)
	prompt("Spyglass", base * CFrame.new(0, 3, -12), "The Spyglass", "Watch the raid", { PortAction = "spectate" }, 14)
	-- Benches to sit on and watch the sea.
	for _, x in ipairs({ -8, 8 }) do
		local seat = Instance.new("Seat")
		seat.Name = "Bench"
		seat.Size = Vector3.new(6, 1, 2)
		seat.CFrame = base * CFrame.new(x, 1.5, -15)
		seat.Color = WOOD_LIGHT
		seat.Material = PLANKS
		seat.Anchored = true
		seat.Parent = town
	end
end

-- The island's shore: palms, rocks, small boats moored at little jetties ----------------------------------------------------
local function buildShore()
	local palms = {
		{ -150, 120 },
		{ -120, 168 },
		{ 140, 140 },
		{ 170, 92 },
		{ 60, 230 },
		{ -40, 238 },
		{ 196, 10 },
		{ -168, -68 },
		{ 170, -70 },
		{ -60, -100 },
		{ 52, -104 },
		{ 0, 250 },
	}
	local Kit = require(script.Parent.WorldKit)
	for _, p in ipairs(palms) do
		local x, z = C.X + p[1], C.Z + p[2]
		local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0))
		if hit and hit.Position.Y > 1.5 and hit.Material ~= Enum.Material.Water then
			pcall(Kit.palm, x, z, hit.Position.Y, 6 + (p[1] % 5))
		end
	end
	-- Moored dinghies by the boarding pier.
	for i, z in ipairs({ -96, -128, -152 }) do
		local side = i % 2 == 0 and -1 or 1
		local cf = at(side * 17, 0.6, z) * CFrame.Angles(0, math.rad(side * 6), 0)
		deco("Dinghy", Vector3.new(4.6, 1.6, 10), cf, ({ RED, TEAL, GOLD })[i], PLANKS)
		deco("DinghySeat", Vector3.new(4.4, 0.4, 1.4), cf * CFrame.new(0, 0.9, 1), WOOD_LIGHT, PLANKS)
		deco(
			"DinghyBow",
			Vector3.new(4.6, 1.6, 3),
			cf * CFrame.new(0, 0, -6.2) * CFrame.Angles(0, math.rad(180), 0),
			({ RED, TEAL, GOLD })[i],
			PLANKS,
			{ wedge = true }
		)
	end
	-- Buoys round the harbour.
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local x, z = math.cos(a) * 330, 40 + math.sin(a) * 330
		local buoy = deco(
			"Buoy",
			Vector3.new(3, 4, 3),
			at(x, 1.2, z),
			k % 2 == 0 and RED or rgb(250, 248, 240),
			SMOOTH,
			{ egg = true }
		)
		local lantern =
			deco("BuoyLamp", Vector3.new(1, 1, 1), buoy.CFrame * CFrame.new(0, 2.6, 0), GOLD, NEON, { ball = true })
		light(lantern, rgb(255, 200, 110), 16, 0.8)
	end
end

-- Building it all ---------------------------------------------------------------------------------------------------------
function Port.build(worldRefs, displayModel)
	refs = worldRefs
	local root = refs.folders.root
	core = Instance.new("Model")
	core.Name = "PortCore"
	core.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	town = Instance.new("Model")
	town.Name = "PortTown"
	buildTerrain()
	buildPlaza()
	buildDeparture()
	buildShipyard(displayModel)
	buildMenagerie()
	buildWardrobe()
	buildPodium()
	buildSpyglass()
	buildShore()
	core.Parent = root
	town.Parent = root
	-- For the clients: where the Port is (its own screen, the map, spectating).
	core:SetAttribute("Center", C)
	Port.core = core
end

-- Moving goblins in ---------------------------------------------------------------------------------------------------------
local function freeOf(player)
	local _, humanoid, root = Util.getCharacterParts(player)
	if not root then
		return nil, nil
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
	humanoid.PlatformStand = false
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", nil)
	player:SetAttribute("LaunchBy", nil)
	return humanoid, root
end

-- Put a goblin in the Port: at `spot` (a CFrame) or the next free arrival point round the fountain. Teleports are
-- retried for a moment, because a goblin who was at a boat's wheel can be pulled back by their own client.
function Port.arrive(player, spot)
	player:SetAttribute("Zone", "port")
	player:SetAttribute("Ready", nil)
	local humanoid, root = freeOf(player)
	if not root then
		return
	end
	if not spot then
		nextSpawn = nextSpawn % #spawnPoints + 1
		spot = spawnPoints[nextSpawn]
	end
	local token = (arriving[player] or 0) + 1
	arriving[player] = token
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(spot.Position, 3)
		end)
		for attempt = 1, 4 do
			if arriving[player] ~= token or not root.Parent then
				return
			end
			if attempt > 1 and (root.Position - spot.Position).Magnitude < 12 then
				break
			end
			root.Anchored = true
			root.AssemblyLinearVelocity = Vector3.zero
			if humanoid.SeatPart then
				humanoid.Sit = false
			end
			player.Character:PivotTo(spot)
			task.wait(attempt == 1 and P.ARRIVE_GRACE or 0.4)
		end
		if arriving[player] == token and root.Parent then
			root.Anchored = false
		end
	end)
end

-- The raid's winners come home onto the podium (up to three of them; anyone else goes to the fountain).
function Port.arriveWinners(players)
	for index, player in ipairs(players) do
		local spot = podiumSpots[math.min(index, 3)]
		if index > 3 then
			spot = podiumSpots[1] * CFrame.new((index - 3) * 1.8, 0, 0)
		end
		Port.arrive(player, spot)
	end
end

-- Is this goblin in the Port (by the attribute the server keeps, or by where they stand)?
function Port.has(player)
	if player:GetAttribute("Zone") == "port" then
		return true
	end
	local root = Util.aliveRoot(player)
	return root ~= nil and Lobby.inPort(root.Position)
end

-- Who is standing aboard the Little Goblin (ready to go).
function Port.isReady(player)
	local root = Util.aliveRoot(player)
	if not root or not readyBox then
		return false
	end
	local localPos = readyBox.cframe:PointToObjectSpace(root.Position)
	local half = readyBox.size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

-- The champion's statue: their look, their name, their gold. nil clears it.
function Port.setChampion(player, gold)
	if statue then
		statue:Destroy()
		statue = nil
	end
	local text = "NO CHAMPION YET"
	if player and Port.statueSpot then
		local look = Catalog.decodeLook(player:GetAttribute("Look"))
		statue = mannequinOn(Port.statueSpot, look, core)
		statue.Name = "ChampionStatue"
		-- A golden crown floats over the champion.
		local crown =
			deco("StatueCrown", Vector3.new(1.6, 0.8, 1.6), Port.statueSpot * CFrame.new(0, 7.4, 0), GOLD, METAL, {
				cyl = true,
				parent = statue,
			})
		crown.CFrame = crown.CFrame * UPRIGHT
		text = string.format("CHAMPION: %s  (%d GOLD)", string.upper(player.DisplayName), gold or 0)
	end
	if statueLabel then
		for _, gui in ipairs(statueLabel:GetChildren()) do
			local label = gui:FindFirstChild("Text")
			if label then
				label.Text = text
			end
		end
	end
end

-- Spectating ----------------------------------------------------------------------------------------------------------------
-- The client asks; the server decides who may be watched (a goblin in the raid, alive) and streams the world round
-- them to the spectator (ReplicationFocus). Nothing a spectator does reaches the raid.
Port.inRaid = function(_player)
	return false
end

local function focusOn(spectator, target)
	local root = target and Util.aliveRoot(target)
	pcall(function()
		spectator.ReplicationFocus = root
	end)
	if root then
		pcall(function()
			spectator:RequestStreamAroundAsync(root.Position, 2)
		end)
	end
end

local function stopSpectating(spectator, why)
	if spectators[spectator] == nil and not spectator:GetAttribute("Spectating") then
		return
	end
	spectators[spectator] = nil
	spectator:SetAttribute("Spectating", nil)
	pcall(function()
		spectator.ReplicationFocus = nil
	end)
	Net.send(spectator, "SpectateEnd", { why = why })
end
Port.stopSpectating = stopSpectating

function Port.targets()
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if Port.inRaid(other) and Util.aliveRoot(other) then
			table.insert(list, { userId = other.UserId, name = other.DisplayName })
		end
	end
	return list
end

local function watch(spectator, target)
	spectators[spectator] = target
	spectator:SetAttribute("Spectating", target.UserId)
	task.spawn(focusOn, spectator, target)
end

-- action: "start" (userId or nil: the first one), "next", "back", "stop".
function Port.spectate(spectator, action, userId)
	if action == "stop" then
		stopSpectating(spectator, "stop")
		return
	end
	if Port.inRaid(spectator) then
		return
	end
	if workspace:GetAttribute("RaidPhase") ~= "raid" then
		Net.toast(spectator, "No raid to watch right now: the next one starts soon.")
		stopSpectating(spectator, "noraid")
		return
	end
	local targets = Port.targets()
	if #targets == 0 then
		Net.toast(spectator, "Nobody is out raiding just now.")
		stopSpectating(spectator, "empty")
		return
	end
	local current = spectators[spectator] and spectators[spectator].UserId or nil
	local pick
	if action == "start" then
		pick = type(userId) == "number" and userId or nil
		local valid = false
		for _, entry in ipairs(targets) do
			valid = valid or entry.userId == pick
		end
		if not valid then
			pick = Lobby.cycle(targets, nil, 1)
		end
	else
		pick = Lobby.cycle(targets, current, action == "back" and -1 or 1)
	end
	local target = pick and Players:GetPlayerByUserId(pick)
	if target then
		watch(spectator, target)
	end
end

-- Each frame (from Main, through Raid): keep every spectator's stream on their target, move on when a target is gone.
local nextSweep = 0
function Port.tick()
	local t = now()
	if t < nextSweep then
		return
	end
	nextSweep = t + 0.5
	for spectator, target in pairs(spectators) do
		if not spectator.Parent then
			spectators[spectator] = nil
		elseif not target.Parent or not Port.inRaid(target) then
			local targets = Port.targets()
			if #targets > 0 then
				local pick = Players:GetPlayerByUserId(Lobby.cycle(targets, nil, 1))
				if pick then
					watch(spectator, pick)
					Net.send(spectator, "SpectateSwitch", { why = "gone" })
				end
			else
				stopSpectating(spectator, "empty")
			end
		else
			local root = Util.aliveRoot(target)
			if root and spectator.ReplicationFocus ~= root then
				focusOn(spectator, target)
			end
		end
	end
	-- Late entry is open while enough raid is left (the prompt on the pier and the screen's JOIN button both ask).
	if Port.joinPrompt then
		local ok =
			Lobby.canJoinLate(workspace:GetAttribute("RaidPhase"), t, workspace:GetAttribute("PhaseEndsAt"), false)
		Port.joinPrompt.Enabled = ok
	end
end

-- The raid ended (or the spectator joined it): everyone stops watching.
function Port.stopAll(why)
	for spectator in pairs(spectators) do
		stopSpectating(spectator, why)
	end
end

-- A goblin left. (Anyone watching them is moved on by Port.tick, which sees their target gone.)
function Port.forget(player)
	spectators[player] = nil
	arriving[player] = nil
end

function Port.spawnPoint()
	nextSpawn = nextSpawn % #spawnPoints + 1
	return spawnPoints[nextSpawn]
end

return Port

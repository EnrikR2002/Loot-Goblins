-- The far ring: seven islands that are a real commitment to reach. Each has a recognizable
-- silhouette (a boxy fort, a pillared jungle, a smoking cone, a whirlpool needle, white glacier
-- peaks, a giant ribcage, a skull) and its own kind of trouble waiting at the treasure.
-- Like Islands.lua, these only describe things in `refs`; the mechanism modules run them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.WorldKit)
local Sea = require(script.Parent.Sea)
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))

local IslandsFar = {}

local terrain = Kit.terrain
local folders = Kit.folders
local refs = Kit.refs

local ground, structure, decor, neon = Kit.ground, Kit.structure, Kit.decor, Kit.neon
local cylinder, plank, ladder = Kit.cylinder, Kit.plank, Kit.ladder
local fillColumn, compass, groundY = Kit.fillColumn, Kit.compass, Kit.groundY
local rockRamp, tunnel, deck = Kit.rockRamp, Kit.tunnel, Kit.deck
local pointLight, glow, islandSign, dock = Kit.pointLight, Kit.glow, Kit.islandSign, Kit.dock
local flatDirection = Kit.flatDirection

local STONE, DARK_STONE, WOOD, DARK_WOOD = Kit.STONE, Kit.DARK_STONE, Kit.WOOD, Kit.DARK_WOOD
local AIR = Enum.Material.Air
local BONE = Color3.fromRGB(240, 234, 214)

local function info(id)
	return Archipelago.byId[id]
end

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

-- Fort Barnacle: a pirate fort on a sea-cliff plateau. A harbor basin cuts in from the south
-- (the Navy sits there); the open way in is a north back door, the south gate and the cracked
-- east wall need a cannon or kegs; four corner turrets guard the keep. ----------------------------
local function buildFort()
	local f = info("Fort")
	local cx, cz = f.x, f.z
	fillColumn(cx, cz, -30, 1.5, 190, Enum.Material.Sand)
	fillColumn(cx, cz, -30, 20, 124, Enum.Material.Rock)
	fillColumn(cx, cz, 17, 20, 123, Enum.Material.Slate)
	-- The harbor basin: a deep slot cut in from the south, with cliff walls on either side.
	terrain:FillBlock(CFrame.new(cx, 0, cz + 126), v3(46, 52, 160), AIR)
	-- A wooden walkway on stilts up the basin's east wall, from the quay to the south gate.
	local quayTop, quayBottom = v3(cx + 17, 20.6, cz + 50), v3(cx + 17, 1.4, cz + 112)
	plank("HarborWalk", quayBottom, quayTop, 8, 1.2, WOOD, Enum.Material.WoodPlanks, folders.ground, 2)
	for i = 0, 5 do
		local p = quayBottom:Lerp(quayTop, i / 5)
		cylinder(
			"Stilt",
			0.7,
			p.Y + 10,
			v3(p.X - 3.5, (p.Y - 10) / 2 - 0.5, p.Z),
			DARK_WOOD,
			Enum.Material.Wood,
			folders.structures
		)
	end
	ground("HarborQuay", v3(8, 1, 22), CFrame.new(cx + 17, 1.1, cz + 124), WOOD, Enum.Material.WoodPlanks)
	-- A north approach for visitors: a path ramp from the pier beach up the sea cliff.
	rockRamp(v3(cx, 1.5, cz - 168), v3(cx, 20, cz - 128), 12, Enum.Material.Rock)

	-- The outer wall: a square of stone around the yard.
	local top = 20
	local half = 52
	local height, thick = 16, 5
	local corners = {
		v3(cx - half, top, cz - half - 10), -- north-west
		v3(cx + half, top, cz - half - 10), -- north-east
		v3(cx + half, top, cz + half - 10), -- south-east
		v3(cx - half, top, cz + half - 10), -- south-west
	}
	local function wallRun(a, b, gapStart, gapEnd)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local function piece(t0, t1)
			if t1 - t0 > 1 then
				Kit.wall("FortWall", a + dir * t0, a + dir * t1, height, thick, STONE, Enum.Material.Brick)
			end
		end
		if gapStart then
			piece(0, gapStart)
			piece(gapEnd, length)
		else
			piece(0, length)
		end
	end
	wallRun(corners[1], corners[2], 49, 55) -- north, with a 6-wide back door
	wallRun(corners[2], corners[3], 38, 66) -- east, with the cracked section as the gap
	wallRun(corners[4], corners[3], 64, 74) -- south, with the gate gap
	wallRun(corners[1], corners[4]) -- west

	local function breakable(name, centerPos, size, color, kind, health, label)
		local m = Instance.new("Model")
		m.Name = name
		local face = Kit.partOf(m, name .. "Panel", size, CFrame.new(centerPos), color, Enum.Material.Brick)
		for i = 1, 3 do
			Kit.partOf(
				m,
				"Crack",
				v3(0.2, size.Y - 5 * i, 0.3),
				CFrame.new(centerPos + v3(size.X / 2 + 0.1, 0, -size.Z / 4 + i * 2.5))
					* CFrame.Angles(0, 0, math.rad(8 * i)),
				Color3.fromRGB(40, 30, 28),
				Enum.Material.Slate
			)
		end
		m.PrimaryPart = face
		m.Parent = folders.structures
		table.insert(refs.breakables, { model = m, health = health, kind = kind, label = label })
		return m
	end
	-- East: the cracked section (any blast opens it).
	local eastMid = corners[2] + (corners[3] - corners[2]).Unit * 52
	breakable(
		"FortCracked",
		eastMid + v3(0, height / 2, 0),
		v3(thick, height, 28),
		Color3.fromRGB(176, 150, 120),
		"weak",
		1,
		"Cracked wall"
	)
	-- South: the gate, heavy enough to need a cannonball (or a lot of kegs).
	local gateMid = corners[4] + (corners[3] - corners[4]).Unit * 69
	local gate = Instance.new("Model")
	gate.Name = "FortGate"
	local gatePanel = Kit.partOf(
		gate,
		"GatePanel",
		v3(10, 12, 3),
		CFrame.new(gateMid + v3(0, 6, 0)),
		Color3.fromRGB(96, 66, 42),
		Enum.Material.WoodPlanks
	)
	for _, y in ipairs({ -3.5, 3.5 }) do
		Kit.partOf(
			gate,
			"GateBand",
			v3(10.4, 1, 3.4),
			CFrame.new(gateMid + v3(0, 6 + y, 0)),
			Color3.fromRGB(40, 40, 46),
			Enum.Material.Metal
		)
	end
	gate.PrimaryPart = gatePanel
	gate.Parent = folders.structures
	table.insert(refs.breakables, { model = gate, health = 2, kind = "gate", label = "Fort gate" })

	-- Corner towers: round and crenellated, with a turret on the roof (the fort's own defense).
	for i, corner in ipairs(corners) do
		cylinder("FortTower", 8.5, 34, corner + v3(0, 17, 0), STONE, Enum.Material.Brick, folders.structures)
		cylinder("TowerTop", 9.5, 2, corner + v3(0, 35, 0), DARK_STONE, Enum.Material.Slate, folders.ground)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			structure(
				"Merlon",
				v3(2.6, 3, 2.6),
				CFrame.new(corner + v3(math.cos(a) * 8.6, 38, math.sin(a) * 8.6)),
				STONE,
				Enum.Material.Brick
			)
		end
		Kit.totem("FortTurret" .. i, corner + v3(0, 36, 0), v3(cx, 20, cz))
		refs.totems[#refs.totems].kind = "turret"
	end

	-- The keep: a tall tower with a door on the south, a ladder up, the strongbox on top.
	local keepBase = v3(cx, top, cz - 40)
	local keepSize, keepHeight = 24, 36
	structure(
		"KeepWall",
		v3(keepSize, keepHeight, 2),
		CFrame.new(keepBase + v3(0, keepHeight / 2, -keepSize / 2)),
		STONE,
		Enum.Material.Brick
	)
	structure(
		"KeepWall",
		v3(2, keepHeight, keepSize),
		CFrame.new(keepBase + v3(-keepSize / 2, keepHeight / 2, 0)),
		STONE,
		Enum.Material.Brick
	)
	structure(
		"KeepWall",
		v3(2, keepHeight, keepSize),
		CFrame.new(keepBase + v3(keepSize / 2, keepHeight / 2, 0)),
		STONE,
		Enum.Material.Brick
	)
	for _, x in ipairs({ -8, 8 }) do
		structure(
			"KeepWall",
			v3(8, keepHeight, 2),
			CFrame.new(keepBase + v3(x, keepHeight / 2, keepSize / 2)),
			STONE,
			Enum.Material.Brick
		)
	end
	structure(
		"KeepLintel",
		v3(8, keepHeight - 9, 2),
		CFrame.new(keepBase + v3(0, 9 + (keepHeight - 9) / 2, keepSize / 2)),
		STONE,
		Enum.Material.Brick
	)
	-- The upper floor, with a hatch (south-east corner) for the ladder.
	ground("KeepFloor", v3(23, 1, 18), CFrame.new(keepBase + v3(0, 24, -2.5)), WOOD, Enum.Material.WoodPlanks)
	ground("KeepFloor", v3(17, 1, 5), CFrame.new(keepBase + v3(-3, 24, 9)), WOOD, Enum.Material.WoodPlanks)
	ladder("KeepLadder", keepBase + v3(keepSize / 2 - 3, 0.5, keepSize / 2 - 3), 26)
	structure(
		"KeepRoof",
		v3(keepSize + 2, 2, keepSize + 2),
		CFrame.new(keepBase + v3(0, keepHeight + 1, 0)),
		DARK_STONE,
		Enum.Material.Slate
	)
	Kit.lootSpot("Strongbox", CFrame.new(keepBase + v3(0, 24.5 + 2.4, -4)))
	pointLight(
		structure(
			"KeepLamp",
			v3(1, 1, 1),
			CFrame.new(keepBase + v3(0, 33, 0)),
			Color3.fromRGB(255, 180, 90),
			Enum.Material.Neon
		),
		Color3.fromRGB(255, 180, 90),
		28,
		1.4
	)

	-- The yard: barracks, barrels (they explode), kegs by the gate, a free cannon on the wall.
	for _, b in ipairs({ { -32, 18 }, { 30, 28 } }) do
		local barracks = CFrame.new(cx + b[1], top, cz + b[2] - 10)
		structure(
			"Barracks",
			v3(26, 9, 12),
			barracks * CFrame.new(0, 4.5, 0),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.WoodPlanks
		)
		structure(
			"BarracksRoof",
			v3(29, 1.4, 15),
			barracks * CFrame.new(0, 9.7, 0),
			Color3.fromRGB(70, 60, 70),
			Enum.Material.Fabric
		)
	end
	for _, spot in ipairs({ { -10, 6 }, { -6, 10 }, { 12, 14 }, { 4, -10 } }) do
		table.insert(refs.barrels, Kit.barrel(v3(cx + spot[1], top, cz + spot[2] - 10)))
	end
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx - 12, top, cz + 30)))
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx + 14, top, cz + 30)))
	ground("CannonStand", v3(10, 1, 10), CFrame.new(cx - 26, top + 15.6, cz - 6), DARK_STONE, Enum.Material.Slate)
	Kit.cannon(v3(cx - 26, top + 16.1, cz - 6), v3(cx - 26, top, cz + 200), "Fort cannon")
	ladder("WallLadder", v3(cx - 26, top, cz - 1), 16)
	-- The Navy sits in the harbor, one ship each side of the basin.
	table.insert(refs.navyBases, {
		id = "Fort",
		position = v3(cx, 0, cz + 130),
		spawns = {
			CFrame.lookAt(v3(cx - 8, 0, cz + 120), v3(cx - 8, 0, cz + 400)),
			CFrame.lookAt(v3(cx - 8, 0, cz + 160), v3(cx - 8, 0, cz + 400)),
		},
	})
	refs.troubleSites.Navy = { base = refs.navyBases[#refs.navyBases] }
	structure(
		"FortFlagPole",
		v3(0.9, 22, 0.9),
		CFrame.new(keepBase + v3(0, keepHeight + 12, 0)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	decor(
		"FortFlag",
		v3(0.3, 6, 10),
		CFrame.new(keepBase + v3(0, keepHeight + 18, 5)),
		Color3.fromRGB(190, 30, 40),
		Enum.Material.Fabric
	)
	dock(v3(cx + 30, 0, cz - 186), v3(cx + 30, 0, cz - 252), { 1 })
	islandSign(v3(cx, 100, cz), f.name, f.color)
end

-- Tangle Isle: jungle pillars joined by rope bridges that snap in a quake. -----------------------
local function buildTangle()
	local t = info("Tangle")
	local cx, cz = t.x, t.z
	Kit.blob(cx, cz, 190, 150, 6, 7, 515, Enum.Material.Rock, Enum.Material.Grass)
	-- x, z, height, radius (relative to the island). The last is the shrine pillar.
	local pillars = {
		{ -70, 40, 52, 9 },
		{ -10, -10, 62, 8 },
		{ 55, -35, 58, 9 },
		{ 95, 10, 46, 10 },
		{ 120, -75, 84, 13 },
	}
	local tops = {}
	for i, p in ipairs(pillars) do
		local x, z, h, r = cx + p[1], cz + p[2], p[3], p[4]
		fillColumn(x, z, -30, h, r, Enum.Material.Rock)
		fillColumn(x, z, -30, 12, r + 5, Enum.Material.Rock)
		deck("PillarDeck", v3(x, h, z), r * 1.1)
		tops[i] = v3(x, h, z)
		for k = 1, 3 do
			local a = k * 2.2 + i
			Kit.tree(x + math.cos(a) * (r + 12), z + math.sin(a) * (r + 12), 6, 13 + k * 2)
		end
	end
	ladder("TangleLadder", v3(tops[1].X - pillars[1][4] - 1.2, 3, tops[1].Z), pillars[1][3])
	ladder("ShrineLadder", v3(tops[5].X + pillars[5][4] + 1.2, 3, tops[5].Z), pillars[5][3])
	-- The canopy route: P1 -> P2 -> P3 -> shrine. The ground route climbs P4 and crosses to the shrine.
	local function rim(from, to, r)
		return v3(from.X, from.Y + 1, from.Z) + flatDirection(from, to) * (r * 0.8)
	end
	Kit.breakBridge("CanopyBridgeA", rim(tops[1], tops[2], 9), rim(tops[2], tops[1], 8), 4, 5)
	Kit.breakBridge("CanopyBridgeB", rim(tops[2], tops[3], 8), rim(tops[3], tops[2], 9), 4, 5)
	Kit.breakBridge("CanopyBridgeC", rim(tops[3], tops[5], 9), rim(tops[5], tops[3], 13), 4, 5)
	Kit.breakBridge("GroundBridge", rim(tops[4], tops[5], 10), rim(tops[5], tops[4], 13), 5, 5)
	rockRamp(v3(cx + 140, 4, cz + 60), v3(tops[4].X + 8, 46, tops[4].Z + 4), 8, Enum.Material.Rock)
	-- The shrine: four columns, a roof and the Jade Frog.
	local shrine = tops[5]
	for _, off in ipairs({ { 6, 6 }, { -6, 6 }, { 6, -6 }, { -6, -6 } }) do
		Kit.column(shrine + v3(off[1], 0.5, off[2]), 12, 1.1, Color3.fromRGB(150, 195, 150), false)
	end
	structure(
		"ShrineRoof",
		v3(18, 1.6, 18),
		CFrame.new(shrine + v3(0, 13.2, 0)),
		Color3.fromRGB(90, 130, 90),
		Enum.Material.Slate
	)
	Kit.lootSpot("Frog", CFrame.new(shrine + v3(0, 3.4, 0)))
	pointLight(
		decor(
			"ShrineGlow",
			v3(1, 1, 1),
			CFrame.new(shrine + v3(0, 8, 0)),
			Color3.fromRGB(110, 235, 130),
			Enum.Material.Neon
		),
		Color3.fromRGB(110, 235, 130),
		24,
		1.4
	)
	-- Escape: a zipline from the shrine out to the south beach.
	Kit.zipline("ShrineZipline", shrine + v3(-9, 12, 9), v3(cx + 40, 12, cz + 150))
	-- A thick jungle to get lost in.
	local random = Kit.rng(42)
	for _ = 1, 40 do
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(25, 150)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local y = groundY(x, z, -50)
		if y > 3 and y < 12 then
			Kit.tree(x, z, y, random:NextNumber(12, 20))
		end
	end
	dock(v3(cx - 20, 0, cz + 170), v3(cx - 20, 0, cz + 236), { 1 })
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx - 40, 6, cz + 120)))
	islandSign(v3(cx, 110, cz), t.name, t.color)
	refs.troubleSites.Quake = { center = v3(cx, 40, cz) }
end

-- Ember Isle: a volcano with a lava crater, geysers on the flanks and the Ember Crown on a rock
-- in the lava. Taking it makes the mountain erupt. -----------------------------------------------
local function buildEmber()
	local e = info("Ember")
	local cx, cz = e.x, e.z
	fillColumn(cx, cz, -30, 1.5, 205, Enum.Material.Sand)
	fillColumn(cx, cz, -30, 8, 170, Enum.Material.Basalt)
	Kit.cone(cx, cz, 6, 56, 166, 104, Enum.Material.Basalt, 0.1, 811, Enum.Material.Basalt)
	Kit.cone(cx, cz, 54, 124, 98, 46, Enum.Material.Basalt, 0.08, 812, Enum.Material.Basalt)
	-- The crater: a funnel (walkable walls, so you can climb back out) down to a lava pool.
	for i = 0, 8 do
		terrain:FillCylinder(CFrame.new(cx, 108 + i * 2 + 1, cz), 2.2, 22 + i * 2.1, AIR)
	end
	terrain:FillCylinder(CFrame.new(cx, 104, cz), 8, 24, Enum.Material.CrackedLava)
	fillColumn(cx, cz, 100, 111, 6, Enum.Material.Basalt) -- the pedestal
	for i = 0, 3 do
		local a = math.rad(200 + i * 52)
		local r = 17.5 - i * 3.6
		fillColumn(cx + math.cos(a) * r, cz + math.sin(a) * r, 100, 110.2, 2.8, Enum.Material.Basalt)
	end
	Kit.lavaZone(v3(cx, 109.5, cz), v3(46, 4, 46), 24)
	Kit.lootSpot("Crown", CFrame.new(cx, 111 + 2.4, cz))
	pointLight(
		decor("CraterGlow", v3(1, 1, 1), CFrame.new(cx, 116, cz), Color3.fromRGB(255, 120, 40), Enum.Material.Neon),
		Color3.fromRGB(255, 120, 40),
		60,
		2
	)
	-- Smoke you can see from the next island, and embers.
	local plume = decor("Plume", v3(2, 2, 2), CFrame.new(cx, 130, cz), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	plume.Transparency = 1
	emitter(plume, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 60)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 90) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(14, 22),
		SpreadAngle = Vector2.new(12, 12),
		Rate = 6,
		RotSpeed = NumberRange.new(-20, 20),
	})
	emitter(plume, {
		Color = ColorSequence.new(Color3.fromRGB(255, 130, 40)),
		LightEmission = 1,
		Size = NumberSequence.new(1.6, 0),
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(30, 60),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 14,
	})
	local flame = Instance.new("Fire")
	flame.Size = 40
	flame.Heat = 20
	flame.Color = Color3.fromRGB(255, 120, 30)
	flame.SecondaryColor = Color3.fromRGB(255, 60, 20)
	flame.Parent = plume
	-- Geysers up the south flank: timed launches (a way up if you time them, a way to get thrown).
	for i, g in ipairs({ { 0, 130 }, { -50, 100 }, { 48, 98 }, { -20, 72 } }) do
		local gx, gz = cx + g[1], cz + g[2]
		Kit.geyser(v3(gx, groundY(gx, gz, 30), gz), 7 + i % 2, 1.8, i * 1.9, v3(0, 105, 0))
	end
	local out = compass(225)
	dock(v3(cx, 0, cz) + out * 178, v3(cx, 0, cz) + out * 244, { 1 })
	local kx, kz = cx - 105, cz + 120
	table.insert(refs.kegCrates, Kit.kegCrate(v3(kx, groundY(kx, kz, 8), kz)))
	table.insert(refs.barrels, Kit.barrel(v3(kx + 5, groundY(kx + 5, kz + 4, 8), kz + 4)))
	table.insert(refs.barrels, Kit.barrel(v3(kx + 9, groundY(kx + 9, kz - 2, 8), kz - 2)))
	islandSign(v3(cx, 190, cz), e.name, e.color)
	refs.troubleSites.Eruption = { center = v3(cx, 110, cz), radius = 250 }
end

-- Maelstrom Rock: a needle of stone at the heart of a whirlpool. Boats are carried around it
-- and drawn in; the ring of stacks is a breakwater with gaps, and the eye is calm. ----------------
local function buildMaelstrom()
	local m = info("Maelstrom")
	local cx, cz = m.x, m.z
	fillColumn(cx, cz, -30, 1.5, 54, Enum.Material.Sand)
	fillColumn(cx, cz, -30, 64, 14, Enum.Material.Rock)
	terrain:FillBall(v3(cx - 10, 14, cz + 6), 15, Enum.Material.Rock)
	terrain:FillBall(v3(cx + 8, 8, cz - 9), 13, Enum.Material.Rock)
	deck("NeedleDeck", v3(cx, 64, cz), 12)
	ladder("NeedleLadder", v3(cx + 15.2, 1.5, cz), 62)
	Kit.lootSpot("Trident", CFrame.new(cx, 64.5 + 3, cz))
	pointLight(
		decor("TridentGlow", v3(1, 1, 1), CFrame.new(cx, 70, cz), Color3.fromRGB(150, 190, 255), Enum.Material.Neon),
		Color3.fromRGB(150, 190, 255),
		30,
		1.6
	)
	-- The breakwater: six stacks with wide gaps between them.
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.25
		local x, z = cx + math.cos(a) * 96, cz + math.sin(a) * 96
		fillColumn(x, z, -30, 1.5, 17, Enum.Material.Sand)
		fillColumn(x, z, -30, 14 + (i % 3) * 8, 8, Enum.Material.Rock)
		if i % 2 == 0 then
			Kit.coral(v3(x, 2, z), 40 + i, 3)
		end
	end
	-- The current itself (Sea.lua), and the foam spirals that show it.
	Sea.addWhirl("Maelstrom", v3(cx, 0, cz), 270, 30, 17)
	local foam = Instance.new("Model")
	foam.Name = "WhirlFoam"
	for arm = 0, 3 do
		for k = 1, 14 do
			local t = k / 14
			local a = arm * math.pi / 2 + t * 2.6
			local r = 250 - t * 190
			local p = v3(cx + math.cos(a) * r, 0.5, cz + math.sin(a) * r)
			local piece = Kit.partOf(
				foam,
				"Foam",
				v3(6 + (1 - t) * 14, 0.3, 16),
				CFrame.lookAt(p, p + v3(-math.sin(a), 0, math.cos(a))),
				Color3.fromRGB(235, 245, 255),
				Enum.Material.Neon
			)
			piece.Transparency = 0.45
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false
		end
	end
	foam.WorldPivot = CFrame.new(cx, 0.5, cz)
	foam.Parent = folders.decor
	Kit.spinner(foam, foam.WorldPivot, nil, -0.18, false, 0)
	islandSign(v3(cx, 120, cz), m.name, m.color)
	refs.troubleSites.Squall = { center = v3(cx, 0, cz) }
end

-- Frost Spire: three glacier peaks, an ice tunnel and a summit worth dying for. ------------------
local function buildFrost()
	local f = info("Frost")
	local cx, cz = f.x, f.z
	fillColumn(cx, cz, -30, 2, 175, Enum.Material.Snow)
	fillColumn(cx, cz, -30, 6, 150, Enum.Material.Glacier)
	local summit = Kit.cone(cx, cz, 4, 152, 100, 16, Enum.Material.Glacier, 0.12, 1001, Enum.Material.Snow)
	Kit.cone(cx - 105, cz + 35, 4, 98, 62, 12, Enum.Material.Glacier, 0.15, 1002, Enum.Material.Snow)
	Kit.cone(cx + 92, cz - 28, 4, 88, 56, 10, Enum.Material.Glacier, 0.15, 1003, Enum.Material.Snow)
	-- The slippery band: glacier between y 62 and 96 turns to ice (it's a slide, not a path).
	terrain:ReplaceMaterial(
		Region3.new(v3(cx - 130, 62, cz - 130), v3(cx + 130, 96, cz + 130)):ExpandToGrid(4),
		4,
		Enum.Material.Glacier,
		Enum.Material.Ice
	)
	-- The ice tunnel clean through the mountain, floored in slippery ice.
	local a, b = v3(cx, 3, cz + 112), v3(cx, 3, cz - 112)
	tunnel(a, b, 13, 12)
	terrain:FillBlock(
		CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -1, 0),
		v3(13, 2, (b - a).Magnitude + 2),
		Enum.Material.Ice
	)
	for i = 0, 8 do
		glow(v3(cx - 5.5, 8, cz + 100 - i * 25), Color3.fromRGB(140, 220, 255), 22)
	end
	-- The climb is a straight walk up the south slope; neon markers point the way.
	for i = 0, 7 do
		local y = 20 + i * 18
		local r = 100 - (y - 4) * 84 / 148
		local mark =
			neon(decor("PathMarker", v3(1.2, 3, 1.2), CFrame.new(cx + 6, y + 2, cz + r), Color3.fromRGB(150, 245, 255)))
		mark.CanCollide = false
	end
	deck("SummitDeck", v3(summit.X, summit.Y, summit.Z), 12)
	Kit.lootSpot("Aurora", CFrame.new(summit.X, summit.Y + 1 + 3, summit.Z))
	pointLight(
		decor(
			"AuroraGlow",
			v3(1, 1, 1),
			CFrame.new(summit.X, summit.Y + 7, summit.Z),
			Color3.fromRGB(150, 245, 255),
			Enum.Material.Neon
		),
		Color3.fromRGB(150, 245, 255),
		40,
		1.8
	)
	-- Northern lights: huge soft neon curtains high over the island, visible from far away.
	for i, color in ipairs({
		Color3.fromRGB(120, 255, 190),
		Color3.fromRGB(150, 200, 255),
		Color3.fromRGB(210, 150, 255),
	}) do
		local curtain = decor(
			"Aurora",
			v3(300, 150, 1),
			CFrame.new(cx + (i - 2) * 90, 330, cz - 80 + i * 22) * CFrame.Angles(0, math.rad(15 * (i - 2)), 0),
			color,
			Enum.Material.Neon
		)
		curtain.Transparency = 0.82
		curtain.CastShadow = false
	end
	local random = Kit.rng(55)
	for _ = 1, 22 do
		local ang = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(110, 160)
		local x, z = cx + math.cos(ang) * r, cz + math.sin(ang) * r
		if groundY(x, z, -50) > 0 then
			local shard = decor(
				"IceShard",
				v3(random:NextNumber(3, 7), random:NextNumber(8, 22), random:NextNumber(3, 7)),
				CFrame.new(x, 8, z)
					* CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)),
				Color3.fromRGB(190, 235, 255),
				Enum.Material.Glass,
				true
			)
			shard.Transparency = 0.25
		end
	end
	dock(v3(cx + 40, 0, cz + 172), v3(cx + 40, 0, cz + 234), {})
	local kx, kz = cx - 30, cz + 150
	table.insert(refs.kegCrates, Kit.kegCrate(v3(kx, groundY(kx, kz, 4), kz)))
	islandSign(v3(cx, 215, cz), f.name, f.color)
	refs.troubleSites.Avalanche = { start = v3(summit.X, summit.Y - 6, summit.Z + 10), direction = v3(0, 0, 1) }
end

-- Leviathan's Rest: a whale skeleton on a white shore. Ribs arch over a high spine walkway, and
-- the tooth sits in the jaws of the skull. ------------------------------------------------------
local function buildBone()
	local b = info("Bone")
	local cx, cz = b.x, b.z
	fillColumn(cx, cz, -30, 1.5, 178, Enum.Material.Sand)
	fillColumn(cx, cz, -30, 3.4, 150, Enum.Material.Salt)
	fillColumn(cx - 30, cz, -30, 3.4, 130, Enum.Material.Salt)
	local spineY = 34
	-- Nine pairs of ribs, each an arch from the ground up to the spine.
	for i = 0, 8 do
		local x = cx - 100 + i * 22
		local width = 34 - math.abs(i - 4) * 2.4
		local rise = spineY - 3
		for _, side in ipairs({ -1, 1 }) do
			local prev
			for k = 0, 10 do
				local a = k / 10 * 1.45
				local p = v3(x, 3 + rise * math.sin(a) / math.sin(1.45), cz + side * (4 + (width - 4) * math.cos(a)))
				if prev then
					plank("Rib", prev, p, 3.4, 3.4, BONE, Enum.Material.Marble, folders.structures, 0.6)
				end
				prev = p
			end
		end
		structure("Vertebra", v3(8, 5, 7), CFrame.new(x, spineY, cz), BONE, Enum.Material.Marble)
		if i < 8 then
			ground(
				"SpineWalk",
				v3(15, 1.2, 5),
				CFrame.new(x + 11, spineY + 2.9, cz),
				Color3.fromRGB(215, 208, 188),
				Enum.Material.Marble
			)
		end
	end
	ground(
		"SpineWalkEnd",
		v3(14, 1.2, 5),
		CFrame.new(cx + 84, spineY + 2.9, cz),
		Color3.fromRGB(215, 208, 188),
		Enum.Material.Marble
	)
	ladder("SpineLadder", v3(cx + 92, 3.4, cz), spineY + 2)
	-- The skull at the west end: a hall with open jaws and the tooth.
	local skull = v3(cx - 152, 3.4, cz)
	structure("SkullCrown", v3(34, 6, 40), CFrame.new(skull + v3(0, 26, 0)), BONE, Enum.Material.Marble)
	structure("SkullBackWall", v3(2, 22, 40), CFrame.new(skull + v3(14, 14, 0)), BONE, Enum.Material.Marble)
	for _, side in ipairs({ -1, 1 }) do
		structure("SkullSide", v3(32, 22, 2), CFrame.new(skull + v3(0, 14, side * 20)), BONE, Enum.Material.Marble)
		for k = 0, 4 do
			structure(
				"Tooth",
				v3(2.4, 6, 2.4),
				CFrame.new(skull + v3(-16.5, 4 + (k % 2), side * (3 + k * 3.4))),
				BONE,
				Enum.Material.Marble
			)
		end
		neon(decor("EyeSocket", v3(3, 5, 5), CFrame.new(skull + v3(-17, 26, side * 11)), Color3.fromRGB(120, 255, 190)))
	end
	pointLight(
		decor(
			"SkullGlow",
			v3(1, 1, 1),
			CFrame.new(skull + v3(-4, 8, 0)),
			Color3.fromRGB(120, 255, 190),
			Enum.Material.Neon
		),
		Color3.fromRGB(120, 255, 190),
		38,
		1.4
	)
	structure(
		"Fang",
		v3(3, 9, 3),
		CFrame.new(skull + v3(-6, 7.9, 0)) * CFrame.Angles(0, 0, math.rad(8)),
		BONE,
		Enum.Material.Marble
	)
	Kit.lootSpot("Tooth", CFrame.new(skull + v3(-6, 13.9, 0)))
	for i = 1, 7 do
		local random = Kit.rng(70 + i)
		local ang = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(50, 130)
		Kit.coral(v3(cx + math.cos(ang) * r, 3, cz + math.sin(ang) * r), 90 + i, 3)
	end
	dock(v3(cx + 150, 0, cz + 20), v3(cx + 214, 0, cz + 20), {})
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx + 120, 3.4, cz - 30)))
	islandSign(v3(cx, 120, cz), b.name, b.color)
	refs.troubleSites.Kraken = { center = v3(cx - 40, 0, cz), radius = 280 }
end

-- Skull Rock: a rock carved like a skull. Boats sail in through its mouth to an inner lagoon;
-- a ladder shaft climbs to the cranium, where the chalice waits behind green eyes. ---------------
local function buildSkull()
	local s = info("Skull")
	local cx, cz = s.x, s.z
	fillColumn(cx, cz, -30, 1.5, 160, Enum.Material.Sand)
	-- Cranium and jaw, both rock; the face looks south (+Z).
	terrain:FillBall(v3(cx, 40, cz - 8), 70, Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(cx, 10, cz + 12), v3(84, 28, 86), Enum.Material.Rock) -- the jaw
	terrain:FillBlock(CFrame.new(cx, 26, cz + 20), v3(70, 16, 70), Enum.Material.Rock) -- the cheekbones
	-- Eye sockets and a nose hole that break through the face; then the mouth: a channel from the
	-- open sea (through the sand ring) into an inner lagoon cavern for boats.
	for _, side in ipairs({ -1, 1 }) do
		terrain:FillBall(v3(cx + side * 25, 46, cz + 58), 15, AIR)
	end
	terrain:FillBlock(CFrame.new(cx, 30, cz + 60) * CFrame.Angles(0, 0, math.rad(45)), v3(8, 8, 30), AIR)
	terrain:FillBlock(CFrame.new(cx, 0, cz + 100), v3(26, 26, 200), AIR) -- the mouth channel
	terrain:FillCylinder(CFrame.new(cx, 2, cz - 6), 24, 32, AIR) -- the lagoon cavern
	terrain:FillCylinder(CFrame.new(cx, 7, cz - 6), 14, 36, AIR)
	for k = -4, 4 do
		if math.abs(k) > 1 then
			structure(
				"Tooth",
				v3(4, 9, 4),
				CFrame.new(cx + k * 7.4, 11, cz + 56),
				Color3.fromRGB(240, 235, 215),
				Enum.Material.Marble
			)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local eye = neon(
			decor("SkullEye", v3(14, 14, 14), CFrame.new(cx + side * 25, 46, cz + 50), Color3.fromRGB(110, 255, 170))
		)
		eye.Shape = Enum.PartType.Ball
		pointLight(eye, Color3.fromRGB(110, 255, 170), 60, 2)
	end
	-- Inside: a pier at the back of the lagoon, then a ladder shaft up to the cranium.
	ground("InnerPier", v3(16, 1, 14), CFrame.new(cx, 1.2, cz - 28), WOOD, Enum.Material.WoodPlanks)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		glow(v3(cx + math.cos(a) * 26, 8, cz - 6 + math.sin(a) * 26), Color3.fromRGB(110, 255, 170), 24)
	end
	terrain:FillCylinder(CFrame.new(cx, 13, cz - 32), 26, 4.5, AIR)
	ladder("SkullShaft", v3(cx + 1.6, 1.2, cz - 32), 24)
	-- The cranium chamber and the throne.
	terrain:FillBall(v3(cx, 36, cz - 20), 20, AIR)
	ground(
		"CraniumFloor",
		v3(30, 1.4, 30),
		CFrame.new(cx, 23.8, cz - 20),
		Color3.fromRGB(90, 80, 90),
		Enum.Material.Slate
	)
	structure("Throne", v3(8, 6, 4), CFrame.new(cx, 27, cz - 30), Color3.fromRGB(60, 55, 65), Enum.Material.Slate)
	Kit.lootSpot("Chalice", CFrame.new(cx, 24.5 + 3, cz - 20))
	pointLight(
		decor(
			"ChaliceGlow",
			v3(1, 1, 1),
			CFrame.new(cx, 32, cz - 20),
			Color3.fromRGB(130, 255, 180),
			Enum.Material.Neon
		),
		Color3.fromRGB(130, 255, 180),
		36,
		1.6
	)
	for i = 1, 6 do
		local a = i * 1.1
		Kit.coral(v3(cx + math.cos(a) * 130, 2, cz + math.sin(a) * 130), 120 + i, 3)
	end
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx + 100, 2, cz - 40)))
	islandSign(v3(cx, 130, cz), s.name, s.color)
	refs.troubleSites.GhostFleet = {
		spawns = {
			CFrame.lookAt(v3(cx - 260, 0, cz + 160), v3(cx, 0, cz)),
			CFrame.lookAt(v3(cx + 260, 0, cz + 160), v3(cx, 0, cz)),
		},
	}
end

function IslandsFar.build()
	buildFort()
	buildTangle()
	buildEmber()
	buildMaelstrom()
	buildFrost()
	buildBone()
	buildSkull()
end

return IslandsFar

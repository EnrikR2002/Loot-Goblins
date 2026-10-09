-- The near and middle ring of the archipelago: Pebble Isle, Coral Atoll, Windmill Hills,
-- the Tide Vault and the Smuggler's stash. (World.lua builds home, Crossroads, the Sun
-- Temple, Crystal Isle and the Shoals; IslandsFar.lua builds the far ring.)
--
-- Every island is its own function: terrain first, then structures, then the loot spot and
-- whatever mechanisms the island offers. Mechanisms are described as data in `refs` and run by
-- Mechanisms.lua, Destructibles.lua and Cannons.lua, so nothing here has logic of its own.
local Kit = require(script.Parent.WorldKit)
local Archipelago =
	require(game:GetService("ReplicatedStorage"):WaitForChild("LootGoblins"):WaitForChild("Archipelago"))

local Islands = {}

local terrain = Kit.terrain
local folders = Kit.folders
local refs = Kit.refs

local ground, structure, decor, neon = Kit.ground, Kit.structure, Kit.decor, Kit.neon
local cylinder, plank, ladder = Kit.cylinder, Kit.plank, Kit.ladder
local fillColumn, compass, groundY = Kit.fillColumn, Kit.compass, Kit.groundY
local rockRamp, tunnel, palm = Kit.rockRamp, Kit.tunnel, Kit.palm
local pointLight, glow, islandSign, dock = Kit.pointLight, Kit.glow, Kit.islandSign, Kit.dock

local STONE, DARK_STONE, WOOD, DARK_WOOD = Kit.STONE, Kit.DARK_STONE, Kit.WOOD, Kit.DARK_WOOD
local AIR = Enum.Material.Air

local function info(id)
	return Archipelago.byId[id]
end

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

-- A neon ring of small cubes facing `direction`, used as a boost gate or portal.
local function hoop(center, direction, radius, color)
	local look = CFrame.lookAt(center, center + direction)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local at = look * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		neon(decor("HoopLight", v3(1.6, 1.6, 1.6), at, color, Enum.Material.Neon))
	end
end

-- A small fenced box with a roof and a door gap, for huts and sheds.
local function hut(base, size, wallColor, roofColor, doorSide)
	local walls = {
		{ v3(size.X, size.Y, 1), CFrame.new(0, size.Y / 2, -size.Z / 2) },
		{ v3(1, size.Y, size.Z), CFrame.new(-size.X / 2, size.Y / 2, 0) },
		{ v3(1, size.Y, size.Z), CFrame.new(size.X / 2, size.Y / 2, 0) },
	}
	for _, w in ipairs(walls) do
		structure("HutWall", w[1], base * w[2], wallColor, Enum.Material.WoodPlanks)
	end
	if doorSide ~= "closed" then
		for _, x in ipairs({ -size.X / 2 + 2, size.X / 2 - 2 }) do
			structure(
				"HutWall",
				v3(4, size.Y, 1),
				base * CFrame.new(x, size.Y / 2, size.Z / 2),
				wallColor,
				Enum.Material.WoodPlanks
			)
		end
		structure(
			"HutLintel",
			v3(size.X, 2, 1),
			base * CFrame.new(0, size.Y - 1, size.Z / 2),
			wallColor,
			Enum.Material.WoodPlanks
		)
	end
	structure(
		"HutRoof",
		v3(size.X + 3, 1.2, size.Z + 3),
		base * CFrame.new(0, size.Y + 0.6, 0),
		roofColor,
		Enum.Material.Fabric
	)
end

-- Pebble Isle: the first, easiest treasure. A dune, a wreck, a flag. ----------------------
local function buildPebble()
	local p = info("Pebble")
	local cx, cz = p.x, p.z
	Kit.blob(cx, cz, 66, 46, 3.6, 5, 101, Enum.Material.Sand, Enum.Material.Sand)
	terrain:FillBall(v3(cx + 6, -5, cz - 4), 17, Enum.Material.Sand)
	terrain:FillBall(v3(cx + 6, 4, cz - 4), 8, Enum.Material.Grass)
	local top = groundY(cx + 6, cz - 4, 12)
	Kit.lootSpot("Compass", CFrame.new(cx + 6, top + 2.6, cz - 4))

	-- A wrecked rowboat and a signal flag.
	local boat = CFrame.new(cx - 32, 2.2, cz + 24) * CFrame.Angles(0.12, 0.7, 0.3)
	structure("Rowboat", v3(5, 2, 12), boat, WOOD, Enum.Material.WoodPlanks)
	structure("RowboatRib", v3(5.4, 1, 0.8), boat * CFrame.new(0, 1.2, -2), DARK_WOOD, Enum.Material.Wood)
	structure("RowboatRib", v3(5.4, 1, 0.8), boat * CFrame.new(0, 1.2, 2), DARK_WOOD, Enum.Material.Wood)
	structure("FlagPole", v3(0.8, 16, 0.8), CFrame.new(cx + 22, 10, cz + 10), DARK_WOOD, Enum.Material.Wood)
	decor("Flag", v3(0.3, 4, 6), CFrame.new(cx + 22, 16, cz + 13), Color3.fromRGB(255, 90, 90), Enum.Material.Fabric)
	palm(cx - 18, cz + 8, nil, 10)
	palm(cx + 30, cz + 16, nil, 14)
	palm(cx + 8, cz - 34, nil, 8)
	islandSign(v3(cx, 52, cz), p.name, p.color)
end

-- Coral Atoll: a reef ring around a lagoon. Boats enter by a wide gate, a narrow gate or a
-- kicker ramp, and boost hoops inside reward a clean line. ----------------------------------
local function buildCoral()
	local c = info("Coral")
	local cx, cz = c.x, c.z
	local outer, inner = 112, 86
	fillColumn(cx, cz, -30, 0.8, outer, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(cx, -2, cz), 12, inner, AIR) -- the lagoon basin
	-- Gates through the reef (carved across the ring).
	local function gate(degrees, width)
		local dir = compass(degrees)
		local mid = v3(cx, 0, cz) + dir * ((inner + outer) / 2)
		terrain:FillBlock(CFrame.lookAt(mid, mid + dir), v3(width, 12, outer - inner + 8), AIR)
	end
	gate(220, 34) -- the wide gate, facing home
	gate(330, 13) -- the narrow gate: skiffs only, and only if you aim
	-- Reef decorations: coral heads all around the ring, a rock spike or two.
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local r = (inner + outer) / 2
		local pos = v3(cx + math.cos(a) * r, 1, cz + math.sin(a) * r)
		local degrees = math.deg(a) % 360
		if math.abs(degrees - 220) > 14 and math.abs(degrees - 330) > 8 then
			Kit.coral(pos, 200 + i, 6)
		end
	end
	-- The kicker ramp on the south side: hit it fast and fly over the reef.
	local rampDir = compass(100)
	local rampFoot = v3(cx, -3.2, cz) + rampDir * 152
	local rampTop = v3(cx, 5.5, cz) + rampDir * 121
	plank(
		"KickerRamp",
		rampFoot,
		rampTop,
		14,
		2,
		Color3.fromRGB(255, 170, 90),
		Enum.Material.Slate,
		folders.structures,
		4
	)
	table.insert(
		refs.boostGates,
		{ position = rampFoot:Lerp(rampTop, 0.45) + v3(0, 2, 0), radius = 12, kind = "kick", direction = -rampDir }
	)
	neon(
		decor(
			"KickerGlow",
			v3(12, 0.3, 2),
			CFrame.lookAt(rampTop + v3(0, 0.6, 0), rampTop + rampDir * -5),
			Color3.fromRGB(255, 220, 90)
		)
	)
	-- Boost hoops in the lagoon: a clean line through all three is a free speed run.
	local hoops = {
		{ v3(cx + 36, 4, cz + 26), v3(-1, 0, -0.6) },
		{ v3(cx - 6, 4, cz - 44), v3(-1, 0, 0.2) },
		{ v3(cx - 50, 4, cz + 4), v3(0.3, 0, 1) },
	}
	for _, h in ipairs(hoops) do
		hoop(h[1], h[2].Unit, 8, Color3.fromRGB(120, 255, 230))
		table.insert(
			refs.boostGates,
			{ position = h[1] - v3(0, 3, 0), radius = 9, kind = "boost", direction = h[2].Unit }
		)
	end
	-- The central sandbar and the giant clam holding the pearl.
	fillColumn(cx, cz, -9, 3, 24, Enum.Material.Sand)
	palm(cx + 14, cz + 12, 3, 12)
	palm(cx - 12, cz - 14, 3, 10)
	local clam = CFrame.new(cx, 3, cz)
	local shell = Color3.fromRGB(255, 205, 220)
	decor("ClamBottom", v3(11, 3, 9), clam * CFrame.new(0, 1.6, 0), shell, Enum.Material.Slate, true).Shape =
		Enum.PartType.Ball
	decor(
		"ClamLid",
		v3(11, 4, 9),
		clam * CFrame.new(0, 3.6, 3.6) * CFrame.Angles(math.rad(-48), 0, 0),
		shell,
		Enum.Material.Slate,
		true
	).Shape =
		Enum.PartType.Ball
	Kit.lootSpot("Pearl", CFrame.new(cx, 3 + 3.8, cz))
	islandSign(v3(cx, 48, cz), c.name, c.color)
end

-- Windmill Hills: farmland, and a windmill whose sails sweep the balcony the Golden Gear
-- sits on. Time the gap. ---------------------------------------------------------------------
local function buildWindmill()
	local w = info("Windmill")
	local cx, cz = w.x, w.z
	Kit.blob(cx, cz, 150, 118, 8, 6, 303, Enum.Material.Rock, Enum.Material.Grass)
	local top = v3(cx + 10, 0, cz - 10)
	terrain:FillBall(v3(top.X, -20, top.Z), 60, Enum.Material.Grass)
	for _, h in ipairs({ { -70, 30, 34, -12 }, { 60, 55, 30, -8 }, { -30, -75, 30, -8 }, { 85, -35, 24, -4 } }) do
		terrain:FillBall(v3(cx + h[1], h[4], cz + h[2]), h[3], Enum.Material.Grass)
	end
	local hillTop = groundY(top.X, top.Z, 40)

	-- The windmill: a tapering tower, a gallery deck with a ladder, and the sails.
	local axis = v3(-1, 0, 0.35).Unit -- the sails face home
	local right = v3(-axis.Z, 0, axis.X)
	local base = v3(top.X, hillTop, top.Z)
	for i = 0, 2 do
		cylinder(
			"MillTower",
			8.5 - i * 1.3,
			12.5,
			base + v3(0, 6 + i * 12, 0),
			Color3.fromRGB(235, 225, 205),
			Enum.Material.Brick,
			folders.structures
		)
	end
	cylinder("MillCap", 6, 3, base + v3(0, 38, 0), Color3.fromRGB(150, 70, 60), Enum.Material.Slate, folders.structures)
	local deckY = hillTop + 26
	cylinder("MillGallery", 12, 1, v3(base.X, deckY, base.Z), WOOD, Enum.Material.WoodPlanks, folders.ground)
	ladder("MillLadder", base - axis * 9.4 + v3(0, 1, 0), 26)
	local hubPos = base + axis * 10.5 + v3(0, 36, 0)
	local hub = CFrame.lookAt(hubPos, hubPos + axis)
	local sails = Instance.new("Model")
	sails.Name = "MillSails"
	for i = 0, 3 do
		local blade = CFrame.Angles(0, 0, i * math.pi / 2)
		Kit.partOf(
			sails,
			"SailSpar",
			v3(1.2, 34, 1.2),
			hub * blade * CFrame.new(0, 17, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		Kit.partOf(
			sails,
			"SailCloth",
			v3(7, 24, 0.4),
			hub * blade * CFrame.new(3.8, 21, 0.2),
			Color3.fromRGB(245, 235, 210),
			Enum.Material.Fabric
		)
	end
	Kit.partOf(sails, "SailHub", v3(4, 4, 4), hub, DARK_WOOD, Enum.Material.Wood)
	sails.WorldPivot = hub
	sails.Parent = folders.structures
	local spinner = Kit.spinner(sails, hub, nil, 0.9, true, 17)
	refs.windmill = spinner
	-- The balcony in the sails' path holds the Golden Gear.
	local balcony = base + axis * 9.2 + v3(0, 26.5, 0)
	ground("MillBalcony", v3(9, 1, 9), CFrame.lookAt(balcony, balcony + axis), WOOD, Enum.Material.WoodPlanks)
	Kit.lootSpot("Gear", CFrame.new(balcony + v3(0, 3, 0)))
	structure(
		"BalconyRail",
		v3(0.6, 3, 9),
		CFrame.lookAt(balcony + right * 4.6 + v3(0, 2, 0), balcony + right * 4.6 + axis + v3(0, 2, 0)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	structure(
		"BalconyRail",
		v3(0.6, 3, 9),
		CFrame.lookAt(balcony - right * 4.6 + v3(0, 2, 0), balcony - right * 4.6 + axis + v3(0, 2, 0)),
		DARK_WOOD,
		Enum.Material.Wood
	)

	-- Farmland: wheat and field patches, a farmhouse, a barn, haystacks, a few kegs of cider.
	local random = Kit.rng(77)
	for i = 1, 14 do
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(40, 100)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local y = groundY(x, z, -50)
		if y > 2 and (v3(x, 0, z) - v3(top.X, 0, top.Z)).Magnitude > 62 then
			local color = (i % 2 == 0) and Color3.fromRGB(235, 205, 90) or Color3.fromRGB(120, 190, 80)
			local patch = decor(
				"Field",
				v3(random:NextNumber(14, 26), 0.3, random:NextNumber(14, 26)),
				CFrame.new(x, y + 0.2, z) * CFrame.Angles(0, a, 0),
				color,
				Enum.Material.Grass
			)
			patch.CanQuery = false
		end
	end
	local farmY = groundY(cx - 55, cz + 62, 10)
	hut(
		CFrame.new(cx - 55, farmY, cz + 62) * CFrame.Angles(0, math.rad(20), 0),
		v3(14, 9, 12),
		Color3.fromRGB(170, 120, 80),
		Color3.fromRGB(160, 60, 50)
	)
	local barnY = groundY(cx + 70, cz + 40, 10)
	hut(
		CFrame.new(cx + 70, barnY, cz + 40) * CFrame.Angles(0, math.rad(-35), 0),
		v3(18, 11, 14),
		Color3.fromRGB(150, 60, 55),
		Color3.fromRGB(90, 90, 100)
	)
	for i = 1, 5 do
		local x, z = cx - 30 + i * 9, cz + 78 + (i % 2) * 6
		local y = groundY(x, z, 6)
		cylinder(
			"Haystack",
			3.2,
			4.5,
			v3(x, y + 2.2, z),
			Color3.fromRGB(235, 205, 90),
			Enum.Material.Grass,
			folders.structures
		)
	end
	for _, spot in ipairs({ { 75, 52 }, { 60, 36 } }) do
		local y = groundY(cx + spot[1], cz + spot[2], 8)
		table.insert(refs.kegCrates, Kit.kegCrate(v3(cx + spot[1], y, cz + spot[2])))
	end
	palm(cx + 100, cz - 30, nil, 12)
	dock(v3(cx - 20, 0, cz + 120), v3(cx - 20, 0, cz + 180), { 1 })
	islandSign(v3(cx + 10, hillTop + 70, cz - 10), w.name, w.color)
end

-- Smuggler's Cove gets a locked shed: a cracked wall that only a blast opens. ----------------
local function buildSmugglerStash()
	local s = info("Smuggler")
	local cx, cz = s.x, s.z
	local y = 4
	local base = CFrame.new(cx - 12, y, cz - 6)
	-- Three solid sides and a roof; the fourth wall is cracked.
	structure("ShedWall", v3(10, 8, 1), base * CFrame.new(0, 4, -5), STONE, Enum.Material.Brick)
	structure("ShedWall", v3(1, 8, 10), base * CFrame.new(-5, 4, 0), STONE, Enum.Material.Brick)
	structure("ShedWall", v3(10, 8, 1), base * CFrame.new(0, 4, 5), STONE, Enum.Material.Brick)
	structure("ShedRoof", v3(12, 1, 12), base * CFrame.new(0, 8.5, 0), DARK_STONE, Enum.Material.Slate)
	local cracked = Instance.new("Model")
	cracked.Name = "CrackedWall"
	local panel = Kit.partOf(
		cracked,
		"CrackedPanel",
		v3(1.2, 8, 10),
		base * CFrame.new(5, 4, 0),
		Color3.fromRGB(176, 150, 120),
		Enum.Material.Brick
	)
	for i = 1, 3 do
		Kit.partOf(
			cracked,
			"Crack",
			v3(0.2, 6 - i, 0.3),
			base * CFrame.new(5.7, 4, -3 + i * 2) * CFrame.Angles(0, 0, math.rad(12 * i - 20)),
			Color3.fromRGB(40, 30, 28),
			Enum.Material.Slate
		)
	end
	cracked.PrimaryPart = panel
	cracked.Parent = folders.structures
	table.insert(refs.breakables, { model = cracked, health = 1, kind = "weak", label = "Cracked wall" })
	Kit.lootSpot("Stash", base * CFrame.new(-1, 3, 0))
	pointLight(panel, Color3.fromRGB(255, 190, 120), 14, 1)
	-- Powder kegs beside the shed, and a barrel or two to blow up for fun.
	table.insert(refs.kegCrates, Kit.kegCrate(v3(cx + 14, y, cz + 4)))
	table.insert(refs.barrels, Kit.barrel(v3(cx + 20, y, cz - 6)))
	table.insert(refs.barrels, Kit.barrel(v3(cx + 22, y, cz - 2)))
end

-- The Tide Vault: a half-drowned temple. A portcullis seals the vault until a lever (far
-- off, on a pavilion) is pulled; a flooded drain tunnel is the back way in. Taking the pearl
-- slams the gate and floods the chamber: the lever (or the drain) is the way out. ------------
local function buildTideVault()
	local t = info("Tide")
	local cx, cz = t.x, t.z
	fillColumn(cx, cz, -30, -2.5, 150, Enum.Material.Sand) -- the wadeable shallows
	-- The temple platform.
	fillColumn(cx, cz, -3, 14, 48, Enum.Material.Rock)
	fillColumn(cx, cz, 11, 14, 47, Enum.Material.Slate)
	rockRamp(v3(cx, -2.5, cz - 82), v3(cx, 14, cz - 46), 12, Enum.Material.Rock)
	-- Chamber, entrance tunnel (south) and the drain tunnel (west, under the sea).
	terrain:FillBlock(CFrame.new(cx, 6.5, cz), v3(26, 9, 26), AIR)
	tunnel(v3(cx, 2, cz + 56), v3(cx, 2, cz + 11), 9, 8)
	rockRamp(v3(cx, -2.5, cz + 88), v3(cx, 2, cz + 50), 10, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(cx - 8, -2.5, cz - 8), 11, 3.2, AIR)
	terrain:FillBlock(CFrame.new(cx - 40, -4.5, cz - 8), v3(64, 5, 5.4), AIR)
	terrain:FillCylinder(CFrame.new(cx - 72, -2.5, cz - 8), 10, 3.2, AIR)
	-- A ring of glowing stones marks the drain's mouth in the shallows.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		neon(
			decor(
				"DrainStone",
				v3(1.4, 1.4, 1.4),
				CFrame.new(cx - 72 + math.cos(a) * 4.8, -1.2, cz - 8 + math.sin(a) * 4.8),
				Color3.fromRGB(110, 230, 255)
			)
		)
	end

	-- The portcullis (closed position and open position are both data for Mechanisms).
	local gateModel = Instance.new("Model")
	gateModel.Name = "VaultGate"
	local closed = CFrame.new(cx, 6, cz + 26)
	local bars =
		Kit.partOf(gateModel, "GateBars", v3(9.2, 8.4, 1.2), closed, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	for i = -3, 3 do
		Kit.partOf(
			gateModel,
			"GateBar",
			v3(0.5, 8.4, 1.6),
			closed * CFrame.new(i * 1.3, 0, 0),
			Color3.fromRGB(30, 30, 36),
			Enum.Material.Metal
		)
	end
	gateModel.PrimaryPart = bars
	gateModel.Parent = folders.structures
	local gateEntry = { model = gateModel, closed = closed, open = closed * CFrame.new(0, 9, 0), name = "Vault gate" }
	table.insert(refs.gates, gateEntry)

	-- The altar, runes and the pearl.
	structure("Altar", v3(7, 1.4, 7), CFrame.new(cx, 2.7, cz), Color3.fromRGB(190, 200, 210), Enum.Material.Marble)
	Kit.lootSpot("Vault", CFrame.new(cx, 3.4 + 2.2, cz))
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local dir = compass(angle)
		glow(v3(cx, 7, cz) + dir * 12, Color3.fromRGB(110, 230, 255), 22)
	end

	-- The lever pavilion out in the shallows, 100 studs from the gate.
	local pav = v3(cx + 50, -1, cz - 86)
	ground("PavilionDeck", v3(12, 1, 12), CFrame.new(pav), Color3.fromRGB(200, 205, 215), Enum.Material.Marble)
	for _, off in ipairs({ { 5, 5 }, { -5, 5 }, { 5, -5 }, { -5, -5 } }) do
		Kit.column(pav + v3(off[1], 0.5, off[2]), 9, 0.9, Color3.fromRGB(220, 225, 235), false)
	end
	local lever = Kit.lever(pav + v3(0, 0.5, 0), "Vault lever", gateEntry)
	table.insert(refs.levers, lever)

	-- Colonnade ring of broken columns across the shallows, lit with runes.
	local random = Kit.rng(909)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local r = 104 + random:NextNumber(-8, 8)
		local pos = v3(cx + math.cos(a) * r, -2.5, cz + math.sin(a) * r)
		Kit.column(pos, 16, 2.2, STONE, i % 3 ~= 0)
		if i % 4 == 0 then
			glow(pos + v3(0, 5, 0), Color3.fromRGB(110, 230, 255), 16)
		end
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		Kit.column(v3(cx + math.cos(a) * 34, 14, cz + math.sin(a) * 34), 15, 1.8, STONE, i % 2 == 0)
	end
	refs.troubleSites.Flood = {
		gate = gateEntry,
		chamberCenter = v3(cx, 6.5, cz),
		chamberSize = v3(26, 9, 26),
		tunnelCenter = v3(cx, 5, cz + 30),
		tunnelSize = v3(9, 6, 36),
		lever = lever,
	}
	dock(v3(cx + 24, 0, cz - 128), v3(cx + 24, 0, cz - 190), { -1 })
	islandSign(v3(cx, 60, cz), t.name, t.color)
end

function Islands.build()
	buildPebble()
	buildCoral()
	buildWindmill()
	buildSmugglerStash()
	buildTideVault()
end

return Islands

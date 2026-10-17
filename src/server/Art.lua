-- Island landmarks (V10, docs/ART_DIRECTION.md "Island identity"). Every major island gets one SIGNATURE shape
-- you can name from a boat hundreds of studs away: a tower of pebbles, a crown of coral, a smugglers' arch, a
-- colossal stone head, a broken galleon, crystal spires, a colossal tree, a drowned dome, black spikes round a
-- whirlpool, a volcano's plume, a giant golden sun, an ice needle, a sea serpent's ribcage, ghost lights.
--
-- Rules, so a landmark can never cost a goblin a route:
--   * Every piece is decoration: anchored, non-colliding, not hit by rays (grapples, aim, cannons pass through).
--   * Each landmark finds its own spot (findSpot): high ground for tall ones, the shallows for sea ones, and
--     always a clear distance from treasure, boat spawns, the Hoard, and every built thing (docks, ladders, decks,
--     ziplines, catapults, launch pads, cannons, levers) and every hoop and ramp.
--   * The search is deterministic, so the same landmark stands in the same place every raid.
--   * Each landmark model is persistent (streamed to every player), so it reads on the horizon. Tens of parts each.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Palette = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Palette"))

local Art = {}

local refs
local folders
local made = {} -- island id -> { model, position, parts }

local SLATE, GLASS, NEON = Enum.Material.Slate, Enum.Material.Glass, Enum.Material.Neon
local SMOOTH, WOOD, FABRIC = Enum.Material.SmoothPlastic, Enum.Material.Wood, Enum.Material.Fabric
local MARBLE, METAL, GRASS = Enum.Material.Marble, Enum.Material.Metal, Enum.Material.Grass

-- Pieces -------------------------------------------------------------------------------------------------
local current -- the model being built

local function piece(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = current
	return p
end

-- An ellipsoid: organic shapes (pebbles, domes, skulls, canopies) without any asset.
local function egg(name, size, cf, color, material)
	local p = piece(name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function ball(name, diameter, at, color, material)
	return piece(name, Vector3.new(diameter, diameter, diameter), CFrame.new(at), color, material, Enum.PartType.Ball)
end

-- A beam from a to b (square section).
local function beam(name, a, b, width, color, material)
	local mid = (a + b) / 2
	return piece(name, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt(mid, b), color, material)
end

-- A crystal / spike: a square shaft turned 45 degrees with a stepped point, leaning by `lean`.
local function spire(name, base, height, width, color, material, lean, core)
	local frame = CFrame.new(base) * lean
	local shaft = height * 0.72
	piece(
		name,
		Vector3.new(width, shaft, width),
		frame * CFrame.new(0, shaft / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
		color,
		material
	)
	local y, w = shaft, width
	for i = 1, 3 do
		local h = height * (0.12 - i * 0.02)
		w *= 0.62
		piece(
			name,
			Vector3.new(w, h, w),
			frame * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			color,
			material
		)
		y += h
	end
	if core then
		piece(
			name .. "Core",
			Vector3.new(width * 0.34, shaft * 0.8, width * 0.34),
			frame * CFrame.new(0, shaft * 0.45, 0),
			core,
			NEON
		)
	end
	return (frame * CFrame.new(0, y, 0)).Position
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.2
	l.Parent = part
	return l
end

-- Finding a place --------------------------------------------------------------------------------------------
local downParams = RaycastParams.new()
downParams.FilterType = Enum.RaycastFilterType.Include
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.IgnoreWater = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function keepClearPoints()
	local points = {}
	for _, cf in pairs(refs.lootSpots or {}) do
		table.insert(points, cf.Position)
	end
	for _, spawn in ipairs(refs.boatSpawns or {}) do
		table.insert(points, spawn.cf.Position)
	end
	if refs.hoard then
		table.insert(points, refs.hoard.position)
	end
	return points
end

local function isBusy(name)
	return string.find(name, "Hoop")
		or string.find(name, "Ramp")
		or string.find(name, "Kicker")
		or string.find(name, "Buoy")
end

-- The best spot on (or just off) an island. mode: "high" (the highest open ground), "shore" (low ground near the
-- water), "shallows" (water 2 to 14 studs deep). minF/maxF: the ring to search, as shares of the island's radius.
-- clear: studs to keep from anything built or anything players need.
function Art.findSpot(island, mode, minF, maxF, clear, avoid)
	local best, bestScore = nil, -math.huge
	local keep = keepClearPoints()
	for _, other in ipairs(avoid or {}) do
		table.insert(keep, other)
	end
	for ring = 0, 6 do
		local f = minF + (maxF - minF) * ring / 6
		for step = 0, 35 do
			local a = math.rad(step * 10 + ring * 5)
			local x, z = island.x + math.cos(a) * island.r * f, island.z + math.sin(a) * island.r * f
			local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -600, 0), downParams)
			if hit then
				local y = hit.Position.Y
				local water = hit.Material == Enum.Material.Water
				local score
				if mode == "high" and not water and y > 4 then
					score = y
				elseif mode == "shore" and not water and y > 0.5 and y < 10 then
					score = -math.abs(y - 3) + f * 10
				elseif mode == "shallows" and water then
					local floor = workspace:Raycast(Vector3.new(x, 2, z), Vector3.new(0, -60, 0), floorParams)
					local depth = floor and -floor.Position.Y or 60
					if depth > 2 and depth < 14 then
						score = -math.abs(depth - 6)
					end
				end
				if score and score > bestScore then
					local spot = Vector3.new(x, y, z)
					local ok = true
					for _, point in ipairs(keep) do
						if Vector3.new(point.X - x, 0, point.Z - z).Magnitude < clear + 12 then
							ok = false
							break
						end
					end
					if ok then
						for _, part in ipairs(workspace:GetPartBoundsInRadius(spot, clear, overlap)) do
							if part.Parent ~= folders.decor or isBusy(part.Name) then
								ok = false
								break
							end
						end
					end
					if ok then
						best, bestScore = spot, score
					end
				end
			end
		end
	end
	return best
end

-- The landmarks ---------------------------------------------------------------------------------------------
local B = {}

-- Pebble Isle: a tower of giant smooth pebbles balanced on each other, a sky-blue pennant on top.
function B.Pebble(at)
	local stones = {
		{ Vector3.new(32, 15, 28), Color3.fromRGB(176, 184, 192) },
		{ Vector3.new(25, 13, 22), Color3.fromRGB(214, 194, 162) },
		{ Vector3.new(20, 12, 18), Color3.fromRGB(150, 162, 176) },
		{ Vector3.new(14, 10, 13), Color3.fromRGB(222, 208, 184) },
		{ Vector3.new(9, 7, 9), Color3.fromRGB(132, 146, 162) },
	}
	local y = at.Y - 3
	for i, s in ipairs(stones) do
		local size = s[1]
		y += size.Y * 0.42
		egg(
			"Pebble",
			size,
			CFrame.new(at.X + (i % 2 == 0 and 1.6 or -1.2), y, at.Z)
				* CFrame.Angles(0, i * 0.7, (i % 2 == 0 and 0.12 or -0.1)),
			s[2],
			SMOOTH
		)
		y += size.Y * 0.42
	end
	-- Loose pebbles round its foot.
	for i = 0, 3 do
		local a = i * 1.7
		egg(
			"Pebble",
			Vector3.new(7, 4, 6),
			CFrame.new(at + Vector3.new(math.cos(a) * 19, -0.5, math.sin(a) * 19)) * CFrame.Angles(0, a, 0),
			stones[i % #stones + 1][2],
			SMOOTH
		)
	end
	piece("FlagPole", Vector3.new(0.7, 16, 0.7), CFrame.new(at.X, y + 7, at.Z), Palette.WOOD_DARK, WOOD)
	piece("Flag", Vector3.new(0.3, 5, 9), CFrame.new(at.X, y + 12.5, at.Z - 4.6), Color3.fromRGB(110, 190, 255), FABRIC)
end

-- Coral Atoll: a crown of giant branching coral round an opened giant shell with its glowing pearl.
function B.Coral(at)
	local random = Random.new(42)
	for i = 0, 5 do
		local a = i * math.pi / 3 + random:NextNumber(-0.2, 0.2)
		local base = at + Vector3.new(math.cos(a) * 22, -4, math.sin(a) * 22)
		local color = Palette.CORALS[i % #Palette.CORALS + 1]
		local h = random:NextNumber(20, 34)
		local stem = CFrame.new(base) * CFrame.Angles(math.cos(a) * 0.25, 0, -math.sin(a) * 0.25)
		piece("Coral", Vector3.new(3.4, h, 3.4), stem * CFrame.new(0, h / 2, 0), color, SLATE)
		for arm = 1, 2 do
			local tilt = (arm == 1 and 0.7 or -0.6)
			local frame = stem * CFrame.new(0, h * (0.5 + arm * 0.15), 0) * CFrame.Angles(0, a + arm, tilt)
			local len = h * 0.5
			piece("Coral", Vector3.new(2.4, len, 2.4), frame * CFrame.new(0, len / 2, 0), color, SLATE)
			ball(
				"CoralTip",
				3.6,
				(frame * CFrame.new(0, len, 0)).Position,
				color:Lerp(Color3.new(1, 1, 1), 0.25),
				SLATE
			)
		end
		ball("CoralTip", 4.4, (stem * CFrame.new(0, h, 0)).Position, color:Lerp(Color3.new(1, 1, 1), 0.25), SLATE)
	end
	-- The giant clam, open, pink and ridged, its pearl glowing.
	egg(
		"ShellBottom",
		Vector3.new(26, 8, 22),
		CFrame.new(at + Vector3.new(0, 0, 0)),
		Color3.fromRGB(255, 132, 146),
		SMOOTH
	)
	egg(
		"ShellTop",
		Vector3.new(26, 7, 22),
		CFrame.new(at + Vector3.new(0, 9, 7)) * CFrame.Angles(math.rad(-50), 0, 0),
		Color3.fromRGB(255, 108, 132),
		SMOOTH
	)
	for i = -2, 2 do
		piece(
			"ShellRidge",
			Vector3.new(1.2, 1.2, 18),
			CFrame.new(at + Vector3.new(0, 9, 7)) * CFrame.Angles(math.rad(-50), i * 0.28, 0) * CFrame.new(0, 3.4, 0),
			Color3.fromRGB(255, 186, 190),
			SMOOTH
		)
	end
	local pearl = ball("GiantPearl", 7, at + Vector3.new(0, 5, -1), Color3.fromRGB(255, 250, 240), NEON)
	light(pearl, Color3.fromRGB(255, 220, 240), 30, 1.2)
end

-- Smuggler's Cove: a natural sea arch of dark rock chunks, lanterns hanging from its span.
function B.Smuggler(at, yaw)
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local random = Random.new(11)
	local rocks = { Color3.fromRGB(112, 96, 112), Color3.fromRGB(86, 72, 90), Color3.fromRGB(132, 116, 128) }
	local R, H = 24, 40
	for i = 0, 14 do
		local t = i / 14
		local a = math.pi * t
		local s = 14 - 5 * math.sin(a) + random:NextNumber(-1.5, 1.5)
		local x = -R * math.cos(a)
		local y = H * math.sin(a) - 7
		piece(
			"ArchRock",
			Vector3.new(s * 1.15, s, s * 1.2),
			frame
				* CFrame.new(x, y, random:NextNumber(-1.5, 1.5))
				* CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(-0.4, 0.4), a - math.pi / 2),
			rocks[i % 3 + 1],
			SLATE
		)
	end
	-- A hooked crag on one shoulder, so the arch has a profile you can name.
	piece(
		"ArchCrag",
		Vector3.new(10, 18, 10),
		frame * CFrame.new(-18, 40, 0) * CFrame.Angles(0, 0.4, 0.55),
		rocks[2],
		SLATE
	)
	piece(
		"ArchCrag",
		Vector3.new(7, 10, 7),
		frame * CFrame.new(-25, 47, 0) * CFrame.Angles(0, 0.2, 1.1),
		rocks[1],
		SLATE
	)
	for i, x in ipairs({ -9, 0, 9 }) do
		local top = (frame * CFrame.new(x, H - 16 - math.abs(x) * 0.3, 0)).Position
		beam("LanternChain", top, top - Vector3.new(0, 6 + i, 0), 0.25, Palette.IRON, METAL)
		local lamp = piece(
			"Lantern",
			Vector3.new(1.8, 2.4, 1.8),
			CFrame.new(top - Vector3.new(0, 7.4 + i, 0)),
			Color3.fromRGB(255, 170, 70),
			NEON
		)
		if i == 2 then
			light(lamp, Color3.fromRGB(255, 170, 80), 34, 1.4)
		end
	end
end

-- Crossroads Ruins: a colossal stone head, half sunk and leaning, one eye still burning red.
function B.Cross(at, yaw)
	local frame = CFrame.new(at - Vector3.new(0, 10, 0))
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(math.rad(-6), 0, math.rad(7))
	local stone, dark = Color3.fromRGB(138, 140, 144), Color3.fromRGB(100, 102, 108)
	local socket = Color3.fromRGB(40, 32, 28)
	local function block(name, size, x, y, z, color)
		return piece(name, size, frame * CFrame.new(x, y, z), color or stone, SLATE)
	end
	block("Head", Vector3.new(22, 44, 20), 0, 22, 0)
	block("Brow", Vector3.new(24, 6, 6), 0, 34, -9.5, dark)
	block("Nose", Vector3.new(6, 18, 7), 0, 22, -12)
	block("NoseTip", Vector3.new(9, 4, 8), 0, 13.5, -12.5, dark)
	block("Lips", Vector3.new(14, 3, 3), 0, 8, -10.5, dark)
	block("Chin", Vector3.new(20, 6, 18), 0, 2, -1)
	for _, side in ipairs({ -1, 1 }) do
		block("Ear", Vector3.new(3, 18, 6), side * 12, 24, 0, dark)
		block("Socket", Vector3.new(7, 5, 2), side * 6.5, 29, -10.3, socket)
	end
	local eye = block("WatcherEye", Vector3.new(4, 3, 1), -6.5, 29, -11.1, Palette.DANGER)
	eye.Material = NEON -- no light: a red light washes the whole head pink
	piece(
		"Topknot",
		Vector3.new(10, 20, 20),
		frame * CFrame.new(0, 49, 1) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(132, 94, 80),
		SLATE,
		Enum.PartType.Cylinder
	)
	piece("Moss", Vector3.new(18, 1, 5), frame * CFrame.new(0, 37.4, -8), Color3.fromRGB(98, 170, 74), GRASS)
	piece("Moss", Vector3.new(14, 1.2, 14), frame * CFrame.new(-2, 54.4, 1), Color3.fromRGB(98, 170, 74), GRASS)
	piece(
		"Crack",
		Vector3.new(0.6, 16, 0.6),
		frame * CFrame.new(7.5, 18, -10.2) * CFrame.Angles(0, 0, 0.35),
		Color3.fromRGB(60, 50, 44),
		SLATE
	)
end

-- Shipwreck Shoals: a galleon broken in two on the sandbar, ribs bare between the halves, masts askew.
function B.Shoals(at, yaw)
	local S = 1.4
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local wood, drift = Color3.fromRGB(128, 96, 70), Palette.DRIFTWOOD
	local canvas = Color3.fromRGB(232, 220, 192)
	local function at3(x, y, z)
		return CFrame.new(x * S, y * S, z * S)
	end
	local bow = frame * at3(0, 2, -26) * CFrame.Angles(math.rad(-16), 0, math.rad(18))
	piece("WreckHull", Vector3.new(14, 11, 30) * S, bow, wood, Enum.Material.WoodPlanks)
	piece(
		"WreckStripe",
		Vector3.new(14.4, 1.4, 30.4) * S,
		bow * at3(0, 3, 0),
		Color3.fromRGB(176, 60, 48),
		Enum.Material.WoodPlanks
	)
	piece(
		"WreckBow",
		Vector3.new(10, 9, 10) * S,
		bow * at3(0, 0, -17) * CFrame.Angles(0, math.rad(45), 0),
		wood,
		Enum.Material.WoodPlanks
	)
	piece("WreckMast", Vector3.new(1.6, 34, 1.6) * S, bow * at3(0, 20, 2) * CFrame.Angles(0, 0, 0.2), drift, WOOD)
	piece("WreckSail", Vector3.new(0.4, 12, 13) * S, bow * at3(1, 26, 2) * CFrame.Angles(0, 0, 0.2), canvas, FABRIC)
	piece("WreckSail", Vector3.new(0.4, 6, 9) * S, bow * at3(1, 17, 3) * CFrame.Angles(0.15, 0, 0.3), canvas, FABRIC)
	local stern = frame * at3(3, 1, 22) * CFrame.Angles(math.rad(12), math.rad(20), math.rad(-14))
	piece("WreckHull", Vector3.new(15, 12, 24) * S, stern, wood, Enum.Material.WoodPlanks)
	piece(
		"WreckStripe",
		Vector3.new(15.4, 1.4, 24.4) * S,
		stern * at3(0, 3, 0),
		Color3.fromRGB(176, 60, 48),
		Enum.Material.WoodPlanks
	)
	piece(
		"WreckCastle",
		Vector3.new(14, 7, 10) * S,
		stern * at3(0, 9, 6),
		Color3.fromRGB(110, 80, 58),
		Enum.Material.WoodPlanks
	)
	for i = -2, 2 do
		piece(
			"WreckWindow",
			Vector3.new(1.6, 2, 0.4) * S,
			stern * at3(i * 2.6, 9, 11.1),
			Color3.fromRGB(255, 214, 120),
			NEON
		)
	end
	piece(
		"WreckMast",
		Vector3.new(1.4, 24, 1.4) * S,
		stern * at3(-1, 18, -2) * CFrame.Angles(0.5, 0, -0.4),
		drift,
		WOOD
	)
	piece(
		"WreckFlag",
		Vector3.new(0.3, 3, 5) * S,
		stern * at3(-1, 28, -9) * CFrame.Angles(0.5, 0, -0.4),
		Color3.fromRGB(30, 30, 34),
		FABRIC
	)
	-- Bare ribs between the halves.
	for i = -2, 2 do
		for _, side in ipairs({ -1, 1 }) do
			local z = i * 4.2
			beam(
				"Rib",
				(frame * at3(side * 3, -1, z)).Position,
				(frame * at3(side * 7, 9 - math.abs(i), z)).Position,
				1.2 * S,
				drift,
				WOOD
			)
		end
	end
	beam("Keel", (frame * at3(0, -1.5, -12)).Position, (frame * at3(1, -1, 12)).Position, 1.6 * S, wood, WOOD)
end

-- Crystal Isle: a crown of violet and cyan crystal spires, glowing from inside.
function B.Crystal(at)
	local random = Random.new(7)
	local colors = { Color3.fromRGB(168, 92, 255), Color3.fromRGB(60, 214, 255), Color3.fromRGB(236, 120, 255) }
	local top = spire(
		"Crystal",
		at - Vector3.new(0, 4, 0),
		96,
		16,
		colors[1],
		GLASS,
		CFrame.new(),
		Color3.fromRGB(230, 190, 255)
	)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7 + random:NextNumber(-0.25, 0.25)
		local base = at + Vector3.new(math.cos(a) * 15, -4, math.sin(a) * 15)
		local lean = CFrame.Angles(math.sin(a) * 0.38, 0, -math.cos(a) * 0.38)
		local color = colors[i % 3 + 1]
		spire(
			"Crystal",
			base,
			random:NextNumber(30, 58),
			random:NextNumber(6, 10),
			color,
			GLASS,
			lean,
			i % 2 == 0 and color:Lerp(Color3.new(1, 1, 1), 0.5) or nil
		)
	end
	local glow = piece("CrystalGlow", Vector3.new(1, 1, 1), CFrame.new(top - Vector3.new(0, 40, 0)), colors[1], NEON)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(200, 150, 255), 60, 1.6)
end

-- Tangle Isle: a colossal twisted tree, buttress roots gripping the hill, a layered jungle canopy with purple
-- blossom and hanging vines.
function B.Tangle(at)
	local bark, barkDark = Color3.fromRGB(122, 86, 60), Color3.fromRGB(92, 62, 44)
	local pos = at - Vector3.new(0, 3, 0)
	local width = 20
	for i = 1, 6 do
		local twist = CFrame.Angles(0, i * 0.5, 0) * CFrame.Angles(0.1, 0, (i % 2 == 0) and 0.08 or -0.07)
		local h = 14
		local frame = CFrame.new(pos) * twist
		piece(
			"TreeTrunk",
			Vector3.new(width, h + 2, width),
			frame * CFrame.new(0, h / 2, 0),
			i % 2 == 0 and bark or barkDark,
			WOOD
		)
		pos = (frame * CFrame.new(0, h, 0)).Position
		width *= 0.84
	end
	-- Buttress roots: out, down, and into the ground.
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7 + 0.3
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local knee = at + out * 15 + Vector3.new(0, 5, 0)
		beam("Root", at + Vector3.new(0, 12, 0) + out * 5, knee, 7, barkDark, WOOD)
		beam("Root", knee, at + out * 27 - Vector3.new(0, 5, 0), 5, barkDark, WOOD)
	end
	-- A big branch or two holding up the canopy's edges.
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		beam("Branch", pos - Vector3.new(0, 10, 0), pos + out * 24 + Vector3.new(0, 4, 0), 4, bark, WOOD)
	end
	-- The canopy: wide flattened layers, dark below and light on top.
	local dark, lite = Palette.LEAVES.jungle[2], Palette.LEAVES.jungle[1]
	egg("Canopy", Vector3.new(76, 26, 70), CFrame.new(pos + Vector3.new(0, 6, 0)), dark, GRASS)
	local layers =
		{ { 14, 16, 8, 44 }, { -16, 15, -10, 46 }, { 6, 22, -18, 38 }, { -10, 20, 16, 40 }, { 0, 26, 0, 40 } }
	for _, c in ipairs(layers) do
		egg(
			"Canopy",
			Vector3.new(c[4], c[4] * 0.42, c[4]),
			CFrame.new(pos + Vector3.new(c[1], c[2], c[3])),
			lite,
			GRASS
		)
	end
	local blossom = Palette.LEAVES.blossom
	for i = 0, 7 do
		local a = i * math.pi / 4 + 0.2
		ball(
			"Blossom",
			10 + (i % 3) * 2,
			pos + Vector3.new(math.cos(a) * 30, 14 + (i % 2) * 8, math.sin(a) * 28),
			blossom[i % 2 + 1],
			GRASS
		)
	end
	-- Vines hanging from the canopy's underside.
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.5
		local top = pos + Vector3.new(math.cos(a) * 26, -2, math.sin(a) * 24)
		beam("Vine", top, top - Vector3.new(0, 16 + (i % 3) * 5, 0), 0.7, Color3.fromRGB(70, 140, 60), GRASS)
	end
end

-- Tide Vault: a drowned temple dome rising out of the shallows, green with age, a ring of broken columns.
function B.Tide(at)
	local marble = Palette.MARBLE
	local patina = Color3.fromRGB(104, 186, 164)
	egg("DrownedDome", Vector3.new(42, 34, 42), CFrame.new(at + Vector3.new(0, 2, 0)), marble, MARBLE)
	egg("DomePatina", Vector3.new(30, 18, 30), CFrame.new(at + Vector3.new(0, 12.6, 0)), patina, MARBLE)
	piece(
		"DomeRing",
		Vector3.new(3, 46, 46),
		CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		patina,
		MARBLE,
		Enum.PartType.Cylinder
	)
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = at + out * 19.6 + Vector3.new(0, 7, 0)
		piece("DomeWindow", Vector3.new(3.4, 6, 1), CFrame.lookAt(p, p + out), Color3.fromRGB(26, 44, 58), SLATE)
	end
	piece("Finial", Vector3.new(2, 14, 2), CFrame.new(at + Vector3.new(0, 25, 0)), Palette.GOLD, METAL)
	ball("FinialOrb", 4, at + Vector3.new(0, 32, 0), Palette.GOLD, METAL)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local base = at + Vector3.new(math.cos(a) * 30, -6, math.sin(a) * 30)
		local h = (i % 3 == 0) and 14 or 24
		piece(
			"Column",
			Vector3.new(h, 3.6, 3.6),
			CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			marble,
			MARBLE,
			Enum.PartType.Cylinder
		)
		if h > 20 then
			piece("ColumnCap", Vector3.new(5.6, 1.4, 5.6), CFrame.new(base + Vector3.new(0, h, 0)), marble, MARBLE)
		end
	end
end

-- Maelstrom Rock: black spikes leaning in round the whirlpool's rock, foam at their feet.
function B.Maelstrom(at)
	local random = Random.new(9)
	local black = Color3.fromRGB(46, 44, 56)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7 + random:NextNumber(-0.2, 0.2)
		local base = at + Vector3.new(math.cos(a) * 26, -6, math.sin(a) * 26)
		-- Leaning OUT, like teeth round the whirlpool's mouth.
		local lean = CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4)
		spire(
			"Spike",
			base,
			random:NextNumber(30, 54),
			random:NextNumber(4, 6.5),
			i % 2 == 0 and black or Color3.fromRGB(70, 66, 82),
			SLATE,
			lean
		)
	end
	local foam =
		egg("Foam", Vector3.new(70, 1.2, 70), CFrame.new(at.X, 0.6, at.Z), Color3.fromRGB(236, 246, 255), SMOOTH)
	foam.Transparency = 0.45
end

-- Ember Isle: lava glowing down the volcano's flanks (the crater's own smoke and glow are IslandsFar's).
function B.Ember(at)
	-- Lava streams: short neon segments laid down the slope from the crater, following the ground.
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local last
		for step = 0, 6 do
			local flatAt = at + out * (12 + step * 14)
			local hit = workspace:Raycast(Vector3.new(flatAt.X, 500, flatAt.Z), Vector3.new(0, -600, 0), downParams)
			if not hit or hit.Material == Enum.Material.Water then
				break
			end
			local point = hit.Position + Vector3.new(0, 0.6, 0)
			if last then
				local stream = beam("LavaStream", last, point, 3.4 - step * 0.3, Palette.EMBER, NEON)
				stream.CastShadow = false
			end
			last = point
		end
	end
end

-- Sun Temple: a giant golden sun disc on a stone pillar, rays turning slowly in the light. The temple's crown.
function B.Temple(at, yaw)
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	piece("SunPillar", Vector3.new(8, 34, 8), frame * CFrame.new(0, 15, 0), Color3.fromRGB(204, 186, 152), SLATE)
	piece("SunPillarCap", Vector3.new(11, 3, 11), frame * CFrame.new(0, 33, 0), Color3.fromRGB(176, 156, 122), SLATE)
	local center = frame * CFrame.new(0, 58, 0)
	piece(
		"SunDisc",
		Vector3.new(3, 40, 40),
		center * CFrame.Angles(0, math.rad(90), 0),
		Palette.GOLD,
		METAL,
		Enum.PartType.Cylinder
	)
	local core = piece(
		"SunCore",
		Vector3.new(3.4, 24, 24),
		center * CFrame.new(0, 0, -0.6) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 220, 120),
		NEON,
		Enum.PartType.Cylinder
	)
	piece(
		"SunCore",
		Vector3.new(3.4, 24, 24),
		center * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 220, 120),
		NEON,
		Enum.PartType.Cylinder
	)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local long = i % 2 == 0
		piece(
			"SunRay",
			Vector3.new(long and 4 or 3, long and 14 or 9, 2),
			center * CFrame.Angles(0, 0, a) * CFrame.new(0, long and 27 or 24.5, 0),
			Palette.GOLD_DEEP,
			METAL
		)
	end
	light(core, Color3.fromRGB(255, 210, 120), 90, 2)
end

-- Frost Spire: a tall twisted needle of ice, shards round its foot.
function B.Frost(at)
	local pos = at - Vector3.new(0, 3, 0)
	local width = 22
	for i = 1, 9 do
		local h = 16
		local frame = CFrame.new(pos) * CFrame.Angles(0, i * math.rad(18), 0) * CFrame.Angles(0.04, 0, -0.03)
		piece(
			"IceNeedle",
			Vector3.new(width, h + 1, width),
			frame * CFrame.new(0, h / 2, 0),
			i % 2 == 0 and Color3.fromRGB(150, 214, 252) or Color3.fromRGB(104, 184, 244),
			GLASS
		)
		pos = (frame * CFrame.new(0, h, 0)).Position
		width *= 0.8
	end
	piece("IceTip", Vector3.new(2, 14, 2), CFrame.new(pos + Vector3.new(0, 7, 0)), Palette.SNOW, Enum.Material.Ice)
	local random = Random.new(3)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local base = at + Vector3.new(math.cos(a) * 20, -3, math.sin(a) * 20)
		spire(
			"IceShard",
			base,
			random:NextNumber(12, 24),
			random:NextNumber(4, 6),
			Palette.FROST,
			Enum.Material.Ice,
			CFrame.Angles(-math.sin(a) * 0.4, 0, math.cos(a) * 0.4)
		)
	end
end

-- Leviathan's Rest: a sea serpent's skeleton half out of the shallows: curved ribs on a long spine, the horned
-- skull laid on the sand with its jaw fallen open.
function B.Bone(at, yaw)
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local bone, boneDark = Color3.fromRGB(222, 212, 186), Color3.fromRGB(196, 184, 156)
	local function p3(x, y, z)
		return (frame * CFrame.new(x, y, z)).Position
	end
	local function chain(name, points, w0, w1)
		for i = 1, #points - 1 do
			local w = w0 + (w1 - w0) * (i - 1) / math.max(1, #points - 2)
			beam(name, points[i], points[i + 1], w, bone, SMOOTH)
		end
	end
	local spine = {}
	for i = 0, 6 do
		local z = -36 + i * 12
		local s = 1 - math.abs(i - 2.5) * 0.1
		local top = 2 + 26 * s
		table.insert(spine, p3(0, top, z))
		for _, side in ipairs({ -1, 1 }) do
			local points = {}
			for k = 0, 5 do
				local a = math.rad(k * 23)
				table.insert(points, p3(side * 16 * s * math.sin(a), 2 + 26 * s * math.cos(a) - (k == 5 and 6 or 0), z))
			end
			chain("Rib", points, 2.6, 1.6)
		end
	end
	table.insert(spine, 1, p3(0, 14, -50))
	table.insert(spine, 1, p3(0, 8, -58))
	table.insert(spine, p3(0, 12, 50))
	table.insert(spine, p3(0, 2, 62))
	chain("Spine", spine, 3.6, 2)
	-- The skull: a long cranium, a snout, heavy brows, deep sockets, curling horns, a fallen jaw with teeth.
	local skull = frame * CFrame.new(0, 7, -64)
	egg("Cranium", Vector3.new(18, 13, 20), skull, bone, SMOOTH)
	egg("Snout", Vector3.new(11, 7, 22), skull * CFrame.new(0, -1.5, -14), bone, SMOOTH)
	egg("Jaw", Vector3.new(10, 4, 22), skull * CFrame.new(0, -6.5, -12) * CFrame.Angles(0.3, 0, 0), boneDark, SMOOTH)
	for _, side in ipairs({ -1, 1 }) do
		egg("Brow", Vector3.new(7, 4, 9), skull * CFrame.new(side * 5.4, 5, -4), boneDark, SMOOTH)
		egg("Socket", Vector3.new(4, 5, 6), skull * CFrame.new(side * 7.6, 2.2, -5), Color3.fromRGB(30, 40, 46), SMOOTH)
		chain("Horn", {
			(skull * CFrame.new(side * 5, 5, 3)).Position,
			(skull * CFrame.new(side * 9, 11, 12)).Position,
			(skull * CFrame.new(side * 10, 13, 22)).Position,
			(skull * CFrame.new(side * 8, 11, 28)).Position,
		}, 2.6, 1.2)
		for k = 0, 3 do
			piece(
				"Tooth",
				Vector3.new(0.8, 3, 1.6),
				skull * CFrame.new(side * 4.4, -5.2, -8 - k * 4) * CFrame.Angles(math.rad(180), 0, 0),
				Color3.fromRGB(250, 246, 232),
				SMOOTH,
				Enum.PartType.Wedge
			)
		end
	end
end

-- Skull Rock: the skull's eyes burn ghost-teal, ghost lanterns ring the shore.
function B.Skull(_at, _yaw, island)
	for _, p in ipairs(folders.decor:GetChildren()) do
		if
			p.Name == "SkullEye"
			and Vector3.new(p.Position.X - island.x, 0, p.Position.Z - island.z).Magnitude < 160
		then
			p.Material = NEON
			p.Color = Palette.GHOST
			light(p, Palette.GHOST, 18, 1.2) -- short: a long light dyes the whole skull teal
		end
	end
	-- Lanterns round the shore: walk in from the sea along twelve bearings to the first dry ground.
	local spots = {}
	for i = 0, 11 do
		local a = i * math.pi / 6 + 0.2
		for f = 0.95, 0.3, -0.05 do
			local x, z = island.x + math.cos(a) * island.r * f, island.z + math.sin(a) * island.r * f
			local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), downParams)
			if hit and hit.Material ~= Enum.Material.Water and hit.Position.Y > 1 then
				table.insert(spots, hit.Position)
				break
			end
		end
	end
	for _, spot in ipairs(spots) do
		piece(
			"GhostPost",
			Vector3.new(0.7, 9, 0.7),
			CFrame.new(spot + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0.1, 0, -0.08),
			Color3.fromRGB(60, 70, 72),
			WOOD
		)
		local lamp = piece(
			"GhostLantern",
			Vector3.new(1.6, 2.2, 1.6),
			CFrame.new(spot + Vector3.new(0.4, 9.6, 0)),
			Palette.GHOST,
			NEON
		)
		lamp.Transparency = 0.1
	end
end

-- Windmill Hills: farm country. The fields become a patchwork of wheat, lavender, tulips and pumpkins in rows;
-- the mill is whitewashed with a red cap and canvas sails; the huts get red barn roofs. Only colours and
-- decoration: every part that existed keeps its size, place and collision.
function B.Windmill(_at, _yaw, island)
	local crops = {
		{ ground = Color3.fromRGB(150, 128, 60), row = Color3.fromRGB(240, 198, 80) }, -- wheat
		{ ground = Color3.fromRGB(96, 120, 70), row = Color3.fromRGB(168, 126, 224) }, -- lavender
		{ ground = Color3.fromRGB(104, 84, 60), row = Color3.fromRGB(98, 168, 68), pumpkins = true },
		{ ground = Color3.fromRGB(96, 130, 64), row = Color3.fromRGB(232, 74, 80) }, -- tulips
	}
	local function near(p)
		return Vector3.new(p.Position.X - island.x, 0, p.Position.Z - island.z).Magnitude < island.r
	end
	local fields = {}
	for _, p in ipairs(folders.decor:GetChildren()) do
		if p.Name == "Field" and p:IsA("BasePart") and near(p) then
			table.insert(fields, p)
		end
	end
	table.sort(fields, function(a, b)
		return a.Position.X + a.Position.Z * 0.01 < b.Position.X + b.Position.Z * 0.01
	end)
	for i, field in ipairs(fields) do
		local crop = crops[i % #crops + 1]
		field.Color = crop.ground
		field.Material = Enum.Material.Ground
		local long = field.Size.Z >= field.Size.X
		local across = long and field.Size.X or field.Size.Z
		local along = long and field.Size.Z or field.Size.X
		for r = -1, 1 do
			local offset = long and CFrame.new(r * across * 0.3, 0.3, 0) or CFrame.new(0, 0.3, r * across * 0.3)
			local size = long and Vector3.new(1.6, 0.5, along * 0.9) or Vector3.new(along * 0.9, 0.5, 1.6)
			piece("CropRow", size, field.CFrame * offset, crop.row, GRASS)
			if crop.pumpkins then
				for k = -1, 1, 2 do
					local spot = long and CFrame.new(r * across * 0.3 + 1.4, 1.2, k * along * 0.22)
						or CFrame.new(k * along * 0.22, 1.2, r * across * 0.3 + 1.4)
					ball("Pumpkin", 2.4, (field.CFrame * spot).Position, Color3.fromRGB(240, 134, 40), SMOOTH)
				end
			end
		end
	end
	for _, p in ipairs(folders.structures:GetChildren()) do
		if p:IsA("BasePart") and near(p) then
			if p.Name == "MillTower" then
				p.Color = Color3.fromRGB(238, 230, 214)
			elseif p.Name == "MillCap" then
				p.Color = Color3.fromRGB(196, 62, 50)
			elseif p.Name == "SailCloth" then
				p.Color = Color3.fromRGB(248, 240, 222)
			elseif p.Name == "HutRoof" then
				p.Color = Color3.fromRGB(190, 64, 52)
			end
		end
	end
end

-- Fort Barnacle: the Navy's colours. Long navy banners down every tower and bunting strung between them. The
-- towers keep their Watchers on top; nothing here touches the walls, ladders, gate or cannon.
function B.Fort(_at, _yaw, island)
	local towers = {}
	local middle = Vector3.zero
	for _, p in ipairs(folders.structures:GetChildren()) do
		if
			p.Name == "FortTower"
			and Vector3.new(p.Position.X - island.x, 0, p.Position.Z - island.z).Magnitude < island.r
		then
			table.insert(towers, p)
			middle += p.Position
		end
	end
	if #towers == 0 then
		return
	end
	middle /= #towers
	local navy, white, red, gold = Palette.NAVY, Color3.fromRGB(240, 240, 236), Palette.DANGER, Palette.GOLD
	local tops = {}
	for _, tower in ipairs(towers) do
		local height, radius = tower.Size.X, tower.Size.Y / 2
		local top = tower.Position.Y + height / 2
		local out = Vector3.new(tower.Position.X - middle.X, 0, tower.Position.Z - middle.Z).Unit
		for _, turn in ipairs({ -0.75, 0.75 }) do
			local dir = CFrame.Angles(0, turn, 0):VectorToWorldSpace(out)
			local at = tower.Position + dir * (radius + 0.3)
			local face = CFrame.lookAt(Vector3.new(at.X, top - 9, at.Z), Vector3.new(at.X, top - 9, at.Z) + dir)
			piece("Banner", Vector3.new(6, 14, 0.4), face, navy, FABRIC)
			piece("BannerStripe", Vector3.new(6.1, 1, 0.5), face * CFrame.new(0, -4.6, 0), white, FABRIC)
			piece("BannerTail", Vector3.new(6, 2.4, 0.4), face * CFrame.new(0, -8.2, 0), red, FABRIC)
			ball("BannerBadge", 2.6, (face * CFrame.new(0, 2.4, -0.4)).Position, gold, METAL)
		end
		table.insert(
			tops,
			{ position = Vector3.new(tower.Position.X, top + 1.5, tower.Position.Z), angle = math.atan2(out.Z, out.X) }
		)
	end
	-- Bunting round the ring of towers.
	table.sort(tops, function(a, b)
		return a.angle < b.angle
	end)
	local colors = { navy, white, red }
	for i, entry in ipairs(tops) do
		local a, b = entry.position, tops[i % #tops + 1].position
		local last = a
		for k = 1, 9 do
			local t = k / 9
			local point = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 6, 0)
			beam("BuntingLine", last, point, 0.2, Palette.ROPE, FABRIC)
			if k < 9 then
				local flat = (b - a) * Vector3.new(1, 0, 1)
				piece(
					"Bunting",
					Vector3.new(0.2, 2.2, 1.8),
					CFrame.lookAt(point, point + flat)
						* CFrame.new(0, -1.2, 0)
						* CFrame.Angles(math.rad(180), math.rad(90), 0),
					colors[k % 3 + 1],
					FABRIC,
					Enum.PartType.Wedge
				)
			end
			last = point
		end
	end
end

-- Where each landmark goes: { mode, minF, maxF, clear }.
local PLACES = {
	Pebble = { "high", 0.1, 0.7, 14 },
	Coral = { "shallows", 0.7, 1.4, 26 },
	Smuggler = { "shallows", 0.8, 1.4, 30 },
	Cross = { "high", 0.3, 0.85, 26 },
	Shoals = { "shallows", 0.6, 1.25, 34 },
	Crystal = { "high", 0.25, 0.8, 22 },
	Tangle = { "high", 0.2, 0.75, 32 },
	Tide = { "shallows", 0.8, 1.35, 34 },
	Maelstrom = { "shallows", 0.7, 1.6, 30 },
	Ember = { "high", 0, 0.35, 8 },
	Temple = { "high", 0.3, 0.85, 30 },
	Frost = { "high", 0.3, 0.85, 22 },
	Bone = { "shallows", 0.75, 1.3, 40 },
	Skull = { "self" },
	Windmill = { "self" },
	Fort = { "self" },
}

-- Build every island's landmark. Run after the islands, the sea runs and the boats' spawns are in refs.
function Art.dress(worldRefs)
	refs = worldRefs
	folders = refs.folders
	downParams.FilterDescendantsInstances = { workspace.Terrain, folders.ground }
	downParams.IgnoreWater = false
	floorParams.FilterDescendantsInstances = { workspace.Terrain, folders.ground }
	overlap.FilterDescendantsInstances = {
		folders.structures,
		folders.ground,
		folders.ziplines,
		folders.launchPads,
		folders.loot,
		folders.decor,
		folders.coins,
	}
	local placed = {}
	for id, place in pairs(PLACES) do
		local island = Archipelago.byId[id]
		local build = B[id]
		if island and build then
			local at
			if place[1] == "self" then
				at = Vector3.new(island.x, 0, island.z)
			else
				at = Art.findSpot(island, place[1], place[2], place[3], place[4])
					-- A crowded island: look further out and settle for a little less room.
					or Art.findSpot(island, place[1], place[2] * 0.5, place[3] * 1.4, place[4] * 0.6)
			end
			if at then
				current = Instance.new("Model")
				current.Name = "Landmark" .. id
				current.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
				-- Face out to sea (from the island's middle toward the spot).
				local out = Vector3.new(at.X - island.x, 0, at.Z - island.z)
				local yaw = out.Magnitude > 1 and math.atan2(-out.X, -out.Z) or 0
				build(at, yaw, island)
				local count = 0
				for _, p in ipairs(current:GetDescendants()) do
					if p:IsA("BasePart") then
						count += 1
					end
				end
				current.Parent = folders.landmarks
				made[id] = { model = current, position = at, parts = count }
				table.insert(placed, id)
				current = nil
			else
				table.insert(refs.buildWarnings, "No clear spot for " .. id .. "'s landmark")
			end
		end
	end
	return placed
end

-- For tests and the report: where each landmark went.
function Art.landmarks()
	return made
end

return Art

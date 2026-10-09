-- Shared building blocks for the generated world: part and terrain helpers, docks,
-- bridges, ladders, signs, totems and the traversal toys. World.lua builds the
-- original five islands with them and Islands.lua builds the rest of the archipelago.
-- One module holds the folders and refs tables so every builder fills the same ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local Kit = {}

local SEA_Y = 0
local STONE = Color3.fromRGB(150, 145, 140)
local DARK_STONE = Color3.fromRGB(85, 80, 90)
local SANDSTONE = Color3.fromRGB(226, 190, 122)
local WOOD = Color3.fromRGB(120, 80, 48)
local DARK_WOOD = Color3.fromRGB(78, 52, 34)
local GOLD = Color3.fromRGB(255, 200, 40)
local CAVE_GLOW = Color3.fromRGB(120, 255, 200)
Kit.SEA_Y = SEA_Y
Kit.STONE, Kit.DARK_STONE, Kit.SANDSTONE = STONE, DARK_STONE, SANDSTONE
Kit.WOOD, Kit.DARK_WOOD, Kit.GOLD, Kit.CAVE_GLOW = WOOD, DARK_WOOD, GOLD, CAVE_GLOW

local terrain = workspace.Terrain
local folders: { [string]: Folder } = {}
local refs: { [string]: any } = {}
Kit.terrain, Kit.folders, Kit.refs = terrain, folders, refs

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

-- Unit vector pointing out from an island center at a compass angle (degrees).
-- 0 is east (+X), 90 is south (+Z), 180 is west, 270 is north.
local function compass(degrees)
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- A ladder you can climb (Roblox climbs TrussParts on its own).
local function ladder(name, bottom, height)
	local h = math.max(2, math.floor(height / 2 + 0.5) * 2)
	local truss = Instance.new("TrussPart")
	truss.Name = name
	truss.Size = Vector3.new(2, h, 2)
	truss.CFrame = CFrame.new(bottom + Vector3.new(0, h / 2, 0))
	truss.Anchored = true
	truss.Color = DARK_WOOD
	truss.Material = Enum.Material.Wood
	truss.Parent = folders.structures
	return truss
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

-- A cliff-walled plateau: rock all the way up, a thin top layer.
local function mesa(center, radius, bottomY, topY, material, topMaterial)
	fillColumn(center.X, center.Z, bottomY, topY, radius, material)
	fillColumn(center.X, center.Z, topY - 3, topY, radius - 1, topMaterial or material)
end

-- A natural rock ramp whose walking surface runs from a to b. It is a thick
-- tilted block, so its underside stays buried in whatever it leans on.
local function rockRamp(a, b, width, material)
	local length = (b - a).Magnitude
	local thickness = math.abs(b.Y - a.Y) + 8
	local cframe = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -thickness / 2, 0)
	terrain:FillBlock(cframe, Vector3.new(width, thickness, length + 4), material or Enum.Material.Rock)
end

-- A rock ramp hugging the outside of a round cliff. It climbs `length` studs
-- around the cliff from lowY and arrives at the cliff top (topY) at `degrees`,
-- right beside the edge. turn (1 or -1) picks which way around it climbs.
local function cliffRamp(center, radius, degrees, lowY, topY, length, turn, width, material)
	width = width or 12
	local out = compass(degrees)
	local along = Vector3.new(-out.Z, 0, out.X) * turn
	local r = radius + width / 2 - 1
	local top = Vector3.new(center.X, topY, center.Z) + out * r
	local foot = top - along * length
	rockRamp(Vector3.new(foot.X, lowY, foot.Z), top, width, material)
	return Vector3.new(foot.X, lowY, foot.Z), top
end

-- Carves a walkable tunnel whose floor runs from a to b.
local function tunnel(a, b, width, height)
	local cframe = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, height / 2, 0)
	terrain:FillBlock(cframe, Vector3.new(width, height, (b - a).Magnitude + 2), Enum.Material.Air)
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

-- Palms scattered around a ring, skipping the sea and any spot near the given
-- keep-clear points.
local function palmRing(center, radius, count, startDegrees, keepClear)
	for i = 0, count - 1 do
		local out = compass(startDegrees + i * 360 / count + (i % 3) * 7)
		local r = radius + (i % 4) * 6
		local x, z = center.X + out.X * r, center.Z + out.Z * r
		local clear = true
		for _, point in ipairs(keepClear or {}) do
			if Util.flatDistance(Vector3.new(x, 0, z), point) < 22 then
				clear = false
			end
		end
		local y = groundY(x, z, -100)
		if clear and y > SEA_Y + 1 then
			palm(x, z, y)
		end
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

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Parent = parent
	return light
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
	pointLight(flame, Color3.fromRGB(255, 170, 80), 18, 1.5)
end

-- A small glowing gem on a wall or floor, so caves are readable.
local function glow(position, color, range)
	local gem = neon(decor("CaveGlow", Vector3.new(0.8, 0.8, 0.8), CFrame.new(position), color))
	pointLight(gem, color, range or 16, 1.1)
	return gem
end

-- A light pillar from a point up into the sky. Landmarks you can find from anywhere.
local function skyBeam(name, position, color, width)
	local bottom = Instance.new("Attachment")
	bottom.Name = name .. "Bottom"
	bottom.Position = position
	bottom.Parent = terrain
	local top = Instance.new("Attachment")
	top.Name = name .. "Top"
	top.Position = position + Vector3.new(0, 500, 0)
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
	gui.Size = UDim2.fromOffset(210, 38)
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

-- A floating name over an island, readable from across the sea.
local function islandSign(position, text, color)
	-- A persistent model, so the name stays loaded even when the island itself has streamed out.
	local model = Instance.new("Model")
	model.Name = "IslandSignModel"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local holder = decor("IslandSign", Vector3.new(0.4, 0.4, 0.4), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	holder.Parent = model
	model.PrimaryPart = holder
	model.Parent = folders.landmarks
	sign(holder, text, color or Color3.fromRGB(255, 245, 220), Vector3.zero, 1500)
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

-- A wooden dock from the shore out to sea, with boats moored alongside its
-- outer end. sides: one entry per boat, -1 (left) or 1 (right) of the dock.
local function dock(shore, sea, sides, types)
	local a = Vector3.new(shore.X, 2, shore.Z)
	local b = Vector3.new(sea.X, 2, sea.Z)
	local direction = flatDirection(a, b)
	local right = Vector3.new(-direction.Z, 0, direction.X)
	local length = (b - a).Magnitude
	ground("Dock", Vector3.new(8, 1, length), CFrame.lookAt((a + b) / 2, b), WOOD, Enum.Material.WoodPlanks)
	for d = 8, length - 2, 14 do
		for _, side in ipairs({ -3.5, 3.5 }) do
			local p = a + direction * d + right * side
			cylinder(
				"DockPost",
				0.6,
				10,
				Vector3.new(p.X, -2.5, p.Z),
				DARK_WOOD,
				Enum.Material.Wood,
				folders.structures
			)
		end
	end
	-- Boats moor alongside the dock's outer end, bows pointing out to sea.
	-- types: one boat type per entry in sides (default "skiff").
	for i, side in ipairs(sides) do
		local typeName = types and types[i] or "skiff"
		local size = Config.BOAT_TYPES[typeName].size
		local p = a + direction * (length - size.Z / 2 + 3) + right * side * (4 + size.X / 2 + 1.8)
		local at = Vector3.new(p.X, 0.8, p.Z)
		table.insert(refs.boatSpawns, { cf = CFrame.lookAt(at, at + direction), type = typeName })
	end
end

-- A sagging rope bridge between two points (walkable planks, decorative ropes).
local function ropeBridge(name, a, b, sag, width)
	width = width or 6
	local pieces = math.max(8, math.floor((b - a).Magnitude / 4.5))
	local function point(t)
		return a:Lerp(b, t) - Vector3.new(0, sag * math.sin(math.pi * t), 0)
	end
	local side = Vector3.new(-(b - a).Z, 0, (b - a).X).Unit * (width / 2 + 0.2)
	for i = 0, pieces - 1 do
		plank(
			name,
			point(i / pieces),
			point((i + 1) / pieces),
			width,
			0.6,
			Color3.fromRGB(165, 125, 80),
			Enum.Material.WoodPlanks,
			folders.ground,
			0.3
		)
		for _, s in ipairs({ side, -side }) do
			local rope = plank(
				"Rope",
				point(i / pieces) + s + Vector3.new(0, 3, 0),
				point((i + 1) / pieces) + s + Vector3.new(0, 3, 0),
				0.25,
				0.25,
				Color3.fromRGB(200, 170, 110),
				Enum.Material.Fabric,
				folders.decor
			)
			rope.CanCollide = false
			rope.CanQuery = false
		end
	end
	for _, p in ipairs({ a, b }) do
		for _, s in ipairs({ side, -side }) do
			structure(
				"RopePost",
				Vector3.new(0.8, 4, 0.8),
				CFrame.new(p + s + Vector3.new(0, 1.5, 0)),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
	end
end

-- A flat wooden deck on top of something, so high perches read clearly.
local function deck(name, center, size)
	return ground(
		name,
		Vector3.new(size, 1, size),
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		WOOD,
		Enum.Material.WoodPlanks
	)
end

-- Traversal toys (the client drives these) -------------------------------------------
-- A launch pad throws whoever touches it. Launch is a velocity; keep it mostly
-- vertical, because air control eats sideways speed.
function Kit.launchPad(position, launch)
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
function Kit.zipline(name, from, to)
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

-- Landforms and props for the archipelago --------------------------------------------
-- Deterministic randomness: islands look the same every raid, so players can learn them.
function Kit.rng(seed)
	return Random.new(seed)
end

-- A stack of terrain discs from baseY up to topY, narrowing from baseR to topR. wobble
-- (0..1) shifts and resizes each disc so the silhouette is craggy instead of a cone.
function Kit.cone(cx, cz, baseY, topY, baseR, topR, material, wobble, seed, topMaterial)
	local random = Random.new(seed or 1)
	local steps = math.max(2, math.ceil((topY - baseY) / 4))
	local stepHeight = (topY - baseY) / steps
	local lean = Vector3.zero
	for i = 0, steps - 1 do
		local t = (i + 0.5) / steps
		local radius = baseR + (topR - baseR) * t
		lean += Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * (wobble or 0) * 2
		lean = lean * 0.9
		local r = radius * (1 + random:NextNumber(-0.1, 0.1) * (wobble or 0))
		local y0 = baseY + i * stepHeight
		fillColumn(cx + lean.X, cz + lean.Z, y0, y0 + stepHeight + 1, math.max(r, 2), material)
	end
	if topMaterial then
		fillColumn(cx + lean.X, cz + lean.Z, topY - 3, topY, math.max(topR - 1, 2), topMaterial)
	end
	return Vector3.new(cx + lean.X, topY, cz + lean.Z)
end

-- A blobby island: several overlapping discs give a ragged coastline. Returns the lobes.
-- beachR is the whole footprint's radius; topR the grassy part's radius.
function Kit.blob(cx, cz, beachR, topR, topY, lobes, seed, bodyMaterial, topMaterial)
	local random = Random.new(seed or 1)
	local list = {}
	for i = 1, lobes do
		local angle = (i / lobes) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local spread = (i == 1) and 0 or random:NextNumber(0.35, 0.62)
		local lobeR = (i == 1) and 1 or random:NextNumber(0.42, 0.62)
		table.insert(list, {
			x = cx + math.cos(angle) * beachR * spread,
			z = cz + math.sin(angle) * beachR * spread,
			beach = beachR * lobeR,
			top = topR * lobeR,
		})
	end
	for _, lobe in ipairs(list) do
		fillColumn(lobe.x, lobe.z, -30, 1.5, lobe.beach, Enum.Material.Sand)
	end
	for _, lobe in ipairs(list) do
		fillColumn(lobe.x, lobe.z, -30, topY - 2, lobe.top, bodyMaterial)
		fillColumn(lobe.x, lobe.z, topY - 4, topY, math.max(lobe.top - 1, 2), topMaterial)
	end
	return list
end

-- A tree: a trunk and a few leafy balls. Trunks are walkable-ish decoration (they block).
function Kit.tree(x, z, y, height, leafColor)
	height = height or 14
	local trunk = structure(
		"TreeTrunk",
		Vector3.new(2.2, height, 2.2),
		CFrame.new(x, y + height / 2, z),
		Color3.fromRGB(110, 80, 50),
		Enum.Material.Wood
	)
	for i = 0, 2 do
		local a = i * 2.1
		local ball = decor(
			"Leaves",
			Vector3.new(11, 8, 11),
			CFrame.new(x + math.cos(a) * 3, y + height + 1 + (i % 2) * 2, z + math.sin(a) * 3),
			leafColor or Color3.fromRGB(58, 160, 70),
			Enum.Material.Grass
		)
		ball.Shape = Enum.PartType.Ball
	end
	return trunk
end

-- A stone column, optionally snapped off at a ragged height.
function Kit.column(position, height, radius, color, broken)
	local h = broken and height * (0.35 + (position.X * 7 + position.Z * 3) % 10 / 25) or height
	return cylinder(
		"Column",
		radius or 2,
		h,
		position + Vector3.new(0, h / 2, 0),
		color or STONE,
		Enum.Material.Marble,
		folders.structures
	)
end

-- Colorful coral heads and rock spikes for reefs. Cheap parts, no terrain.
function Kit.coral(position, seed, count)
	local random = Random.new(seed or 1)
	local colors = {
		Color3.fromRGB(255, 120, 140),
		Color3.fromRGB(255, 170, 70),
		Color3.fromRGB(190, 110, 255),
		Color3.fromRGB(80, 220, 200),
	}
	for _ = 1, count or 5 do
		local height = random:NextNumber(3, 9)
		local offset = Vector3.new(random:NextNumber(-6, 6), 0, random:NextNumber(-6, 6))
		decor(
			"Coral",
			Vector3.new(random:NextNumber(1.5, 3.5), height, random:NextNumber(1.5, 3.5)),
			CFrame.new(position + offset + Vector3.new(0, height / 2 - 1, 0))
				* CFrame.Angles(random:NextNumber(-0.25, 0.25), random:NextNumber(0, 6), random:NextNumber(-0.25, 0.25)),
			colors[random:NextInteger(1, #colors)],
			Enum.Material.Slate,
			true
		)
	end
end

-- Rotates a model around a local axis from the server (windmill sails, whirlpool rings).
-- The server steps it each frame through refs.spinners.
function Kit.spinner(model, pivot, axis, speed, dangerous, radius)
	local entry = {
		model = model,
		pivot = pivot,
		axis = axis,
		speed = speed,
		baseSpeed = speed,
		angle = 0,
		dangerous = dangerous,
		radius = radius,
	}
	table.insert(refs.spinners, entry)
	return entry
end

-- A named loot spot. The CFrame is where the treasure's center rests.
function Kit.lootSpot(id, cframe)
	refs.lootSpots[id] = cframe
end

-- A wall of stone blocks (for forts and ruins). Returns the part.
function Kit.wall(name, from, to, height, thickness, color, material, parent)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cf =
		CFrame.lookAt(Vector3.new(mid.X, from.Y + height / 2, mid.Z), Vector3.new(to.X, from.Y + height / 2, to.Z))
	return Util.part(
		name,
		Vector3.new(thickness, height, length),
		cf,
		color or STONE,
		material or Enum.Material.Brick,
		parent or folders.structures
	)
end

-- A part inside a model (the model supplies the parent).
function Kit.partOf(model, name, size, cframe, color, material)
	return Util.part(name, size, cframe, color, material, model)
end

-- A crate of powder kegs. Kegs.lua runs its prompt.
function Kit.kegCrate(position)
	local crate = Util.part(
		"KegCrate",
		Vector3.new(4.4, 3, 4.4),
		CFrame.new(position + Vector3.new(0, 1.5, 0)),
		Color3.fromRGB(120, 84, 52),
		Enum.Material.WoodPlanks,
		folders.structures
	)
	for i, x in ipairs({ -1.1, 1.1 }) do
		local keg = Util.part(
			"KegTop",
			Vector3.new(2, 2, 2),
			CFrame.new(position + Vector3.new(x, 3.8, (i - 1.5) * 0.5)),
			Color3.fromRGB(70, 48, 32),
			Enum.Material.Wood,
			folders.decor
		)
		keg.Shape = Enum.PartType.Ball
		keg.CanCollide = false
		keg.CanQuery = false
	end
	crate:SetAttribute("KegCrate", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KegPrompt"
	prompt.ObjectText = "Powder kegs"
	prompt.ActionText = "Take a keg"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	return crate
end

-- An explosive barrel: any blast sets it off, and it blasts in turn. Returns its Model.
function Kit.barrel(position)
	local model = Instance.new("Model")
	model.Name = "PowderBarrel"
	local barrel = cylinder(
		"PowderBarrel",
		1.6,
		4.2,
		position + Vector3.new(0, 2.1, 0),
		Color3.fromRGB(176, 60, 50),
		Enum.Material.Metal,
		model
	)
	for _, y in ipairs({ -1.2, 1.2 }) do
		local band = Util.part(
			"BarrelBand",
			Vector3.new(0.4, 3.4, 3.4),
			CFrame.new(position + Vector3.new(0, 2.1 + y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 30, 34),
			Enum.Material.Metal,
			model
		)
		band.Shape = Enum.PartType.Cylinder
		band.CanCollide = false
		band.CanQuery = false
	end
	model.PrimaryPart = barrel
	model:SetAttribute("Explosive", true)
	model.Parent = folders.structures
	return model
end

-- A lever on a post. Mechanisms.lua runs its prompt and opens `gate` (an entry in refs.gates).
function Kit.lever(position, label, gate)
	local model = Instance.new("Model")
	model.Name = "Lever"
	local post = Util.part(
		"LeverPost",
		Vector3.new(1.4, 4, 1.4),
		CFrame.new(position + Vector3.new(0, 2, 0)),
		DARK_STONE,
		Enum.Material.Slate,
		model
	)
	local handle = Util.part(
		"LeverHandle",
		Vector3.new(0.6, 3.4, 0.6),
		CFrame.new(position + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0, 0, math.rad(35)),
		Color3.fromRGB(255, 200, 40),
		Enum.Material.Metal,
		model
	)
	handle.CanCollide = false
	local knob = Util.part(
		"LeverKnob",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(position + Vector3.new(-1, 5.9, 0)),
		Color3.fromRGB(255, 80, 60),
		Enum.Material.Neon,
		model
	)
	knob.Shape = Enum.PartType.Ball
	knob.CanCollide = false
	model.PrimaryPart = post
	model.Parent = folders.structures
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LeverPrompt"
	prompt.ObjectText = label
	prompt.ActionText = "Pull lever"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle
	return {
		model = model,
		handle = handle,
		knob = knob,
		prompt = prompt,
		label = label,
		gate = gate,
		restCFrame = handle.CFrame,
	}
end

-- A cannon on an emplacement. Players press its prompt (E) to fire where they aim; Cannons.lua
-- does the firing. faceToward is only the resting direction. Returns the cannons entry.
function Kit.cannon(position, faceToward, name)
	local model = Instance.new("Model")
	model.Name = name or "Cannon"
	local look = CFrame.lookAt(position, Vector3.new(faceToward.X, position.Y, faceToward.Z))
	local base = Util.part(
		"CannonBase",
		Vector3.new(5.4, 1.6, 7),
		look * CFrame.new(0, 0.8, 0),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		model
	)
	for _, x in ipairs({ -2.9, 2.9 }) do
		local wheel = Util.part(
			"CannonWheel",
			Vector3.new(0.8, 3.6, 3.6),
			look * CFrame.new(x, 1.8, 0.6),
			Color3.fromRGB(70, 48, 32),
			Enum.Material.Wood,
			model
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
	end
	local pivot = look * CFrame.new(0, 3.2, 0.8)
	local barrel = Util.part(
		"CannonBarrel",
		Vector3.new(2.6, 2.6, 8),
		pivot * CFrame.new(0, 0, -3),
		Color3.fromRGB(58, 58, 66),
		Enum.Material.Metal,
		model
	)
	barrel.CanCollide = false
	Util.part(
		"CannonRing",
		Vector3.new(3.1, 3.1, 1),
		pivot * CFrame.new(0, 0, -6.8),
		Color3.fromRGB(35, 35, 40),
		Enum.Material.Metal,
		model
	).CanCollide =
		false
	model.PrimaryPart = base
	model.Parent = folders.structures
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CannonPrompt"
	prompt.ObjectText = name or "Cannon"
	prompt.ActionText = "Fire cannon"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base
	local entry = {
		model = model,
		base = base,
		barrel = barrel,
		pivot = pivot.Position,
		name = name or "Cannon",
		restLook = look.LookVector,
	}
	table.insert(refs.cannons, entry)
	return entry
end

-- A sagging rope bridge that breaks (all at once) when a blast hits it.
function Kit.breakBridge(name, a, b, sag, width)
	width = width or 6
	local model = Instance.new("Model")
	model.Name = name
	local pieces = math.max(8, math.floor((b - a).Magnitude / 4.5))
	local function point(t)
		return a:Lerp(b, t) - Vector3.new(0, sag * math.sin(math.pi * t), 0)
	end
	local side = Vector3.new(-(b - a).Z, 0, (b - a).X).Unit * (width / 2 + 0.2)
	for i = 0, pieces - 1 do
		plank(
			name .. "Plank",
			point(i / pieces),
			point((i + 1) / pieces),
			width,
			0.6,
			Color3.fromRGB(165, 125, 80),
			Enum.Material.WoodPlanks,
			model,
			0.3
		)
		for _, s in ipairs({ side, -side }) do
			local rope = plank(
				"Rope",
				point(i / pieces) + s + Vector3.new(0, 3, 0),
				point((i + 1) / pieces) + s + Vector3.new(0, 3, 0),
				0.25,
				0.25,
				Color3.fromRGB(200, 170, 110),
				Enum.Material.Fabric,
				model
			)
			rope.CanCollide = false
			rope.CanQuery = false
		end
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	model.Parent = folders.ground
	table.insert(refs.breakables, { model = model, health = 1, kind = "bridge", label = name })
	return model
end

-- A steam vent: shoots whoever stands on it into the air, on a timer anyone can read. The
-- client animates and launches from these attributes, so the server does nothing per frame.
function Kit.geyser(position, period, activeTime, phase, launch)
	local vent = Util.part(
		"GeyserVent",
		Vector3.new(7, 0.8, 7),
		CFrame.new(position + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(120, 105, 95),
		Enum.Material.Slate,
		folders.launchPads
	)
	vent.Shape = Enum.PartType.Cylinder
	vent.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	vent:SetAttribute("GeyserPeriod", period)
	vent:SetAttribute("GeyserActive", activeTime)
	vent:SetAttribute("GeyserPhase", phase)
	vent:SetAttribute("Launch", launch)
	table.insert(refs.geysers, vent)
	return vent
end

-- A lava hazard volume. Invisible; the glow is the terrain below. Mechanisms.lua burns whoever is in it.
function Kit.lavaZone(center, size, damage)
	local zone =
		Util.part("LavaZone", size, CFrame.new(center), Color3.fromRGB(255, 90, 20), Enum.Material.Neon, folders.decor)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	table.insert(refs.lavaZones, { part = zone, damage = damage or 22 })
	return zone
end

-- Export every helper so builders can alias what they use.
Kit.folder = folder
Kit.ground = ground
Kit.structure = structure
Kit.decor = decor
Kit.neon = neon
Kit.upright = upright
Kit.cylinder = cylinder
Kit.plank = plank
Kit.flatDirection = flatDirection
Kit.compass = compass
Kit.ladder = ladder
Kit.fillColumn = fillColumn
Kit.island = island
Kit.mesa = mesa
Kit.rockRamp = rockRamp
Kit.cliffRamp = cliffRamp
Kit.tunnel = tunnel
Kit.groundY = groundY
Kit.palm = palm
Kit.palmRing = palmRing
Kit.rockPile = rockPile
Kit.pointLight = pointLight
Kit.brazier = brazier
Kit.glow = glow
Kit.skyBeam = skyBeam
Kit.sign = sign
Kit.islandSign = islandSign
Kit.totem = totem
Kit.dock = dock
Kit.ropeBridge = ropeBridge
Kit.deck = deck
Kit.terrainOnly = terrainOnly

return Kit

-- Goblin cosmetics (V11, Goblin Life). Builds what a goblin wears on a character: skin, ears, nose, hat, eyewear,
-- face, outfit and back piece. Shared, because the SAME code dresses live goblins on the server (server/GoblinLook.lua)
-- and the shop's previews and thumbnails on the client, so a preview can never disagree with the real thing.
--
-- The contract (docs/ART_DIRECTION.md "The collision contract"): every part made here is welded to a body part and is
-- massless, non-colliding, never hit by rays and never touched. Movement, hitboxes, grapples, the Poltergoblin body
-- copy and the loose-limbed tumble are exactly what they were; a hat simply rides along.
--
-- Sizes: head pieces are written for a 1.2-stud head (centre at 0, face at z = -0.6, crown at y = 0.6) and scaled to
-- the real head per axis, so they fit any avatar's head. Body pieces are written from the real body parts' sizes.
-- A worn Roblox avatar item that would clash with a game item in the same place (a hat under a hat, a shirt under a
-- coat) is hidden while the game item is worn and comes back when it is taken off.
local Catalog = require(script.Parent:WaitForChild("Catalog"))
local Palette = require(script.Parent:WaitForChild("Palette"))

local Wardrobe = {}

local rgb = Color3.fromRGB
local SMOOTH = Enum.Material.SmoothPlastic
-- Cloth is SmoothPlastic: Roblox's Fabric material reads as noisy knitted wool at a goblin's scale (checked in a
-- Studio screenshot), and V10's toy look wants clean colour.
local FABRIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local FOIL = Enum.Material.Foil

local GOLD = rgb(255, 200, 60)
local GOLD_DEEP = rgb(214, 150, 40)
local BLACK = rgb(26, 24, 30)
local WHITE = rgb(246, 244, 238)
local RED = rgb(214, 58, 48)

Wardrobe.FOLDER = "GoblinLook"

-- Skin colours, and the colour inside the ears for each.
Wardrobe.SKINS = {
	skin_classic = { color = Palette.GOBLIN, inner = rgb(214, 132, 120) },
	skin_moss = { color = rgb(78, 150, 64), inner = rgb(200, 120, 110) },
	skin_swamp = { color = rgb(124, 130, 60), inner = rgb(196, 128, 104) },
	skin_sea = { color = rgb(70, 168, 140), inner = rgb(226, 140, 150) },
	skin_cave = { color = rgb(172, 188, 152), inner = rgb(226, 160, 160) },
	skin_hob = { color = rgb(196, 94, 62), inner = rgb(240, 160, 130) },
	skin_violet = { color = rgb(150, 104, 196), inner = rgb(236, 150, 200) },
	skin_gold = { color = rgb(255, 200, 64), inner = rgb(222, 150, 40), material = FOIL },
}

-- Which avatar items each game slot hides (by AccessoryType, and by the attachment for older accessories).
local HIDES = {
	hat = {
		types = { Hat = true, Hair = true },
		attachments = { HatAttachment = true, HairAttachment = true },
	},
	eyes = { types = { Face = true }, attachments = { FaceFrontAttachment = true, FaceCenterAttachment = true } },
	face = { types = { Face = true }, attachments = { FaceFrontAttachment = true, FaceCenterAttachment = true } },
	outfit = {
		types = { TShirt = true, Shirt = true, Jacket = true, Sweater = true, Neck = true, Front = true, Waist = true },
		attachments = {
			NeckAttachment = true,
			BodyFrontAttachment = true,
			WaistFrontAttachment = true,
			WaistCenterAttachment = true,
		},
		clothing = { Shirt = true, ShirtGraphic = true },
	},
	legs = {
		types = { Pants = true, Shorts = true, DressSkirt = true, LeftShoe = true, RightShoe = true },
		attachments = { WaistBackAttachment = true },
		clothing = { Pants = true },
	},
	back = {
		types = { Back = true, Shoulder = true },
		attachments = {
			BodyBackAttachment = true,
			LeftShoulderAttachment = true,
			RightShoulderAttachment = true,
			LeftCollarAttachment = true,
			RightCollarAttachment = true,
		},
	},
}

-- The body ---------------------------------------------------------------------------------------------------------
local function find(character, ...)
	for _, name in ipairs({ ... }) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

function Wardrobe.rig(character)
	local rig = {
		head = find(character, "Head"),
		torso = find(character, "UpperTorso", "Torso"),
		lower = find(character, "LowerTorso"),
		armL = find(character, "LeftUpperArm", "Left Arm"),
		armR = find(character, "RightUpperArm", "Right Arm"),
		foreL = find(character, "LeftLowerArm"),
		foreR = find(character, "RightLowerArm"),
		legL = find(character, "LeftUpperLeg", "Left Leg"),
		legR = find(character, "RightUpperLeg", "Right Leg"),
		shinL = find(character, "LeftLowerLeg"),
		shinR = find(character, "RightLowerLeg"),
		footL = find(character, "LeftFoot"),
		footR = find(character, "RightFoot"),
	}
	rig.r6 = rig.lower == nil
	return rig
end

-- Every part the game colours as skin.
local BODY = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

-- Making parts -----------------------------------------------------------------------------------------------------
local count = 0

local function make(folder, base, name, shape, size, cf, color, material, transparency)
	local p
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == "ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = material or SMOOTH
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = base.CFrame * cf
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	count += 1
	return p
end

-- Rotations used a lot: a cylinder's axis is its X; these turn it upright, or to face forward.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local FACING = CFrame.Angles(0, math.rad(90), 0)
local function deg(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- The builder handed to every item: head pieces in head units, body pieces in studs.
local function context(folder, rig)
	local head = rig.head
	local hs = head.Size
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		-- The classic six-part avatar's head is a 2x1x1 part drawn as a rounded 1.25-stud head.
		hs = Vector3.new(1.2, 1.2, 1.2) * mesh.Scale.X / 1.25
	end
	local sx, sy, sz = hs.X / 1.2, hs.Y / 1.2, hs.Z / 1.2
	local s = (sx + sy + sz) / 3
	local c = { rig = rig, s = s }
	local function hcf(cf)
		local p = cf.Position
		return CFrame.new(p.X * sx, p.Y * sy, p.Z * sz) * cf.Rotation
	end
	-- head(name, shape, size, cf, color, material, transparency): size and position in head units.
	function c.head(name, shape, size, cf, color, material, transparency)
		return make(folder, head, name, shape, size * s, hcf(cf), color, material, transparency)
	end
	-- An upright cylinder on the head (height, diameter).
	function c.hcyl(name, height, diameter, cf, color, material, transparency)
		return c.head(name, "cyl", Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, transparency)
	end
	-- A disc facing forward on the head (thickness, diameter).
	function c.hdisc(name, thickness, diameter, cf, color, material, transparency)
		return c.head(
			name,
			"cyl",
			Vector3.new(thickness, diameter, diameter),
			cf * FACING,
			color,
			material,
			transparency
		)
	end
	-- on(part, ...): in studs, relative to a body part.
	function c.on(part, name, shape, size, cf, color, material, transparency)
		return make(folder, part, name, shape, size, cf, color, material, transparency)
	end
	function c.cyl(part, name, height, diameter, cf, color, material, transparency)
		return make(
			folder,
			part,
			name,
			"cyl",
			Vector3.new(height, diameter, diameter),
			cf * UPRIGHT,
			color,
			material,
			transparency
		)
	end
	function c.disc(part, name, thickness, diameter, cf, color, material, transparency)
		return make(
			folder,
			part,
			name,
			"cyl",
			Vector3.new(thickness, diameter, diameter),
			cf * FACING,
			color,
			material,
			transparency
		)
	end
	-- A shell a little larger than a body part (a sleeve, a coat body, a trouser leg).
	function c.shell(part, name, color, material, pad, transparency)
		if not part then
			return nil
		end
		pad = pad or 0.12
		return make(
			folder,
			part,
			name,
			"block",
			part.Size + Vector3.new(pad, pad * 0.4, pad),
			CFrame.new(),
			color,
			material,
			transparency
		)
	end
	-- A chain of eggs through a list of points (feathers, horns, braids, curls). widths: one per segment.
	function c.chain(name, points, widths, depth, color, material)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local mid = (a + b) / 2
			local length = (b - a).Magnitude
			local cf = CFrame.lookAt(mid, b) * CFrame.Angles(math.rad(90), 0, 0)
			c.head(name, "egg", Vector3.new(widths[i], length * 1.25, depth or widths[i]), cf, color, material)
		end
	end
	-- The lower torso's frame (the six-part avatar has one torso: its lower part is used).
	function c.lowerFrame()
		if rig.lower then
			return rig.lower, CFrame.new(), rig.lower.Size
		end
		return rig.torso,
			CFrame.new(0, -rig.torso.Size.Y * 0.4, 0),
			Vector3.new(rig.torso.Size.X, 0.4, rig.torso.Size.Z)
	end
	return c
end

-- The goblin's own features ------------------------------------------------------------------------------------------
local EARS = {}

local function earPair(c, skin, spec)
	for _, side in ipairs({ -1, 1 }) do
		local suffix = side < 0 and "L" or "R"
		local at = CFrame.new(side * spec.x, spec.y, spec.z) * deg(spec.pitch, side * spec.yaw, side * spec.roll)
		c.head("Ear" .. suffix, "wedge", spec.size, at * deg(0, 180, 0), skin.color, skin.material)
		c.head(
			"EarInner" .. suffix,
			"wedge",
			spec.size * Vector3.new(0.45, 0.6, 0.63),
			at * CFrame.new(side * 0.12 * spec.k, -0.08 * spec.k, 0.1 * spec.k) * deg(0, 180, 0),
			skin.inner,
			skin.material
		)
		if spec.hoops then
			for i, offset in ipairs({ CFrame.new(side * 0.02, -0.34, -0.32), CFrame.new(side * 0.02, -0.26, 0.08) }) do
				c.head("Hoop" .. suffix .. i, "cyl", Vector3.new(0.06, 0.32, 0.32), at * offset, GOLD, METAL)
			end
		end
	end
end

local LONG =
	{ x = 0.95, y = 0.12, z = 0.1, pitch = 0, yaw = -20, roll = -62, size = Vector3.new(0.28, 0.75, 1.5), k = 1 }
EARS.ears_long = function(c, skin)
	earPair(c, skin, LONG)
end
EARS.ears_hoops = function(c, skin)
	local spec = table.clone(LONG)
	spec.hoops = true
	earPair(c, skin, spec)
end
EARS.ears_droopy = function(c, skin)
	earPair(
		c,
		skin,
		{ x = 0.82, y = 0.02, z = 0.18, pitch = 48, yaw = -32, roll = -70, size = Vector3.new(0.26, 0.72, 1.45), k = 1 }
	)
end
EARS.ears_tiny = function(c, skin)
	earPair(
		c,
		skin,
		{ x = 0.66, y = 0.12, z = 0.05, pitch = 0, yaw = -20, roll = -62, size = Vector3.new(0.18, 0.3, 0.45), k = 0.4 }
	)
end
EARS.ears_bat = function(c, skin)
	for _, side in ipairs({ -1, 1 }) do
		local suffix = side < 0 and "L" or "R"
		local at = CFrame.new(side * 0.52, 0.72, 0.08) * deg(0, side * 72, side * -14)
		c.head("Ear" .. suffix, "wedge", Vector3.new(0.2, 1.05, 0.55), at, skin.color, skin.material)
		c.head(
			"EarInner" .. suffix,
			"wedge",
			Vector3.new(0.1, 0.72, 0.36),
			at * CFrame.new(0, -0.08, 0.04) * CFrame.new(side * -0.06, 0, 0),
			skin.inner,
			skin.material
		)
	end
end

local NOSES = {}
NOSES.nose_round = function(c, skin)
	c.head("Nose", "egg", Vector3.new(0.42, 0.42, 0.7), CFrame.new(0, -0.05, -0.72), skin.color, skin.material)
end
NOSES.nose_long = function(c, skin)
	c.head(
		"Nose",
		"egg",
		Vector3.new(0.2, 0.22, 1.1),
		CFrame.new(0, 0.0, -0.98) * deg(-12, 0, 0),
		skin.color,
		skin.material
	)
	c.head("NoseTip", "ball", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0, 0.12, -1.5), skin.color, skin.material)
end
NOSES.nose_potato = function(c, skin)
	c.head("Nose", "egg", Vector3.new(0.58, 0.5, 0.64), CFrame.new(0, -0.08, -0.74), skin.color, skin.material)
	local wart = skin.color:Lerp(rgb(70, 60, 40), 0.35)
	for i, at in ipairs({
		Vector3.new(0.18, 0.06, -0.98),
		Vector3.new(-0.2, -0.12, -0.95),
		Vector3.new(0.05, -0.24, -0.96),
	}) do
		c.head("Wart" .. i, "ball", Vector3.new(0.1, 0.1, 0.1), CFrame.new(at), wart, skin.material)
	end
end

-- Hats -------------------------------------------------------------------------------------------------------------
local ITEMS = {}

ITEMS.hat_bandana = function(c)
	c.head("Bandana", "egg", Vector3.new(1.34, 0.64, 1.38), CFrame.new(0, 0.36, 0.02), RED, FABRIC)
	for i, angle in ipairs({ { 30, 40 }, { 150, 45 }, { 260, 50 }, { 340, 25 }, { 90, 20 } }) do
		local theta, phi = math.rad(angle[1]), math.rad(angle[2])
		local p = Vector3.new(
			0.69 * math.sin(phi) * math.cos(theta),
			0.36 + 0.33 * math.cos(phi),
			0.71 * math.sin(phi) * math.sin(theta)
		)
		c.head("Dot" .. i, "ball", Vector3.new(0.11, 0.11, 0.11), CFrame.new(p), WHITE, FABRIC)
	end
	c.head("Knot", "ball", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.3, 0.68), RED, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		c.head(
			"Tail",
			"block",
			Vector3.new(0.12, 0.38, 0.06),
			CFrame.new(side * 0.09, 0.08, 0.74) * deg(-20, 0, side * 14),
			RED,
			FABRIC
		)
	end
end

ITEMS.hat_sailor = function(c)
	local base = CFrame.new(0.14, 0.64, 0.06) * deg(0, 0, -16)
	c.hcyl("Brim", 0.07, 0.66, base, rgb(236, 238, 242), FABRIC)
	c.hcyl("Crown", 0.24, 0.52, base * CFrame.new(0, 0.14, 0), WHITE, FABRIC)
	c.hcyl("Band", 0.08, 0.54, base * CFrame.new(0, 0.06, 0), rgb(36, 62, 120), FABRIC)
	c.head("Pompom", "ball", Vector3.new(0.16, 0.16, 0.16), base * CFrame.new(0, 0.3, 0), RED, FABRIC)
end

ITEMS.hat_tricorn = function(c)
	local felt = rgb(40, 32, 38)
	c.hcyl("Crown", 0.44, 1.02, CFrame.new(0, 0.74, 0), felt, FABRIC)
	for i, n in ipairs({ Vector3.new(0, 0, 1), Vector3.new(-0.866, 0, -0.5), Vector3.new(0.866, 0, -0.5) }) do
		local center = Vector3.new(0, 0.66, 0) + n * 0.56
		local cf = CFrame.lookAt(center, center + n) * deg(-26, 0, 0)
		c.head("Brim" .. i, "block", Vector3.new(1.36, 0.42, 0.09), cf, felt, FABRIC)
		c.head("Braid" .. i, "block", Vector3.new(1.36, 0.06, 0.12), cf * CFrame.new(0, 0.22, 0), GOLD, METAL)
	end
	c.head("Skull", "ball", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.78, -0.52), WHITE)
	for _, side in ipairs({ -1, 1 }) do
		c.head("SkullEye", "ball", Vector3.new(0.06, 0.06, 0.06), CFrame.new(side * 0.045, 0.8, -0.62), BLACK)
	end
end

ITEMS.hat_bucket = function(c)
	local tin, dark = rgb(160, 166, 176), rgb(112, 118, 128)
	c.hcyl("Bucket", 0.8, 1.32, CFrame.new(0, 0.66, 0.02), tin, METAL)
	c.hcyl("Rim", 0.09, 1.4, CFrame.new(0, 0.28, 0.02), dark, METAL)
	c.hcyl("Bottom", 0.05, 1.22, CFrame.new(0, 1.07, 0.02), dark, METAL)
	local points = {}
	for i = 0, 5 do
		local a = math.rad(15 + i * 30)
		table.insert(points, Vector3.new(math.cos(a) * 0.68, 0.9 + math.sin(a) * 0.42, 0.02))
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		c.head(
			"Handle" .. i,
			"block",
			Vector3.new(0.05, 0.05, (b - a).Magnitude + 0.03),
			CFrame.lookAt((a + b) / 2, b),
			dark,
			METAL
		)
	end
	c.head("Dent", "egg", Vector3.new(0.3, 0.22, 0.08), CFrame.new(0.32, 0.78, -0.65), dark, METAL)
end

ITEMS.hat_chef = function(c)
	c.hcyl("Band", 0.38, 1.12, CFrame.new(0, 0.72, 0), WHITE, FABRIC)
	c.head("Puff", "egg", Vector3.new(1.3, 0.9, 1.3), CFrame.new(0, 1.3, 0), WHITE, FABRIC)
	c.head("PuffL", "egg", Vector3.new(0.72, 0.62, 0.72), CFrame.new(-0.42, 1.25, 0.08), WHITE, FABRIC)
	c.head("PuffR", "egg", Vector3.new(0.72, 0.62, 0.72), CFrame.new(0.42, 1.25, -0.04), WHITE, FABRIC)
	c.head(
		"Ladle",
		"block",
		Vector3.new(0.06, 0.95, 0.06),
		CFrame.new(0.52, 1.0, 0.34) * deg(0, 0, -18),
		rgb(150, 150, 160),
		METAL
	)
	c.head("LadleBowl", "egg", Vector3.new(0.26, 0.14, 0.26), CFrame.new(0.66, 1.46, 0.34), rgb(150, 150, 160), METAL)
end

ITEMS.hat_explorer = function(c)
	local khaki = rgb(208, 188, 134)
	c.head("Dome", "egg", Vector3.new(1.36, 0.98, 1.44), CFrame.new(0, 0.6, 0.02), khaki, FABRIC)
	c.hcyl("Brim", 0.07, 1.95, CFrame.new(0, 0.38, 0.02) * deg(-4, 0, 0), khaki:Lerp(rgb(120, 100, 60), 0.15), FABRIC)
	c.hcyl("Band", 0.14, 1.38, CFrame.new(0, 0.5, 0.02), rgb(70, 112, 62), FABRIC)
	c.head("Knob", "ball", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 1.08, 0.02), khaki)
	c.head(
		"Feather",
		"egg",
		Vector3.new(0.08, 0.78, 0.2),
		CFrame.new(0.62, 0.84, 0.28) * deg(-28, 0, -18),
		rgb(222, 72, 52),
		FABRIC
	)
end

ITEMS.hat_viking = function(c)
	local iron, bronze, ivory = rgb(132, 138, 148), rgb(180, 128, 66), rgb(238, 228, 200)
	c.head("Dome", "egg", Vector3.new(1.38, 0.98, 1.4), CFrame.new(0, 0.56, 0), iron, METAL)
	c.hcyl("Band", 0.16, 1.42, CFrame.new(0, 0.4, 0), bronze, METAL)
	for i, x in ipairs({ -0.4, 0, 0.4 }) do
		c.head(
			"Rivet" .. i,
			"ball",
			Vector3.new(0.08, 0.08, 0.08),
			CFrame.new(x, 0.4, -0.7 + math.abs(x) * 0.18),
			bronze,
			METAL
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		c.chain("Horn", {
			Vector3.new(side * 0.6, 0.66, 0),
			Vector3.new(side * 0.92, 0.92, -0.04),
			Vector3.new(side * 1.04, 1.26, -0.1),
			Vector3.new(side * 0.96, 1.56, -0.16),
		}, { 0.32, 0.24, 0.14 }, nil, ivory)
	end
	c.head(
		"Dent",
		"egg",
		Vector3.new(0.26, 0.2, 0.08),
		CFrame.new(-0.34, 0.86, -0.56) * deg(-30, 0, 0),
		iron:Lerp(BLACK, 0.3),
		METAL
	)
end

ITEMS.hat_feather = function(c)
	local magenta = rgb(176, 48, 128)
	local tilt = deg(-6, 0, 7)
	c.hcyl("Brim", 0.07, 2.75, CFrame.new(0, 0.58, 0) * tilt, magenta, FABRIC)
	c.hcyl("Crown", 0.52, 1.06, CFrame.new(0, 0.84, 0) * tilt, magenta, FABRIC)
	c.hcyl("Band", 0.13, 1.09, CFrame.new(0, 0.68, 0) * tilt, GOLD, METAL)
	c.head("Jewel", "ball", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 0.7, -0.56), rgb(110, 230, 255), GLASS)
	local points = {}
	for i = 0, 4 do
		table.insert(points, Vector3.new(0.42 + 0.08 * i, 0.86 + 0.52 * i - 0.07 * i * i, 0.3 + 0.36 * i))
	end
	c.chain("Plume", points, { 0.3, 0.36, 0.34, 0.24 }, 0.1, rgb(255, 228, 92), FABRIC)
end

ITEMS.hat_captain = function(c)
	c.head("Bicorne", "egg", Vector3.new(3.0, 1.32, 0.56), CFrame.new(0, 0.8, 0.04), BLACK, FABRIC)
	c.head("Braid", "egg", Vector3.new(3.14, 1.44, 0.42), CFrame.new(0, 0.8, 0.06), GOLD, METAL)
	c.hdisc("Cockade", 0.05, 0.44, CFrame.new(0.32, 1.0, -0.27), rgb(36, 62, 120), FABRIC)
	c.hdisc("CockadeRing", 0.05, 0.3, CFrame.new(0.32, 1.0, -0.3), WHITE, FABRIC)
	c.hdisc("CockadeHeart", 0.05, 0.16, CFrame.new(0.32, 1.0, -0.33), RED, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		c.head("Tassel", "ball", Vector3.new(0.18, 0.18, 0.18), CFrame.new(side * 1.52, 0.66, 0.04), GOLD, METAL)
	end
end

ITEMS.hat_crown = function(c)
	c.head("Velvet", "egg", Vector3.new(1.0, 0.62, 1.0), CFrame.new(0, 0.82, 0), rgb(150, 20, 44), FABRIC)
	local band = c.hcyl("Band", 0.34, 1.14, CFrame.new(0, 0.68, 0), GOLD, METAL)
	band.Reflectance = 0.15
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + math.pi / 2
		local x, z = math.cos(a) * 0.52, -math.sin(a) * 0.52
		c.head(
			"Point" .. i,
			"block",
			Vector3.new(0.18, 0.4, 0.1),
			CFrame.lookAt(Vector3.new(x, 0.95, z), Vector3.new(x * 2, 0.95, z * 2)),
			GOLD,
			METAL
		)
		c.head(
			"PointBall" .. i,
			"ball",
			Vector3.new(0.15, 0.15, 0.15),
			CFrame.new(x * 1.02, 1.17, z * 1.02),
			GOLD,
			METAL
		)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 2
		c.head(
			"Ruby" .. i,
			"ball",
			Vector3.new(0.15, 0.15, 0.15),
			CFrame.new(math.cos(a) * 0.58, 0.68, -math.sin(a) * 0.58),
			rgb(220, 30, 64),
			GLASS
		)
	end
	c.head("Orb", "ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1.2, 0), GOLD, METAL)
end

ITEMS.hat_idol = function(c)
	local pale = rgb(255, 226, 110)
	c.hcyl("Band", 0.36, 1.14, CFrame.new(0, 0.68, 0), GOLD_DEEP, METAL)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + math.pi / 2
		c.head(
			"Prong" .. i,
			"block",
			Vector3.new(0.2, 0.46, 0.2),
			CFrame.new(math.cos(a) * 0.5, 1.0, -math.sin(a) * 0.5),
			pale,
			METAL
		)
	end
	c.head(
		"BrowGem",
		"block",
		Vector3.new(0.17, 0.17, 0.17),
		CFrame.new(0, 0.68, -0.6) * deg(0, 0, 45),
		rgb(255, 40, 60),
		NEON
	)
	c.hdisc("Halo", 0.06, 1.95, CFrame.new(0, 0.6, 0.68), pale, NEON, 0.35)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		c.head(
			"Ray" .. i,
			"block",
			Vector3.new(0.1, 0.34, 0.05),
			CFrame.new(0, 0.6, 0.7) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.12, 0),
			pale,
			NEON,
			0.2
		)
	end
end

-- Eyewear (eyes at y = 0.15, the face at z = -0.6) -------------------------------------------------------------------------
ITEMS.eyes_patch = function(c)
	c.head("Patch", "egg", Vector3.new(0.36, 0.32, 0.1), CFrame.new(0.21, 0.15, -0.63), BLACK, FABRIC)
	c.head("Strap", "cyl", Vector3.new(0.05, 1.27, 1.27), CFrame.new(0, 0.15, 0) * deg(0, 0, 70), BLACK, FABRIC)
	for _, z in ipairs({ 45, -45 }) do
		c.head("Stitch", "block", Vector3.new(0.16, 0.03, 0.02), CFrame.new(0.21, 0.15, -0.69) * deg(0, 0, z), WHITE)
	end
end

ITEMS.eyes_spectacles = function(c)
	local rim, lens = rgb(74, 48, 30), rgb(200, 232, 255)
	for _, side in ipairs({ -1, 1 }) do
		c.hdisc("Rim", 0.05, 0.5, CFrame.new(side * 0.25, 0.15, -0.67), rim)
		c.hdisc("Lens", 0.03, 0.42, CFrame.new(side * 0.25, 0.15, -0.69), lens, GLASS, 0.45)
		c.head("Arm", "block", Vector3.new(0.05, 0.05, 0.66), CFrame.new(side * 0.56, 0.17, -0.35), rim)
	end
	c.head("Bridge", "block", Vector3.new(0.12, 0.05, 0.05), CFrame.new(0, 0.2, -0.68), rim)
end

ITEMS.eyes_googly = function(c)
	for _, side in ipairs({ -1, 1 }) do
		c.head("EyeWhite", "ball", Vector3.new(0.36, 0.36, 0.36), CFrame.new(side * 0.22, 0.17, -0.62), WHITE)
	end
	c.head("Pupil", "ball", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.29, 0.11, -0.77), BLACK)
	c.head("Pupil", "ball", Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.27, 0.25, -0.76), BLACK)
end

ITEMS.eyes_goggles = function(c)
	local brass = rgb(204, 152, 62)
	for _, side in ipairs({ -1, 1 }) do
		c.hdisc("Housing", 0.17, 0.42, CFrame.new(side * 0.23, 0.16, -0.68), brass, METAL)
		c.hdisc("Lens", 0.04, 0.31, CFrame.new(side * 0.23, 0.16, -0.77), rgb(92, 176, 116), GLASS, 0.2)
		c.head("Rivet", "ball", Vector3.new(0.07, 0.07, 0.07), CFrame.new(side * 0.44, 0.16, -0.7), brass, METAL)
	end
	c.head("Strap", "cyl", Vector3.new(0.12, 1.3, 1.3), CFrame.new(0, 0.16, 0) * UPRIGHT, rgb(72, 48, 34), FABRIC)
	c.head("Bridge", "block", Vector3.new(0.12, 0.07, 0.08), CFrame.new(0, 0.18, -0.7), brass, METAL)
end

ITEMS.eyes_monocle = function(c)
	c.hdisc("Rim", 0.05, 0.38, CFrame.new(-0.23, 0.17, -0.67), GOLD, METAL)
	c.hdisc("Lens", 0.03, 0.32, CFrame.new(-0.23, 0.17, -0.69), rgb(220, 240, 255), GLASS, 0.5)
	for i = 1, 4 do
		c.head(
			"Chain" .. i,
			"ball",
			Vector3.new(0.055, 0.055, 0.055),
			CFrame.new(-0.36 - i * 0.04, 0.02 - i * 0.12, -0.66 + i * 0.05),
			GOLD,
			METAL
		)
	end
end

ITEMS.eyes_shades = function(c)
	local pink = rgb(255, 70, 170)
	for _, side in ipairs({ -1, 1 }) do
		local at = CFrame.new(side * 0.26, 0.16, -0.68)
		c.head("StarCore", "ball", Vector3.new(0.24, 0.24, 0.24), at, pink, GLASS, 0.05)
		c.head("StarWide", "egg", Vector3.new(0.58, 0.13, 0.06), at * CFrame.new(0, 0, -0.03), pink, GLASS, 0.05)
		c.head("StarTall", "egg", Vector3.new(0.13, 0.58, 0.06), at * CFrame.new(0, 0, -0.03), pink, GLASS, 0.05)
		c.head("Arm", "block", Vector3.new(0.05, 0.05, 0.66), CFrame.new(side * 0.57, 0.17, -0.35), pink)
	end
	c.head("Bridge", "block", Vector3.new(0.12, 0.05, 0.05), CFrame.new(0, 0.2, -0.7), pink)
end

ITEMS.eyes_mask = function(c)
	c.head("Mask", "egg", Vector3.new(1.36, 0.36, 1.34), CFrame.new(0, 0.16, 0), BLACK, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		c.head("EyeWhite", "ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(side * 0.22, 0.17, -0.68), WHITE)
		c.head("Pupil", "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(side * 0.22 + 0.03, 0.16, -0.76), BLACK)
		c.head(
			"Tail",
			"block",
			Vector3.new(0.1, 0.34, 0.05),
			CFrame.new(side * 0.08, 0.02, 0.72) * deg(-15, 0, side * 16),
			BLACK,
			FABRIC
		)
	end
	c.head("Knot", "ball", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.18, 0.68), BLACK, FABRIC)
end

-- Face (under the nose: the mouth at y = -0.38) ---------------------------------------------------------------------------
ITEMS.face_moustache = function(c)
	local hair = rgb(74, 46, 30)
	c.head("Middle", "egg", Vector3.new(0.32, 0.13, 0.15), CFrame.new(0, -0.31, -0.75), hair)
	for _, side in ipairs({ -1, 1 }) do
		c.head(
			"Half",
			"egg",
			Vector3.new(0.36, 0.12, 0.13),
			CFrame.new(side * 0.2, -0.32, -0.72) * deg(0, side * -20, side * -10),
			hair
		)
		c.chain("Curl", {
			Vector3.new(side * 0.36, -0.34, -0.66),
			Vector3.new(side * 0.47, -0.26, -0.62),
			Vector3.new(side * 0.44, -0.15, -0.62),
		}, { 0.1, 0.08 }, 0.08, hair)
	end
end

ITEMS.face_tooth = function(c)
	local mouth = rgb(86, 30, 40)
	c.head("Mouth", "egg", Vector3.new(0.36, 0.13, 0.06), CFrame.new(0, -0.42, -0.6), mouth)
	for _, side in ipairs({ -1, 1 }) do
		c.head(
			"Corner",
			"egg",
			Vector3.new(0.2, 0.09, 0.06),
			CFrame.new(side * 0.21, -0.38, -0.58) * deg(0, side * -25, side * 22),
			mouth
		)
	end
	c.head("Teeth", "block", Vector3.new(0.34, 0.05, 0.03), CFrame.new(0, -0.39, -0.63), WHITE)
	local tooth =
		c.head("GoldTooth", "block", Vector3.new(0.075, 0.075, 0.035), CFrame.new(0.08, -0.405, -0.645), GOLD, FOIL)
	tooth.Reflectance = 0.3
end

ITEMS.face_scar = function(c)
	local scar = rgb(140, 56, 56)
	local line = CFrame.new(-0.27, 0.0, -0.62) * deg(0, 0, 24)
	c.head("Scar", "block", Vector3.new(0.05, 0.46, 0.03), line, scar)
	for i = -1, 1 do
		c.head(
			"Stitch",
			"block",
			Vector3.new(0.17, 0.025, 0.035),
			line * CFrame.new(0, i * 0.13, -0.01),
			rgb(60, 30, 30)
		)
	end
end

ITEMS.face_warpaint = function(c)
	local paint = rgb(214, 40, 40)
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 1 do
			c.head(
				"Stripe",
				"block",
				Vector3.new(0.27, 0.055, 0.03),
				CFrame.new(side * 0.25, -0.02 - i * 0.09, -0.61 + i * 0.01) * deg(0, side * -18, side * -10),
				paint
			)
		end
	end
	c.head("Brow", "block", Vector3.new(0.07, 0.2, 0.03), CFrame.new(0, 0.38, -0.6), paint)
end

ITEMS.face_beard = function(c)
	local ginger = rgb(196, 98, 40)
	c.head("Beard", "egg", Vector3.new(0.82, 0.66, 0.44), CFrame.new(0, -0.62, -0.42), ginger, FABRIC)
	c.head("Moustache", "egg", Vector3.new(0.62, 0.15, 0.17), CFrame.new(0, -0.32, -0.74), ginger, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		c.head("Braid", "ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(side * 0.15, -0.98, -0.46), ginger, FABRIC)
		c.head("Braid", "ball", Vector3.new(0.16, 0.16, 0.16), CFrame.new(side * 0.15, -1.17, -0.45), ginger, FABRIC)
		c.head(
			"BraidRing",
			"cyl",
			Vector3.new(0.07, 0.17, 0.17),
			CFrame.new(side * 0.15, -1.07, -0.46) * UPRIGHT,
			GOLD,
			METAL
		)
	end
end

ITEMS.face_chops = function(c)
	local grey = rgb(206, 206, 210)
	for _, side in ipairs({ -1, 1 }) do
		c.head("Chop", "egg", Vector3.new(0.3, 0.62, 0.42), CFrame.new(side * 0.52, -0.2, -0.26), grey, FABRIC)
		c.head(
			"Eyebrow",
			"egg",
			Vector3.new(0.32, 0.1, 0.13),
			CFrame.new(side * 0.24, 0.35, -0.6) * deg(0, 0, side * -10),
			grey,
			FABRIC
		)
	end
	c.head("Moustache", "egg", Vector3.new(0.64, 0.17, 0.19), CFrame.new(0, -0.31, -0.74), grey, FABRIC)
end

-- Outfits -----------------------------------------------------------------------------------------------------------
-- Each returns true if it dresses the legs too (then the avatar's own trousers are hidden while it is worn).
local function sleeves(c, color, material, withForearms)
	local rig = c.rig
	c.shell(rig.armL, "SleeveL", color, material, 0.12)
	c.shell(rig.armR, "SleeveR", color, material, 0.12)
	if withForearms then
		c.shell(rig.foreL, "CuffL", color, material, 0.12)
		c.shell(rig.foreR, "CuffR", color, material, 0.12)
	end
end

local function trousers(c, color, material, shins)
	local rig = c.rig
	c.shell(rig.legL, "LegL", color, material, 0.1)
	c.shell(rig.legR, "LegR", color, material, 0.1)
	if shins then
		c.shell(rig.shinL, "ShinL", shins.color or color, shins.material or material, 0.12)
		c.shell(rig.shinR, "ShinR", shins.color or color, shins.material or material, 0.12)
	end
end

local function front(rig)
	return -rig.torso.Size.Z / 2
end

ITEMS.outfit_deckhand = function(c)
	local rig = c.rig
	local t = rig.torso
	local navy = rgb(36, 62, 120)
	c.shell(t, "Shirt", WHITE, FABRIC, 0.12)
	for i, y in ipairs({ 0.45, 0.05, -0.35 }) do
		c.on(
			t,
			"Stripe" .. i,
			"block",
			Vector3.new(t.Size.X + 0.16, 0.16, t.Size.Z + 0.16),
			CFrame.new(0, y * t.Size.Y / 1.6, 0),
			navy,
			FABRIC
		)
	end
	sleeves(c, WHITE, FABRIC, false)
	for _, arm in ipairs({ rig.armL, rig.armR }) do
		c.on(
			arm,
			"SleeveStripe",
			"block",
			Vector3.new(arm.Size.X + 0.16, 0.15, arm.Size.Z + 0.16),
			CFrame.new(0, 0.05, 0),
			navy,
			FABRIC
		)
	end
	local lower, offset, size = c.lowerFrame()
	c.on(
		lower,
		"Belt",
		"block",
		Vector3.new(size.X + 0.18, 0.2, size.Z + 0.18),
		offset * CFrame.new(0, size.Y / 2 - 0.05, 0),
		rgb(196, 160, 104),
		FABRIC
	)
	c.on(
		t,
		"Kerchief",
		"egg",
		Vector3.new(0.78, 0.46, 0.14),
		CFrame.new(0, t.Size.Y / 2 - 0.26, front(rig) - 0.08),
		RED,
		FABRIC
	)
	c.on(
		t,
		"Knot",
		"ball",
		Vector3.new(0.24, 0.24, 0.24),
		CFrame.new(0, t.Size.Y / 2 - 0.08, front(rig) - 0.1),
		RED,
		FABRIC
	)
	trousers(c, navy, FABRIC, {})
	return true
end

ITEMS.outfit_barrel = function(c)
	local rig = c.rig
	local t = rig.torso
	local height = t.Size.Y + (rig.lower and rig.lower.Size.Y or 0) + 0.3
	local center = CFrame.new(0, -(rig.lower and rig.lower.Size.Y or 0) / 2 - 0.05, 0)
	local width = t.Size.X * 1.1
	c.cyl(t, "Barrel", height, width, center, rgb(166, 112, 62), Enum.Material.WoodPlanks)
	for i, y in ipairs({ height / 2 - 0.25, -height / 2 + 0.25 }) do
		c.cyl(t, "Hoop" .. i, 0.16, width + 0.08, center * CFrame.new(0, y, 0), rgb(70, 72, 80), METAL)
	end
	c.on(
		t,
		"Stencil",
		"block",
		Vector3.new(0.6, 0.32, 0.05),
		center * CFrame.new(0, 0.1, -width / 2 - 0.01),
		rgb(60, 36, 22),
		WOOD
	)
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			t,
			"Brace",
			"block",
			Vector3.new(0.16, 0.7, t.Size.Z + 0.22),
			CFrame.new(side * t.Size.X * 0.3, t.Size.Y / 2 - 0.05, 0),
			rgb(92, 58, 36),
			FABRIC
		)
	end
	return true -- bare legs out of the bottom of a barrel are the joke
end

ITEMS.outfit_explorer = function(c)
	local rig = c.rig
	local t = rig.torso
	local khaki = rgb(196, 172, 112)
	c.shell(t, "Vest", khaki, FABRIC, 0.14)
	c.on(
		t,
		"ShirtFront",
		"block",
		Vector3.new(0.4, t.Size.Y - 0.05, 0.05),
		CFrame.new(0, 0, front(rig) - 0.08),
		WHITE,
		FABRIC
	)
	for i, at in ipairs({ { -0.5, 0.3 }, { 0.5, 0.3 }, { -0.55, -0.35 }, { 0.55, -0.35 } }) do
		c.on(
			t,
			"Pocket" .. i,
			"block",
			Vector3.new(0.46, 0.38, 0.08),
			CFrame.new(at[1], at[2] * t.Size.Y / 1.6, front(rig) - 0.1),
			khaki:Lerp(rgb(110, 90, 50), 0.25),
			FABRIC
		)
	end
	c.on(
		t,
		"Strap",
		"block",
		Vector3.new(0.16, t.Size.Y * 1.35, 0.06),
		CFrame.new(0, 0, front(rig) - 0.14) * deg(0, 0, 38),
		rgb(110, 70, 40)
	)
	local lower, offset, size = c.lowerFrame()
	c.on(
		lower,
		"Satchel",
		"block",
		Vector3.new(0.7, 0.55, 0.3),
		offset * CFrame.new(size.X / 2 + 0.05, -0.1, 0.1),
		rgb(120, 78, 44),
		FABRIC
	)
	c.disc(t, "Compass", 0.06, 0.32, CFrame.new(-0.2, -0.1, front(rig) - 0.18), GOLD, METAL)
	sleeves(c, WHITE, FABRIC, false)
	trousers(c, khaki:Lerp(rgb(120, 100, 60), 0.2), FABRIC)
	return true
end

ITEMS.outfit_armor = function(c)
	local rig = c.rig
	local t = rig.torso
	local steel, dark = rgb(176, 182, 192), rgb(70, 72, 82)
	c.shell(t, "Tunic", rgb(176, 146, 100), FABRIC, 0.1)
	c.disc(t, "ChestLid", 0.12, t.Size.X * 0.72, CFrame.new(0, 0.05, front(rig) - 0.1), steel, METAL)
	c.on(t, "ChestKnob", "ball", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.05, front(rig) - 0.22), dark, METAL)
	c.disc(t, "BackLid", 0.12, t.Size.X * 0.72, CFrame.new(0, 0.05, -front(rig) + 0.1), steel, METAL)
	for _, side in ipairs({ -1, 1 }) do
		local shoulder = CFrame.new(side * (t.Size.X / 2 + 0.05), t.Size.Y / 2, 0) * deg(0, 0, side * -30)
		c.cyl(t, "ShoulderLid", 0.1, 0.95, shoulder, steel, METAL)
		c.on(t, "ShoulderKnob", "ball", Vector3.new(0.16, 0.16, 0.16), shoulder * CFrame.new(0, 0.1, 0), dark, METAL)
	end
	c.on(
		t,
		"Fork",
		"block",
		Vector3.new(0.08, 1.4, 0.05),
		CFrame.new(0, 0.1, -front(rig) + 0.24) * deg(0, 0, 35),
		steel,
		METAL
	)
	c.on(
		t,
		"Spoon",
		"block",
		Vector3.new(0.08, 1.4, 0.05),
		CFrame.new(0, 0.1, -front(rig) + 0.26) * deg(0, 0, -35),
		steel,
		METAL
	)
	c.cyl(t, "String", 0.06, t.Size.X * 1.18, CFrame.new(0, -t.Size.Y * 0.32, 0), rgb(220, 200, 150), FABRIC)
	return false
end

ITEMS.outfit_formal = function(c)
	local rig = c.rig
	local t = rig.torso
	local velvet = rgb(96, 40, 128)
	c.shell(t, "Waistcoat", velvet, FABRIC, 0.14)
	c.on(
		t,
		"ShirtFront",
		"block",
		Vector3.new(0.5, t.Size.Y * 0.8, 0.05),
		CFrame.new(0, t.Size.Y * 0.1, front(rig) - 0.08),
		WHITE,
		FABRIC
	)
	for i = 0, 2 do
		c.on(
			t,
			"Button" .. i,
			"ball",
			Vector3.new(0.12, 0.12, 0.12),
			CFrame.new(0.32, 0.25 - i * 0.32, front(rig) - 0.1),
			GOLD,
			METAL
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			t,
			"Bow",
			"egg",
			Vector3.new(0.5, 0.36, 0.14),
			CFrame.new(side * 0.27, t.Size.Y / 2 - 0.16, front(rig) - 0.14) * deg(0, 0, side * 12),
			BLACK,
			FABRIC
		)
	end
	c.on(
		t,
		"BowKnot",
		"ball",
		Vector3.new(0.18, 0.18, 0.18),
		CFrame.new(0, t.Size.Y / 2 - 0.16, front(rig) - 0.17),
		BLACK,
		FABRIC
	)
	c.on(
		t,
		"WatchChain",
		"block",
		Vector3.new(0.5, 0.04, 0.04),
		CFrame.new(-0.3, -0.3, front(rig) - 0.1) * deg(0, 0, -15),
		GOLD,
		METAL
	)
	sleeves(c, WHITE, FABRIC, true)
	trousers(c, rgb(34, 32, 40), FABRIC, {})
	return true
end

ITEMS.outfit_captain = function(c)
	local rig = c.rig
	local t = rig.torso
	local coat = rgb(176, 36, 40)
	c.shell(t, "Coat", coat, FABRIC, 0.16)
	local lower, offset, size = c.lowerFrame()
	c.on(lower, "CoatWaist", "block", size + Vector3.new(0.18, 0.06, 0.18), offset, coat, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			lower,
			"Tail",
			"block",
			Vector3.new(size.X * 0.44, 1.8, 0.12),
			offset * CFrame.new(side * size.X * 0.24, -1.0, size.Z / 2 + 0.08) * deg(8, 0, side * -4),
			coat,
			FABRIC
		)
		for i = 0, 1 do
			c.on(
				t,
				"Button",
				"ball",
				Vector3.new(0.15, 0.15, 0.15),
				CFrame.new(side * 0.32, 0.3 - i * 0.45, front(rig) - 0.11),
				GOLD,
				METAL
			)
		end
		local shoulder = CFrame.new(side * (t.Size.X / 2 - 0.08), t.Size.Y / 2 + 0.06, 0) * deg(0, 0, side * -10)
		c.cyl(t, "Epaulette", 0.12, 0.62, shoulder, GOLD, METAL)
		c.on(
			t,
			"Fringe",
			"egg",
			Vector3.new(0.66, 0.22, 0.66),
			shoulder * CFrame.new(side * 0.06, -0.1, 0),
			rgb(255, 222, 110),
			FABRIC
		)
	end
	sleeves(c, coat, FABRIC, true)
	for _, fore in ipairs({ rig.foreL, rig.foreR }) do
		if fore then
			c.on(
				fore,
				"Cuff",
				"block",
				Vector3.new(fore.Size.X + 0.22, 0.2, fore.Size.Z + 0.22),
				CFrame.new(0, -fore.Size.Y / 2 + 0.22, 0),
				GOLD,
				FABRIC
			)
		end
	end
	c.on(
		t,
		"Cravat",
		"egg",
		Vector3.new(0.52, 0.42, 0.3),
		CFrame.new(0, t.Size.Y / 2 - 0.25, front(rig) - 0.12),
		WHITE,
		FABRIC
	)
	trousers(c, rgb(236, 230, 214), FABRIC, { color = BLACK, material = SMOOTH })
	return true
end

ITEMS.outfit_royal = function(c)
	local rig = c.rig
	local t = rig.torso
	local purple = rgb(110, 44, 150)
	c.shell(t, "Robe", purple, FABRIC, 0.16)
	local lower, offset, size = c.lowerFrame()
	local legLength = (rig.legL and rig.legL.Size.Y or 1) + (rig.shinL and rig.shinL.Size.Y or 0)
	c.on(
		lower,
		"RobeSkirt",
		"block",
		Vector3.new(size.X + 0.4, legLength + size.Y, size.Z + 0.5),
		offset * CFrame.new(0, -legLength / 2 + 0.05, 0),
		purple,
		FABRIC
	)
	c.on(
		t,
		"Ermine",
		"egg",
		Vector3.new(t.Size.X + 0.6, 0.55, t.Size.Z + 0.6),
		CFrame.new(0, t.Size.Y / 2, 0),
		WHITE,
		FABRIC
	)
	for i, at in ipairs({ { -0.7, -0.4 }, { 0.6, -0.42 }, { -0.2, 0.55 }, { 0.3, 0.6 } }) do
		c.on(
			t,
			"Spot" .. i,
			"ball",
			Vector3.new(0.1, 0.1, 0.1),
			CFrame.new(at[1], t.Size.Y / 2 + 0.2, at[2]),
			BLACK,
			FABRIC
		)
	end
	for i = 0, 4 do
		local a = math.rad(-60 + i * 30)
		c.on(
			t,
			"Chain" .. i,
			"ball",
			Vector3.new(0.16, 0.16, 0.16),
			CFrame.new(math.sin(a) * 0.62, t.Size.Y / 2 - 0.25 - math.cos(a) * 0.45, front(rig) - 0.12),
			GOLD,
			METAL
		)
	end
	c.disc(t, "Medallion", 0.08, 0.36, CFrame.new(0, -0.1, front(rig) - 0.15), GOLD, METAL)
	sleeves(c, purple, FABRIC, true)
	return true
end

ITEMS.outfit_ghost = function(c)
	local rig = c.rig
	local t = rig.torso
	local ghost = Palette.GHOST
	local coat = c.shell(t, "GhostCoat", ghost:Lerp(rgb(40, 80, 90), 0.45), SMOOTH, 0.16, 0.3)
	local lower, offset, size = c.lowerFrame()
	c.on(
		lower,
		"GhostWaist",
		"block",
		size + Vector3.new(0.18, 0.06, 0.18),
		offset,
		ghost:Lerp(rgb(40, 80, 90), 0.45),
		SMOOTH,
		0.3
	)
	for i, x in ipairs({ -0.55, 0, 0.55 }) do
		c.on(
			lower,
			"Tatter" .. i,
			"wedge",
			Vector3.new(0.12, 1.3 - math.abs(x) * 0.6, 0.5),
			offset * CFrame.new(x * size.X / 2, -0.75, size.Z / 2 + 0.06) * deg(0, 90, 180),
			ghost:Lerp(rgb(40, 80, 90), 0.3),
			SMOOTH,
			0.35
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			t,
			"Glow",
			"block",
			Vector3.new(0.08, t.Size.Y, 0.05),
			CFrame.new(side * 0.42, 0, front(rig) - 0.1),
			ghost,
			NEON,
			0.2
		)
	end
	for i = 0, 2 do
		c.on(
			t,
			"Button" .. i,
			"ball",
			Vector3.new(0.13, 0.13, 0.13),
			CFrame.new(0, 0.4 - i * 0.4, front(rig) - 0.11),
			ghost,
			NEON
		)
	end
	sleeves(c, ghost:Lerp(rgb(40, 80, 90), 0.45), SMOOTH, true)
	trousers(c, rgb(40, 52, 60), FABRIC)
	-- A few wisps rising off the coat (one small emitter, bounded).
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "Wisps"
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Color = ColorSequence.new(ghost)
	wisps.LightEmission = 0.6
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.2) })
	wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	wisps.Lifetime = NumberRange.new(1, 1.6)
	wisps.Speed = NumberRange.new(1, 2)
	wisps.Rate = 4
	wisps.Parent = coat
	return true
end

ITEMS.outfit_admiral = function(c)
	local rig = c.rig
	local t = rig.torso
	local navy = rgb(28, 44, 96)
	c.shell(t, "Coat", navy, FABRIC, 0.16)
	local lower, offset, size = c.lowerFrame()
	c.on(lower, "CoatWaist", "block", size + Vector3.new(0.18, 0.06, 0.18), offset, navy, FABRIC)
	c.on(
		t,
		"Sash",
		"block",
		Vector3.new(0.3, t.Size.Y * 1.4, t.Size.Z + 0.26),
		CFrame.new(0, 0, 0) * deg(0, 0, -38),
		GOLD,
		FABRIC
	)
	for i, color in ipairs({ rgb(220, 40, 60), rgb(60, 160, 240), WHITE }) do
		c.on(
			t,
			"Ribbon" .. i,
			"block",
			Vector3.new(0.16, 0.24, 0.05),
			CFrame.new(-0.62 + i * 0.2, 0.42, front(rig) - 0.1),
			color,
			FABRIC
		)
		c.disc(t, "Medal" .. i, 0.05, 0.18, CFrame.new(-0.62 + i * 0.2, 0.22, front(rig) - 0.12), GOLD, METAL)
	end
	for _, side in ipairs({ -1, 1 }) do
		local shoulder = CFrame.new(side * (t.Size.X / 2 - 0.08), t.Size.Y / 2 + 0.06, 0) * deg(0, 0, side * -10)
		c.cyl(t, "Epaulette", 0.12, 0.66, shoulder, GOLD, METAL)
		c.on(
			t,
			"Fringe",
			"egg",
			Vector3.new(0.7, 0.24, 0.7),
			shoulder * CFrame.new(side * 0.06, -0.1, 0),
			rgb(255, 222, 110),
			FABRIC
		)
	end
	sleeves(c, navy, FABRIC, true)
	trousers(c, WHITE, FABRIC, { color = BLACK, material = SMOOTH })
	return true
end

-- Back and shoulder ----------------------------------------------------------------------------------------------------
local function back(rig)
	return rig.torso.Size.Z / 2
end

ITEMS.back_sack = function(c)
	local rig = c.rig
	local t = rig.torso
	local burlap = rgb(178, 142, 92)
	c.on(
		t,
		"Sack",
		"egg",
		Vector3.new(1.05, 1.3, 0.85),
		CFrame.new(0.25, 0.1, back(rig) + 0.42) * deg(0, 0, 16),
		burlap,
		FABRIC
	)
	c.on(
		t,
		"Patch",
		"block",
		Vector3.new(0.32, 0.32, 0.05),
		CFrame.new(0.15, -0.05, back(rig) + 0.85) * deg(0, 0, 10),
		rgb(120, 92, 60),
		FABRIC
	)
	c.on(
		t,
		"Tie",
		"ball",
		Vector3.new(0.26, 0.26, 0.26),
		CFrame.new(0.45, 0.78, back(rig) + 0.38),
		burlap:Lerp(BLACK, 0.2),
		FABRIC
	)
	c.on(
		t,
		"Strap",
		"block",
		Vector3.new(0.16, t.Size.Y * 1.35, 0.06),
		CFrame.new(0, 0, front(rig) - 0.06) * deg(0, 0, -38),
		rgb(130, 96, 60),
		FABRIC
	)
	c.on(
		t,
		"StrapBack",
		"block",
		Vector3.new(0.16, t.Size.Y * 1.1, 0.06),
		CFrame.new(-0.1, 0, back(rig) + 0.05) * deg(0, 0, 38),
		rgb(130, 96, 60),
		FABRIC
	)
	return false
end

ITEMS.back_cape = function(c)
	local rig = c.rig
	local t = rig.torso
	local cape = rgb(190, 40, 44)
	local top = CFrame.new(0, t.Size.Y / 2 - 0.08, back(rig) + 0.1) * deg(-10, 0, 0)
	c.on(t, "Cape", "block", Vector3.new(t.Size.X * 1.05, 2.3, 0.08), top * CFrame.new(0, -1.15, 0), cape, FABRIC)
	for i, x in ipairs({ -0.66, 0, 0.66 }) do
		c.on(
			t,
			"Tatter" .. i,
			"wedge",
			Vector3.new(0.08, 0.36, t.Size.X * 0.33),
			top * CFrame.new(x * t.Size.X / 2, -2.48, 0) * deg(0, 90, 180),
			cape,
			FABRIC
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			t,
			"Clasp",
			"ball",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(side * 0.55, t.Size.Y / 2 - 0.15, front(rig) - 0.08),
			GOLD,
			METAL
		)
	end
	c.on(
		t,
		"Cord",
		"block",
		Vector3.new(1.1, 0.06, 0.06),
		CFrame.new(0, t.Size.Y / 2 - 0.15, front(rig) - 0.1),
		GOLD,
		METAL
	)
	return false
end

ITEMS.back_anchor = function(c)
	local rig = c.rig
	local t = rig.torso
	local iron = rgb(62, 64, 74)
	local at = CFrame.new(0, -0.05, back(rig) + 0.25)
	c.cyl(t, "Shank", 1.6, 0.2, at, iron, METAL)
	c.on(t, "Stock", "block", Vector3.new(0.95, 0.14, 0.14), at * CFrame.new(0, 0.6, 0), iron, METAL)
	c.on(t, "Ring", "cyl", Vector3.new(0.08, 0.36, 0.36), at * CFrame.new(0, 0.88, 0), iron, METAL)
	for _, side in ipairs({ -1, 1 }) do
		c.on(
			t,
			"Arm",
			"block",
			Vector3.new(0.13, 0.66, 0.13),
			at * CFrame.new(side * 0.24, -0.72, 0) * deg(0, 0, side * 52),
			iron,
			METAL
		)
		c.on(
			t,
			"Fluke",
			"wedge",
			Vector3.new(0.1, 0.26, 0.3),
			at * CFrame.new(side * 0.5, -0.56, 0) * deg(0, side * 90, 0),
			iron,
			METAL
		)
		c.on(
			t,
			"Strap",
			"block",
			Vector3.new(0.16, t.Size.Y * 0.9, 0.06),
			CFrame.new(side * 0.45, 0.1, front(rig) - 0.05),
			rgb(110, 70, 40),
			FABRIC
		)
	end
	return false
end

ITEMS.back_parrot = function(c)
	local rig = c.rig
	local t = rig.torso
	local red, yellow, blue = rgb(224, 44, 40), rgb(255, 210, 60), rgb(40, 100, 224)
	-- Perched out on the right shoulder and big enough to read beside the head from a few studs away.
	local k = 1.45
	local perch = CFrame.new(t.Size.X / 2 + 0.1, t.Size.Y / 2 + 0.62, 0.15) * deg(-12, 20, 0)
	local function at(x, y, z)
		return perch * CFrame.new(x * k, y * k, z * k)
	end
	c.on(t, "ParrotBody", "egg", Vector3.new(0.42, 0.62, 0.48) * k, perch, red, FABRIC)
	c.on(t, "ParrotBelly", "egg", Vector3.new(0.3, 0.42, 0.2) * k, at(0, -0.02, -0.18), yellow, FABRIC)
	c.on(t, "ParrotHead", "ball", Vector3.new(0.38, 0.38, 0.38) * k, at(0, 0.42, -0.06), red, FABRIC)
	c.on(
		t,
		"ParrotBeak",
		"egg",
		Vector3.new(0.14, 0.22, 0.2) * k,
		at(0, 0.36, -0.28) * deg(-30, 0, 0),
		rgb(236, 226, 196)
	)
	for _, side in ipairs({ -1, 1 }) do
		c.on(t, "ParrotEye", "ball", Vector3.new(0.08, 0.08, 0.08) * k, at(side * 0.17, 0.47, -0.12), BLACK)
		c.on(
			t,
			"ParrotWing",
			"egg",
			Vector3.new(0.1, 0.48, 0.34) * k,
			at(side * 0.22, 0.02, 0.04) * deg(10, 0, side * 8),
			blue,
			FABRIC
		)
	end
	c.on(t, "ParrotTail", "egg", Vector3.new(0.14, 0.62, 0.16) * k, at(0, -0.45, 0.24) * deg(30, 0, 0), blue, FABRIC)
	return false
end

ITEMS.back_wings = function(c)
	local rig = c.rig
	local t = rig.torso
	local skin, bone = rgb(84, 46, 104), rgb(44, 30, 54)
	local root = CFrame.new(0, 0.35, back(rig) + 0.12)
	c.on(t, "WingRoot", "ball", Vector3.new(0.3, 0.3, 0.3), root, bone)
	for _, side in ipairs({ -1, 1 }) do
		local spar = root * deg(0, side * -25, side * 32) * CFrame.new(side * 0.75, 0, 0)
		c.on(t, "Spar", "block", Vector3.new(1.5, 0.08, 0.08), spar, bone)
		for i = 0, 1 do
			c.on(
				t,
				"Membrane",
				"wedge",
				Vector3.new(0.04, 0.7, 0.72),
				spar * CFrame.new(side * (-0.35 + i * 0.7), -0.36, 0) * deg(0, 90, 180) * deg(0, 0, 0),
				skin,
				FABRIC
			)
		end
		c.on(t, "Claw", "ball", Vector3.new(0.12, 0.12, 0.12), spar * CFrame.new(side * 0.76, 0, 0), bone)
	end
	return false
end

ITEMS.back_hoard = function(c)
	local rig = c.rig
	local t = rig.torso
	local burlap = rgb(178, 142, 92)
	local at = CFrame.new(0, 0.12, back(rig) + 0.52)
	c.on(t, "HoardSack", "egg", Vector3.new(1.2, 1.4, 1.0), at, burlap, FABRIC)
	c.on(t, "Opening", "egg", Vector3.new(0.8, 0.22, 0.66), at * CFrame.new(0, 0.62, 0), rgb(60, 40, 24), FABRIC)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local coin = c.on(
			t,
			"Coin" .. i,
			"cyl",
			Vector3.new(0.06, 0.28, 0.28),
			at
				* CFrame.new(math.cos(a) * 0.26, 0.74 + (i % 2) * 0.08, math.sin(a) * 0.22)
				* deg(i * 37, i * 61, 90 + i * 23),
			GOLD,
			METAL
		)
		coin.Reflectance = 0.2
	end
	c.cyl(t, "Goblet", 0.44, 0.2, at * CFrame.new(-0.22, 0.84, 0.05) * deg(0, 0, 12), GOLD, METAL)
	c.on(t, "GobletCup", "egg", Vector3.new(0.34, 0.24, 0.34), at * CFrame.new(-0.27, 1.08, 0.05), GOLD, METAL)
	c.on(
		t,
		"Strap",
		"block",
		Vector3.new(0.16, t.Size.Y * 1.35, 0.06),
		CFrame.new(0, 0, front(rig) - 0.06) * deg(0, 0, -38),
		rgb(130, 96, 60),
		FABRIC
	)
	return false
end

Wardrobe.ITEMS = ITEMS
Wardrobe.EARS = EARS
Wardrobe.NOSES = NOSES

-- Hiding avatar items ------------------------------------------------------------------------------------------------
local function attachmentOf(accessory)
	local handle = accessory:FindFirstChild("Handle")
	local attachment = handle and handle:FindFirstChildOfClass("Attachment")
	return attachment and attachment.Name or ""
end

local function setHidden(instance, hidden)
	for _, p in ipairs(instance:IsA("BasePart") and { instance } or instance:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then
			local stored = p:GetAttribute("GLHideT")
			if hidden and stored == nil then
				p:SetAttribute("GLHideT", p.Transparency)
				p.Transparency = 1
			elseif not hidden and stored ~= nil then
				p.Transparency = stored
				p:SetAttribute("GLHideT", nil)
			end
		end
	end
end

local function hideConflicts(character, look, coversLegs)
	local rules = {}
	for slot in pairs(HIDES) do
		if slot == "legs" then
			if coversLegs then
				table.insert(rules, HIDES.legs)
			end
		elseif look[slot] then
			table.insert(rules, HIDES[slot])
		end
	end
	local stash = character:FindFirstChild("GoblinStash")
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") then
			local kind = child:IsA("Accessory") and child.AccessoryType.Name or "Unknown"
			local attachment = attachmentOf(child)
			local hide = false
			for _, rule in ipairs(rules) do
				if rule.types[kind] or (kind == "Unknown" and rule.attachments[attachment]) then
					hide = true
				end
			end
			setHidden(child, hide)
		elseif child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			for _, rule in ipairs(rules) do
				if rule.clothing and rule.clothing[child.ClassName] then
					if not stash then
						stash = Instance.new("Folder")
						stash.Name = "GoblinStash"
						stash.Parent = character
					end
					child.Parent = stash
					break
				end
			end
		end
	end
	-- Clothing put away earlier comes back once nothing covers it.
	if stash then
		for _, child in ipairs(stash:GetChildren()) do
			local covered = false
			for _, rule in ipairs(rules) do
				if rule.clothing and rule.clothing[child.ClassName] then
					covered = true
				end
			end
			if not covered then
				child.Parent = character
			end
		end
	end
end

-- Skin -----------------------------------------------------------------------------------------------------------------
local function paintSkin(character, skin)
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.HeadColor3 = skin.color
	colors.LeftArmColor3 = skin.color
	colors.RightArmColor3 = skin.color
	colors.LeftLegColor3 = skin.color
	colors.RightLegColor3 = skin.color
	colors.TorsoColor3 = skin.color
	for _, name in ipairs(BODY) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = skin.color
			local original = p:GetAttribute("GLMaterial")
			if skin.material then
				if original == nil then
					p:SetAttribute("GLMaterial", p.Material.Name)
				end
				p.Material = skin.material
			elseif original ~= nil then
				p.Material = Enum.Material[original]
				p:SetAttribute("GLMaterial", nil)
			end
		end
	end
end

-- Dressing -------------------------------------------------------------------------------------------------------------
local GOBLIN_SLOTS = { "skin", "ears", "nose", "hat", "eyes", "face", "outfit", "back" }

local function signature(look)
	local parts = {}
	for _, slot in ipairs(GOBLIN_SLOTS) do
		table.insert(parts, look[slot] or "-")
	end
	return table.concat(parts, ",")
end

-- Dresses a character in a look (Catalog look table). Safe to call any number of times: it rebuilds the pieces only
-- when the look changed or the avatar's head or torso was replaced, and always re-applies skin colour and hiding
-- (avatar loading can reset both just after spawning). Returns the number of parts it made (0 when nothing changed).
function Wardrobe.dress(character, look)
	local rig = Wardrobe.rig(character)
	if not rig.head or not rig.torso then
		return 0
	end
	look = Catalog.withDefaults(table.clone(look or {}))
	local skin = Wardrobe.SKINS[look.skin] or Wardrobe.SKINS.skin_classic
	paintSkin(character, skin)
	local folder = character:FindFirstChild(Wardrobe.FOLDER)
	local sig = signature(look)
	local current = folder
		and folder:GetAttribute("Look") == sig
		and folder:FindFirstChild("OnHead")
		and folder.OnHead.Value == rig.head
		and folder:FindFirstChild("OnTorso")
		and folder.OnTorso.Value == rig.torso
	if current then
		hideConflicts(character, look, folder:GetAttribute("Legs") == true)
		return 0
	end
	-- V10 put the ears and nose straight in the character: clear those.
	for _, name in ipairs({ "GoblinEarL", "GoblinEarR", "GoblinEarInnerL", "GoblinEarInnerR", "GoblinNose" }) do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = Wardrobe.FOLDER
	folder:SetAttribute("Look", sig)
	local onHead = Instance.new("ObjectValue")
	onHead.Name = "OnHead"
	onHead.Value = rig.head
	onHead.Parent = folder
	local onTorso = Instance.new("ObjectValue")
	onTorso.Name = "OnTorso"
	onTorso.Value = rig.torso
	onTorso.Parent = folder
	count = 0
	local c = context(folder, rig)
	local ears = EARS[look.ears] or EARS.ears_long
	ears(c, skin)
	local nose = NOSES[look.nose] or NOSES.nose_round
	nose(c, skin)
	local legs = false
	for _, slot in ipairs({ "hat", "eyes", "face", "outfit", "back" }) do
		local id = look[slot]
		local build = id and ITEMS[id]
		if build then
			local ok, coversLegs = pcall(build, c)
			if not ok then
				warn("[Wardrobe] " .. id .. ": " .. tostring(coversLegs))
			elseif slot == "outfit" and coversLegs then
				legs = true
			end
		end
	end
	folder:SetAttribute("Legs", legs)
	folder.Parent = character
	hideConflicts(character, look, legs)
	return count
end

-- Builds one head item on any part standing in for a head (a celebration's floating crown, a shop thumbnail).
function Wardrobe.buildOn(part, itemId)
	local build = ITEMS[itemId]
	if not build then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = Wardrobe.FOLDER
	local c = context(folder, { head = part, torso = part })
	local ok, err = pcall(build, c)
	if not ok then
		warn("[Wardrobe] " .. itemId .. ": " .. tostring(err))
	end
	folder.Parent = part
	return folder
end

-- Takes every game piece off (the avatar's own items come back).
function Wardrobe.undress(character)
	local folder = character:FindFirstChild(Wardrobe.FOLDER)
	if folder then
		folder:Destroy()
	end
	hideConflicts(character, {}, false)
end

-- A stand-in goblin for shop thumbnails and as a fallback preview: a blocky body of the default avatar's
-- proportions, anchored. Dress it like a real character.
function Wardrobe.mannequin()
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local function limb(name, size, cf, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Color = Palette.GOBLIN
		p.Material = SMOOTH
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = shape
			mesh.Scale = Vector3.new(1, 1, 1)
			mesh.Parent = p
		end
		p.Parent = model
		return p
	end
	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.1, 0), Enum.MeshType.Sphere)
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	limb("UpperTorso", Vector3.new(2, 1.6, 1), CFrame.new(0, 2.7, 0))
	limb("LowerTorso", Vector3.new(2, 0.4, 1), CFrame.new(0, 1.7, 0))
	for _, side in ipairs({ -1, 1 }) do
		local prefix = side < 0 and "Left" or "Right"
		limb(prefix .. "UpperArm", Vector3.new(1, 1.2, 1), CFrame.new(side * 1.5, 2.88, 0))
		limb(prefix .. "LowerArm", Vector3.new(1, 1.05, 1), CFrame.new(side * 1.5, 1.75, 0))
		limb(prefix .. "Hand", Vector3.new(1, 0.3, 1), CFrame.new(side * 1.5, 1.07, 0))
		limb(prefix .. "UpperLeg", Vector3.new(1, 1.2, 1), CFrame.new(side * 0.5, 0.9, 0))
		limb(prefix .. "LowerLeg", Vector3.new(1, 1.05, 1), CFrame.new(side * 0.5, -0.22, 0))
		limb(prefix .. "Foot", Vector3.new(1, 0.3, 1), CFrame.new(side * 0.5, -0.9, 0))
	end
	model.PrimaryPart = head
	return model
end

-- Does every goblin item in the catalogue have a look here? (The tests ask.)
function Wardrobe.covers(item)
	if item.slot == "skin" then
		return Wardrobe.SKINS[item.id] ~= nil
	elseif item.slot == "ears" then
		return EARS[item.id] ~= nil
	elseif item.slot == "nose" then
		return NOSES[item.id] ~= nil
	end
	return ITEMS[item.id] ~= nil
end

return Wardrobe

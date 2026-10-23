-- The pets (V11, Goblin Life; V13 the bestiary): forty-two little characters, their alternative looks and their hats.
-- Shared, so the pets that follow goblins about (client/Pets.lua), the shop's previews (client/Shop.lua) and the pets
-- wandering the Port's menagerie (client/PortLife.lua) are built AND animated by the same code.
--
-- A pet is a list of anchored parts, each with a REST position (relative to the pet's own origin, facing -Z, feet at
-- y = 0) and a GROUP (body, head, wingL, legA...). Every frame each part goes to origin * group pose * rest, where a
-- group pose turns about that group's PIVOT (PetLook.pose works out the poses). No scripts, welds or physics in a pet:
-- they cannot touch, push or block anything. The five V11 pets are built below; the thirty-seven V13 ones are in
-- shared/PetBestiary.lua.
--
-- SPECIES says how each one moves and what it does when its goblin stands still:
--   kind   walker (scuttles, strides), hopper, plodder (slow and heavy), crawler (slides along), roller (rolls on its
--          edge) on the ground; flier, floater, swimmer (swims through the air), slither (weaves, a chain of
--          segments) holding a spot in the air beside its goblin. Ground pets ride the deck in a boat and cling on in
--          the air or the water; air pets keep flying.
--   theme  ocean, pirate, magic or island (the shop's filter and the Port's pens)
--   quirk  its idle moment (see PetLook.pose)
-- What a pet DOES (its ability) is the server's: Config.PETS[id].ability.
local Palette = require(script.Parent:WaitForChild("Palette"))
local Config = require(script.Parent:WaitForChild("Config"))

local PetLook = {}

local rgb = Color3.fromRGB
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.SmoothPlastic -- Fabric reads as knitted wool at pet scale
local METAL = Enum.Material.Metal
local FOIL = Enum.Material.Foil
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local SLATE = Enum.Material.Slate

local BLACK = rgb(24, 22, 28)
local WHITE = rgb(248, 248, 250)
local GOLD = rgb(255, 200, 64)

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function deg(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

PetLook.SPECIES = {
	-- The five V11 pets.
	Crab = { kind = "walker", theme = "ocean", quirk = "snap" },
	Tortoise = { kind = "plodder", theme = "ocean", quirk = "yawn" },
	Frog = { kind = "hopper", theme = "island", quirk = "tongue" },
	Gull = { kind = "flier", theme = "pirate", quirk = "look" },
	Ghost = { kind = "floater", theme = "magic", quirk = "loop" },
	-- Ocean.
	Inky = { kind = "walker", theme = "ocean", quirk = "ink" },
	Puffle = { kind = "swimmer", theme = "ocean", quirk = "puff" },
	Nibs = { kind = "swimmer", theme = "ocean", quirk = "circle" },
	Bubbles = { kind = "swimmer", theme = "ocean", quirk = "bubble" },
	Wobble = { kind = "floater", theme = "ocean", quirk = "pulse" },
	Twinkle = { kind = "walker", theme = "ocean", quirk = "cartwheel" },
	Nudi = { kind = "crawler", theme = "ocean", quirk = "wiggle" },
	Tusk = { kind = "swimmer", theme = "ocean", quirk = "flip" },
	Lumo = { kind = "swimmer", theme = "ocean", quirk = "lure" },
	Otter = { kind = "walker", theme = "ocean", quirk = "float" },
	-- Pirate.
	Parrot = { kind = "flier", theme = "pirate", quirk = "look" },
	Rat = { kind = "walker", theme = "pirate", quirk = "sniff" },
	Bat = { kind = "flier", theme = "pirate", quirk = "hang" },
	Monkey = { kind = "hopper", theme = "pirate", quirk = "clap" },
	Ferret = { kind = "walker", theme = "pirate", quirk = "wiggle" },
	Fuse = { kind = "walker", theme = "pirate", quirk = "sparkle" },
	Chompers = { kind = "hopper", theme = "pirate", quirk = "chomp" },
	-- Magic.
	Shard = { kind = "floater", theme = "magic", quirk = "spin" },
	Flurry = { kind = "floater", theme = "magic", quirk = "spin" },
	Glimmer = { kind = "floater", theme = "magic", quirk = "loop" },
	Dubloon = { kind = "roller", theme = "magic", quirk = "flip" },
	Rubble = { kind = "plodder", theme = "magic", quirk = "stomp" },
	Spore = { kind = "hopper", theme = "magic", quirk = "spores" },
	Moth = { kind = "flier", theme = "magic", quirk = "look" },
	Whelp = { kind = "flier", theme = "magic", quirk = "loop" },
	-- Island.
	Levi = { kind = "slither", theme = "island", quirk = "loop" },
	Sunny = { kind = "plodder", theme = "island", quirk = "stomp" },
	Echo = { kind = "floater", theme = "island", quirk = "dart" },
	Lamb = { kind = "walker", theme = "island", quirk = "headbutt" },
	Bones = { kind = "floater", theme = "island", quirk = "brandish" },
	Zap = { kind = "slither", theme = "island", quirk = "spin" },
	Peek = { kind = "walker", theme = "island", quirk = "freeze" },
	Waddles = { kind = "walker", theme = "island", quirk = "slide" },
	Cinderling = { kind = "hopper", theme = "island", quirk = "flare" },
	Bonefish = { kind = "swimmer", theme = "island", quirk = "rattle" },
	Clammy = { kind = "hopper", theme = "island", quirk = "chomp" },
	Twig = { kind = "hopper", theme = "island", quirk = "clap" },
}
PetLook.THEMES = { "ocean", "pirate", "magic", "island" }
PetLook.FLYING = { flier = true, floater = true, swimmer = true, slither = true }

-- How each pet moves (client/Pets.lua): from SPECIES.
PetLook.KIND = {}
for id, species in pairs(PetLook.SPECIES) do
	PetLook.KIND[id] = species.kind
end

local function newRig(petId)
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId
	return {
		id = petId,
		kind = PetLook.KIND[petId],
		species = PetLook.SPECIES[petId],
		model = model,
		parts = {},
		rest = {},
		groups = {},
		pivots = { body = Vector3.zero },
		hat = CFrame.new(0, 1, 0),
		hatGroup = "body",
	}
end

local function add(rig, group, name, shape, size, cf, color, material, transparency)
	local p = shape == "wedge" and Instance.new("WedgePart") or Instance.new("Part")
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or SMOOTH
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = group == "body"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = cf
	p.Parent = rig.model
	table.insert(rig.parts, p)
	table.insert(rig.rest, cf)
	table.insert(rig.groups, group)
	return p
end

-- The pets ----------------------------------------------------------------------------------------------------------
local BUILD = {}

-- Tug Crab: a squat red crab, eyes on stalks, one claw bigger than the other, six busy legs.
BUILD.Crab = function(rig, look)
	local shell, dark, light =
		look.shell or rgb(232, 88, 66), look.dark or rgb(186, 58, 46), look.light or rgb(252, 140, 104)
	local mat = look.material
	rig.pivots.eyes = Vector3.new(0, 0.9, -0.35)
	rig.pivots.clawL = Vector3.new(-0.7, 0.6, -0.4)
	rig.pivots.clawR = Vector3.new(0.7, 0.6, -0.4)
	rig.pivots.pinchL = Vector3.new(-1.0, 0.7, -0.75)
	rig.pivots.pinchR = Vector3.new(1.0, 0.7, -0.75)
	rig.pivots.legA = Vector3.new(0, 0.45, 0)
	rig.pivots.legB = Vector3.new(0, 0.45, 0)
	add(rig, "body", "Body", "egg", Vector3.new(1.75, 0.78, 1.25), CFrame.new(0, 0.58, 0), shell, mat)
	add(rig, "body", "Top", "egg", Vector3.new(1.3, 0.38, 0.92), CFrame.new(0, 0.84, 0.05), light, mat)
	add(rig, "body", "Mouth", "block", Vector3.new(0.34, 0.06, 0.05), CFrame.new(0, 0.48, -0.62), rgb(90, 24, 24))
	for _, side in ipairs({ -1, 1 }) do
		add(
			rig,
			"eyes",
			"Stalk",
			"cyl",
			Vector3.new(0.42, 0.11, 0.11),
			CFrame.new(side * 0.26, 1.06, -0.36) * UPRIGHT,
			dark,
			mat
		)
		add(rig, "eyes", "Eye", "ball", Vector3.new(0.26, 0.26, 0.26), CFrame.new(side * 0.26, 1.32, -0.38), WHITE)
		add(rig, "eyes", "Pupil", "ball", Vector3.new(0.13, 0.13, 0.13), CFrame.new(side * 0.27, 1.34, -0.5), BLACK)
		local claw = side < 0 and "clawL" or "clawR"
		local pinch = side < 0 and "pinchL" or "pinchR"
		local big = side > 0 and 1.25 or 1 -- one claw is bigger: crabs are like that
		add(
			rig,
			claw,
			"Arm",
			"egg",
			Vector3.new(0.26, 0.26, 0.66),
			CFrame.new(side * 0.85, 0.6, -0.5) * deg(0, side * 25, 0),
			shell,
			mat
		)
		add(
			rig,
			claw,
			"Palm",
			"egg",
			Vector3.new(0.5, 0.42, 0.5) * big,
			CFrame.new(side * 1.0, 0.66, -0.86),
			shell,
			mat
		)
		add(
			rig,
			claw,
			"PincerLow",
			"egg",
			Vector3.new(0.26, 0.16, 0.5) * big,
			CFrame.new(side * 1.02, 0.56, -1.16),
			dark,
			mat
		)
		add(
			rig,
			pinch,
			"PincerTop",
			"egg",
			Vector3.new(0.28, 0.2, 0.56) * big,
			CFrame.new(side * 1.02, 0.78, -1.16),
			dark,
			mat
		)
		for i, z in ipairs({ -0.2, 0.15, 0.5 }) do
			local group = ((i + (side > 0 and 1 or 0)) % 2 == 0) and "legA" or "legB"
			add(
				rig,
				group,
				"Leg",
				"block",
				Vector3.new(0.9, 0.14, 0.14),
				CFrame.new(side * 1.0, 0.24, z) * deg(0, side * (z * 30), side * -30),
				dark,
				mat
			)
		end
	end
	rig.hat = CFrame.new(0, 1.05, 0.1)
	if look.hermit then
		local tan, stripe = rgb(236, 212, 170), rgb(176, 104, 62)
		add(rig, "body", "Shell", "egg", Vector3.new(1.35, 1.25, 1.45), CFrame.new(0, 1.15, 0.32) * deg(-15, 0, 0), tan)
		add(
			rig,
			"body",
			"ShellStripe",
			"cyl",
			Vector3.new(0.08, 1.38, 1.38),
			CFrame.new(0, 1.15, 0.32) * deg(0, 0, 70),
			stripe
		)
		add(
			rig,
			"body",
			"ShellStripe",
			"cyl",
			Vector3.new(0.08, 1.2, 1.2),
			CFrame.new(0, 1.3, 0.38) * deg(0, 0, 110),
			stripe
		)
		add(rig, "body", "ShellTip", "ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.82, 0.62), stripe)
		rig.hat = CFrame.new(0, 1.85, 0.25)
	end
end

-- Scout Gull: a round white seabird with grey wings, black tips and a yellow beak.
BUILD.Gull = function(rig, look)
	local body, wing, tip, beak =
		look.body or WHITE, look.wing or rgb(150, 158, 172), look.tip or BLACK, look.beak or rgb(250, 200, 60)
	rig.pivots.head = Vector3.new(0, 0.3, -0.55)
	rig.pivots.wingL = Vector3.new(-0.35, 0.15, 0)
	rig.pivots.wingR = Vector3.new(0.35, 0.15, 0)
	add(rig, "body", "Body", "egg", Vector3.new(0.92, 0.86, 1.6), CFrame.new(0, 0, 0), body)
	if look.belly then
		add(rig, "body", "Belly", "egg", Vector3.new(0.78, 0.72, 1.3), CFrame.new(0, -0.1, -0.12), look.belly)
	end
	add(rig, "head", "Head", "ball", Vector3.new(0.76, 0.76, 0.76), CFrame.new(0, 0.46, -0.76), body)
	if look.face then
		for _, side in ipairs({ -1, 1 }) do
			add(
				rig,
				"head",
				"Face",
				"egg",
				Vector3.new(0.12, 0.5, 0.5),
				CFrame.new(side * 0.32, 0.44, -0.82),
				look.face
			)
		end
	end
	add(
		rig,
		"head",
		"Beak",
		"egg",
		Vector3.new(look.bigBeak and 0.26 or 0.18, look.bigBeak and 0.3 or 0.16, 0.52),
		CFrame.new(0, 0.38, -1.22),
		beak
	)
	if look.bigBeak then
		add(
			rig,
			"head",
			"BeakStripe",
			"egg",
			Vector3.new(0.28, 0.31, 0.1),
			CFrame.new(0, 0.38, -1.12),
			rgb(250, 210, 70)
		)
	else
		add(rig, "head", "BeakDot", "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.33, -1.38), rgb(230, 60, 40))
	end
	for _, side in ipairs({ -1, 1 }) do
		add(rig, "head", "Eye", "ball", Vector3.new(0.13, 0.13, 0.13), CFrame.new(side * 0.28, 0.56, -0.98), BLACK)
		local group = side < 0 and "wingL" or "wingR"
		add(rig, group, "Wing", "egg", Vector3.new(1.6, 0.12, 0.82), CFrame.new(side * 1.0, 0.15, 0.02), wing)
		add(rig, group, "WingTip", "egg", Vector3.new(0.72, 0.1, 0.5), CFrame.new(side * 1.7, 0.15, 0.16), tip)
		add(
			rig,
			"body",
			"Leg",
			"cyl",
			Vector3.new(0.36, 0.09, 0.09),
			CFrame.new(side * 0.18, -0.52, 0.12) * UPRIGHT,
			rgb(255, 150, 60)
		)
	end
	add(
		rig,
		"body",
		"Tail",
		"wedge",
		Vector3.new(0.6, 0.14, 0.52),
		CFrame.new(0, 0.06, 0.98) * deg(0, 180, 0),
		look.tail or wing
	)
	rig.hat = CFrame.new(0, 0.86, -0.74)
	rig.hatGroup = "head"
end

-- Spring Frog: a fat green frog with huge eyes, big back legs and a pale throat that pulses.
BUILD.Frog = function(rig, look)
	local skin, belly = look.skin or rgb(110, 200, 86), look.belly or rgb(206, 232, 146)
	rig.pivots.head = Vector3.new(0, 0.6, -0.3)
	rig.pivots.legBack = Vector3.new(0, 0.35, 0.3)
	rig.pivots.legFront = Vector3.new(0, 0.4, -0.5)
	rig.pivots.throat = Vector3.new(0, 0.5, -0.85)
	add(rig, "body", "Body", "egg", Vector3.new(1.3, 0.86, 1.42), CFrame.new(0, 0.46, 0.1), skin)
	add(rig, "body", "Belly", "egg", Vector3.new(1.0, 0.56, 0.9), CFrame.new(0, 0.33, -0.15), belly)
	add(rig, "head", "Head", "egg", Vector3.new(1.22, 0.62, 0.92), CFrame.new(0, 0.76, -0.55), skin)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, "head", "Eye", "ball", Vector3.new(0.44, 0.44, 0.44), CFrame.new(side * 0.36, 1.1, -0.6), skin)
		add(rig, "head", "EyeWhite", "ball", Vector3.new(0.34, 0.34, 0.34), CFrame.new(side * 0.37, 1.13, -0.7), WHITE)
		add(rig, "head", "Pupil", "ball", Vector3.new(0.18, 0.18, 0.18), CFrame.new(side * 0.38, 1.15, -0.84), BLACK)
		add(rig, "legBack", "Thigh", "egg", Vector3.new(0.42, 0.42, 0.82), CFrame.new(side * 0.66, 0.36, 0.36), skin)
		add(rig, "legBack", "Foot", "egg", Vector3.new(0.38, 0.12, 0.62), CFrame.new(side * 0.72, 0.07, -0.06), skin)
		add(
			rig,
			"legFront",
			"Arm",
			"egg",
			Vector3.new(0.18, 0.52, 0.18),
			CFrame.new(side * 0.46, 0.22, -0.56) * deg(0, 0, side * -12),
			skin
		)
	end
	add(rig, "head", "Mouth", "block", Vector3.new(0.72, 0.04, 0.04), CFrame.new(0, 0.6, -1.0), rgb(60, 90, 40))
	add(rig, "throat", "Throat", "egg", Vector3.new(0.52, 0.3, 0.3), CFrame.new(0, 0.5, -0.86), belly)
	local tongue =
		add(rig, "head", "Tongue", "block", Vector3.new(0.09, 0.05, 1.4), CFrame.new(0, 0.62, -1.7), rgb(236, 90, 110))
	tongue.Transparency = 1
	rig.tongue = tongue
	for i, spot in ipairs(look.spots or {}) do
		add(rig, "body", "Spot" .. i, "ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(spot), BLACK)
	end
	rig.hat = CFrame.new(0, 1.08, -0.4)
	rig.hatGroup = "head"
end

-- Shell Tortoise: a domed shell with paler plates, a slow head, four stumpy legs. Its shell glows while it is ready to
-- bounce a grapple (everyone can see that).
BUILD.Tortoise = function(rig, look)
	local shell, rim, skin, plate =
		look.shell or rgb(112, 132, 70),
		look.rim or rgb(84, 98, 52),
		rgb(152, 162, 102),
		look.plate or rgb(150, 170, 96)
	rig.pivots.head = Vector3.new(0, 0.65, -0.9)
	rig.pivots.legA = Vector3.new(0, 0.4, 0)
	rig.pivots.legB = Vector3.new(0, 0.4, 0)
	add(rig, "body", "Shell", "egg", Vector3.new(1.8, 1.12, 2.0), CFrame.new(0, 0.76, 0), shell)
	add(rig, "body", "Rim", "egg", Vector3.new(2.02, 0.32, 2.22), CFrame.new(0, 0.42, 0), rim)
	for i, at in ipairs({
		Vector3.new(0, 1.3, 0),
		Vector3.new(-0.46, 1.16, 0.36),
		Vector3.new(0.46, 1.16, 0.36),
		Vector3.new(0, 1.18, -0.5),
	}) do
		add(rig, "body", "Plate" .. i, "egg", Vector3.new(0.62, 0.2, 0.62), CFrame.new(at), plate)
	end
	rig.glow = add(
		rig,
		"body",
		"Glow",
		"egg",
		Vector3.new(1.98, 1.24, 2.18),
		CFrame.new(0, 0.77, 0),
		rgb(255, 226, 120),
		NEON,
		0.62
	)
	add(rig, "head", "Head", "egg", Vector3.new(0.56, 0.52, 0.74), CFrame.new(0, 0.66, -1.16), skin)
	for _, side in ipairs({ -1, 1 }) do
		add(rig, "head", "Eye", "ball", Vector3.new(0.11, 0.11, 0.11), CFrame.new(side * 0.19, 0.8, -1.42), BLACK)
	end
	add(rig, "head", "Mouth", "block", Vector3.new(0.3, 0.03, 0.03), CFrame.new(0, 0.58, -1.52), rgb(70, 60, 40))
	for i, at in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local group = (i == 1 or i == 4) and "legA" or "legB"
		add(
			rig,
			group,
			"Leg",
			"cyl",
			Vector3.new(0.46, 0.42, 0.42),
			CFrame.new(at[1] * 0.64, 0.22, at[2] * 0.6) * UPRIGHT,
			skin
		)
	end
	add(rig, "body", "Tail", "wedge", Vector3.new(0.2, 0.2, 0.36), CFrame.new(0, 0.38, 1.16) * deg(0, 180, 0), skin)
	for i, flower in ipairs(look.flowers or {}) do
		add(
			rig,
			"body",
			"Tuft" .. i,
			"egg",
			Vector3.new(0.4, 0.22, 0.4),
			CFrame.new(flower.at),
			rgb(80, 150, 56),
			FABRIC
		)
		add(
			rig,
			"body",
			"Flower" .. i,
			"ball",
			Vector3.new(0.16, 0.16, 0.16),
			CFrame.new(flower.at + Vector3.new(0, 0.16, 0)),
			flower.color
		)
	end
	rig.hat = CFrame.new(0, 0.96, -1.12)
	rig.hatGroup = "head"
end

-- Pocket Ghost: a little round spirit with a wispy tail, nub arms, black eyes and an "o" mouth.
BUILD.Ghost = function(rig, look)
	local body = look.body or rgb(226, 240, 255)
	rig.pivots.armL = Vector3.new(-0.55, 0.15, 0)
	rig.pivots.armR = Vector3.new(0.55, 0.15, 0)
	rig.pivots.tail1 = Vector3.new(0, -0.3, 0.1)
	rig.pivots.tail2 = Vector3.new(0, -0.75, 0.25)
	rig.pivots.tail3 = Vector3.new(0, -1.05, 0.38)
	add(rig, "body", "Body", "egg", Vector3.new(1.32, 1.42, 1.22), CFrame.new(0, 0.2, 0), body, SMOOTH, 0.12)
	add(rig, "tail1", "Tail1", "egg", Vector3.new(0.92, 0.72, 0.82), CFrame.new(0, -0.55, 0.15), body, SMOOTH, 0.18)
	add(rig, "tail2", "Tail2", "egg", Vector3.new(0.56, 0.5, 0.52), CFrame.new(0.12, -0.95, 0.32), body, SMOOTH, 0.25)
	add(rig, "tail3", "Tail3", "egg", Vector3.new(0.3, 0.36, 0.3), CFrame.new(0.24, -1.2, 0.45), body, SMOOTH, 0.32)
	for _, side in ipairs({ -1, 1 }) do
		add(
			rig,
			side < 0 and "armL" or "armR",
			"Arm",
			"egg",
			Vector3.new(0.26, 0.46, 0.26),
			CFrame.new(side * 0.7, 0.02, -0.1) * deg(0, 0, side * 35),
			body,
			SMOOTH,
			0.12
		)
		if not look.pumpkin then
			add(rig, "body", "Eye", "egg", Vector3.new(0.18, 0.3, 0.08), CFrame.new(side * 0.24, 0.36, -0.58), BLACK)
			add(
				rig,
				"body",
				"Blush",
				"egg",
				Vector3.new(0.17, 0.08, 0.05),
				CFrame.new(side * 0.42, 0.14, -0.5),
				rgb(255, 160, 190)
			)
		end
	end
	if look.pumpkin then
		local orange = rgb(240, 130, 36)
		add(rig, "body", "Pumpkin", "egg", Vector3.new(1.3, 1.02, 1.2), CFrame.new(0, 0.5, -0.05), orange)
		add(
			rig,
			"body",
			"Rib",
			"egg",
			Vector3.new(0.5, 1.04, 1.24),
			CFrame.new(0, 0.5, -0.05),
			orange:Lerp(rgb(160, 70, 20), 0.25)
		)
		add(
			rig,
			"body",
			"Stem",
			"cyl",
			Vector3.new(0.3, 0.16, 0.16),
			CFrame.new(0, 1.08, -0.05) * UPRIGHT,
			rgb(70, 110, 40)
		)
		for _, side in ipairs({ -1, 1 }) do
			add(
				rig,
				"body",
				"Carved",
				"wedge",
				Vector3.new(0.06, 0.22, 0.26),
				CFrame.new(side * 0.26, 0.62, -0.62) * deg(0, 90, 0),
				rgb(255, 210, 90),
				NEON
			)
		end
		add(
			rig,
			"body",
			"Grin",
			"block",
			Vector3.new(0.5, 0.1, 0.06),
			CFrame.new(0, 0.3, -0.62),
			rgb(255, 210, 90),
			NEON
		)
		rig.hat = CFrame.new(0, 1.12, -0.05)
	else
		add(rig, "body", "Mouth", "egg", Vector3.new(0.22, 0.2, 0.08), CFrame.new(0, 0.04, -0.6), rgb(60, 50, 80))
		rig.hat = CFrame.new(0, 0.92, 0)
	end
end

-- Alternative looks ---------------------------------------------------------------------------------------------------
PetLook.SKINS = {
	petskin_crab_hermit = {
		pet = "Crab",
		look = { hermit = true, shell = rgb(242, 136, 82), dark = rgb(196, 92, 56), light = rgb(255, 172, 120) },
	},
	petskin_crab_gold = {
		pet = "Crab",
		look = { shell = GOLD, dark = rgb(214, 150, 40), light = rgb(255, 226, 120), material = FOIL },
	},
	petskin_gull_puffin = {
		pet = "Gull",
		look = {
			body = rgb(36, 36, 44),
			belly = WHITE,
			face = WHITE,
			wing = rgb(36, 36, 44),
			tip = rgb(20, 20, 26),
			beak = rgb(240, 110, 40),
			bigBeak = true,
		},
	},
	petskin_frog_dart = {
		pet = "Frog",
		look = {
			skin = rgb(40, 124, 232),
			belly = rgb(28, 88, 186),
			spots = {
				Vector3.new(-0.32, 0.86, 0.2),
				Vector3.new(0.3, 0.84, 0.45),
				Vector3.new(0.05, 0.88, 0.62),
				Vector3.new(-0.5, 0.6, 0.55),
			},
		},
	},
	petskin_tortoise_moss = {
		pet = "Tortoise",
		look = {
			shell = rgb(72, 128, 58),
			plate = rgb(98, 158, 70),
			flowers = {
				{ at = Vector3.new(0.1, 1.42, 0.05), color = rgb(255, 140, 190) },
				{ at = Vector3.new(-0.5, 1.26, 0.4), color = rgb(255, 230, 90) },
				{ at = Vector3.new(0.45, 1.24, -0.35), color = WHITE },
			},
		},
	},
	petskin_ghost_pumpkin = { pet = "Ghost", look = { pumpkin = true } },
}

-- Pet hats (on the pet's own hat spot) --------------------------------------------------------------------------------
local HATS = {}
HATS.pethat_bow = function(rig, at, group)
	local red = rgb(226, 44, 60)
	for _, side in ipairs({ -1, 1 }) do
		add(
			rig,
			group,
			"Bow",
			"egg",
			Vector3.new(0.46, 0.3, 0.16),
			at * CFrame.new(side * 0.22, 0.08, 0) * deg(0, 0, side * -18),
			red,
			FABRIC
		)
	end
	add(rig, group, "BowKnot", "ball", Vector3.new(0.16, 0.16, 0.16), at * CFrame.new(0, 0.08, 0), red, FABRIC)
end
HATS.pethat_party = function(rig, at, group)
	local tilt = at * deg(0, 0, -12)
	for i, spec in ipairs({ { 0.56, rgb(80, 180, 255) }, { 0.4, rgb(255, 210, 60) }, { 0.24, rgb(255, 90, 160) } }) do
		add(
			rig,
			group,
			"Cone" .. i,
			"cyl",
			Vector3.new(0.22, spec[1], spec[1]),
			tilt * CFrame.new(0, 0.1 + (i - 1) * 0.2, 0) * UPRIGHT,
			spec[2]
		)
	end
	add(rig, group, "Pompom", "ball", Vector3.new(0.16, 0.16, 0.16), tilt * CFrame.new(0, 0.66, 0), WHITE, FABRIC)
end
HATS.pethat_tricorn = function(rig, at, group)
	local felt = rgb(40, 32, 38)
	add(rig, group, "Crown", "cyl", Vector3.new(0.24, 0.5, 0.5), at * CFrame.new(0, 0.12, 0) * UPRIGHT, felt, FABRIC)
	for i, n in ipairs({ Vector3.new(0, 0, 1), Vector3.new(-0.866, 0, -0.5), Vector3.new(0.866, 0, -0.5) }) do
		local center = Vector3.new(0, 0.1, 0) + n * 0.27
		add(
			rig,
			group,
			"Brim" .. i,
			"block",
			Vector3.new(0.66, 0.2, 0.05),
			at * CFrame.lookAt(center, center + n) * deg(-25, 0, 0),
			felt,
			FABRIC
		)
	end
	add(rig, group, "Skull", "ball", Vector3.new(0.12, 0.12, 0.12), at * CFrame.new(0, 0.13, -0.27), WHITE)
end
HATS.pethat_crown = function(rig, at, group)
	add(rig, group, "Band", "cyl", Vector3.new(0.18, 0.52, 0.52), at * CFrame.new(0, 0.09, 0) * UPRIGHT, GOLD, METAL)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + math.pi / 2
		add(
			rig,
			group,
			"Point" .. i,
			"block",
			Vector3.new(0.12, 0.24, 0.08),
			at * CFrame.new(math.cos(a) * 0.23, 0.26, -math.sin(a) * 0.23),
			GOLD,
			METAL
		)
	end
	add(
		rig,
		group,
		"Jewel",
		"ball",
		Vector3.new(0.12, 0.12, 0.12),
		at * CFrame.new(0, 0.1, -0.26),
		rgb(220, 30, 64),
		Enum.Material.Glass
	)
end
-- V13.3: earned in the Port (an achievement or a week's quests).
HATS.pethat_explorer = function(rig, at, group)
	local khaki = rgb(214, 190, 140)
	add(rig, group, "Dome", "egg", Vector3.new(0.5, 0.34, 0.56), at * CFrame.new(0, 0.16, 0), khaki)
	add(rig, group, "Brim", "cyl", Vector3.new(0.05, 0.78, 0.82), at * CFrame.new(0, 0.05, 0) * UPRIGHT, khaki)
	add(
		rig,
		group,
		"Band",
		"cyl",
		Vector3.new(0.07, 0.52, 0.56),
		at * CFrame.new(0, 0.1, 0) * UPRIGHT,
		rgb(120, 76, 44)
	)
end
HATS.pethat_laurel = function(rig, at, group)
	local leaf = rgb(96, 170, 70)
	for i = 0, 4 do -- five leaves: the biggest pet plus its hat stays within the 40-part budget (PetSpec)
		local a = i / 5 * math.pi * 2
		add(
			rig,
			group,
			"Leaf" .. i,
			"egg",
			Vector3.new(0.12, 0.08, 0.22),
			at * CFrame.new(math.cos(a) * 0.26, 0.06, math.sin(a) * 0.26) * CFrame.Angles(0, -a, math.rad(20)),
			i % 2 == 0 and leaf or rgb(130, 196, 80)
		)
	end
end
-- V13.4: the weekly Pirate Championship's gold tier: a big doubloon worn like a badge.
HATS.pethat_doubloon = function(rig, at, group)
	add(
		rig,
		group,
		"Coin",
		"cyl",
		Vector3.new(0.08, 0.44, 0.44),
		at * CFrame.new(0, 0.2, -0.1) * deg(0, 90, 0),
		GOLD,
		METAL
	)
	add(
		rig,
		group,
		"CoinMark",
		"block",
		Vector3.new(0.12, 0.04, 0.1),
		at * CFrame.new(0, 0.2, -0.15),
		rgb(190, 120, 20),
		METAL
	)
end
HATS.pethat_medal = function(rig, at, group)
	local blue = rgb(50, 110, 220)
	add(
		rig,
		group,
		"Rosette",
		"cyl",
		Vector3.new(0.08, 0.46, 0.46),
		at * CFrame.new(0, 0.12, -0.12) * deg(0, 90, 0),
		blue
	)
	add(
		rig,
		group,
		"RosetteCore",
		"cyl",
		Vector3.new(0.1, 0.24, 0.24),
		at * CFrame.new(0, 0.12, -0.16) * deg(0, 90, 0),
		GOLD,
		METAL
	)
	for _, side in ipairs({ -1, 1 }) do
		add(
			rig,
			group,
			"Ribbon",
			"block",
			Vector3.new(0.1, 0.3, 0.04),
			at * CFrame.new(side * 0.08, -0.08, -0.14) * deg(0, 0, side * 12),
			blue
		)
	end
end
PetLook.HATS = HATS

-- The V13 bestiary: thirty-seven more pets, built with the same parts kit.
do
	local bestiary = require(script.Parent:WaitForChild("PetBestiary"))({
		add = add,
		deg = deg,
		rgb = rgb,
		UPRIGHT = UPRIGHT,
		SMOOTH = SMOOTH,
		NEON = NEON,
		METAL = METAL,
		GLASS = GLASS,
		FOIL = FOIL,
		SLATE = SLATE,
		BLACK = BLACK,
		WHITE = WHITE,
		GOLD = GOLD,
	})
	for id, builder in pairs(bestiary) do
		BUILD[id] = builder
	end
end

-- V13 pet looks (an alternative colouring of one pet, worn by that pet only).
PetLook.SKINS.petskin_inky_glow = {
	pet = "Inky",
	look = { skin = rgb(40, 150, 170), spot = rgb(120, 255, 230) },
}
PetLook.SKINS.petskin_parrot_macaw = {
	pet = "Parrot",
	look = { red = rgb(40, 120, 230), blue = rgb(255, 200, 40) },
}
PetLook.SKINS.petskin_wobble_moon = {
	pet = "Wobble",
	look = { bell = rgb(196, 220, 255), glow = rgb(235, 245, 255) },
}

-- Builds a pet. Returns the rig (see the header), its parts placed at rest around the origin.
-- V13: rig.groupSet (the groups it has, for the animator), rig.glow (the "ready" glow of a pet whose ability is the
-- Shell: the Tortoise has its own, the others get a soft halo), rig.light (a lamp on its lure, flame or core).
function PetLook.build(petId, skinId, hatId)
	local builder = BUILD[petId]
	if not builder then
		return nil
	end
	local rig = newRig(petId)
	local skin = skinId and PetLook.SKINS[skinId]
	builder(rig, (skin and skin.pet == petId) and skin.look or {})
	local hat = hatId and HATS[hatId]
	if hat then
		hat(rig, rig.hat, rig.hatGroup)
	end
	local def = Config.PETS[petId]
	if def and def.ability == "Tortoise" and not rig.glow then
		local cf, size = rig.model:GetBoundingBox()
		rig.glow = add(
			rig,
			"body",
			"Glow",
			"egg",
			size * 1.12,
			cf, -- the parts sit at rest round the origin, so the box is already in the pet's own frame
			rgb(255, 226, 120),
			NEON,
			0.62
		)
		rig.glow.CastShadow = false
	end
	rig.groupSet = {}
	for _, group in ipairs(rig.groups) do
		rig.groupSet[group] = true
	end
	if rig.light then
		for _, part in ipairs(rig.parts) do
			if part.Name == rig.light.part then
				local l = Instance.new("PointLight")
				l.Color = rig.light.color
				l.Range = rig.light.range
				l.Brightness = 0.9
				l.Shadows = false
				l.Parent = part
				break
			end
		end
	end
	return rig
end

-- Does every pet item in the catalogue have a look here? (The tests ask.)
function PetLook.covers(item)
	if item.slot == "pet" then
		return BUILD[item.id] ~= nil and PetLook.SPECIES[item.id] ~= nil
	elseif item.slot == "petskin" then
		local skin = PetLook.SKINS[item.id]
		return skin ~= nil and skin.pet == item.pet
	elseif item.slot == "pethat" then
		return HATS[item.id] ~= nil
	end
	return false
end

-- A colour for each pet (the shop's accents): the art direction's where it has one, Config.PETS's otherwise.
PetLook.ACCENT = {
	Crab = Palette.CORAL,
	Gull = rgb(240, 240, 245),
	Frog = rgb(110, 220, 110),
	Tortoise = rgb(110, 150, 90),
	Ghost = Palette.GHOST,
}
for id, def in pairs(Config.PETS) do
	if not PetLook.ACCENT[id] and def.color then
		PetLook.ACCENT[id] = def.color
	end
end

-- The animator -----------------------------------------------------------------------------------------------------------
-- PetLook.pose(entry, t, move, s) -> poses (group -> CFrame about its pivot), bounce (studs up), extra (a CFrame for the
-- whole pet: a roll, a flip, a spin, or nil). entry: { rig, phase, quirk, quirkAt } (phase advances with the pet's own
-- movement); move: how fast the pet itself is going; s: { speed (its goblin's), chased, diving }.
-- One function for every pet, by what groups it has, so a new species needs no animation code: give it the groups.
local function A(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end
local function ease(p)
	p = math.clamp(p, 0, 1)
	return p * p * (3 - 2 * p)
end

local KIND = {}

KIND.walker = function(entry, t, move, s, poses)
	local rig = entry.rig
	local walking = move > 1.5
	local stride = walking and math.sin(entry.phase * 14) or 0
	if rig.id == "Crab" then
		-- V11's crab: sideways scuttle, claws, snapping pincers.
		local snap = 0
		if entry.quirk == "snap" or (s.chased and math.sin(t * 9) > 0.6) then
			snap = math.max(0, math.sin(t * 18))
		end
		poses.legA = CFrame.new(0, 0.06 * math.max(0, stride), 0) * A(0, 0, 14 * stride)
		poses.legB = CFrame.new(0, 0.06 * math.max(0, -stride), 0) * A(0, 0, -14 * stride)
		poses.clawL = A(0, 6 * math.sin(t * 2.2), 0)
		poses.clawR = A(0, -6 * math.sin(t * 2.2 + 1), 0)
		poses.pinchL = A(-28 * snap, 0, 0)
		poses.pinchR = A(-28 * snap, 0, 0)
		poses.eyes = CFrame.new(0, 0.05 * math.sin(t * 3), 0)
	else
		poses.legA = CFrame.new(0, 0.05 * math.max(0, stride), 0) * A(28 * stride, 0, 0)
		poses.legB = CFrame.new(0, 0.05 * math.max(0, -stride), 0) * A(-28 * stride, 0, 0)
		poses.armL = A(-22 * stride, 0, 0)
		poses.armR = A(22 * stride, 0, 0)
		poses.tentA = A(18 * stride, 0, 0)
		poses.tentB = A(-18 * stride, 0, 0)
	end
	return walking and 0.06 * math.abs(math.sin(entry.phase * 14)) or 0
end

KIND.hopper = function(entry, t, move, s, poses)
	local hopping = move > 1.5 or s.chased
	local p = (entry.phase * 2.2) % 1
	local lift = hopping and math.sin(p * math.pi) or 0
	local tongue = entry.quirk == "tongue"
	if entry.rig.tongue then
		entry.rig.tongue.Transparency = tongue and 0 or 1
	end
	poses.legBack = A(hopping and (p < 0.5 and -35 or 10) or 0, 0, 0)
	poses.legFront = A(hopping and -20 * lift or 0, 0, 0)
	poses.throat = CFrame.new(0, 0, -0.06 * (0.5 + 0.5 * math.sin(t * 7)))
	poses.head = A(tongue and 8 or 0, 0, 0)
	poses.armL = A(hopping and -40 * lift or 0, 0, 0)
	poses.armR = A(hopping and -40 * lift or 0, 0, 0)
	return 1.3 * lift
end

KIND.plodder = function(entry, t, move, s, poses)
	local walking = move > 1
	local step = walking and math.sin(entry.phase * 7) or 0
	local yawn = entry.quirk == "yawn" and math.sin(math.clamp((t - (entry.quirkAt or t)) / 1.6, 0, 1) * math.pi) or 0
	poses.legA = CFrame.new(0, 0.12 * math.max(0, step), 0)
	poses.legB = CFrame.new(0, 0.12 * math.max(0, -step), 0)
	poses.head = CFrame.new(0, 0.04 * step, (s.chased and 0.35 or 0) - 0.08 * yawn) * A(18 * yawn, 0, 0)
	poses.armL = A(-15 * step, 0, 0)
	poses.armR = A(15 * step, 0, 0)
	-- The stone ones stomp: a little drop on every step.
	local heavy = entry.rig.id ~= "Tortoise"
	return heavy and 0.07 * math.abs(step) or 0
end

KIND.crawler = function(entry, t, move, _s, poses)
	local speed = move > 1 and 9 or 3
	poses.tentA = A(14 * math.sin(t * speed), 0, 0)
	poses.tentB = A(-14 * math.sin(t * speed), 0, 0)
	return 0.03 * math.abs(math.sin(entry.phase * 10))
end

KIND.roller = function(entry, _t, _move, _s, poses)
	local _ = poses
	return 0, CFrame.new(0, 0.9, 0) * A(-entry.phase * 520, 0, 0) * CFrame.new(0, -0.9, 0)
end

KIND.flier = function(entry, t, _move, s, poses)
	local fast = (s.speed or 0) > 30 or s.diving
	local flap = math.sin(t * (fast and 22 or 12))
	local gliding = not fast and math.sin(t * 0.7) > 0.3
	local wing = gliding and 4 or 34 * flap
	local look = entry.quirk == "look" and 50 * math.sin((t - (entry.quirkAt or t)) * 3) or 12 * math.sin(t * 0.9)
	poses.wingL = A(0, 0, -wing)
	poses.wingR = A(0, 0, wing)
	poses.head = A(0, look, 0)
	return 0.12 * flap
end

KIND.floater = function(_entry, t, _move, s, poses)
	local wave = math.sin(t * 3)
	poses.tail1 = A(8 * math.sin(t * 2.6), 10 * wave, 0)
	poses.tail2 = A(12 * math.sin(t * 2.6 - 0.8), 16 * math.sin(t * 3 - 0.8), 0)
	poses.tail3 = A(16 * math.sin(t * 2.6 - 1.6), 22 * math.sin(t * 3 - 1.6), 0)
	poses.armL = A(0, 0, -20 - 20 * math.sin(t * 4))
	poses.armR = A(0, 0, 20 + 20 * math.sin(t * 4 + 1))
	return 0.25 * math.sin(t * 2.4) + (s.chased and 0.08 * math.sin(t * 40) or 0)
end

KIND.swimmer = function(_entry, t, _move, s, poses)
	local fast = (s.speed or 0) > 30
	local beat = math.sin(t * (fast and 12 or 5))
	poses.tail = A(0, 26 * beat, 0)
	poses.finL = A(0, 0, -25 * math.sin(t * 6))
	poses.finR = A(0, 0, 25 * math.sin(t * 6))
	return 0.18 * math.sin(t * 1.9), A(0, -6 * beat, 0)
end

KIND.slither = function(_entry, t, _move, _s, poses)
	for i = 1, 5 do
		local w = math.sin(t * 4 - i * 0.9)
		poses["seg" .. i] = CFrame.new(w * 0.12 * i, 0.05 * math.sin(t * 3 - i), 0) * A(0, 14 * w, 0)
	end
	poses.head = A(4 * math.sin(t * 2), 10 * math.sin(t * 4 + 0.6), 0)
	return 0.2 * math.sin(t * 1.6)
end

function PetLook.pose(entry, t, move, s)
	local rig = entry.rig
	local poses = {}
	local kindPose = KIND[rig.kind] or KIND.walker
	local bounce, extra = kindPose(entry, t, move, s, poses)
	bounce = bounce or 0
	local has = rig.groupSet or {}
	-- What every pet has, whatever it is.
	if has.tail and not poses.tail then
		poses.tail = A(0, 16 * math.sin(t * (move > 1.5 and 9 or 4)), 0)
	end
	if has.finL and not poses.finL then
		poses.finL = A(0, 0, -20 * math.sin(t * 5))
		poses.finR = A(0, 0, 20 * math.sin(t * 5))
	end
	if has.tentA and not poses.tentA then
		poses.tentA = A(15 * math.sin(t * 2.5), 0, 0)
		poses.tentB = A(-15 * math.sin(t * 2.5), 0, 0)
	end
	if has.seg1 and not poses.seg1 then
		-- A ferret's segments wiggle as it runs.
		local w = move > 1.5 and 1 or 0.3
		for i = 1, 3 do
			poses["seg" .. i] = A(0, 10 * w * math.sin(t * 9 - i), 0)
		end
	end
	if has.lid and not poses.lid then
		poses.lid = A(-6 * (0.5 + 0.5 * math.sin(t * 2)), 0, 0)
	end
	if has.halo then
		poses.halo = A(0, 0, t * 45)
	end
	if has.orbit then
		poses.orbit = A(0, t * 90, 0)
	end
	if has.flame then
		poses.flame = CFrame.new(0, 0.05 * math.sin(t * 17), 0) * A(5 * math.sin(t * 13), 0, 6 * math.sin(t * 11))
	end
	if has.lure then
		poses.lure = A(10 * math.sin(t * 2), 0, 8 * math.sin(t * 1.3))
	end
	if has.bell then
		poses.bell = CFrame.new(0, 0.08 * math.sin(t * 2.6), 0)
	end
	if has.head and not poses.head then
		poses.head = CFrame.new(0, 0.03 * math.sin(t * 2.4), 0) * A(0, 10 * math.sin(t * 0.8), 0)
	end
	-- Its quirk, when its goblin stands still (and a few that answer to speed or danger).
	local quirk = entry.quirk
	local q = quirk and (t - (entry.quirkAt or t)) or 0
	if quirk == "spin" then
		extra = A(0, ease(q / 1.2) * 360, 0)
	elseif quirk == "flip" then
		extra = CFrame.new(0, 0.9, 0) * A(-ease(q / 1.0) * 360, 0, 0) * CFrame.new(0, -0.9, 0)
		bounce += math.sin(math.clamp(q / 1.0, 0, 1) * math.pi) * 1.2
	elseif quirk == "loop" then
		extra = A(ease(q / 1.2) * 360, 0, 0)
	elseif quirk == "cartwheel" then
		extra = CFrame.new(0, 0.95, 0) * A(0, 0, ease(q / 1.2) * 360) * CFrame.new(0, -0.95, 0)
	elseif quirk == "hang" then
		extra = CFrame.new(0, 0.4, 0) * A(180, 0, 0)
		poses.wingL = A(0, 0, -70)
		poses.wingR = A(0, 0, 70)
	elseif quirk == "float" then
		extra = CFrame.new(0, 0.6, 0) * A(-80, 0, 0)
		bounce += 0.1 * math.sin(t * 2)
	elseif quirk == "clap" then
		local clap = math.abs(math.sin(q * 14))
		poses.armL = A(-60, 0, -50 * clap)
		poses.armR = A(-60, 0, 50 * clap)
	elseif quirk == "chomp" then
		poses.lid = A(-38 * math.abs(math.sin(q * 12)), 0, 0)
	elseif quirk == "brandish" then
		poses.armR = A(-70 * math.abs(math.sin(q * 5)), 0, 25)
	elseif quirk == "headbutt" and q < 0.6 then
		extra = CFrame.new(0, 0, -0.7 * math.sin(q / 0.6 * math.pi)) * A(-15 * math.sin(q / 0.6 * math.pi), 0, 0)
	elseif quirk == "stomp" then
		bounce += 0.45 * math.abs(math.sin(q * 6)) * (q < 1.2 and 1 or 0)
	elseif quirk == "sniff" then
		poses.head = A(10 * math.sin(t * 22), 0, 0)
	elseif quirk == "flare" then
		poses.flame = CFrame.new(0, 0.25, 0) * A(0, q * 200, 0)
	elseif quirk == "rattle" then
		extra = A(0, 0, 9 * math.sin(q * 40))
	elseif quirk == "pulse" then
		poses.bell = CFrame.new(0, 0.25 * math.abs(math.sin(q * 5)), 0)
	elseif quirk == "wiggle" then
		poses.tentA = A(25 * math.sin(t * 14), 0, 0)
		poses.tentB = A(-25 * math.sin(t * 14), 0, 0)
	elseif quirk == "lure" then
		poses.lure = A(30 * math.sin(q * 6), 0, 20 * math.sin(q * 4))
	end
	-- The penguin slides on its belly when its goblin runs.
	if rig.species and rig.species.quirk == "slide" and move > 14 then
		extra = CFrame.new(0, 0.5, 0) * A(-78, 0, 0)
		bounce = 0
	end
	-- The pufferfish puffs up when frightened (its quirk, or something big chasing its goblin).
	if rig.puff then
		local puffed = quirk == "puff" or s.chased == true
		if rig.puffed ~= puffed then
			rig.puffed = puffed
			for _, part in ipairs(rig.puff) do
				part.Transparency = puffed and 0 or 1
			end
		end
	end
	return poses, bounce, extra
end

-- How long a quirk lasts (the client clears it after this). Peek's "freeze" is not a moment but a rule (it only moves
-- while nobody is looking at it: client/Pets.lua).
PetLook.QUIRK_TIME = { hang = 3.5, float = 3.5, circle = 2.4, dart = 1.6, freeze = 0 }

-- Starts and ends a pet's idle quirk. `idle`: its goblin is standing still. Returns the quirk when one starts now.
function PetLook.updateQuirk(entry, t, idle)
	if entry.quirk and t - (entry.quirkAt or t) > (PetLook.QUIRK_TIME[entry.quirk] or 1.8) then
		entry.quirk = nil
	end
	if idle and not entry.quirk and t >= (entry.idleAt or 0) then
		entry.idleAt = t + 6 + math.random() * 5
		local quirk = entry.rig.species and entry.rig.species.quirk
		if quirk and quirk ~= "freeze" and quirk ~= "slide" then
			entry.quirk, entry.quirkAt = quirk, t
			return quirk
		end
	end
	return nil
end

-- Where every part of a posed pet goes: origin * extra * (group pose about its pivot) * rest. With `parts` and
-- `cframes` the moves are appended for one BulkMoveTo; without, the parts are placed directly (a preview).
function PetLook.apply(rig, origin, poses, extra, parts, cframes)
	if extra then
		origin = origin * extra
	end
	local cache = {}
	for i, part in ipairs(rig.parts) do
		local group = rig.groups[i]
		local g = cache[group]
		if not g then
			local pose = poses[group]
			if pose then
				local pivot = rig.pivots[group] or Vector3.zero
				g = CFrame.new(pivot) * pose * CFrame.new(-pivot)
			else
				g = CFrame.identity
			end
			cache[group] = g
		end
		local cf = origin * g * rig.rest[i]
		if parts then
			table.insert(parts, part)
			table.insert(cframes, cf)
		else
			part.CFrame = cf
		end
	end
	return origin
end

return PetLook

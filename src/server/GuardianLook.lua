-- What the Sun Temple's Guardian looks like (V10, docs/ART_DIRECTION.md). One design, used twice: the rigged
-- golem that walks its island (Threats.lua) and the one squeezed into its tiny speedboat (Pursuit.lua), so the
-- thing chasing you is unmistakably the thing you robbed.
--
-- The idea: a temple come to life. Sandstone body, top-heavy (shoulders and fists far too big for its legs),
-- gold bands like temple trim, moss where it has stood for centuries, deep sockets with burning eyes, and a
-- golden sun disc behind its head that slowly turns. The sun disc is its silhouette: from a boat you see the
-- halo before you see the face.
--
-- Rig space: the origin is between the feet, +Y is up, -Z is forward (the face). Each part has a pivot (the
-- joint it turns about), a hang (the offset from that joint to the part) and a limb tag that says which joint
-- moves it: "armL", "armR", "legL", "legR", "halo" (spins about the disc's centre) or nil (the body).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Palette"))

local GuardianLook = {}

GuardianLook.STONE = Color3.fromRGB(176, 152, 126)
GuardianLook.STONE_DARK = Color3.fromRGB(122, 102, 92)
GuardianLook.GOLD = Palette.GOLD_DEEP
GuardianLook.MOSS = Color3.fromRGB(98, 170, 74)
GuardianLook.SOCKET = Color3.fromRGB(36, 26, 26)

local S, D, G = GuardianLook.STONE, GuardianLook.STONE_DARK, GuardianLook.GOLD
local SLATE, METAL, GRASS, NEON = Enum.Material.Slate, Enum.Material.Metal, Enum.Material.Grass, Enum.Material.Neon
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder

local SHOULDER = 15.4
local HIP = 6.5
local HALO = Vector3.new(0, 20.6, 2.8)

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

-- The parts, in rig space. Built fresh each call (callers scale and keep them).
function GuardianLook.parts()
	local list = {}
	local function add(name, size, color, material, pivot, hang, limb, shape)
		table.insert(list, {
			name = name,
			size = size,
			color = color,
			material = material,
			pivot = pivot,
			hang = hang or CFrame.new(),
			limb = limb,
			shape = shape,
		})
	end
	-- The body.
	add("Torso", Vector3.new(10, 8, 7), S, SLATE, at(0, 12.2, 0))
	add("Belly", Vector3.new(8.4, 3.6, 6.2), D, SLATE, at(0, 7.6, 0.2))
	add("Belt", Vector3.new(9.4, 1.2, 6.9), G, METAL, at(0, 9.3, 0))
	add(
		"ChestSun",
		Vector3.new(0.8, 4.6, 4.6),
		G,
		METAL,
		at(0, 13, -3.6) * CFrame.Angles(0, math.rad(90), 0),
		nil,
		nil,
		CYL
	)
	for _, side in ipairs({ -1, 1 }) do
		add("Shoulder", Vector3.new(6.4, 6.4, 6.4), S, SLATE, at(side * 6.3, 15.8, 0), nil, nil, BALL)
		add(
			"Moss",
			Vector3.new(4.8, 1.1, 4.4),
			GuardianLook.MOSS,
			GRASS,
			at(side * 6, 18.8, 0.3) * CFrame.Angles(0, 0, side * -0.25)
		)
	end
	-- The head: a heavy brow over deep sockets, a jaw jutting forward.
	add("Head", Vector3.new(6.6, 5, 5.6), S, SLATE, at(0, 19.6, -0.3))
	add("Jaw", Vector3.new(5.8, 1.7, 4.6), D, SLATE, at(0, 17, -1.1))
	add("Brow", Vector3.new(7.4, 1.4, 1.9), D, SLATE, at(0, 21.4, -2.9) * CFrame.Angles(math.rad(-10), 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		add("Socket", Vector3.new(2, 1.5, 0.3), GuardianLook.SOCKET, SLATE, at(side * 1.5, 20.1, -3.12))
		add("Eye", Vector3.new(1.5, 1, 0.4), Color3.fromRGB(60, 25, 25), NEON, at(side * 1.5, 20.1, -3.28))
	end
	-- The sun halo behind the head: a disc and six rays, turning slowly.
	add("SunDisc", Vector3.new(0.8, 10, 10), G, METAL, CFrame.new(HALO), CFrame.Angles(0, math.rad(90), 0), "halo", CYL)
	add(
		"SunCore",
		Vector3.new(0.9, 6.4, 6.4),
		Color3.fromRGB(255, 214, 110),
		NEON,
		CFrame.new(HALO),
		CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.rad(90), 0),
		"halo",
		CYL
	)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		add(
			"SunRay",
			Vector3.new(1.4, 3.4, 0.7),
			G,
			METAL,
			CFrame.new(HALO),
			CFrame.Angles(0, 0, a) * CFrame.new(0, 6.6, 0),
			"halo"
		)
	end
	-- Arms: far too big. Upper arm, forearm, a gold cuff, and a fist like a boulder.
	for _, side in ipairs({ -1, 1 }) do
		local limb = side < 0 and "armL" or "armR"
		local suffix = side < 0 and "L" or "R"
		local shoulder = at(side * 6.6, SHOULDER, 0)
		add("Arm" .. suffix, Vector3.new(3.6, 6, 3.6), D, SLATE, shoulder, at(0, -3, 0), limb)
		add("Forearm" .. suffix, Vector3.new(4.4, 5, 4.4), S, SLATE, shoulder, at(0, -7.6, 0), limb)
		add("Cuff" .. suffix, Vector3.new(4.9, 1.1, 4.9), G, METAL, shoulder, at(0, -9.7, 0), limb)
		add("Fist" .. suffix, Vector3.new(5.6, 5, 5.6), S, SLATE, shoulder, at(0, -12.3, 0), limb)
	end
	-- Legs: short and stubby under all that.
	for _, side in ipairs({ -1, 1 }) do
		local limb = side < 0 and "legL" or "legR"
		local suffix = side < 0 and "L" or "R"
		local hip = at(side * 2.6, HIP, 0)
		add("Leg" .. suffix, Vector3.new(3.8, 5.5, 3.8), D, SLATE, hip, at(0, -2.75, 0), limb)
		add("Foot" .. suffix, Vector3.new(4.8, 1.6, 6), S, SLATE, hip, at(0, -5.7, -0.6), limb)
	end
	return list
end

-- Where each part sits for a held pose (the rider in its boat): arms at `arms` radians (positive is forward
-- and up; 1.1 grips the gunwales, 2.8 is both fists overhead), legs still, halo at `halo` radians.
function GuardianLook.posed(arms, halo)
	local out = {}
	for _, entry in ipairs(GuardianLook.parts()) do
		local rot = CFrame.new()
		if entry.limb == "armL" or entry.limb == "armR" then
			rot = CFrame.Angles(arms or 0, 0, 0)
		elseif entry.limb == "halo" then
			rot = CFrame.Angles(0, 0, halo or 0)
		end
		table.insert(out, {
			name = entry.name,
			size = entry.size,
			color = entry.color,
			material = entry.material,
			shape = entry.shape,
			limb = entry.limb,
			cframe = entry.pivot * rot * entry.hang,
		})
	end
	return out
end

return GuardianLook

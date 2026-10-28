-- Boat cosmetics (V11, Goblin Life): paint (livery), flags and figureheads. Shared: the server dresses real boats
-- (server/BoatStyle.lua) and the shop dresses a copy of a real boat for its preview with this same code.
--
-- Paint recolours the parts V10 gave every player boat (Hull, Prow, Strake, CapRail, Transom, Sail, SailStripe,
-- Yard, MastCap, Mast, Cabin) by role; the first time a boat is painted, each part's own colour is remembered on it,
-- so "Class Colours" puts back exactly what V10 built. Flags and figureheads are new parts in a `BoatCosmetics` folder.
--
-- The contract: nothing here touches the hull's size, mass, collision or physics. Every new part is welded to the
-- hull, massless, non-colliding, never hit by rays and never touched; recolouring changes only Color and Material.
-- A paid or earned boat look is never a hidden upgrade.
local Palette = require(script.Parent:WaitForChild("Palette"))

local BoatLook = {}

local rgb = Color3.fromRGB
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks

local WHITE = rgb(246, 244, 238)
local BLACK = rgb(28, 26, 32)
local GOLD = rgb(255, 200, 60)

BoatLook.FOLDER = "BoatCosmetics"

-- The parts paint can touch, by role.
local ROLES = {
	Hull = "hull",
	Prow = "hull",
	Strake = "stripe",
	CapRail = "trim",
	Transom = "trim",
	Sail = "sail",
	SailStripe = "sailStripe",
	Yard = "trim",
	MastCap = "stripe",
	Mast = "mast",
	Cabin = "cabin",
}

-- Paint jobs: a colour (and optionally a material) per role, plus extra details.
BoatLook.LIVERIES = {
	livery_sunset = {
		hull = rgb(236, 120, 52),
		trim = rgb(150, 60, 40),
		stripe = rgb(222, 48, 140),
		sail = rgb(255, 214, 180),
		sailStripe = rgb(236, 96, 60),
		mast = rgb(120, 60, 40),
		cabin = rgb(236, 150, 90),
	},
	livery_pumpkin = {
		hull = rgb(236, 128, 36),
		trim = rgb(56, 110, 40),
		stripe = rgb(70, 146, 48),
		sail = rgb(250, 236, 200),
		sailStripe = rgb(236, 128, 36),
		mast = rgb(56, 110, 40),
		cabin = rgb(236, 150, 60),
	},
	livery_reef = {
		hull = rgb(52, 190, 196),
		trim = rgb(24, 100, 120),
		stripe = rgb(255, 128, 120),
		sail = rgb(250, 246, 236),
		sailStripe = rgb(255, 128, 120),
		mast = rgb(30, 110, 126),
		cabin = rgb(110, 214, 210),
	},
	livery_shark = {
		hull = rgb(128, 138, 152),
		trim = rgb(66, 74, 88),
		stripe = rgb(232, 234, 238),
		sail = rgb(226, 230, 236),
		sailStripe = rgb(66, 74, 88),
		mast = rgb(66, 74, 88),
		cabin = rgb(150, 158, 170),
	},
	livery_jolly = {
		hull = rgb(34, 32, 38),
		trim = rgb(96, 88, 82),
		stripe = rgb(232, 226, 206),
		sail = rgb(42, 40, 46),
		sailStripe = rgb(232, 226, 206),
		mast = rgb(34, 32, 38),
		cabin = rgb(50, 46, 52),
	},
	livery_royal = {
		hull = rgb(244, 242, 236),
		trim = rgb(214, 160, 40),
		stripe = rgb(230, 176, 48),
		sail = rgb(120, 60, 170),
		sailStripe = rgb(255, 204, 64),
		mast = rgb(244, 242, 236),
		cabin = rgb(236, 232, 224),
		materials = { trim = METAL, stripe = METAL, hull = SMOOTH, cabin = SMOOTH, mast = SMOOTH },
	},
	livery_leviathan = {
		hull = rgb(24, 98, 106),
		trim = rgb(14, 58, 66),
		stripe = rgb(242, 172, 60),
		sail = rgb(40, 122, 130),
		sailStripe = rgb(112, 222, 200),
		mast = rgb(14, 58, 66),
		cabin = rgb(30, 110, 118),
		materials = { hull = SMOOTH, cabin = SMOOTH },
	},
	livery_starlit = {
		hull = rgb(22, 28, 66),
		trim = rgb(190, 198, 216),
		stripe = rgb(206, 214, 240),
		sail = rgb(30, 38, 92),
		sailStripe = rgb(222, 228, 255),
		mast = rgb(22, 28, 66),
		cabin = rgb(34, 42, 86),
		materials = { trim = METAL, stripe = METAL, hull = SMOOTH, cabin = SMOOTH },
	},
	-- V13.3: season rewards (shared/Seasons.lua).
	livery_champion = {
		hull = rgb(150, 28, 34),
		trim = rgb(230, 176, 48),
		stripe = rgb(255, 210, 70),
		sail = rgb(196, 36, 40),
		sailStripe = rgb(255, 214, 90),
		mast = rgb(90, 20, 24),
		cabin = rgb(170, 40, 44),
		materials = { trim = METAL, stripe = METAL, hull = SMOOTH, cabin = SMOOTH },
	},
	livery_legend = { -- V13.4: Pirate Legends' gold tier
		hull = rgb(20, 30, 70),
		trim = rgb(230, 180, 60),
		stripe = rgb(255, 214, 90),
		sail = rgb(28, 40, 96),
		sailStripe = rgb(255, 210, 80),
		mast = rgb(14, 20, 50),
		cabin = rgb(30, 42, 90),
		materials = { trim = METAL, stripe = METAL, hull = SMOOTH, cabin = SMOOTH },
	},
	livery_racer = {
		hull = rgb(246, 244, 238),
		trim = rgb(28, 26, 32),
		stripe = rgb(220, 40, 44),
		sail = rgb(246, 244, 238),
		sailStripe = rgb(28, 26, 32),
		mast = rgb(28, 26, 32),
		cabin = rgb(236, 234, 228),
		materials = { hull = SMOOTH, cabin = SMOOTH },
	},
	livery_voyager = {
		hull = rgb(46, 132, 116),
		trim = rgb(150, 104, 62),
		stripe = rgb(232, 210, 160),
		sail = rgb(232, 214, 168),
		sailStripe = rgb(150, 90, 50),
		mast = rgb(110, 76, 46),
		cabin = rgb(60, 150, 130),
	},
}

-- Making parts ---------------------------------------------------------------------------------------------------------
local function piece(folder, hull, name, shape, size, cf, color, material, transparency)
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
	p.CFrame = hull.CFrame * cf
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function deg(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- Everything the builders need about this boat: its hull, size, bow, the flag part and the sails.
local function frame(model, folder)
	local hull = model:FindFirstChild("Hull")
	local size = hull.Size
	local f = {
		hull = hull,
		folder = folder,
		size = size,
		top = size.Y / 2,
		bow = -size.Z / 2,
		k = size.X / 9, -- 1 on a skiff, about 1.55 on a cutter
		sails = {},
	}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "Flag" then
				f.flag = p
			elseif p.Name == "Sail" then
				table.insert(f.sails, p)
			end
		end
	end
	function f.add(name, shape, sizeV, cf, color, material, transparency)
		return piece(folder, hull, name, shape, sizeV, cf, color, material, transparency)
	end
	-- Relative to another part (a sail, the flag): the cframe is in that part's space.
	function f.addOn(part, name, shape, sizeV, cf, color, material, transparency)
		return piece(
			folder,
			hull,
			name,
			shape,
			sizeV,
			hull.CFrame:ToObjectSpace(part.CFrame * cf),
			color,
			material,
			transparency
		)
	end
	return f
end

-- Paint extras (details a livery adds) -------------------------------------------------------------------------------------
local EXTRAS = {}

EXTRAS.livery_pumpkin = function(f)
	local k = f.k
	f.add(
		"Stalk",
		"cyl",
		Vector3.new(1.6 * k, 0.6 * k, 0.6 * k),
		CFrame.new(0, f.top + 0.6 * k, f.size.Z / 2 + 0.2) * UPRIGHT * deg(0, 0, -15),
		rgb(70, 110, 40),
		WOOD
	)
	f.add(
		"Leaf",
		"egg",
		Vector3.new(1.4 * k, 0.12, 0.8 * k),
		CFrame.new(0.6 * k, f.top + 0.9 * k, f.size.Z / 2 + 0.3) * deg(0, 30, -20),
		rgb(80, 160, 50),
		FABRIC
	)
end

EXTRAS.livery_reef = function(f)
	for _, sail in ipairs(f.sails) do
		for i, at in ipairs({ { 0.25, -0.25 }, { -0.2, 0.2 }, { 0.3, 0.3 } }) do
			for _, side in ipairs({ -1, 1 }) do
				f.addOn(
					sail,
					"Dot" .. i,
					"cyl",
					Vector3.new(0.05, sail.Size.Y * 0.16, sail.Size.Y * 0.16),
					CFrame.new(side * (sail.Size.X / 2 + 0.02), at[1] * sail.Size.Y, at[2] * sail.Size.Z),
					rgb(255, 128, 120),
					FABRIC
				)
			end
		end
	end
end

EXTRAS.livery_shark = function(f)
	local k = f.k
	for _, side in ipairs({ -1, 1 }) do
		local cheek = CFrame.new(side * (f.size.X / 2 - 0.6 * k), 0.1, f.bow + 1.2 * k) * deg(0, side * -27, 0)
		f.add(
			"Mouth",
			"block",
			Vector3.new(0.12, 0.7 * k, 3.4 * k),
			cheek * CFrame.new(side * 0.32, -0.25, 0),
			rgb(120, 30, 40)
		)
		for i = 0, 3 do
			f.add(
				"Tooth",
				"wedge",
				Vector3.new(0.14, 0.42 * k, 0.5 * k),
				cheek * CFrame.new(side * 0.36, 0.0, -1.2 * k + i * 0.8 * k) * deg(180, 0, 0),
				WHITE
			)
		end
		f.add("Eye", "ball", Vector3.new(0.8, 0.8, 0.8) * k, cheek * CFrame.new(side * 0.25, 0.75 * k, -0.6 * k), WHITE)
		f.add(
			"Pupil",
			"ball",
			Vector3.new(0.42, 0.42, 0.42) * k,
			cheek * CFrame.new(side * 0.55, 0.75 * k, -0.75 * k),
			BLACK
		)
	end
end

EXTRAS.livery_jolly = function(f)
	for _, sail in ipairs(f.sails) do
		for _, side in ipairs({ -1, 1 }) do
			local face = CFrame.new(side * (sail.Size.X / 2 + 0.04), -sail.Size.Y * 0.08, 0)
			local r = sail.Size.Y * 0.3
			f.addOn(sail, "Skull", "egg", Vector3.new(0.06, r, r * 0.95), face, WHITE, FABRIC)
			f.addOn(
				sail,
				"Jaw",
				"block",
				Vector3.new(0.06, r * 0.28, r * 0.55),
				face * CFrame.new(0, -r * 0.5, 0),
				WHITE,
				FABRIC
			)
			for _, z in ipairs({ -1, 1 }) do
				f.addOn(
					sail,
					"SkullEye",
					"egg",
					Vector3.new(0.08, r * 0.24, r * 0.22),
					face * CFrame.new(side * 0.01, r * 0.05, z * r * 0.2),
					BLACK,
					FABRIC
				)
				f.addOn(
					sail,
					"Bone",
					"block",
					Vector3.new(0.05, r * 0.14, r * 1.5),
					face * CFrame.new(0, -r * 0.62, 0) * deg(z * 35, 0, 0),
					WHITE,
					FABRIC
				)
			end
		end
	end
end

EXTRAS.livery_leviathan = function(f)
	local k = f.k
	for _, side in ipairs({ -1, 1 }) do
		local cheek = CFrame.new(side * (f.size.X / 2 - 0.5 * k), 0.4, f.bow + 1.6 * k) * deg(0, side * -27, 0)
		f.add(
			"Eye",
			"egg",
			Vector3.new(0.3, 0.9 * k, 1.3 * k),
			cheek * CFrame.new(side * 0.3, 0, 0),
			rgb(255, 176, 50),
			NEON
		)
		f.add("Slit", "block", Vector3.new(0.34, 0.75 * k, 0.16 * k), cheek * CFrame.new(side * 0.36, 0, 0), BLACK)
		for i = 0, 3 do
			f.add(
				"Scale",
				"egg",
				Vector3.new(0.2, 1.0 * k, 1.6 * k),
				CFrame.new(side * (f.size.X / 2 + 0.05), -0.1 + (i % 2) * 0.35, -f.size.Z * 0.15 + i * f.size.Z * 0.12),
				rgb(14, 66, 74),
				SMOOTH
			)
		end
	end
	for _, sail in ipairs(f.sails) do
		f.addOn(
			sail,
			"Fin",
			"wedge",
			Vector3.new(0.12, sail.Size.Y * 0.35, sail.Size.Z * 0.6),
			CFrame.new(0, sail.Size.Y * 0.62, 0.1 * sail.Size.Z),
			rgb(112, 222, 200),
			FABRIC
		)
	end
end

EXTRAS.livery_starlit = function(f)
	local spots = {
		{ 0.48, 0.1, -0.3 },
		{ 0.5, -0.1, 0.05 },
		{ 0.49, 0.15, 0.3 },
		{ -0.48, 0.05, -0.2 },
		{ -0.5, -0.12, 0.15 },
		{ -0.49, 0.12, 0.38 },
	}
	for i, s in ipairs(spots) do
		f.add(
			"Star" .. i,
			"ball",
			Vector3.new(0.35, 0.35, 0.35) * f.k,
			CFrame.new(s[1] * f.size.X + math.sign(s[1]) * 0.1, s[2] * f.size.Y, s[3] * f.size.Z),
			i % 2 == 0 and rgb(255, 236, 160) or WHITE,
			NEON
		)
	end
	for _, sail in ipairs(f.sails) do
		for i, at in ipairs({ { 0.3, -0.25 }, { 0.05, 0.3 }, { -0.28, -0.05 } }) do
			f.addOn(
				sail,
				"SailStar" .. i,
				"ball",
				Vector3.new(0.3, 0.3, 0.3) * f.k,
				CFrame.new(0, at[1] * sail.Size.Y, at[2] * sail.Size.Z),
				WHITE,
				NEON
			)
		end
	end
end

-- V13.3: a gold laurel on each sail of the Champion's Sails, and chequers down the Racer's sides.
EXTRAS.livery_champion = function(f)
	for _, sail in ipairs(f.sails) do
		for _, side in ipairs({ -1, 1 }) do
			local face = CFrame.new(side * (sail.Size.X / 2 + 0.04), 0, 0)
			for i = 0, 4 do
				local a = math.rad(-70 + i * 35)
				for _, arm in ipairs({ -1, 1 }) do
					f.addOn(
						sail,
						"Laurel",
						"egg",
						Vector3.new(0.06, sail.Size.Y * 0.1, sail.Size.Z * 0.07),
						face
							* CFrame.new(
								0,
								-math.cos(a) * sail.Size.Y * 0.22,
								arm * math.sin(math.abs(a)) * sail.Size.Z * 0.22
							)
							* deg(arm * (20 + i * 12), 0, 0),
						GOLD,
						FABRIC
					)
				end
			end
		end
	end
end

EXTRAS.livery_racer = function(f)
	local k = f.k
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 5 do
			f.add(
				"Check",
				"block",
				Vector3.new(0.08, 0.7 * k, 1.1 * k),
				CFrame.new(
					side * (f.size.X / 2 + 0.05),
					(i % 2 == 0) and 0.35 * k or -0.35 * k,
					-f.size.Z * 0.3 + i * 1.1 * k
				),
				BLACK,
				SMOOTH
			)
		end
	end
end

-- Flags (built round the boat's own Flag part, which they replace) --------------------------------------------------------------
local FLAGS = {}

-- V13.3: season pennants.
FLAGS.flag_leader = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	f.addOn(flag, "Banner", "block", Vector3.new(flag.Size.X, h, w * 0.7), CFrame.new(0, 0, -w * 0.15), GOLD, FABRIC)
	for _, y in ipairs({ -1, 1 }) do
		f.addOn(
			flag,
			"Tail",
			"wedge",
			Vector3.new(flag.Size.X, h / 2, w * 0.3),
			CFrame.new(0, y * h / 4, w * 0.35) * deg(y > 0 and 180 or 0, 0, 0),
			GOLD,
			FABRIC
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		local face = CFrame.new(side * (flag.Size.X / 2 + 0.04), 0, -w * 0.15)
		for i = 0, 3 do
			f.addOn(
				flag,
				"Leaf",
				"egg",
				Vector3.new(0.05, h * 0.14, w * 0.1),
				face * CFrame.new(0, -h * 0.25 + i * h * 0.16, -w * 0.12) * deg(30, 0, 0),
				rgb(70, 140, 60),
				FABRIC
			)
			f.addOn(
				flag,
				"Leaf",
				"egg",
				Vector3.new(0.05, h * 0.14, w * 0.1),
				face * CFrame.new(0, -h * 0.25 + i * h * 0.16, w * 0.12) * deg(-30, 0, 0),
				rgb(70, 140, 60),
				FABRIC
			)
		end
	end
	return true
end

-- V13.4: the weekly Pirate Championship's top ten: crimson with a gold band and three gold stars (the best three
-- raids) on both faces.
FLAGS.flag_champion = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	f.addOn(flag, "Banner", "block", Vector3.new(flag.Size.X, h, w), CFrame.new(), rgb(170, 30, 40), FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		local face = CFrame.new(side * (flag.Size.X / 2 + 0.04), 0, 0)
		f.addOn(flag, "Band", "block", Vector3.new(0.05, h * 0.14, w), face * CFrame.new(0, -h * 0.28, 0), GOLD, FABRIC)
		for i = -1, 1 do
			f.addOn(
				flag,
				"Star",
				"egg",
				Vector3.new(0.05, h * 0.18, h * 0.18),
				face * CFrame.new(0, h * 0.12, i * w * 0.26),
				GOLD,
				FABRIC
			)
		end
	end
	return true
end

FLAGS.flag_burgee = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	for row = 0, 1 do
		f.addOn(
			flag,
			"Check",
			"block",
			Vector3.new(flag.Size.X, h / 2, w * 0.3),
			CFrame.new(0, (row - 0.5) * h / 2, -w * 0.35),
			row == 0 and WHITE or BLACK,
			FABRIC
		)
		f.addOn(
			flag,
			"Check",
			"block",
			Vector3.new(flag.Size.X, h / 2, w * 0.3),
			CFrame.new(0, (row - 0.5) * h / 2, -w * 0.05),
			row == 0 and BLACK or WHITE,
			FABRIC
		)
	end
	f.addOn(
		flag,
		"Point",
		"wedge",
		Vector3.new(flag.Size.X, h, w * 0.42),
		CFrame.new(0, 0, w * 0.31) * deg(180, 0, 0),
		rgb(220, 40, 44),
		FABRIC
	)
	return true
end

FLAGS.flag_questor = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	f.addOn(
		flag,
		"Pennant",
		"wedge",
		Vector3.new(flag.Size.X, h * 0.8, w * 1.5),
		CFrame.new(0, 0, w * 0.25),
		rgb(60, 110, 200),
		FABRIC
	)
	for _, side in ipairs({ -1, 1 }) do
		f.addOn(
			flag,
			"Seal",
			"cyl",
			Vector3.new(0.08, h * 0.42, h * 0.42),
			CFrame.new(side * (flag.Size.X / 2 + 0.05), 0, -w * 0.3) * CFrame.Angles(0, 0, 0),
			GOLD,
			METAL
		)
	end
	return true
end

-- The default keeps each boat's coloured flag (the colours tell boats apart) and adds a skull to it.
FLAGS.flag_jolly = function(f)
	local flag = f.flag
	local h = flag.Size.Y
	for _, side in ipairs({ -1, 1 }) do
		local face = CFrame.new(side * (flag.Size.X / 2 + 0.03), h * 0.08, 0)
		f.addOn(flag, "Skull", "egg", Vector3.new(0.05, h * 0.36, h * 0.34), face, WHITE, FABRIC)
		for _, z in ipairs({ -1, 1 }) do
			f.addOn(
				flag,
				"SkullEye",
				"egg",
				Vector3.new(0.07, h * 0.09, h * 0.08),
				face * CFrame.new(side * 0.01, h * 0.02, z * h * 0.07),
				BLACK,
				FABRIC
			)
			f.addOn(
				flag,
				"Bone",
				"block",
				Vector3.new(0.05, h * 0.06, h * 0.62),
				face * CFrame.new(0, -h * 0.22, 0) * deg(z * 30, 0, 0),
				WHITE,
				FABRIC
			)
		end
	end
	return false -- the boat's own flag stays
end

FLAGS.flag_checker = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	for row = 0, 1 do
		for col = 0, 2 do
			local color = (row + col) % 2 == 0 and WHITE or BLACK
			f.addOn(
				flag,
				"Check",
				"block",
				Vector3.new(flag.Size.X, h / 2, w / 3),
				CFrame.new(0, (row - 0.5) * h / 2, (col - 1) * w / 3),
				color,
				FABRIC
			)
		end
	end
	return true
end

FLAGS.flag_fish = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	local colors = { rgb(226, 60, 50), WHITE, rgb(60, 110, 220) }
	for i = 0, 2 do
		f.addOn(
			flag,
			"Sock" .. i,
			"cyl",
			Vector3.new(w / 3 + 0.05, h * (0.75 - i * 0.12), h * (0.75 - i * 0.12)),
			CFrame.new(0, 0, (i - 1) * w / 3) * CFrame.Angles(0, math.rad(90), 0),
			colors[i + 1],
			FABRIC
		)
	end
	f.addOn(
		flag,
		"FishEye",
		"ball",
		Vector3.new(0.3, 0.3, 0.3) * f.k,
		CFrame.new(h * 0.3, h * 0.12, -w / 2 + 0.3),
		BLACK
	)
	f.addOn(
		flag,
		"FishEyeR",
		"ball",
		Vector3.new(0.3, 0.3, 0.3) * f.k,
		CFrame.new(-h * 0.3, h * 0.12, -w / 2 + 0.3),
		BLACK
	)
	f.addOn(
		flag,
		"FishTail",
		"wedge",
		Vector3.new(0.1, h * 0.8, w * 0.3),
		CFrame.new(0, 0, w / 2 + w * 0.15) * deg(0, 0, 0),
		colors[3],
		FABRIC
	)
	return true
end

FLAGS.flag_crown = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	local purple = rgb(110, 44, 150)
	f.addOn(flag, "Banner", "block", Vector3.new(flag.Size.X, h, w * 0.7), CFrame.new(0, 0, -w * 0.15), purple, FABRIC)
	for _, y in ipairs({ -1, 1 }) do
		f.addOn(
			flag,
			"Tail",
			"wedge",
			Vector3.new(flag.Size.X, h / 2, w * 0.3),
			CFrame.new(0, y * h / 4, w * 0.35) * deg(y > 0 and 180 or 0, 0, 0),
			purple,
			FABRIC
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		local face = CFrame.new(side * (flag.Size.X / 2 + 0.04), 0, -w * 0.15)
		f.addOn(
			flag,
			"CrownBand",
			"block",
			Vector3.new(0.06, h * 0.16, w * 0.32),
			face * CFrame.new(0, -h * 0.12, 0),
			GOLD,
			METAL
		)
		for i = -1, 1 do
			f.addOn(
				flag,
				"CrownPoint",
				"wedge",
				Vector3.new(0.06, h * 0.22, w * 0.09),
				face * CFrame.new(0, h * 0.06, i * w * 0.11),
				GOLD,
				METAL
			)
		end
	end
	return true
end

FLAGS.flag_ghost = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	local ghost = Palette.GHOST
	for _, y in ipairs({ -1, 1 }) do
		f.addOn(
			flag,
			"Pennant",
			"wedge",
			Vector3.new(flag.Size.X, h / 2, w * 1.9),
			CFrame.new(0, y * h / 4, w * 0.45) * deg(y > 0 and 180 or 0, 0, 0),
			ghost:Lerp(rgb(40, 80, 90), 0.3),
			FABRIC,
			0.25
		)
	end
	f.addOn(
		flag,
		"Edge",
		"block",
		Vector3.new(flag.Size.X + 0.05, 0.12, w * 1.9),
		CFrame.new(0, 0, w * 0.45),
		ghost,
		NEON,
		0.2
	)
	return true
end

FLAGS.flag_map = function(f)
	local flag = f.flag
	local w, h = flag.Size.Z, flag.Size.Y
	f.addOn(flag, "Chart", "block", Vector3.new(flag.Size.X, h, w), CFrame.new(), rgb(232, 210, 160), FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		local face = CFrame.new(side * (flag.Size.X / 2 + 0.03), 0, 0)
		for _, r in ipairs({ 45, -45 }) do
			f.addOn(
				flag,
				"Cross",
				"block",
				Vector3.new(0.05, h * 0.08, h * 0.42),
				face * CFrame.new(0, -h * 0.15, w * 0.25) * deg(r, 0, 0),
				rgb(200, 40, 40),
				FABRIC
			)
		end
		for i = 0, 2 do
			f.addOn(
				flag,
				"Path",
				"block",
				Vector3.new(0.05, h * 0.05, w * 0.1),
				face * CFrame.new(0, h * (0.25 - i * 0.12), -w * 0.3 + i * w * 0.16),
				rgb(90, 60, 40),
				FABRIC
			)
		end
	end
	return true
end

-- Figureheads (at the bow, leaning out) ---------------------------------------------------------------------------------------
local FIGUREHEADS = {}

local function bowFrame(f)
	return CFrame.new(0, f.top - 0.1, f.bow - 2.6 * f.k) * deg(-20, 0, 0)
end

FIGUREHEADS.fig_goblin = function(f)
	local k, at = f.k, bowFrame(f)
	local wood = rgb(186, 134, 82)
	f.add("BustBody", "egg", Vector3.new(1.4, 2.0, 1.2) * k, at, wood, WOOD)
	f.add("BustHead", "ball", Vector3.new(1.3, 1.3, 1.3) * k, at * CFrame.new(0, 1.35 * k, -0.25 * k), wood, WOOD)
	f.add("BustNose", "egg", Vector3.new(0.45, 0.45, 0.8) * k, at * CFrame.new(0, 1.3 * k, -0.95 * k), wood, WOOD)
	for _, side in ipairs({ -1, 1 }) do
		f.add(
			"BustEar",
			"wedge",
			Vector3.new(0.22, 0.6, 1.3) * k,
			at * CFrame.new(side * 0.85 * k, 1.5 * k, 0) * deg(0, side * -20 + 180, side * -62),
			wood,
			WOOD
		)
		f.add(
			"BustEye",
			"ball",
			Vector3.new(0.2, 0.2, 0.2) * k,
			at * CFrame.new(side * 0.28 * k, 1.5 * k, -0.6 * k),
			rgb(60, 40, 30)
		)
	end
end

FIGUREHEADS.fig_duck = function(f)
	local k, at = f.k, bowFrame(f) * deg(20, 0, 0)
	local yellow = rgb(255, 214, 40)
	f.add("DuckBody", "egg", Vector3.new(1.9, 1.5, 2.3) * k, at * CFrame.new(0, 0.4 * k, 0), yellow)
	f.add("DuckHead", "ball", Vector3.new(1.4, 1.4, 1.4) * k, at * CFrame.new(0, 1.6 * k, -0.6 * k), yellow)
	f.add(
		"DuckBill",
		"egg",
		Vector3.new(0.9, 0.35, 0.9) * k,
		at * CFrame.new(0, 1.45 * k, -1.35 * k),
		rgb(255, 130, 30)
	)
	f.add("DuckTail", "wedge", Vector3.new(0.5, 0.7, 0.7) * k, at * CFrame.new(0, 0.9 * k, 1.2 * k), yellow)
	for _, side in ipairs({ -1, 1 }) do
		f.add(
			"DuckEye",
			"ball",
			Vector3.new(0.24, 0.24, 0.24) * k,
			at * CFrame.new(side * 0.45 * k, 1.85 * k, -1.0 * k),
			BLACK
		)
	end
end

FIGUREHEADS.fig_dragon = function(f)
	local k, at = f.k, bowFrame(f)
	local green, belly = rgb(52, 150, 84), rgb(214, 200, 120)
	f.add("Neck", "egg", Vector3.new(1.0, 2.6, 1.0) * k, at * CFrame.new(0, 0.6 * k, 0), green)
	f.add("Head", "egg", Vector3.new(1.3, 1.1, 2.0) * k, at * CFrame.new(0, 1.9 * k, -0.6 * k), green)
	f.add("Snout", "egg", Vector3.new(0.9, 0.7, 1.3) * k, at * CFrame.new(0, 1.75 * k, -1.6 * k), green)
	f.add("Jaw", "egg", Vector3.new(0.8, 0.35, 1.2) * k, at * CFrame.new(0, 1.35 * k, -1.4 * k), belly)
	for _, side in ipairs({ -1, 1 }) do
		f.add(
			"Eye",
			"ball",
			Vector3.new(0.3, 0.3, 0.3) * k,
			at * CFrame.new(side * 0.5 * k, 2.15 * k, -0.95 * k),
			rgb(255, 214, 60),
			NEON
		)
		f.add(
			"Horn",
			"wedge",
			Vector3.new(0.2, 0.5, 1.2) * k,
			at * CFrame.new(side * 0.4 * k, 2.55 * k, 0.1 * k) * deg(20, 0, 0),
			rgb(236, 226, 196)
		)
		f.add(
			"Frill",
			"wedge",
			Vector3.new(0.12, 0.9, 1.0) * k,
			at * CFrame.new(side * 0.7 * k, 1.9 * k, 0.2 * k) * deg(0, side * 30, 0),
			rgb(220, 70, 50),
			FABRIC
		)
	end
end

FIGUREHEADS.fig_idol = function(f)
	local k, at = f.k, bowFrame(f)
	local gold, deep = rgb(255, 196, 46), rgb(214, 150, 40)
	f.add("IdolBelly", "ball", Vector3.new(1.6, 1.6, 1.6) * k, at, gold, METAL).Reflectance = 0.2
	f.add("IdolHead", "ball", Vector3.new(1.3, 1.3, 1.3) * k, at * CFrame.new(0, 1.3 * k, -0.1 * k), gold, METAL).Reflectance =
		0.2
	f.add(
		"IdolCrown",
		"cyl",
		Vector3.new(0.4, 1.1, 1.1) * k,
		at * CFrame.new(0, 2.05 * k, -0.1 * k) * UPRIGHT,
		deep,
		METAL
	)
	for _, side in ipairs({ -1, 1 }) do
		f.add(
			"IdolArm",
			"egg",
			Vector3.new(1.4, 0.4, 0.4) * k,
			at * CFrame.new(side * 1.1 * k, 0.6 * k, -0.2 * k) * deg(0, 0, side * 30),
			gold,
			METAL
		)
		f.add(
			"IdolEar",
			"wedge",
			Vector3.new(0.2, 0.5, 1.0) * k,
			at * CFrame.new(side * 0.75 * k, 1.45 * k, 0) * deg(0, side * -20 + 180, side * -62),
			gold,
			METAL
		)
		f.add(
			"IdolEye",
			"block",
			Vector3.new(0.25, 0.18, 0.15) * k,
			at * CFrame.new(side * 0.25 * k, 1.4 * k, -0.62 * k),
			rgb(255, 40, 60),
			NEON
		)
	end
end

BoatLook.EXTRAS = EXTRAS
BoatLook.FLAGS = FLAGS
BoatLook.FIGUREHEADS = FIGUREHEADS

-- Applying ---------------------------------------------------------------------------------------------------------------
-- Remembers a part's own colour and material the first time it is painted.
local function remember(p)
	if p:GetAttribute("GLColor") == nil then
		p:SetAttribute("GLColor", p.Color)
		p:SetAttribute("GLMat", p.Material.Name)
	end
end

local function restore(p)
	local color = p:GetAttribute("GLColor")
	if color ~= nil then
		p.Color = color
		p.Material = Enum.Material[p:GetAttribute("GLMat")] or p.Material
	end
end

-- Dresses a player boat in a look (a Catalog look table: livery, flag, figurehead). Returns true if anything changed.
-- Never call it on the Navy's or anyone else's AI ships (server/BoatStyle.lua checks).
function BoatLook.apply(model, look)
	local hull = model:FindFirstChild("Hull")
	if not hull then
		return false
	end
	look = look or {}
	local livery = look.livery or "livery_classic"
	local flagId = look.flag or "flag_jolly"
	local figure = look.figurehead
	local sig = livery .. "|" .. flagId .. "|" .. (figure or "-")
	if model:GetAttribute("StyleSig") == sig and model:FindFirstChild(BoatLook.FOLDER) then
		return false
	end
	model:SetAttribute("StyleSig", sig)
	local paint = BoatLook.LIVERIES[livery]
	for _, p in ipairs(model:GetChildren()) do
		local role = p:IsA("BasePart") and ROLES[p.Name]
		if role then
			remember(p)
			if paint and paint[role] then
				p.Color = paint[role]
				local material = paint.materials and paint.materials[role]
				if material then
					p.Material = material
				elseif role ~= "hull" then
					p.Material = Enum.Material[p:GetAttribute("GLMat")] or p.Material
				else
					p.Material = PLANKS
				end
			else
				restore(p)
			end
		end
	end
	local old = model:FindFirstChild(BoatLook.FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = BoatLook.FOLDER
	local f = frame(model, folder)
	if EXTRAS[livery] then
		local ok, err = pcall(EXTRAS[livery], f)
		if not ok then
			warn("[BoatLook] " .. livery .. ": " .. tostring(err))
		end
	end
	if f.flag then
		local stored = f.flag:GetAttribute("GLFlagT")
		if stored == nil then
			f.flag:SetAttribute("GLFlagT", f.flag.Transparency)
			stored = f.flag.Transparency
		end
		local build = FLAGS[flagId] or FLAGS.flag_jolly
		local ok, replaces = pcall(build, f)
		if not ok then
			warn("[BoatLook] " .. flagId .. ": " .. tostring(replaces))
			replaces = false
		end
		f.flag.Transparency = replaces and 1 or stored
	end
	if figure and FIGUREHEADS[figure] then
		local ok, err = pcall(FIGUREHEADS[figure], f)
		if not ok then
			warn("[BoatLook] " .. figure .. ": " .. tostring(err))
		end
	end
	folder.Parent = model
	return true
end

-- Does every boat item in the catalogue have a look here? (The tests ask.)
function BoatLook.covers(item)
	if item.slot == "livery" then
		return item.id == "livery_classic" or BoatLook.LIVERIES[item.id] ~= nil
	elseif item.slot == "flag" then
		return FLAGS[item.id] ~= nil
	elseif item.slot == "figurehead" then
		return FIGUREHEADS[item.id] ~= nil
	end
	return false
end

return BoatLook

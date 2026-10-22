-- What each boat class LOOKS like (V13; the Skiff, Cutter and patrol ship are V10's, moved here unchanged). One
-- builder per class adds welded, massless, non-colliding detail to the hull part BoatSim drives, so a class's look
-- never changes its physics: that is Config.BOAT_TYPES's job.
--
-- Names matter. shared/BoatLook.lua recolours parts by name (Hull, Prow, Strake, CapRail, Transom, Sail, SailStripe,
-- Yard, MastCap, Mast, Cabin), so a goblin's paint job dresses every class; a part called Flag carries their flag.
-- Anything with another name keeps the class's own colours (the Reefhopper's spring, the Ironbelly's rivets), which is
-- what keeps a class recognisable under any paint.
--
-- Silhouettes, at a glance across the water:
--   Skiff        one mast, a little sail                          Cutter       two masts, a cabin, a bow gun
--   Reefhopper   twin pontoons, a gold spring on the stern, a fin  Broadside    two square-rigged masts, gun ports
--   Stormrunner  one tall lightning-bolt sail, a spinning vane     Wraith       low and narrow, glowing ghost sails
--   Ironbelly    no sails: an iron ram, a smoking funnel, tyres
--   Anchorjack   an iron anchor at the bow, a capstan, a gaff sail   Wavebreaker  a curling wave plough, round sails
--   Corsair      black hull, blood-red sails, a harpoon on the bow (V13.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Palette"))

local BoatModels = {}

local rgb = Color3.fromRGB
local PLANKS, WOOD, FABRIC, METAL, NEON, SMOOTH, GLASS =
	Enum.Material.WoodPlanks,
	Enum.Material.Wood,
	Enum.Material.Fabric,
	Enum.Material.Metal,
	Enum.Material.Neon,
	Enum.Material.SmoothPlastic,
	Enum.Material.Glass

-- The class colours for the new boats (V10's skiff, cutter and navy live in Palette.BOATS).
BoatModels.LIVERY = {
	reefhopper = {
		hull = rgb(255, 150, 96),
		trim = rgb(150, 70, 50),
		stripe = rgb(64, 214, 200),
		sail = rgb(255, 244, 222),
		sailStripe = rgb(64, 214, 200),
	},
	broadside = {
		hull = rgb(120, 52, 40),
		trim = rgb(60, 30, 24),
		stripe = rgb(255, 196, 46),
		sail = rgb(240, 228, 200),
		sailStripe = rgb(176, 40, 40),
	},
	stormrunner = {
		hull = rgb(78, 102, 140),
		trim = rgb(40, 52, 76),
		stripe = rgb(255, 226, 64),
		sail = rgb(196, 208, 226),
		sailStripe = rgb(255, 226, 64),
	},
	wraith = {
		hull = rgb(40, 44, 54),
		trim = rgb(24, 26, 32),
		stripe = rgb(110, 255, 210),
		sail = rgb(196, 255, 236),
		sailStripe = rgb(110, 255, 210),
	},
	ironbelly = {
		hull = rgb(120, 118, 116),
		trim = rgb(70, 66, 64),
		stripe = rgb(255, 200, 40),
		sail = rgb(230, 230, 230),
		sailStripe = rgb(40, 38, 40),
	},
	-- V13.2
	anchorjack = {
		hull = rgb(48, 112, 104),
		trim = rgb(150, 76, 40),
		stripe = rgb(240, 200, 120),
		sail = rgb(236, 220, 186),
		sailStripe = rgb(150, 76, 40),
	},
	wavebreaker = {
		hull = rgb(36, 96, 170),
		trim = rgb(230, 244, 255),
		stripe = rgb(120, 220, 255),
		sail = rgb(236, 246, 255),
		sailStripe = rgb(36, 96, 170),
	},
	corsair = {
		hull = rgb(34, 30, 36),
		trim = rgb(150, 30, 34),
		stripe = rgb(230, 190, 80),
		sail = rgb(170, 30, 36),
		sailStripe = rgb(24, 22, 26),
	},
}

function BoatModels.livery(typeName)
	return BoatModels.LIVERY[typeName] or Palette.BOATS[typeName] or Palette.BOATS.default
end

-- A welded decoration part. opts: shape ("ball", "cyl", "wedge", "egg"), transparency, shadow
local function add(model, hull, name, size, offset, color, material, opts)
	opts = opts or {}
	local p = Instance.new(opts.shape == "wedge" and "WedgePart" or "Part")
	if opts.shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif opts.shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif opts.shape == "egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or WOOD
	p.Transparency = opts.transparency or 0
	p.CFrame = hull.CFrame * offset
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = opts.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end
BoatModels.add = add

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis along the hull (Z)

-- Shared by every player class: a pointed prow, a stripe and a cap rail each side, a transom, a bow lantern.
local function common(model, hull, size, look, prowWidth)
	local top, bow = size.Y / 2, -size.Z / 2
	for _, side in ipairs({ -1, 1 }) do
		add(
			model,
			hull,
			"Prow",
			Vector3.new(size.X * (prowWidth or 0.62), size.Y * 0.9, size.Z * 0.3),
			CFrame.new(side * size.X * 0.2, -0.1, bow - size.Z * 0.08) * CFrame.Angles(0, -side * math.rad(27), 0),
			look.hull,
			PLANKS
		)
		add(
			model,
			hull,
			"Strake",
			Vector3.new(0.35, size.Y * 0.36, size.Z * 0.78),
			CFrame.new(side * (size.X / 2 + 0.12), top * 0.2, size.Z * 0.05),
			look.stripe,
			SMOOTH
		)
		add(
			model,
			hull,
			"CapRail",
			Vector3.new(0.7, 0.45, size.Z * 0.8),
			CFrame.new(side * (size.X / 2 - 0.2), top + 0.2, size.Z * 0.04),
			look.trim,
			WOOD
		)
	end
	add(
		model,
		hull,
		"Transom",
		Vector3.new(size.X + 0.3, size.Y * 0.9, 0.5),
		CFrame.new(0, 0.05, size.Z / 2 + 0.1),
		look.trim,
		PLANKS
	)
	local lamp = add(
		model,
		hull,
		"BowLamp",
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(0, top + 0.9, bow - size.Z * 0.12),
		rgb(255, 214, 120),
		NEON,
		{ shape = "ball" }
	)
	return lamp
end

-- Class builders ------------------------------------------------------------------------------------------------------
local BUILD = {}

BUILD.skiff = function(model, hull, size, look, trim)
	common(model, hull, size, look)
	local top = size.Y / 2
	add(model, hull, "Mast", Vector3.new(0.7, 12, 0.7), CFrame.new(0, top + 6, -2), rgb(88, 58, 36))
	add(model, hull, "Sail", Vector3.new(0.25, 8.5, 7), CFrame.new(0, top + 7, 1.2), rgb(240, 235, 215), FABRIC)
	add(model, hull, "Flag", Vector3.new(0.3, 2.4, 3.6), CFrame.new(0, top + 12.4, -0.2), trim, FABRIC)
end

BUILD.cutter = function(model, hull, size, look, trim)
	common(model, hull, size, look)
	local top = size.Y / 2
	for _, z in ipairs({ -6, 6 }) do
		add(model, hull, "Mast", Vector3.new(0.9, 18, 0.9), CFrame.new(0, top + 9, z), rgb(88, 58, 36))
		add(model, hull, "Sail", Vector3.new(0.3, 12, 10), CFrame.new(0, top + 10, z + 0.6), rgb(240, 235, 215), FABRIC)
	end
	add(model, hull, "Flag", Vector3.new(0.3, 3, 5), CFrame.new(0, top + 18.5, -6), trim, FABRIC)
	add(model, hull, "Cabin", Vector3.new(8, 3, 7), CFrame.new(0, top + 1.5, size.Z / 2 - 5), look.hull, PLANKS)
end

-- Reefhopper: a stubby stunt boat on twin pontoons, with a big gold spring at the stern and a dorsal fin.
BUILD.reefhopper = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.5)
	local top = size.Y / 2
	for _, side in ipairs({ -1, 1 }) do
		-- Outrigger pontoons on two struts.
		local x = side * (size.X / 2 + 2.6)
		add(
			model,
			hull,
			"Pontoon",
			Vector3.new(2.4, 2.2, size.Z * 0.95),
			CFrame.new(x, -0.4, 0),
			look.stripe,
			SMOOTH,
			{ shape = "egg" }
		)
		add(
			model,
			hull,
			"PontoonTip",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(x, -0.2, -size.Z * 0.47),
			look.trim,
			SMOOTH,
			{ shape = "ball" }
		)
		for _, z in ipairs({ -size.Z * 0.25, size.Z * 0.25 }) do
			add(
				model,
				hull,
				"Strut",
				Vector3.new(3.4, 0.5, 0.8),
				CFrame.new(side * (size.X / 2 + 1.2), top * 0.4, z),
				look.trim,
				WOOD
			)
		end
	end
	-- The spring: gold coils on the stern deck.
	for i = 0, 4 do
		add(
			model,
			hull,
			"SpringCoil",
			Vector3.new(0.45, 3.2, 3.2),
			CFrame.new(0, top + 0.4 + i * 0.55, size.Z / 2 - 2.6) * UPRIGHT,
			rgb(255, 200, 60),
			METAL,
			{ shape = "cyl", transparency = 0 }
		)
	end
	add(
		model,
		hull,
		"SpringCap",
		Vector3.new(3.4, 0.5, 3.4),
		CFrame.new(0, top + 3.3, size.Z / 2 - 2.6),
		look.stripe,
		SMOOTH
	)
	-- A dorsal fin in the class's teal, and a small triangular sail on a short mast.
	add(
		model,
		hull,
		"Fin",
		Vector3.new(0.4, 3, 5),
		CFrame.new(0, top + 1.5, 1.5) * CFrame.Angles(0, math.rad(180), 0),
		look.stripe,
		SMOOTH,
		{ shape = "wedge" }
	)
	add(model, hull, "Mast", Vector3.new(0.6, 8, 0.6), CFrame.new(0, top + 4, -2.6), rgb(150, 70, 50))
	add(
		model,
		hull,
		"Sail",
		Vector3.new(0.25, 5.4, 4.6),
		CFrame.new(0, top + 4.6, -1.0),
		rgb(255, 244, 222),
		FABRIC,
		{ shape = "wedge" }
	)
	add(model, hull, "Flag", Vector3.new(0.3, 1.8, 2.8), CFrame.new(0, top + 8.6, -2.6), trim, FABRIC)
end

-- Broadside: a chunky gunboat with high bulwarks, gun ports down both sides, two square-rigged masts and a raised
-- quarterdeck. (Its two working cannons are mounted by server/Cannons.lua; these are the painted ports.)
BUILD.broadside = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.7)
	local top = size.Y / 2
	for _, side in ipairs({ -1, 1 }) do
		add(
			model,
			hull,
			"Bulwark",
			Vector3.new(0.6, 2.2, size.Z * 0.82),
			CFrame.new(side * (size.X / 2 - 0.1), top + 1.1, size.Z * 0.02),
			look.trim,
			PLANKS
		)
		for i = -2, 2 do
			local port = add(
				model,
				hull,
				"GunPort",
				Vector3.new(0.3, 1.1, 1.6),
				CFrame.new(side * (size.X / 2 + 0.22), top * 0.35, i * size.Z * 0.15),
				rgb(24, 22, 26),
				SMOOTH
			)
			port.CastShadow = false
			add(
				model,
				hull,
				"PortRim",
				Vector3.new(0.25, 1.4, 1.9),
				CFrame.new(side * (size.X / 2 + 0.18), top * 0.35, i * size.Z * 0.15),
				look.stripe,
				METAL
			)
		end
		-- Iron bands round the hull.
		for _, z in ipairs({ -size.Z * 0.3, 0, size.Z * 0.3 }) do
			add(
				model,
				hull,
				"IronBand",
				Vector3.new(0.3, size.Y * 0.9, 0.7),
				CFrame.new(side * (size.X / 2 + 0.25), 0, z),
				Palette.IRON,
				METAL
			)
		end
	end
	for i, z in ipairs({ -9, 6 }) do
		local height = i == 1 and 22 or 26
		add(model, hull, "Mast", Vector3.new(1.1, height, 1.1), CFrame.new(0, top + height / 2, z), rgb(70, 44, 30))
		add(
			model,
			hull,
			"Sail",
			Vector3.new(0.35, height * 0.55, size.X * 1.1),
			CFrame.new(0, top + height * 0.55, z + 0.8) * CFrame.Angles(0, math.rad(90), 0),
			rgb(240, 228, 200),
			FABRIC
		)
	end
	add(model, hull, "Flag", Vector3.new(0.3, 3.2, 5.2), CFrame.new(0, top + 27.8, 6), trim, FABRIC)
	add(
		model,
		hull,
		"Cabin",
		Vector3.new(size.X - 2, 4, 9),
		CFrame.new(0, top + 2, size.Z / 2 - 5.5),
		look.hull,
		PLANKS
	)
	for _, x in ipairs({ -4, 0, 4 }) do
		add(
			model,
			hull,
			"SternWindow",
			Vector3.new(1.6, 1.4, 0.3),
			CFrame.new(x, top + 2.4, size.Z / 2 + 0.2),
			rgb(255, 214, 130),
			NEON
		)
	end
end

-- Stormrunner: a sleek boat under one tall lightning-bolt sail, with a spinning wind vane at the masthead.
BUILD.stormrunner = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.55)
	local top = size.Y / 2
	for _, side in ipairs({ -1, 1 }) do
		-- Two thin bilge keels: it sits in rough water like a catamaran.
		add(
			model,
			hull,
			"Keel",
			Vector3.new(0.8, 2.2, size.Z * 0.8),
			CFrame.new(side * (size.X / 2 - 0.6), -size.Y / 2 - 0.4, 0),
			look.trim,
			SMOOTH
		)
	end
	add(model, hull, "Mast", Vector3.new(0.8, 24, 0.8), CFrame.new(0, top + 12, -3), rgb(40, 52, 76))
	add(
		model,
		hull,
		"Sail",
		Vector3.new(0.3, 19, 11),
		CFrame.new(0, top + 11, 2.6),
		rgb(196, 208, 226),
		FABRIC,
		{ shape = "wedge" }
	)
	-- The bolt across the sail, both faces (SailStripe takes the paint's sail stripe colour).
	for _, side in ipairs({ -1, 1 }) do
		for _, seg in ipairs({ { 3, -1.5, 30 }, { 0, 1.2, -32 }, { -3, -0.8, 30 } }) do
			add(
				model,
				hull,
				"SailStripe",
				Vector3.new(0.12, 5.2, 1.4),
				CFrame.new(side * 0.22, top + 11 + seg[1], 2.4 + seg[2]) * CFrame.Angles(math.rad(seg[3]), 0, 0),
				rgb(255, 226, 64),
				NEON
			)
		end
	end
	-- The vane: three cups on spokes (the client spins anything called StormVane).
	local hubOffset = CFrame.new(0, top + 24.6, -3)
	add(model, hull, "StormVane", Vector3.new(0.6, 0.6, 0.6), hubOffset, rgb(255, 226, 64), METAL, { shape = "ball" })
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		add(
			model,
			hull,
			"StormVane",
			Vector3.new(2.6, 0.2, 0.2),
			hubOffset * CFrame.Angles(0, a, 0) * CFrame.new(1.3, 0, 0),
			rgb(40, 52, 76),
			METAL
		)
		add(
			model,
			hull,
			"StormVane",
			Vector3.new(0.7, 0.7, 0.7),
			hubOffset * CFrame.Angles(0, a, 0) * CFrame.new(2.6, 0, 0),
			rgb(255, 226, 64),
			METAL,
			{ shape = "ball" }
		)
	end
	add(model, hull, "Flag", Vector3.new(0.3, 2, 3.4), CFrame.new(0, top + 22.4, -3.1), trim, FABRIC)
	add(model, hull, "Cabin", Vector3.new(6, 2.2, 6), CFrame.new(0, top + 1.1, size.Z / 2 - 4.5), look.hull, PLANKS)
end

-- Wraith: low, narrow and dark, with a scythe-curved prow, tattered glowing sails and ghost-fire lanterns.
BUILD.wraith = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.5)
	local top = size.Y / 2
	-- The scythe prow, curling up and back.
	for i = 0, 3 do
		add(
			model,
			hull,
			"ScytheProw",
			Vector3.new(0.6, 0.8, 2.6),
			CFrame.new(0, top + 0.6 + i * 1.1, -size.Z / 2 - 1.2 + i * 0.7) * CFrame.Angles(math.rad(40 + i * 18), 0, 0),
			look.stripe,
			NEON,
			{ transparency = 0.15 }
		)
	end
	add(model, hull, "Mast", Vector3.new(0.6, 14, 0.6), CFrame.new(0, top + 7, -1), rgb(30, 32, 40))
	-- Two tattered sails: see-through and glowing.
	for _, spec in ipairs({ { 6.6, 9, 1.8 }, { 4.6, 6, 5.6 } }) do
		local sail = add(
			model,
			hull,
			"Sail",
			Vector3.new(0.2, spec[2], spec[1]),
			CFrame.new(0, top + 3 + spec[2] / 2, spec[3] - 1),
			rgb(196, 255, 236),
			FABRIC,
			{ transparency = 0.35 }
		)
		sail.Name = "Sail"
		for k = 0, 2 do
			add(
				model,
				hull,
				"SailTatter",
				Vector3.new(0.15, 1.6, 0.8),
				CFrame.new(0, top + 2.4, spec[3] - 1 - spec[1] / 2 + 0.6 + k * (spec[1] / 3)),
				rgb(110, 255, 210),
				NEON,
				{ transparency = 0.4 + k * 0.1 }
			)
		end
	end
	add(model, hull, "Flag", Vector3.new(0.3, 2.2, 3.6), CFrame.new(0, top + 13.6, -1.2), trim, FABRIC)
	for _, z in ipairs({ -size.Z * 0.3, size.Z * 0.35 }) do
		for _, side in ipairs({ -1, 1 }) do
			local lantern = add(
				model,
				hull,
				"GhostLantern",
				Vector3.new(0.9, 1.2, 0.9),
				CFrame.new(side * (size.X / 2 - 0.4), top + 1.6, z),
				rgb(110, 255, 210),
				NEON,
				{ shape = "egg" }
			)
			local light = Instance.new("PointLight")
			light.Color = rgb(110, 255, 210)
			light.Range = 10
			light.Brightness = 1
			light.Parent = lantern
		end
	end
end

-- Ironbelly: a riveted iron tug with a ram on the bow, a smoking funnel, a wheelhouse and tyres for fenders.
BUILD.ironbelly = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.75)
	local top = size.Y / 2
	-- The ram: an iron wedge on the bow, just above the water.
	add(
		model,
		hull,
		"Ram",
		Vector3.new(size.X * 0.7, size.Y * 0.55, 6),
		CFrame.new(0, -size.Y * 0.1, -size.Z / 2 - 3.2) * CFrame.Angles(0, math.rad(180), 0),
		Palette.IRON,
		METAL,
		{ shape = "wedge" }
	)
	add(
		model,
		hull,
		"RamStripe",
		Vector3.new(size.X * 0.72, 0.6, 2.2),
		CFrame.new(0, size.Y * 0.18, -size.Z / 2 - 1.6),
		rgb(255, 200, 40),
		SMOOTH
	)
	for _, side in ipairs({ -1, 1 }) do
		-- Iron plates with rivets, and a hazard stripe.
		for i = -2, 2 do
			add(
				model,
				hull,
				"Plate",
				Vector3.new(0.3, size.Y * 0.7, size.Z * 0.17),
				CFrame.new(side * (size.X / 2 + 0.2), -0.2, i * size.Z * 0.18),
				Palette.IRON:Lerp(rgb(140, 90, 60), (i % 2) * 0.25),
				METAL
			)
			add(
				model,
				hull,
				"Rivet",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(side * (size.X / 2 + 0.38), size.Y * 0.22, i * size.Z * 0.18),
				rgb(200, 200, 196),
				METAL,
				{ shape = "ball" }
			)
		end
		-- Tyres hanging over the side as fenders.
		for _, z in ipairs({ -size.Z * 0.26, 0, size.Z * 0.26 }) do
			add(
				model,
				hull,
				"Tyre",
				Vector3.new(1.4, 3.2, 3.2),
				CFrame.new(side * (size.X / 2 + 0.9), top * 0.25, z) * CFrame.Angles(0, 0, 0),
				rgb(36, 34, 36),
				SMOOTH,
				{ shape = "cyl" }
			)
		end
	end
	-- The wheelhouse and the funnel with smoke.
	add(model, hull, "Cabin", Vector3.new(size.X * 0.6, 6, 9), CFrame.new(0, top + 3, size.Z / 2 - 8), look.hull, METAL)
	for _, x in ipairs({ -2.6, 2.6 }) do
		add(
			model,
			hull,
			"CabinWindow",
			Vector3.new(2.2, 1.6, 0.3),
			CFrame.new(x, top + 4, size.Z / 2 - 12.6),
			rgb(170, 220, 240),
			GLASS,
			{ transparency = 0.2 }
		)
	end
	local funnel = add(
		model,
		hull,
		"Funnel",
		Vector3.new(10, 4, 4),
		CFrame.new(0, top + 6 + 5, size.Z / 2 - 15) * UPRIGHT,
		rgb(40, 38, 40),
		METAL,
		{ shape = "cyl" }
	)
	add(
		model,
		hull,
		"FunnelBand",
		Vector3.new(1.6, 4.2, 4.2),
		CFrame.new(0, top + 6 + 8.6, size.Z / 2 - 15) * UPRIGHT,
		rgb(255, 200, 40),
		SMOOTH,
		{ shape = "cyl" }
	)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "FunnelSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(rgb(90, 90, 96), rgb(200, 200, 205))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Speed = NumberRange.new(6, 9)
	smoke.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis is its X, which points up here
	smoke.Rate = 6
	smoke.Parent = funnel
	add(model, hull, "Mast", Vector3.new(0.5, 6, 0.5), CFrame.new(0, top + 9, size.Z / 2 - 6), rgb(70, 66, 64))
	add(model, hull, "Flag", Vector3.new(0.3, 2, 3.2), CFrame.new(0, top + 11, size.Z / 2 - 5), trim, FABRIC)
	-- The tow winch at the stern.
	add(
		model,
		hull,
		"Winch",
		Vector3.new(3, 2.4, 2.4),
		CFrame.new(0, top + 1.2, size.Z / 2 - 2.4) * ALONG * CFrame.Angles(0, math.rad(90), 0),
		rgb(255, 200, 40),
		METAL,
		{ shape = "cyl" }
	)
end

-- V13.2: Anchorjack. A stout harbour workboat: a big iron anchor hung at the bow on a chain, a capstan, a crane boom
-- over the stern and a gaff sail. (The thrown anchor is drawn by the clients: client/Main's ability effects.)
BUILD.anchorjack = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.66)
	local top, bow = size.Y / 2, -size.Z / 2
	-- The anchor: shank, stock, two flukes and a ring, hanging over the bow.
	local anchorAt = CFrame.new(0, top - 1.2, bow - 2.2)
	add(model, hull, "AnchorShank", Vector3.new(0.7, 4.6, 0.7), anchorAt, Palette.IRON, METAL)
	add(model, hull, "AnchorStock", Vector3.new(3.6, 0.6, 0.6), anchorAt * CFrame.new(0, 1.9, 0), Palette.IRON, METAL)
	for _, side in ipairs({ -1, 1 }) do
		add(
			model,
			hull,
			"AnchorFluke",
			Vector3.new(0.6, 2.2, 0.7),
			anchorAt * CFrame.new(side * 1.1, -2.0, 0) * CFrame.Angles(0, 0, side * math.rad(-48)),
			Palette.IRON,
			METAL
		)
	end
	add(
		model,
		hull,
		"AnchorRing",
		Vector3.new(0.4, 1.4, 1.4),
		anchorAt * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, math.rad(90), 0),
		look.stripe,
		METAL,
		{ shape = "cyl" }
	)
	for i = 0, 3 do
		add(
			model,
			hull,
			"AnchorChain",
			Vector3.new(0.5, 0.9, 0.5),
			CFrame.new(0, top + 0.4 - i * 0.3, bow + 1.2 - i * 0.9) * CFrame.Angles(math.rad(40), 0, 0),
			rgb(90, 90, 96),
			METAL
		)
	end
	-- The capstan on the foredeck.
	add(
		model,
		hull,
		"Capstan",
		Vector3.new(2.4, 2.6, 2.6),
		CFrame.new(0, top + 1.2, bow + 5) * UPRIGHT,
		look.trim,
		WOOD,
		{ shape = "cyl" }
	)
	for _, angle in ipairs({ 0, 90 }) do
		add(
			model,
			hull,
			"CapstanBar",
			Vector3.new(4.6, 0.35, 0.35),
			CFrame.new(0, top + 2.2, bow + 5) * CFrame.Angles(0, math.rad(angle), 0),
			rgb(88, 58, 36),
			WOOD
		)
	end
	-- The wheelhouse, a gaff-rigged mast and a crane boom over the stern.
	add(model, hull, "Cabin", Vector3.new(7, 3.4, 6), CFrame.new(0, top + 1.7, size.Z / 2 - 6), look.hull, PLANKS)
	add(model, hull, "Mast", Vector3.new(0.8, 14, 0.8), CFrame.new(0, top + 7, -2), rgb(88, 58, 36))
	add(
		model,
		hull,
		"Sail",
		Vector3.new(0.3, 9, 7),
		CFrame.new(0, top + 7.5, 1.4),
		look.sail,
		FABRIC,
		{ shape = "wedge" }
	)
	add(
		model,
		hull,
		"Boom",
		Vector3.new(0.5, 0.5, 9),
		CFrame.new(0, top + 6, size.Z / 2 - 4) * CFrame.Angles(math.rad(-20), 0, 0),
		look.stripe,
		WOOD
	)
	add(model, hull, "Flag", Vector3.new(0.3, 2.2, 3.4), CFrame.new(0, top + 14.2, -2), trim, FABRIC)
end

-- V13.2: Wavebreaker. A blunt, broad-bowed boat with a curling wave plough on the bow, foam-white trim, a low
-- wheelhouse and two short masts with rounded sails.
BUILD.wavebreaker = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.8)
	local top, bow = size.Y / 2, -size.Z / 2
	-- The plough: a curved shield of three tilted plates across the bow, and a white curl on top.
	for i, angle in ipairs({ -35, 0, 35 }) do
		add(
			model,
			hull,
			"Plough",
			Vector3.new(size.X * 0.42, size.Y * 1.1, 0.6),
			CFrame.new((i - 2) * size.X * 0.3, 0.2, bow - 0.9 + math.abs(i - 2) * 1.3)
				* CFrame.Angles(math.rad(-18), math.rad(angle), 0),
			look.stripe,
			SMOOTH
		)
	end
	for i = 0, 4 do
		add(
			model,
			hull,
			"Curl",
			Vector3.new(size.X * 0.9 - i * 1.2, 0.8, 0.8),
			CFrame.new(0, top + 0.6 + math.sin(i * 0.8) * 0.9, bow + 0.4 + i * 0.7),
			look.trim,
			SMOOTH,
			{ shape = "cyl" }
		)
	end
	-- Wave crests painted down both sides.
	for _, side in ipairs({ -1, 1 }) do
		for i = -2, 2 do
			add(
				model,
				hull,
				"Crest",
				Vector3.new(0.3, 1.2, 2.6),
				CFrame.new(side * (size.X / 2 + 0.2), -0.4, i * size.Z * 0.17) * CFrame.Angles(math.rad(30), 0, 0),
				look.trim,
				SMOOTH,
				{ shape = "wedge" }
			)
		end
	end
	add(model, hull, "Cabin", Vector3.new(8, 3, 6), CFrame.new(0, top + 1.5, size.Z / 2 - 5), look.hull, PLANKS)
	for _, z in ipairs({ -4, 4 }) do
		add(model, hull, "Mast", Vector3.new(0.8, 13, 0.8), CFrame.new(0, top + 6.5, z), rgb(88, 58, 36))
		add(
			model,
			hull,
			"Sail",
			Vector3.new(0.3, 8, 7.5),
			CFrame.new(0, top + 7.5, z + 0.6),
			look.sail,
			FABRIC,
			{ shape = "egg" }
		)
	end
	add(model, hull, "Flag", Vector3.new(0.3, 2.2, 3.4), CFrame.new(0, top + 13.4, -4), trim, FABRIC)
end

-- V13.2: Corsair. A lean black pirate sloop with blood-red sails, a gold stripe, a crow's nest and a harpoon launcher
-- on the bow (the boarding hook).
BUILD.corsair = function(model, hull, size, look, trim)
	common(model, hull, size, look, 0.55)
	local top, bow = size.Y / 2, -size.Z / 2
	-- The harpoon: a swivel post, a barrel and a barbed head.
	add(model, hull, "HookPost", Vector3.new(1.2, 1.6, 1.2), CFrame.new(0, top + 0.8, bow + 3.4), look.trim, WOOD)
	add(
		model,
		hull,
		"HookBarrel",
		Vector3.new(0.9, 0.9, 4.6),
		CFrame.new(0, top + 1.9, bow + 2.4) * CFrame.Angles(math.rad(8), 0, 0),
		Palette.IRON,
		METAL
	)
	for _, side in ipairs({ -1, 1 }) do
		add(
			model,
			hull,
			"HookBarb",
			Vector3.new(0.35, 0.35, 1.6),
			CFrame.new(side * 0.5, top + 2.1, bow - 0.3) * CFrame.Angles(0, side * math.rad(35), 0),
			look.stripe,
			METAL
		)
	end
	-- A long bowsprit, a tall mast with a crow's nest, a red mainsail and jib.
	add(
		model,
		hull,
		"Bowsprit",
		Vector3.new(0.5, 0.5, 9),
		CFrame.new(0, top + 2, bow - 3) * CFrame.Angles(math.rad(14), 0, 0),
		rgb(70, 44, 30),
		WOOD
	)
	add(model, hull, "Mast", Vector3.new(0.9, 20, 0.9), CFrame.new(0, top + 10, -1), rgb(52, 36, 30))
	add(
		model,
		hull,
		"CrowsNest",
		Vector3.new(1.4, 3, 3),
		CFrame.new(0, top + 17, -1) * UPRIGHT,
		look.trim,
		PLANKS,
		{ shape = "cyl" }
	)
	add(model, hull, "Sail", Vector3.new(0.3, 11, 8), CFrame.new(0, top + 9.5, 0.2), look.sail, FABRIC)
	add(
		model,
		hull,
		"Jib",
		Vector3.new(0.25, 7, 6),
		CFrame.new(0, top + 6, bow + 3.2) * CFrame.Angles(0, math.rad(180), 0),
		look.sail,
		FABRIC,
		{ shape = "wedge" }
	)
	-- The emblem on the mainsail: a pale moon (the skull of a jolly roger at a distance).
	add(
		model,
		hull,
		"SailEmblem",
		Vector3.new(0.4, 3.6, 3.6),
		CFrame.new(-0.2, top + 10, 0.2) * CFrame.Angles(0, math.rad(90), 0),
		rgb(236, 230, 214),
		SMOOTH,
		{ shape = "cyl" }
	)
	add(model, hull, "Flag", Vector3.new(0.3, 2.4, 3.8), CFrame.new(0, top + 20.4, -1), trim, FABRIC)
	add(model, hull, "Cabin", Vector3.new(6, 2.4, 5), CFrame.new(0, top + 1.2, size.Z / 2 - 4.5), look.hull, PLANKS)
end

-- The Navy's patrol ship (AI only; Boats.lua repaints it white and blue afterwards).
BUILD.navy = function(model, hull, size, _look, _trim)
	common(model, hull, size, Palette.BOATS.navy)
	local top = size.Y / 2
	hull.Color = rgb(55, 45, 55)
	for _, z in ipairs({ -9, 4 }) do
		add(model, hull, "Mast", Vector3.new(1.1, 24, 1.1), CFrame.new(0, top + 12, z), rgb(50, 40, 40))
		add(model, hull, "Sail", Vector3.new(0.3, 15, 13), CFrame.new(0, top + 12, z + 0.7), rgb(170, 35, 40), FABRIC)
	end
	add(model, hull, "Cabin", Vector3.new(11, 5, 10), CFrame.new(0, top + 2.5, size.Z / 2 - 7), rgb(70, 55, 60), PLANKS)
	local lamp = add(
		model,
		hull,
		"Lantern",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(0, top + 6.4, size.Z / 2 - 7),
		rgb(255, 90, 60),
		NEON
	)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 90, 60)
	light.Range = 30
	light.Parent = lamp
end

-- Dresses a hull for its class. `trim` is the dock boat's flag colour (it tells boats apart).
function BoatModels.dress(typeName, model, hull, size, trim)
	local look = BoatModels.livery(typeName)
	hull.Color = look.hull
	local build = BUILD[typeName] or BUILD.skiff
	build(model, hull, size, look, trim)
	model:SetAttribute("Livery", typeName)
end

-- Where the passengers sit, in the hull's frame (the driver's seat is Boats.lua's: at the stern).
local SEATS = {
	skiff = function(y)
		return { Vector3.new(0, y, 2) }
	end,
	cutter = function(y)
		return { Vector3.new(-3.4, y, 2), Vector3.new(3.4, y, 2), Vector3.new(0, y, -3) }
	end,
	reefhopper = function(y)
		return { Vector3.new(0, y, 1.5) }
	end,
	-- The Broadside's first two passengers sit by its two side cannons (gunners); the third mid-deck.
	broadside = function(y, size)
		return {
			Vector3.new(-(size.X / 2 - 3.2), y, 2.5),
			Vector3.new(size.X / 2 - 3.2, y, 2.5),
			Vector3.new(0, y, -6),
		}
	end,
	stormrunner = function(y)
		return { Vector3.new(0, y, 2.5), Vector3.new(0, y, -4) }
	end,
	wraith = function(y)
		return { Vector3.new(0, y, 2) }
	end,
	ironbelly = function(y)
		return { Vector3.new(-4, y, 0), Vector3.new(4, y, 0), Vector3.new(-4, y, -8), Vector3.new(4, y, -8) }
	end,
	-- V13.2
	anchorjack = function(y)
		return { Vector3.new(-3, y, 1), Vector3.new(3, y, 1) }
	end,
	wavebreaker = function(y)
		return { Vector3.new(-3, y, 0.5), Vector3.new(3, y, 0.5) }
	end,
	corsair = function(y)
		return { Vector3.new(0, y, 3), Vector3.new(0, y, -5) }
	end,
}

function BoatModels.seats(typeName, size)
	local y = size.Y / 2 + 0.7
	local fn = SEATS[typeName]
	return fn and fn(y, size) or {}
end

return BoatModels

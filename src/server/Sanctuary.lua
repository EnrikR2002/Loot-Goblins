-- THE PET SANCTUARY (V13.3): every goblin in the server has a little floating isle high over the Port, where the pets
-- they own wander, nap in their nests, splash in the pond, come running when they are fed, chase a thrown ball and
-- gather at the bell. The goods and the rules are shared/Habitat.lua's; this module builds the isles and runs them.
--
--   THE ISLES  one per goblin, in two rings over the town (Config.SANCTUARY.RINGS), built when their profile is first
--              seen and rebuilt only when what it looks like changes (theme, features, decorations, trophies). The pets
--              are drawn by every client from the isle's attributes (client/Sanctuary.lua): Residents (whom the owner
--              chose, or the pets they own, newest first), Away (out on expeditions), FedAt, Toy*, BellAt.
--   GETTING    the SANCTUARY LIFT in the Port (a balloon basket: E to go to your own isle; VISIT to go to anyone's),
--   THERE      the screen's 🐾 chip, or SanctuaryRequest("home" | "visit", userId). The basket on every isle goes back
--              down to the Port (or jump off: the Port has no fall damage).
--   ACTIONS    ShopRequest: "sanctbuy" (kind, id), "sanctplace" (socket, decor), "sancttheme" (theme), "residents"
--              (list), "expsend" (pet, trip), "expcollect" (id), "exprecall" (id): all need the real profile open.
--   EXPEDITIONS a pet sent away is unequipped (it cannot follow you and scavenge), shows as Away, and is back on the
--              server's clock (Habitat). Collecting pays once, inside the day's cap.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Habitat = require(Shared:WaitForChild("Habitat"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Port = require(script.Parent.Port)
local Progress = require(script.Parent.Progress)
local Economy = require(script.Parent.Economy)
local Analytics = require(script.Parent.Analytics)
local Minigames = require(script.Parent.Minigames)

local Sanctuary = {}

local SC = Config.SANCTUARY
local rgb = Color3.fromRGB
local v3 = Vector3.new
local kit
local folder
local slots = {} -- index -> player
local isles = {} -- player -> { slot, model, sig, center }
local asks = setmetatable({}, { __mode = "k" })

local function now()
	return workspace:GetServerTimeNow()
end

local function unix()
	return os.time()
end

-- Where isle `index` floats.
local function slotCenter(index)
	local i = index
	for _, ring in ipairs(SC.RINGS) do
		if i <= ring.count then
			local a = (i - 0.5) / ring.count * math.pi * 2 + (ring.radius > 300 and 0.13 or 0)
			local I = PortGames.ISLAND
			return v3(I.X + math.cos(a) * ring.radius, ring.y, I.Z + math.sin(a) * ring.radius)
		end
		i -= ring.count
	end
	return nil
end
Sanctuary.slotCenter = slotCenter

-- Building an isle ----------------------------------------------------------------------------------------------------------
local function part(model, name, size, cf, color, material, opts)
	opts = opts or {}
	local p = Instance.new(opts.wedge and "WedgePart" or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.collide == true
	p.CanTouch = false
	p.CastShadow = opts.shadow == true
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
	p.Parent = model
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90))

local function prompt(model, name, cf, objectText, actionText, attributes, distance)
	local pad = part(model, name, v3(3, 3, 3), cf, rgb(255, 255, 255), nil, { transparency = 1 })
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name .. "Prompt"
	pp.ObjectText = objectText
	pp.ActionText = actionText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = distance or 10
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	for key, value in pairs(attributes or {}) do
		pp:SetAttribute(key, value)
	end
	pp.Parent = pad
	return pp
end

-- The decorations (one look each; "statue" is the owner, dressed as they are).
local DECOR = {}
DECOR.flowers = function(model, at)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local p = at * CFrame.new(math.cos(a) * 1.8, 0.4, math.sin(a) * 1.8)
		part(model, "Stem", v3(0.2, 1, 0.2), p, rgb(80, 150, 60))
		part(
			model,
			"Bloom",
			v3(0.9, 0.9, 0.9),
			p * CFrame.new(0, 0.6, 0),
			({ rgb(255, 120, 160), rgb(255, 220, 90), rgb(160, 120, 255) })[k % 3 + 1],
			nil,
			{ egg = true }
		)
	end
end
DECOR.mushrooms = function(model, at)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local s = 0.8 + (k % 2) * 0.5
		local p = at * CFrame.new(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)
		part(model, "MushStalk", v3(0.6 * s, 1.4 * s, 0.6 * s), p * CFrame.new(0, 0.7 * s, 0), rgb(240, 232, 214))
		part(
			model,
			"MushCap",
			v3(2 * s, 1 * s, 2 * s),
			p * CFrame.new(0, 1.5 * s, 0),
			rgb(220, 50, 50),
			nil,
			{ egg = true }
		)
	end
end
DECOR.palm = function(model, at)
	for k = 0, 5 do
		part(
			model,
			"Trunk",
			v3(0.9, 1.6, 0.9),
			at * CFrame.new(k * 0.15, 0.8 + k * 1.5, 0) * CFrame.Angles(0, 0, math.rad(-4)),
			rgb(150, 110, 70),
			Enum.Material.Wood
		)
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		part(
			model,
			"Frond",
			v3(0.3, 1.4, 5),
			at * CFrame.new(0.9, 9.4, 0) * CFrame.Angles(0, a, math.rad(-20)) * CFrame.new(0, 0, -2.4),
			rgb(90, 170, 70),
			nil,
			{ egg = true }
		)
	end
end
DECOR.torches = function(model, at)
	for _, x in ipairs({ -2.4, 2.4 }) do
		part(model, "TorchPole", v3(0.5, 4.5, 0.5), at * CFrame.new(x, 2.2, 0), rgb(120, 84, 50), Enum.Material.Wood)
		local flame = part(
			model,
			"TorchFlame",
			v3(0.9, 1.4, 0.9),
			at * CFrame.new(x, 5, 0),
			rgb(255, 170, 60),
			Enum.Material.Neon,
			{ egg = true }
		)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 170, 80)
		light.Range = 14
		light.Parent = flame
	end
end
DECOR.hammock = function(model, at)
	for _, x in ipairs({ -3.4, 3.4 }) do
		part(model, "HammockPost", v3(0.6, 4, 0.6), at * CFrame.new(x, 2, 0), rgb(120, 84, 50), Enum.Material.Wood)
	end
	part(
		model,
		"Hammock",
		v3(6.4, 0.4, 2.2),
		at * CFrame.new(0, 2.2, 0),
		rgb(230, 200, 140),
		Enum.Material.Fabric,
		{ egg = true }
	)
end
DECOR.totem = function(model, at)
	for k = 0, 2 do
		part(
			model,
			"TotemBlock",
			v3(2.2, 1.8, 2.2),
			at * CFrame.new(0, 0.9 + k * 1.8, 0),
			({ rgb(170, 110, 70), rgb(120, 170, 90), rgb(200, 120, 70) })[k + 1],
			Enum.Material.Wood
		)
		part(model, "TotemEyes", v3(1.4, 0.4, 0.2), at * CFrame.new(0, 1.1 + k * 1.8, -1.12), rgb(30, 26, 30))
	end
	part(model, "TotemWings", v3(5, 0.6, 1), at * CFrame.new(0, 5.6, 0), rgb(255, 200, 70), Enum.Material.Wood)
end
DECOR.treasure = function(model, at)
	part(model, "Chest", v3(3, 2, 2), at * CFrame.new(0, 1, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	for k = 0, 8 do
		local a = k * 0.8
		part(
			model,
			"Coin",
			v3(0.8, 0.8, 0.8),
			at * CFrame.new(math.cos(a) * (1 + k * 0.15), 0.3 + (k % 3) * 0.3, math.sin(a) * (1 + k * 0.15)),
			Palette.GOLD,
			Enum.Material.Metal,
			{ ball = true }
		)
	end
	part(
		model,
		"Gem",
		v3(0.8, 1.1, 0.8),
		at * CFrame.new(0, 2.4, 0),
		rgb(110, 230, 255),
		Enum.Material.Neon,
		{ egg = true }
	)
end
DECOR.statue = function(model, at, owner)
	part(model, "StatuePlinth", v3(3, 1.4, 3), at * CFrame.new(0, 0.7, 0), Palette.STONE, Enum.Material.Cobblestone)
	if owner and kit and kit.mannequinOn then
		local ok, figure =
			pcall(kit.mannequinOn, at * CFrame.new(0, 1.4, 0), Catalog.decodeLook(owner:GetAttribute("Look")), model)
		if ok and figure then
			figure.Name = "OwnerStatue"
		end
	end
end

-- Positions on the isle (its own frame: +Z is toward the Port's middle).
local SOCKET_AT = { v3(-14, 0, -12), v3(14, 0, -12), v3(-17, 0, 6), v3(17, 0, 6) }

local function build(player, s, center)
	local profile = s.profile
	local theme = Habitat.THEME_BY_ID[profile.sanctuary.theme] or Habitat.THEMES[1]
	local model = Instance.new("Model")
	model.Name = "Isle_" .. player.UserId
	local I = PortGames.ISLAND
	local toward = v3(I.X, center.Y, I.Z)
	local frame = CFrame.lookAt(center, toward) -- -Z faces the Port's middle
	local R = SC.ISLE
	-- Ground: a grassy disc you can walk on, a rocky underside, a rim.
	part(
		model,
		"IsleTop",
		v3(2, R * 2, R * 2),
		frame * CFrame.new(0, -1, 0) * UP,
		theme.grass,
		Enum.Material.Grass,
		{ cyl = true, collide = true }
	)
	part(
		model,
		"IsleRim",
		v3(2.6, R * 2 + 2, R * 2 + 2),
		frame * CFrame.new(0, -1.6, 0) * UP,
		theme.rim,
		Enum.Material.SmoothPlastic,
		{ cyl = true }
	)
	part(
		model,
		"IsleRock",
		v3(R * 2, 26, R * 2),
		frame * CFrame.new(0, -14, 0),
		theme.rock,
		Enum.Material.Slate,
		{ egg = true }
	)
	part(
		model,
		"IsleRoot",
		v3(R, 22, R),
		frame * CFrame.new(3, -30, 2),
		theme.rock,
		Enum.Material.Slate,
		{ egg = true }
	)
	-- A low fence with a gap at the basket.
	for k = 0, 23 do
		if k ~= 18 and k ~= 17 and k ~= 19 then
			local a = k / 24 * math.pi * 2
			part(
				model,
				"FencePost",
				v3(0.6, 2.4, 0.6),
				frame * CFrame.new(math.cos(a) * (R - 1), 1.2, math.sin(a) * (R - 1)),
				Palette.WOOD_DARK,
				Enum.Material.Wood,
				{ collide = true }
			)
		end
	end
	-- The basket back down to the Port, at the edge facing the town.
	local basketAt = frame * CFrame.new(0, 0, -(R - 3))
	part(model, "Basket", v3(5, 3, 5), basketAt * CFrame.new(0, 1.5, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	part(
		model,
		"Balloon",
		v3(9, 10, 9),
		basketAt * CFrame.new(0, 13, 0),
		theme.accent,
		Enum.Material.Fabric,
		{ egg = true }
	)
	for _, sx in ipairs({ -1, 1 }) do
		part(
			model,
			"BalloonRope",
			v3(0.2, 8, 0.2),
			basketAt * CFrame.new(sx * 2.2, 6.5, 0),
			Palette.ROPE or rgb(200, 170, 120),
			Enum.Material.Fabric
		)
	end
	prompt(
		model,
		"BasketDown",
		basketAt * CFrame.new(0, 2.5, 0),
		"The basket",
		"Down to the Port",
		{ SanctuaryAction = "port" },
		10
	)
	-- The owner's sign.
	local sign = kit.board(
		"IsleSign",
		v3(14, 2.6, 0.4),
		frame * CFrame.new(0, 6, -(R - 9)) * CFrame.Angles(0, math.rad(180), 0),
		string.upper(player.DisplayName) .. "'S SANCTUARY",
		Palette.GOLD
	)
	sign.Parent = model
	-- The pond.
	local pond = Habitat.level(profile, "pond")
	local pondAt = frame * CFrame.new(-6, 0.05, 10)
	local pondR = ({ 4, 6.5, 8.5 })[math.clamp(pond, 1, 3)]
	part(
		model,
		"Pond",
		v3(0.3, pondR * 2, pondR * 2),
		pondAt * UP,
		rgb(80, 180, 220),
		Enum.Material.Glass,
		{ cyl = true, transparency = 0.15 }
	)
	if pond >= 2 then
		for k = 0, 3 do
			local a = k * 1.7
			part(
				model,
				"LilyPad",
				v3(0.1, 1.6, 1.6),
				pondAt * CFrame.new(math.cos(a) * pondR * 0.6, 0.2, math.sin(a) * pondR * 0.6) * UP,
				rgb(90, 180, 80),
				nil,
				{ cyl = true }
			)
		end
	end
	if pond >= 3 then
		local spout = part(
			model,
			"Fountain",
			v3(1.4, 3, 1.4),
			pondAt * CFrame.new(0, 1.5, 0),
			Palette.STONE,
			Enum.Material.Cobblestone
		)
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spray.Color = ColorSequence.new(rgb(190, 240, 255))
		spray.Size = NumberSequence.new(0.4, 0.1)
		spray.Lifetime = NumberRange.new(0.8, 1.2)
		spray.Speed = NumberRange.new(8, 12)
		spray.SpreadAngle = Vector2.new(15, 15)
		spray.Acceleration = v3(0, -24, 0)
		spray.Rate = 14
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = spout
	end
	-- The nests (where pets nap).
	local nests = ({ 1, 3, 5 })[math.clamp(Habitat.level(profile, "nest"), 1, 3)]
	for k = 1, nests do
		local at = frame * CFrame.new(8 + (k - 1) % 3 * 4, 0.3, 8 + ((k - 1) // 3) * 4)
		part(model, "Nest", v3(0.6, 3, 3), at * UP, rgb(200, 160, 100), Enum.Material.Fabric, { cyl = true })
		part(
			model,
			"NestPillow",
			v3(0.4, 2, 2),
			at * CFrame.new(0, 0.3, 0) * UP,
			rgb(250, 230, 200),
			Enum.Material.Fabric,
			{ cyl = true }
		)
	end
	if Habitat.level(profile, "nest") >= 3 then
		part(
			model,
			"BurrowMound",
			v3(8, 4, 7),
			frame * CFrame.new(14, 1, 16),
			theme.grass:Lerp(rgb(120, 90, 60), 0.4),
			Enum.Material.Grass,
			{ egg = true }
		)
		part(
			model,
			"BurrowHole",
			v3(2.6, 2.2, 0.4),
			frame * CFrame.new(14, 1, 12.5),
			rgb(40, 30, 24),
			nil,
			{ egg = true }
		)
	end
	-- Lights.
	local lights = Habitat.level(profile, "lights")
	if lights >= 1 then
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			local at = frame * CFrame.new(math.cos(a) * (R - 4), 0, math.sin(a) * (R - 4))
			part(
				model,
				"LanternPost",
				v3(0.5, 5, 0.5),
				at * CFrame.new(0, 2.5, 0),
				Palette.WOOD_DARK,
				Enum.Material.Wood
			)
			local glow = part(
				model,
				"Lantern",
				v3(1, 1.3, 1),
				at * CFrame.new(0, 5.4, 0),
				rgb(255, 214, 130),
				Enum.Material.Neon
			)
			local light = Instance.new("PointLight")
			light.Color = rgb(255, 200, 120)
			light.Range = 16
			light.Parent = glow
		end
	end
	if lights >= 2 then
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			part(
				model,
				"StringLight",
				v3(0.5, 0.5, 0.5),
				frame * CFrame.new(math.cos(a) * (R - 2), 3.4 + (k % 2) * 0.4, math.sin(a) * (R - 2)),
				({ rgb(255, 120, 160), rgb(120, 220, 255), rgb(255, 230, 120) })[k % 3 + 1],
				Enum.Material.Neon,
				{ ball = true }
			)
		end
		local fireflies = part(
			model,
			"Fireflies",
			v3(1, 1, 1),
			frame * CFrame.new(0, 4, 0),
			rgb(255, 255, 255),
			nil,
			{ transparency = 1 }
		)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(rgb(255, 240, 150))
		emitter.Size = NumberSequence.new(0.3)
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 6
		emitter.LightEmission = 1
		emitter.Parent = fireflies
	end
	-- The expedition dock and its boat (a rowboat, a sloop, a little galleon).
	local dock = Habitat.level(profile, "dock")
	local dockAt = frame * CFrame.new(-(R - 2), 0, -6) * CFrame.Angles(0, math.rad(90), 0)
	part(
		model,
		"Jetty",
		v3(4, 0.8, 10),
		dockAt * CFrame.new(0, 0.2, -4),
		Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks,
		{ collide = true }
	)
	local hullSize = ({ v3(3, 1.4, 6), v3(4, 2, 9), v3(5, 2.6, 12) })[math.clamp(dock, 1, 3)]
	local hull = part(
		model,
		"ExpeditionBoat",
		hullSize,
		dockAt * CFrame.new(3.6, -0.6, -6),
		Palette.WOOD,
		Enum.Material.WoodPlanks
	)
	if dock >= 2 then
		part(
			model,
			"BoatMast",
			v3(0.4, hullSize.Z * 0.8, 0.4),
			hull.CFrame * CFrame.new(0, hullSize.Z * 0.4, 0),
			Palette.WOOD_DARK,
			Enum.Material.Wood
		)
		part(
			model,
			"BoatSail",
			v3(0.2, hullSize.Z * 0.5, hullSize.Z * 0.4),
			hull.CFrame * CFrame.new(0, hullSize.Z * 0.5, 0.4),
			rgb(246, 238, 220),
			Enum.Material.Fabric
		)
	end
	if dock >= 3 then
		part(
			model,
			"BoatFlag",
			v3(0.15, 1, 1.6),
			hull.CFrame * CFrame.new(0, hullSize.Z * 0.85, 0.8),
			theme.accent,
			Enum.Material.Fabric
		)
	end
	prompt(
		model,
		"Expeditions",
		dockAt * CFrame.new(0, 2.4, -6),
		"Expedition Dock",
		"Send pets out",
		{ OpensPanel = "expeditions", Owner = player.UserId },
		10
	)
	-- Feeding, a toy chest, the bell, and the signpost for decorating.
	local trough = frame * CFrame.new(4, 0, -12)
	part(model, "Trough", v3(5, 1.2, 2), trough * CFrame.new(0, 0.6, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	part(model, "Food", v3(4.4, 0.4, 1.4), trough * CFrame.new(0, 1.2, 0), rgb(230, 170, 80))
	prompt(model, "Feed", trough * CFrame.new(0, 2, 0), "Pet food", "Feed the pets", { SanctuaryAction = "feed" }, 9)
	local toys = frame * CFrame.new(-6, 0, -14)
	part(model, "ToyChest", v3(3, 2, 2), toys * CFrame.new(0, 1, 0), rgb(200, 80, 70), Enum.Material.WoodPlanks)
	prompt(model, "Toy", toys * CFrame.new(0, 2.4, 0), "Toy chest", "Throw a ball", { SanctuaryAction = "toy" }, 9)
	local bellAt = frame * CFrame.new(0, 0, 2)
	part(model, "BellPost", v3(0.6, 6, 0.6), bellAt * CFrame.new(0, 3, 0), Palette.WOOD_DARK, Enum.Material.Wood)
	part(
		model,
		"Bell",
		v3(1.8, 2, 1.8),
		bellAt * CFrame.new(0, 5.6, 0),
		Palette.GOLD,
		Enum.Material.Metal,
		{ egg = true }
	)
	prompt(model, "Bell", bellAt * CFrame.new(0, 3, 0), "Dinner bell", "Ring it", { SanctuaryAction = "bell" }, 9)
	local post = frame * CFrame.new(9, 0, -16)
	part(model, "DecoratePost", v3(0.6, 5, 0.6), post * CFrame.new(0, 2.5, 0), Palette.WOOD_DARK, Enum.Material.Wood)
	part(
		model,
		"DecorateBoard",
		v3(3.6, 2, 0.3),
		post * CFrame.new(0, 4.4, 0),
		rgb(244, 232, 204),
		Enum.Material.WoodPlanks
	)
	prompt(
		model,
		"Decorate",
		post * CFrame.new(0, 3, 0),
		"Your sanctuary",
		"Decorate",
		{ OpensPanel = "sanctuary", Owner = player.UserId },
		9
	)
	-- Decorations in their spots.
	for i, at in ipairs(SOCKET_AT) do
		local id = profile.sanctuary.decor[i]
		local builder = id and DECOR[id]
		if builder then
			local ok, err = pcall(builder, model, frame * CFrame.new(at), player)
			if not ok then
				warn("[Sanctuary] decor " .. tostring(id) .. ": " .. tostring(err))
			end
		end
	end
	-- The trophy case: the season's trophies (Seasons.pay records them).
	local case = frame * CFrame.new(-16, 0, -4) * CFrame.Angles(0, math.rad(90), 0)
	part(model, "TrophyShelf", v3(8, 0.4, 2), case * CFrame.new(0, 2.6, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	part(model, "TrophyShelfLow", v3(8, 0.4, 2), case * CFrame.new(0, 0.9, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	for k, trophy in ipairs(profile.season.trophies) do
		if k > 8 then
			break
		end
		local color = (trophy.rank == 1 or trophy.tier == "gold") and Palette.GOLD
			or (trophy.tier == "silver" and rgb(210, 214, 224) or rgb(214, 140, 80))
		local at = case * CFrame.new(-3 + ((k - 1) % 4) * 2, k <= 4 and 3.6 or 1.9, 0)
		part(model, "TrophyCup", v3(0.9, 1.2, 0.9), at, color, Enum.Material.Metal, { egg = true })
		part(model, "TrophyBase", v3(0.8, 0.3, 0.8), at * CFrame.new(0, -0.7, 0), color, Enum.Material.Metal)
	end
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("Center", center)
	model:SetAttribute("Radius", R)
	model:SetAttribute("Theme", theme.id)
	model:SetAttribute("Landing", (basketAt * CFrame.new(0, 3.5, 4)).Position)
	model.Parent = folder
	return model, basketAt
end

-- Which pets live on an isle: the owner's choice, or the pets they own (the one out first, then newest).
local function residentsOf(s)
	local profile = s.profile
	if #profile.sanctuary.residents > 0 then
		return profile.sanctuary.residents
	end
	local list = {}
	local out = profile.equipped.pet
	if out and Economy.owns(profile, out) then
		table.insert(list, out)
	end
	local owned = {}
	for id in pairs(profile.owned) do
		local item = Catalog.get(id)
		if item and item.slot == "pet" and id ~= out then
			table.insert(owned, item)
		end
	end
	table.sort(owned, function(a, b)
		return a.order > b.order
	end)
	for _, item in ipairs(owned) do
		if #list >= SC.RESIDENTS then
			break
		end
		table.insert(list, item.id)
	end
	return list
end

local function signature(s)
	local p = s.profile
	local parts = { p.sanctuary.theme }
	for _, feature in ipairs(Habitat.FEATURES) do
		table.insert(parts, tostring(Habitat.level(p, feature.id)))
	end
	for i = 1, Habitat.SOCKETS do
		table.insert(parts, p.sanctuary.decor[i] or "")
	end
	table.insert(parts, tostring(#p.season.trophies))
	if
		p.sanctuary.decor[1] == "statue"
		or p.sanctuary.decor[2] == "statue"
		or p.sanctuary.decor[3] == "statue"
		or p.sanctuary.decor[4] == "statue"
	then
		table.insert(parts, s.player:GetAttribute("Look") or "")
	end
	return table.concat(parts, "|")
end

-- Every change to a goblin's profile comes through here (Progress.publishers): the isle and the attributes.
local function publish(s)
	local player = s.player
	if not player.Parent or not folder then
		return
	end
	local isle = isles[player]
	if not isle then
		for i = 1, 32 do
			if not slots[i] and slotCenter(i) then
				slots[i] = player
				isle = { slot = i, center = slotCenter(i) }
				isles[player] = isle
				break
			end
		end
		if not isle then
			return -- more goblins than isles: no isle for this one (32 is the server's most)
		end
	end
	local sig = signature(s)
	if sig ~= isle.sig then
		isle.sig = sig
		if isle.model then
			isle.model:Destroy()
		end
		local ok, model = pcall(build, player, s, isle.center)
		if ok then
			isle.model = model
		else
			warn("[Sanctuary] build: " .. tostring(model))
		end
	end
	local model = isle.model
	if model then
		local residents = table.concat(residentsOf(s), ",")
		local away = {}
		for pet in pairs(Habitat.away(s.profile)) do
			table.insert(away, pet)
		end
		table.sort(away)
		if model:GetAttribute("Residents") ~= residents then
			model:SetAttribute("Residents", residents)
		end
		local awayText = table.concat(away, ",")
		if model:GetAttribute("Away") ~= awayText then
			model:SetAttribute("Away", awayText)
		end
	end
	-- The owner's panels.
	local x = s.profile.expeditions
	local list = {}
	for _, e in ipairs(x.list) do
		table.insert(list, { id = e.id, pet = e.pet, trip = e.trip, back = e.back, at = e.at })
	end
	local sanctuary = s.profile.sanctuary
	local owned = {}
	for key in pairs(sanctuary.owned) do
		table.insert(owned, key)
	end
	table.sort(owned)
	local levels = {}
	for _, feature in ipairs(Habitat.FEATURES) do
		levels[feature.id] = Habitat.level(s.profile, feature.id)
	end
	local ok, text = pcall(HttpService.JSONEncode, HttpService, {
		theme = sanctuary.theme,
		owned = owned,
		levels = levels,
		decor = sanctuary.decor,
		residents = sanctuary.residents,
		slot = isle.slot,
		expeditions = {
			list = list,
			slots = Habitat.slots(s.profile),
			day = x.day,
			today = x.collected,
		},
	})
	if ok and text ~= s.sanctuarySent then
		s.sanctuarySent = text
		player:SetAttribute("Sanctuary", text)
	end
end

local function forget(player)
	local isle = isles[player]
	if isle then
		if isle.model then
			isle.model:Destroy()
		end
		slots[isle.slot] = nil
		isles[player] = nil
	end
end

-- Going there and back ----------------------------------------------------------------------------------------------------
local function goTo(player, cframe)
	if player:GetAttribute("Zone") == "raid" then
		Net.toast(player, "Your sanctuary waits for you in the Port.")
		return false
	end
	if Minigames.sessionOf(player) then
		Minigames.leave(player, "leave")
	end
	local _, root = Port.freeOf(player)
	if not root then
		return false
	end
	Net.send(player, "PlayFx", { kind = "lift" })
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, 3)
		end)
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			player.Character:PivotTo(cframe)
		end
	end)
	return true
end

local function landingOf(owner)
	local isle = isles[owner]
	if not isle or not isle.model then
		return nil
	end
	local landing = isle.model:GetAttribute("Landing")
	local center = isle.center
	return typeof(landing) == "Vector3" and CFrame.lookAt(landing, v3(center.X, landing.Y, center.Z)) or nil
end

local function onIsle(player)
	local root = Util.aliveRoot(player)
	if not root then
		return nil
	end
	for owner, isle in pairs(isles) do
		local d = v3(root.Position.X - isle.center.X, 0, root.Position.Z - isle.center.Z).Magnitude
		if d <= SC.ISLE + 6 and math.abs(root.Position.Y - isle.center.Y) < 25 then
			return owner, isle
		end
	end
	return nil
end

function Sanctuary.request(player, action, a)
	local t = os.clock()
	if t - (asks[player] or 0) < 0.4 then
		return
	end
	asks[player] = t
	if action == "home" then
		local cf = landingOf(player)
		if cf then
			goTo(player, cf)
		else
			Net.toast(player, "Your sanctuary is still being built: try again in a moment.")
		end
	elseif action == "visit" then
		local owner = type(a) == "number" and Players:GetPlayerByUserId(a) or nil
		local cf = owner and landingOf(owner)
		if cf then
			goTo(player, cf)
			if owner ~= player then
				Net.toast(owner, player.DisplayName .. " is visiting your sanctuary!")
			end
		end
	elseif action == "port" then
		if onIsle(player) then
			Port.arrive(player)
		end
	elseif action == "feed" or action == "toy" or action == "bell" then
		local owner, isle = onIsle(player)
		if not owner or not isle.model then
			return
		end
		local model = isle.model
		local stamp = now()
		if action == "feed" then
			if stamp - (model:GetAttribute("FedAt") or 0) >= SC.FEED_GAP then
				model:SetAttribute("FedAt", stamp)
			end
		elseif action == "bell" then
			if stamp - (model:GetAttribute("BellAt") or 0) >= SC.BELL_GAP then
				model:SetAttribute("BellAt", stamp)
			end
		else
			if stamp - (model:GetAttribute("ToyAt") or 0) >= SC.TOY_GAP then
				-- Where the ball lands: where the goblin looks, kept on the isle.
				local root = Util.aliveRoot(player)
				local look = root and root.CFrame.LookVector or v3(0, 0, -1)
				local spot = root and (root.Position + v3(look.X, 0, look.Z).Unit * 14) or isle.center
				local flat = v3(spot.X - isle.center.X, 0, spot.Z - isle.center.Z)
				if flat.Magnitude > SC.ISLE - 4 then
					flat = flat.Unit * (SC.ISLE - 4)
				end
				model:SetAttribute("ToyX", isle.center.X + flat.X)
				model:SetAttribute("ToyZ", isle.center.Z + flat.Z)
				model:SetAttribute("ToyAt", stamp)
			end
		end
	end
end

-- The profile's side (ShopRequest actions) ------------------------------------------------------------------------------------
local MESSAGES = {
	funds = "Not enough Shinies yet.",
	owned = "You already have that.",
	max = "That is as good as it gets.",
	notowned = "You do not own that.",
	socket = "Pick one of the four spots.",
	unknown = "That does not exist.",
	away = "That pet is already out on an expedition.",
	full = "Every expedition slot is busy (a bigger dock holds more).",
	early = "Not back yet.",
}

local function reply(s, action, outcome, message)
	Net.send(s.player, "ShopResult", {
		action = action,
		ok = outcome.ok,
		code = outcome.code,
		message = message or MESSAGES[outcome.code],
		balance = s.profile.shinies,
	})
end

local function needReady(s, action)
	if Progress.isReady(s) then
		return true
	end
	reply(
		s,
		action,
		{ ok = false, code = "unsaved" },
		"That waits until your saved progress is open (a few seconds after joining)."
	)
	return false
end

local function petOwned(s, id)
	local item = Catalog.get(id)
	return item ~= nil and item.slot == "pet" and Economy.owns(s.profile, id)
end

function Sanctuary.init(portKit)
	kit = portKit
	local root = workspace:FindFirstChild("LootGoblinsGenerated")
	folder = Instance.new("Folder")
	folder.Name = "Sanctuaries"
	folder.Parent = root or workspace
	-- The lift in the Port.
	local built, err = pcall(function()
		local base = kit.at(52, 6, 76)
		kit.part(
			"LiftPlatform",
			v3(10, 1.2, 10),
			base * CFrame.new(0, -0.1, 0),
			Palette.WOOD_LIGHT,
			Enum.Material.WoodPlanks
		)
		kit.deco("LiftBasket", v3(6, 3, 6), base * CFrame.new(0, 2, 0), Palette.WOOD, Enum.Material.WoodPlanks)
		kit.deco(
			"LiftBalloon",
			v3(12, 14, 12),
			base * CFrame.new(0, 17, 0),
			rgb(255, 150, 190),
			Enum.Material.Fabric,
			{ egg = true }
		)
		for _, sx in ipairs({ -1, 1 }) do
			kit.deco("LiftRope", v3(0.2, 9, 0.2), base * CFrame.new(sx * 2.6, 8, 0), Palette.ROPE, Enum.Material.Fabric)
		end
		kit.deco("SkyRope", v3(0.3, 160, 0.3), base * CFrame.new(0, 100, 0), Palette.ROPE, Enum.Material.Fabric)
		kit.board(
			"LiftSign",
			v3(14, 3, 0.4),
			base * CFrame.new(0, 7, 5) * CFrame.Angles(0, math.rad(180), 0),
			"PET SANCTUARY LIFT",
			rgb(255, 180, 210)
		)
		local home = kit.prompt(
			"LiftHome",
			base * CFrame.new(0, 3, 4),
			"Pet Sanctuary Lift",
			"Up to my sanctuary",
			{ SanctuaryAction = "home" },
			12
		)
		local _ = home
		kit.prompt(
			"LiftVisit",
			base * CFrame.new(0, 3, -4),
			"Pet Sanctuary Lift",
			"Visit someone's sanctuary",
			{ OpensPanel = "visit" },
			12
		)
	end)
	if not built then
		warn("[Sanctuary] lift: " .. tostring(err))
	end
	table.insert(Progress.publishers, publish)
	Players.PlayerRemoving:Connect(forget)
	Progress.actions.sanctbuy = function(s, kind, id)
		if not needReady(s, "sanctbuy") then
			return
		end
		local outcome = Habitat.buy(s.profile, kind, id)
		local message
		if outcome.ok then
			Analytics.shinies(s.player, true, outcome.price, s.profile.shinies, "Shop", "sanctuary:" .. tostring(id))
			message = "Your sanctuary has it now!"
			Progress.markChanged(s.player, true)
		elseif outcome.code == "funds" then
			message = string.format("Not enough Shinies yet: %d more to go.", outcome.short or 0)
		end
		reply(s, "sanctbuy", outcome, message)
	end
	Progress.actions.sanctplace = function(s, socket, decor)
		if not needReady(s, "sanctplace") then
			return
		end
		local outcome = Habitat.place(s.profile, tonumber(socket), decor)
		if outcome.ok then
			Progress.markChanged(s.player, false)
		end
		reply(s, "sanctplace", outcome)
	end
	Progress.actions.sancttheme = function(s, theme)
		if not needReady(s, "sancttheme") then
			return
		end
		local outcome = Habitat.setTheme(s.profile, theme)
		if outcome.ok then
			Progress.markChanged(s.player, false)
		end
		reply(s, "sancttheme", outcome)
	end
	Progress.actions.residents = function(s, list)
		if not needReady(s, "residents") then
			return
		end
		local outcome = Habitat.setResidents(s.profile, list, function(id)
			return petOwned(s, id)
		end)
		Progress.markChanged(s.player, false)
		reply(s, "residents", outcome, "Your sanctuary's residents are set.")
	end
	Progress.actions.expsend = function(s, pet, trip)
		if not needReady(s, "expsend") then
			return
		end
		local outcome = Habitat.send(s.profile, pet, trip, unix(), type(pet) == "string" and petOwned(s, pet))
		local message
		if outcome.ok then
			-- A pet on an expedition is not following anyone.
			if s.profile.equipped.pet == pet then
				s.profile.equipped.pet = nil
			end
			local item = Catalog.get(pet)
			local tripDef = Habitat.TRIP_BY_ID[trip]
			message = string.format(
				"%s set off on the %s.",
				item and item.name or "Your pet",
				tripDef and tripDef.name or "expedition"
			)
			Progress.markChanged(s.player, true)
		end
		reply(s, "expsend", outcome, message)
	end
	Progress.actions.expcollect = function(s, id)
		if not needReady(s, "expcollect") then
			return
		end
		local outcome = Habitat.collect(s.profile, tonumber(id), unix())
		local message
		if outcome.ok then
			local item = Catalog.get(outcome.pet)
			if outcome.shinies > 0 then
				message =
					string.format("%s is home with %d Shinies!", item and item.name or "Your pet", outcome.shinies)
				Analytics.shinies(s.player, false, outcome.shinies, s.profile.shinies, "Gameplay", "expedition")
			else
				message = string.format(
					"%s is home. (Today's expedition haul is full: more tomorrow.)",
					item and item.name or "Your pet"
				)
			end
			Progress.milestone(s.player, "FirstExpeditionCollected")
			Progress.record(s.player, "expedition")
			Progress.markChanged(s.player, true)
			Progress.checkAchievements(s.player)
			Net.send(s.player, "PlayFx", { kind = "expeditionhome", pet = outcome.pet, shinies = outcome.shinies })
		elseif outcome.code == "early" then
			message = string.format("Not back yet: %d min to go.", math.ceil((outcome.left or 0) / 60))
		end
		reply(s, "expcollect", outcome, message)
	end
	Progress.actions.exprecall = function(s, id)
		if not needReady(s, "exprecall") then
			return
		end
		local outcome = Habitat.recall(s.profile, tonumber(id))
		if outcome.ok then
			Progress.markChanged(s.player, false)
		end
		reply(s, "exprecall", outcome, outcome.ok and "Called home early (no Shinies for a trip cut short)." or nil)
	end
	-- Prompts on the isles and the lift.
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(pp, player)
		local action = pp:GetAttribute("SanctuaryAction")
		if action then
			Sanctuary.request(player, action)
		end
	end)
end

function Sanctuary.isleOf(player)
	local isle = isles[player]
	return isle and isle.model
end

return Sanctuary

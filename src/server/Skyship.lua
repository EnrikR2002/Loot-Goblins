-- The skyship: every raid starts on a flying pirate ship 540 studs over the sea.
-- Goblins stand on the deck (or walk out along its wings), climb into a cannon (E), LOOK at where
-- they want to come down and fire.
--
-- V13.2: IT FLIES A ROUTE (shared/SkyRoute.lua). It waits at one end of the raid's route for Config.SKYSHIP.PREP
-- seconds (climb in and aim; the cannons are LOCKED, here on the server, and nobody can step off), then crosses the
-- archipelago in PASS seconds. A cannon throws about 1,200 studs across, so what can be reached changes as it flies.
-- An island picked on the map is where the ship fires a goblin still on deck as it passes closest (if that island is in
-- reach on this route at all). When the pass ends anyone still aboard is fired at the best landing in reach. The ship
-- is one welded assembly moved by its Deck (one replicated CFrame a frame; every client also moves its own copy along
-- the same route, so it glides); goblins in a cannon are welded into it and ride along.
--
-- V8: the ship only owns the ship. Its twelve cannons are LAUNCHERS (server/Flight.lua), the same
-- thing an island catapult is, so the aiming, the flight, the bounces and the landings are one system.
-- What is here: the hull, the deck spots, the wings you can walk on, the window, and what happens to
-- a goblin who walks off the edge (a free dive) or who is still aboard at the end (fired off).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Dive = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Dive"))
local Landing = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Landing"))
local SkyRoute = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("SkyRoute"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Flight = require(script.Parent.Flight)

local Skyship = {}

local S = Config.SKYSHIP
local D = Config.DIVE

local model
local shipCFrame -- where the ship is now (V13.2: it moves; the Deck is the assembly's root)
local buildCFrame -- where it was built (its local frame: every spot on it is stored relative to this)
local shipVelocity = Vector3.zero
local deck
local route = nil -- V13.2: { points, opensAt, index, reversed, passBy = { [islandId] = SkyRoute.passBy(...) } }
local routeLanding = {} -- V13.2: island id -> this route's landing spot, checked by flying the throw from where it passes
local landWorld = nil -- the world refs findLandings was given (the per-route search uses them too)
local REACH = SkyRoute.reach()
local cannons = {}
local deckSpawns = {} -- local CFrames on the deck
local aboard = {} -- player -> { spot, autoFor }: goblins who are the ship's business (on deck or in a cannon)
local chosen = {} -- player -> island id picked on the map
local opensAt, endsAt = 0, 0
local boardedFor = 0 -- a counter: a straggler is only auto-fired once per window
local landing = {} -- V12: island id -> where a goblin who picks it comes down (see findLandings)

local HULL_GROUP = Flight.HULL_GROUP

local function now()
	return workspace:GetServerTimeNow()
end

-- Building the ship -----------------------------------------------------------------------------
local WOOD = Color3.fromRGB(150, 98, 58)
local WOOD_LIGHT = Color3.fromRGB(184, 128, 76)
local DARK_WOOD = Color3.fromRGB(88, 56, 36)
local SAIL = Color3.fromRGB(246, 236, 210)
local TRIM = Color3.fromRGB(255, 196, 46)
local RED = Color3.fromRGB(214, 58, 48)

local function part(name, size, cf, color, material, collide, shape)
	local p = Instance.new(shape or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = buildCFrame * cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildCannon(index, x, z, outward)
	part("CannonBase" .. index, Vector3.new(7, 2.4, 9), CFrame.new(x, 2.2, z), DARK_WOOD)
	local yaw = outward > 0 and math.rad(-90) or math.rad(90) -- the barrel's default heading: out over the side
	local localBase = CFrame.new(x, 4.6, z) * CFrame.Angles(0, yaw, 0) -- V13.2: on the ship, wherever it is
	local baseCF = buildCFrame * localBase
	local barrel = Instance.new("Part")
	barrel.Name = "Cannon" .. index
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(11, 4.6, 4.6)
	barrel.Color = Color3.fromRGB(52, 54, 62)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CanTouch = false
	barrel.TopSurface = Enum.SurfaceType.Smooth
	barrel.BottomSurface = Enum.SurfaceType.Smooth
	-- The cylinder's axis is its X: aim X along the launch direction. V13.2: the barrel hangs on a Motor6D from the Deck
	-- (the ship moves), so aiming sets the joint, in the ship's own frame; until the joint exists it is placed directly.
	local localFrom = localBase.Position
	local motor
	local function aimLocal(localDirection)
		local cf = CFrame.lookAt(localFrom, localFrom + localDirection) * CFrame.Angles(0, math.rad(90), 0)
		if motor then
			motor.C0 = cf
		else
			barrel.CFrame = buildCFrame * cf
		end
	end
	local function aim(direction)
		aimLocal((shipCFrame or buildCFrame):VectorToObjectSpace(direction))
	end
	local out = Vector3.new(outward, 0, 0) -- in the ship's frame: out over its own side
	local rest = (out + Vector3.new(0, 0.55, 0)).Unit
	aimLocal(rest)
	barrel.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "CannonRing" .. index
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1, 5.4, 5.4)
	ring.Color = TRIM
	ring.Material = Enum.Material.Metal
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.Parent = model
	local function setRing()
		-- (V13.2: welded to the barrel once the ship is assembled; until then placed beside it.)
		if not ring:FindFirstChild("RingWeld") then
			ring.CFrame = barrel.CFrame * CFrame.new(4.1, 0, 0)
		end
	end
	setRing()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LoadPrompt"
	prompt.ObjectText = "Launch cannon"
	prompt.ActionText = "Climb in"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = barrel
	local mounts = {} -- player -> the weld that holds them in this cannon (V13.2)
	local cannon = Flight.addLauncher({
		kind = "cannon",
		index = index,
		barrel = barrel,
		ring = ring,
		prompt = prompt,
		from = baseCF.Position,
		localFrom = localFrom,
		-- V13.2: the ship moves, so where the throw starts is asked for each time.
		fromFn = function()
			return (shipCFrame or buildCFrame) * localFrom
		end,
		exitFn = function()
			return (shipCFrame or buildCFrame) * (localFrom + Vector3.new(0, 1.5, 0) - out * 7)
		end,
		speed = D.CANNON_SPEED,
		elevation = D.CANNON_ELEVATION,
		-- With nobody aiming it: a point on the sea, out over its own side.
		rest = baseCF.Position + buildCFrame:VectorToWorldSpace(out) * 900 - Vector3.new(0, baseCF.Position.Y, 0),
		restFn = function()
			local from = (shipCFrame or buildCFrame) * localFrom
			local side = (shipCFrame or buildCFrame):VectorToWorldSpace(out)
			return Vector3.new(from.X + side.X * 900, 0, from.Z + side.Z * 900)
		end,
		exit = baseCF.Position + Vector3.new(0, 1.5, 0) - out * 7,
		back = "aboard",
		-- Climbing in with an island picked on the map: it starts pointed there (V13.2: if it is in reach now).
		restFor = function(player)
			local id = chosen[player]
			local spot = id and Skyship.landingFor(id)
			if spot and Skyship.inReach(spot) then
				return spot
			end
			return nil
		end,
		aim = function(direction)
			aim(direction)
			setRing()
		end,
		-- V13.2: a goblin in this cannon is welded into the ship (it moves), posed looking out along the barrel.
		mount = function(player, root)
			local old = mounts[player]
			if old then
				old:Destroy()
			end
			local weld = Instance.new("Weld")
			weld.Name = "CannonSeat"
			weld.Part0 = deck
			weld.Part1 = root
			weld.C0 = CFrame.new(localFrom)
			root.Anchored = false
			weld.Parent = root
			mounts[player] = weld
		end,
		orient = function(player, direction)
			local weld = mounts[player]
			if weld and weld.Parent then
				local d = (shipCFrame or buildCFrame):VectorToObjectSpace(direction)
				weld.C0 = CFrame.lookAt(localFrom - d * 1.5, localFrom + d * 20)
			end
		end,
		unmount = function(player)
			local weld = mounts[player]
			mounts[player] = nil
			if weld then
				weld:Destroy()
			end
		end,
		fired = function(_direction)
			if motor then
				motor.C0 = motor.C0 * CFrame.new(-2, 0, 0)
			end
			task.delay(0.35, function()
				aimLocal(rest)
				setRing()
			end)
		end,
		-- V9: climb in and aim any time you are aboard. V13.2: it fires only once the ship sets off (opensAt), checked
		-- here on the server whatever the client says.
		ready = function(player)
			return aboard[player] ~= nil
		end,
		canFire = function(_player)
			local t = now()
			if workspace:GetAttribute("RaidPhase") ~= "raid" or opensAt <= 0 or t < opensAt then
				local left = opensAt > 0 and math.max(1, math.ceil(opensAt - t)) or 0
				return false,
					left > 0 and ("LOCKED: the cannons fire when the ship sets off, in " .. left .. "...")
						or "The cannons fire when the ship sets off."
			end
			return true
		end,
	})
	cannon.restDirection = rest
	cannon.setMotor = function(m)
		motor = m
	end
	cannon.localRest = rest
	table.insert(cannons, cannon)
end

-- V10: the dressing that makes it the GOLDEN GOBLIN (docs/ART_DIRECTION.md). A rounded hull in three tiers of
-- planking with a gold stripe, a curved prow with a golden goblin figurehead and a bowsprit, a jib, striped
-- sails, rigging, a crow's nest and a pennant, glowing stern windows and lanterns, and two propellers (the
-- clients spin them). Every piece here is decoration: non-colliding and not hit by rays, so the deck, the
-- wings, the cannons and the aim are exactly what they were.
local function line(name, a, b, width, color)
	local mid = (a + b) / 2
	local p = part(
		name,
		Vector3.new(width, width, (b - a).Magnitude),
		CFrame.lookAt(mid, b),
		color,
		Enum.Material.Wood,
		false
	)
	p.CastShadow = false
	return p
end

local function dressShip()
	local B = S.BEAM
	for _, side in ipairs({ -1, 1 }) do
		-- The hull's belly: three tiers of planking curving in toward the keel.
		part(
			"HullSide",
			Vector3.new(2.6, 7, 116),
			CFrame.new(side * 22.4, -2.8, 0) * CFrame.Angles(0, 0, side * math.rad(-14)),
			WOOD_LIGHT,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullSide",
			Vector3.new(2.6, 7, 108),
			CFrame.new(side * 19.2, -8.8, 1) * CFrame.Angles(0, 0, side * math.rad(-32)),
			WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullSide",
			Vector3.new(2.6, 6, 96),
			CFrame.new(side * 14.6, -13.6, 2) * CFrame.Angles(0, 0, side * math.rad(-50)),
			DARK_WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"HullStripe",
			Vector3.new(0.7, 1.4, 117),
			CFrame.new(side * 23.5, -0.9, 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		-- The prow: two panels closing to a point under the bow.
		part(
			"BowHull",
			Vector3.new(2.6, 11, 36),
			CFrame.new(side * 8.4, -4.5, -84) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(-14)),
			WOOD_LIGHT,
			Enum.Material.WoodPlanks,
			false
		)
		part(
			"BowStripe",
			Vector3.new(0.7, 1.4, 36),
			CFrame.new(side * 9.9, -0.9, -84) * CFrame.Angles(0, side * math.rad(-25), 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		-- Stern lanterns on the quarterdeck's corners.
		part(
			"SternPost",
			Vector3.new(0.9, 7, 0.9),
			CFrame.new(side * 20.5, 10.5, 86),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)
		local lamp = part(
			"SternLamp",
			Vector3.new(2, 2, 2),
			CFrame.new(side * 20.5, 14.6, 86),
			Color3.fromRGB(255, 206, 120),
			Enum.Material.Neon,
			false
		)
		lamp.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Range = 34
		light.Brightness = 1.4
		light.Parent = lamp
	end
	-- The figurehead: a golden goblin leaning out over the clouds, ears back.
	local head = part("FigureHead", Vector3.new(6, 6, 6), CFrame.new(0, -0.5, -101), TRIM, Enum.Material.Metal, false)
	head.Shape = Enum.PartType.Ball
	part(
		"FigureBody",
		Vector3.new(5, 6, 4),
		CFrame.new(0, -5, -99) * CFrame.Angles(math.rad(-20), 0, 0),
		TRIM,
		Enum.Material.Metal,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		part(
			"FigureEar",
			Vector3.new(0.8, 3, 5),
			CFrame.new(side * 3.6, 1.2, -99.5)
				* CFrame.Angles(math.rad(-25), side * math.rad(-30), side * math.rad(-35)),
			TRIM,
			Enum.Material.Metal,
			false
		)
		local eye = part(
			"FigureEye",
			Vector3.new(1, 1, 1),
			CFrame.new(side * 1.4, 0.4, -103.8),
			Color3.fromRGB(110, 255, 210),
			Enum.Material.Neon,
			false
		)
		eye.Shape = Enum.PartType.Ball
	end
	-- Bowsprit and jib.
	part(
		"Bowsprit",
		Vector3.new(1.8, 1.8, 36),
		CFrame.new(0, 8, -106) * CFrame.Angles(math.rad(20), 0, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	local jib =
		part("Jib", Vector3.new(0.5, 40, 66), CFrame.new(0, 25, -76), SAIL, Enum.Material.Fabric, false, "WedgePart")
	jib.Transparency = 0.04
	-- Sails: a red band and a gold hem on each; a crow's nest and a pennant on the mainmast.
	for i, z in ipairs({ -42, -4, 40 }) do
		local height = i == 2 and 96 or 78
		part(
			"SailBand",
			Vector3.new(B * 1.3 + 0.2, height * 0.07, 0.9),
			CFrame.new(0, height * 0.6, z - 0.8),
			RED,
			Enum.Material.Fabric,
			false
		)
		part(
			"SailHem",
			Vector3.new(B * 1.3 + 0.2, 1.2, 0.9),
			CFrame.new(0, height * 0.27, z - 0.8),
			TRIM,
			Enum.Material.Fabric,
			false
		)
		-- Rigging from the masthead down to the rails, fore and aft on both sides.
		for _, side in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -16, 14 }) do
				line(
					"Rigging",
					Vector3.new(0, height - 2, z),
					Vector3.new(side * (B / 2 - 1), 3, z + dz),
					0.3,
					DARK_WOOD
				)
			end
		end
	end
	local nest = part(
		"CrowsNest",
		Vector3.new(2, 8, 8),
		CFrame.new(0, 80, -4) * CFrame.Angles(0, 0, math.rad(90)),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	nest.Shape = Enum.PartType.Cylinder
	part("Pennant", Vector3.new(0.3, 3.4, 20), CFrame.new(0, 99, 6), TRIM, Enum.Material.Fabric, false)
	part("PennantTip", Vector3.new(0.3, 2.4, 6), CFrame.new(0, 99, 18.5), RED, Enum.Material.Fabric, false)
	-- Glowing stern windows.
	for _, x in ipairs({ -14, -7, 0, 7, 14 }) do
		part(
			"SternWindow",
			Vector3.new(3.4, 4, 0.4),
			CFrame.new(x, 11.5, 89.2),
			Color3.fromRGB(255, 214, 130),
			Enum.Material.Neon,
			false
		)
	end
	-- Two propellers under the stern. The server only builds them; every client spins its own (Skyship.lua).
	for _, side in ipairs({ -1, 1 }) do
		local hub = part(
			"PropellerHub",
			Vector3.new(4, 3, 3),
			CFrame.new(side * 15, -7, 93) * CFrame.Angles(0, math.rad(90), 0),
			TRIM,
			Enum.Material.Metal,
			false
		)
		hub.Shape = Enum.PartType.Cylinder
		hub:SetAttribute("Spin", side)
		for k = 0, 2 do
			local blade = part(
				"PropellerBlade",
				Vector3.new(2.4, 12, 0.8),
				CFrame.new(side * 15, -7, 94.5)
					* CFrame.Angles(0, 0, math.rad(k * 120))
					* CFrame.new(0, 6, 0)
					* CFrame.Angles(0, math.rad(20), 0),
				DARK_WOOD,
				Enum.Material.Wood,
				false
			)
			blade:SetAttribute("Spin", side)
		end
	end
end

-- V11: Madame Ragwort's wardrobe, a tailor's stall on the quarterdeck where every raid begins, so a goblin waiting for
-- the cannons sees the shop. Decoration only (nothing here is solid or hit by rays); its prompt opens the wardrobe on
-- the client (client/Shop.lua listens for prompts with the OpensWardrobe attribute).
local function buildWardrobe()
	local x, z = -13, 72
	local SKIN = Color3.fromRGB(126, 184, 72)
	local function ball(name, size, cf, color, material)
		local p = part(name, size, cf, color, material or Enum.Material.SmoothPlastic, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	part(
		"WardrobeCounter",
		Vector3.new(8, 3, 2.4),
		CFrame.new(x, 8.5, z - 2),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks,
		false
	)
	part(
		"WardrobeCounterTop",
		Vector3.new(8.6, 0.4, 2.8),
		CFrame.new(x, 10.2, z - 2),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	for _, px in ipairs({ -3.8, 3.8 }) do
		for _, pz in ipairs({ -3.2, 3.6 }) do
			part(
				"WardrobePost",
				Vector3.new(0.5, 7.4, 0.5),
				CFrame.new(x + px, 10.7, z + pz),
				DARK_WOOD,
				Enum.Material.Wood,
				false
			)
		end
	end
	for i = 0, 4 do
		part(
			"WardrobeAwning",
			Vector3.new(1.8, 0.3, 8.2),
			CFrame.new(x - 3.6 + i * 1.8, 14.6, z + 0.2) * CFrame.Angles(math.rad(14), 0, 0),
			i % 2 == 0 and RED or Color3.fromRGB(246, 240, 226),
			Enum.Material.Fabric,
			false
		)
	end
	-- The tailor: a stout goblin in spectacles with a tape measure round her neck.
	ball(
		"RagwortBody",
		Vector3.new(2.4, 2.8, 1.9),
		CFrame.new(x, 11.4, z + 0.4),
		Color3.fromRGB(150, 70, 140),
		Enum.Material.Fabric
	)
	ball("RagwortHead", Vector3.new(1.7, 1.6, 1.6), CFrame.new(x, 13.4, z + 0.3), SKIN)
	ball("RagwortNose", Vector3.new(0.5, 0.5, 0.9), CFrame.new(x, 13.3, z - 0.6), SKIN)
	ball("RagwortBun", Vector3.new(1.1, 1, 1.1), CFrame.new(x, 14.4, z + 0.6), Color3.fromRGB(196, 196, 214))
	part(
		"RagwortTape",
		Vector3.new(0.25, 2.2, 0.08),
		CFrame.new(x - 0.45, 12.3, z - 0.55),
		Color3.fromRGB(255, 214, 60),
		Enum.Material.Fabric,
		false
	)
	part(
		"RagwortTape",
		Vector3.new(0.25, 2.2, 0.08),
		CFrame.new(x + 0.45, 12.3, z - 0.55),
		Color3.fromRGB(255, 214, 60),
		Enum.Material.Fabric,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		local ear = part(
			"RagwortEar",
			Vector3.new(0.25, 0.7, 1.4),
			CFrame.new(x + side * 1.15, 13.6, z + 0.4)
				* CFrame.Angles(0, math.rad(180 + side * -20), side * math.rad(-62)),
			SKIN,
			Enum.Material.SmoothPlastic,
			false,
			"WedgePart"
		)
		ear.CastShadow = false
		local lens = part(
			"RagwortLens",
			Vector3.new(0.08, 0.42, 0.42),
			CFrame.new(x + side * 0.32, 13.65, z - 0.52) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(220, 240, 255),
			Enum.Material.Glass,
			false
		)
		lens.Shape = Enum.PartType.Cylinder
		lens.Transparency = 0.35
		ball("RagwortHand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + side * 1.3, 10.9, z - 0.9), SKIN)
	end
	-- Stock on the counter and a rack: hats, a folded coat, a little boat flag.
	local tricorn = part(
		"StockHat",
		Vector3.new(1.5, 0.5, 1.5),
		CFrame.new(x - 2.4, 10.7, z - 2.2),
		Color3.fromRGB(40, 32, 38),
		Enum.Material.Fabric,
		false
	)
	tricorn.Shape = Enum.PartType.Cylinder
	tricorn.CFrame = buildCFrame * CFrame.new(x - 2.4, 10.7, z - 2.2) * CFrame.Angles(0, 0, math.rad(90))
	part(
		"StockCoat",
		Vector3.new(1.8, 0.5, 1.2),
		CFrame.new(x + 2.2, 10.65, z - 2.1),
		Color3.fromRGB(176, 36, 40),
		Enum.Material.Fabric,
		false
	)
	ball("StockCrown", Vector3.new(0.9, 0.6, 0.9), CFrame.new(x + 2.2, 11.1, z - 2.1), TRIM, Enum.Material.Metal)
	part("RackPole", Vector3.new(0.35, 7, 0.35), CFrame.new(x + 6.2, 10.5, z + 1), DARK_WOOD, Enum.Material.Wood, false)
	part(
		"RackArm",
		Vector3.new(2.6, 0.25, 0.25),
		CFrame.new(x + 6.2, 13.6, z + 1),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	part(
		"RackCape",
		Vector3.new(1.6, 3, 0.15),
		CFrame.new(x + 5.5, 12, z + 1.1),
		Color3.fromRGB(70, 110, 200),
		Enum.Material.Fabric,
		false
	)
	part(
		"RackSack",
		Vector3.new(1.2, 1.5, 1),
		CFrame.new(x + 7, 12.4, z + 1.1),
		Color3.fromRGB(178, 142, 92),
		Enum.Material.Fabric,
		false
	)
	-- The sign.
	local board = part(
		"WardrobeSign",
		Vector3.new(8.4, 1.8, 0.3),
		CFrame.new(x, 16.3, z - 3.6),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = board
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.Text = "WARDROBE"
	signLabel.TextColor3 = TRIM
	signLabel.TextScaled = true
	signLabel.Parent = signGui
	-- V13: no prompt any more. Shopping lives in the Port (her real shop is on its south street); the stall stays as
	-- the ship's dressing, so a raid's deck is about the cannons.
end

-- V12: where a goblin who picks an island comes down. Through V11 a pick (the map, the ship's own auto-fire)
-- aimed at the island's middle at sea level, which is often water: the throw came down in the sea beside the
-- island and skipped three times on past it (measured: 390 studs beyond Pebble Isle's treasure). Now each
-- island has one spot: dry, level, open ground (no roof, no lava) as near its treasure as there is, looked for
-- first on the ship's side so the arc comes in over the sea. Every machine reads the same spot (published on
-- the generated folder as `Land_<id>`), so the map's pick, the cannon's first aim, the beam and the auto-fire
-- agree. Aiming by hand is unchanged: a goblin can still look anywhere and land anywhere.
local function insideLava(position, zones)
	for _, zone in ipairs(zones or {}) do
		local p = zone.part
		if p and p.Parent then
			local localPos = p.CFrame:PointToObjectSpace(position)
			local half = p.Size / 2 + Vector3.new(6, 6, 6)
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- From high in the sky, so a spot under an overhang, a cave roof or a building is never chosen.
local SKY = 900
local function findLandings(worldRefs)
	if not worldRefs or not worldRefs.lootSpots then
		return
	end
	local folders = worldRefs.folders
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, folders.ground, folders.structures }
	params.IgnoreWater = false
	for id in pairs(Config.ISLAND_INFO) do
		local spot
		for _, def in ipairs(Config.LOOT) do
			if def.island == id and worldRefs.lootSpots[def.id] then
				spot = worldRefs.lootSpots[def.id].Position
				break
			end
		end
		-- V12: an island whose treasure is under a roof (Crystal Isle's Heart) names where to aim instead.
		local hint = spot and worldRefs.landingHints and worldRefs.landingHints[id]
		if hint then
			spot = hint
		end
		if spot then
			local function good(point, pass)
				local hit = workspace:Raycast(Vector3.new(point.X, SKY, point.Z), Vector3.new(0, -SKY - 100, 0), params)
				return hit
					and Landing.acceptable({
						y = hit.Position.Y,
						normalY = hit.Normal.Y,
						water = hit.Material == Enum.Material.Water,
						structure = hit.Instance:IsDescendantOf(folders.structures),
						lava = insideLava(hit.Position, worldRefs.lavaZones),
					}, spot.Y, pass.sea)
					and hit.Position
			end
			local found
			for _, pass in ipairs(Landing.PASSES) do
				local points = Landing.candidates(spot, buildCFrame.Position)
				if hint then
					table.insert(points, 1, hint) -- the hint itself first
				end
				for _, point in ipairs(points) do
					local at = good(point, pass)
					if at then
						-- V12: dry ground all round it, and no water just before it on the way in (a throw comes down
						-- a little short): slopes, rocks and roofs are fine there, the sea and lava are not.
						local apron = true
						local around = Landing.apron(point, pass.apron)
						for _, back in ipairs(Landing.approach(point, buildCFrame.Position, pass.approach)) do
							table.insert(around, back)
						end
						for _, other in ipairs(around) do
							local hit = workspace:Raycast(
								Vector3.new(other.X, SKY, other.Z),
								Vector3.new(0, -SKY - 100, 0),
								params
							)
							if
								not hit
								or hit.Material == Enum.Material.Water
								or hit.Position.Y < spot.Y - Landing.BELOW
								or insideLava(hit.Position, worldRefs.lavaZones)
							then
								apron = false
								break
							end
						end
						if apron then
							found = at
							break
						end
					end
				end
				if found then
					break
				end
			end
			landing[id] = found or spot
			folders.root:SetAttribute("Land_" .. id, landing[id])
		end
	end
end

-- V13.2: where a throw from `from` (a cannon in the air) aimed at `target` really comes down: the flight on Dive's own
-- rules, a 30th of a second at a time, stopped by the first solid thing (or the sea) its path meets, the way the
-- goblin's own client flies and stops it. Returns the touch point and whether it is water, or nil (out of reach).
local THROW_BODY = 3 -- studs: the radius of a tumbling goblin, limbs and all
local throwParams = RaycastParams.new()
throwParams.FilterType = Enum.RaycastFilterType.Include
throwParams.IgnoreWater = false
local function throwLands(from, target)
	local velocity, reach = Dive.solve(from, target, D.CANNON_ELEVATION, D.CANNON_SPEED)
	if not reach then
		return nil
	end
	local position, dt = from, 1 / 30
	for _ = 1, 30 * 30 do
		velocity = Dive.step(velocity, Vector3.zero, "tumble", dt)
		local step = velocity * dt
		-- A goblin is not a point: sweep a body-sized ball (a thin ray slipped over a hill's crest the real goblin hit,
		-- and the real throw slid 59 studs down to the beach: measured in Studio).
		local hit = workspace:Spherecast(position, THROW_BODY, step, throwParams)
		if hit then
			return hit.Position, hit.Material == Enum.Material.Water
		end
		position += step
		if position.Y < -10 then
			return position, true
		end
	end
	return nil
end
Skyship.throwLands = throwLands

-- A landing is GOOD from `from` if a throw at it comes down on dry ground near it.
local LAND_NEAR = 22
local function landsWell(from, spot)
	local at, water = throwLands(from, spot)
	return at ~= nil and not water and Vector3.new(at.X - spot.X, 0, at.Z - spot.Z).Magnitude <= LAND_NEAR
end

-- Where a pick of island `id` comes down: this raid's route's landing spot (V13.2), else its landing spot, or (an
-- island with no treasure) its middle.
function Skyship.landingFor(id)
	local island = id and Archipelago.byId[id]
	if not island then
		return nil
	end
	return routeLanding[id] or landing[id] or Vector3.new(island.x, 0, island.z)
end

-- V13.2: the route decides where the throws come from, so each island's landing is chosen again for it: from where the
-- ship passes it (its closest pass), the island's usual spot if a throw from there comes down on it, else the first
-- spot round the treasure (the same strict, then loose, rules: dry, level, open, an apron of good ground) that a throw
-- from there does come down on. Done a little at a time, while the Port waits. Islands it cannot fix keep their spot.
local function planLandings(points, token)
	if not landWorld or not landWorld.lootSpots then
		return
	end
	local folders = landWorld.folders
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, folders.ground, folders.structures }
	params.IgnoreWater = false
	local checked, fixed = 0, 0
	for id, info in pairs(Config.ISLAND_INFO) do
		if token ~= route.token then
			return
		end
		local pass = info.major and route.passBy[id]
		local usual = landing[id]
		if pass and pass.from and usual then
			checked += 1
			local from = SkyRoute.cframeAt(points, 0, pass.at).Position + Vector3.new(0, 4.6, 0)
			if not landsWell(from, usual) then
				local treasure
				for _, def in ipairs(Config.LOOT) do
					if def.island == id and landWorld.lootSpots[def.id] then
						treasure = landWorld.lootSpots[def.id].Position
						break
					end
				end
				treasure = (landWorld.landingHints and landWorld.landingHints[id]) or treasure or usual
				local tries = 0
				for _, pass2 in ipairs(Landing.PASSES) do
					for _, point in ipairs(Landing.candidates(treasure, from)) do
						local hit =
							workspace:Raycast(Vector3.new(point.X, SKY, point.Z), Vector3.new(0, -SKY - 100, 0), params)
						if
							hit
							and Landing.acceptable({
								y = hit.Position.Y,
								normalY = hit.Normal.Y,
								water = hit.Material == Enum.Material.Water,
								structure = hit.Instance:IsDescendantOf(folders.structures),
								lava = insideLava(hit.Position, landWorld.lavaZones),
							}, treasure.Y, pass2.sea)
						then
							tries += 1
							if landsWell(from, hit.Position) then
								routeLanding[id] = hit.Position
								fixed += 1
								break
							end
							if tries >= 14 then
								break
							end
						end
					end
					if routeLanding[id] or tries >= 14 then
						break
					end
				end
			end
			if routeLanding[id] then
				folders.root:SetAttribute("Land_" .. id, routeLanding[id])
			end
			task.wait()
		end
	end
	route.landingsChecked = { checked = checked, moved = fixed }
end

-- V13.2: the ship becomes ONE assembly: its Deck stays anchored as the root and everything else is welded to it, so
-- moving the Deck moves the whole ship (one CFrame to replicate, not four hundred). The cannon barrels hang on Motor6Ds
-- (aiming moves the joint, not the ship), their rings are welded to the barrels, and the propeller hubs hang on Motor6Ds
-- each client turns for itself (client/Skyship.lua).
local function assemble()
	deck = model:FindFirstChild("Deck")
	local barrels, rings, hubs = {}, {}, {}
	for _, c in ipairs(cannons) do
		barrels[c.barrel] = c
		rings[c.ring] = c.barrel
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= deck and p.Name == "PropellerHub" then
			hubs[p:GetAttribute("Spin")] = p
		end
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= deck then
			if barrels[p] then
				local m = Instance.new("Motor6D")
				m.Name = "Aim"
				m.Part0 = deck
				m.Part1 = p
				m.C0 = deck.CFrame:ToObjectSpace(p.CFrame)
				m.C1 = CFrame.new()
				m.Parent = p
				barrels[p].setMotor(m)
			elseif rings[p] then
				local w = Instance.new("WeldConstraint")
				w.Name = "RingWeld"
				w.Part0 = rings[p]
				w.Part1 = p
				w.Parent = p
			elseif p.Name == "PropellerHub" then
				local m = Instance.new("Motor6D")
				m.Name = "Spin"
				m.Part0 = deck
				m.Part1 = p
				m.C0 = deck.CFrame:ToObjectSpace(p.CFrame)
				m.C1 = CFrame.new()
				m.Parent = p
			elseif p.Name == "PropellerBlade" and hubs[p:GetAttribute("Spin")] then
				local w = Instance.new("WeldConstraint")
				w.Part0 = hubs[p:GetAttribute("Spin")]
				w.Part1 = p
				w.Parent = p
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = deck
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
			p.Massless = true
		end
	end
	deck.Anchored = true
end

function Skyship.build(worldRefs)
	local old = workspace:FindFirstChild("LootGoblinsGenerated")
	local landmarks = old and old:FindFirstChild("Landmarks") or workspace
	buildCFrame = CFrame.new(S.POSITION)
	shipCFrame = nil
	model = Instance.new("Model")
	model.Name = "Skyship"

	-- The deck, bow and stern.
	part("Deck", Vector3.new(S.BEAM, 2, 118), CFrame.new(0, 0, 0), WOOD)
	part("BowDeck", Vector3.new(S.BEAM * 0.62, 2, 22), CFrame.new(0, 0, -70), WOOD)
	part("BowTip", Vector3.new(S.BEAM * 0.3, 2, 18), CFrame.new(0, 0, -89), WOOD)
	part("QuarterDeck", Vector3.new(S.BEAM, 2, 30), CFrame.new(0, 6, 72), WOOD)
	part("QuarterStep", Vector3.new(S.BEAM, 6, 2), CFrame.new(0, 3, 56), DARK_WOOD)
	part("QuarterRamp", Vector3.new(14, 2, 16), CFrame.new(0, 3, 50) * CFrame.Angles(math.rad(22), 0, 0), WOOD)
	part("SternWall", Vector3.new(S.BEAM + 2, 14, 2), CFrame.new(0, 13, 88), DARK_WOOD)
	-- The hull under it: shapes only, nothing to bump into, narrower than the deck so a goblin who
	-- hops the rail falls clear of it.
	part("Keel", Vector3.new(S.BEAM * 0.55, 14, 128), CFrame.new(0, -8, 4), DARK_WOOD, nil, false)
	part("KeelBow", Vector3.new(S.BEAM * 0.3, 10, 24), CFrame.new(0, -6, -76), DARK_WOOD, nil, false)
	part("HullBand", Vector3.new(S.BEAM * 0.8, 2, 124), CFrame.new(0, -1.2, 2), TRIM, Enum.Material.Metal, false)
	-- The rails: low walls along both sides with the cannons set into them.
	for _, side in ipairs({ -1, 1 }) do
		-- V8: a gate amidships on each side opens onto the wing.
		part("Rail", Vector3.new(1, 4, 52), CFrame.new(side * (S.BEAM / 2 - 0.5), 3, -32), DARK_WOOD)
		part("Rail", Vector3.new(1, 4, 52), CFrame.new(side * (S.BEAM / 2 - 0.5), 3, 32), DARK_WOOD)
		for _, z in ipairs({ -6, 6 }) do
			part(
				"GatePost",
				Vector3.new(1.6, 7, 1.6),
				CFrame.new(side * (S.BEAM / 2 - 0.5), 4.5, z),
				TRIM,
				Enum.Material.Metal
			)
		end
		part(
			"RailBow",
			Vector3.new(1, 4, 26),
			CFrame.new(side * 7, 3, -76) * CFrame.Angles(0, side * math.rad(-24), 0),
			DARK_WOOD
		)
	end
	-- Three masts, their yards and sails; a figurehead.
	for i, z in ipairs({ -42, -4, 40 }) do
		local height = i == 2 and 96 or 78
		local mast = part(
			"Mast" .. i,
			Vector3.new(height, 3.2, 3.2),
			CFrame.new(0, 1 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			DARK_WOOD,
			nil,
			false,
			"Part"
		)
		mast.Shape = Enum.PartType.Cylinder
		local yard =
			part("Yard" .. i, Vector3.new(S.BEAM * 1.5, 1.8, 1.8), CFrame.new(0, height - 6, z), DARK_WOOD, nil, false)
		yard.Shape = Enum.PartType.Cylinder
		yard.CFrame = buildCFrame * CFrame.new(0, height - 6, z) * CFrame.Angles(0, 0, 0)
		local sail = part(
			"Sail" .. i,
			Vector3.new(S.BEAM * 1.3, height * 0.5, 0.8),
			CFrame.new(0, height * 0.52, z - 0.8),
			SAIL,
			Enum.Material.Fabric,
			false
		)
		sail.Transparency = 0.04
		local emblem = part(
			"Emblem" .. i,
			Vector3.new(0.9, 11, 11),
			CFrame.new(0, height * 0.52, z - 1.4),
			Color3.fromRGB(30, 30, 38),
			Enum.Material.Fabric,
			false
		)
		emblem.Shape = Enum.PartType.Cylinder
		emblem.CFrame = buildCFrame * CFrame.new(0, height * 0.52, z - 1.4) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- Wings and lift. V8: the wings are DECK. Each one is a broad canvas-and-spar platform level with
	-- the main deck at the gate and rising a little toward its tip, where a diving board sticks out
	-- over nothing. Walk out, look down at the whole sea, and step off (a free dive) or go back for a
	-- cannon. Nothing rails them in: falling off a wing is a way off the ship, not an accident.
	local WING_SPAN, WING_RISE = 40, math.rad(8)
	for _, side in ipairs({ -1, 1 }) do
		local lift = CFrame.Angles(0, 0, side * WING_RISE)
		local midX = side * (S.BEAM / 2 + WING_SPAN / 2 * math.cos(WING_RISE))
		local midY = 0.4 + WING_SPAN / 2 * math.sin(WING_RISE)
		local wing =
			part("Wing", Vector3.new(WING_SPAN, 1.2, 64), CFrame.new(midX, midY, 2) * lift, SAIL, Enum.Material.Fabric)
		wing.Transparency = 0.05
		for _, z in ipairs({ -30, -9, 13, 34 }) do
			part(
				"WingSpar",
				Vector3.new(WING_SPAN + 2, 1.6, 2),
				CFrame.new(midX, midY - 0.2, z) * lift,
				TRIM,
				Enum.Material.Metal
			)
		end
		-- The walkway from the gate to the tip, in planks, and the board beyond it.
		part(
			"WingWalk",
			Vector3.new(WING_SPAN, 0.5, 9),
			CFrame.new(midX, midY + 0.75, 0) * lift,
			WOOD,
			Enum.Material.WoodPlanks
		)
		local tipX = side * (S.BEAM / 2 + WING_SPAN * math.cos(WING_RISE))
		local tipY = 0.4 + WING_SPAN * math.sin(WING_RISE)
		part(
			"DivingBoard",
			Vector3.new(16, 0.8, 5),
			CFrame.new(tipX + side * 7, tipY + 0.9, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		local lantern = part(
			"WingLantern",
			Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(tipX + side * 14.5, tipY + 2.6, 0),
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon,
			false
		)
		lantern.Shape = Enum.PartType.Ball
	end
	local glow = part(
		"Belly",
		Vector3.new(26, 4, 70),
		CFrame.new(0, -15.5, 4),
		Color3.fromRGB(120, 230, 255),
		Enum.Material.Neon,
		false
	)
	glow.Transparency = 0.25
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 26) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.Rate = 14
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = glow
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(150, 235, 255)
	lamp.Range = 40
	lamp.Brightness = 2
	lamp.Parent = glow

	-- Cannons: six a side, set into the rails.
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -50, -30, -10, 10, 30, 50 }) do
			index += 1
			buildCannon(index, side * (S.BEAM / 2 - 5), z, side)
		end
	end
	-- A sign, the way it is in a game: what this is.
	local sign = part("Sign", Vector3.new(26, 7, 1), CFrame.new(0, 12, 86), DARK_WOOD, Enum.Material.WoodPlanks, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "THE GOLDEN GOBLIN"
	label.TextColor3 = TRIM
	label.TextScaled = true
	label.Parent = gui

	dressShip()
	buildWardrobe()

	-- Where goblins stand when they arrive: a loose grid on the main deck (in the ship's frame: V13.2).
	for row = 0, 5 do
		for col = 0, 5 do
			table.insert(deckSpawns, CFrame.new(-10 + col * 4, 4.4, -22 + row * 7))
		end
	end
	model.PrimaryPart = model:FindFirstChild("Deck")
	assemble()
	shipCFrame = buildCFrame
	model.Parent = landmarks
	-- Everything on the ship is in the Landmarks folder, which streams as persistent, so it is in
	-- view from the first frame wherever the goblin is.
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
			p.CollisionGroup = HULL_GROUP
		end
	end
	for _, c in ipairs(cannons) do
		c.barrel.CastShadow = true
	end
	findLandings(worldRefs)
	landWorld = worldRefs
	throwParams.FilterDescendantsInstances =
		{ workspace.Terrain, worldRefs.folders.ground, worldRefs.folders.structures }
	-- Between raids it waits at the start of a route (the Port shows the next one: Skyship.plan).
	Skyship.plan(1, false)
end

-- V13.2: the route the NEXT raid will fly (chosen in the Port, so it can be shown there): the ship goes to its start.
function Skyship.plan(index, reversed)
	local points = SkyRoute.points(index, reversed)
	if not points then
		return
	end
	local token = (route and route.token or 0) + 1
	route = { points = points, index = index, reversed = reversed, opensAt = math.huge, passBy = {}, token = token }
	-- Back to every island's usual spot, then (in the background) the ones this route needs moved.
	for id in pairs(routeLanding) do
		if landWorld and landing[id] then
			landWorld.folders.root:SetAttribute("Land_" .. id, landing[id])
		end
	end
	table.clear(routeLanding)
	for id in pairs(Config.ISLAND_INFO) do
		local spot = Skyship.landingFor(id)
		if spot then
			route.passBy[id] = SkyRoute.passBy(points, spot.X, spot.Z, SkyRoute.reach(spot.Y))
		end
	end
	task.spawn(planLandings, points, token)
	workspace:SetAttribute("SkyRoute", index)
	workspace:SetAttribute("SkyRouteReversed", reversed or nil)
	workspace:SetAttribute("SkyRouteOpensAt", nil)
	shipCFrame = SkyRoute.cframeAt(points, math.huge, 0)
	if deck then
		deck.CFrame = shipCFrame
	end
end

-- V13.2: is a point in reach of the ship's cannons right now?
function Skyship.inReach(point)
	if not shipCFrame then
		return false
	end
	local p = shipCFrame.Position
	return Vector3.new(point.X - p.X, 0, point.Z - p.Z).Magnitude <= SkyRoute.reach(point.Y)
end

-- V13.2: is this island in reach at some point on this raid's route? (nil if no route is planned)
function Skyship.reachable(id)
	local pass = route and route.passBy[id]
	return pass ~= nil and pass.from ~= nil
end

-- V13.2: the island whose landing spot is nearest the ship and in reach now (the straggler's auto-fire), or nil.
function Skyship.bestInReach(preferred, from)
	from = from or (shipCFrame.Position + Vector3.new(0, 4.6, 0))
	if preferred then
		local spot = Skyship.landingFor(preferred)
		if spot and Skyship.inReach(spot) and landsWell(from, spot) then
			return preferred, spot
		end
	end
	-- Nearest first, and only one a throw from here really comes down on (a few tries at most).
	local list = {}
	local p = shipCFrame.Position
	for id, info in pairs(Config.ISLAND_INFO) do
		local spot = info.major and Skyship.landingFor(id)
		if spot then
			local gap = Vector3.new(spot.X - p.X, 0, spot.Z - p.Z).Magnitude
			if gap <= SkyRoute.reach(spot.Y) then
				table.insert(list, { id = id, spot = spot, gap = gap })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.gap < b.gap
	end)
	for i, entry in ipairs(list) do
		if i > 4 then
			break
		end
		if landsWell(from, entry.spot) then
			return entry.id, entry.spot
		end
	end
	return list[1] and list[1].id, list[1] and list[1].spot
end

-- For tests and the playtest hook: how this route's landings were checked.
function Skyship.routeLandings()
	return route and route.landingsChecked, routeLanding
end

-- For tests and the map: the ship's CFrame and velocity now, and the cannons' reach.
function Skyship.where()
	return shipCFrame, shipVelocity, REACH
end

-- Goblins ---------------------------------------------------------------------------------------
-- Put a goblin on the deck. `since` (optional) keeps the time of the first attempt when this is a retry.
function Skyship.board(player, since)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return
	end
	Flight.forget(player)
	Poltergoblin.finish(player, "cancel")
	local seat = humanoid.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	local i = (#Players:GetPlayers() > 0 and (player.UserId % #deckSpawns) or 0) + 1
	local spot = deckSpawns[i] -- (V13.2: a spot in the ship's frame)
	-- Spread: find a spot nobody is standing on.
	for step = 0, #deckSpawns - 1 do
		local candidate = deckSpawns[(i + step - 1) % #deckSpawns + 1]
		local taken = false
		for other, entry in pairs(aboard) do
			if other ~= player and entry.spot == candidate then
				taken = true
				break
			end
		end
		if not taken then
			spot = candidate
			break
		end
	end
	-- boardedAt: a goblin who was at a boat's wheel a moment ago is still held in that seat on their own
	-- client, and the move to the deck can be undone by it (a test saw one put aboard, snap back to the sea
	-- and "dive" into the seabed). The tick below puts them aboard again until it takes.
	aboard[player] = { spot = spot, boardedAt = since or now() }
	-- V12: a goblin who arrives late in the window (a join, a respawn) still gets MIN_DECK seconds on the deck.
	-- V13.2: one who arrives after the pass rides the next lap for LATE_DECK seconds.
	local t0 = since or now()
	local by = t0 < endsAt and math.max(endsAt, t0 + S.MIN_DECK) or t0 + S.LATE_DECK
	player:SetAttribute("LaunchBy", workspace:GetAttribute("RaidPhase") == "raid" and endsAt > 0 and by or nil)
	aboard[player].by = by
	root.Anchored = false
	humanoid.PlatformStand = false
	root.CFrame = shipCFrame * spot * CFrame.Angles(0, math.rad(180), 0)
	root.AssemblyLinearVelocity = Vector3.zero
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", "aboard")
end

-- V13: the goblins setting off from the Port (server/Raid.lua decides who), all aboard together.
function Skyship.boardList(players)
	for _, player in ipairs(players) do
		Skyship.board(player)
	end
end

-- V11: is this goblin the ship's business (on the deck or in a cannon)? Pets may be changed aboard.
function Skyship.isAboard(player)
	return aboard[player] ~= nil
end

function Skyship.isDeploying()
	return now() < endsAt
end

-- A character just spawned (first load, or a respawn): it is nobody's flight yet. (V13: where it goes, the skyship,
-- Goblin Cove or the Port, is server/Raid.lua's call: Raid.placeCharacter.)
function Skyship.onCharacter(player)
	Flight.forget(player)
	aboard[player] = nil
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", nil)
end

function Skyship.forget(player)
	Flight.forget(player)
	aboard[player] = nil
	chosen[player] = nil
end

-- The raid has started: the PREP (aim, cannons locked), then the pass (V13.2). Returns when the pass ends (the raid
-- clock starts then).
function Skyship.open()
	local t = now()
	if not route then
		Skyship.plan(1, false)
	end
	opensAt = t + S.PREP
	endsAt = opensAt + S.PASS
	route.opensAt = opensAt
	workspace:SetAttribute("SkyRouteOpensAt", opensAt)
	workspace:SetAttribute("DeployOpensAt", opensAt)
	workspace:SetAttribute("DeployEndsAt", endsAt)
	boardedFor += 1
	for player in pairs(aboard) do
		player:SetAttribute("LaunchBy", endsAt)
	end
	Net.broadcast("DeployOpen", { opensAt = opensAt, endsAt = endsAt })
	return endsAt
end

function Skyship.reset()
	Flight.reset()
	for player in pairs(aboard) do
		player:SetAttribute("LaunchBy", nil)
	end
	table.clear(aboard)
	table.clear(chosen)
	opensAt, endsAt = 0, 0
	workspace:SetAttribute("DeployOpensAt", nil)
	workspace:SetAttribute("DeployEndsAt", nil)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("DeployDest", nil)
	end
end

-- The island a goblin picked on the map is where the ship fires them as it passes it (V13.2: closest approach), and
-- where their cannon points when they climb in while it is in reach (they can look anywhere from there).
-- V13.2: only an island in reach on this raid's route can be picked.
function Skyship.choose(player, id)
	if typeof(id) ~= "string" or not Config.ISLAND_INFO[id] or not Archipelago.byId[id] then
		return
	end
	if route and not Skyship.reachable(id) then
		Net.toast(player, Archipelago.byId[id].name .. " is out of the ship's reach on this route. Pick a lit island.")
		player:SetAttribute("DeployDest", chosen[player])
		return
	end
	chosen[player] = id
	player:SetAttribute("DeployDest", id)
end

-- Each frame ---------------------------------------------------------------------------------------------
-- V13.2: the ship fires a goblin standing on its deck at a spot (an island's landing). It fires them from a fixed point
-- over the deck, which the server and every client agree on (the ship's route), and tells their client to start the
-- flight exactly there: where the server last saw a goblin on a moving deck lags their own client by a few frames of the
-- ship's travel (measured: 36 studs), enough to slide a throw off a hilltop landing.
local FIRE_POINT = Vector3.new(0, 14, 0)
local function fireAt(player, _root, id, spot, why)
	aboard[player] = nil
	local from = shipCFrame * FIRE_POINT
	Flight.launch(player, (Dive.solve(from, spot, D.CANNON_ELEVATION, D.CANNON_SPEED)), nil, from)
	Net.toast(player, why .. " " .. Archipelago.byId[id].name .. "!")
end

function Skyship.tick(_dt)
	if not model then
		return
	end
	local t = now()
	-- V13.2: fly. (Every client moves its own copy along the same route each frame too; this keeps the server's ship,
	-- its cannons and the goblins welded in them where the clients see them.)
	if route and deck then
		local cf, velocity = SkyRoute.cframeAt(route.points, route.opensAt, t)
		shipVelocity = velocity
		if
			(cf.Position - shipCFrame.Position).Magnitude > 0.01
			or cf.LookVector:Dot(shipCFrame.LookVector) < 0.99999
		then
			shipCFrame = cf
			deck.CFrame = cf
		end
	end
	local raiding = endsAt > 0 and workspace:GetAttribute("RaidPhase") == "raid"
	for player, entry in pairs(aboard) do
		-- V12: each goblin's own deadline: the window, or MIN_DECK after they came aboard if that is later (V13.2: or
		-- LATE_DECK on a later lap).
		local windowOver = raiding and t >= (entry.by or math.max(endsAt, entry.boardedAt + S.MIN_DECK))
		local root = Util.aliveRoot(player)
		local phase = Flight.phaseOf(player)
		if not root or not player.Parent or phase == "diving" or phase == "embedded" then
			aboard[player] = nil -- gone, or thrown: the flight has them now
		elseif phase == "loaded" then
			if windowOver and t >= opensAt then
				Flight.fire(player)
			end
		elseif phase == nil then
			local onShip = shipCFrame:PointToObjectSpace(root.Position)
			local id = chosen[player]
			local pass = id and route and route.passBy[id]
			if onShip.Y < -9 and t - entry.boardedAt < 2 then
				-- Only just put aboard and already far below: the move did not take (see Skyship.board). Again.
				Skyship.board(player, entry.boardedAt)
			elseif onShip.Y < -9 and t >= opensAt and raiding then
				-- Over the side, or off the end of a wing: a free dive from where they are, keeping the ship's speed.
				aboard[player] = nil
				Flight.launch(player, root.AssemblyLinearVelocity + shipVelocity, nil)
			elseif onShip.Y < -40 then
				-- before the cannons unlock: put them back (nobody falls off before the bell)
				Skyship.board(player)
			elseif
				raiding
				and t >= opensAt
				and t < endsAt
				and pass
				and pass.from
				and t - opensAt >= pass.at
				and Skyship.inReach(Skyship.landingFor(id))
			then
				-- V13.2: the island they picked is as close as it gets on this pass: the ship fires them at it.
				fireAt(player, root, id, Skyship.landingFor(id), "Your island! The ship fires you at")
			elseif windowOver and entry.autoFor ~= boardedFor then
				-- The window is over: the ship fires the straggler at their island if it is in reach, else the nearest
				-- landing it can reach (V13.2: a cannon cannot throw across the whole sea any more).
				entry.autoFor = boardedFor
				local best, spot = Skyship.bestInReach(id or player:GetAttribute("DeployDest"), shipCFrame * FIRE_POINT)
				if best then
					fireAt(player, root, best, spot, "Last call! The ship fires you at")
				else
					aboard[player] = nil
					Flight.launch(player, root.AssemblyLinearVelocity + shipVelocity + Vector3.new(0, 20, 0), nil)
					Net.toast(player, "Last call! Over the side you go.")
				end
			end
		end
	end
	-- the window is over for everybody: tidy the attribute so the HUD can let go of it
	if raiding and t >= endsAt + 1 and workspace:GetAttribute("DeployEndsAt") then
		if next(aboard) == nil then
			workspace:SetAttribute("DeployEndsAt", nil)
			workspace:SetAttribute("DeployOpensAt", nil)
		end
	end
end

function Skyship.model()
	return model
end

function Skyship.cannonCount()
	return #cannons
end

-- For tests: the cannon table.
function Skyship.cannonAt(index)
	return cannons[index]
end

return Skyship

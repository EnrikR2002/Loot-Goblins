-- The Ghost Fleet (V9): a small supernatural navy that hunts whoever takes the Skull Chalice.
--
-- Through V8 the fleet was two transparent patrol ships with nobody aboard. V9 makes it a fleet with a crew:
--   1. Taking the Chalice raises a fog and Config.GHOST_FLEET.SHIPS ghost ships, each with ghost pirates
--      on its deck (they sway, wave their cutlasses and point at the thief). The ships spread out behind
--      the thief, never in a rigid line, and fire marked volleys (rings on the water before each shell).
--      Ghosts batter boats, they do not sink them (the hull floor), and a volley never lands in the sanctuary.
--   2. They are slower than a boosting skiff, so a goblin can get clear of them. Once the thief is
--      DEPLOY studs off Skull Rock's shore, pirates LEAP from the decks into tiny rowing boats (DINGHIES in
--      all), which are much faster than the ships, and keep after the thief all the way to the sanctuary.
--      The ships fall back into the fog and sink away.
--   3. A dinghy hangs just behind the thief and, close enough, its pirate waves a cutlass and LEAPS for the
--      treasure (a grip hit: Loot.knockLoose's two-strike rule, Impact's grace). Only one pirate leaps at a
--      time, fleet-wide. A keg or a cannonball sinks a dinghy outright.
-- Everything is kinematic, moved from here (Pursuit's tools: swim, air, place, hit), so tornadoes lift the
-- ships and dinghies and ramps throw dinghies; nothing is a physics boat. One fleet at a time; it ends at the
-- sanctuary, when the Chalice is banked or leaves the thief's hands (it follows a new holder at sea), when
-- the thief dies or leaves, and at the raid's reset.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Blast = require(script.Parent.Blast)
local SeaNav = require(script.Parent.SeaNav)
local Pursuit = require(script.Parent.Pursuit)

local GhostFleet = {}

local G = Config.GHOST_FLEET
local GHOST = Color3.fromRGB(110, 255, 210)
local GHOST_DIM = Color3.fromRGB(70, 170, 160)
local HULL = Color3.fromRGB(60, 120, 120)
-- V10: the sails are pale and torn, the hull darker and much less see-through than V9's (0.35), so a ship
-- reads as a SHIP in fog: spectral by its glow and its rags, not by being hard to see.
local SAIL = Color3.fromRGB(196, 255, 232)
local HULL_DARK = Color3.fromRGB(34, 78, 82)
local BONE = Color3.fromRGB(226, 232, 214)
local CREW_SCALE = 1.35

local fleet = nil
local generation = 0
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function turned(direction, radians)
	local c, s = math.cos(radians), math.sin(radians)
	return Vector3.new(direction.X * c - direction.Z * s, 0, direction.X * s + direction.Z * c)
end

local function block(name, size, offset, color, material, transparency, shape)
	return { name, size, offset, color, material, shape, transparency }
end

-- Bodies -----------------------------------------------------------------------------------------------
-- A ghost galleon (V10): a long dark hull with a glowing waterline and gunwale, a pointed bow carrying a
-- bowsprit and a bone skull figurehead, a two-tier stern castle with green-lit windows, cannon ports down each
-- side, three masts of torn glowing sails (each sail two ragged halves), a crow's nest and a black skull flag.
local function shipBody()
	local GLASS, NEON, FABRIC = Enum.Material.Glass, Enum.Material.Neon, Enum.Material.Fabric
	local parts = {
		block("Hull", Vector3.new(18, 8, 50), nil, HULL, GLASS, 0.18),
		block("Keel", Vector3.new(12, 3, 46), CFrame.new(0, -4.6, 0), HULL_DARK, GLASS, 0.15),
		block("Waterline", Vector3.new(18.4, 0.6, 50.4), CFrame.new(0, -2.2, 0), GHOST, NEON, 0.35),
		block("Gunwale", Vector3.new(18.6, 0.8, 50.6), CFrame.new(0, 4.4, 0), GHOST, NEON, 0.25),
		block("Deck", Vector3.new(16, 1, 46), CFrame.new(0, 4, 0), GHOST_DIM, Enum.Material.WoodPlanks, 0.2),
		block(
			"Bow",
			Vector3.new(12.7, 8, 12.7),
			CFrame.new(0, 0, -25) * CFrame.Angles(0, math.rad(45), 0),
			HULL,
			GLASS,
			0.18
		),
		block(
			"BowRail",
			Vector3.new(13, 0.8, 13),
			CFrame.new(0, 4.4, -25) * CFrame.Angles(0, math.rad(45), 0),
			GHOST,
			NEON,
			0.25
		),
		block(
			"Bowsprit",
			Vector3.new(1.2, 1.2, 22),
			CFrame.new(0, 8, -40) * CFrame.Angles(math.rad(18), 0, 0),
			GHOST_DIM,
			Enum.Material.Wood,
			0.1
		),
		block(
			"Figurehead",
			Vector3.new(3.4, 3.4, 3.4),
			CFrame.new(0, 3.4, -34.5),
			BONE,
			Enum.Material.SmoothPlastic,
			0,
			Enum.PartType.Ball
		),
		block("FigureheadEyes", Vector3.new(2.4, 0.6, 0.4), CFrame.new(0, 3.8, -36.2), GHOST, NEON, 0),
		block("Castle", Vector3.new(16, 6, 12), CFrame.new(0, 7.5, 19), HULL, GLASS, 0.18),
		block("CastleTop", Vector3.new(14, 4, 7), CFrame.new(0, 12.5, 21.5), HULL, GLASS, 0.18),
		block("CastleRail", Vector3.new(16.4, 0.7, 12.4), CFrame.new(0, 10.7, 19), GHOST, NEON, 0.25),
		block(
			"SternWindows",
			Vector3.new(12, 2, 0.4),
			CFrame.new(0, 7.8, 25.2),
			Color3.fromRGB(150, 255, 120),
			NEON,
			0.1
		),
		block("MastA", Vector3.new(1.6, 44, 1.6), CFrame.new(0, 26, -12), GHOST_DIM, Enum.Material.Wood, 0.1),
		block("MastB", Vector3.new(1.8, 50, 1.8), CFrame.new(0, 29, 2), GHOST_DIM, Enum.Material.Wood, 0.1),
		block("MastC", Vector3.new(1.4, 34, 1.4), CFrame.new(0, 21, 14), GHOST_DIM, Enum.Material.Wood, 0.1),
		block(
			"CrowsNest",
			Vector3.new(1.8, 4.6, 4.6),
			CFrame.new(0, 47, 2) * CFrame.Angles(0, 0, math.rad(90)),
			GHOST_DIM,
			Enum.Material.Wood,
			0.1,
			Enum.PartType.Cylinder
		),
		block("Flag", Vector3.new(0.3, 4, 7), CFrame.new(0, 55, 2), Color3.fromRGB(20, 20, 24), FABRIC, 0),
		block("FlagSkull", Vector3.new(0.4, 1.8, 1.8), CFrame.new(0, 55, 1.6), BONE, NEON, 0, Enum.PartType.Ball),
		block("LanternBow", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 8.4, -30), GHOST, NEON, 0, Enum.PartType.Ball),
		block("LanternStern", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 16, 24), GHOST, NEON, 0, Enum.PartType.Ball),
	}
	-- Torn sails: two ragged halves per yard, hanging at different lengths, slightly twisted.
	for _, mast in ipairs({
		{ z = -12, y = 34, w = 18, h = 11 },
		{ z = 2, y = 38, w = 20, h = 13 },
		{ z = 2, y = 22, w = 17, h = 9 },
		{ z = 14, y = 26, w = 14, h = 9 },
	}) do
		for _, side in ipairs({ -1, 1 }) do
			local hang = mast.h * (side < 0 and 1 or 0.72)
			table.insert(
				parts,
				block(
					"Sail",
					Vector3.new(mast.w * 0.48, hang, 0.4),
					CFrame.new(side * mast.w * 0.26, mast.y - (mast.h - hang) / 2, mast.z - 0.6)
						* CFrame.Angles(0, side * 0.08, side * 0.04),
					SAIL,
					NEON,
					0.58
				)
			)
		end
		table.insert(
			parts,
			block(
				"Yard",
				Vector3.new(mast.w + 2, 0.8, 0.8),
				CFrame.new(0, mast.y + mast.h / 2, mast.z),
				GHOST_DIM,
				Enum.Material.Wood,
				0.1
			)
		)
	end
	-- Cannon ports.
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			table.insert(
				parts,
				block(
					"Port",
					Vector3.new(0.4, 2, 2.4),
					CFrame.new(side * 9.1, 1.2, -12 + i * 10),
					Color3.fromRGB(14, 30, 32),
					Enum.Material.SmoothPlastic,
					0
				)
			)
		end
	end
	return parts
end

-- A ghost pirate's dinghy (V10): a tiny glowing tub with a pointed bow, two oars and a lantern on a pole, and
-- its pirate (the same figure as the ships' crews) standing in the bow waving a cutlass.
-- One ghost pirate (V10): a translucent long coat with a belt, a round glowing head with green eyes and a wispy
-- beard, a black tricorn (a brim and a crown), a cutlass, and a ghostly tail where the legs should be.
-- { name, size, offset, color, material, transparency, round, rotation }
local CREW_PARTS = {
	{ "Body", Vector3.new(1.9, 2.6, 1.3), Vector3.new(0, 2.3, 0), GHOST, Enum.Material.Glass, 0.25 },
	{ "Belt", Vector3.new(2, 0.4, 1.4), Vector3.new(0, 1.7, 0), Color3.fromRGB(26, 26, 30), Enum.Material.Fabric, 0 },
	{ "Tail", Vector3.new(1.3, 1.8, 0.9), Vector3.new(0, 0.3, 0.2), GHOST, Enum.Material.Glass, 0.5 },
	{ "Head", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 4.3, 0), GHOST, Enum.Material.Glass, 0.2, true },
	{
		"Beard",
		Vector3.new(1.1, 0.9, 0.5),
		Vector3.new(0, 3.6, -0.6),
		Color3.fromRGB(200, 255, 236),
		Enum.Material.Glass,
		0.3,
	},
	{
		"HatBrim",
		Vector3.new(2.8, 0.3, 2.2),
		Vector3.new(0, 5.15, 0),
		Color3.fromRGB(22, 22, 28),
		Enum.Material.Fabric,
		0,
	},
	{
		"HatCrown",
		Vector3.new(1.7, 0.9, 1.5),
		Vector3.new(0, 5.6, 0),
		Color3.fromRGB(22, 22, 28),
		Enum.Material.Fabric,
		0,
	},
	{
		"Eyes",
		Vector3.new(1, 0.25, 0.2),
		Vector3.new(0, 4.45, -0.8),
		Color3.fromRGB(180, 255, 120),
		Enum.Material.Neon,
		0,
	},
	{
		"Cutlass",
		Vector3.new(0.25, 0.25, 3),
		Vector3.new(1.4, 3.6, -1.2),
		Color3.fromRGB(210, 220, 230),
		Enum.Material.Metal,
		0,
	},
}

local function dinghyBody()
	local s = CREW_SCALE
	local parts = {
		block("Hull", Vector3.new(5, 1.6, 9), nil, HULL, Enum.Material.Glass, 0.2),
		block(
			"Bow",
			Vector3.new(3.6, 1.6, 3.6),
			CFrame.new(0, 0, -4.6) * CFrame.Angles(0, math.rad(45), 0),
			HULL,
			Enum.Material.Glass,
			0.2
		),
		block("Rim", Vector3.new(5.4, 0.5, 9.4), CFrame.new(0, 0.9, 0), GHOST, Enum.Material.Neon, 0.25),
		block("OarL", Vector3.new(5, 0.3, 0.8), CFrame.new(-4.2, 0.8, 0.5), GHOST_DIM, Enum.Material.Wood, 0.1),
		block("OarR", Vector3.new(5, 0.3, 0.8), CFrame.new(4.2, 0.8, 0.5), GHOST_DIM, Enum.Material.Wood, 0.1),
		block("Pole", Vector3.new(0.3, 4.6, 0.3), CFrame.new(1.8, 3, 3.6), GHOST_DIM, Enum.Material.Wood, 0.1),
		block(
			"Lantern",
			Vector3.new(1, 1, 1),
			CFrame.new(1.8, 5.5, 3.6),
			Color3.fromRGB(150, 255, 120),
			Enum.Material.Neon,
			0,
			Enum.PartType.Ball
		),
	}
	for _, spec in ipairs(CREW_PARTS) do
		table.insert(
			parts,
			block(
				spec[1],
				spec[2] * s,
				CFrame.new(spec[3].X * s, 1 + spec[3].Y * s, -1 + spec[3].Z * s) * (spec[8] or CFrame.new()),
				spec[4],
				spec[5],
				spec[6],
				spec[7] and Enum.PartType.Ball or nil
			)
		)
	end
	return parts
end

local function makeCrew(model)
	local member = { parts = {} }
	for _, spec in ipairs(CREW_PARTS) do
		local p = Instance.new("Part")
		p.Name = "Ghost" .. spec[1]
		p.Size = spec[2] * CREW_SCALE
		p.Color = spec[4]
		p.Material = spec[5]
		p.Transparency = spec[6]
		if spec[7] then
			p.Shape = Enum.PartType.Ball
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(0, -300, 0)
		p.Parent = model
		table.insert(member.parts, { part = p, offset = spec[3] * CREW_SCALE, name = spec[1] })
	end
	return member
end

-- Pose every crew member of every ship in one go: standing on the deck, swaying, cutlasses waving, and
-- (for one that is jumping into a dinghy) flying through the air.
local function poseCrew(t)
	local parts, frames = {}, {}
	for _, ship in ipairs(fleet.ships) do
		local deck = ship.root.CFrame
		for i, member in ipairs(ship.crew) do
			local base
			if member.leap then
				local leap = member.leap
				local k = math.clamp((t - leap.startAt) / leap.time, 0, 1)
				local from, to = leap.from, leap.dinghy.root.Position
				local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 18, 0)
				base = CFrame.new(p) * CFrame.Angles(k * math.pi * 2, 0, 0)
				if k >= 1 then
					member.leap = nil
					member.gone = true
					leap.dinghy.crewed = true
					Pursuit.fx("splash", to)
				end
			elseif member.gone then
				base = CFrame.new(0, -300, 0)
			else
				local slot = member.slot
				local sway = math.sin(t * 2.2 + i) * 0.18
				base = deck * CFrame.new(slot.X, 4.5, slot.Z) * CFrame.Angles(0, member.facing, sway)
			end
			local wave = math.sin(t * 7 + i * 1.7) * 0.9
			for _, entry in ipairs(member.parts) do
				local frame = base * CFrame.new(entry.offset)
				if entry.name == "Cutlass" then
					frame *= CFrame.Angles(wave, 0, 0)
				end
				table.insert(parts, entry.part)
				table.insert(frames, frame)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The fleet -----------------------------------------------------------------------------------------------
local function skullIsland()
	return Archipelago.byId.Skull
end

local function inHands(player)
	local item = Loot.itemOf(player)
	return item ~= nil and item.def.island == "Skull"
end

local function chaliceHolder()
	for _, entry in ipairs(Loot.carriers()) do
		if entry.item.def.island == "Skull" then
			return entry.player
		end
	end
	return nil
end

local function mover(model, root, position, heading, draft)
	return {
		model = model,
		root = root,
		position = Vector3.new(position.X, 0, position.Z),
		heading = heading,
		speed = 0,
		alt = 0,
		vy = 0,
		draft = draft,
		keepOut = true,
	}
end

local function sinkAndRemove(entry, seconds)
	entry.sinking = now()
	entry.sinkFor = seconds or 2
end

local function finishFleet(text)
	local f = fleet
	if not f then
		return
	end
	fleet = nil
	generation += 1
	for _, ship in ipairs(f.ships) do
		if ship.model then
			ship.model:Destroy()
		end
	end
	for _, dinghy in ipairs(f.dinghies) do
		if dinghy.model then
			dinghy.model:Destroy()
		end
	end
	if text then
		Net.feed(text, GHOST)
	end
end

-- Raise the fleet after a thief. `spawns`: CFrames in the fog off Skull Rock (the island's trouble site).
function GhostFleet.rise(player, spawns)
	if fleet then
		finishFleet(nil)
	end
	local t = now()
	fleet = {
		target = player,
		ships = {},
		dinghies = {},
		bornAt = t,
		deployed = false,
		boardReadyAt = t + 4,
	}
	local island = skullIsland()
	for i = 1, G.SHIPS do
		local spawn = spawns and spawns[(i - 1) % #spawns + 1]
		local at = spawn and spawn.Position or Vector3.new(island.x, 0, island.z + island.r + 120)
		-- Spread them out if two share a spawn.
		at += Vector3.new((i - 2) * 90, 0, (i % 2) * 60)
		local water = SeaNav.nearestWater(at.X, at.Z, 3.8)
		at = water and Vector3.new(water.X, 0, water.Z) or at
		local model, root = Pursuit.body("GhostShip", shipBody(), 1)
		for _, name in ipairs({ "LanternBow", "SternWindows" }) do
			local lamp = model:FindFirstChild(name)
			if lamp then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(130, 255, 190)
				light.Range = 34
				light.Brightness = 1.6
				light.Parent = lamp
			end
		end
		model:SetAttribute("Pursuer", "The Ghost Fleet")
		model:SetAttribute("Chasing", player.UserId)
		local light = Instance.new("PointLight")
		light.Color = GHOST
		light.Range = 50
		light.Brightness = 2.5
		light.Parent = root
		local look = spawn and flat(spawn.LookVector) or Vector3.new(0, 0, 1)
		local ship = mover(model, root, at, look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1), 3.8)
		ship.kind = "ship"
		ship.index = i
		ship.side = i == 1 and -1 or (i == 2 and 1 or 0)
		ship.nextVolley = t + 3 + i * 0.9
		ship.crew = {}
		for c = 1, G.CREW do
			local member = makeCrew(model)
			member.slot = Vector3.new(((c % 2) == 0 and 4 or -4) + random:NextNumber(-1, 1), 0, -14 + (c - 1) * 8)
			member.facing = random:NextNumber(-0.6, 0.6)
			table.insert(ship.crew, member)
		end
		ship.rise = 0 -- surfaces out of the sea over its first seconds
		table.insert(fleet.ships, ship)
		Pursuit.fx("erupt", at)
	end
	Net.send(
		player,
		"Message",
		{ text = "THE GHOST FLEET RISES! IT IS CREWED. IT IS COMING.", duration = 3.5, color = GHOST }
	)
	Net.feed("The Ghost Fleet has risen after " .. player.DisplayName .. "!", GHOST)
	return fleet
end

-- Pirates over the side: each dinghy is launched from a ship, its pirate leaping from the deck into it.
local function deploy(t, targetAt)
	fleet.deployed = true
	fleet.deployedAt = t
	local count = 0
	local ships = fleet.ships
	for i = 1, G.DINGHIES do
		local ship = ships[(i - 1) % #ships + 1]
		if ship and ship.model and not ship.sinking then
			local side = (i % 2 == 0) and 1 or -1
			local across = turned(ship.heading, math.rad(90)) * side
			local at = ship.position + across * 22 + ship.heading * random:NextNumber(-12, 12)
			local water = SeaNav.nearestWater(at.X, at.Z, 1)
			at = water and Vector3.new(water.X, 0, water.Z) or at
			local model, root = Pursuit.body("GhostDinghy", dinghyBody(), 1)
			model:SetAttribute("Pursuer", "A ghost pirate's dinghy")
			model:SetAttribute("Chasing", fleet.target.UserId)
			local toward = flat(targetAt - at)
			local dinghy = mover(model, root, at, toward.Magnitude > 1 and toward.Unit or ship.heading, 1)
			dinghy.kind = "dinghy"
			dinghy.slot = (i - (G.DINGHIES + 1) / 2) * 22 -- spread across the thief's wake
			dinghy.state = "chase"
			dinghy.crewed = false
			dinghy.launchAt = t + 0.5 + (i - 1) * 0.35
			dinghy.nextLunge = t + random:NextNumber(2, 4)
			-- Hide the dinghy's own pirate until the leaping one lands in it.
			for _, name in ipairs({ "Body", "Head", "Hat", "Eyes", "Cutlass" }) do
				local p = model:FindFirstChild(name)
				if p then
					p:SetAttribute("Shown", p.Transparency)
					p.Transparency = 1
				end
			end
			table.insert(fleet.dinghies, dinghy)
			-- One of the ship's crew jumps for it.
			for _, member in ipairs(ship.crew) do
				if not member.gone and not member.leap then
					local from = (ship.root.CFrame * CFrame.new(member.slot.X, 6, member.slot.Z)).Position
					member.leap = { from = from, dinghy = dinghy, startAt = t + (i - 1) * 0.35, time = 0.9 }
					break
				end
			end
			count += 1
		end
	end
	Net.send(fleet.target, "Message", {
		text = "THE GHOST PIRATES ARE TAKING TO THE DINGHIES!",
		duration = 3,
		color = GHOST,
	})
	Pursuit.fx("yarr", ships[1] and ships[1].position or targetAt)
	return count
end

local function showPirate(dinghy)
	for _, name in ipairs({ "Body", "Head", "Hat", "Eyes", "Cutlass" }) do
		local p = dinghy.model:FindFirstChild(name)
		if p then
			p.Transparency = p:GetAttribute("Shown") or 0
		end
	end
end

local function tickShip(ship, dt, t, info)
	if ship.sinking then
		local k = (t - ship.sinking) / ship.sinkFor
		if k >= 1 then
			ship.model:Destroy()
			ship.model = nil
			return
		end
		Pursuit.place(ship, -k * 18, CFrame.Angles(math.rad(k * 12), 0, math.rad(k * 8)))
		return
	end
	ship.rise = math.min(1, ship.rise + dt / 2.5)
	-- Their places: either side of the thief's wake and one further back, never a rigid line.
	local back = info.velocity.Magnitude > 10 and -info.velocity.Unit or flat(ship.position - info.at).Unit
	local across = Vector3.new(-back.Z, 0, back.X)
	local slot = info.at
		+ back * (ship.side == 0 and 200 or 90)
		+ across * ship.side * G.SPACING
		+ across * math.sin(t * 0.5 + ship.index) * 25
	local gap = flat(info.at - ship.position).Magnitude
	local want
	if fleet.deployed then
		want = math.max(40, info.targetSpeed * 0.55) -- falling back into the fog
	elseif gap > 450 then
		want = G.SHIP_SURGE
	else
		want = math.clamp(info.targetSpeed + (flat(slot - ship.position).Magnitude - 30) * 0.8, 30, G.SHIP_SPEED)
	end
	local rate = want > ship.speed and 80 or 60
	ship.speed += math.clamp(want - ship.speed, -rate * dt, rate * dt)
	Pursuit.air(ship, dt, t)
	Pursuit.swim(ship, slot, ship.speed, dt, G.SHIP_TURN)
	-- Volleys: marked shells where the thief will be.
	if
		not fleet.deployed
		and t >= ship.nextVolley
		and gap < G.VOLLEY_RANGE
		and (ship.alt or 0) < 3
		and ship.rise >= 1
	then
		ship.nextVolley = t + G.VOLLEY_GAP * random:NextNumber(0.85, 1.25)
		for shot = 1, G.VOLLEY_SHOTS do
			local lead = info.at + info.velocity * (G.VOLLEY_DELAY * (0.6 + shot * 0.3))
			local aim = lead + Vector3.new(random:NextNumber(-10, 10), 0, random:NextNumber(-10, 10))
			if not Pursuit.inSanctuary(aim, 30) then
				local muzzle = ship.position + Vector3.new(0, 8, 0) + across * -ship.side * 9
				Net.broadcastNear(
					aim,
					1400,
					"Shell",
					{ from = muzzle, to = aim, duration = G.VOLLEY_DELAY + shot * 0.2 }
				)
				Blast.strike(Vector3.new(aim.X, 0.5, aim.Z), G.VOLLEY_DELAY + shot * 0.2, {
					radius = G.SHELL_RADIUS,
					damage = 12,
					knockback = 55,
					hullDamage = G.SHELL_HULL,
					boatPush = G.SHELL_PUSH,
					-- No lootReason: a volley throws and batters, it never loosens a grip. Only a pirate who
					-- boards takes hold of the treasure (a Chalice lost to a shell and a leap 4 s apart was
					-- the first test run's result, too harsh).
					cause = "a ghost ship",
					markerColor = GHOST,
					color = GHOST,
				})
			end
		end
		Pursuit.fx("cannon", ship.position)
	end
	local tilt = CFrame.Angles(0, 0, math.sin(t * 1.3 + ship.index) * 0.06)
	Pursuit.place(ship, -9 * (1 - ship.rise) + 1, tilt)
end

local function tickDinghy(dinghy, dt, t, info)
	if dinghy.sinking then
		local k = (t - dinghy.sinking) / dinghy.sinkFor
		if k >= 1 then
			dinghy.model:Destroy()
			dinghy.model = nil
			return
		end
		Pursuit.place(dinghy, -k * 8, CFrame.Angles(0, k * 6, 0))
		return
	end
	if t < dinghy.launchAt or not dinghy.crewed then
		Pursuit.place(dinghy, 0.3) -- waiting for its pirate, bobbing beside the ship
		return
	end
	if not dinghy.shown then
		dinghy.shown = true
		showPirate(dinghy)
	end
	local back = info.velocity.Magnitude > 10 and -info.velocity.Unit or flat(dinghy.position - info.at).Unit
	local across = Vector3.new(-back.Z, 0, back.X)
	local follow = 34
	local gap = flat(info.at - dinghy.position).Magnitude - (info.boat and info.boat.spec.size.Z * 0.4 or 0)
	local goal = info.at + back * follow + across * dinghy.slot
	if dinghy.state == "tell" or (dinghy.lungeUntil and t < dinghy.lungeUntil) then
		goal = info.at + info.velocity * 0.3
	end
	local want
	if gap > 300 then
		want = G.DINGHY_SURGE
	elseif dinghy.lungeUntil and t < dinghy.lungeUntil then
		want = info.targetSpeed + 60
	else
		want = math.clamp(info.targetSpeed + (gap - follow) * 2, 0, G.DINGHY_SURGE)
	end
	local rate = want > dinghy.speed and 260 or 120
	dinghy.speed += math.clamp(want - dinghy.speed, -rate * dt, rate * dt)
	local airborne = Pursuit.air(dinghy, dt, t)
	if not Pursuit.swim(dinghy, goal, dinghy.speed, dt, G.DINGHY_TURN) then
		dinghy.stuckFor = (dinghy.stuckFor or 0) + dt
	else
		dinghy.stuckFor = 0
	end
	-- Hopelessly far behind or stuck: it is a ghost; it fades, and rows out of the fog behind them.
	if (gap > 950 or (dinghy.stuckFor or 0) > 3) and t - (dinghy.resurfacedAt or -10) > 4 then
		local spot = info.at + back * 380 + across * dinghy.slot
		local water = SeaNav.nearestWater(spot.X, spot.Z, 1)
		if water and not Pursuit.inSanctuary(water) then
			dinghy.resurfacedAt = t
			dinghy.position = Vector3.new(water.X, 0, water.Z)
			dinghy.speed = info.targetSpeed
			dinghy.stuckFor = 0
			Pursuit.fx("launch", dinghy.position)
		end
	end
	-- Boarding: one pirate at a time, fleet-wide.
	if dinghy.state == "chase" then
		if t >= dinghy.nextLunge and gap < follow + 25 then
			dinghy.nextLunge = t + random:NextNumber(4.5, 7)
			dinghy.lungeUntil = t + 1.2
		end
		if gap < G.BOARD_REACH and not airborne and t >= fleet.boardReadyAt then
			fleet.boardReadyAt = t + G.BOARD_TELL + G.BOARD_REST
			dinghy.state = "tell"
			dinghy.stateUntil = t + G.BOARD_TELL
			Pursuit.fx("yarr", dinghy.position)
		end
	elseif dinghy.state == "tell" then
		if t >= dinghy.stateUntil then
			dinghy.state = "rest"
			dinghy.stateUntil = t + G.BOARD_REST
			local root, _, boat = Pursuit.vessel(fleet.target)
			local where = boat and boat.hull.Position or (root and root.Position)
			if where and flat(where - dinghy.position).Magnitude < G.BOARD_REACH + 10 and not airborne then
				Pursuit.hit(fleet.target, dinghy.position, {
					push = 30,
					lift = 12,
					spin = 1,
					hull = 3,
					reason = "ghost",
					cause = "a ghost pirate",
					text = "A GHOST PIRATE LEAPT ABOARD! Shake them off!",
				})
				Pursuit.fx("snatch", where)
			end
			dinghy.speed *= 0.4 -- it falls back after the leap
		end
	elseif dinghy.state == "rest" and t >= dinghy.stateUntil then
		dinghy.state = "chase"
	end
	local extra = dinghy.state == "tell" and CFrame.Angles(math.rad(-14), 0, math.sin(t * 20) * 0.15) or nil
	Pursuit.place(dinghy, 0.3, extra)
end

function GhostFleet.tick(dt)
	local f = fleet
	if not f then
		return
	end
	local t = now()
	dt = math.min(dt, 0.1)
	-- Who it is after: the Chalice's holder (a new one, if it was snatched at sea).
	local target = f.target
	if not target.Parent or not inHands(target) then
		local holder = chaliceHolder()
		if holder and holder.Parent and Pursuit.atSea(holder) then
			f.target = holder
			target = holder
			for _, entry in ipairs(f.ships) do
				if entry.model then
					entry.model:SetAttribute("Chasing", holder.UserId)
				end
			end
			for _, entry in ipairs(f.dinghies) do
				if entry.model then
					entry.model:SetAttribute("Chasing", holder.UserId)
				end
			end
			Net.toast(holder, "THE GHOST FLEET IS AFTER YOU NOW!")
			f.lostAt = nil
		else
			f.lostAt = f.lostAt or t
			if t - f.lostAt > 3 then
				finishFleet("The Ghost Fleet sinks back into the fog.")
				return
			end
		end
	end
	local root, _, boat = Pursuit.vessel(target)
	local part = boat and boat.hull or root
	if not part then
		return
	end
	if Pursuit.inSanctuary(part.Position) then
		Net.toast(target, "The ghost pirates wail at the cove lights and fade away.")
		Pursuit.fx("quit", part.Position, { color = GHOST })
		Pursuit.Escaped:Fire(target, "Skull") -- V13: an escape from the Ghost Fleet
		finishFleet("The Ghost Fleet gives up at the lights of Goblin Cove.")
		return
	end
	if t - f.bornAt > 200 then
		finishFleet("The Ghost Fleet fades with the fog.")
		return
	end
	local info = {
		at = flat(part.Position),
		velocity = flat(part.AssemblyLinearVelocity),
		boat = boat,
	}
	-- V13: a Wraith's ghost fools the fleet for a moment (its volleys and leaps go to where the ghost runs).
	local decoy = Pursuit.decoyOf(target)
	if decoy then
		info.at, info.velocity = decoy.at, decoy.velocity
	end
	info.targetSpeed = info.velocity.Magnitude
	-- Far enough from Skull Rock: the pirates take to the dinghies.
	local island = skullIsland()
	local off = (info.at - Vector3.new(island.x, 0, island.z)).Magnitude - island.r
	if not f.deployed and Pursuit.atSea(target) and off > G.DEPLOY then
		deploy(t, info.at)
	end
	if f.deployed and t - f.deployedAt > G.SHIP_FADE then
		for _, ship in ipairs(f.ships) do
			if ship.model and not ship.sinking then
				sinkAndRemove(ship, 3)
			end
		end
	end
	for index = #f.ships, 1, -1 do
		local ship = f.ships[index]
		if ship.model then
			tickShip(ship, dt, t, info)
		end
		if not ship.model then
			table.remove(f.ships, index)
		end
	end
	for index = #f.dinghies, 1, -1 do
		local dinghy = f.dinghies[index]
		if dinghy.model then
			tickDinghy(dinghy, dt, t, info)
		end
		if not dinghy.model then
			table.remove(f.dinghies, index)
		end
	end
	if fleet then
		poseCrew(t)
	end
end

-- A keg or a cannonball: a dinghy it reaches is sunk; a ship it reaches lurches.
local function onBlast(position, radius)
	if not fleet then
		return
	end
	for _, dinghy in ipairs(fleet.dinghies) do
		if dinghy.model and not dinghy.sinking and flat(dinghy.position - position).Magnitude < radius + 6 then
			sinkAndRemove(dinghy, 1.2)
			Pursuit.fx("yelp", dinghy.position)
		end
	end
end

function GhostFleet.build()
	Blast.Hit:Connect(onBlast)
end

function GhostFleet.reset()
	finishFleet(nil)
	generation += 1
end

function GhostFleet.forget(player)
	if fleet and fleet.target == player and not chaliceHolder() then
		finishFleet(nil)
	end
end

-- For tests.
function GhostFleet.inspect()
	local f = fleet
	if not f then
		return nil
	end
	local out = { target = f.target.Name, deployed = f.deployed, ships = {}, dinghies = {} }
	for _, ship in ipairs(f.ships) do
		local crew = 0
		for _, member in ipairs(ship.crew) do
			if not member.gone then
				crew += 1
			end
		end
		table.insert(out.ships, { speed = math.floor(ship.speed), crew = crew, sinking = ship.sinking ~= nil })
	end
	for _, dinghy in ipairs(f.dinghies) do
		table.insert(out.dinghies, { speed = math.floor(dinghy.speed), state = dinghy.state, crewed = dinghy.crewed })
	end
	return out
end

return GhostFleet

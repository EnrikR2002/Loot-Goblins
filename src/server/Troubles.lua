-- What each treasure does when it is taken. Threats.lua handles the original four (the Guardian,
-- the cave-in, the wreck's barrage, the bell); everything else lives here and plugs into
-- Threats.handlers. The pattern is the same for all of them:
--
--   * A recognizable cause the moment the loot leaves its spot (a banner and a feed line).
--   * A telegraph before anything dangerous lands (rings, rumbles, a countdown players can read).
--   * Something that changes the ROUTE rather than only adding damage: a gate that slams shut, bridges
--     that snap, a sea that boils, ships that sail out, a mountain that rains fire.
--
-- Nothing here is unavoidable. Every strike is marked and every effect ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Threats = require(script.Parent.Threats)
local Blast = require(script.Parent.Blast)
local Storms = require(script.Parent.Storms)
local Navy = require(script.Parent.Navy)
local Mechanisms = require(script.Parent.Mechanisms)
local Destructibles = require(script.Parent.Destructibles)

local Troubles = {}

local refs
local flooded = false
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function groundBelow(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(position.X, 400, position.Z), Vector3.new(0, -500, 0), params)
	return hit and math.max(hit.Position.Y, 0) or 0
end

-- The carrier closest to a point, within radius.
local function carrierNear(center, radius)
	local best, bestDistance
	for _, carrier in ipairs(Loot.carriers()) do
		local distance = (Vector3.new(carrier.root.Position.X, 0, carrier.root.Position.Z) - Vector3.new(
			center.X,
			0,
			center.Z
		)).Magnitude
		if distance < radius and (not bestDistance or distance < bestDistance) then
			best, bestDistance = carrier, distance
		end
	end
	return best
end

-- Runs `step` every `gap` seconds until `duration` has passed or the raid resets.
local function repeating(duration, gap, step)
	local generation = Threats.generation()
	task.spawn(function()
		local endsAt = now() + duration
		while now() < endsAt and generation == Threats.generation() do
			step()
			task.wait(type(gap) == "function" and gap() or gap)
		end
	end)
end

-- Texts for the banner (Threats broadcasts them with the Trouble event).
Threats.text.Gulls = "THE GULLS SCREAM - EVERYONE KNOWS!"
Threats.text.Windmill = "THE MILL RUNS WILD!"
Threats.text.Flood = "THE VAULT GATE SLAMS SHUT - THE CHAMBER FLOODS!"
Threats.text.Squall = "A SQUALL CLOSES IN ON THE ROCK!"
Threats.text.Navy = "THE ADMIRAL'S ALARM! PATROL SHIPS INCOMING!"
Threats.text.Eruption = "THE VOLCANO ERUPTS!"
Threats.text.Avalanche = "THE GLACIER RUMBLES - AVALANCHE!"
Threats.text.Kraken = "THE LEVIATHAN STIRS - TENTACLES!"
Threats.text.GhostFleet = "THE GHOST FLEET RISES!"
Threats.text.Quake = "THE JUNGLE SHAKES - THE BRIDGES ARE GOING!"

-- Pebble Isle and Coral Atoll: a flock takes off and everyone hears it. Light, but a loud thief is
-- an easy thief to find.
Threats.handlers.Gulls = function(item)
	Threats.reveal(item, Config.GULLS_REVEAL_TIME)
	Net.broadcast("Gulls", { position = item.spot.Position })
end

-- The windmill spins up for a while. The Golden Gear's balcony is in the sails' path, so the
-- thief has to leave through the storm of blades; so does anyone chasing.
Threats.handlers.Windmill = function()
	local spinner = refs.windmill
	if not spinner then
		return
	end
	spinner.speed = spinner.baseSpeed * 3
	local generation = Threats.generation()
	task.delay(Config.WINDMILL_RAGE_TIME, function()
		if generation == Threats.generation() then
			spinner.speed = spinner.baseSpeed
		end
	end)
end

-- Tide Vault: the portcullis drops and the chamber fills. The way out is the drain tunnel (swim),
-- or a friend at the lever.
Threats.handlers.Flood = function()
	local site = refs.troubleSites.Flood
	if not site then
		return
	end
	local terrain = workspace.Terrain
	Mechanisms.slamGate(site.gate, 0)
	local generation = Threats.generation()
	local chamber, tunnel = site.chamberCenter, site.tunnelCenter
	local function fill(material)
		terrain:FillBlock(CFrame.new(chamber), site.chamberSize, material)
		terrain:FillBlock(CFrame.new(tunnel), site.tunnelSize, material)
		flooded = material == Enum.Material.Water
	end
	task.spawn(function()
		task.wait(0.8)
		if generation ~= Threats.generation() then
			return
		end
		fill(Enum.Material.Water)
		Net.broadcast("Flood", { position = chamber, rising = true })
		task.wait(Config.FLOOD_TIME)
		fill(Enum.Material.Air)
		if generation == Threats.generation() then
			Mechanisms.openGate(site.gate, 8)
			Net.feed("The vault drains and the gate rumbles open again.", Color3.fromRGB(110, 230, 255))
		end
	end)
end

-- Maelstrom Rock: a storm settles on the whirlpool.
Threats.handlers.Squall = function()
	local site = refs.troubleSites.Squall
	if site then
		Storms.spawn({ x = site.center.X, z = site.center.Z, r = 270, strength = 1, duration = Config.SQUALL_TIME })
	end
end

-- Fort Barnacle: the alarm sends the patrol out at once.
Threats.handlers.Navy = function(_, player)
	Navy.dispatch(player, 2, true)
end

-- Ember Isle: lava bombs rain on the island and the water around it, mostly near the thief. Every
-- bomb is a marked circle that closes in over its flight time.
Threats.handlers.Eruption = function()
	local site = refs.troubleSites.Eruption
	if not site then
		return
	end
	repeating(Config.ERUPTION_TIME, function()
		return random:NextNumber(0.5, 0.9)
	end, function()
		local carrier = carrierNear(site.center, site.radius + 80)
		local position
		if carrier and random:NextNumber() < 0.6 then
			local v = carrier.root.AssemblyLinearVelocity
			local lead = Vector3.new(v.X, 0, v.Z) * Config.ERUPTION_BOMB_DELAY * 0.8
			position = carrier.root.Position
				+ lead
				+ Vector3.new(random:NextNumber(-14, 14), 0, random:NextNumber(-14, 14))
		else
			local a, r = random:NextNumber(0, math.pi * 2), random:NextNumber(30, site.radius)
			position = Vector3.new(site.center.X + math.cos(a) * r, 0, site.center.Z + math.sin(a) * r)
		end
		position = Vector3.new(position.X, groundBelow(position), position.Z)
		Blast.strike(position, Config.ERUPTION_BOMB_DELAY, {
			radius = 12,
			damage = 26,
			knockback = 72,
			hullDamage = 55,
			boatPush = 50,
			lootReason = "boulder",
			cause = "a lava bomb",
			markerColor = Color3.fromRGB(255, 120, 40),
			style = "lava",
			color = Color3.fromRGB(255, 130, 40),
		})
	end)
end

-- Frost Spire: snow boulders roll down the south face, one after another.
Threats.handlers.Avalanche = function()
	local site = refs.troubleSites.Avalanche
	if not site then
		return
	end
	local generation = Threats.generation()
	for i = 1, Config.AVALANCHE_BALLS do
		task.delay(Config.AVALANCHE_WARNING + i * Config.AVALANCHE_GAP, function()
			if generation ~= Threats.generation() then
				return
			end
			local size = random:NextNumber(8, 13)
			local ball = Instance.new("Part")
			ball.Name = "SnowBoulder"
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(size, size, size)
			ball.Color = Color3.fromRGB(240, 248, 255)
			ball.Material = Enum.Material.Snow
			ball.CustomPhysicalProperties = PhysicalProperties.new(1.6, 0.3, 0.2)
			ball.CFrame = CFrame.new(site.start + Vector3.new(random:NextNumber(-16, 16), 0, 0))
			ball.Parent = refs.folders.fx
			pcall(function()
				ball:SetNetworkOwner(nil)
			end)
			ball.AssemblyLinearVelocity = site.direction * 18
			Threats.addRoller(ball, size / 2, 32, 72, 14, 16)
			Net.broadcast("Rumble", { position = ball.Position })
		end)
	end
end

-- Leviathan's Rest: tentacles smash up out of the sea around the island, aimed at the thief. A
-- ring on the water, a beat, then the slam. Leave the area and they lose you.
Threats.handlers.Kraken = function()
	local site = refs.troubleSites.Kraken
	if not site then
		return
	end
	repeating(Config.KRAKEN_TIME, Config.KRAKEN_GAP, function()
		local carrier = carrierNear(site.center, site.radius)
		if carrier then
			local v = carrier.root.AssemblyLinearVelocity
			local position = carrier.root.Position + Vector3.new(v.X, 0, v.Z) * Config.KRAKEN_DELAY * 0.9
			position = Vector3.new(
				position.X + random:NextNumber(-5, 5),
				math.max(position.Y - 2, 0),
				position.Z + random:NextNumber(-5, 5)
			)
			Net.broadcast("Tentacle", { position = position, delay = Config.KRAKEN_DELAY })
			Blast.strike(position, Config.KRAKEN_DELAY, {
				radius = 17,
				damage = 30,
				knockback = 95,
				hullDamage = 95,
				boatPush = 85,
				lootReason = "boulder",
				cause = "the leviathan",
				markerColor = Color3.fromRGB(190, 110, 255),
				style = "kraken",
				color = Color3.fromRGB(150, 90, 220),
			})
		end
	end)
end

-- Skull Rock: ghost ships sail out of a fog bank.
Threats.handlers.GhostFleet = function(item, player)
	local site = refs.troubleSites.GhostFleet
	if not site then
		return
	end
	local center = item.spot.Position
	Storms.spawn({
		kind = "fog",
		x = center.X,
		z = center.Z + 120,
		r = 360,
		strength = 1,
		duration = Config.GHOST_FOG_TIME,
	})
	Navy.dispatchGhosts(site.spawns, Config.GHOST_SHIPS, player)
end

-- Tangle Isle: after a rumble the rope bridges snap. The ladders and the zipline are the way out.
Threats.handlers.Quake = function()
	local site = refs.troubleSites.Quake
	if not site then
		return
	end
	Net.broadcast("Quake", { position = site.center })
	local generation = Threats.generation()
	task.delay(Config.QUAKE_DELAY, function()
		if generation == Threats.generation() then
			Destructibles.breakNear(site.center, 300, { bridge = true })
		end
	end)
end

function Troubles.build(worldRefs)
	refs = worldRefs
end

-- A raid ended mid-trouble: drain the vault so the next raid starts dry.
function Troubles.reset()
	local site = refs.troubleSites.Flood
	if flooded and site then
		workspace.Terrain:FillBlock(CFrame.new(site.chamberCenter), site.chamberSize, Enum.Material.Air)
		workspace.Terrain:FillBlock(CFrame.new(site.tunnelCenter), site.tunnelSize, Enum.Material.Air)
		flooded = false
	end
end

return Troubles

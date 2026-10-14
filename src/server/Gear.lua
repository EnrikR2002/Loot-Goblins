-- Gear (V7): a tool you pick up in the world that changes how one island treats you. Three pieces,
-- each made for one hard island (Config.GEAR / Config.ISLAND_INFO):
--   Diver's Rebreather  (Kelp Cay)     swim fast; for the Tide Vault's flood and its eel
--   Cinder Boots        (Lantern Key)  fire, lava and lava bombs do nothing; for Ember Isle
--   Frost Claws         (Lantern Key)  the Chill drains a quarter as much; for Frost Spire
-- Lantern Key offers boots OR claws: one piece is carried at a time, so taking the other swaps.
-- V8: gear is OPTIONAL. Nothing needs it (V7 locked three treasures behind it and the playtest found that a
-- chore); a piece only makes its island kinder.
-- Caches give the gear once per goblin per raid, free: gear is never for sale. Shinies can buy
-- "start the raid with it" (Progress), which is a convenience, not a lock.
-- Pets are read here too (Gear.pet) so the modules that care ask one place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Net = require(script.Parent.Net)

local Gear = {}

local refs

-- What a goblin carries (an id from Config.GEAR) or nil.
function Gear.get(player)
	return player:GetAttribute("Gear")
end

function Gear.has(player, id)
	return player:GetAttribute("Gear") == id
end

-- The pet a goblin has out (an id from Config.PETS) or nil. Server-validated: only Progress sets it.
function Gear.pet(player)
	return player:GetAttribute("Pet")
end

function Gear.petIs(player, id)
	return player:GetAttribute("Pet") == id
end

function Gear.give(player, id, quiet)
	local def = Config.GEAR[id]
	if not def then
		return
	end
	player:SetAttribute("Gear", id)
	if not quiet then
		Net.toast(player, "You took the " .. def.name .. ": " .. def.effect)
	end
end

-- Fire and lava: boots make a goblin immune.
function Gear.fireproof(player)
	return Gear.has(player, "CinderBoots")
end

local function groundAtIsland(island)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	params.IgnoreWater = true
	-- Search outwards from the centre for dry ground: the centre can be a lagoon.
	for radius = 0, 70, 10 do
		for step = 0, 5 do
			local angle = step * math.pi / 3
			local x, z = island.x + math.cos(angle) * radius, island.z + math.sin(angle) * radius
			local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -300, 0), params)
			if hit and hit.Position.Y > 1.5 and hit.Normal.Y > 0.7 then
				return hit.Position
			end
		end
	end
	return nil
end

local function buildCache(islandId, gearId, offsetX)
	local island = Archipelago.byId[islandId]
	local def = Config.GEAR[gearId]
	if not island or not def then
		return
	end
	local ground = groundAtIsland(island)
	if not ground then
		warn("[Gear] no dry ground for the " .. def.name .. " cache on " .. island.name)
		return
	end
	local base = Instance.new("Part")
	base.Name = "GearCache_" .. gearId
	base.Size = Vector3.new(4.4, 3, 3.4)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Wood
	base.Color = Color3.fromRGB(110, 80, 50)
	base.CFrame = CFrame.new(ground + Vector3.new(offsetX or 0, 1.5, 0))
	base.Parent = refs.folders.decor
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(2.6, 2.6, 2.6)
	glow.Anchored = true
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Color = def.color
	glow.CFrame = base.CFrame * CFrame.new(0, 2.8, 0)
	glow.Parent = refs.folders.decor
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 22
	light.Parent = glow
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.name
	prompt.ActionText = "Take it"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if Gear.has(player, gearId) then
			Net.toast(player, "You already carry the " .. def.name .. ".")
			return
		end
		Gear.give(player, gearId)
	end)
	-- A sign saying what it is for, readable only up close (it is gear for another island).
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(190, 46)
	sign.StudsOffset = Vector3.new(0, 5.5, 0)
	sign.MaxDistance = 90
	sign.AlwaysOnTop = false
	sign.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = def.color
	label.TextStrokeTransparency = 0.3
	label.TextSize = 14
	label.TextWrapped = true
	label.Text = def.short .. "\nfor " .. Archipelago.byId[def.for_].name
	label.Parent = sign
end

function Gear.build(worldRefs)
	refs = worldRefs
	buildCache("Kelp", "Rebreather", 0)
	buildCache("Lantern", "CinderBoots", -5)
	buildCache("Lantern", "FrostClaws", 5)
end

-- A raid is over: everything carried goes back to the caches. (Progress hands out start-gear again.)
function Gear.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Gear", nil)
	end
end

function Gear.forget(_player) end

return Gear

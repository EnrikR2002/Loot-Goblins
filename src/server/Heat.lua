-- Heat: one shared trouble meter for the whole raid. Stealing loot from its
-- spot adds a chunk, carrying loot outside the ward keeps adding, and it cools
-- while nobody carries anything. Tiers decide how hard the world hits back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local Heat = {}
Heat.value = 0
Heat.tier = 1
Heat.TierChanged = Util.signal() -- (newTier, oldTier)

local function tierFor(value)
	local tier = 1
	for i, t in ipairs(Config.HEAT_TIERS) do
		if value >= t.at then
			tier = i
		end
	end
	return tier
end

local function publish()
	-- Whole numbers keep the attribute from replicating every frame.
	local shown = math.floor(Heat.value + 0.5)
	if workspace:GetAttribute("Heat") ~= shown then
		workspace:SetAttribute("Heat", shown)
	end
	local tier = tierFor(Heat.value)
	if tier ~= Heat.tier then
		local old = Heat.tier
		Heat.tier = tier
		workspace:SetAttribute("HeatTier", tier)
		Heat.TierChanged:Fire(tier, old)
	end
end

function Heat.add(amount)
	Heat.value = math.clamp(Heat.value + amount, 0, Config.HEAT_MAX)
	publish()
end

-- carryRate: heat per second from everyone carrying loot outside the Hoard ward (each carrier
-- contributes in proportion to how hot their treasure is, so a cheap trinket stays quiet and a
-- deep treasure escalates fast). Zero means nobody is carrying: Heat cools.
function Heat.tick(dt, carryRate)
	if carryRate > 0 then
		Heat.add(math.min(carryRate, Config.HEAT_CARRY_RATE_CAP) * dt)
	else
		Heat.add(-Config.HEAT_DECAY_RATE * dt)
	end
end

function Heat.reset()
	Heat.value = 0
	Heat.tier = 1
	workspace:SetAttribute("Heat", 0)
	workspace:SetAttribute("HeatTier", 1)
end

function Heat.tierInfo(tier)
	return Config.HEAT_TIERS[tier or Heat.tier]
end

return Heat

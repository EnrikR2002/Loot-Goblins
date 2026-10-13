-- What Heat DOES. The meter is shared and the tiers are qualitative: each step changes how the
-- world plays, not just how hard it hits.
--
--   ALERT   (25)  Flares. Every carrier outside the Hoard's ward fires a signal that all players see,
--                 with a long beam of light, so a thief on the open sea is visible from the next
--                 island. (Carriers also glow through walls; the totems wake. Threats.lua.)
--   HUNTED  (50)  The Navy sails: patrol ships head for the most valuable carrier. (The Guardian
--                 hunts from the temple.) A second ship follows if the first is sunk or lost.
--   FRENZY  (80)  The sea turns: a tempest sails in from a flank, steering at the thief (Storms),
--                 and the whole sea runs rougher. The Guardian is unleashed beyond its island.
--
-- All of it is answerable. Heat falls while nobody carries, patrol ships lose you behind an island or
-- in the shallows, the tempest is slower than a boat, and flares only reveal where you are, not
-- where you are going. Dropping a tier stands the Navy down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Sea = require(script.Parent.Sea)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)
local Navy = require(script.Parent.Navy)
local Storms = require(script.Parent.Storms)

local Escalation = {}

local refs
local nextFlareAt = 0
local nextNavyCheckAt = 0
local tempestSent = false

local function now()
	return workspace:GetServerTimeNow()
end

local function inWard(position)
	return Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS
end

-- The carrier holding the most valuable loot, outside the ward.
local function topCarrier()
	local best
	for _, carrier in ipairs(Loot.carriers()) do
		if not inWard(carrier.root.Position) and (not best or carrier.item.def.value > best.item.def.value) then
			best = carrier
		end
	end
	return best
end

local function onTierChanged(tier, old)
	if tier > old then
		if tier >= 3 then
			local carrier = topCarrier()
			if carrier then
				Navy.dispatch(carrier.player, 1)
			end
		end
		if tier >= 4 and not tempestSent then
			local carrier = topCarrier()
			if carrier then
				tempestSent = true
				Storms.hunt(carrier.player)
				Sea.rough = Config.FRENZY_ROUGH
				Net.broadcast("Frenzy", {})
			end
		end
	else
		if tier < 3 then
			Navy.standDown()
		end
		if tier < 4 then
			tempestSent = false
			Sea.rough = 0
		end
	end
end

function Escalation.tick()
	local t = now()
	local tier = Heat.tier
	if tier >= 2 and t >= nextFlareAt then
		nextFlareAt = t + Config.FLARE_GAP
		for _, carrier in ipairs(Loot.carriers()) do
			if not inWard(carrier.root.Position) then
				Net.broadcast("Flare", {
					position = carrier.root.Position,
					userId = carrier.player.UserId,
					color = carrier.item.def.color,
					name = carrier.player.DisplayName,
				})
			end
		end
	end
	if t >= nextNavyCheckAt then
		nextNavyCheckAt = t + 4
		if tier >= 3 then
			local want = tier >= 4 and 2 or 1
			local carrier = topCarrier()
			if carrier and Navy.count() < want then
				Navy.dispatch(carrier.player, 1)
			end
		end
		if tier >= 4 and not tempestSent then
			local carrier = topCarrier()
			if carrier then
				tempestSent = true
				Storms.hunt(carrier.player)
				Sea.rough = Config.FRENZY_ROUGH
			end
		end
	end
end

function Escalation.build(worldRefs)
	refs = worldRefs
	Heat.TierChanged:Connect(onTierChanged)
end

function Escalation.reset()
	tempestSent = false
	Sea.rough = 0
	nextFlareAt = 0
	nextNavyCheckAt = 0
end

return Escalation

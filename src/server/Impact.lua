-- Being hit by the WORLD (V8). One set of rules for everything that is not another goblin:
-- creatures, the Guardian, lava, blades, boulders, lightning, Navy shells, sea monsters.
--
-- The V7 playtest found the chaos funny and its price too high: a goblin in the middle of three
-- things going wrong lost health, control and treasure to each of them in the same second. So:
--   * GRACE. After a world hit lands, nothing else from the world can land on that goblin for
--     Config.IMPACT.GRACE seconds: one thing happens to you at a time, and you get to answer it.
--   * SMALLER BITES. World damage is scaled by DAMAGE_SCALE, and a hit cannot kill a goblin who had
--     more than LAST_STAND health: it leaves them on 1. Dying takes two mistakes, not one.
--   * A hit moves you (knockback is unchanged): being thrown is the fun part.
-- What it does NOT touch: anything a rival does (sword, a thrown keg, a fired cannon, the grapple
-- catch). Those keep their own rules, so a creature brushing a carrier never shields them from a
-- thief. Treasure has its own rule, in Loot.knockLoose (V8 to V13 the two-strike grip; V13.1: the world never
-- takes treasure, it hurts a carrier instead, and a knockout drops it: server/Knockout.lua).
--
-- Callers ask Impact.open(player) before a world hit and only apply it if that returns true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Impact = {}

local lastHit = {} -- player -> server time of the last world hit that landed

local function now()
	return workspace:GetServerTimeNow()
end

-- May the world hit this goblin now? True stamps the grace period.
function Impact.open(player)
	local t = now()
	if t - (lastHit[player] or -math.huge) < Config.IMPACT.GRACE then
		return false
	end
	lastHit[player] = t
	player:SetAttribute("WorldHitAt", t)
	return true
end

-- Is this goblin inside the grace period (without stamping it)?
function Impact.shielded(player)
	return now() - (lastHit[player] or -math.huge) < Config.IMPACT.GRACE
end

-- World damage: scaled, and never the whole of a healthy goblin (V13.1: unless they carry treasure: for a carrier
-- the danger is meant to be real, Config.KNOCKOUT). Returns what was dealt.
function Impact.damage(humanoid, amount)
	if amount <= 0 or humanoid.Health <= 0 then
		return 0
	end
	amount *= Config.IMPACT.DAMAGE_SCALE
	local before = humanoid.Health
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	local carrier = player ~= nil and player:GetAttribute("CarryingLoot") ~= nil
	if before > Config.IMPACT.LAST_STAND and not carrier then
		amount = math.min(amount, before - 1)
	end
	humanoid:TakeDamage(amount)
	return before - humanoid.Health
end

-- V9: nothing from the world lands on this goblin for `seconds` (after a launch high into the air: they
-- should get to enjoy the flight and land before anything else happens to them).
function Impact.protect(player, seconds)
	local t = now()
	lastHit[player] = math.max(lastHit[player] or -math.huge, t + seconds - Config.IMPACT.GRACE)
	player:SetAttribute("WorldHitAt", t)
end

function Impact.forget(player)
	lastHit[player] = nil
end

function Impact.reset()
	table.clear(lastHit)
end

return Impact

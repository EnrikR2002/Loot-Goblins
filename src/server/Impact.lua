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
-- thief. Treasure has its own rule, in Loot.knockLoose (the two-strike grip).
--
-- Callers ask Impact.open(player) before a world hit and only apply it if that returns true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- World damage: scaled, and never the whole of a healthy goblin. Returns what was dealt.
function Impact.damage(humanoid, amount)
	if amount <= 0 or humanoid.Health <= 0 then
		return 0
	end
	amount *= Config.IMPACT.DAMAGE_SCALE
	local before = humanoid.Health
	if before > Config.IMPACT.LAST_STAND then
		amount = math.min(amount, before - 1)
	end
	humanoid:TakeDamage(amount)
	return before - humanoid.Health
end

function Impact.forget(player)
	lastHit[player] = nil
end

function Impact.reset()
	table.clear(lastHit)
end

return Impact

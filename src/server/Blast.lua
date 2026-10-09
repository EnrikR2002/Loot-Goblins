-- One place for "something goes bang". Cannonballs, powder kegs, barrels, the Guardian's
-- boulders, lava bombs, lightning, tentacle slams and Navy shells all call Blast.at, so the
-- rules stay the same everywhere:
--
--   players   damage with falloff, shoved away, carriers' loot knocked loose
--             (the one who set it off takes the shove at half strength and no damage, so a keg
--              at your feet is a launcher, not a suicide)
--   boats     hull damage and a shove (Boats.hitAt)
--   loot      loose loot is thrown around
--   structures cracked walls, gates, bridges and other barrels (Destructibles)
--
-- Blast.strike announces a blast first (a marker players can see and dodge), then lands it.
local Players = game:GetService("Players")

local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Loot = require(script.Parent.Loot)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Destructibles = require(script.Parent.Destructibles)

local Blast = {}
local generation = 0 -- Bumped on reset, so strikes from an old raid never land.

-- opts: radius, damage, knockback, hullDamage, boatPush, breakPower, lootReason, owner (Player),
-- cause (text for the wreck feed), color.
function Blast.at(position, opts)
	local radius = opts.radius or 12
	local owner = opts.owner
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			local offset = root.Position - position
			local distance = offset.Magnitude
			if distance <= radius then
				local falloff = 1 - 0.55 * distance / radius
				local isOwner = player == owner
				if (opts.damage or 0) > 0 and not isOwner then
					local dealt = Util.damage(humanoid, opts.damage * falloff)
					if owner then
						Poltergoblin.markDamage(owner, humanoid, dealt)
					end
				end
				local push = (opts.knockback or 0) * falloff * (isOwner and 0.5 or 1)
				if push > 0 then
					local direction = distance > 0.1 and offset.Unit or Vector3.yAxis
					Util.knockback(root, direction * push + Vector3.new(0, push * 0.55, 0), 0.22)
				end
				if opts.lootReason and not isOwner then
					Loot.knockLoose(player, position, opts.lootReason, owner)
				end
			end
		end
	end
	if (opts.hullDamage or 0) > 0 or (opts.boatPush or 0) > 0 then
		Boats.hitAt(position, radius, opts.hullDamage or 0, opts.boatPush or 0, opts.cause, opts.exceptBoat)
	end
	for _, item in ipairs(Loot.items) do
		if item.state == "loose" then
			local offset = item.core.Position - position
			if offset.Magnitude <= radius then
				local direction = offset.Magnitude > 0.1 and offset.Unit or Vector3.yAxis
				item.core:ApplyImpulse(
					(direction + Vector3.new(0, 0.8, 0)) * item.core.AssemblyMass * (opts.knockback or 40) * 0.4
				)
			end
		end
	end
	if (opts.breakPower or 0) > 0 then
		Destructibles.blastAt(position, radius, opts.breakPower)
	end
	Net.broadcast("Blast", { position = position, radius = radius, color = opts.color })
end

-- Marks a spot, then blasts it after `delay` seconds. The marker is the warning: it closes in
-- over the delay so players can read when it lands and get out.
function Blast.strike(position, delay, opts)
	Net.broadcast("Marker", {
		position = position,
		radius = opts.radius or 12,
		duration = delay,
		color = opts.markerColor,
		style = opts.style,
	})
	local current = generation
	task.delay(delay, function()
		if current == generation then
			if opts.bolt then
				Net.broadcast("Bolt", { position = position })
			end
			Blast.at(position, opts)
		end
	end)
end

function Blast.reset()
	generation += 1
end

Destructibles.explode = Blast.at

return Blast

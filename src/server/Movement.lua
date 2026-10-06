-- The server owns WalkSpeed. Every speed effect goes through here, so carrying,
-- water and spirit form stack instead of overwriting each other.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local Movement = {}

local carrySpeed = {} -- player -> speed while holding loot
local boost = {} -- player -> multiplier (Poltergoblin)

function Movement.setCarrySpeed(player, speed)
	carrySpeed[player] = speed
end

function Movement.setBoost(player, multiplier)
	boost[player] = multiplier
end

function Movement.inWater(root)
	return root.Position.Y < Config.WATER_ROOT_Y
end

function Movement.speedFor(player, root)
	local speed = carrySpeed[player] or Config.WALK_SPEED
	if root and Movement.inWater(root) then
		speed *= Config.WATER_SPEED_MULT
	end
	speed *= boost[player] or 1
	-- Half-stud steps keep WalkSpeed from replicating every frame.
	return math.floor(speed * 2 + 0.5) / 2
end

function Movement.tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			local speed = Movement.speedFor(player, root)
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
	end
end

function Movement.forget(player)
	carrySpeed[player] = nil
	boost[player] = nil
end

return Movement

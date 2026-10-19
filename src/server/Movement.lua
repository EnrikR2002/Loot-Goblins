-- The server owns WalkSpeed. Every speed effect goes through here, so carrying,
-- sprinting, water and spirit form stack instead of overwriting each other.
--
-- Running is fast and never costs anything. Stamina pays for the exceptional moves:
--   dash      C (V13.2: or Shift on foot): a short burst the client plays on its own character at once; the server
--             takes the stamina and enforces the cooldown
--   air jump  one extra jump per flight, same split
--   swings    a carrier's heavy sword swing (Combat calls Movement.spend)
-- Carrying loot makes every cost bigger, by the treasure's weight, so a carrier is not slow, but cannot do everything
-- at once.
-- V13.2: there is no sprint. The speed here is the BASE a goblin's own client multiplies by its MOMENTUM
-- (shared/Momentum.lua: from 0.75 of it at the first step to 1.36 after a couple of seconds of running on). The base is
-- published as the MoveCap attribute; WalkSpeed is set to it too, so a client that does not play momentum runs at the
-- ordinary run.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Gear = require(script.Parent.Gear)
local Net = require(script.Parent.Net)

local Movement = {}

local REQUEST_SLACK = 0.75 -- Requests arrive with latency: allow them a little early.

local carrySpeed = {} -- player -> speed while holding loot
local carryWeight = {} -- player -> weight of the loot held
local boost = {} -- player -> multiplier (Poltergoblin)
local stamina = {} -- player -> { value, lastSpendAt, dashAt, airAt }

-- speed and weight of the loot the player holds, or nil for empty hands.
function Movement.setCarry(player, speed, weight)
	carrySpeed[player] = speed
	carryWeight[player] = speed and (weight or 1) or nil
end

function Movement.setBoost(player, multiplier)
	boost[player] = multiplier
end

-- V13.2: there is no sprint any more; kept so the callers that stop it (a catch, a knockout) need not change.
function Movement.setSprintHeld(_player, _held) end

function Movement.inWater(root)
	return root.Position.Y < Config.WATER_ROOT_Y
end

local function staminaOf(player)
	local s = stamina[player]
	if not s then
		s = {
			value = Config.STAMINA_MAX,
			lastSpendAt = -math.huge,
			dashAt = -math.huge,
			airAt = -math.huge,
		}
		stamina[player] = s
	end
	return s
end

-- Loot makes stamina costs bigger (the client shows the same number: Hud and Main).
local function costMult(player)
	return 1 + (carryWeight[player] or 0) * Config.CARRY_STAMINA_PER_WEIGHT
end

-- The base run (momentum multiplies it on the goblin's own client).
function Movement.speedFor(player, root)
	local carry = carrySpeed[player]
	local speed = carry or Config.WALK_SPEED
	if root and Movement.inWater(root) then
		speed *= Config.WATER_SPEED_MULT * (Gear.has(player, "Rebreather") and Config.REBREATHER_SWIM or 1)
	end
	speed *= boost[player] or 1
	-- Half-stud steps keep WalkSpeed from replicating every frame.
	return math.floor(speed * 2 + 0.5) / 2
end

-- The client draws the stamina bar from these attributes.
local function publish(player, s)
	local shown = math.floor(s.value + 0.5)
	if player:GetAttribute("Stamina") ~= shown then
		player:SetAttribute("Stamina", shown)
	end
end

-- The Chill (Frost Spire's inhabitant): for `seconds`, stamina comes back at a crawl and
-- leaks away. It is the one thing in the game that attacks stamina instead of health.
local chillUntil = {}

function Movement.chill(player, seconds)
	chillUntil[player] = math.max(chillUntil[player] or 0, os.clock() + seconds)
end

local function tickStamina(player, dt, t)
	local s = staminaOf(player)
	local chilled = (chillUntil[player] or 0) > t
	if (player:GetAttribute("Chilled") == true) ~= chilled then
		player:SetAttribute("Chilled", chilled or nil)
	end
	if t - s.lastSpendAt >= Config.STAMINA_REGEN_DELAY then
		s.value =
			math.min(s.value + Config.STAMINA_REGEN * (chilled and Config.CHILL_REGEN or 1) * dt, Config.STAMINA_MAX)
	end
	if chilled then
		s.value = math.max(
			s.value - Config.CHILL_DRAIN * (Gear.has(player, "FrostClaws") and Config.CLAWS_CHILL or 1) * dt,
			0
		)
	end
	publish(player, s)
end

function Movement.tick(dt)
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			tickStamina(player, dt, t)
			local speed = Movement.speedFor(player, root)
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
			if player:GetAttribute("MoveCap") ~= speed then
				player:SetAttribute("MoveCap", speed)
			end
		end
	end
end

-- Spends stamina on an action. False if there isn't enough. It also pauses regen, like
-- sprinting does, so nobody can spend and recover at once. Loot weight scales the cost.
function Movement.spend(player, amount)
	local s = staminaOf(player)
	amount *= costMult(player)
	if s.value < amount then
		return false
	end
	s.value -= amount
	s.lastSpendAt = os.clock()
	publish(player, s)
	return true
end

-- The client played a dash or an air jump on its own character and asks us to pay for it.
-- The server cannot stop a client moving its own character (Roblox gives each client its own
-- physics), so this only keeps the meter and the cooldown honest.
function Movement.request(player, kind)
	local root, humanoid = Util.aliveRoot(player)
	if not root or humanoid.SeatPart then
		return
	end
	local s = staminaOf(player)
	local t = os.clock()
	if kind == "dash" then
		local cooldown = Config.DASH_COOLDOWN * (Gear.petIs(player, "Frog") and Config.PET_FROG_DASH or 1)
		if t - s.dashAt < cooldown * REQUEST_SLACK or not Movement.spend(player, Config.DASH_COST) then
			return
		end
		s.dashAt = t
		Net.broadcast("Dash", { userId = player.UserId, position = root.Position })
	elseif kind == "airjump" then
		if t - s.airAt < 0.25 or not Movement.spend(player, Config.AIR_JUMP_COST) then
			return
		end
		s.airAt = t
		Net.broadcast("AirJump", { userId = player.UserId, position = root.Position })
	end
end

-- A fresh character starts with full stamina.
function Movement.refill(player)
	local s = staminaOf(player)
	s.value = Config.STAMINA_MAX
	publish(player, s)
end

function Movement.forget(player)
	carrySpeed[player] = nil
	carryWeight[player] = nil
	boost[player] = nil
	stamina[player] = nil
end

return Movement

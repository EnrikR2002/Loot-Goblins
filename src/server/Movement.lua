-- The server owns WalkSpeed. Every speed effect goes through here, so carrying,
-- sprinting, water and spirit form stack instead of overwriting each other.
--
-- Running is fast and never costs anything. Stamina pays for the exceptional moves:
--   sprint    the client only says "Shift is held"; the server decides whether you are
--             really sprinting (moving, on foot, stamina left) and drains the meter
--   dash      C: a short burst the client plays on its own character at once; the server
--             takes the stamina and enforces the cooldown
--   air jump  one extra jump per flight, same split
--   swings    a carrier's heavy sword swing (Combat calls Movement.spend)
-- Run the meter dry by sprinting and you're winded: no sprinting until it refills to
-- STAMINA_RECOVER. Carrying loot makes every cost bigger, by the treasure's weight, so a
-- carrier is not slow, but cannot do everything at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)

local Movement = {}

local MOVING_SPEED = 4 -- Slower than this counts as standing still (no stamina used).
local REQUEST_SLACK = 0.75 -- Requests arrive with latency: allow them a little early.

local carrySpeed = {} -- player -> speed while holding loot
local carryWeight = {} -- player -> weight of the loot held
local boost = {} -- player -> multiplier (Poltergoblin)
local sprintHeld = {} -- player -> true while the sprint key is held
local stamina = {} -- player -> { value, winded, sprinting, lastSpendAt, dashAt, airAt }

-- speed and weight of the loot the player holds, or nil for empty hands.
function Movement.setCarry(player, speed, weight)
	carrySpeed[player] = speed
	carryWeight[player] = speed and (weight or 1) or nil
end

function Movement.setBoost(player, multiplier)
	boost[player] = multiplier
end

function Movement.setSprintHeld(player, held)
	sprintHeld[player] = held or nil
end

function Movement.inWater(root)
	return root.Position.Y < Config.WATER_ROOT_Y
end

local function staminaOf(player)
	local s = stamina[player]
	if not s then
		s = {
			value = Config.STAMINA_MAX,
			winded = false,
			sprinting = false,
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

function Movement.isSprinting(player)
	local s = stamina[player]
	return s ~= nil and s.sprinting
end

function Movement.speedFor(player, root)
	local carry = carrySpeed[player]
	local speed = carry or Config.WALK_SPEED
	if Movement.isSprinting(player) then
		speed *= carry and Config.CARRY_SPRINT_MULT or Config.SPRINT_MULT
	end
	if root and Movement.inWater(root) then
		speed *= Config.WATER_SPEED_MULT
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
	if player:GetAttribute("Sprinting") ~= s.sprinting then
		player:SetAttribute("Sprinting", s.sprinting)
	end
	if player:GetAttribute("Winded") ~= s.winded then
		player:SetAttribute("Winded", s.winded)
	end
end

local function tickStamina(player, root, humanoid, dt, t)
	local s = staminaOf(player)
	local velocity = root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
	s.sprinting = sprintHeld[player] == true and moving and not s.winded and s.value > 0 and humanoid.SeatPart == nil
	if s.sprinting then
		s.value = math.max(s.value - Config.STAMINA_DRAIN * costMult(player) * dt, 0)
		s.lastSpendAt = t
		if s.value <= 0 then
			s.winded = true
		end
	elseif t - s.lastSpendAt >= Config.STAMINA_REGEN_DELAY then
		s.value = math.min(s.value + Config.STAMINA_REGEN * dt, Config.STAMINA_MAX)
	end
	if s.winded and s.value >= Config.STAMINA_RECOVER then
		s.winded = false
	end
	publish(player, s)
end

function Movement.tick(dt)
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			tickStamina(player, root, humanoid, dt, t)
			local speed = Movement.speedFor(player, root)
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
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
		if t - s.dashAt < Config.DASH_COOLDOWN * REQUEST_SLACK or not Movement.spend(player, Config.DASH_COST) then
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
	s.winded = false
	s.sprinting = false
	publish(player, s)
end

function Movement.forget(player)
	carrySpeed[player] = nil
	carryWeight[player] = nil
	boost[player] = nil
	sprintHeld[player] = nil
	stamina[player] = nil
end

return Movement

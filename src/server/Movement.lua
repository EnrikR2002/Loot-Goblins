-- The server owns WalkSpeed. Every speed effect goes through here, so carrying,
-- sprinting, water and spirit form stack instead of overwriting each other.
--
-- Sprint: the client only says "Shift is held". The server decides whether you
-- are really sprinting (moving, on foot, out of the water, stamina left) and
-- owns the stamina meter. Run it dry and you're winded: no sprinting until it
-- refills to STAMINA_RECOVER. Carriers sprint too, but only a little.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local Movement = {}

local MOVING_SPEED = 4 -- Slower than this counts as standing still (no stamina used).

local carrySpeed = {} -- player -> speed while holding loot
local boost = {} -- player -> multiplier (Poltergoblin)
local sprintHeld = {} -- player -> true while the sprint key is held
local stamina = {} -- player -> { value, winded, sprinting, lastSprintAt }

function Movement.setCarrySpeed(player, speed)
	carrySpeed[player] = speed
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
		s = { value = Config.STAMINA_MAX, winded = false, sprinting = false, lastSprintAt = -math.huge }
		stamina[player] = s
	end
	return s
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
	s.sprinting = sprintHeld[player] == true
		and moving
		and not s.winded
		and s.value > 0
		and humanoid.SeatPart == nil
		and not Movement.inWater(root)
	if s.sprinting then
		s.value = math.max(s.value - Config.STAMINA_DRAIN * dt, 0)
		s.lastSprintAt = t
		if s.value <= 0 then
			s.winded = true
		end
	elseif t - s.lastSprintAt >= Config.STAMINA_REGEN_DELAY then
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
	boost[player] = nil
	sprintHeld[player] = nil
	stamina[player] = nil
end

return Movement

-- The KNOCKOUT (V13.1, the V13 playtest: "death equals being knocked out for 5 seconds, no respawn shenanigans").
--
-- A goblin whose health runs out does not die. Roblox's Dead state is switched off on their humanoid (here, and on
-- their own client: client/Main.client.lua), so health 0 is just a number, and this module turns it into:
--   * KNOCKED OUT where they fell for Config.KNOCKOUT.TIME seconds (a SPIRIT pet shortens it): flat on the ground
--     (PlatformStand), or slumped at the wheel of their boat, which coasts; the player attribute KnockedOutUntil
--     tells their client to dim the screen, count down and ignore their keys.
--   * whatever they carried DROPS there (Loot.dropFor "knockout"): loose, for anyone, and the pursuer that was after
--     them circles it for a while (Pursuit) in case they get up and grab it again.
--   * then they GET UP with full health, where they lay, with WAKE_GRACE seconds before the world can hit them.
-- Util.aliveRoot counts a knocked-out goblin as down, so nothing targets, damages or steers by them meanwhile.
--
-- The one real respawn left: a body that falls out of the world (below VOID_Y) or loses its root is rebuilt by
-- LoadCharacter (it lands wherever Raid.placeCharacter puts it). The Reset button asks for the same (a goblin who
-- is stuck can still get unstuck), dropping their treasure first.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Impact = require(script.Parent.Impact)
local Movement = require(script.Parent.Movement)
local Gear = require(script.Parent.Gear)

local Knockout = {}

-- (player, cause) after a goblin is knocked out; Main tells Poltergoblin and anything else that cares.
Knockout.KnockedOut = Util.signal()

local K = Config.KNOCKOUT
local tokens = {} -- player -> number: a knockout's identity (a new body or a new knockout makes the old one stale)
local respawning = {} -- player -> true while a LoadCharacter is pending

local function now()
	return workspace:GetServerTimeNow()
end

function Knockout.isOut(player)
	local untilAt = player:GetAttribute("KnockedOutUntil")
	return untilAt ~= nil
end

local function timeFor(player)
	return K.TIME * (Gear.petIs(player, "Ghost") and Config.PET_GHOST_KNOCKOUT or 1)
end

local function wake(player, humanoid, token)
	if tokens[player] ~= token or not humanoid.Parent then
		return
	end
	player:SetAttribute("KnockedOutUntil", nil)
	player:SetAttribute("WokeAt", now())
	humanoid.Health = humanoid.MaxHealth
	if not humanoid.SeatPart then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	Impact.protect(player, K.WAKE_GRACE)
	Net.send(player, "WokeUp", {})
end

-- Knock this goblin out (their health has run out). `cause` is for the feed.
function Knockout.start(player, cause)
	local _, humanoid, root = Util.getCharacterParts(player)
	if not humanoid or Knockout.isOut(player) then
		return false
	end
	local t = now()
	local seconds = timeFor(player)
	local token = (tokens[player] or 0) + 1
	tokens[player] = token
	player:SetAttribute("KnockedOutUntil", t + seconds)
	player:SetAttribute("KnockedOutAt", t)
	-- What they held lies where they fell (a seated goblin's treasure tumbles over the side). The feed says so
	-- ("... was KNOCKED OUT and dropped the ...": Main's Loosened line); an empty-handed knockout gets its own line.
	local carried = Loot.itemOf(player) ~= nil
	Loot.dropFor(player, "knockout")
	Movement.setSprintHeld(player, false)
	if not humanoid.SeatPart then
		humanoid.PlatformStand = true
		-- Down they go: a little hop backwards so it reads as a knockout, not a freeze.
		local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		Util.knockback(root, back * 12 + Vector3.new(0, 18, 0), 0.15)
	end
	Impact.protect(player, seconds + 0.5) -- nothing more from the world while they are down
	Net.send(player, "KnockedOut", { seconds = seconds, cause = cause })
	if not carried then
		Net.feed(
			player.DisplayName .. " was knocked out" .. (cause and (" by " .. cause) or "") .. "!",
			Color3.fromRGB(255, 150, 120)
		)
	end
	Knockout.KnockedOut:Fire(player, cause)
	task.delay(seconds, wake, player, humanoid, token)
	return true
end

-- A real respawn (fallen out of the world, a broken body, or the Reset button).
function Knockout.respawn(player, why)
	if respawning[player] or not player.Parent then
		return
	end
	respawning[player] = true
	Loot.dropFor(player, why or "respawn")
	tokens[player] = (tokens[player] or 0) + 1
	player:SetAttribute("KnockedOutUntil", nil)
	task.defer(function()
		if player.Parent then
			player:LoadCharacter()
		end
		respawning[player] = nil
	end)
end

-- A new body: no Dead state (so health 0 is a knockout, not a death), and the watch on its health.
function Knockout.watch(player, character, humanoid)
	tokens[player] = (tokens[player] or 0) + 1
	player:SetAttribute("KnockedOutUntil", nil)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.HealthChanged:Connect(function(health)
		if player.Character ~= character then
			return
		end
		if health <= 0 then
			if not Knockout.isOut(player) then
				local hitAt = player:GetAttribute("LastHitAt")
				local fresh = hitAt and now() - hitAt < 3
				Knockout.start(player, fresh and player:GetAttribute("LastHitBy") or nil)
			end
		elseif Knockout.isOut(player) and health < humanoid.MaxHealth then
			-- Roblox's own regeneration ticks a downed goblin's health up: they stay down until they wake.
			humanoid.Health = 0
		end
	end)
end

-- Each frame (cheap): bodies that fell out of the world, or lost their root, are rebuilt.
local nextCheck = 0
function Knockout.tick()
	local t = os.clock()
	if t < nextCheck then
		return
	end
	nextCheck = t + 0.5
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.Parent and not respawning[player] then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or root.Position.Y < K.VOID_Y then
				Knockout.respawn(player, "lost")
			end
		end
	end
end

function Knockout.forget(player)
	tokens[player] = nil
	respawning[player] = nil
end

-- Between raids nobody stays down.
function Knockout.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		if Knockout.isOut(player) then
			local _, humanoid = Util.getCharacterParts(player)
			if humanoid then
				wake(player, humanoid, tokens[player])
			end
		end
	end
end

return Knockout

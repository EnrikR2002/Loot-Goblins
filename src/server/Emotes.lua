-- Emotes and victory dances (V11): the server decides who may emote and when it stops; every client draws it
-- (client/Looks.lua, shared/EmoteMoves.lua). The player attribute Emote = "id@serverTime" is the whole state.
--
-- An emote is allowed for an owned emote, on a live goblin standing on something, not seated, not flying, not knocked
-- down and not a spirit; one at a time, at most one start a second. It ends when its time is up or the goblin moves,
-- jumps, sits, dies or is launched: a pose only (it never moves the character), so it can never be a way to travel or
-- dodge, and it never touches treasure, hits or boats.
-- The winner of a raid plays their equipped victory dance on the skyship's deck as the results come up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local EmoteMoves = require(Shared:WaitForChild("EmoteMoves"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Util = require(script.Parent.Util)

local Emotes = {}

local active = {} -- player -> { id, untilTime, start }
local lastStart = {} -- player -> time

local function now()
	return workspace:GetServerTimeNow()
end

local function stop(player)
	if active[player] then
		active[player] = nil
		if player.Parent then
			player:SetAttribute("Emote", nil)
		end
	end
end

-- Can this goblin strike a pose right now?
local function free(player)
	local root, humanoid = Util.aliveRoot(player)
	if not root or not humanoid then
		return false
	end
	if humanoid.SeatPart or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	if player:GetAttribute("Diving") or (player:GetAttribute("DownedUntil") or 0) > now() then
		return false
	end
	if Poltergoblin.isSpirit(player) then
		return false
	end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude < 4
end

local function start(player, id)
	local move = EmoteMoves.get(id)
	local root = Util.aliveRoot(player)
	if not move or not root then
		return false
	end
	local t = now()
	active[player] = { id = id, untilTime = t + move.duration, start = root.Position }
	lastStart[player] = time()
	player:SetAttribute("Emote", string.format("%s@%.3f", id, t))
	return true
end

-- EmoteRequest(id | "stop").
function Emotes.request(player, id)
	if id == "stop" then
		stop(player)
		return
	end
	local item = Catalog.get(id)
	if not item or item.slot ~= "emote" or not Progress.owns(player, id) then
		return
	end
	if time() - (lastStart[player] or 0) < 1 or not free(player) then
		return
	end
	start(player, id)
end

-- The raid's winners dance (V13: after Port.arriveWinners has put them on the podium).
function Emotes.celebrate(player)
	if not player.Parent then
		return
	end
	local look = Progress.look(player)
	local id = look.victory or "victory_cheer"
	local move = EmoteMoves.get(id)
	if not move then
		return
	end
	stop(player)
	if start(player, id) then
		Net.broadcast("Celebrate", { userId = player.UserId, id = id, fx = move.fx })
	end
end

function Emotes.tick()
	local t = now()
	for player, entry in pairs(active) do
		local root, humanoid = Util.aliveRoot(player)
		local ended = t >= entry.untilTime or not root or not humanoid
		if not ended then
			local moved = Vector3.new(root.Position.X - entry.start.X, 0, root.Position.Z - entry.start.Z).Magnitude
			ended = moved > 2.5 or humanoid.SeatPart ~= nil or player:GetAttribute("Diving") ~= nil
		end
		if ended then
			stop(player)
		end
	end
end

function Emotes.forget(player)
	active[player] = nil
	lastStart[player] = nil
end

Players.PlayerRemoving:Connect(Emotes.forget)

return Emotes

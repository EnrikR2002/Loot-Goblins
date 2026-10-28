-- The Port's games (V13.3, The Living Port): one framework for all seven, so each game is only what makes it itself.
-- A game module (server/Regatta.lua, Gauntlet.lua, CannonGolf.lua, PetDerby.lua, TreasureToss.lua, TargetGallery.lua,
-- CrabChaos.lua) registers here and gives a few hooks; this module runs everything around them:
--
--   JOINING    a prompt at the venue (E), a challenge (server/Challenges.lua), or AGAIN on the results. Only a goblin in
--              the Port and in no other game. HEAT games (one session at a time: the Regatta, the Derby, the Toss, the
--              Gallery, Crab Chaos) wait in a LOBBY for Config.PLAYGROUND.LOBBY seconds after the first goblin steps in;
--              anyone arriving while a heat runs is QUEUED for the next one. CONCURRENT games (the Gauntlet, Golf) give
--              every goblin (or challenge pair) a run of their own at once, up to the game's own limit.
--   A HEAT     lobby -> countdown (COUNTDOWN s: everyone placed and held) -> running -> results (RESULTS s) -> closed.
--              The game says when a goblin is DONE and with what score (Minigames.done) or keeps a running score
--              (Minigames.points); the heat ends when everyone is done, when the game's time runs out, or when
--              nobody is left in it.
--   LEAVING    LEAVE on the screen, walking off during the lobby, disconnecting, a reset, the goblin's raid setting off
--              (the raid always wins: Raid.lua calls Minigames.leaveAll first), or the Zone becoming the raid. The game
--              cleans up that goblin's things (its `drop` hook); a heat with nobody left in it ends.
--   RESULTS    standings by score (ties share a place). A score counts for rewards when the goblin FINISHED (a time
--              game) or scored above zero (a points game): standing about earns nothing. What a run pays, the daily
--              caps, bests, quests and boards are Progress's (Minigames.reward, set by Main: server/Progress.lua and
--              shared/PortGames.lua). Everyone in the heat gets their own breakdown ("PlayResult").
--   TELLING    every session publishes a JSON StringValue in ReplicatedStorage.LootGoblinsPlay (its state, clocks,
--              roster and scores, and anything the game adds), and games that move a lot publish a second, faster one
--              (`<id>.live`). Clients draw everything from those (client/PlayHud.lua). Players carry PlayGame and
--              PlaySession attributes.
--
-- A game module: { id, concurrent, limit (concurrent sessions), max (players), duration (seconds after GO),
--   build(kit), prepare(session), go(session, t), tick(session, dt, t), input(session, player, action, a, b),
--   drop(session, player, why), stop(session), public(session) (optional), spot(session, player) (optional: where a
--   goblin is put back afterwards) }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Port = require(script.Parent.Port)

local Minigames = {}
Minigames.Finished = Util.signal() -- (session, standings): a heat is over (Challenges listens)
-- (player, gameId, score or nil, place, humans, session) -> the run's breakdown (Main sets it: Progress.onPortGame).
Minigames.reward = function()
	return nil
end

local G = Config.PLAYGROUND
local modules = {} -- gameId -> game module
local sessions = {} -- id -> session
local playing = {} -- player -> session
local queues = {} -- gameId -> { players waiting for the next heat }
local waiting = {} -- gameId -> { private sessions (challenges) waiting for the venue }
local nextId = 0
local folder
local lastInput = setmetatable({}, { __mode = "k" }) -- player -> { times } (Config.PLAYGROUND.INPUT_RATE)

local function now()
	return workspace:GetServerTimeNow()
end

function Minigames.register(gameModule)
	modules[gameModule.id] = gameModule
end

function Minigames.module(gameId)
	return modules[gameId]
end

-- Publishing ------------------------------------------------------------------------------------------------------------
local function standingsOf(session)
	local def = session.def
	local list = {}
	for _, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry and not entry.gone then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local sa, sb = a.score, b.score
		if sa == nil or sb == nil then
			if sa ~= sb then
				return sa ~= nil
			end
			return a.joinedAt < b.joinedAt
		end
		if sa ~= sb then
			if def.kind == "time" then
				return sa < sb
			end
			return sa > sb
		end
		return a.joinedAt < b.joinedAt
	end)
	-- Places, with ties sharing one.
	local place, last = 0, nil
	for i, entry in ipairs(list) do
		if entry.score == nil then
			entry.place = nil
		else
			if last == nil or entry.score ~= last then
				place = i
				last = entry.score
			end
			entry.place = place
		end
	end
	return list
end

function Minigames.publish(session)
	if not session.value then
		return
	end
	local roster = {}
	for _, entry in ipairs(standingsOf(session)) do
		table.insert(roster, {
			u = entry.userId,
			n = entry.name,
			s = entry.score,
			d = entry.done or nil,
			p = entry.place,
			l = entry.left or nil,
			x = entry.show, -- a short line the game wants shown (laps, crabs, a checkpoint)
		})
	end
	local data = {
		id = session.id,
		game = session.game,
		state = session.state,
		lobbyEndsAt = session.lobbyEndsAt,
		goAt = session.goAt,
		endsAt = session.endsAt,
		resultsUntil = session.resultsUntil,
		challenge = session.challenge and session.challenge.id or nil,
		players = roster,
		extra = session.mod.public and session.mod.public(session) or nil,
	}
	local ok, text = pcall(HttpService.JSONEncode, HttpService, data)
	if ok and text ~= session.lastText then
		session.lastText = text
		session.value.Value = text
	end
end

-- A game's fast channel (positions of pets, crabs...). `data` is any plain table.
function Minigames.live(session, data)
	if not session.liveValue then
		local value = Instance.new("StringValue")
		value.Name = session.id .. ".live"
		value.Parent = folder
		session.liveValue = value
	end
	local ok, text = pcall(HttpService.JSONEncode, HttpService, data)
	if ok then
		session.liveValue.Value = text
	end
end

local function publishQueue(gameId)
	if folder then
		folder:SetAttribute(gameId .. "Queue", #(queues[gameId] or {}))
	end
end

-- Sessions ----------------------------------------------------------------------------------------------------------------
local function activeFor(gameId)
	local list = {}
	for _, session in pairs(sessions) do
		if session.game == gameId and session.state ~= "closed" and session.state ~= "waiting" then
			table.insert(list, session)
		end
	end
	return list
end

local function create(gameId, private)
	nextId += 1
	local session = {
		id = gameId .. "#" .. nextId,
		game = gameId,
		def = PortGames.BY_ID[gameId],
		mod = modules[gameId],
		state = "lobby",
		entries = {},
		order = {},
		data = {},
		private = private == true,
		createdAt = now(),
	}
	local value = Instance.new("StringValue")
	value.Name = session.id
	value.Parent = folder
	session.value = value
	sessions[session.id] = session
	return session
end

local function addPlayer(session, player)
	local entry = {
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		joinedAt = now(),
		data = {},
	}
	session.entries[player] = entry
	table.insert(session.order, player)
	playing[player] = session
	player:SetAttribute("PlayGame", session.game)
	player:SetAttribute("PlaySession", session.id)
	return entry
end

local function clearPlayer(player, session)
	if playing[player] == session then
		playing[player] = nil
		if player.Parent then
			player:SetAttribute("PlayGame", nil)
			player:SetAttribute("PlaySession", nil)
		end
	end
end

local function humans(session)
	local n = 0
	for _, entry in pairs(session.entries) do
		if not entry.gone then
			n += 1
		end
	end
	return n
end

local function present(session)
	local n = 0
	for _, entry in pairs(session.entries) do
		if not entry.gone and not entry.left then
			n += 1
		end
	end
	return n
end

-- Puts a goblin back somewhere sensible at the venue afterwards (the game may say where).
local function returnPlayer(session, player)
	if not player.Parent or player:GetAttribute("Zone") == "raid" then
		return
	end
	local spot = session.mod.spot and session.mod.spot(session, player)
	if spot then
		Port.arrive(player, spot)
	end
end

local function close(session)
	if session.state == "closed" then
		return
	end
	session.state = "closed"
	for player in pairs(session.entries) do
		clearPlayer(player, session)
	end
	sessions[session.id] = nil
	if session.value then
		session.value:Destroy()
		session.value = nil
	end
	if session.liveValue then
		session.liveValue:Destroy()
		session.liveValue = nil
	end
end

local startLobby

-- After a heat closes, the next one: a challenge waiting for the venue first, then the queue.
local function openNext(gameId)
	local mod = modules[gameId]
	if mod.concurrent then
		return
	end
	if #activeFor(gameId) > 0 then
		return
	end
	local private = waiting[gameId] and table.remove(waiting[gameId], 1)
	if private then
		startLobby(private)
		return
	end
	local queue = queues[gameId]
	if queue and #queue > 0 then
		local session = create(gameId, false)
		while #queue > 0 and #session.order < (mod.max or 8) do
			local player = table.remove(queue, 1)
			if player.Parent and playing[player] == nil and player:GetAttribute("Zone") ~= "raid" then
				addPlayer(session, player)
			end
		end
		publishQueue(gameId)
		if #session.order == 0 then
			close(session)
			return
		end
		startLobby(session)
	end
end

-- The heat is over: standings, rewards, results, then the venue opens again.
function Minigames.finish(session, why)
	if session.state == "results" or session.state == "closed" then
		return
	end
	session.state = "results"
	session.endedWhy = why
	pcall(session.mod.stop, session)
	local standings = standingsOf(session)
	local count = humans(session)
	local kind = session.def.kind
	for _, entry in ipairs(standings) do
		local player = entry.player
		if player.Parent and not entry.left then
			local counts = entry.score ~= nil and (kind == "time" or entry.score > 0)
			-- (The Derby's place counts the bot pets too: the game says.)
			if session.mod.placeOf then
				entry.place = session.mod.placeOf(session, entry) or entry.place
			end
			local ok, breakdown = pcall(
				Minigames.reward,
				player,
				session.game,
				counts and entry.score or nil,
				entry.place,
				count,
				session
			)
			if not ok then
				warn("[Minigames] reward: " .. tostring(breakdown))
				breakdown = nil
			end
			entry.breakdown = breakdown
			Net.send(player, "PlayResult", {
				game = session.game,
				session = session.id,
				score = entry.score,
				place = entry.place,
				players = count,
				counted = counts,
				breakdown = breakdown,
				challenge = session.challenge and session.challenge.id or nil,
				why = why,
			})
		end
	end
	session.resultsUntil = now() + G.RESULTS
	Minigames.publish(session)
	Minigames.Finished:Fire(session, standings)
	local token = session.id
	task.delay(G.RESULTS, function()
		local s = sessions[token]
		if not s then
			return
		end
		for _, player in ipairs(s.order) do
			local entry = s.entries[player]
			if entry and not entry.left and not entry.gone and playing[player] == s then
				returnPlayer(s, player)
			end
		end
		close(s)
		openNext(s.game)
	end)
end

local function begin(session)
	if session.state ~= "lobby" then
		return
	end
	if present(session) == 0 then
		close(session)
		openNext(session.game)
		return
	end
	session.state = "countdown"
	session.goAt = now() + G.COUNTDOWN
	local ok, err = pcall(session.mod.prepare, session)
	if not ok then
		warn("[Minigames] " .. session.game .. " prepare: " .. tostring(err))
		Minigames.finish(session, "error")
		return
	end
	Minigames.publish(session)
end

function startLobby(session)
	session.state = "lobby"
	local lobby = session.private and 0.5 or (session.mod.concurrent and 0.2 or G.LOBBY)
	session.lobbyEndsAt = now() + lobby
	Minigames.publish(session)
end

-- Joining and leaving ----------------------------------------------------------------------------------------------------
local function canPlay(player)
	if player:GetAttribute("Zone") == "raid" or player:GetAttribute("InRaid") then
		return false, "You're in a raid. The Port's games are here when you're back."
	end
	if player:GetAttribute("Spectating") then
		return false, "Stop watching the raid first."
	end
	local root = Util.aliveRoot(player)
	if not root or not Lobby.inPort(root.Position) then
		return false, nil
	end
	if playing[player] then
		return false, "You're already in a game (LEAVE on the screen to stop)."
	end
	return true
end

-- A goblin asks to play `gameId` (the venue's prompt, AGAIN on the results).
function Minigames.join(player, gameId)
	local mod = modules[gameId]
	if not mod then
		return false
	end
	local ok, why = canPlay(player)
	if not ok then
		if why then
			Net.toast(player, why)
		end
		return false
	end
	if mod.canJoin then
		local allowed, reason = mod.canJoin(player)
		if not allowed then
			if reason then
				Net.toast(player, reason)
			end
			return false
		end
	end
	if mod.concurrent then
		if #activeFor(gameId) >= (mod.limit or 8) then
			Net.toast(player, "Every place is taken just now: try again in a moment.")
			return false
		end
		local session = create(gameId, false)
		addPlayer(session, player)
		startLobby(session)
		return true
	end
	for _, session in ipairs(activeFor(gameId)) do
		if session.state == "lobby" and not session.private and #session.order < (mod.max or 8) then
			addPlayer(session, player)
			Minigames.publish(session)
			return true
		end
	end
	if #activeFor(gameId) > 0 or (waiting[gameId] and #waiting[gameId] > 0) then
		queues[gameId] = queues[gameId] or {}
		if not table.find(queues[gameId], player) then
			table.insert(queues[gameId], player)
		end
		publishQueue(gameId)
		Net.toast(player, string.format("A heat is on: you're next in line (%d waiting).", #queues[gameId]))
		return true
	end
	local session = create(gameId, false)
	addPlayer(session, player)
	startLobby(session)
	return true
end

-- A private heat for a challenge (server/Challenges.lua): these goblins only, as soon as the venue is free.
function Minigames.startPrivate(gameId, players, challenge)
	local mod = modules[gameId]
	if not mod then
		return nil
	end
	for _, player in ipairs(players) do
		local ok = canPlay(player)
		if not ok then
			return nil
		end
	end
	local session = create(gameId, true)
	session.challenge = challenge
	for _, player in ipairs(players) do
		addPlayer(session, player)
	end
	if mod.concurrent or #activeFor(gameId) <= 1 then
		startLobby(session)
	else
		session.state = "waiting"
		session.private = true
		waiting[gameId] = waiting[gameId] or {}
		table.insert(waiting[gameId], session)
		Minigames.publish(session)
		for _, player in ipairs(players) do
			Net.toast(player, "The venue is busy: your challenge starts right after this heat.")
		end
	end
	return session
end

-- A goblin stops playing (why: "leave", "gone", "raid", "zone", "reset", "spectate").
function Minigames.leave(player, why)
	local queued = false
	for gameId, queue in pairs(queues) do
		local index = table.find(queue, player)
		if index then
			table.remove(queue, index)
			publishQueue(gameId)
			queued = true
		end
	end
	local session = playing[player]
	if not session then
		return queued
	end
	local entry = session.entries[player]
	clearPlayer(player, session)
	if not entry then
		return true
	end
	if session.state == "lobby" or session.state == "waiting" then
		session.entries[player] = nil
		local index = table.find(session.order, player)
		if index then
			table.remove(session.order, index)
		end
		if session.state == "waiting" and session.challenge then
			-- A challenge waiting for the venue loses its point without both goblins.
			for gameId, list in pairs(waiting) do
				local i = table.find(list, session)
				if i then
					table.remove(list, i)
					local _ = gameId
				end
			end
			Minigames.Finished:Fire(session, {})
			close(session)
			return true
		end
		if #session.order == 0 then
			close(session)
			openNext(session.game)
		else
			Minigames.publish(session)
		end
		return true
	end
	entry.left = true
	entry.gone = why == "gone"
	pcall(session.mod.drop, session, player, why)
	if session.state == "running" or session.state == "countdown" then
		if present(session) == 0 then
			Minigames.finish(session, "empty")
		else
			Minigames.publish(session)
		end
	end
	if why == "leave" and player.Parent then
		returnPlayer(session, player)
	end
	return true
end

-- The raid is setting off with these goblins: their games end first (the raid always wins).
function Minigames.leaveAll(players, why)
	for _, player in ipairs(players) do
		Minigames.leave(player, why or "raid")
	end
end

function Minigames.sessionOf(player)
	return playing[player]
end

function Minigames.entryOf(player)
	local session = playing[player]
	return session and session.entries[player], session
end

-- Helpers for the games -------------------------------------------------------------------------------------------------------
-- Put a goblin at a spot (out of any seat or launcher first); `hold`: anchored there until Minigames.release (a start
-- line during the countdown).
function Minigames.place(player, cframe, hold)
	local _, root = Port.freeOf(player)
	if not root then
		return false
	end
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, 2)
		end)
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	player.Character:PivotTo(cframe)
	root.Anchored = hold == true
	return true
end

function Minigames.release(player)
	local root = Util.aliveRoot(player)
	if root then
		root.Anchored = false
	end
end

-- What the games report ------------------------------------------------------------------------------------------------------
-- A goblin finished, with a score (a time in seconds, or points). Ends the heat when everyone is done.
function Minigames.done(session, player, score, show)
	local entry = session.entries[player]
	if not entry or entry.done or session.state ~= "running" then
		return
	end
	entry.done = true
	entry.score = score
	entry.finishedAt = now()
	entry.show = show or entry.show
	Minigames.publish(session)
	local allDone = true
	for _, other in pairs(session.entries) do
		if not other.done and not other.left then
			allDone = false
		end
	end
	if allDone then
		Minigames.finish(session, "done")
	end
end

-- A running score for a points game (it ends by time: the game calls Minigames.finish, or the clock does).
function Minigames.points(session, player, add, show)
	local entry = session.entries[player]
	if not entry or session.state ~= "running" or entry.left then
		return
	end
	entry.score = (entry.score or 0) + add
	entry.show = show or entry.show
	session.dirty = true
end

-- Heartbeat --------------------------------------------------------------------------------------------------------------------
local nextSweep = 0
function Minigames.tick(dt)
	local t = now()
	-- (Snapshots: a heat ending opens the next one, which adds sessions and players while we look.)
	local list = {}
	for _, session in pairs(sessions) do
		table.insert(list, session)
	end
	for _, session in ipairs(list) do
		if session.state == "lobby" and t >= (session.lobbyEndsAt or 0) then
			begin(session)
		elseif session.state == "countdown" and t >= session.goAt then
			session.state = "running"
			session.startedAt = t
			session.endsAt = t + (session.mod.duration or 60)
			local ok, err = pcall(session.mod.go, session, t)
			if not ok then
				warn("[Minigames] " .. session.game .. " go: " .. tostring(err))
				Minigames.finish(session, "error")
			else
				Minigames.publish(session)
			end
		elseif session.state == "running" then
			local ok, err = pcall(session.mod.tick, session, dt, t)
			if not ok then
				warn("[Minigames] " .. session.game .. " tick: " .. tostring(err))
			end
			if session.state == "running" and t >= session.endsAt then
				Minigames.finish(session, "time")
			elseif session.dirty and session.state == "running" then
				session.dirty = false
				if t >= (session.nextPublish or 0) then
					session.nextPublish = t + 0.25
					Minigames.publish(session)
				else
					session.dirty = true
				end
			end
		end
	end
	-- A few times a second: anyone who has wandered off, or whose raid is starting, stops playing.
	if t < nextSweep then
		return
	end
	nextSweep = t + 0.3
	local who = {}
	for player, session in pairs(playing) do
		table.insert(who, { player, session })
	end
	for _, pair in ipairs(who) do
		local player, session = pair[1], pair[2]
		if not player.Parent then
			Minigames.leave(player, "gone")
		elseif player:GetAttribute("Zone") == "raid" then
			Minigames.leave(player, "raid")
		elseif player:GetAttribute("Spectating") then
			Minigames.leave(player, "spectate")
		elseif session.state == "lobby" then
			-- Waiting in a lobby means waiting at the venue.
			local venue = PortGames.VENUES[session.game]
			local root = Util.aliveRoot(player)
			if venue and root and (root.Position - venue.zone).Magnitude > venue.radius + 30 then
				Minigames.leave(player, "zone")
				Net.toast(player, "You walked away from the " .. session.def.name .. ".")
			end
		end
	end
end

-- Input from the client: "leave", "again" (play the same game again), or a game's own input.
function Minigames.request(player, action, a, b)
	if type(action) ~= "string" then
		return
	end
	local t = os.clock()
	local times = lastInput[player]
	if not times then
		times = {}
		lastInput[player] = times
	end
	for i = #times, 1, -1 do
		if t - times[i] > 1 then
			table.remove(times, i)
		end
	end
	if #times >= G.INPUT_RATE then
		return
	end
	table.insert(times, t)
	if action == "leave" then
		Minigames.leave(player, "leave")
		return
	elseif action == "again" then
		if type(a) == "string" and modules[a] and not playing[player] then
			Minigames.join(player, a)
		end
		return
	end
	local session = playing[player]
	if session and session.state == "running" and session.mod.input then
		local entry = session.entries[player]
		if entry and not entry.left then
			local ok, err = pcall(session.mod.input, session, player, action, a, b)
			if not ok then
				warn("[Minigames] " .. session.game .. " input: " .. tostring(err))
			end
		end
	end
end

-- Building ----------------------------------------------------------------------------------------------------------------------
function Minigames.build(kit)
	local old = ReplicatedStorage:FindFirstChild("LootGoblinsPlay")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "LootGoblinsPlay"
	folder.Parent = ReplicatedStorage
	for _, def in ipairs(PortGames.GAMES) do
		local mod = modules[def.id]
		if mod then
			local ok, err = pcall(mod.build, kit)
			if not ok then
				warn("[Minigames] " .. def.id .. " build: " .. tostring(err))
			end
			-- The venue's prompt: E to play.
			local venue = PortGames.VENUES[def.id]
			if venue and not mod.ownPrompt then
				local pad = kit.deco(
					"Join_" .. def.id,
					Vector3.new(4, 4, 4),
					CFrame.new(venue.join),
					Color3.new(1, 1, 1),
					Enum.Material.SmoothPlastic,
					{ transparency = 1, parent = kit.core }
				)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "PlayPrompt"
				prompt.ObjectText = def.name
				prompt.ActionText = "Play"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt:SetAttribute("PlayGame", def.id)
				prompt.Parent = pad
				prompt.Triggered:Connect(function(player)
					Minigames.join(player, def.id)
				end)
			end
			publishQueue(def.id)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		Minigames.leave(player, "gone")
	end)
end

-- For tests and the HUD: how many sessions of a game are running.
function Minigames.activeCount(gameId)
	return #activeFor(gameId)
end

return Minigames

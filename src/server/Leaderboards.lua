-- THE LEADERBOARDS (V13.3, made the Port's centrepiece in V13.4). The RAID boards: the weekly BIGGEST HAUL (one raid)
-- and PIRATE CHAMPIONSHIP (a goblin's best Config.SEASONS.WEEK_RAIDS raids of the week added up), and the monthly
-- PIRATE LEGENDS (the best CHAMPION_RAIDS of the month). The Port's records: the fastest Regatta and the best Cannon Golf
-- round (weekly) and the fastest Gauntlet (monthly). All stand in the HALL OF LEGENDS behind the podium, raid boards in
-- the middle. The rules and rewards are shared/Seasons.lua's; this module is the DataStores and the boards.
--
--   PLACES     a goblin's place is their saved best set among the board's last read (Seasons.rankAmong), so a new best
--              shows its place at once ("BoardBest" carries it, and the place before), not two minutes later.
--
--   SCORES     only the server's own measurements (a raid's banked gold from Raid.finish through Progress, a lap or a
--              round timed by the server's games). Each goblin's best per board and period lives in their profile
--              first (Seasons.submit), then goes to the board's OrderedDataStore ("LG_Board_<board>", scope = the period
--              key), at most once per Config.SEASONS.WRITE_GAP per board, keeping only the better value. A goblin's
--              current bests are written again whenever their profile opens, so a crash never costs a place for long.
--   READING    each board's top HALL is read every REFRESH seconds; the top SHOW go on the boards (workspace
--              attribute Board_<id>), and each goblin here learns their rank if they are in the top HALL.
--   THE HALL   once a period has been over for SETTLE seconds, the first server to notice writes its final standings
--              (the top HALL) to "LG_Hall_v1" with one UpdateAsync that never overwrites a final record. Every server
--              then reads the same standings: the durable record of who won, and the placements rewards are paid by.
--   REWARDS    paid into each goblin's own profile, once (Seasons.pay marks the period in the same profile change),
--              the next time they are in a server after the Hall is written: being offline at a reset loses nothing.
--              If the Hall is still missing after GIVE_UP_DAYS, the tier reward is paid without a placement.
-- In Studio without DataStore access, in-memory stand-ins are used (everything resets when Play stops).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Economy = require(script.Parent.Economy)
local Analytics = require(script.Parent.Analytics)

local Leaderboards = {}

local S = Config.SEASONS
local rgb = Color3.fromRGB
local mode = "none" -- "datastore" | "studio" | "none"
local ordered = {} -- "board@key" -> store
local hallStore
local tops = {} -- boardId -> { key, list = { { u, s } } (stored values, best first), readAt }
local halls = {} -- "board@key" -> { final = true, top = { { u, s } } }
local pending = {} -- player -> { ["board@key"] = { board, key, value, due } }
local written = setmetatable({}, { __mode = "k" }) -- player -> { ["board@key"] = os.clock() of the last write }
local names = {} -- userId -> display name

local function unix()
	return os.time()
end

-- In-memory stand-ins (Studio without DataStore access) -------------------------------------------------------------------
local MockOrdered = {}
MockOrdered.__index = MockOrdered
local function mockOrdered()
	return setmetatable({ data = {} }, MockOrdered)
end
function MockOrdered:UpdateAsync(key, fn)
	local value = fn(self.data[key])
	if value ~= nil then
		self.data[key] = value
	end
	return value
end
function MockOrdered:GetAsync(key)
	return self.data[key]
end
function MockOrdered:GetSortedAsync(ascending, pageSize)
	local list = {}
	for key, value in pairs(self.data) do
		table.insert(list, { key = key, value = value })
	end
	table.sort(list, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(pageSize, #list) do
		page[i] = list[i]
	end
	return {
		GetCurrentPage = function()
			return page
		end,
	}
end
local mockHall = { data = {} }
function mockHall:UpdateAsync(key, fn)
	local value = fn(self.data[key] and HttpService:JSONDecode(HttpService:JSONEncode(self.data[key])) or nil)
	if value ~= nil then
		self.data[key] = value
	end
	return value
end
function mockHall:GetAsync(key)
	return self.data[key]
end

-- Stores ----------------------------------------------------------------------------------------------------------------
local function storeFor(board, key)
	local name = board.id .. "@" .. key
	local store = ordered[name]
	if not store then
		if mode == "datastore" then
			local ok, result = pcall(function()
				return DataStoreService:GetOrderedDataStore("LG_Board_" .. board.id, key)
			end)
			store = ok and result or nil
		elseif mode == "studio" then
			store = mockOrdered()
		end
		ordered[name] = store
	end
	return store
end

-- Names for the boards (UserService, cached; a goblin here is known by their own player).
local function nameOf(userId)
	local here = Players:GetPlayerByUserId(userId)
	if here then
		names[userId] = here.DisplayName
	end
	return names[userId] or ("Goblin " .. tostring(userId))
end

local function learnNames(ids)
	local missing = {}
	for _, id in ipairs(ids) do
		if not names[id] and not Players:GetPlayerByUserId(id) and id > 0 then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in ipairs(infos) do
			if info.Id and info.DisplayName then
				names[info.Id] = info.DisplayName
			end
		end
	end
end

-- Writing a goblin's best ---------------------------------------------------------------------------------------------------
local function queueWrite(player, board, key, value)
	pending[player] = pending[player] or {}
	local slot = board.id .. "@" .. key
	local old = pending[player][slot]
	local last = written[player] and written[player][slot] or -math.huge
	local due = math.max(os.clock() + 1, last + S.WRITE_GAP)
	pending[player][slot] = { board = board, key = key, value = value, due = old and math.min(old.due, due) or due }
end

local function write(userId, item)
	local store = storeFor(item.board, item.key)
	if not store then
		return false
	end
	local ok = pcall(function()
		store:UpdateAsync(tostring(userId), function(old)
			if type(old) == "number" and not Seasons.better(item.board, item.value, old) then
				return nil -- the board already has this or better
			end
			return item.value
		end)
	end)
	return ok
end

local function flush(player, force)
	local list = pending[player]
	if not list then
		return
	end
	local t = os.clock()
	for slot, item in pairs(list) do
		if force or t >= item.due then
			list[slot] = nil
			written[player] = written[player] or {}
			written[player][slot] = t
			task.spawn(function()
				if not write(player.UserId, item) and player.Parent then
					-- Try again later (the profile has it either way).
					item.due = os.clock() + S.WRITE_GAP * 2
					pending[player] = pending[player] or {}
					pending[player][slot] = pending[player][slot] or item
				end
			end)
		end
	end
end

-- Where a goblin stands on a board this period: their saved best placed among the board's last read (so a new best
-- shows its place at once, before the next read). nil without a score or past the top HALL.
local function rankFor(player, profile, board)
	local top = tops[board.id]
	local best = Seasons.best(profile, board.id, unix())
	if best == nil or not top or top.key ~= Seasons.boardKey(board, unix()) then
		return nil
	end
	return Seasons.rankAmong(board, top.list, player.UserId, best)
end

-- A new score for a board, measured by the server. Saved in the profile at once, written to the board soon.
function Leaderboards.submit(player, boardId, score)
	local s = Progress.session(player)
	local board = Seasons.BOARD_BY_ID[boardId]
	if not s or not board or type(score) ~= "number" then
		return false
	end
	local before = rankFor(player, s.profile, board)
	local improved, key, value = Seasons.submit(s.profile, boardId, score, unix())
	if improved then
		queueWrite(player, board, key, value)
		Progress.markChanged(player, false)
		local rank = rankFor(player, s.profile, board)
		Net.send(player, "BoardBest", {
			board = boardId,
			score = score,
			key = key,
			rank = rank,
			was = before,
		})
	end
	return improved
end

-- V13.4: climbing into a raid board's top three is news for the whole server, and the Hall cheers. Once per raid, for
-- the best of the places that raid moved (a raid can touch all three raid boards: one line, not three).
local function announce(player, moved)
	local best
	for _, move in ipairs(moved) do
		if move.to <= 3 and (move.from == nil or move.to < move.from) and (not best or move.to < best.to) then
			best = move
		end
	end
	local board = best and Seasons.BOARD_BY_ID[best.board]
	if not board then
		return
	end
	Net.feed(
		string.format("%s %s is #%d on the %s!", board.icon, player.DisplayName, best.to, board.name),
		Palette.GOLD
	)
	if Leaderboards.hallSpot then
		local spot = Leaderboards.hallSpot
		Net.broadcastNear(spot, 600, "PlayFx", { kind = "hallcheer", position = spot })
	end
end

-- Reading the boards ----------------------------------------------------------------------------------------------------------
local function readTop(board, key, count)
	local store = storeFor(board, key)
	if not store then
		return nil
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(board.order == "asc", count)
	end)
	if not ok or not pages then
		return nil
	end
	local ok2, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 or type(page) ~= "table" then
		return nil
	end
	local list = {}
	for _, row in ipairs(page) do
		local id = tonumber(row.key)
		if id and type(row.value) == "number" then
			table.insert(list, { u = id, s = row.value })
		end
	end
	return list
end

local function hallKey(board, key)
	return board.id .. "@" .. key
end

-- The final standings of a finished period: from the cache, the Hall, or (once SETTLE has passed) written now.
local function getHall(board, key, finished)
	local name = hallKey(board, key)
	local cached = halls[name]
	if cached and cached.final then
		return cached
	end
	if not hallStore then
		return nil
	end
	local ok, stored = pcall(function()
		return hallStore:GetAsync(name)
	end)
	if ok and type(stored) == "table" and stored.final then
		halls[name] = stored
		return stored
	end
	if not ok or unix() < finished + S.SETTLE then
		return nil
	end
	-- Ours to write (unless another server is first: UpdateAsync never replaces a final record).
	local list = readTop(board, key, S.HALL)
	if not list then
		return nil
	end
	local wrote = pcall(function()
		hallStore:UpdateAsync(name, function(old)
			if type(old) == "table" and old.final then
				return nil
			end
			return { final = true, at = unix(), top = list }
		end)
	end)
	if not wrote then
		return nil
	end
	local ok2, again = pcall(function()
		return hallStore:GetAsync(name)
	end)
	if ok2 and type(again) == "table" and again.final then
		halls[name] = again
		return again
	end
	return nil
end

local function rankIn(hall, userId)
	for i, row in ipairs(hall.top or {}) do
		if row.u == userId then
			return i
		end
	end
	return nil
end

-- Paying a goblin for finished periods (when the Hall exists, or after GIVE_UP_DAYS without one).
local paying = setmetatable({}, { __mode = "k" })
local function payPending(player)
	local s = Progress.session(player)
	if not s or not Progress.isReady(s) or paying[player] then
		return
	end
	paying[player] = true
	local list = Seasons.pending(s.profile, unix())
	for _, entry in ipairs(list) do
		local board = Seasons.BOARD_BY_ID[entry.board]
		local hall = getHall(board, entry.key, entry.ended)
		local rank
		local ready = false
		if hall then
			rank = rankIn(hall, player.UserId)
			ready = true
		elseif unix() - entry.ended > S.GIVE_UP_DAYS * 86400 then
			ready = true -- the standings never arrived: the tier at least
		end
		if ready and player.Parent and Progress.session(player) == s then
			local reward = Seasons.pay(s.profile, entry, rank, unix())
			if reward then
				local granted = {}
				if #reward.items > 0 then
					granted = Economy.grant(s.profile, reward.items, "season", unix(), Config.PROGRESS.HISTORY)
				end
				if reward.shinies > 0 then
					Analytics.shinies(
						player,
						false,
						reward.shinies,
						s.profile.shinies,
						"Gameplay",
						"season:" .. entry.board
					)
				end
				local itemNames = {}
				for _, id in ipairs(granted) do
					local item = Catalog.get(id)
					table.insert(itemNames, item and item.name or id)
				end
				Net.send(player, "SeasonReward", {
					board = entry.board,
					name = board.name,
					key = entry.key,
					score = entry.score,
					tier = reward.tier,
					rank = rank,
					shinies = reward.shinies,
					items = itemNames,
				})
				Progress.markChanged(player, true)
			end
		end
	end
	Seasons.trim(s.profile, unix())
	Progress.checkAchievements(player)
	paying[player] = nil
end

-- What a goblin sees of their own season (the Quest Board's SEASON page, the next-up card): bests, ranks, trophies.
local function publish(s)
	local player = s.player
	if not player.Parent then
		return
	end
	local view = { best = {}, rank = {}, trophies = #s.profile.season.trophies }
	for _, board in ipairs(Seasons.BOARDS) do
		view.best[board.id] = Seasons.best(s.profile, board.id, unix())
		view.rank[board.id] = rankFor(player, s.profile, board)
	end
	local ok, text = pcall(HttpService.JSONEncode, HttpService, view)
	if ok and text ~= s.seasonSent then
		s.seasonSent = text
		player:SetAttribute("Season", text)
	end
end

function Leaderboards.rankOf(player, boardId)
	local board = Seasons.BOARD_BY_ID[boardId]
	local s = Progress.session(player)
	return board and s and rankFor(player, s.profile, board) or nil
end

-- What the last raid did to this goblin's places on the raid boards: { { board, from, to } } (the next-up card).
local moves = setmetatable({}, { __mode = "k" })
function Leaderboards.lastMoves(player)
	return moves[player] or {}
end

-- Refreshing every board: this period's top, last period's champions, the Hall when it is due.
local function refresh()
	for _, board in ipairs(Seasons.BOARDS) do
		local key, index = Seasons.boardKey(board, unix())
		local list = readTop(board, key, S.HALL)
		if list then
			tops[board.id] = { key = key, list = list, readAt = unix() }
		end
		local previous = Seasons.key(board.period, index - 1)
		local _, prevEnd = Seasons.bounds(board.period, index - 1)
		local hall = getHall(board, previous, prevEnd)
		local shown = {}
		local ids = {}
		for i, row in ipairs((tops[board.id] and tops[board.id].list) or {}) do
			if i <= S.SHOW then
				table.insert(ids, row.u)
			end
		end
		local champions = {}
		if hall then
			for i = 1, math.min(3, #(hall.top or {})) do
				table.insert(ids, hall.top[i].u)
			end
		end
		learnNames(ids)
		for i, row in ipairs((tops[board.id] and tops[board.id].list) or {}) do
			if i <= S.SHOW then
				table.insert(shown, { u = row.u, n = nameOf(row.u), s = Seasons.decode(board, row.s) })
			end
		end
		if hall then
			for i = 1, math.min(3, #(hall.top or {})) do
				local row = hall.top[i]
				table.insert(champions, { u = row.u, n = nameOf(row.u), s = Seasons.decode(board, row.s) })
			end
		end
		local _, ends = Seasons.bounds(board.period, index)
		local ok, text = pcall(HttpService.JSONEncode, HttpService, {
			key = key,
			ends = ends,
			top = shown,
			last = hall and { key = previous, top = champions } or nil,
		})
		if ok then
			workspace:SetAttribute("Board_" .. board.id, text)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Progress.session(player)
		if s then
			publish(s)
		end
	end
end

-- The Hall of Legends (V13.4; V13.3's Hall of Records): behind the podium, facing the plaza. The three RAID boards stand
-- in a row on a stone stage, big and gilded, under a great trophy; PAST CHAMPIONS and the Port games' records stand
-- beside them. Every client writes the boards itself (client/PortBoard.lua).
--
-- WHERE: PortGames.HALL, in the podium's frame: a 77 by 10 stage, which fits between the Shipyard's quay and the
-- Wardrobe (PortGamesSpec checks its corners against both; a stage further left stands on the quay).
local HALL = PortGames.HALL
local RAID_X = { -30, -15, 0 } -- the raid boards' places on the stage, then PAST CHAMPIONS and PORT RECORDS
local PAST_X, RECORDS_X = 16, 31

local function build(kit)
	local base = kit.at(-56, 6, 52) * CFrame.Angles(0, math.rad(-45), 0)
	local hall = base * CFrame.new(HALL.x, 0, HALL.z)
	local GOLD, PURPLE, NIGHT = Palette.GOLD, rgb(110, 44, 150), rgb(36, 26, 22)
	local METAL, SLATE = Enum.Material.Metal, Enum.Material.Slate
	-- The stage the boards stand on.
	kit.floor(
		"HallStage",
		Vector3.new(HALL.width, 1.4, HALL.depth),
		hall * CFrame.new(0, 0.7, 0),
		Palette.STONE_DARK,
		SLATE
	)
	kit.deco(
		"HallStageTrim",
		Vector3.new(HALL.width + 0.4, 0.4, HALL.depth + 0.4),
		hall * CFrame.new(0, 1.25, 0),
		GOLD,
		METAL
	)
	local raid, games = {}, {}
	for _, board in ipairs(Seasons.BOARDS) do
		table.insert(board.raid and raid or games, board)
	end
	local function pillars(cf, w, h, trim)
		for _, side in ipairs({ -1, 1 }) do
			local x = side * (w / 2 + 0.7)
			kit.part("HallPillar", Vector3.new(1.4, h + 4, 1.4), cf * CFrame.new(x, (h + 4) / 2, 0.4), trim, METAL)
			kit.deco("PillarCap", Vector3.new(2.2, 1, 2.2), cf * CFrame.new(x, h + 4.4, 0.4), trim, METAL)
		end
	end
	local function panel(id, cf, size)
		local part = kit.board(id, size, cf, "", GOLD, NIGHT, kit.core)
		part.Name = id
		return part
	end
	local function title(cf, width, text, color)
		kit.board("HallTitle", Vector3.new(width, 2.4, 0.4), cf, text, color, PURPLE, kit.core)
	end
	-- The raid boards: weekly blue titles, monthly gold.
	for i, board in ipairs(raid) do
		local cf = hall * CFrame.new(RAID_X[i], 1.4, 0)
		pillars(cf, 12, 18, GOLD)
		panel("Board_" .. board.id, cf * CFrame.new(0, 11, 0), Vector3.new(12, 18, 0.5)):SetAttribute("Board", board.id)
		local color = board.period == "week" and rgb(150, 230, 255) or rgb(255, 214, 90)
		title(cf * CFrame.new(0, 21.6, 0), 13, board.icon .. " " .. board.name, color)
	end
	-- PAST CHAMPIONS, then the PORT RECORDS (three small boards, one above another).
	local past = hall * CFrame.new(PAST_X, 1.4, 0)
	pillars(past, 10, 16, Palette.WOOD_DARK)
	panel("PastChampions", past * CFrame.new(0, 10, 0), Vector3.new(10, 16, 0.5))
	title(past * CFrame.new(0, 19.4, 0), 11, "PAST CHAMPIONS", GOLD)
	local records = hall * CFrame.new(RECORDS_X, 1.4, 0)
	pillars(records, 10, 16, Palette.WOOD_DARK)
	for i, board in ipairs(games) do
		local part = panel("Board_" .. board.id, records * CFrame.new(0, 17.4 - i * 5.3, 0), Vector3.new(10, 5, 0.5))
		part:SetAttribute("Board", board.id)
	end
	title(records * CFrame.new(0, 19.4, 0), 11, "PORT RECORDS", rgb(150, 230, 255))
	-- The great sign, and over it a trophy the whole plaza can see, both over the raid boards.
	local middle = hall * CFrame.new(RAID_X[2], 0, 0)
	kit.board(
		"HallSign",
		Vector3.new(30, 4, 0.6),
		middle * CFrame.new(0, 28, 0.4),
		"HALL OF LEGENDS",
		GOLD,
		PURPLE,
		kit.core
	)
	local cup = middle * CFrame.new(0, 31, 0.4)
	Leaderboards.hallSpot = (cup * CFrame.new(0, 8, 0)).Position
	kit.deco("TrophyBase", Vector3.new(5, 1.4, 5), cup * CFrame.new(0, 0.7, 0), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.deco("TrophyStem", Vector3.new(1.2, 3, 1.2), cup * CFrame.new(0, 2.9, 0), GOLD, METAL)
	local bowl =
		kit.deco("TrophyCup", Vector3.new(5.4, 4.4, 5.4), cup * CFrame.new(0, 6.2, 0), GOLD, METAL, { egg = true })
	for _, side in ipairs({ -1, 1 }) do
		local handle = cup * CFrame.new(side * 3.3, 6.6, 0) * CFrame.Angles(0, 0, math.rad(side * -18))
		kit.deco("TrophyHandle", Vector3.new(0.7, 3, 1.6), handle, GOLD, METAL)
	end
	kit.light(bowl, rgb(255, 220, 140), 40, 1.2)
	-- Two braziers in front of the stage's ends: warm light on the boards at night.
	for _, side in ipairs({ -1, 1 }) do
		local at = hall * CFrame.new(side * 37, 0, -7)
		kit.part("Brazier", Vector3.new(2.6, 5, 2.6), at * CFrame.new(0, 2.5, 0), Palette.STONE_DARK, SLATE)
		local coals = kit.deco(
			"BrazierFire",
			Vector3.new(2.4, 0.8, 2.4),
			at * CFrame.new(0, 5.2, 0),
			rgb(255, 140, 40),
			Enum.Material.Neon
		)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 5, 6
		fire.Parent = coals
		kit.light(coals, rgb(255, 170, 90), 36, 1.4)
	end
end

function Leaderboards.init(kit)
	local built, err = pcall(build, kit)
	if not built then
		warn("[Leaderboards] hall: " .. tostring(err))
	end
	-- Where scores go.
	local ok, probe = pcall(function()
		return DataStoreService:GetOrderedDataStore("LG_Board_probe")
	end)
	if ok and probe and RunService:IsStudio() then
		ok = pcall(function()
			probe:GetAsync("access-check")
		end)
	end
	if ok and probe then
		mode = "datastore"
		local hallOk, store = pcall(function()
			return DataStoreService:GetDataStore("LG_Hall_v1")
		end)
		hallStore = hallOk and store or nil
	elseif RunService:IsStudio() then
		mode = "studio"
		hallStore = mockHall
	end
	table.insert(Progress.publishers, publish)
	-- Scores from raids and from the Port's games.
	Progress.RaidRewarded:Connect(function(player, s, result)
		moves[player] = nil
		if (result.gold or 0) > 0 then
			local before = {}
			for _, board in ipairs(Seasons.BOARDS) do
				if board.raid then
					before[board.id] = rankFor(player, s.profile, board)
				end
			end
			Leaderboards.submit(player, "haul", result.gold)
			local month, week = Seasons.addRaid(s.profile, result.gold, unix())
			if month then
				Leaderboards.submit(player, "champion", month)
			end
			if week then
				Leaderboards.submit(player, "crown", week)
			end
			local list = {}
			for _, board in ipairs(Seasons.BOARDS) do
				local rank = board.raid and rankFor(player, s.profile, board)
				if rank then
					table.insert(list, { board = board.id, from = before[board.id], to = rank })
				end
			end
			moves[player] = list
			announce(player, list)
		end
	end)
	Progress.GamePlayed:Connect(function(player, _s, gameId, score)
		local def = PortGames.BY_ID[gameId]
		if def and def.board and score ~= nil then
			Leaderboards.submit(player, def.board, score)
		end
	end)
	-- A goblin arriving: their bests go to the boards again (healing a write a crash lost), and old periods are paid.
	Progress.Opened:Connect(function(player)
		local s = Progress.session(player)
		if not s then
			return
		end
		for name, value in pairs(s.profile.season.best) do
			local boardId, key = string.match(name, "^([%w_]+)@(.+)$")
			local board = boardId and Seasons.BOARD_BY_ID[boardId]
			if board and key == Seasons.boardKey(board, unix()) then
				queueWrite(player, board, key, value)
			end
		end
		task.spawn(payPending, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		flush(player, true)
		pending[player] = nil
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			flush(player, true)
		end
		task.wait(2)
	end)
	task.spawn(function()
		local nextRefresh, nextPay = 0, os.clock() + 60
		while true do
			task.wait(1)
			for player in pairs(pending) do
				if player.Parent then
					flush(player, false)
				else
					pending[player] = nil
				end
			end
			if os.clock() >= nextRefresh then
				nextRefresh = os.clock() + S.REFRESH
				local okRefresh, refreshErr = pcall(refresh)
				if not okRefresh then
					warn("[Leaderboards] refresh: " .. tostring(refreshErr))
				end
			end
			if os.clock() >= nextPay then
				nextPay = os.clock() + 300
				for _, player in ipairs(Players:GetPlayers()) do
					task.spawn(payPending, player)
				end
			end
		end
	end)
end

-- For the Studio boot check: which store is in use.
function Leaderboards.mode()
	return mode
end

return Leaderboards

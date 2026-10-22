-- CHALLENGES (V13.3): ask another goblin in the Port to a game, one on one: the Regatta, the Gauntlet, Cannon Golf,
-- the Derby, the Toss, the Gallery or Crab Chaos. No matchmaking and no second server: the two of them get a private
-- heat at the venue as soon as it is free (server/Minigames.lua: Minigames.startPrivate).
--
--   ASKING     ChallengeRequest("ask", userId, game) from the Port screen's ⚔ CHALLENGE picker. Both must be in the
--              Port, not raiding, not watching, not already playing. One invitation out at a time per goblin.
--   ANSWERING  the invited goblin sees ACCEPT / NO THANKS for Config.CHALLENGES.INVITE_TIME seconds
--              ("answer", inviteId, yes). The asker can take it back ("cancel"). Silence is a no.
--   RESULT     the better score wins (a time game needs a finish; equal scores are a TIE). A goblin who leaves or
--              disconnects forfeits: the other is told they won, but a forfeit pays nothing (so nobody farms an
--              opponent who walks off). A win pays WIN Shinies and a tie TIE, at most DAILY_PAID paid a day and
--              PER_OPPONENT against the same goblin (the counters are in the profile). Wins count toward The
--              Challenger trophy; playing counts toward the challenge quest.
--   REMATCH    both press REMATCH within REMATCH seconds: the same game again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Analytics = require(script.Parent.Analytics)
local Minigames = require(script.Parent.Minigames)

local Challenges = {}

local CH = Config.CHALLENGES
local invites = {} -- id -> invite
local outgoing = {} -- player -> invite
local records = {} -- challenge id -> { id, game, a, b, rematch = { [player] = true }, until }
local lastAsk = setmetatable({}, { __mode = "k" })

local function now()
	return workspace:GetServerTimeNow()
end

local function free(player)
	if not player or not player.Parent then
		return false, "gone"
	end
	if player:GetAttribute("Zone") == "raid" or player:GetAttribute("InRaid") then
		return false, "raid"
	end
	if player:GetAttribute("Spectating") then
		return false, "watching"
	end
	if Minigames.sessionOf(player) then
		return false, "playing"
	end
	local root = Util.aliveRoot(player)
	if not root or not Lobby.inPort(root.Position) then
		return false, "away"
	end
	return true
end

local WHY = {
	raid = "%s is out on a raid.",
	watching = "%s is watching the raid.",
	playing = "%s is already playing a game.",
	away = "%s isn't in the Port right now.",
	gone = "%s has left.",
}

local function close(invite, why)
	if invites[invite.id] ~= invite then
		return
	end
	invites[invite.id] = nil
	if outgoing[invite.from] == invite then
		outgoing[invite.from] = nil
	end
	if invite.to.Parent then
		Net.send(invite.to, "ChallengeClosed", { id = invite.id, why = why })
	end
	if invite.from.Parent then
		Net.send(invite.from, "ChallengeClosed", { id = invite.id, why = why, outgoing = true })
	end
end

function Challenges.ask(player, userId, gameId)
	local t = os.clock()
	if t - (lastAsk[player] or 0) < CH.GAP then
		Net.toast(player, "Give them a moment to answer first.")
		return
	end
	local def = PortGames.BY_ID[gameId]
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	if not def or not target or target == player then
		return
	end
	local ok, why = free(player)
	if not ok then
		Net.toast(
			player,
			why == "playing" and "Finish (or LEAVE) your game first." or "Challenges are for goblins in the Port."
		)
		return
	end
	local okTarget, whyTarget = free(target)
	if not okTarget then
		Net.toast(player, string.format(WHY[whyTarget] or "%s can't play right now.", target.DisplayName))
		return
	end
	lastAsk[player] = t
	if outgoing[player] then
		close(outgoing[player], "replaced")
	end
	local invite = {
		id = HttpService:GenerateGUID(false),
		from = player,
		to = target,
		game = gameId,
		expiresAt = now() + CH.INVITE_TIME,
	}
	invites[invite.id] = invite
	outgoing[player] = invite
	Net.send(target, "ChallengeInvite", {
		id = invite.id,
		from = player.DisplayName,
		fromId = player.UserId,
		game = gameId,
		expiresAt = invite.expiresAt,
	})
	Net.send(player, "ChallengeSent", {
		id = invite.id,
		to = target.DisplayName,
		game = gameId,
		expiresAt = invite.expiresAt,
	})
end

local function start(gameId, a, b, recordId)
	local record = recordId and records[recordId]
		or {
			id = HttpService:GenerateGUID(false),
			game = gameId,
			a = a,
			b = b,
		}
	records[record.id] = record
	record.rematch = {}
	record.session = Minigames.startPrivate(gameId, { a, b }, record)
	if not record.session then
		for _, p in ipairs({ a, b }) do
			if p.Parent then
				Net.toast(p, "The challenge couldn't start: is everyone in the Port and free?")
			end
		end
		records[record.id] = nil
		return nil
	end
	for _, p in ipairs({ a, b }) do
		Net.send(p, "ChallengeStart", {
			id = record.id,
			game = gameId,
			opponent = (p == a and b or a).DisplayName,
		})
	end
	return record
end

function Challenges.answer(player, inviteId, yes)
	local invite = type(inviteId) == "string" and invites[inviteId] or nil
	if not invite or invite.to ~= player then
		return
	end
	if not yes then
		close(invite, "declined")
		Net.toast(invite.from, invite.to.DisplayName .. " said no thanks this time.")
		return
	end
	local okA, whyA = free(invite.from)
	local okB, whyB = free(player)
	if not okA or not okB then
		close(invite, "unavailable")
		local who = not okA and invite.from or player
		Net.toast(player, string.format(WHY[not okA and whyA or whyB] or "%s can't play right now.", who.DisplayName))
		return
	end
	close(invite, "accepted")
	start(invite.game, invite.from, player)
end

function Challenges.cancel(player)
	local invite = outgoing[player]
	if invite then
		close(invite, "cancelled")
		if invite.to.Parent then
			Net.toast(invite.to, invite.from.DisplayName .. " took the challenge back.")
		end
	end
end

-- Both pressed REMATCH: the same game, as soon as both are out of the last heat.
function Challenges.rematch(player, recordId)
	local record = type(recordId) == "string" and records[recordId] or nil
	if not record or (record.a ~= player and record.b ~= player) then
		return
	end
	if now() > (record.rematchUntil or 0) then
		Net.toast(player, "Too late for a rematch: challenge them again!")
		return
	end
	record.rematch = record.rematch or {}
	record.rematch[player] = true
	local other = record.a == player and record.b or record.a
	if not record.rematch[other] then
		if other.Parent then
			Net.send(other, "ChallengeRematch", { id = record.id, from = player.DisplayName })
		end
		return
	end
	record.rematchUntil = 0
	task.spawn(function()
		for _ = 1, 40 do
			if not record.a.Parent or not record.b.Parent then
				return
			end
			if not Minigames.sessionOf(record.a) and not Minigames.sessionOf(record.b) then
				break
			end
			task.wait(0.25)
		end
		start(record.game, record.a, record.b, record.id)
	end)
end

-- The heat is over: who won, what it pays.
local function pay(winner, loser, amount, s)
	local c = s.profile.challenges
	local day = Seasons.period("day", os.time())
	if c.day ~= day then
		c.day, c.paid, c.pairs = day, 0, {}
	end
	local key = tostring(loser.UserId)
	if c.paid >= CH.DAILY_PAID or (c.pairs[key] or 0) >= CH.PER_OPPONENT then
		return 0
	end
	c.paid += 1
	c.pairs[key] = (c.pairs[key] or 0) + 1
	s.profile.shinies += amount
	Analytics.shinies(winner, false, amount, s.profile.shinies, "Gameplay", "challenge")
	Progress.markChanged(winner, true)
	return amount
end

Minigames.Finished:Connect(function(session, standings)
	local record = session.challenge
	if not record then
		return
	end
	if session.state == "waiting" or session.state == "lobby" then
		-- It never started (one of them left while it waited for the venue): nobody won anything.
		for _, p in ipairs({ record.a, record.b }) do
			if p.Parent then
				Net.toast(p, "The challenge was called off.")
			end
		end
		return
	end
	record.rematchUntil = now() + CH.REMATCH
	local a, b = record.a, record.b
	local ea, eb = session.entries[a], session.entries[b]
	local kind = session.def.kind
	local function score(entry)
		if not entry or entry.left then
			return nil
		end
		if entry.score == nil then
			return nil
		end
		if kind ~= "time" and entry.score <= 0 then
			return nil
		end
		return entry.score
	end
	local sa, sb = score(ea), score(eb)
	local leftA, leftB = ea == nil or ea.left, eb == nil or eb.left
	local outcome -- "a" | "b" | "tie" | "forfeitA" (a left) | "forfeitB" | "void"
	if leftA and leftB then
		outcome = "void"
	elseif leftA then
		outcome = "forfeitA"
	elseif leftB then
		outcome = "forfeitB"
	elseif sa ~= nil and (sb == nil or PortGames.better(session.game, sa, sb)) then
		outcome = "a"
	elseif sb ~= nil and (sa == nil or PortGames.better(session.game, sb, sa)) then
		outcome = "b"
	else
		outcome = "tie"
	end
	local function tell(player, result, shinies, other)
		if not player.Parent then
			return
		end
		Net.send(player, "ChallengeResult", {
			id = record.id,
			game = session.game,
			result = result,
			opponent = other.DisplayName,
			shinies = shinies,
			mine = player == a and sa or sb,
			theirs = player == a and sb or sa,
			rematchUntil = record.rematchUntil,
		})
	end
	if outcome == "void" then
		return
	end
	for _, p in ipairs({ a, b }) do
		if p.Parent and not (session.entries[p] and session.entries[p].left) then
			Progress.record(p, "challenge")
			Analytics.event(p, "ChallengePlayed", 1, { game = session.game, outcome = outcome })
		end
	end
	if outcome == "a" or outcome == "b" then
		local winner = outcome == "a" and a or b
		local loser = outcome == "a" and b or a
		local s = Progress.session(winner)
		local paid = 0
		if s then
			s.profile.stats.challengeWins = (s.profile.stats.challengeWins or 0) + 1
			paid = pay(winner, loser, CH.WIN, s)
			Progress.checkAchievements(winner)
		end
		tell(winner, "win", paid, loser)
		tell(loser, "lose", 0, winner)
	elseif outcome == "tie" then
		for _, p in ipairs({ a, b }) do
			local s = Progress.session(p)
			local other = p == a and b or a
			tell(p, "tie", s and pay(p, other, CH.TIE, s) or 0, other)
		end
	else
		local stayed = outcome == "forfeitA" and b or a
		local gone = outcome == "forfeitA" and a or b
		tell(stayed, "forfeit", 0, gone)
	end
	local _ = standings
end)

function Challenges.request(player, action, a, b)
	if action == "ask" then
		Challenges.ask(player, a, b)
	elseif action == "answer" then
		Challenges.answer(player, a, b == true)
	elseif action == "cancel" then
		Challenges.cancel(player)
	elseif action == "rematch" then
		Challenges.rematch(player, a)
	end
end

function Challenges.init()
	Players.PlayerRemoving:Connect(function(player)
		for _, invite in pairs(table.clone(invites)) do
			if invite.from == player or invite.to == player then
				close(invite, "gone")
			end
		end
		outgoing[player] = nil
		for id, record in pairs(records) do
			if
				(record.a == player or record.b == player) and (not record.session or record.session.state == "closed")
			then
				records[id] = nil
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for _, invite in pairs(table.clone(invites)) do
				if t >= invite.expiresAt then
					close(invite, "expired")
				end
			end
			for id, record in pairs(table.clone(records)) do
				if
					(record.rematchUntil or math.huge) < t - 30
					and not (record.session and record.session.state ~= "closed")
				then
					records[id] = nil
				end
			end
		end
	end)
end

return Challenges

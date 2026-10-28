-- THE PET DERBY (V13.3): your pet (the one you have out, or a crab on loan) races round an oval on the Port's south
-- lawn against other goblins' pets and the menagerie's, over six hurdles. You stand in the grandstand and CHEER: as your
-- pet reaches a hurdle, a well-timed cheer is a clean jump and a burst of speed; too soon, too late or none at all and
-- it trips over the hurdle; cheering with no hurdle near makes it stumble (no mashing). Every pet runs the same speed,
-- whatever it is or cost: rarity is never speed. Every pet also stops once to sniff a flower (the same pause for all,
-- somewhere different each race), so a race is never only a straight line.
--
-- V13.4: the heart of the window is a PERFECT cheer (a longer burst), clean jumps in a row make a STREAK (the third on
-- is ON FIRE: a faster burst; a tumble or mashing ends it), and a COMMENTATOR calls the race (PetDerby.call). Bots are
-- never perfect (only clean, BOT_SKILL of the time); every pet still runs the same speed.
--
-- The race is the server's (20 steps a second): each racer's fraction of a lap, its speed and what it is doing. Clients
-- draw the pets with the shared animator (shared/PetLook.lua) from the session's fast channel (Minigames.live, 10 a
-- second) and extrapolate between: client/PlayHud.lua. A cheer is judged on the server's own racer with a little
-- allowance for lag (PortGames.derbyJudge).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local Palette = require(Shared:WaitForChild("Palette"))
local Net = require(script.Parent.Net)
local Minigames = require(script.Parent.Minigames)

local DG = Config.PLAYGROUND.DERBY
local track = PortGames.DERBY
local rgb = Color3.fromRGB
local v3 = Vector3.new

local PetDerby = { id = "derby", max = DG.MAX, duration = DG.LIMIT }

-- The menagerie's runners, when there are not enough goblins' pets.
local BOTS = {
	{ pet = "Waddles", name = "Waddles" },
	{ pet = "Rubble", name = "Rubble" },
	{ pet = "Monkey", name = "Rascal" },
	{ pet = "Lamb", name = "Lambkin" },
	{ pet = "Fuse", name = "Fuse" },
	{ pet = "Otter", name = "Kelp" },
	{ pet = "Twig", name = "Twig" },
	{ pet = "Chompers", name = "Chompers" },
	{ pet = "Dubloon", name = "Dubloon" },
}

local raceNumber = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Building ------------------------------------------------------------------------------------------------------------------
function PetDerby.build(kit)
	local C = track.center
	-- The track: a band of packed earth round the oval, the infield lawn, rails, and the hurdles.
	local segments = 56
	local width = track.lanes * track.laneWidth + 3
	for i = 0, segments - 1 do
		local f0, f1 = i / segments, (i + 1) / segments
		local a = PortGames.derbyPoint(f0, 1)
		local b = PortGames.derbyPoint(f1, 1)
		local _, heading = PortGames.derbyPoint((f0 + f1) / 2, 1)
		local outward = v3(-heading.Z, 0, heading.X)
		local mid = (a + b) / 2 + outward * (width / 2 - 1.2)
		kit.part(
			"DerbyTrack",
			v3(width, 1, (b - a).Magnitude + 0.6),
			CFrame.lookAt(v3(mid.X, 5.6, mid.Z), v3(mid.X, 5.6, mid.Z) + heading),
			(i % 2 == 0) and rgb(196, 150, 104) or rgb(186, 142, 98),
			Enum.Material.Ground
		)
		if i % 2 == 0 then
			kit.deco(
				"DerbyRail",
				v3(0.4, 0.4, (b - a).Magnitude),
				CFrame.lookAt(
					v3(mid.X, 6.8, mid.Z) + outward * (width / 2 + 0.4),
					v3(mid.X, 6.8, mid.Z) + outward * (width / 2 + 0.4) + heading
				),
				rgb(246, 244, 238),
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- The infield: a flat oval of lawn (an ellipsoid squashed flat).
	kit.deco(
		"DerbyInfield",
		v3(track.a * 2 - 2, 0.5, track.b * 2 - 2),
		CFrame.new(C + v3(0, -0.2, 0)),
		rgb(126, 196, 92),
		Enum.Material.Grass,
		{ egg = true }
	)
	for i, f in ipairs(track.hurdles) do
		local inner = PortGames.derbyPoint(f, 1)
		local outer = PortGames.derbyPoint(f, track.lanes)
		local _, heading = PortGames.derbyPoint(f, 1)
		local mid = (inner + outer) / 2
		local span = (outer - inner).Magnitude + 2
		local cf = CFrame.lookAt(v3(mid.X, 6.6, mid.Z), v3(mid.X, 6.6, mid.Z) + heading)
		kit.deco(
			"Hurdle",
			v3(span, 0.6, 0.6),
			cf * CFrame.new(0, 0.8, 0),
			(i % 2 == 0) and rgb(230, 50, 46) or rgb(246, 244, 238),
			Enum.Material.SmoothPlastic
		)
		for _, side in ipairs({ -1, 1 }) do
			kit.deco(
				"HurdleLeg",
				v3(0.4, 1.8, 0.4),
				cf * CFrame.new(side * span / 2, 0, 0),
				Palette.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	-- The start and finish line.
	local s0 = PortGames.derbyPoint(0, 1)
	local s1 = PortGames.derbyPoint(0, track.lanes)
	local _, h0 = PortGames.derbyPoint(0, 1)
	for k = 0, 7 do
		local at = s0:Lerp(s1, (k + 0.5) / 8)
		kit.deco(
			"DerbyLine",
			v3(track.laneWidth * track.lanes / 8 + 0.1, 0.1, 1.2),
			CFrame.lookAt(v3(at.X, 6.12, at.Z), v3(at.X, 6.12, at.Z) + h0),
			(k % 2 == 0) and rgb(28, 26, 32) or rgb(246, 244, 238),
			Enum.Material.SmoothPlastic
		)
	end
	-- The grandstand on the north side, facing the line.
	local stand = C + v3(0, 0, -(track.b + track.lanes * track.laneWidth + 12))
	for row = 0, 2 do
		kit.part(
			"StandStep",
			v3(46, 1 + row * 1.6, 5),
			CFrame.new(stand + v3(0, -0.4 + row * 0.8, -row * 5)),
			Palette.WOOD,
			Enum.Material.WoodPlanks
		)
	end
	for k = 0, 9 do
		kit.deco(
			"StandAwning",
			v3(4.6, 0.3, 17),
			CFrame.new(stand + v3(-20.7 + k * 4.6, 9.6, -5)) * CFrame.Angles(math.rad(-10), 0, 0),
			(k % 2 == 0) and rgb(255, 150, 190) or rgb(250, 244, 230),
			Enum.Material.Fabric
		)
	end
	for _, x in ipairs({ -22, 22 }) do
		kit.part("StandPost", v3(0.8, 10, 0.8), CFrame.new(stand + v3(x, 4, 2)), Palette.WOOD_DARK, Enum.Material.Wood)
	end
	kit.board(
		"DerbySign",
		v3(22, 4, 0.5),
		CFrame.lookAt(PortGames.VENUES.derby.sign, PortGames.VENUES.derby.sign + v3(0, 0, 1)),
		"THE PET DERBY",
		rgb(255, 170, 205)
	)
	PetDerby.stand = stand
end

-- Racing --------------------------------------------------------------------------------------------------------------------
local function standSpot(i)
	local stand = PetDerby.stand or track.center
	local x = -15 + ((i - 1) % 6) * 6
	return CFrame.lookAt(stand + v3(x, 5, -5), track.center + v3(x, 3, 0))
end

function PetDerby.prepare(session)
	raceNumber += 1
	session.data.racers = {}
	session.data.byUser = {}
	local lane = 0
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry and not entry.left then
			lane += 1
			local look = Catalog.decodeLook(player:GetAttribute("Look"))
			local racer = {
				id = tostring(player.UserId),
				user = player.UserId,
				name = player.DisplayName,
				pet = look.pet or "Crab",
				skin = look.petskin,
				hat = look.pethat,
				loan = look.pet == nil,
				lane = lane,
			}
			table.insert(session.data.racers, racer)
			session.data.byUser[player.UserId] = racer
			entry.data.racer = racer
			Minigames.place(player, standSpot(i), false)
		end
	end
	local start = raceNumber % #BOTS
	local b = 0
	while #session.data.racers < DG.FIELD do
		b += 1
		local bot = BOTS[(start + b - 1) % #BOTS + 1]
		lane += 1
		table.insert(session.data.racers, {
			id = "bot" .. b,
			name = bot.name,
			pet = bot.pet,
			lane = lane,
			bot = true,
		})
	end
	-- Everyone's sniff: somewhere between 15% and 90% of the lap, the same length for all.
	for i, racer in ipairs(session.data.racers) do
		local h = Seasons.mix(raceNumber, i * 13)
		racer.sniffAt = 0.15 + (h % 750) / 1000
		racer.p = 0
		racer.state = "run"
		racer.stateAt = now()
		racer.untilAt = 0
		racer.nextHurdle = 1
		racer.judged = {}
		racer.seed = h
	end
	session.data.cheerAt = {}
end

local function speedOf(racer)
	local s = racer.state
	if s == "zoom" then
		return DG.SPEED * ((racer.streak or 0) >= DG.STREAK and DG.FIRE or DG.ZOOM)
	elseif s == "trip" then
		return DG.SPEED * DG.TRIP
	elseif s == "sniff" or s == "done" then
		return 0
	elseif s == "stumble" then
		return DG.SPEED * 0.5
	end
	return DG.SPEED
end

local function setState(session, racer, state, seconds, t)
	racer.state = state
	racer.stateAt = t
	racer.untilAt = t + (seconds or 0)
	session.data.liveDirty = true
end

function PetDerby.go(session, t)
	session.endsAt = t + DG.LIMIT
	session.data.nextLive = t
	for _, racer in ipairs(session.data.racers) do
		racer.stateAt = t
	end
end

local function publishLive(session, t)
	local rows = {}
	for _, racer in ipairs(session.data.racers) do
		table.insert(rows, {
			i = racer.id,
			p = math.floor(racer.p * 100000 + 0.5) / 100000,
			v = speedOf(racer),
			s = racer.state,
			a = racer.stateAt,
			k = (racer.streak or 0) > 0 and racer.streak or nil, -- V13.4: clean jumps in a row
		})
	end
	Minigames.live(session, { t = t, r = rows })
end

function PetDerby.tick(session, dt, t)
	local L = track.length
	for _, racer in ipairs(session.data.racers) do
		if racer.state ~= "done" then
			if racer.state ~= "run" and t >= racer.untilAt then
				setState(session, racer, "run", 0, t)
			end
			racer.p += speedOf(racer) * dt / L
			if not racer.sniffed and racer.p >= racer.sniffAt and racer.state == "run" then
				racer.sniffed = true
				setState(session, racer, "sniff", DG.SNIFF, t)
			end
			-- A bot makes up its mind just before a hurdle.
			local h = track.hurdles[racer.nextHurdle]
			if racer.bot and h and not racer.judged[racer.nextHurdle] then
				local tth = (h - racer.p) * L / math.max(speedOf(racer), 0.1)
				if tth <= 0.3 then
					local roll = (Seasons.mix(racer.seed, racer.nextHurdle * 7 + raceNumber) % 1000) / 1000
					racer.judged[racer.nextHurdle] = roll < DG.BOT_SKILL and "clean" or "miss"
				end
			end
			-- The hurdle is settled a moment after the pet reaches it (late cheers still count).
			if h and racer.p >= h + DG.LATE * DG.SPEED / L then
				local verdict = racer.judged[racer.nextHurdle]
				racer.nextHurdle += 1
				if verdict == "clean" or verdict == "perfect" then
					racer.streak = (racer.streak or 0) + 1
					setState(session, racer, "zoom", verdict == "perfect" and DG.PERFECT_TIME or DG.ZOOM_TIME, t)
					if racer.streak == DG.STREAK then
						PetDerby.call(session, t, "fire", racer)
					end
				else
					local wasLeading = session.data.leader == racer
					racer.streak = 0
					setState(session, racer, "trip", DG.TRIP_TIME, t)
					if wasLeading then
						PetDerby.call(session, t, "trip", racer)
					end
				end
			end
			if racer.p >= 1 then
				racer.p = 1
				racer.finishedAt = t
				setState(session, racer, "done", 0, t)
				if not session.data.winner then
					session.data.winner = racer
					PetDerby.call(session, t, "win", racer)
				elseif PetDerby.place(session, racer) == 2 and t - session.data.winner.finishedAt < 0.35 then
					PetDerby.call(session, t, "photo", racer)
				end
				if racer.user then
					local player
					for p, entry in pairs(session.entries) do
						if entry.userId == racer.user then
							player = p
						end
					end
					if player then
						local time = math.floor((t - session.goAt) * 100 + 0.5) / 100
						Minigames.done(session, player, time, { place = PetDerby.place(session, racer) })
					end
				end
			end
		end
	end
	-- The leader, for the commentator (who has the lead, and the final stretch once).
	local leader
	for _, racer in ipairs(session.data.racers) do
		if not racer.finishedAt and not racer.gone and (not leader or racer.p > leader.p) then
			leader = racer
		end
	end
	if leader and not session.data.winner then
		if leader ~= session.data.leader then
			local first = session.data.leader == nil
			session.data.leader = leader
			if not first and leader.p > 0.08 then
				PetDerby.call(session, t, "lead", leader)
			end
		end
		if leader.p > 0.86 and not session.data.stretch then
			session.data.stretch = true
			PetDerby.call(session, t, "stretch", leader, true)
		end
	end
	if session.state == "running" and (session.data.liveDirty or t >= session.data.nextLive) then
		session.data.liveDirty = false
		session.data.nextLive = t + 0.1
		publishLive(session, t)
	end
end

-- THE COMMENTATOR (V13.4): a line on everyone's screen at the oval for the moments worth shouting about: a new
-- leader, the leader tumbling, a pet on fire, the final stretch, a photo finish, the winner. At most one every
-- CALL_GAP seconds (the winner and the photo always get theirs). The lines are picked by the race, not at random, so
-- every client and the tests see the same.
local CALL_GAP = 2.2
local LINES = {
	lead = { "%s takes the lead!", "%s noses in front!", "And now it's %s out front!" },
	trip = { "Oh no! %s goes head over heels!", "%s trips! The crowd gasps!", "Down goes %s! What a tumble!" },
	fire = { "%s is ON FIRE!", "Three clean jumps: %s is flying!", "Nobody can stop %s!" },
	stretch = { "Final stretch! %s leads!", "Into the home straight: %s in front!" },
	photo = { "PHOTO FINISH! %s by a whisker!", "So close! %s is just behind!" },
	win = { "%s WINS THE DERBY!", "It's %s! What a race!", "%s takes it! Treats all round!" },
}

local function petName(racer)
	local item = racer.pet and Catalog.get(racer.pet)
	local pet = item and item.name or racer.pet or "?"
	if racer.bot then
		return racer.name
	end
	return string.format("%s's %s", racer.name, pet)
end

function PetDerby.call(session, t, kind, racer, force)
	local important = kind == "win" or kind == "photo"
	if not important and not force and t - (session.data.calledAt or -math.huge) < CALL_GAP then
		return
	end
	session.data.calledAt = t
	local list = LINES[kind]
	session.data.calls = (session.data.calls or 0) + 1
	local text = string.format(list[(raceNumber + session.data.calls) % #list + 1], petName(racer))
	Net.broadcastNear(track.center, 400, "PlayFx", { kind = "derbycall", text = text, call = kind, racer = racer.id })
end

-- Where a racer finished among every pet in the race (bots too); unfinished pets by how far they got.
function PetDerby.place(session, racer)
	local ahead = 0
	for _, other in ipairs(session.data.racers) do
		if other ~= racer then
			local finishedFirst = other.finishedAt and (not racer.finishedAt or other.finishedAt < racer.finishedAt)
			local fartherAlong = not other.finishedAt and not racer.finishedAt and other.p > racer.p
			if finishedFirst or fartherAlong then
				ahead += 1
			end
		end
	end
	return ahead + 1
end

function PetDerby.placeOf(session, entry)
	local racer = entry.data.racer
	return racer and PetDerby.place(session, racer) or nil
end

-- CHEER: judged against this racer's next hurdle.
function PetDerby.input(session, player, action)
	if action ~= "cheer" then
		return
	end
	local entry = session.entries[player]
	local racer = entry and entry.data.racer
	if not racer or racer.state == "done" then
		return
	end
	local t = now()
	if t - (session.data.cheerAt[player] or 0) < 0.12 then
		return
	end
	session.data.cheerAt[player] = t
	local h = track.hurdles[racer.nextHurdle]
	local tth = h and (h - racer.p) * track.length / math.max(speedOf(racer), DG.SPEED * 0.3) or nil
	local verdict = PortGames.derbyJudge(tth)
	if h and racer.judged[racer.nextHurdle] then
		verdict = "none" -- a second cheer for the same hurdle is mashing
	end
	if verdict == "perfect" or verdict == "clean" or verdict == "early" then
		racer.judged[racer.nextHurdle] = verdict
	elseif racer.state == "run" then
		racer.streak = 0 -- mashing breaks a streak
		setState(session, racer, "stumble", DG.STUMBLE, t)
	end
	Net.broadcastNear(
		track.center,
		400,
		"PlayFx",
		{ kind = "cheer", racer = racer.id, verdict = verdict, userId = player.UserId }
	)
end

function PetDerby.drop(session, player)
	local entry = session.entries[player]
	local racer = entry and entry.data.racer
	if racer then
		-- The pet stops: its goblin went home.
		racer.state = "done"
		racer.gone = true
		session.data.liveDirty = true
	end
end

function PetDerby.stop(_session) end

function PetDerby.spot(_session, player)
	local i = (player.UserId % 6) + 1
	return standSpot(i)
end

-- What every client needs once: who races in which lane with which pet.
function PetDerby.public(session)
	local list = {}
	for _, racer in ipairs(session.data.racers or {}) do
		table.insert(list, {
			i = racer.id,
			u = racer.user,
			n = racer.name,
			pet = racer.pet,
			skin = racer.skin,
			hat = racer.hat,
			lane = racer.lane,
			bot = racer.bot,
			loan = racer.loan,
		})
	end
	return { racers = list }
end

return PetDerby

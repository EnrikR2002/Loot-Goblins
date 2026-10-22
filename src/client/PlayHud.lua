-- The Port's games on this client (V13.3). Everything here is drawn from what the server publishes
-- (ReplicatedStorage.LootGoblinsPlay: one JSON StringValue per session, and a fast `.live` one for games that move a
-- lot) and from shared/PortGames.lua; this client only ever sends intent (PlayRequest: "leave", "again", a game's
-- own input). The game-specific parts live beside it: client/PlayGolf.lua (the tee's aim and power), PlayRange.lua
-- (Treasure Toss and the Target Gallery: targets, throws, cannons), PlayCritters.lua (the Derby's pets and the crabs).
--
--   VENUE SIGNS  over each venue, what it is doing now: E TO PLAY, STARTING IN 5 (2 in), RACE ON, how many are waiting.
--   THE PANEL    while you play: the game, a big 3-2-1-GO, the clock (time games count up, points games count down),
--                your progress (a checkpoint, a hole, your points and place), the leaders, LEAVE and RESET. If you
--                are signed up for the raid, a red warning before it leaves (it ends your game).
--   MARKERS      the next checkpoint (Regatta) or platform (Gauntlet), pointed at from wherever you are.
--   RESULTS      your score, place and medal, a new best, the Shinies (and the day's cap), AGAIN or REMATCH.
-- The raid HUD steps aside in the Port; while you drive a Racing Tub its boat panel comes back (client/Hud.lua).
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local PlayGolf = require(script.Parent.PlayGolf)
local PlayRange = require(script.Parent.PlayRange)
local PlayCritters = require(script.Parent.PlayCritters)

local PlayHud = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local playRemote = remotes:WaitForChild("PlayRequest")
local challengeRemote = remotes:WaitForChild("ChallengeRequest")
local C = Ui.C
local G = Config.PLAYGROUND
local GOLD = C.gold

local sessions = {} -- id -> decoded session
local lives = {} -- id -> decoded live data
local hud -- client/Hud (toasts, banners)
local gui, scaler, panel, title, big, sub, roster, buttons, resetButton, warning
local resultCard
local venueSigns = {}
local marker, markerLabel
local ctx -- what the game parts are given each frame

local function now()
	return workspace:GetServerTimeNow()
end

local function clock(seconds, tenths)
	seconds = math.max(0, seconds)
	if tenths then
		return string.format("%d:%04.1f", seconds // 60, seconds % 60)
	end
	seconds = math.floor(seconds + 0.5)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
PlayHud.clock = clock

local function ordinal(n)
	if not n then
		return ""
	end
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

local function scoreText(def, score)
	if score == nil then
		return "-"
	end
	if def and def.kind == "time" then
		return string.format("%.2f s", score)
	end
	return tostring(math.floor(score + 0.5)) .. " pts"
end
PlayHud.scoreText = scoreText

-- Watching the server's sessions ----------------------------------------------------------------------------------------
local folder
local function decode(value)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return ok and data or nil
end

local function watch(value)
	if not value:IsA("StringValue") then
		return
	end
	local name = value.Name
	local isLive = string.sub(name, -5) == ".live"
	local function read()
		local data = decode(value)
		if isLive then
			lives[string.sub(name, 1, -6)] = data
		else
			sessions[name] = data
		end
	end
	read()
	value.Changed:Connect(read)
end

local function mySession()
	local id = player:GetAttribute("PlaySession")
	return id and sessions[id] or nil, id
end
PlayHud.mySession = mySession

local function myRow(session)
	for _, row in ipairs(session and session.players or {}) do
		if row.u == player.UserId then
			return row
		end
	end
	return nil
end

-- Building --------------------------------------------------------------------------------------------------------------------
local function build()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsPlay", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = false },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local root = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	scaler = Ui.make("UIScale", {}, root)
	panel = Ui.make("Frame", {
		Name = "GamePanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 104),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	Ui.corner(panel, 16)
	Ui.stroke(panel, GOLD, 2)
	title = Ui.label(panel, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 18),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	big = Ui.label(panel, {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 46),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 40,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(big, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	sub = Ui.label(panel, {
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = C.parchment,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	})
	roster = Ui.make("Frame", {
		Name = "Leaders",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 140),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.3,
		Visible = false,
	}, root)
	Ui.corner(roster, 10)
	Ui.pad(roster, 8, 6, 8, 6)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, roster)
	buttons = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(300, 38),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buttons)
	Ui.button(buttons, {
		text = "LEAVE",
		style = "wood",
		size = UDim2.fromOffset(110, 36),
		textSize = 16,
		order = 1,
		name = "LeaveGame",
	}, function()
		playRemote:FireServer("leave")
	end)
	resetButton = Ui.button(buttons, {
		text = "↺ RESET",
		style = "parchment",
		size = UDim2.fromOffset(120, 36),
		textSize = 16,
		order = 2,
		name = "ResetGame",
	}, function()
		playRemote:FireServer("reset")
	end)
	warning = Ui.label(root, {
		Name = "RaidWarning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 164),
		Size = UDim2.fromOffset(340, 30),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 18,
		TextColor3 = C.white,
		BackgroundColor3 = C.danger,
		BackgroundTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(warning, 15)
	-- The marker over the next checkpoint or platform.
	local anchor = Ui.make("Part", {
		Name = "PlayMarkerAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
	}, workspace)
	marker = Ui.make("BillboardGui", {
		Name = "PlayMarker",
		Adornee = anchor,
		Size = UDim2.fromOffset(150, 64),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 3000,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	markerLabel = Ui.label(marker, {
		Size = UDim2.fromScale(1, 1),
		Text = "▼",
		Font = Ui.TITLE,
		TextScaled = true,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(markerLabel, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	PlayHud.markerAnchor = anchor
end

-- A sign over each venue: what it is doing right now.
local function buildVenueSigns()
	for _, def in ipairs(PortGames.GAMES) do
		local venue = PortGames.VENUES[def.id]
		local anchor = Ui.make("Part", {
			Name = "VenueSign_" .. def.id,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(venue.sign + Vector3.new(0, 6, 0)),
		}, workspace)
		local sign = Ui.make("BillboardGui", {
			Name = "VenueStatus",
			Adornee = anchor,
			Size = UDim2.fromOffset(240, 70),
			LightInfluence = 0,
			MaxDistance = 220,
			AlwaysOnTop = false,
		}, player:WaitForChild("PlayerGui"))
		local label = Ui.label(sign, {
			Size = UDim2.fromScale(1, 1),
			Text = def.icon .. " " .. string.upper(def.name),
			Font = Ui.TITLE,
			TextScaled = true,
			TextColor3 = C.white,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.stroke(label, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		venueSigns[def.id] = { label = label, gui = sign }
	end
end

local function updateVenueSigns(t)
	local byGame = {}
	for _, session in pairs(sessions) do
		if session.game then
			byGame[session.game] = byGame[session.game] or {}
			table.insert(byGame[session.game], session)
		end
	end
	for _, def in ipairs(PortGames.GAMES) do
		local sign = venueSigns[def.id]
		if sign then
			local list = byGame[def.id] or {}
			local queue = folder and folder:GetAttribute(def.id .. "Queue") or 0
			local line
			if #list == 0 then
				line = "E TO PLAY"
			elseif def.concurrent then
				line = string.format("%d PLAYING  ·  E TO PLAY", #list)
			else
				local s = list[1]
				if s.state == "lobby" then
					line = string.format(
						"STARTING IN %d  ·  %d IN  ·  E TO JOIN",
						math.ceil(math.max(0, (s.lobbyEndsAt or t) - t)),
						#(s.players or {})
					)
				elseif s.state == "countdown" or s.state == "running" then
					line = (def.kind == "time" and "RACE ON" or "ROUND ON")
						.. (queue > 0 and string.format("  ·  %d WAITING", queue) or "  ·  E: NEXT HEAT")
				elseif s.state == "results" then
					line = "RESULTS!"
				else
					line = "E TO PLAY"
				end
			end
			sign.label.Text = def.icon .. " " .. string.upper(def.name) .. "\n" .. line
		end
	end
end

-- The panel while playing ---------------------------------------------------------------------------------------------------
local function progressLine(def, session, row, t)
	local x = row and row.x
	if def.id == "regatta" and type(x) == "table" then
		return string.format("CHECKPOINT %d/%d%s", x.cp or 0, x.of or 13, x.pos and ("  ·  " .. ordinal(x.pos)) or "")
	elseif def.id == "gauntlet" and type(x) == "table" then
		return string.format("PLATFORM %d/%d", x.cp or 0, x.of or 8)
	elseif def.id == "golf" and type(x) == "table" then
		local shots = {}
		for _, s in ipairs(x.shots or {}) do
			table.insert(shots, tostring(s))
		end
		return string.format(
			"HOLE %d/%d  ·  %s",
			x.hole or 1,
			x.of or 3,
			#shots > 0 and table.concat(shots, " + ") or "aim and hold to charge"
		)
	elseif def.id == "derby" then
		return PlayCritters.derbyLine(session, t) or "CHEER (SPACE) as your pet reaches a hurdle!"
	end
	local place = row and row.p
	return string.format("%s%s", scoreText(def, row and row.s or 0), place and ("  ·  " .. ordinal(place)) or "")
end

local function updateRoster(session)
	for _, child in ipairs(roster:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local def = PortGames.BY_ID[session.game]
	local shown = 0
	for i, row in ipairs(session.players or {}) do
		if shown < 5 and not row.l then
			shown += 1
			local mine = row.u == player.UserId
			Ui.label(roster, {
				Size = UDim2.new(1, 0, 0, 18),
				Text = string.format(
					"%s %s  %s",
					row.p and ordinal(row.p) or "·",
					row.n or "?",
					row.s ~= nil and scoreText(def, row.s) or (row.d and "done" or "")
				),
				Font = mine and Ui.BOLD or Ui.BODY,
				TextSize = 13,
				TextColor3 = mine and C.goldPale or C.white,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = i,
			})
		end
	end
	roster.Visible = shown >= 2
end

local lastRosterText
local function updatePanel(t)
	local session = mySession()
	if not session then
		panel.Visible = false
		buttons.Visible = false
		roster.Visible = false
		warning.Visible = false
		marker.Enabled = false
		return
	end
	local def = PortGames.BY_ID[session.game]
	local row = myRow(session)
	panel.Visible = true
	buttons.Visible = session.state ~= "results"
	resetButton.Visible = (def.id == "regatta" or def.id == "gauntlet") and session.state == "running"
	title.Text = def.icon .. "  " .. string.upper(def.name) .. (session.challenge and "  ·  CHALLENGE" or "")
	if session.state == "lobby" or session.state == "waiting" then
		local left = math.max(0, (session.lobbyEndsAt or t) - t)
		big.Text = session.state == "waiting" and "WAITING FOR THE VENUE" or ("STARTING IN " .. math.ceil(left))
		big.TextSize = 28
		sub.Text = def.hint
	elseif session.state == "countdown" then
		local left = (session.goAt or t) - t
		big.Text = left > 0 and tostring(math.ceil(left)) or "GO!"
		big.TextSize = 46
		sub.Text = def.hint
	elseif session.state == "running" then
		big.TextSize = 38
		if def.kind == "time" then
			big.Text = row and row.d and row.s and string.format("%.2f s", row.s)
				or clock(t - (session.goAt or t), true)
		else
			big.Text = clock((session.endsAt or t) - t) .. "   " .. tostring(math.floor((row and row.s or 0) + 0.5))
		end
		sub.Text = progressLine(def, session, row, t)
	else
		big.Text = "FINISHED!"
		big.TextSize = 34
		sub.Text = row and row.p and (ordinal(row.p) .. " of " .. #(session.players or {})) or ""
	end
	local text = HttpService:JSONEncode(session.players or {})
	if text ~= lastRosterText then
		lastRosterText = text
		updateRoster(session)
	end
	-- The raid leaving soon ends the game for anyone signed up.
	local phase = workspace:GetAttribute("RaidPhase")
	local leavesIn = (workspace:GetAttribute("PhaseEndsAt") or 0) - t
	local signed = (workspace:GetAttribute("PortSigned") or 0) > 0
	if player:GetAttribute("RaidOptIn") and phase == "port" and signed and leavesIn <= G.RAID_WARN and leavesIn > 0 then
		warning.Visible = true
		warning.Text = string.format("⚔ YOUR RAID LEAVES IN %d", math.ceil(leavesIn))
	else
		warning.Visible = false
	end
	-- The next checkpoint or platform.
	local x = row and row.x
	local target
	if session.state == "running" and type(x) == "table" and not (row and row.d) then
		if def.id == "regatta" then
			local cp = PortGames.REGATTA.checkpoints[(x.cp or 0) + 1]
			target = cp and (cp.discs[1].center + Vector3.new(0, 16, 0))
			markerLabel.Text = cp
					and (cp.teeth and "▼ THE TEETH" or "▼ " .. ((x.cp or 0) + 1 == PortGames.REGATTA.finish and "FINISH" or "NEXT"))
				or ""
		elseif def.id == "gauntlet" then
			local p = PortGames.GAUNTLET.platforms[(x.cp or 0) + 1]
			target = p and (p.center + Vector3.new(0, 9, 0))
			markerLabel.Text = p and ("▼ " .. (p.name == "FINISH" and "THE BELL" or "NEXT")) or ""
		end
	end
	if target then
		PlayHud.markerAnchor.CFrame = CFrame.new(target)
		marker.Enabled = true
	else
		marker.Enabled = false
	end
end

-- Results ------------------------------------------------------------------------------------------------------------------
local function closeResult()
	if resultCard then
		resultCard:Destroy()
		resultCard = nil
	end
end

local MEDAL = { gold = "🥇", silver = "🥈", bronze = "🥉" }

function PlayHud.result(p)
	closeResult()
	local def = PortGames.BY_ID[p.game]
	if not def then
		return
	end
	local b = p.breakdown or {}
	local card = Ui.make("Frame", {
		Name = "GameResult",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.55, 0),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.parchment,
	}, gui:FindFirstChildOfClass("Frame"))
	resultCard = card
	Ui.corner(card, 16)
	Ui.stroke(card, C.goldDeep, 3)
	Ui.pad(card, 14, 12, 14, 12)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	local scale = Ui.make("UIScale", { Scale = 0.8 }, card)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 20),
		Text = def.icon .. "  " .. string.upper(def.name),
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = C.inkSoft,
		LayoutOrder = 1,
	})
	local headline
	if p.score == nil or not p.counted then
		headline = (def.kind == "time" and p.score == nil) and "DIDN'T FINISH" or "NO SCORE THIS TIME"
	else
		headline = (MEDAL[b.medal] or "") .. " " .. scoreText(def, p.score)
	end
	Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 36),
		Text = headline,
		Font = Ui.TITLE,
		TextSize = 30,
		LayoutOrder = 2,
	})
	if p.place and (p.players or 1) >= 2 or (def.id == "derby" and p.place) then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = ordinal(p.place) .. (def.id == "derby" and " of the field" or (" of " .. tostring(p.players))),
			Font = Ui.TITLE,
			TextSize = 18,
			TextColor3 = p.place == 1 and C.goldDeep or C.ink,
			LayoutOrder = 3,
		})
	end
	if b.best then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = "★ NEW PERSONAL BEST!",
			Font = Ui.TITLE,
			TextSize = 18,
			TextColor3 = C.goldDeep,
			LayoutOrder = 4,
		})
	elseif b.first then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Your first score here: now beat it!",
			Font = Ui.BODY,
			TextSize = 14,
			TextColor3 = C.inkSoft,
			LayoutOrder = 4,
		})
	elseif b.previous then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Your best: " .. scoreText(def, b.previous),
			Font = Ui.BODY,
			TextSize = 14,
			TextColor3 = C.inkSoft,
			LayoutOrder = 4,
		})
	end
	local row = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 5 }, card)
	Ui.gem(row, 14, UDim2.new(0, 6, 0.5, 0))
	local shinyText
	if (b.shinies or 0) > 0 then
		shinyText = string.format("+%d SHINIES   (today %d/%d)", b.shinies, b.today or 0, b.cap or G.DAILY_SHINIES)
	elseif b.capped then
		shinyText = "Today's game Shinies are all won: play for bests!"
	else
		shinyText = "No Shinies for this one"
	end
	Ui.label(row, {
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Text = shinyText,
		Font = Ui.TITLE,
		TextSize = (b.shinies or 0) > 0 and 18 or 13,
		TextColor3 = (b.shinies or 0) > 0 and C.goldDeep or C.inkSoft,
		TextWrapped = true,
	})
	local actions =
		Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 10 }, card)
	local again = Ui.button(actions, {
		text = p.challenge and "⚔ REMATCH" or "▶ AGAIN",
		size = UDim2.new(0.6, -4, 1, 0),
		textSize = 17,
		name = "PlayAgain",
	}, function()
		if p.challenge then
			challengeRemote:FireServer("rematch", PlayHud.lastChallenge)
			hud.toast("Rematch asked: waiting for them to press it too...")
		else
			playRemote:FireServer("again", p.game)
		end
		closeResult()
	end)
	Ui.button(actions, {
		text = "CLOSE",
		style = "ghost",
		size = UDim2.new(0.4, -4, 1, 0),
		position = UDim2.new(0.6, 4, 0, 0),
		textSize = 17,
	}, closeResult)
	Ui.focus(again)
	if b.best or b.medal == "gold" then
		Effects.chime(Effects.CHIME_GOOD, 0.8)
	else
		Effects.chime({ 1, 1.26 }, 0.6)
	end
	local this = card
	task.delay(14, function()
		if resultCard == this then
			closeResult()
		end
	end)
end

-- Effects the server asks for ------------------------------------------------------------------------------------------------
function PlayHud.fx(p)
	local kind = p.kind
	if PlayGolf.fx(p) or PlayRange.fx(p) or PlayCritters.fx(p) then
		return
	end
	if kind == "splash" and p.position then
		Effects.spray(p.position, 1.6)
		Effects.ring(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(190, 240, 255), (p.radius or 20) + 10, 0.8)
		Effects.sound("splash", { position = p.position, speed = 0.8, volume = 1, range = 500 })
		Effects.sound("boom", { position = p.position, speed = 1.4, volume = 0.5, range = 500 })
	elseif kind == "finish" and p.position then
		Effects.firework(p.position + Vector3.new(0, 18, 0), GOLD)
		Effects.sound("rise", { position = p.position, speed = 1.3, volume = 0.9, range = 600 })
		if p.userId == player.UserId then
			hud.banner("FINISHED!", GOLD, 2.5, 3)
		end
	elseif kind == "bell" and p.position then
		Effects.ring(p.position, GOLD, 18, 0.6)
		Effects.sound("blip", { position = p.position, speed = 0.5, volume = 1, range = 500 })
		Effects.firework(p.position + Vector3.new(0, 12, 0), GOLD)
		if p.userId == player.UserId then
			hud.banner("DING! RUN COMPLETE!", GOLD, 2.5, 3)
		end
	elseif kind == "checkpoint" then
		Effects.chime({ 1.26, 1.5 }, 0.5)
	elseif kind == "fall" then
		hud.toast("Splash! Back to your last platform (the clock runs on).")
	elseif kind == "reset" then
		hud.toast("Back at your last checkpoint.")
	elseif kind == "lift" then
		if PlayHud.fade then
			PlayHud.fade()
		end
	end
end

-- Every frame ---------------------------------------------------------------------------------------------------------------
local nextSigns = 0
local function update(dt)
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scaler.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.15)
	end
	local t = now()
	if t >= nextSigns then
		nextSigns = t + 0.5
		updateVenueSigns(t)
	end
	updatePanel(t)
	local session = mySession()
	ctx.t = t
	ctx.sessions = sessions
	ctx.lives = lives
	ctx.mine = session
	ctx.myRow = session and myRow(session) or nil
	PlayGolf.update(dt, ctx)
	PlayRange.update(dt, ctx)
	PlayCritters.update(dt, ctx)
end

-- Keyboard: Backspace resets (Regatta, Gauntlet).
local function onReset(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local session = mySession()
	if session and (session.game == "regatta" or session.game == "gauntlet") and session.state == "running" then
		playRemote:FireServer("reset")
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function PlayHud.start(hudModule, fade)
	hud = hudModule
	PlayHud.fade = fade
	build()
	buildVenueSigns()
	ctx = { hud = hud, remote = playRemote, sessions = sessions, lives = lives }
	PlayGolf.start(ctx)
	PlayRange.start(ctx)
	PlayCritters.start(ctx)
	task.spawn(function()
		folder = ReplicatedStorage:WaitForChild("LootGoblinsPlay", 60)
		if not folder then
			return
		end
		for _, value in ipairs(folder:GetChildren()) do
			watch(value)
		end
		folder.ChildAdded:Connect(watch)
		folder.ChildRemoved:Connect(function(value)
			local name = value.Name
			if string.sub(name, -5) == ".live" then
				lives[string.sub(name, 1, -6)] = nil
			else
				sessions[name] = nil
			end
		end)
	end)
	ContextActionService:BindActionAtPriority("LootGoblinsPlayReset", onReset, false, 3000, Enum.KeyCode.Backspace)
	RunService.RenderStepped:Connect(update)
	player:GetAttributeChangedSignal("PlaySession"):Connect(function()
		if player:GetAttribute("PlaySession") then
			closeResult()
			Effects.chime({ 1, 1.26, 1.5 }, 0.5)
		end
	end)
end

-- For the challenge client: the challenge a rematch is for.
PlayHud.lastChallenge = nil

-- Is this goblin in a Port game right now? (The Port screen steps aside.)
function PlayHud.playing()
	return player:GetAttribute("PlaySession") ~= nil
end

return PlayHud

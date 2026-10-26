-- The Port's games on this client (V13.3). Everything here is drawn from what the server publishes
-- (ReplicatedStorage.LootGoblinsPlay: one JSON StringValue per session, and a fast `.live` one for games that move a
-- lot) and from shared/PortGames.lua; this client only ever sends intent (PlayRequest: "leave", "again", a game's
-- own input). The golf tee's aim and power and its chase camera live beside it in client/PlayGolf.lua. (V13.5 removed
-- PlayRange.lua and PlayCritters.lua with the Toss, the Gallery, the Derby and Crab Chaos.)
--
--   VENUE SIGNS  over each venue, what it is doing now: E TO PLAY, STARTING IN 5 (2 in), RACE ON, how many are waiting.
--   THE PANEL    while you play: the game, a big 3-2-1-GO, the clock (time games count up; golf shows your score
--                against par), your progress (a checkpoint, a platform, a hole and its shot), the leaders, LEAVE and
--                RESET. If you are signed up for the raid, a red warning before it leaves (it ends your game).
--   THE BOATS    (V13.5) in a Regatta lobby, every boat to race in: the Racing Tub or a test drive in any class.
--   MARKERS      the next checkpoint (Regatta), platform (Gauntlet) or pin (Golf), pointed at from wherever you are.
--   RESULTS      your score, place and medal, a new best, the Shinies (and the day's cap), AGAIN or REMATCH; a Regatta
--                lap's boat and the week's record in it, a golf round's card.
--   THE DOCK     (V13.5) the start lights over the Regatta's line, and the week's class records board.
-- The raid HUD steps aside in the Port; at the wheel of a Regatta boat its boat panel comes back (client/Hud.lua).
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local PlayGolf = require(script.Parent.PlayGolf)

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
local readyButton, callout -- V13.4: START NOW in a lobby; the flash under the panel (splits, places, a new best)
local picker, pickerButtons = nil, {} -- V13.5: the Regatta lobby's boats
local openShop -- V13.5: (focus) opens the wardrobe (the results card's SHOWROOM)
local resultCard
-- V13.4: this run as it goes (checkpoint times, place, whether the best is beaten yet), and the checkpoint times of
-- this visit's best run per time game (so a split says how you are doing against it).
local run = { session = nil, cp = 0, splits = {}, pos = nil, beaten = false }
local bestSplits = {} -- gameId -> { [checkpoint] = seconds }
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
	elseif def and def.kind == "strokes" then
		return string.format("%d strokes", math.floor(score + 0.5))
	end
	return tostring(math.floor(score + 0.5)) .. " pts"
end
PlayHud.scoreText = scoreText

-- V13.5: the boats a Regatta can be raced in (the Racing Tub, then every class), and their names.
local BOATS = { "racer" }
for _, row in ipairs(Config.BOAT_CLASSES) do
	table.insert(BOATS, row.id)
end
local function boatName(class)
	local spec = Config.BOAT_TYPES[class or "racer"]
	return spec and spec.name or "Racing Tub"
end
PlayHud.boatName = boatName

local function ownsBoat(class)
	if class == "racer" then
		return true
	end
	local item = Catalog.get("boat_" .. class)
	if item and Catalog.isFree(item) then
		return true
	end
	return string.find("," .. (player:GetAttribute("Owned") or "") .. ",", ",boat_" .. class .. ",", 1, true) ~= nil
end

-- The week's class records (server/Leaderboards.lua publishes them): class -> { s, n }.
local function classRecords()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, workspace:GetAttribute("RegattaRecords") or "{}")
	return ok and type(data) == "table" and type(data.laps) == "table" and data.laps or {}
end

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
	readyButton = Ui.button(buttons, {
		text = "▶ START NOW",
		style = "good",
		size = UDim2.fromOffset(150, 36),
		textSize = 16,
		order = 0,
		name = "StartNow",
	}, function()
		playRemote:FireServer("ready")
		Effects.chime({ 1, 1.5 }, 0.4)
	end)
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
	callout = Ui.label(root, {
		Name = "PlayCallout",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(360, 40),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 30,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.stroke(callout, C.night, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	-- V13.5: the Regatta lobby's boats. The tub is everyone's same boat (the board's race); any class is a test drive.
	picker = Ui.make("Frame", {
		Name = "BoatPicker",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(724, 108),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, root)
	Ui.corner(picker, 14)
	Ui.stroke(picker, GOLD, 2)
	Ui.label(picker, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "YOUR BOAT: the RACING TUB races for the board · any other is a TEST DRIVE (yours or not, free)",
		Font = Ui.BOLD,
		TextSize = 13,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local grid = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 28),
		Size = UDim2.new(1, -16, 1, -34),
		BackgroundTransparency = 1,
	}, picker)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(114, 34),
		CellPadding = UDim2.fromOffset(4, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, class in ipairs(BOATS) do
		pickerButtons[class] = Ui.button(grid, {
			text = boatName(class),
			style = class == "racer" and "good" or "wood",
			size = UDim2.fromOffset(114, 34),
			textSize = 13,
			order = i,
			name = class,
		}, function()
			playRemote:FireServer("choose", "regatta", class)
			Effects.chime({ 1.26 }, 0.35)
		end)
	end
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
local function progressLine(def, _session, row, _t)
	local x = row and row.x
	if def.id == "regatta" and type(x) == "table" then
		return string.format(
			"%s  ·  CHECKPOINT %d/%d%s",
			string.upper(boatName(x.boat)),
			x.cp or 0,
			x.of or #PortGames.REGATTA.checkpoints,
			x.pos and ("  ·  " .. ordinal(x.pos)) or ""
		)
	elseif def.id == "gauntlet" and type(x) == "table" then
		local falls = x.falls or 0
		return string.format(
			"PLATFORM %d/%d%s",
			x.cp or 0,
			x.of or 8,
			falls > 0 and string.format("  ·  %d splash%s", falls, falls > 1 and "es" or "") or ""
		)
	elseif def.id == "golf" and type(x) == "table" then
		-- V13.5: the hole, its par, the shot, and the card so far.
		local card = {}
		for _, strokes in ipairs(x.card or {}) do
			table.insert(card, tostring(strokes))
		end
		return string.format(
			"HOLE %d/%d  ·  PAR %d  ·  SHOT %d/%d%s",
			x.hole or 1,
			x.of or #PortGames.GOLF.holes,
			x.par or 2,
			x.shot or 1,
			x.max or 3,
			#card > 0 and ("  ·  card " .. table.concat(card, " ")) or ""
		)
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

-- V13.4: a short flash under the panel (a split, a place gained, a best beaten). The newest replaces the last.
local flashToken = 0
local function flash(text, color, seconds)
	flashToken += 1
	local mine = flashToken
	callout.Text = text
	callout.TextColor3 = color or C.white
	callout.Visible = true
	local scale = callout:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", {}, callout)
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds or 1.4, function()
		if flashToken == mine then
			callout.Visible = false
		end
	end)
end
PlayHud.flash = flash

-- V13.4: what this run is doing, frame to frame: a new checkpoint (a chime and the split against this visit's best
-- run), a place gained in the Regatta, the moment a points game passes your best.
local function track(session, def, row, t)
	if run.session ~= session.id then
		run = { session = session.id, cp = 0, splits = {}, pos = nil, beaten = false }
	end
	local was = run.state
	run.state = session.state
	if session.state == "running" and was == "countdown" then
		if not run.launched then
			local early = run.early
			flash(early and "WHEELSPIN! TOO EARLY" or "GO!", early and Color3.fromRGB(255, 140, 110) or GOLD, 0.9)
		end
		Effects.chime({ 1.5, 2 }, 0.6)
	end
	if def.id == "regatta" and (session.state == "countdown" or session.state == "running") then
		-- The ROCKET START: throttle down within a moment of GO, not held through the countdown.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local throttle = seat and seat:IsA("VehicleSeat") and seat.ThrottleFloat > 0.5
		local toGo = (session.goAt or t) - t
		if throttle and toGo > 0.25 and toGo < 1.2 then
			run.early = true
		elseif throttle and not run.early and not run.launched and toGo <= 0.25 and toGo >= -0.1 then
			run.launched = true
			task.delay(math.max(0, toGo) + 0.05, function()
				playRemote:FireServer("launch")
			end)
			task.delay(math.max(0, toGo), function()
				flash("🚀 ROCKET START!", GOLD, 1.2)
				Effects.sound("whoosh", { speed = 1.2, volume = 0.7 })
			end)
		end
	end
	if session.state ~= "running" or not row then
		return
	end
	local x = type(row.x) == "table" and row.x or nil
	if x and x.cp and x.cp > run.cp and (def.id == "regatta" or def.id == "gauntlet") then
		run.cp = x.cp
		local elapsed = t - (session.goAt or t)
		run.splits[x.cp] = elapsed
		local ref = bestSplits[def.id] and bestSplits[def.id][x.cp]
		if ref and not row.d then
			local delta = elapsed - ref
			flash(
				string.format("%s%.2f", delta <= 0 and "-" or "+", math.abs(delta)),
				delta <= 0 and Color3.fromRGB(120, 240, 120) or Color3.fromRGB(255, 120, 100),
				1.3
			)
		end
		Effects.chime({ 1.26, 1.5 }, 0.45)
	end
	if def.id == "regatta" and x and x.pos then
		if run.pos and x.pos < run.pos then
			flash("▲ " .. string.upper(ordinal(x.pos)), GOLD, 1.2)
			Effects.chime({ 1.5, 2 }, 0.4)
		end
		run.pos = x.pos
	end
	if def.kind == "points" and row.b and row.s and row.s > row.b and not run.beaten then
		run.beaten = true
		flash("★ NEW BEST!", GOLD, 1.6)
		Effects.chime(Effects.CHIME_GOOD, 0.6)
	end
end

-- A finished time run: if it beat this visit's best, its checkpoint times become the ones to beat.
local function keepSplits(def, score)
	if def.kind ~= "time" or score == nil or next(run.splits) == nil then
		return
	end
	local mine = bestSplits[def.id]
	if not mine or score < (mine.total or math.huge) then
		local copy = table.clone(run.splits)
		copy.total = score
		bestSplits[def.id] = copy
	end
end

-- V13.5: the Gauntlet's hooks for the leg ahead glow, so the way on reads at a glance (the rest stay gold metal).
local hookParts, nextHookLook, litLeg = nil, 0, nil
local function lightHooks(leg)
	if not hookParts and os.clock() >= nextHookLook then
		nextHookLook = os.clock() + 2
		local found = {}
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		for _, d in ipairs(generated and generated:GetDescendants() or {}) do
			if d.Name == "GauntletHook" and d:IsA("BasePart") then
				for i, h in ipairs(PortGames.GAUNTLET.hooks) do
					if (d.Position - h.at).Magnitude < 1 then
						found[i] = d
					end
				end
			end
		end
		if next(found) then
			hookParts = found
		end
	end
	if not hookParts or leg == litLeg then
		return
	end
	litLeg = leg
	for i, part in pairs(hookParts) do
		local on = PortGames.GAUNTLET.hooks[i].leg == leg
		part.Material = on and Enum.Material.Neon or Enum.Material.Metal
		part.Color = on and Color3.fromRGB(255, 240, 150) or Color3.fromRGB(255, 205, 70)
	end
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
		picker.Visible = false
		lightHooks(nil)
		return
	end
	local def = PortGames.BY_ID[session.game]
	local row = myRow(session)
	track(session, def, row, t)
	panel.Visible = true
	buttons.Visible = session.state ~= "results"
	resetButton.Visible = (def.id == "regatta" or def.id == "gauntlet") and session.state == "running"
	readyButton.Visible = session.state == "lobby"
	-- V13.5: the Regatta lobby's boats, the chosen one lit, the ones you do not own marked as a test drive.
	picker.Visible = def.id == "regatta" and session.state == "lobby"
	if picker.Visible then
		local chosen = row and row.o or "racer"
		for class, button in pairs(pickerButtons) do
			local mine = class == chosen
			button.Text = (mine and "✔ " or "")
				.. boatName(class)
				.. ((class ~= "racer" and not ownsBoat(class)) and " ·TEST" or "")
			button.BackgroundColor3 = mine and C.gold or (class == "racer" and C.good or C.woodMid)
			button.TextColor3 = mine and C.ink or (class == "racer" and C.white or C.parchment)
		end
	end
	if session.state == "lobby" then
		local ready, count = 0, 0
		for _, other in ipairs(session.players or {}) do
			count += 1
			ready += other.r and 1 or 0
		end
		readyButton.Text = (row and row.r) and string.format("✔ READY %d/%d", ready, count) or "▶ START NOW"
	end
	-- The score to beat (your best before this heat), beside the game's name.
	local best = row and row.b
	title.Text = def.icon
		.. "  "
		.. string.upper(def.name)
		.. (session.challenge and "  ·  CHALLENGE" or "")
		.. (best and ("  ·  BEST " .. scoreText(def, best)) or "")
	if session.state == "lobby" or session.state == "waiting" then
		local left = math.max(0, (session.lobbyEndsAt or t) - t)
		big.Text = session.state == "waiting" and "WAITING FOR THE VENUE" or ("STARTING IN " .. math.ceil(left))
		big.TextSize = 28
		sub.Text = def.hint
	elseif session.state == "countdown" then
		local left = (session.goAt or t) - t
		local shown = left > 0 and tostring(math.ceil(left)) or "GO!"
		if shown ~= big.Text and left > 0 then
			Effects.chime({ 1 }, 0.35) -- a tick for 3, 2, 1 (GO is track's)
		end
		big.Text = shown
		big.TextSize = 46
		sub.Text = def.id == "regatta" and "🚀 Throttle (W) right on GO: a rocket start!" or def.hint
	elseif session.state == "running" then
		big.TextSize = 38
		local x = row and type(row.x) == "table" and row.x or nil
		if def.kind == "time" then
			big.Text = row and row.d and row.s and string.format("%.2f s", row.s)
				or clock(t - (session.goAt or t), true)
		elseif def.kind == "strokes" then
			-- V13.5: golf's score is against the par of the holes played so far.
			local toPar = x and (x.played or 0) > 0 and PortGames.toPar(x.total or 0, x.played) or "E"
			big.Text = string.format("%s   %s", toPar, clock((session.endsAt or t) - t))
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
			lightHooks(x.cp or 0)
		elseif def.id == "golf" then
			local hole = PortGames.GOLF.holes[x.hole or 1]
			target = hole and (hole.center + Vector3.new(0, 20, 0))
			markerLabel.Text = hole and string.format("▼ %d · PAR %d", x.hole or 1, hole.par) or ""
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
	ContextActionService:UnbindAction("LootGoblinsPlayAgain")
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
	if p.place and (p.players or 1) >= 2 then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = ordinal(p.place) .. " of " .. tostring(p.players),
			Font = Ui.TITLE,
			TextSize = 18,
			TextColor3 = p.place == 1 and C.goldDeep or C.ink,
			LayoutOrder = 3,
		})
	end
	if p.session == run.session then
		keepSplits(def, p.counted and p.score or nil)
	end
	-- V13.4: how close it came. A best by how much; otherwise how far off, so AGAIN has a target.
	local gap = (p.counted and p.score and b.previous) and (p.score - b.previous) or nil
	local versus
	if b.best and gap then
		versus = string.format(
			"★ NEW BEST!  %s",
			def.kind == "time" and string.format("-%.2f s", math.abs(gap))
				or def.kind == "strokes" and string.format("-%d", math.floor(math.abs(gap) + 0.5))
				or string.format("+%d", math.floor(gap + 0.5))
		)
	elseif b.first then
		versus = "First score here: now beat it!"
	elseif gap then
		if def.kind == "time" then
			versus = string.format("+%.2f s off your best (%s)", gap, scoreText(def, b.previous))
		elseif def.kind == "strokes" then
			versus = string.format("%d over your best (%s)", math.floor(gap + 0.5), scoreText(def, b.previous))
		else
			versus = string.format("%d short of your best (%s)", math.floor(-gap + 0.5), scoreText(def, b.previous))
		end
		if gap == 0 then
			versus = "Equal to your best!"
		end
	end
	if versus then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = versus,
			Font = b.best and Ui.TITLE or Ui.BOLD,
			TextSize = b.best and 18 or 14,
			TextColor3 = b.best and C.goldDeep or C.inkSoft,
			LayoutOrder = 4,
		})
	end
	-- The next medal up, when there is one to chase.
	local ladder = G[string.upper(def.id)] and G[string.upper(def.id)].MEDALS
	local chase
	for _, name in ipairs({ "bronze", "silver", "gold" }) do
		if ladder and ladder[name] and not chase then
			local has = b.medal and table.find({ "bronze", "silver", "gold" }, b.medal) or 0
			if table.find({ "bronze", "silver", "gold" }, name) > has then
				chase = name
			end
		end
	end
	if chase then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 18),
			Text = string.format("%s %s at %s", MEDAL[chase], string.upper(chase), scoreText(def, ladder[chase])),
			Font = Ui.BOLD,
			TextSize = 13,
			TextColor3 = C.inkSoft,
			LayoutOrder = 5,
		})
	end
	-- V13.5: what this run was in, and what it is measured against.
	local extra
	local session = sessions[p.session]
	local mine = session and myRow(session)
	if def.id == "regatta" then
		local class = b.class or (mine and mine.o) or "racer"
		local record = classRecords()[class]
		extra = string.format(
			"%s%s",
			class == "racer" and "Racing Tub (the board's race)" or ("Test drive: " .. boatName(class)),
			record and string.format("  ·  week's record %.2f s (%s)", record.s, record.n or "?")
				or "  ·  no record yet this week!"
		)
	elseif def.id == "golf" and mine and type(mine.x) == "table" and mine.x.card then
		local cells = {}
		for i, strokes in ipairs(mine.x.card) do
			table.insert(cells, string.format("%d:%d", i, strokes))
		end
		extra = string.format(
			"%s  ·  %s against par %d",
			table.concat(cells, "  "),
			PortGames.toPar(mine.x.total or 0, PortGames.GOLF.par),
			PortGames.GOLF.par
		)
	end
	if extra then
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 30),
			Text = extra,
			Font = Ui.BOLD,
			TextSize = 13,
			TextColor3 = C.ink,
			TextWrapped = true,
			LayoutOrder = 5,
		})
	end
	local row = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 6 }, card)
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
	local function playAgain()
		if p.challenge then
			challengeRemote:FireServer("rematch", PlayHud.lastChallenge)
			hud.toast("Rematch asked: waiting for them to press it too...")
		else
			playRemote:FireServer("again", p.game)
		end
		closeResult()
	end
	local again = Ui.button(actions, {
		text = p.challenge and "⚔ REMATCH  (R)" or "▶ AGAIN  (R)",
		size = UDim2.new(0.6, -4, 1, 0),
		textSize = 17,
		name = "PlayAgain",
	}, playAgain)
	-- V13.4: R (or Y on a controller) plays again without reaching for the mouse.
	ContextActionService:BindActionAtPriority("LootGoblinsPlayAgain", function(_, state)
		if state == Enum.UserInputState.Begin and resultCard then
			playAgain()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	-- V13.5: a test drive in a boat you do not own: the showroom is one press away.
	local tested = def.id == "regatta" and (b.class or (mine and mine.o))
	if tested and tested ~= "racer" and not ownsBoat(tested) and openShop then
		Ui.button(actions, {
			text = "🛒 SHOWROOM",
			style = "good",
			size = UDim2.new(0.4, -4, 1, 0),
			position = UDim2.new(0.6, 4, 0, 0),
			textSize = 15,
			name = "Showroom",
		}, function()
			closeResult()
			openShop("boat:" .. tested)
		end)
	else
		Ui.button(actions, {
			text = "CLOSE",
			style = "ghost",
			size = UDim2.new(0.4, -4, 1, 0),
			position = UDim2.new(0.6, 4, 0, 0),
			textSize = 17,
		}, closeResult)
	end
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
	if PlayGolf.fx(p) then
		return
	end
	if kind == "splash" and p.position then
		Effects.spray(p.position, 1.6)
		Effects.ring(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(190, 240, 255), (p.radius or 20) + 10, 0.8)
		Effects.sound("splash", { position = p.position, speed = 0.8, volume = 1, range = 500 })
		Effects.sound("boom", { position = p.position, speed = 1.4, volume = 0.5, range = 500 })
	elseif kind == "finish" and p.position then
		-- V13.5: a finish worth crossing: fireworks over the line, a wash of spray, and the place called.
		Effects.firework(p.position + Vector3.new(0, 18, 0), GOLD)
		Effects.firework(p.position + Vector3.new(14, 22, 0), Color3.fromRGB(255, 96, 170))
		Effects.firework(p.position + Vector3.new(-14, 22, 0), Color3.fromRGB(90, 200, 255))
		Effects.splashColumn(p.position, 16, 8)
		Effects.sound("rise", { position = p.position, speed = 1.3, volume = 0.9, range = 600 })
		if p.userId == player.UserId then
			local session = mySession()
			local mine = session and myRow(session)
			local place = mine and type(mine.x) == "table" and mine.x.pos
			hud.banner(place == 1 and "🏆 FIRST ACROSS THE LINE!" or "FINISHED!", GOLD, 2.5, 3)
			Effects.chime(place == 1 and { 1, 1.26, 1.5, 2, 2.5 } or Effects.CHIME_GOOD, 0.7)
		end
	elseif kind == "gate" and p.position then
		-- V13.5: a Regatta checkpoint passed (only the racer who passed it is told).
		Effects.ring(p.position + Vector3.new(0, 1, 0), p.shortcut and Color3.fromRGB(150, 230, 255) or GOLD, 30, 0.6)
		if p.shortcut then
			flash("⚡ THROUGH THE TEETH!", Color3.fromRGB(150, 230, 255), 1.4)
			Effects.chime({ 1.5, 2, 2.5 }, 0.5)
		end
	elseif kind == "bell" and p.position then
		Effects.ring(p.position, GOLD, 18, 0.6)
		Effects.sound("blip", { position = p.position, speed = 0.5, volume = 1, range = 500 })
		Effects.firework(p.position + Vector3.new(0, 12, 0), GOLD)
		if p.userId == player.UserId then
			hud.banner("DING! RUN COMPLETE!", GOLD, 2.5, 3)
		end
	elseif kind == "hallcheer" and p.position then
		-- V13.4: someone climbed into a raid board's top three: the Hall of Legends celebrates.
		Effects.firework(p.position, GOLD)
		Effects.firework(p.position + Vector3.new(10, 4, 0), Color3.fromRGB(200, 140, 255))
		Effects.firework(p.position + Vector3.new(-10, 4, 0), Color3.fromRGB(150, 230, 255))
		Effects.sound("rise", { position = p.position, speed = 1.1, volume = 0.8, range = 600 })
	elseif kind == "checkpoint" and p.shortcut then
		flash(
			(p.skipped or 1) > 1 and string.format("⚡ SHORTCUT! %d PLATFORMS", p.skipped) or "⚡ SHORTCUT!",
			Color3.fromRGB(150, 230, 255),
			1.4
		)
		Effects.chime({ 1.5, 2, 2.5 }, 0.5)
	elseif kind == "fall" then
		hud.toast("Splash! Back on your last platform, facing the next (the clock runs on).")
		if p.position then
			Effects.ring(p.position - Vector3.new(0, 3, 0), Color3.fromRGB(255, 205, 70), 8, 0.5)
			Effects.burst(p.position, Color3.fromRGB(255, 240, 160), 20, 14)
		end
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
	PlayHud.updateDock(t)
end

-- V13.5: the Regatta's start lights (three red at 3, 2, 1, all green at GO, from the heat's own clock: every client
-- lights them the same) and the week's class records board on the dock.
local lights, recordsBoard, nextLook, recordsText = {}, nil, 0, nil
local LIGHT_OFF, LIGHT_RED, LIGHT_GREEN =
	Color3.fromRGB(40, 36, 44), Color3.fromRGB(255, 60, 50), Color3.fromRGB(80, 255, 110)
function PlayHud.updateDock(t)
	if os.clock() >= nextLook and (#lights < 4 or not recordsBoard) then
		nextLook = os.clock() + 2
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		if generated then
			for _, d in ipairs(generated:GetDescendants()) do
				local index = d:GetAttribute("StartLight")
				if index then
					lights[index] = d
				elseif d.Name == "RegattaRecordsBoard" then
					recordsBoard = d
				end
			end
		end
	end
	if #lights == 4 then
		local heat
		for _, session in pairs(sessions) do
			if session.game == "regatta" and (session.state == "countdown" or session.state == "running") then
				heat = session
			end
		end
		local toGo = heat and heat.goAt and heat.goAt - t
		for i, lamp in ipairs(lights) do
			local color, lit = LIGHT_OFF, false
			if toGo and toGo > 0 and i <= 3 and toGo <= 4 - i then
				color, lit = LIGHT_RED, true
			elseif toGo and toGo <= 0 and toGo > -1.5 then
				color, lit = LIGHT_GREEN, true
			end
			if lamp.Parent and lamp.Color ~= color then
				lamp.Color = color
				lamp.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
	if recordsBoard and recordsBoard.Parent then
		local laps = classRecords()
		local lines = { "CLASS RECORDS · THIS WEEK" }
		for _, class in ipairs(BOATS) do
			local row = laps[class]
			table.insert(
				lines,
				string.format(
					"%s  %s",
					boatName(class),
					row and string.format("%.2f s  %s", row.s, row.n or "?") or "·  open!"
				)
			)
		end
		local text = table.concat(lines, "\n")
		if text ~= recordsText then
			recordsText = text
			for _, face in ipairs(recordsBoard:GetChildren()) do
				local label = face:IsA("SurfaceGui") and face:FindFirstChild("Text")
				if label then
					label.Text = text
					label.TextXAlignment = Enum.TextXAlignment.Left
				end
			end
		end
	end
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

function PlayHud.start(hudModule, fade, shop)
	hud = hudModule
	PlayHud.fade = fade
	openShop = shop
	build()
	buildVenueSigns()
	ctx = { hud = hud, remote = playRemote, sessions = sessions, lives = lives }
	PlayGolf.start(ctx)
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

-- V13.5: you set the week's record in a boat (server/Leaderboards.lua).
function PlayHud.classRecord(p)
	flash(string.format("🏆 WEEK'S %s RECORD!", string.upper(boatName(p.class))), GOLD, 2.2)
	Effects.chime({ 1, 1.26, 1.5, 2, 2.5 }, 0.8)
end

-- For the challenge client: the challenge a rematch is for.
PlayHud.lastChallenge = nil

-- Is this goblin in a Port game right now? (The Port screen steps aside.)
function PlayHud.playing()
	return player:GetAttribute("PlaySession") ~= nil
end

return PlayHud

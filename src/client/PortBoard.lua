-- The Captain's Quest Board and the Hall of Records on this client (V13.3).
--
--   THE PANEL   opened at the Quest Board (E), from the Port screen's 📜 chip, or by a quest toast: QUESTS (today's
--               three and the week's three, with progress, CLAIM, and the time to the reset) and SEASON (your best on
--               every board this week or month, your place if you are in the top hundred, the tier you have reached
--               and the next, and how long the period has left). Closing it: X, the CLOSE button, B on a controller.
--   THE BOARDS  every client writes the physical boards itself: the Quest Board shows today's quests with this
--               goblin's own progress; each Hall of Records board shows its top ten (friends starred), the goblins in
--               this Port and their bests, last period's champions, and this goblin's own line.
--   TELLING     a finished quest, a rollover's payment, a season reward, a new best on a board.
-- Everything shown comes from attributes the server keeps (the player's Quests and Season, workspace Board_<id>); the
-- only thing this sends is a claim (ShopRequest "questclaim").
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local PortBoard = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local shopRemote = remotes:WaitForChild("ShopRequest")
local C = Ui.C
local rgb = Color3.fromRGB

local hud
local gui, window, body, tabButtons, page = nil, nil, nil, {}, "quests"
local rewardQueue, rewardShowing = {}, false
local friends = {} -- userId -> true / false (asked once)

local function now()
	return workspace:GetServerTimeNow()
end

local function decode(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	return ok and data or nil
end

local function left(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

local function isFriend(userId)
	if userId == player.UserId then
		return false
	end
	local known = friends[userId]
	if known == nil then
		friends[userId] = false
		task.spawn(function()
			local ok, result = pcall(function()
				return player:IsFriendsWith(userId)
			end)
			friends[userId] = ok and result == true
		end)
		return false
	end
	return known
end

local function fmt(board, score)
	if score == nil then
		return "-"
	end
	if board.unit == "time" then
		return string.format("%.2f s", score)
	end
	return string.format("%d %s", math.floor(score + 0.5), board.unit == "gold" and "gold" or "pts")
end

-- The panel ----------------------------------------------------------------------------------------------------------------
local function clear(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function heading(parent, text, order, color)
	return Ui.label(parent, {
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		Font = Ui.TITLE,
		TextSize = 18,
		TextColor3 = color or C.ink,
		LayoutOrder = order,
	})
end

local function questRow(parent, kind, q, order)
	local row = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = q.claimed and C.parchmentDark or C.white,
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
	}, parent)
	Ui.corner(row, 10)
	local done = q.n >= q.goal
	Ui.label(row, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -150, 0, 22),
		Text = (q.claimed and "✔ " or "") .. q.text,
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = q.claimed and C.inkSoft or C.ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local bar = Ui.make(
		"Frame",
		{ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -170, 0, 12), BackgroundColor3 = C.parchmentDark },
		row
	)
	Ui.corner(bar, 6)
	local fill = Ui.make(
		"Frame",
		{ Size = UDim2.fromScale(math.clamp(q.n / q.goal, 0, 1), 1), BackgroundColor3 = done and C.good or C.gold },
		bar
	)
	Ui.corner(fill, 6)
	Ui.label(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 26),
		Size = UDim2.fromOffset(60, 18),
		Text = string.format("%d/%d", q.n, q.goal),
		Font = Ui.BOLD,
		TextSize = 13,
		TextColor3 = C.inkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	if done and not q.claimed then
		Ui.button(row, {
			text = string.format("CLAIM +%d", q.shinies),
			style = "good",
			size = UDim2.fromOffset(126, 38),
			position = UDim2.new(1, -134, 0.5, -19),
			textSize = 15,
			name = "Claim",
		}, function()
			shopRemote:FireServer("questclaim", kind, q.i)
			Effects.chime(Effects.CHIME_GOOD, 0.6)
		end)
	else
		local label = Ui.label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 24),
			Text = q.claimed and "CLAIMED" or ("◆ " .. q.shinies),
			Font = Ui.TITLE,
			TextSize = 16,
			TextColor3 = q.claimed and C.inkSoft or C.goldDeep,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		if q.go and not q.claimed and PortGames.BY_ID[q.go] then
			label.Text = PortGames.BY_ID[q.go].icon .. "  ◆ " .. q.shinies
		end
	end
end

local function renderQuests()
	local view = decode(player:GetAttribute("Quests")) or { day = {}, week = {} }
	local t = now()
	heading(body, "TODAY  ·  new quests in " .. left(Seasons.secondsLeft("day", t)), 1)
	for i, q in ipairs(view.day or {}) do
		questRow(body, "day", q, 1 + i)
	end
	heading(body, "THIS WEEK  ·  new quests in " .. left(Seasons.secondsLeft("week", t)), 10)
	for i, q in ipairs(view.week or {}) do
		questRow(body, "week", q, 10 + i)
	end
	local week = Seasons.period("week", t)
	local prize = Catalog.get(Seasons.BUNDLE[week % #Seasons.BUNDLE + 1])
	Ui.label(body, {
		Size = UDim2.new(1, 0, 0, 36),
		Text = view.bundle and "★ This week's prize is yours!"
			or string.format("Claim all three weekly quests: this week's prize, the %s.", prize and prize.name or "?"),
		Font = Ui.BODY,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = C.inkSoft,
		LayoutOrder = 20,
	})
	Ui.label(body, {
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Finished quests you don't claim are paid at the reset: nothing is lost.",
		Font = Ui.BODY,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = C.inkSoft,
		LayoutOrder = 21,
	})
end

local TIER_COLOR = { gold = rgb(214, 160, 30), silver = rgb(150, 156, 170), bronze = rgb(176, 110, 60) }
local function renderSeason()
	local mine = decode(player:GetAttribute("Season")) or { best = {}, rank = {} }
	local t = now()
	for i, board in ipairs(Seasons.BOARDS) do
		local best = mine.best and mine.best[board.id]
		local rank = mine.rank and mine.rank[board.id]
		local tier = Seasons.tier(board, best)
		local nextTier
		for _, name in ipairs({ "bronze", "silver", "gold" }) do
			if not tier or (tier == "bronze" and name ~= "bronze") or (tier == "silver" and name == "gold") then
				nextTier = name
				break
			end
		end
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = C.white,
			BackgroundTransparency = 0.25,
			LayoutOrder = i,
		}, body)
		Ui.corner(row, 10)
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -24, 0, 20),
			Text = string.format(
				"%s  ·  %s  ·  ends in %s",
				board.name,
				board.period == "week" and "THIS WEEK" or "THIS MONTH",
				left(Seasons.secondsLeft(board.period, t))
			),
			Font = Ui.BOLD,
			TextSize = 14,
			TextColor3 = C.ink,
		})
		local line = "Your best: " .. fmt(board, best)
		if rank then
			line ..= string.format("   ·   #%d", rank)
		end
		if tier then
			line ..= "   ·   " .. string.upper(tier)
		end
		if nextTier and board.tiers[nextTier] then
			line ..= string.format("   ·   %s at %s", string.upper(nextTier), fmt(board, board.tiers[nextTier]))
		end
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -24, 0, 18),
			Text = line,
			Font = Ui.BODY,
			TextSize = 13,
			TextColor3 = tier and TIER_COLOR[tier] or C.inkSoft,
		})
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(1, -24, 0, 16),
			Text = board.sub,
			Font = Ui.BODY,
			TextSize = 12,
			TextColor3 = C.inkSoft,
		})
	end
	Ui.label(body, {
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Tiers are yours whoever else plays; places are paid after the period ends (next time you're here). "
			.. string.format("Trophies in your sanctuary: %d.", mine.trophies or 0),
		Font = Ui.BODY,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = C.inkSoft,
		LayoutOrder = 20,
	})
end

local function render()
	if not window or not window.Visible then
		return
	end
	clear(body)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	if page == "quests" then
		renderQuests()
	else
		renderSeason()
	end
	for name, button in pairs(tabButtons) do
		Ui.setStyle(button, name == page and "gold" or "wood")
	end
end

function PortBoard.open(which)
	page = which == "season" and "season" or "quests"
	window.Visible = true
	render()
	Ui.focus(tabButtons[page])
	Effects.sound("blip", { speed = 1.2, volume = 0.4 })
end

function PortBoard.close()
	if window.Visible then
		window.Visible = false
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(window) then
			GuiService.SelectedObject = nil
		end
	end
end

function PortBoard.isOpen()
	return window ~= nil and window.Visible
end

local function build()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsQuestBoard", ResetOnSpawn = false, DisplayOrder = 9 },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local scale = Ui.make("UIScale", {}, gui)
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.6, 1.1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	window = Ui.make("Frame", {
		Name = "QuestWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 520),
		BackgroundColor3 = C.wood,
		Visible = false,
	}, gui)
	Ui.corner(window, 18)
	Ui.stroke(window, C.goldDeep, 3)
	Ui.label(window, {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -36, 0, 30),
		Text = "📜 THE CAPTAIN'S QUEST BOARD",
		Font = Ui.TITLE,
		TextSize = 24,
		TextColor3 = C.goldPale,
	})
	Ui.button(window, {
		text = "X",
		style = "danger",
		size = UDim2.fromOffset(38, 34),
		position = UDim2.new(1, -50, 0, 10),
		textSize = 18,
		name = "CloseQuests",
	}, PortBoard.close)
	local tabs = Ui.make(
		"Frame",
		{ Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 36), BackgroundTransparency = 1 },
		window
	)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)
	tabButtons.quests = Ui.button(
		tabs,
		{ text = "QUESTS", size = UDim2.fromOffset(150, 34), textSize = 16, order = 1, name = "TabQuests" },
		function()
			page = "quests"
			render()
		end
	)
	tabButtons.season = Ui.button(tabs, {
		text = "SEASON",
		style = "wood",
		size = UDim2.fromOffset(150, 34),
		textSize = 16,
		order = 2,
		name = "TabSeason",
	}, function()
		page = "season"
		render()
	end)
	local paper = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 92),
		Size = UDim2.new(1, -28, 1, -106),
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window)
	Ui.corner(paper, 12)
	body = Ui.make("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.fromOffset(8, 8),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, paper)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not window.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.X) then
			PortBoard.close()
		end
	end)
	player:GetAttributeChangedSignal("Quests"):Connect(render)
	player:GetAttributeChangedSignal("Season"):Connect(render)
end

-- The physical boards ----------------------------------------------------------------------------------------------------------
local function faces(part)
	local list = {}
	for _, face in ipairs(part:GetChildren()) do
		if face:IsA("SurfaceGui") then
			table.insert(list, face)
		end
	end
	return list
end

-- Replace a board's single painted label with lines of text (once), and return the line labels per face.
local boardLines = {}
local function linesFor(part, count)
	local cached = boardLines[part]
	if cached then
		return cached
	end
	cached = {}
	for _, face in ipairs(faces(part)) do
		local old = face:FindFirstChild("Text")
		if old then
			old.Visible = false
		end
		local holder =
			Ui.make("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, face)
		Ui.pad(holder, 14, 10, 14, 10)
		Ui.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, holder)
		local labels = {}
		for i = 1, count do
			labels[i] = Ui.label(holder, {
				Size = UDim2.fromScale(1, 1 / count),
				Text = "",
				Font = Ui.TITLE,
				TextScaled = true,
				TextColor3 = C.parchment,
				LayoutOrder = i,
			})
			Ui.make("UITextSizeConstraint", { MaxTextSize = 34 }, labels[i])
		end
		table.insert(cached, labels)
	end
	boardLines[part] = cached
	return cached
end

local function writeLines(part, lines, colors)
	for _, labels in ipairs(linesFor(part, #lines)) do
		for i, label in ipairs(labels) do
			label.Text = lines[i] or ""
			label.TextColor3 = colors and colors[i] or C.parchment
		end
	end
end

local function portCore()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("PortCore")
end

local function writeQuestBoard()
	local core = portCore()
	local board = core and core:FindFirstChild("QuestBoard")
	if not board then
		return
	end
	local view = decode(player:GetAttribute("Quests")) or { day = {}, week = {} }
	local lines, colors = { "TODAY" }, { C.gold }
	for _, q in ipairs(view.day or {}) do
		table.insert(lines, string.format("%s %s  %d/%d", q.claimed and "✔" or "•", q.text, q.n, q.goal))
		table.insert(colors, q.claimed and rgb(150, 230, 130) or (q.n >= q.goal and C.goldPale or C.parchment))
	end
	table.insert(lines, "THIS WEEK")
	table.insert(colors, C.gold)
	for _, q in ipairs(view.week or {}) do
		table.insert(lines, string.format("%s %s  %d/%d", q.claimed and "✔" or "•", q.text, q.n, q.goal))
		table.insert(colors, q.claimed and rgb(150, 230, 130) or (q.n >= q.goal and C.goldPale or C.parchment))
	end
	while #lines < 8 do
		table.insert(lines, "")
	end
	writeLines(board, lines, colors)
end

local function writeHall()
	local core = portCore()
	if not core then
		return
	end
	local mine = decode(player:GetAttribute("Season")) or { best = {}, rank = {} }
	for _, board in ipairs(Seasons.BOARDS) do
		local part = core:FindFirstChild("Board_" .. board.id)
		if part then
			local data = decode(workspace:GetAttribute("Board_" .. board.id)) or { top = {} }
			local lines, colors = {}, {}
			for i = 1, 8 do
				local row = data.top and data.top[i]
				if row then
					local friend = isFriend(row.u)
					table.insert(
						lines,
						string.format("%d. %s%s  %s", i, friend and "★ " or "", row.n or "?", fmt(board, row.s))
					)
					table.insert(
						colors,
						row.u == player.UserId and C.goldPale or (friend and rgb(150, 230, 255) or C.parchment)
					)
				else
					table.insert(lines, i == 1 and "No scores yet: be the first!" or "")
					table.insert(colors, C.parchment)
				end
			end
			-- Goblins in this Port, and their best this period.
			local here = {}
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local season = decode(other:GetAttribute("Season"))
					local best = season and season.best and season.best[board.id]
					if best then
						table.insert(here, { name = other.DisplayName, best = best, friend = isFriend(other.UserId) })
					end
				end
			end
			table.sort(here, function(a, b)
				return Seasons.better(board, a.best, b.best)
			end)
			if here[1] then
				table.insert(
					lines,
					string.format(
						"HERE: %s%s %s",
						here[1].friend and "★ " or "",
						here[1].name,
						fmt(board, here[1].best)
					)
				)
				table.insert(colors, rgb(150, 230, 255))
			else
				table.insert(lines, "")
				table.insert(colors, C.parchment)
			end
			local best = mine.best and mine.best[board.id]
			local rank = mine.rank and mine.rank[board.id]
			table.insert(lines, "YOU: " .. fmt(board, best) .. (rank and string.format("  #%d", rank) or ""))
			table.insert(colors, C.gold)
			local last = data.last and data.last.top and data.last.top[1]
			table.insert(
				lines,
				last and string.format("LAST %s: %s", board.period == "week" and "WEEK" or "MONTH", last.n) or ""
			)
			table.insert(colors, rgb(255, 180, 230))
			writeLines(part, lines, colors)
		end
	end
end

-- Telling ---------------------------------------------------------------------------------------------------------------------
local function showNextReward()
	if rewardShowing or #rewardQueue == 0 then
		return
	end
	rewardShowing = true
	local p = table.remove(rewardQueue, 1)
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.1,
	}, gui)
	Ui.corner(card, 14)
	Ui.stroke(card, C.gold, 2)
	Ui.pad(card, 14, 10, 14, 10)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	local kind, index = Seasons.parse(p.key)
	local when = kind == "week" and "LAST WEEK" or (kind == "month" and "LAST MONTH" or "")
	local _ = index
	Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 22),
		Text = "🏆 " .. when .. ": " .. tostring(p.name),
		Font = Ui.TITLE,
		TextSize = 18,
		TextColor3 = C.goldPale,
		LayoutOrder = 1,
	})
	local parts = {}
	if p.tier then
		table.insert(parts, string.upper(p.tier))
	end
	if p.rank then
		table.insert(parts, "#" .. p.rank)
	end
	table.insert(parts, "+" .. tostring(p.shinies or 0) .. " Shinies")
	Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 26),
		Text = table.concat(parts, "   ·   "),
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.white,
		LayoutOrder = 2,
	})
	for i, name in ipairs(p.items or {}) do
		Ui.label(card, {
			Size = UDim2.new(1, 0, 0, 20),
			Text = "★ " .. name .. " (in your locker)",
			Font = Ui.BOLD,
			TextSize = 15,
			TextColor3 = rgb(255, 180, 140),
			LayoutOrder = 2 + i,
		})
	end
	Effects.chime({ 1, 1.26, 1.5, 2, 2.5 }, 0.8)
	task.delay(7, function()
		local fadeOut = TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		fadeOut:Play()
		task.wait(0.4)
		card:Destroy()
		rewardShowing = false
		showNextReward()
	end)
end

function PortBoard.seasonReward(p)
	table.insert(rewardQueue, p)
	showNextReward()
end

function PortBoard.questDone(p)
	hud.banner(
		string.format("QUEST DONE: %s  ·  claim +%d at the Quest Board", p.text or "", p.shinies or 0),
		C.gold,
		3.5,
		3
	)
	Effects.chime(Effects.CHIME_GOOD, 0.7)
end

function PortBoard.rollover(p)
	if (p.shinies or 0) > 0 then
		hud.toast(string.format("New quests! Your %d finished one(s) were paid: +%d Shinies.", p.count or 0, p.shinies))
	end
	if p.itemName then
		hud.banner("THIS WEEK'S PRIZE: " .. string.upper(p.itemName) .. "!", C.gold, 4, 3)
	end
end

function PortBoard.best(p)
	local board = Seasons.BOARD_BY_ID[p.board]
	if board then
		hud.toast(string.format("New best on %s: %s", board.name, fmt(board, p.score)))
	end
end

function PortBoard.start(hudModule)
	hud = hudModule
	build()
	local nextWrite = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t < nextWrite then
			return
		end
		nextWrite = t + 2
		if player:GetAttribute("Zone") == "raid" then
			return
		end
		writeQuestBoard()
		writeHall()
	end)
	player:GetAttributeChangedSignal("Quests"):Connect(writeQuestBoard)
	local _ = Config
end

return PortBoard

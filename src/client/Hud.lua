-- The HUD. Everything it shows comes from replicated attributes (raid timer,
-- Heat, where each loot is, your cooldowns and stamina) plus one-off GameEvents
-- (banner, feed, toasts). Placement keeps clear of Roblox's own chat (top left),
-- player list (top right) and tool hotbar (bottom middle).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Map = require(script.Parent.Map)

local Hud = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(16, 16, 22)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 50)
local SPIRIT = Color3.fromRGB(120, 255, 170)
local WARD = Color3.fromRGB(190, 110, 255)
local STAMINA = Color3.fromRGB(120, 220, 255)
local WINDED = Color3.fromRGB(255, 90, 80)

local gui, scale
local timer, heatFill, heatLabel, heatHint, banner, feedList, board, objective, toast, flash
local results, resultsTitle, resultsList, resultsFooter, help
local slots = {}
local boardRows = {}
local boatPanel, boatSpeed, boatHull, boatHullFill, boatBoost, boatBoostFill, boatNote
local waypoint, waypointLabel
local hoardPart
local shownHeat = 0
local shownStamina = Config.STAMINA_MAX
local bannerToken, toastToken, hintToken = 0, 0, 0

-- Construction helpers ---------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function text(parent, props)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	for key, value in pairs(props) do
		label[key] = value
	end
	return label
end

local function panel(parent, props)
	local frame = make("Frame", {
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, parent)
	for key, value in pairs(props) do
		frame[key] = value
	end
	corner(frame)
	return frame
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Build ------------------------------------------------------------------------------
local function buildTop()
	local top = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(380, 84),
		BackgroundTransparency = 1,
	}, gui)
	local timerBack = panel(top, { Size = UDim2.fromOffset(380, 34) })
	timer = text(timerBack, { Font = Enum.Font.GothamBlack, Text = "RAID" })

	local heatBack = panel(top, { Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(380, 22) })
	heatBack.ClipsDescendants = true
	heatFill = make("Frame", {
		BackgroundColor3 = Config.HEAT_TIERS[1].color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, heatBack)
	corner(heatFill)
	for i = 2, #Config.HEAT_TIERS do
		make("Frame", {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(Config.HEAT_TIERS[i].at / Config.HEAT_MAX, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 2,
		}, heatBack)
	end
	heatLabel = text(heatBack, { Text = "HEAT  CALM", ZIndex = 3, TextStrokeTransparency = 0.2 })
	heatHint = text(top, {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.fromOffset(380, 18),
		Font = Enum.Font.GothamMedium,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
end

local function buildBanner()
	banner = text(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(780, 46),
		Font = Enum.Font.GothamBlack,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	corner(banner)
end

local function buildFeed()
	local feed = make("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 0.74, 0),
		Size = UDim2.fromOffset(400, 190),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, feed)
	feedList = feed
end

local BOARD_ROW = 21

local function buildBoard()
	local rowsCount = #Config.LOOT
	board = panel(gui, {
		Name = "LootBoard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.46, 0),
		Size = UDim2.fromOffset(300, 26 + rowsCount * BOARD_ROW),
	})
	text(board, {
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "TREASURE  (gold value)",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Highest value first: the board reads like the map, deepest at the top.
	local sorted = table.clone(Config.LOOT)
	table.sort(sorted, function(a, b)
		return a.value > b.value
	end)
	for i, def in ipairs(sorted) do
		local row = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 24 + (i - 1) * BOARD_ROW),
			Size = UDim2.new(1, -16, 0, BOARD_ROW - 1),
		}, board)
		local dot = make("Frame", {
			BackgroundColor3 = def.color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 5),
			Size = UDim2.fromOffset(10, 10),
		}, row)
		corner(dot, 5)
		local name = text(row, {
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0.52, -16, 1, 0),
			Text = string.format("%s  %dg", def.name, def.value),
			TextColor3 = def.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 12,
		})
		local status = text(row, {
			Position = UDim2.fromScale(0.52, 0),
			Size = UDim2.fromScale(0.48, 1),
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 11,
		})
		boardRows[def.id] = { status = status, name = name, dot = dot, def = def }
	end
end

local function makeSlot(key, name, color)
	local slot = panel(nil, { Size = UDim2.fromOffset(132, 52) })
	slot.ClipsDescendants = true
	local stroke = make("UIStroke", { Color = color, Thickness = 2 }, slot)
	local fill = make("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, slot)
	local keyWidth = #key > 3 and 58 or 34
	text(slot, {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(keyWidth, 24),
		Text = key,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		ZIndex = 2,
	})
	text(slot, {
		Position = UDim2.fromOffset(keyWidth + 8, 4),
		Size = UDim2.new(1, -(keyWidth + 12), 0, 22),
		Text = name,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})
	local sub = text(slot, {
		Position = UDim2.fromOffset(6, 30),
		Size = UDim2.new(1, -12, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})
	return { frame = slot, fill = fill, sub = sub, stroke = stroke, color = color }
end

local function buildAbilities()
	local row = make("Frame", {
		Name = "Abilities",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(5 * 132 + 4 * 6, 52),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, row)
	slots.sword = makeSlot("LMB", "SWORD", Color3.fromRGB(220, 220, 230))
	slots.throw = makeSlot("Q", "THROW", GOLD)
	slots.grapple = makeSlot("F", "GRAPPLE", Color3.fromRGB(255, 240, 120))
	slots.polter = makeSlot("E", "POLTERGOBLIN", SPIRIT)
	slots.keg = makeSlot("G", "KEG", Color3.fromRGB(255, 150, 90))
	for i, key in ipairs({ "sword", "throw", "grapple", "keg", "polter" }) do
		slots[key].frame.LayoutOrder = i
		slots[key].frame.Parent = row
	end

	-- Sprint sits bottom-left, clear of the hotbar and the objective line. Its fill is stamina.
	slots.sprint = makeSlot("SHIFT", "SPRINT", STAMINA)
	slots.sprint.frame.Name = "Sprint"
	slots.sprint.frame.AnchorPoint = Vector2.new(0, 1)
	slots.sprint.frame.Position = UDim2.new(0, 12, 1, -12)
	slots.sprint.frame.Size = UDim2.fromOffset(200, 52)
	slots.sprint.frame.Parent = gui
end

-- Shown only while you sit in a boat: speed, hull health, boost, anchor and what the cargo costs you.
local function buildBoatPanel()
	boatPanel = panel(gui, {
		Name = "BoatPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(420, 58),
		Visible = false,
	})
	boatSpeed = text(boatPanel, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(150, 24),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SKIFF  0",
	})
	boatNote = text(boatPanel, {
		Position = UDim2.fromOffset(160, 4),
		Size = UDim2.new(1, -170, 0, 24),
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local hullBack = panel(boatPanel, {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.fromOffset(196, 18),
		BackgroundColor3 = Color3.fromRGB(40, 40, 52),
	})
	hullBack.ClipsDescendants = true
	boatHullFill = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(120, 230, 120),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, hullBack)
	boatHull = text(hullBack, { Text = "HULL", ZIndex = 3, TextStrokeTransparency = 0.2 })
	local boostBack = panel(boatPanel, {
		Position = UDim2.fromOffset(214, 32),
		Size = UDim2.fromOffset(196, 18),
		BackgroundColor3 = Color3.fromRGB(40, 40, 52),
	})
	boostBack.ClipsDescendants = true
	boatBoostFill = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 190, 70),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, boostBack)
	boatBoost = text(boostBack, { Text = "SHIFT BOOST", ZIndex = 3, TextStrokeTransparency = 0.2 })
end

local function buildBottom()
	objective = text(gui, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(760, 30),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.3,
	})
	corner(objective)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, objective)
	toast = text(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(560, 24),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 160),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, gui)
end

local function buildResults()
	results = panel(gui, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 330),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 5,
	})
	make("UIStroke", { Color = GOLD, Thickness = 2 }, results)
	resultsTitle = text(results, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		ZIndex = 6,
	})
	resultsList = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 62),
		Size = UDim2.new(1, -48, 0, 220),
		ZIndex = 6,
	}, results)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, resultsList)
	resultsFooter = text(results, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -10),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.GothamMedium,
		ZIndex = 6,
	})
end

local HELP_LINES = {
	{ "STEAL", "Hold E on a glowing treasure to pry it off its spot. That causes TROUBLE. M opens the map." },
	{ "BANK", "Carry it to THE HOARD (gold beam at Goblin Cove). Deeper treasure is worth more." },
	{ "BOATS", "E on a boat to board. W/A/S/D drives, SHIFT boosts, R drops anchor. Mind the waves and storms." },
	{ "MOVE", "Hold SHIFT to sprint (stamina). F on a cliff, wall or mast hooks you up to it." },
	{ "HEAT", "Stealing and carrying raise Heat. High Heat sends flares, the Navy and a tempest after the CARRIER." },
	{ "FIGHT", "Sword hits knock loot loose (carriers swing slow and tired). F near loot or a carrier steals it." },
	{ "TOYS", "G throws a powder keg (take one from keg crates). E at a cannon fires it where you aim." },
	{ "POLTERGOBLIN", "E: leave your body, run as a spirit, snap back. Loot you grab comes back with you." },
	{ "WIN", "Most gold when the raid timer ends wins. Red rings on the ground = something lands there. Move!" },
}

local function buildHelp()
	help = panel(gui, {
		Name = "Help",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 408),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 8,
	})
	make("UIStroke", { Color = GOLD, Thickness = 2 }, help)
	text(help, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 34),
		Text = "LOOT GOBLINS: STEAL IT, ESCAPE, BANK IT",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		ZIndex = 9,
	})
	for i, line in ipairs(HELP_LINES) do
		text(help, {
			Position = UDim2.fromOffset(20, 50 + (i - 1) * 36),
			Size = UDim2.fromOffset(140, 30),
			Text = line[1],
			Font = Enum.Font.GothamBlack,
			TextColor3 = line[1] == "POLTERGOBLIN" and SPIRIT or GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		text(help, {
			Position = UDim2.fromOffset(160, 50 + (i - 1) * 36),
			Size = UDim2.new(1, -180, 0, 30),
			Text = line[2],
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 9,
		})
	end
	text(help, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 20),
		Text = "H shows or hides this",
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(180, 180, 190),
		ZIndex = 9,
	})
end

local function buildWaypoint()
	-- Billboards don't render inside a ScreenGui, so this one sits in PlayerGui.
	waypoint = make("BillboardGui", {
		Name = "HoardWaypoint",
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(170, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 16, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 5000,
		Adornee = hoardPart,
	}, player:WaitForChild("PlayerGui"))
	waypointLabel = text(waypoint, { Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextStrokeTransparency = 0.1 })
end

function Hud.init(hoard)
	hoardPart = hoard
	gui = make("ScreenGui", {
		Name = "LootGoblinsHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	scale = make("UIScale", {}, gui)
	buildTop()
	buildBanner()
	buildFeed()
	buildBoard()
	buildAbilities()
	buildBoatPanel()
	buildBottom()
	buildResults()
	buildHelp()
	buildWaypoint()
	Map.build(gui, hoardPart.Position)
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- One-off messages -------------------------------------------------------------------
function Hud.banner(message, color, duration)
	bannerToken += 1
	local token = bannerToken
	banner.Text = message
	banner.TextColor3 = color or WHITE
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	banner.BackgroundTransparency = 0.15
	banner.Size = UDim2.fromOffset(820, 52)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(780, 46) }):Play()
	task.delay(duration or 2.5, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

function Hud.feed(message, color)
	local line = text(feedList, {
		Size = UDim2.fromOffset(400, 22),
		Text = message,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.2,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.45,
		LayoutOrder = os.clock() * 1000 // 1,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, line)
	local lines = {}
	for _, child in ipairs(feedList:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > 7 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(8, function()
		if line.Parent then
			local fade = TweenService:Create(line, TweenInfo.new(0.6), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Wait()
			line:Destroy()
		end
	end)
end

function Hud.toast(message)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2.2, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Hud.flash(color, strength)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - (strength or 0.25)
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

function Hud.heatHint(message, color)
	hintToken += 1
	local token = hintToken
	heatHint.Text = message
	heatHint.TextColor3 = color or WHITE
	heatHint.TextTransparency = 0
	heatHint.TextStrokeTransparency = 0.3
	task.delay(7, function()
		if token == hintToken then
			TweenService:Create(heatHint, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

function Hud.showResults(list, winners)
	for _, child in ipairs(resultsList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #winners == 0 then
		resultsTitle.Text = "RAID OVER - NOBODY BANKED ANYTHING"
	elseif #winners == 1 then
		resultsTitle.Text = string.upper(winners[1]) .. " WINS THE RAID!"
	else
		resultsTitle.Text = "TIE: " .. string.upper(table.concat(winners, " & "))
	end
	for i, entry in ipairs(list) do
		if i > 8 then
			break
		end
		local mine = entry.userId == player.UserId
		text(resultsList, {
			Size = UDim2.new(1, 0, 0, 24),
			Text = string.format("%d.  %s    %d gold", i, entry.name, entry.gold),
			TextColor3 = mine and GOLD or WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			ZIndex = 6,
		})
	end
	results.Visible = true
end

function Hud.hideResults()
	results.Visible = false
end

function Hud.showHelp(seconds)
	help.Visible = true
	if seconds then
		task.delay(seconds, function()
			help.Visible = false
		end)
	end
end

function Hud.toggleMap()
	Map.toggle()
end

function Hud.toggleHelp()
	help.Visible = not help.Visible
end

-- Per frame ---------------------------------------------------------------------------
local function lootFolder()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Loot")
end

local function inWard(position)
	local hoard = hoardPart.Position
	return Vector3.new(position.X - hoard.X, 0, position.Z - hoard.Z).Magnitude <= Config.WARD_RADIUS
end

local function updateTop(now, phase, phaseEndsAt)
	local left = phaseEndsAt - now
	if phase == "raid" then
		local lastCall = left <= Config.LAST_CALL
		timer.Text = (lastCall and "LAST CALL  " or "RAID  ") .. clock(left)
		local pulse = lastCall and (math.sin(now * 8) > 0) or false
		timer.TextColor3 = lastCall and (pulse and Color3.fromRGB(255, 90, 90) or WHITE) or WHITE
	else
		timer.Text = "NEXT RAID IN " .. math.max(0, math.ceil(left))
		timer.TextColor3 = Color3.fromRGB(190, 190, 200)
	end

	local heat = workspace:GetAttribute("Heat") or 0
	local tier = workspace:GetAttribute("HeatTier") or 1
	local info = Config.HEAT_TIERS[tier] or Config.HEAT_TIERS[1]
	shownHeat += (heat - shownHeat) * 0.15
	heatFill.Size = UDim2.fromScale(math.clamp(shownHeat / Config.HEAT_MAX, 0, 1), 1)
	heatFill.BackgroundColor3 = info.color
	heatLabel.Text = "HEAT  " .. info.name
end

local function updateBoard(now, folder)
	for id, row in pairs(boardRows) do
		local state = folder and folder:GetAttribute(id .. "State") or "spot"
		local bonus = folder and folder:GetAttribute(id .. "Bonus") or 0
		local status
		local color = Color3.fromRGB(200, 200, 210)
		if state == "carried" then
			local carrierId = folder:GetAttribute(id .. "CarrierId")
			if carrierId == player.UserId then
				status, color = "YOU - GET HOME!", GOLD
			else
				status = (folder:GetAttribute(id .. "Carrier") or "?")
				color = Color3.fromRGB(255, 170, 120)
			end
		elseif state == "loose" then
			status, color = "LOOSE!", Color3.fromRGB(255, 110, 110)
		elseif state == "away" then
			local returnAt = folder:GetAttribute(id .. "ReturnAt") or now
			status = string.format("banked %ds", math.max(0, math.ceil(returnAt - now)))
			color = Color3.fromRGB(130, 130, 140)
		else
			status = row.def.place
		end
		row.status.Text = status
		row.status.TextColor3 = color
		row.name.Text =
			string.format("%s  %dg%s", row.def.name, row.def.value + bonus, bonus > 0 and ("+" .. bonus) or "")
		row.dot.BackgroundTransparency = state == "away" and 0.7 or 0
	end
end

local function setSlot(slot, fill, sub, active)
	slot.fill.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
	slot.sub.Text = sub
	slot.stroke.Transparency = active and 0 or 0.65
	slot.fill.BackgroundTransparency = active and 0.55 or 0.85
end

local function updateAbilities(now, root, carrying)
	local polterEnds = player:GetAttribute("PolterEndsAt")
	local polterReady = player:GetAttribute("PolterReadyAt") or 0
	if polterEnds then
		local left = math.max(polterEnds - now, 0)
		local body = player:GetAttribute("PolterBody")
		local tether = (root and body)
				and string.format("  tether %d/%d", math.floor((root.Position - body).Magnitude), Config.POLTER_TETHER)
			or ""
		setSlot(slots.polter, left / Config.POLTER_DURATION, string.format("E RETURN %.1f%s", left, tether), true)
	elseif now < polterReady then
		local left = polterReady - now
		setSlot(slots.polter, 1 - left / Config.POLTER_COOLDOWN, string.format("recharging %.1fs", left), false)
	elseif root and inWard(root.Position) then
		setSlot(slots.polter, 1, "blocked by the ward", false)
	else
		setSlot(slots.polter, 1, "READY: leave your body", true)
	end

	local grappleReady = player:GetAttribute("GrappleReadyAt") or 0
	if now < grappleReady then
		local left = grappleReady - now
		local length = player:GetAttribute("GrappleCooldown") or Config.GRAPPLE_COOLDOWN
		setSlot(slots.grapple, 1 - left / length, string.format("%.1fs", left), false)
	else
		setSlot(slots.grapple, 1, carrying and "hands full" or "hook / steal", not carrying)
	end

	local winded = player:GetAttribute("Winded") == true
	local sprinting = player:GetAttribute("Sprinting") == true
	shownStamina += ((player:GetAttribute("Stamina") or Config.STAMINA_MAX) - shownStamina) * 0.3
	setSlot(
		slots.sprint,
		shownStamina / Config.STAMINA_MAX,
		winded and "OUT OF BREATH" or (sprinting and "sprinting!" or "hold to run"),
		not winded
	)
	slots.sprint.fill.BackgroundColor3 = winded and WINDED or STAMINA
	slots.sprint.stroke.Color = winded and WINDED or STAMINA

	setSlot(slots.throw, carrying and 1 or 0, carrying and "throw your loot" or "nothing held", carrying)
	setSlot(slots.sword, 1, carrying and "heavy bash (tiring)" or "knocks loot loose", true)
	local kegs = player:GetAttribute("Kegs") or 0
	setSlot(
		slots.keg,
		kegs / Config.KEG_MAX,
		kegs > 0 and string.format("%d kegs: throw", kegs) or "find a keg crate",
		kegs > 0
	)
end

local function updateBoatPanel(now)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Parent
	local boatType = model and model:GetAttribute("BoatType")
	if not boatType then
		boatPanel.Visible = false
		return
	end
	boatPanel.Visible = true
	local spec = Config.BOAT_TYPES[boatType]
	local health = model:GetAttribute("Health") or spec.health
	local maxHealth = model:GetAttribute("MaxHealth") or spec.health
	local fraction = math.clamp(health / maxHealth, 0, 1)
	boatSpeed.Text = string.format("%s  %d", string.upper(spec.name), model:GetAttribute("Speed") or 0)
	boatHullFill.Size = UDim2.fromScale(fraction, 1)
	boatHullFill.BackgroundColor3 = fraction > 0.5 and Color3.fromRGB(120, 230, 120)
		or (fraction > 0.25 and Color3.fromRGB(255, 200, 70) or Color3.fromRGB(255, 80, 70))
	boatHull.Text = string.format("HULL %d", math.floor(health))
	local boostEnds = model:GetAttribute("BoostEndsAt") or 0
	local boostReady = model:GetAttribute("BoostReadyAt") or 0
	if now < boostEnds then
		boatBoostFill.Size = UDim2.fromScale(1, 1)
		boatBoost.Text = "BOOSTING!"
	elseif now < boostReady then
		boatBoostFill.Size = UDim2.fromScale(1 - (boostReady - now) / Config.BOAT_BOOST_COOLDOWN, 1)
		boatBoost.Text = string.format("boost %.0fs", boostReady - now)
	else
		boatBoostFill.Size = UDim2.fromScale(1, 1)
		boatBoost.Text = "SHIFT: BOOST"
	end
	local notes = {}
	if model:GetAttribute("Moored") then
		table.insert(notes, "ANCHORED (R)")
	end
	local payload = model:GetAttribute("Payload") or 0
	if payload > 0 then
		table.insert(
			notes,
			string.format("cargo -%d%% speed", math.floor(payload * Config.BOAT_PAYLOAD_DRAG * 100 + 0.5))
		)
	end
	boatNote.Text = table.concat(notes, "   ")
end

-- One line that always says what to do next. While carrying, it also says what the world is doing about it.
local function updateObjective(now, phase, root, carrying)
	if phase ~= "raid" then
		objective.Text = "Raid starting soon. Treasure glows at its spot: steal it and bring it to THE HOARD. M: map"
		objective.TextColor3 = WHITE
		return
	end
	local def
	for _, d in ipairs(Config.LOOT) do
		if d.id == carrying then
			def = d
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inBoat = humanoid and humanoid.SeatPart and humanoid.SeatPart.Parent:GetAttribute("BoatType") ~= nil
	if def then
		local tier = workspace:GetAttribute("HeatTier") or 1
		local distance = root and math.floor((root.Position - hoardPart.Position).Magnitude) or 0
		local watchers = {}
		if tier >= 2 then
			table.insert(watchers, "you're lit up")
		end
		if tier >= 3 then
			table.insert(watchers, "the Navy hunts")
		end
		if tier >= 4 then
			table.insert(watchers, "a TEMPEST is coming")
		end
		objective.Text = string.format(
			"YOU HAVE THE %s (%dg)! HOARD %d studs%s%s",
			string.upper(def.name),
			def.value,
			distance,
			#watchers > 0 and ("  -  " .. table.concat(watchers, ", ")) or "",
			inBoat and "" or "  -  find a boat!"
		)
		local pulse = math.sin(now * 6) > 0
		objective.TextColor3 = pulse and GOLD or WHITE
	elseif player:GetAttribute("PolterEndsAt") then
		objective.Text = "SPIRIT FORM: grab loot and snap back with it. Guard your body!"
		objective.TextColor3 = SPIRIT
	elseif root and inWard(root.Position) then
		objective.Text =
			"You're home. Take a boat (E), sail out, steal treasure (M map, compass up top), bring it back here."
		objective.TextColor3 = WARD
	elseif inBoat then
		objective.Text = "Sailing: W/A/S/D steer, SHIFT boost, R anchor. Mind the storms and the shallows."
		objective.TextColor3 = WHITE
	else
		objective.Text = "Steal treasure (light pillars) or rob a carrier, then bring it to THE HOARD."
		objective.TextColor3 = WHITE
	end
end

local function updateWaypoint(root, carrying)
	if not root then
		waypoint.Enabled = false
		return
	end
	waypoint.Enabled = true
	local distance = math.floor((root.Position - hoardPart.Position).Magnitude)
	if carrying then
		waypointLabel.Text = "THE HOARD  " .. distance
		waypointLabel.TextColor3 = GOLD
		waypoint.Size = UDim2.fromOffset(210, 52)
	else
		waypointLabel.Text = "HOARD " .. distance
		waypointLabel.TextColor3 = Color3.fromRGB(230, 210, 150)
		waypoint.Size = UDim2.fromOffset(130, 30)
	end
end

function Hud.update(now)
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.6, 1.15)
	end
	local phase = workspace:GetAttribute("RaidPhase") or "intermission"
	local phaseEndsAt = workspace:GetAttribute("PhaseEndsAt") or now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carrying = player:GetAttribute("CarryingLoot")
	updateTop(now, phase, phaseEndsAt)
	updateBoard(now, lootFolder())
	updateAbilities(now, root, carrying)
	updateBoatPanel(now)
	Map.update(now)
	updateObjective(now, phase, root, carrying)
	updateWaypoint(root, carrying)
	if results.Visible and phase == "intermission" then
		resultsFooter.Text = "Next raid in " .. math.max(0, math.ceil(phaseEndsAt - now))
	end
end

return Hud

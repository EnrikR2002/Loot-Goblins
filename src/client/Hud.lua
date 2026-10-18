-- The HUD. Everything it shows comes from replicated attributes (raid timer,
-- Heat, where each loot is, your cooldowns and stamina) plus one-off GameEvents
-- (banner, feed, toasts). Placement keeps clear of Roblox's own chat (top left),
-- player list (top right) and tool hotbar (bottom middle).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Map = require(script.Parent.Map)
local BoatDrive = require(script.Parent.BoatDrive)
local BannerQueue = require(script.Parent.BannerQueue)
local Objective = require(script.Parent.Objective)

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
local helpGui, helpScale -- V12: the controls card's own layer, over the hoard arrow and the danger arrows
local timer, heatFill, heatLabel, heatHint, banner, feedList, board, boardTitle, objective, toast, flash
local help
local slots = {}
local boardRows = {}
local boardOrder = {} -- ids, richest first
local boardFull = false -- T: every treasure; by default only what is loose or carried
local boatPanel, boatSpeed, boatHull, boatHullFill, boatBoost, boatBoostFill, boatDrift, boatDriftFill, boatNote
local LOOT_WEIGHT = {}
local LOOT_DEFS = {}
for _, def in ipairs(Config.LOOT) do
	LOOT_WEIGHT[def.id] = def.weight or 1
	LOOT_DEFS[def.id] = def
end
-- The drift meter's colour says which burst releasing now would give: none, small, big.
local DRIFT_COLORS = {
	[0] = Color3.fromRGB(150, 160, 180),
	[1] = Color3.fromRGB(120, 220, 255),
	[2] = Color3.fromRGB(255, 170, 70),
}
local waypoint, waypointLabel
local hoardPart
local shownHeat = 0
local shownStamina = Config.STAMINA_MAX
local coinPanel, coinLabel
local chainCount, chainUntil = 0, 0 -- The run of hoops the boat is on (shown in the boat panel).
local bannerToken, toastToken, hintToken = 0, 0, 0
-- V12: the banner has priorities (client/BannerQueue.lua): a lesser banner waits for the one showing.
local bannerQueue = BannerQueue.new()
-- V12: what the goblin is doing, which decides what the HUD shows ("ship", "flight", "boat" or "foot").
local hudMode = "foot"

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
		-- V9: below the minimap (client/Minimap.lua), top right.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 236),
		Size = UDim2.fromOffset(300, 26 + rowsCount * BOARD_ROW),
	})
	boardTitle = text(board, {
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
		boardRows[def.id] = { status = status, name = name, dot = dot, def = def, frame = row }
		table.insert(boardOrder, def.id)
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

	-- Stamina sits bottom-left, clear of the hotbar and the objective line. It pays for
	-- sprint, dash and air jump; running is free. The dash sits beside it.
	slots.sprint = makeSlot("SHIFT", "SPRINT", STAMINA)
	slots.sprint.frame.Name = "Sprint"
	slots.sprint.frame.AnchorPoint = Vector2.new(0, 1)
	slots.sprint.frame.Position = UDim2.new(0, 12, 1, -12)
	slots.sprint.frame.Size = UDim2.fromOffset(220, 52)
	slots.sprint.frame.Parent = gui
	slots.dash = makeSlot("C", "DASH", STAMINA)
	slots.dash.frame.Name = "Dash"
	slots.dash.frame.AnchorPoint = Vector2.new(0, 1)
	slots.dash.frame.Position = UDim2.new(0, 238, 1, -12)
	slots.dash.frame.Size = UDim2.fromOffset(160, 52)
	slots.dash.frame.Parent = gui

	-- The coin purse, just above: what you have picked up at sea and what it has paid this raid.
	coinPanel = panel(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -70),
		Size = UDim2.fromOffset(386, 24),
	})
	coinLabel = text(coinPanel, {
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 215, 60),
		Text = "COINS 0",
	})
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
	-- Three meters in a row: hull, boost, drift charge.
	local function meter(x, color, label)
		local back = panel(boatPanel, {
			Position = UDim2.fromOffset(x, 32),
			Size = UDim2.fromOffset(128, 18),
			BackgroundColor3 = Color3.fromRGB(40, 40, 52),
		})
		back.ClipsDescendants = true
		local fill = make("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, back)
		return fill, text(back, { Text = label, ZIndex = 3, TextStrokeTransparency = 0.2 })
	end
	boatHullFill, boatHull = meter(10, Color3.fromRGB(120, 230, 120), "HULL")
	boatBoostFill, boatBoost = meter(146, Color3.fromRGB(255, 190, 70), "SHIFT BOOST")
	boatDriftFill, boatDrift = meter(282, DRIFT_COLORS[0], "C DRIFT")
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

-- V12: the help card (H) is a controls card that fits on the screen: the goal, then the keys by where you
-- are, then three rules of the sea. V9 to V11 opened a sixteen-row wall of sentences by itself at every join
-- (its last rows spilled out of the panel) and it covered the first fourteen seconds of the launch window.
local HELP_GOAL = "STEAL TREASURE, ESCAPE, BANK IT AT THE GOLD HOARD RING. MOST GOLD IN 6 MINUTES WINS."
local HELP_COLUMNS = {
	{
		"ON FOOT",
		{
			{ "hold E", "steal a glowing treasure" },
			{ "E", "use: boats, cannons, levers" },
			{ "SHIFT", "sprint" },
			{ "C", "dash (also in the air)" },
			{ "SPACE x2", "jump again in the air" },
			{ "F", "grapple: a cliff or a carrier" },
			{ "Q", "throw what you carry" },
			{ "CLICK", "sword: knocks treasure loose" },
			{ "G", "throw a powder keg" },
			{ "E", "(nothing near) Poltergoblin" },
		},
	},
	{
		"AT SEA",
		{
			{ "B", "call a boat to you" },
			{ "W A S D", "drive  (S brakes)" },
			{ "SHIFT", "boost" },
			{ "hold C", "drift a turn, let go: burst" },
			{ "SPACE", "jump (SUPER JUMP when fast)" },
			{ "R", "trick in the air (again: combo)" },
			{ "X", "leave the boat" },
		},
	},
	{
		"IN THE AIR",
		{
			{ "LOOK", "aim a cannon: CLICK fires" },
			{ "hold SPACE", "glide: a soft landing" },
			{ "hold SHIFT", "dive" },
		},
	},
	{
		"MENUS",
		{
			{ "M", "map: pick where to land" },
			{ "P", "wardrobe   V emotes" },
			{ "T", "every treasure   H this card" },
		},
	},
}
local HELP_RULES = {
	"A ring on the ground or the sea means something lands there: move.",
	"Whatever guards a treasure follows its thief home, until the gold buoys round Goblin Cove.",
	"Keep your speed at sea: pursuers catch whoever slows down.",
	"CONTROLLER: A jump / fire, X boost, B dash / drift, Y leave a boat, R1 trick, L2 hook, L1 throw, R3 (click) map.",
	"D-pad: down calls a boat, left throws a keg, right the wardrobe, up the emotes.",
}

local function buildHelp()
	helpGui = make("ScreenGui", { Name = "LootGoblinsHelp", ResetOnSpawn = false, DisplayOrder = 12 }, nil)
	helpScale = make("UIScale", {}, helpGui)
	help = panel(helpGui, {
		Name = "Help",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 452),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 8,
	})
	make("UIStroke", { Color = GOLD, Thickness = 2 }, help)
	text(help, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 30),
		Text = "LOOT GOBLINS",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		ZIndex = 9,
	})
	text(help, {
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.new(1, -32, 0, 20),
		Text = HELP_GOAL,
		Font = Enum.Font.GothamBold,
		ZIndex = 9,
	})
	-- Two columns: foot and air on the left, sea and menus on the right.
	local columnX = { 20, 400 }
	local y = { 72, 72 }
	for i, section in ipairs(HELP_COLUMNS) do
		local side = (i == 1 or i == 3) and 1 or 2
		text(help, {
			Position = UDim2.fromOffset(columnX[side], y[side]),
			Size = UDim2.fromOffset(340, 18),
			Text = section[1],
			Font = Enum.Font.GothamBlack,
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		y[side] += 22
		for _, row in ipairs(section[2]) do
			local chip = panel(help, {
				Position = UDim2.fromOffset(columnX[side], y[side]),
				Size = UDim2.fromOffset(96, 19),
				BackgroundColor3 = Color3.fromRGB(60, 60, 76),
				BackgroundTransparency = 0,
				ZIndex = 9,
			})
			text(chip, { Text = row[1], Font = Enum.Font.GothamBlack, TextColor3 = WHITE, ZIndex = 10 })
			text(help, {
				Position = UDim2.fromOffset(columnX[side] + 104, y[side]),
				Size = UDim2.fromOffset(236, 19),
				Text = row[2],
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 9,
			})
			y[side] += 22
		end
		y[side] += 8
	end
	local rulesY = math.max(y[1], y[2]) + 2
	for i, rule in ipairs(HELP_RULES) do
		text(help, {
			Position = UDim2.fromOffset(20, rulesY + (i - 1) * 20),
			Size = UDim2.new(1, -40, 0, 18),
			Text = rule,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(255, 220, 140),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
	end
	help.Size = UDim2.fromOffset(760, rulesY + #HELP_RULES * 20 + 34)
	text(help, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 16),
		Text = "H closes this",
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
	buildHelp()
	buildWaypoint()
	Map.build(gui, hoardPart.Position)
	gui.Parent = player:WaitForChild("PlayerGui")
	helpGui.Parent = gui.Parent
end

-- One-off messages -------------------------------------------------------------------
local function showBanner(shown)
	if not shown then
		return
	end
	local duration = shown.duration or 2.5
	bannerToken += 1
	local token = bannerToken
	banner.Text = shown.message
	banner.TextColor3 = shown.color or WHITE
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	banner.BackgroundTransparency = 0.15
	banner.Size = UDim2.fromOffset(820, 52)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(780, 46) }):Play()
	task.delay(duration, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

-- priority: 4 act now, 3 your own big moment, 2 the world reacting (default), 1 news. See BannerQueue.
function Hud.banner(message, color, duration, priority)
	showBanner(BannerQueue.offer(bannerQueue, os.clock(), {
		message = message,
		color = color,
		duration = duration,
		priority = priority,
	}))
end

local function flushBanner()
	showBanner(BannerQueue.flush(bannerQueue, os.clock()))
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

-- The boat just took its `count`-th hoop in a row.
function Hud.chain(count)
	chainCount, chainUntil = count, os.clock() + Config.BOAT_CHAIN_WINDOW
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
	local clockAt = workspace:GetAttribute("RaidClockAt")
	if phase == "raid" and clockAt and now < clockAt then
		-- V9: the launch window. The six-minute clock waits for it. (V12: shorter; at two digits it wrapped.)
		timer.Text = string.format(
			"LAUNCH  %ds   |   THEN RAID %s",
			math.max(0, math.ceil(clockAt - now)),
			clock(phaseEndsAt - clockAt)
		)
		timer.TextColor3 = Color3.fromRGB(150, 230, 255)
	elseif phase == "raid" then
		local lastCall = left <= Config.LAST_CALL
		local rush = left <= Config.FINAL_RUSH
		timer.Text = (lastCall and "LAST CALL  " or (rush and "FINAL RUSH  " or "RAID  ")) .. clock(left)
		local pulse = lastCall and (math.sin(now * 8) > 0) or false
		timer.TextColor3 = lastCall and (pulse and Color3.fromRGB(255, 90, 90) or WHITE)
			or (rush and Color3.fromRGB(255, 170, 90) or WHITE)
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
	local shown = 0
	for _, id in ipairs(boardOrder) do
		local row = boardRows[id]
		local state = folder and folder:GetAttribute(id .. "State") or "spot"
		local visible = boardFull or state == "carried" or state == "loose"
		row.frame.Visible = visible
		if visible then
			row.frame.Position = UDim2.fromOffset(8, 24 + shown * BOARD_ROW)
			shown += 1
		end
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
	board.Size = UDim2.fromOffset(300, 28 + math.max(shown, 0) * BOARD_ROW)
	boardTitle.Text = boardFull and "TREASURE  (gold value)  T: fewer"
		or (shown > 0 and "LOOSE OR CARRIED  T: all treasure" or "T: all treasure")
end

function Hud.toggleBoard()
	boardFull = not boardFull
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
		setSlot(slots.grapple, 1, carrying and "pull only (hands full)" or "hook / steal", true)
	end

	local purse = player:GetAttribute("Coins") or 0
	local coinGold = player:GetAttribute("CoinGold") or 0
	if coinGold >= Config.COIN_GOLD_CAP then
		coinLabel.Text = string.format("COINS %d   (the Hoard has paid all %d gold it will this raid)", purse, coinGold)
	else
		coinLabel.Text = string.format(
			"COINS %d   %d = 1 gold at the Hoard  (%d of %d paid)",
			purse,
			Config.COINS_PER_GOLD,
			coinGold,
			Config.COIN_GOLD_CAP
		)
	end

	local winded = player:GetAttribute("Winded") == true
	local chilled = player:GetAttribute("Chilled") == true
	local sprinting = player:GetAttribute("Sprinting") == true
	local stamina = player:GetAttribute("Stamina") or Config.STAMINA_MAX
	shownStamina += (stamina - shownStamina) * 0.3
	setSlot(
		slots.sprint,
		shownStamina / Config.STAMINA_MAX,
		winded and "OUT OF BREATH"
			or (
				chilled and "CHILLED: stamina draining"
				or (sprinting and "sprinting!" or "stamina: sprint, dash, air jump")
			),
		not winded
	)
	local staminaColor = winded and WINDED or (chilled and Color3.fromRGB(150, 220, 255) or STAMINA)
	slots.sprint.fill.BackgroundColor3 = staminaColor
	slots.sprint.stroke.Color = staminaColor

	-- Loot makes every stamina cost bigger, by its weight: the dash slot shows the real price.
	local dashCost = Config.DASH_COST * (1 + (LOOT_WEIGHT[carrying] or 0) * Config.CARRY_STAMINA_PER_WEIGHT)
	local seated = BoatDrive.info().driving
	setSlot(
		slots.dash,
		math.clamp(stamina / dashCost, 0, 1),
		seated and "at the wheel: DRIFT" or string.format("dodge, any time (%d)", math.floor(dashCost + 0.5)),
		stamina >= dashCost or seated
	)

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
	local drive = BoatDrive.info()
	-- Speed straight from the hull, so passengers see it too.
	local hull = model:FindFirstChild("Hull")
	local velocity = hull and hull.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	boatSpeed.Text = string.format("%s  %d", string.upper(spec.name), math.floor(speed + 0.5))
	-- Drift: the meter fills while you slide; its colour is the burst you get for letting go.
	local full = Config.BOAT_DRIFT_CHARGE[2]
	boatDriftFill.Size = UDim2.fromScale(math.clamp(drive.charge / full, 0, 1), 1)
	boatDriftFill.BackgroundColor3 = DRIFT_COLORS[drive.level] or DRIFT_COLORS[0]
	boatDrift.Text = drive.level == 2 and "LET GO: BIG BURST"
		or (drive.level == 1 and "LET GO: BURST" or (drive.drifting and "DRIFTING..." or "C: DRIFT"))
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
	if os.clock() < chainUntil then
		table.insert(notes, "HOOP CHAIN x" .. chainCount)
	end
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

-- One line that always says what to do next, with the key for it (V12: the main way a first raid is taught;
-- V11 said "find a boat!" even to a goblin walking into the Hoard and never said how). On the ship and in the
-- air the skyship's own banner speaks instead, so this line is hidden there (see applyMode).
local function nearestWaitingTreasure(position, folder)
	local best, bestDistance
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		local core = model:IsA("Model") and model.PrimaryPart
		if core and (folder:GetAttribute(model.Name .. "State") or "spot") == "spot" then
			local distance = (core.Position - position).Magnitude
			if not bestDistance or distance < bestDistance then
				best, bestDistance = model.Name, distance
			end
		end
	end
	return best, bestDistance
end

local OBJECTIVE_TONES = {
	spirit = SPIRIT,
	home = WARD,
	water = Color3.fromRGB(150, 230, 255),
	plain = WHITE,
}

local function updateObjective(now, phase, root, carrying)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inBoat = humanoid and humanoid.SeatPart and humanoid.SeatPart.Parent:GetAttribute("BoatType") ~= nil
	local folder = lootFolder()
	local hoardDistance = root
			and math.floor(
				Vector3.new(root.Position.X - hoardPart.Position.X, 0, root.Position.Z - hoardPart.Position.Z).Magnitude
			)
		or 0
	local def = carrying and LOOT_DEFS[carrying]
	local nearest
	if root and not def then
		local id, distance = nearestWaitingTreasure(root.Position, folder)
		if id and LOOT_DEFS[id] then
			nearest =
				{ name = LOOT_DEFS[id].name, distance = distance, color = LOOT_DEFS[id].color, way = LOOT_DEFS[id].way }
		end
	end
	local line, tone = Objective.line({
		phase = phase,
		carrying = def,
		bonus = def and folder and folder:GetAttribute(def.id .. "Bonus") or 0,
		hoardDistance = hoardDistance,
		nearHoard = hoardDistance <= Config.WARD_RADIUS + 120 and not inBoat,
		inBoat = inBoat,
		swimming = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming,
		inWard = root and inWard(root.Position),
		spirit = player:GetAttribute("PolterEndsAt") ~= nil,
		recallLeft = math.max(0, (player:GetAttribute("RecallReadyAt") or 0) - now),
		nearest = nearest,
	})
	objective.Text = line
	if tone == "carry" then
		objective.TextColor3 = math.sin(now * 6) > 0 and GOLD or WHITE
	elseif tone == "treasure" then
		objective.TextColor3 = nearest and nearest.color or WHITE
	else
		objective.TextColor3 = OBJECTIVE_TONES[tone] or WHITE
	end
end

-- V9: the label over the Hoard shows only while you carry treasure (it is where you are going); the rest
-- of the time the compass and the minimap say where home is, and the horizon stays clear.
local function updateWaypoint(root, carrying)
	if not root or not carrying then
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

-- V12: the HUD follows what the goblin is doing. On the ship and in the air the skyship's banner (client
-- Skyship.lua) is the instruction, so the on-foot slots, the coin purse and the objective line step aside (V11
-- kept all seven ability slots up while aiming a cannon and tumbling). At the wheel the boat panel takes over
-- the stamina slots and the moves a driver cannot make. Toasts move so they never sit on the boat panel or
-- the skyship's banner (they printed over the hull meter and the deck hint in V11).
local function modeOf()
	local state = player:GetAttribute("DeployState")
	if player:GetAttribute("Diving") then
		return "flight"
	elseif state == "aboard" or state == "loaded" or state == "fuse" then
		return "ship"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat.Parent and seat.Parent:GetAttribute("BoatType") then
		return "boat"
	end
	return "foot"
end

local TOAST_Y = { foot = -112, boat = -184, ship = -84, flight = -84 }
local function applyMode(mode)
	if mode == hudMode then
		return
	end
	hudMode = mode
	local foot, boat = mode == "foot", mode == "boat"
	for key, slot in pairs(slots) do
		if key == "sprint" or key == "dash" or key == "keg" or key == "polter" then
			slot.frame.Visible = foot
		else
			slot.frame.Visible = foot or boat
		end
	end
	coinPanel.Visible = foot or boat
	objective.Visible = foot or boat
	toast.Position = UDim2.new(0.5, 0, 1, TOAST_Y[mode] or -112)
end

function Hud.mode()
	return hudMode
end

function Hud.update(now)
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.6, 1.15)
		helpScale.Scale = scale.Scale
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
	applyMode(modeOf())
	flushBanner()
end

return Hud

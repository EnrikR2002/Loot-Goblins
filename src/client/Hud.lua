-- The HUD. Everything it shows comes from replicated attributes (raid timer,
-- Heat, where each loot is, your cooldowns and stamina) plus one-off GameEvents
-- (banner, feed, toasts). Placement keeps clear of Roblox's own chat (top left),
-- player list (top right) and tool hotbar (bottom middle).
--
-- V13, THE QUIET HUD: icons, not sentences. The V12 HUD drew five 132-pixel ability slots each with a line of text,
-- two stamina slots, a coin sentence and an objective sentence, all at once. Now:
--   * moves are square icon buttons with their key in the corner (the controller's button on a controller, nothing on
--     a touch screen, which has its own buttons) and a cooldown that fills like a clock; a move that cannot be used
--     right now is dimmed, and THROW and KEG only appear when you have something to throw;
--   * stamina is one slim bar; the coin purse is a chip that appears once you have coins;
--   * the boat panel is one compact strip: speed, hull, boost, drift and the boat's own ability (Config.BOAT_ABILITIES);
--   * the objective is a short chip that teaches during a goblin's first raids (Objective.TEACH_RAIDS) and after that
--     only speaks when it matters (carrying, swimming, a treasure right here);
--   * the feed keeps four lines, briefly;
--   * in the Port none of this is shown: client/PortHud.lua draws the Port's own small screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
local CHILLED = Color3.fromRGB(150, 220, 255)

local gui, scale
local helpGui, helpScale -- V12: the controls card's own layer, over the hoard arrow and the danger arrows
local top, timer, heatFill, heatLabel, heatHint, banner, feedList, board, boardTitle, objective, toast, flash
local shoreHint, knockoutFrame, knockoutTitle, knockoutSub -- V13.1
local knockoutUntil, knockoutCause
local help
local slots = {}
local boardRows = {}
local boardOrder = {} -- ids, richest first
local boardFull = false -- T: every treasure; by default only what is loose or carried
local staminaBar, staminaFill, staminaIcon, dashChip
local boatPanel, boatSpeed, boatNote
local meters = {}
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
local coinChip, coinLabel
local chainCount, chainUntil = 0, 0 -- The run of hoops the boat is on (shown in the boat panel).
local bannerToken, toastToken, hintToken = 0, 0, 0
-- V12: the banner has priorities (client/BannerQueue.lua): a lesser banner waits for the one showing.
local bannerQueue = BannerQueue.new()
-- V12: what the goblin is doing, which decides what the HUD shows ("ship", "flight", "boat" or "foot"; V13 "port").
local hudMode = "foot"
-- V13: which glyphs the key chips show: "keys", "pad" (a controller) or "touch" (none: the screen has buttons).
local inputKind = "keys"

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
	top = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(240, 66),
		BackgroundTransparency = 1,
	}, gui)
	local timerBack = panel(top, { Size = UDim2.fromOffset(240, 34) })
	corner(timerBack, 17)
	timer = text(timerBack, {
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 1, -6),
		Font = Enum.Font.GothamBlack,
		Text = "RAID",
	})

	local heatBack = panel(top, { Position = UDim2.fromOffset(20, 38), Size = UDim2.fromOffset(200, 8) })
	heatBack.ClipsDescendants = true
	corner(heatBack, 4)
	heatFill = make("Frame", {
		BackgroundColor3 = Config.HEAT_TIERS[1].color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, heatBack)
	corner(heatFill, 4)
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
	-- The heat's name only once it is above calm (calm is the normal state: nothing to read).
	heatLabel = text(top, {
		Position = UDim2.fromOffset(0, 47),
		Size = UDim2.fromOffset(240, 14),
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextStrokeTransparency = 0.3,
	})
	heatHint = text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(460, 18),
		Font = Enum.Font.GothamMedium,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
end

local function buildBanner()
	banner = text(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 122),
		Size = UDim2.fromOffset(640, 40),
		Font = Enum.Font.GothamBlack,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	corner(banner, 12)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, banner)
end

local function buildFeed()
	local feed = make("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -96),
		Size = UDim2.fromOffset(340, 104),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, feed)
	feedList = feed
end

local BOARD_ROW = 20

local function buildBoard()
	local rowsCount = #Config.LOOT
	board = panel(gui, {
		Name = "LootBoard",
		-- V9: below the minimap (client/Minimap.lua), top right.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 236),
		Size = UDim2.fromOffset(260, 26 + rowsCount * BOARD_ROW),
	})
	boardTitle = text(board, {
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "TREASURE",
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
			Size = UDim2.new(0.55, -16, 1, 0),
			Text = string.format("%s  %dg", def.name, def.value),
			TextColor3 = def.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 12,
		})
		local status = text(row, {
			Position = UDim2.fromScale(0.55, 0),
			Size = UDim2.fromScale(0.45, 1),
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 11,
		})
		boardRows[def.id] = { status = status, name = name, dot = dot, def = def, frame = row }
		table.insert(boardOrder, def.id)
	end
end

-- A move: a square icon with its key in the corner, a cooldown that fills it like a clock face, and (for a goblin's
-- first raids) a word under it.
local ICON = 54
local function makeSlot(id, glyph, word, color, keys)
	local slot = panel(nil, { Name = id, Size = UDim2.fromOffset(ICON, ICON) })
	corner(slot, 12)
	slot.ClipsDescendants = false
	local stroke = make("UIStroke", { Color = color, Thickness = 2 }, slot)
	local cool = make("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		ZIndex = 3,
	}, slot)
	corner(cool, 12)
	local icon = text(slot, {
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		Text = glyph,
		TextStrokeTransparency = 1,
		ZIndex = 2,
	})
	local count = text(slot, {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextScaled = false,
		TextSize = 20,
		TextStrokeTransparency = 0.2,
		ZIndex = 4,
	})
	local keyChip = panel(slot, {
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.fromOffset(24, 18),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		ZIndex = 5,
	})
	corner(keyChip, 6)
	local keyLabel = text(keyChip, {
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.new(1, -4, 1, -2),
		Text = keys[1],
		Font = Enum.Font.GothamBlack,
		TextColor3 = DARK,
		TextStrokeTransparency = 1,
		ZIndex = 6,
	})
	local caption = text(slot, {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(ICON + 16, 12),
		Text = word,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
	})
	return {
		frame = slot,
		stroke = stroke,
		cool = cool,
		icon = icon,
		count = count,
		key = keyChip,
		keyLabel = keyLabel,
		keys = keys,
		caption = caption,
		color = color,
		shown = true,
	}
end

local function buildMoves()
	local row = make("Frame", {
		Name = "Abilities",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -26),
		Size = UDim2.fromOffset(5 * ICON + 4 * 10, ICON),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, row)
	-- keys: { keyboard, controller }
	slots.sword = makeSlot("Sword", "⚔", "SWORD", Color3.fromRGB(220, 220, 230), { "LMB", "R2" })
	slots.grapple = makeSlot("Grapple", "🎣", "HOOK", Color3.fromRGB(255, 240, 120), { "F", "L2" })
	slots.polter = makeSlot("Polter", "👻", "SPIRIT", SPIRIT, { "E", "Y" })
	slots.keg = makeSlot("Keg", "💣", "KEG", Color3.fromRGB(255, 150, 90), { "G", "◀" })
	slots.throw = makeSlot("Throw", "🏈", "THROW", GOLD, { "Q", "L1" })
	for i, key in ipairs({ "throw", "keg", "polter", "grapple", "sword" }) do
		slots[key].frame.LayoutOrder = i
		slots[key].frame.Parent = row
	end

	-- Stamina: one slim bar, bottom left. It pays for sprint, dash and air jump; running is free.
	staminaBar = panel(gui, {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 40, 1, -30),
		Size = UDim2.fromOffset(200, 12),
		BackgroundColor3 = Color3.fromRGB(30, 34, 44),
	})
	staminaBar.ClipsDescendants = true
	corner(staminaBar, 6)
	staminaFill = make("Frame", {
		BackgroundColor3 = STAMINA,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, staminaBar)
	corner(staminaFill, 6)
	staminaIcon = text(gui, {
		Name = "StaminaIcon",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -24),
		Size = UDim2.fromOffset(24, 24),
		Text = "⚡",
		TextStrokeTransparency = 1,
	})
	-- The dash: a chip at the end of the bar, lit while there is stamina enough for one.
	dashChip = panel(gui, {
		Name = "Dash",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 246, 1, -26),
		Size = UDim2.fromOffset(58, 20),
		BackgroundColor3 = STAMINA,
		BackgroundTransparency = 0,
	})
	corner(dashChip, 10)
	text(dashChip, {
		Name = "Text",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 1, -4),
		Text = "C DASH",
		Font = Enum.Font.GothamBlack,
		TextColor3 = DARK,
		TextStrokeTransparency = 1,
	})

	-- The coin purse: a chip above the bar, once there is something in it.
	coinChip = panel(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -50),
		Size = UDim2.fromOffset(150, 22),
		Visible = false,
	})
	corner(coinChip, 11)
	coinLabel = text(coinChip, {
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 215, 60),
		Text = "COINS 0",
	})
end

-- Shown only while you sit in a boat: one strip. Speed and notes on top; hull, boost, drift and the ability below.
local function buildBoatPanel()
	boatPanel = panel(gui, {
		Name = "BoatPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(452, 56),
		Visible = false,
	})
	corner(boatPanel, 12)
	boatSpeed = text(boatPanel, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.fromOffset(170, 20),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SKIFF  0",
	})
	boatNote = text(boatPanel, {
		Position = UDim2.fromOffset(182, 4),
		Size = UDim2.new(1, -194, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local function meter(id, x, width, color, label)
		local back = panel(boatPanel, {
			Name = id,
			Position = UDim2.fromOffset(x, 28),
			Size = UDim2.fromOffset(width, 20),
			BackgroundColor3 = Color3.fromRGB(40, 40, 52),
		})
		back.ClipsDescendants = true
		corner(back, 6)
		local fill = make("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, back)
		corner(fill, 6)
		meters[id] = {
			back = back,
			fill = fill,
			label = text(back, {
				Position = UDim2.fromOffset(4, 2),
				Size = UDim2.new(1, -8, 1, -4),
				Text = label,
				ZIndex = 3,
				TextStrokeTransparency = 0.2,
			}),
		}
	end
	meter("hull", 10, 100, Color3.fromRGB(120, 230, 120), "HULL")
	meter("boost", 116, 100, Color3.fromRGB(255, 190, 70), "BOOST")
	meter("drift", 222, 100, DRIFT_COLORS[0], "DRIFT")
	meter("ability", 328, 114, Color3.fromRGB(196, 140, 255), "ABILITY")
end

local function buildBottom()
	objective = text(gui, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 15,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.3,
	})
	corner(objective, 14)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, objective)
	toast = text(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(560, 22),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 160),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	-- V13.1: "B · CALL A BOAT", big and gold, for a carrier at the edge of an island (the V13 playtest: make it easy
	-- to read that B brings a boat).
	shoreHint = text(gui, {
		Name = "ShoreHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -142),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 24,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.4,
		Visible = false,
		ZIndex = 6,
	})
	corner(shoreHint, 12)
	make("UIStroke", { Color = GOLD, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, shoreHint)
	make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, shoreHint)
	-- V13.1: the knockout (server/Knockout.lua).
	knockoutFrame = make("Frame", {
		Name = "Knockout",
		BackgroundColor3 = Color3.fromRGB(10, 6, 14),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
	}, gui)
	knockoutTitle = text(knockoutFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 64),
		Text = "KNOCKED OUT!",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 120, 90),
		TextStrokeTransparency = 0.2,
		ZIndex = 21,
	})
	knockoutSub = text(knockoutFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 30),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.3,
		ZIndex = 21,
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
			{ "E", "in a boat: climb out" },
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
			{ "R", "on the water: your boat's ability" },
			{ "R", "in the air: a trick (again: combo)" },
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
	"Out of health? You're KNOCKED OUT for 5 s and drop what you carry. Creatures never steal it: they hurt you.",
	"CONTROLLER: A jump / fire, X boost, B dash / drift, Y leave a boat, R1 ability / trick, L2 hook, L1 throw, R3 map.",
	"D-pad: down calls a boat, left throws a keg, right the wardrobe, up the emotes.",
}
-- V13: the Port's own card (the same H key, a different card).
local PORT_HELP = {
	"THE GOBLIN PORT",
	"Between raids. Nothing here can hurt you, and nothing you do here counts in a raid.",
	{
		{ "WALK", "aboard the airship: you're READY" },
		{ "", "everyone aboard: the raid leaves early" },
		{ "E", "Shipyard: look at a boat, sail it" },
		{ "E", "Menagerie: adopt a pet" },
		{ "E", "Madame Ragwort's: dress up" },
		{ "E", "Spyglass: watch the raid" },
		{ "P", "the wardrobe, from anywhere" },
		{ "V", "emotes" },
	},
}

local function helpTitle(parent, y, words, color)
	text(parent, {
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, 28),
		Text = words,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color or GOLD,
		ZIndex = 9,
	})
end

local function helpRow(parent, x, y, key, words, fixed)
	if key ~= "" then
		local chip = panel(parent, {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(96, 19),
			BackgroundColor3 = Color3.fromRGB(60, 60, 76),
			BackgroundTransparency = 0,
			ZIndex = 9,
		})
		text(chip, { Text = key, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, ZIndex = 10 })
	end
	text(parent, {
		Position = UDim2.fromOffset(x + 104, y),
		Size = UDim2.fromOffset(fixed and 280 or 236, 19),
		Text = words,
		Font = Enum.Font.GothamMedium,
		TextScaled = not fixed,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
	})
end

local portHelp
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
	helpTitle(help, 10, "LOOT GOBLINS")
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
			helpRow(help, columnX[side], y[side], row[1], row[2])
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
	-- The Port's card.
	portHelp = panel(helpGui, {
		Name = "PortHelp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(430, 96 + #PORT_HELP[3] * 22 + 30),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 8,
	})
	make("UIStroke", { Color = GOLD, Thickness = 2 }, portHelp)
	helpTitle(portHelp, 10, PORT_HELP[1])
	text(portHelp, {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -32, 0, 36),
		Text = PORT_HELP[2],
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 9,
	})
	for i, row in ipairs(PORT_HELP[3]) do
		helpRow(portHelp, 20, 86 + (i - 1) * 22, row[1], row[2], true)
	end
	text(portHelp, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 16),
		Text = "H closes this   ·   during a raid, H shows the raid's controls",
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
	buildMoves()
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
	banner.BackgroundTransparency = 0.2
	banner.Size = UDim2.fromOffset(680, 46)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 40) }):Play()
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

local FEED_LINES, FEED_TIME = 4, 6
function Hud.feed(message, color)
	local line = text(feedList, {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextScaled = false,
		TextWrapped = true,
		TextSize = 13,
		Text = message,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.2,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.5,
		LayoutOrder = os.clock() * 1000 // 1,
	})
	corner(line, 6)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, line)
	make("UISizeConstraint", { MaxSize = Vector2.new(340, 60) }, line) -- long lines wrap instead of being cut off
	local lines = {}
	for _, child in ipairs(feedList:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > FEED_LINES then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(FEED_TIME, function()
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

local function helpCard()
	return hudMode == "port" and portHelp or help
end

function Hud.showHelp(seconds)
	local card = helpCard()
	card.Visible = true
	if seconds then
		task.delay(seconds, function()
			card.Visible = false
		end)
	end
end

function Hud.toggleMap()
	Map.toggle()
end

function Hud.toggleHelp()
	local card = helpCard()
	local other = card == help and portHelp or help
	other.Visible = false
	card.Visible = not card.Visible
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
		-- V9: the launch window. The six-minute clock waits for it.
		timer.Text = string.format("🚀 LAUNCH %d", math.max(0, math.ceil(clockAt - now)))
		timer.TextColor3 = Color3.fromRGB(150, 230, 255)
	elseif phase == "raid" then
		local lastCall = left <= Config.LAST_CALL
		local rush = left <= Config.FINAL_RUSH
		timer.Text = (lastCall and "⏰ LAST CALL " or (rush and "🔥 RUSH " or "⏱ ")) .. clock(left)
		local pulse = lastCall and (math.sin(now * 8) > 0) or false
		timer.TextColor3 = lastCall and (pulse and Color3.fromRGB(255, 90, 90) or WHITE)
			or (rush and Color3.fromRGB(255, 170, 90) or WHITE)
	else
		timer.Text = "NEXT RAID " .. math.max(0, math.ceil(left))
		timer.TextColor3 = Color3.fromRGB(190, 190, 200)
	end

	local heat = workspace:GetAttribute("Heat") or 0
	local tier = workspace:GetAttribute("HeatTier") or 1
	local info = Config.HEAT_TIERS[tier] or Config.HEAT_TIERS[1]
	shownHeat += (heat - shownHeat) * 0.15
	heatFill.Size = UDim2.fromScale(math.clamp(shownHeat / Config.HEAT_MAX, 0, 1), 1)
	heatFill.BackgroundColor3 = info.color
	heatLabel.Text = tier > 1 and ("HEAT: " .. info.name) or ""
	heatLabel.TextColor3 = info.color
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
				status, color = "YOU!", GOLD
			else
				status = (folder:GetAttribute(id .. "Carrier") or "?")
				color = Color3.fromRGB(255, 170, 120)
			end
		elseif state == "loose" then
			status, color = "LOOSE!", Color3.fromRGB(255, 110, 110)
		elseif state == "away" then
			local returnAt = folder:GetAttribute(id .. "ReturnAt") or now
			status = string.format("back in %ds", math.max(0, math.ceil(returnAt - now)))
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
	-- Nothing loose or carried and the full list not asked for: no board at all (T shows it).
	board.Visible = shown > 0
	board.Size = UDim2.fromOffset(260, 28 + math.max(shown, 0) * BOARD_ROW)
	boardTitle.Text = boardFull and "TREASURE   T: fewer" or "ON THE MOVE   T: all"
end

function Hud.toggleBoard()
	boardFull = not boardFull
end

-- One move's icon: `ready` 0..1 (1: ready), `usable` (dimmed if not), `count` (the number on it: a cooldown's
-- seconds, how many kegs), `shown`.
local function setSlot(slot, ready, usable, count, shown)
	if slot.shown ~= shown then
		slot.shown = shown
		slot.frame.Visible = shown
	end
	if not shown then
		return
	end
	slot.cool.Size = UDim2.fromScale(1, math.clamp(1 - ready, 0, 1))
	slot.count.Text = count or ""
	slot.icon.TextTransparency = usable and 0 or 0.55
	slot.stroke.Transparency = usable and 0 or 0.6
	slot.frame.BackgroundTransparency = usable and 0.2 or 0.5
end

local function updateKeys(teaching)
	local kind = inputKind
	for _, slot in pairs(slots) do
		slot.key.Visible = kind ~= "touch"
		slot.keyLabel.Text = kind == "pad" and slot.keys[2] or slot.keys[1]
		slot.caption.Visible = teaching
	end
	local dashText = dashChip:FindFirstChild("Text")
	if dashText then
		dashText.Text = kind == "pad" and "B DASH" or (kind == "touch" and "DASH" or "C DASH")
	end
end

local function cooldownText(left)
	return left > 0.05 and tostring(math.ceil(left)) or nil
end

local function updateMoves(now, root, carrying)
	local foot = hudMode == "foot"
	-- Poltergoblin: active (a countdown), recharging, blocked by the ward, or ready. (Not at the wheel.)
	local polterEnds = player:GetAttribute("PolterEndsAt")
	local polterReady = player:GetAttribute("PolterReadyAt") or 0
	if polterEnds then
		local left = math.max(polterEnds - now, 0)
		setSlot(slots.polter, left / Config.POLTER_DURATION, true, cooldownText(left), foot and Config.POLTER_ENABLED)
	elseif now < polterReady then
		local left = polterReady - now
		setSlot(
			slots.polter,
			1 - left / Config.POLTER_COOLDOWN,
			false,
			cooldownText(left),
			foot and Config.POLTER_ENABLED
		)
	else
		setSlot(slots.polter, 1, not (root and inWard(root.Position)), nil, foot and Config.POLTER_ENABLED)
	end

	local grappleReady = player:GetAttribute("GrappleReadyAt") or 0
	if now < grappleReady then
		local left = grappleReady - now
		local length = player:GetAttribute("GrappleCooldown") or Config.GRAPPLE_COOLDOWN
		setSlot(slots.grapple, 1 - left / length, false, cooldownText(left), true)
	else
		setSlot(slots.grapple, 1, true, nil, true)
	end

	setSlot(slots.throw, 1, true, nil, carrying ~= nil)
	setSlot(slots.sword, 1, true, nil, true)
	local kegs = player:GetAttribute("Kegs") or 0
	setSlot(slots.keg, 1, kegs > 0, kegs > 1 and ("x" .. kegs) or nil, kegs > 0 and foot)

	local purse = player:GetAttribute("Coins") or 0
	local coinGold = player:GetAttribute("CoinGold") or 0
	coinChip.Visible = purse > 0 or coinGold > 0
	if coinChip.Visible then
		coinLabel.Text = coinGold >= Config.COIN_GOLD_CAP and string.format("COINS %d  (all %dg paid)", purse, coinGold)
			or string.format("COINS %d  ·  %d = 1g", purse, Config.COINS_PER_GOLD)
	end

	local winded = player:GetAttribute("Winded") == true
	local chilled = player:GetAttribute("Chilled") == true
	local stamina = player:GetAttribute("Stamina") or Config.STAMINA_MAX
	shownStamina += (stamina - shownStamina) * 0.3
	staminaFill.Size = UDim2.fromScale(math.clamp(shownStamina / Config.STAMINA_MAX, 0, 1), 1)
	local color = winded and WINDED or (chilled and CHILLED or STAMINA)
	staminaFill.BackgroundColor3 = color
	staminaIcon.TextColor3 = color
	staminaIcon.Text = chilled and "❄" or "⚡"
	-- Loot makes every stamina cost bigger, by its weight: the dash chip lights only when one is affordable.
	local dashCost = Config.DASH_COST * (1 + (LOOT_WEIGHT[carrying] or 0) * Config.CARRY_STAMINA_PER_WEIGHT)
	local canDash = stamina >= dashCost and not winded
	dashChip.BackgroundColor3 = canDash and STAMINA or Color3.fromRGB(70, 74, 86)
	dashChip.BackgroundTransparency = canDash and 0 or 0.3
end

local function setMeter(id, fraction, label, color)
	local m = meters[id]
	m.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	m.label.Text = label
	if color then
		m.fill.BackgroundColor3 = color
	end
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
	local pad = inputKind == "pad"
	-- Speed straight from the hull, so passengers see it too.
	local hull = model:FindFirstChild("Hull")
	local velocity = hull and hull.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	boatSpeed.Text = string.format("%s  %d", string.upper(spec.name), math.floor(speed + 0.5))
	setMeter(
		"hull",
		fraction,
		"HULL " .. math.floor(health),
		fraction > 0.5 and Color3.fromRGB(120, 230, 120)
			or (fraction > 0.25 and Color3.fromRGB(255, 200, 70) or Color3.fromRGB(255, 80, 70))
	)
	-- Drift: the meter fills while you slide; its colour is the burst you get for letting go.
	local full = Config.BOAT_DRIFT_CHARGE[2]
	setMeter(
		"drift",
		drive.charge / full,
		drive.level == 2 and "BIG BURST!" or (drive.level == 1 and "BURST" or (pad and "B DRIFT" or "C DRIFT")),
		DRIFT_COLORS[drive.level] or DRIFT_COLORS[0]
	)
	local boostEnds = model:GetAttribute("BoostEndsAt") or 0
	local boostReady = model:GetAttribute("BoostReadyAt") or 0
	local boostCooldown = spec.boostCooldown or Config.BOAT_BOOST_COOLDOWN
	if now < boostEnds then
		setMeter("boost", 1, "BOOSTING!")
	elseif now < boostReady then
		setMeter(
			"boost",
			1 - (boostReady - now) / boostCooldown,
			string.format("BOOST %d", math.ceil(boostReady - now))
		)
	else
		setMeter("boost", 1, pad and "X BOOST" or "SHIFT BOOST")
	end
	-- V13: the boat's own ability (only its driver can use it; passengers see it too).
	local ability = spec.ability and Config.BOAT_ABILITIES[spec.ability]
	meters.ability.back.Visible = ability ~= nil
	if ability then
		local readyAt = model:GetAttribute("AbilityReadyAt") or 0
		local info = BoatDrive.abilityInfo()
		if info then
			readyAt = info.readyAt
		end
		local key = pad and "R1" or (inputKind == "touch" and "" or "R")
		if now < readyAt then
			setMeter(
				"ability",
				1 - (readyAt - now) / ability.cooldown,
				string.format("%s %s %d", ability.glyph, ability.name, math.ceil(readyAt - now)),
				Color3.fromRGB(110, 90, 150)
			)
		else
			setMeter(
				"ability",
				1,
				string.format("%s %s %s", key, ability.glyph, ability.name),
				Color3.fromRGB(196, 140, 255)
			)
		end
	end
	local notes = {}
	if os.clock() < chainUntil then
		table.insert(notes, "HOOPS x" .. chainCount)
	end
	if model:GetAttribute("Moored") then
		table.insert(notes, "⚓ ANCHORED")
	end
	local payload = model:GetAttribute("Payload") or 0
	if payload > 0 then
		table.insert(notes, string.format("cargo -%d%%", math.floor(payload * Config.BOAT_PAYLOAD_DRAG * 100 + 0.5)))
	end
	boatNote.Text = table.concat(notes, "   ")
end

-- One short chip that says what to do next (shared teaching: client/Objective.lua). On the ship and in the air the
-- skyship's own banner speaks instead, so this chip is hidden there (see applyMode).
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

local objectiveWanted = true
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
		raids = player:GetAttribute("Raids") or 0,
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
	objective.Visible = objectiveWanted and line ~= ""
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
	if not root or not carrying or hudMode == "port" then
		waypoint.Enabled = false
		return
	end
	waypoint.Enabled = true
	local distance = math.floor((root.Position - hoardPart.Position).Magnitude)
	waypointLabel.Text = "THE HOARD  " .. distance
	waypointLabel.TextColor3 = GOLD
	waypoint.Size = UDim2.fromOffset(210, 52)
end

-- V12: the HUD follows what the goblin is doing. On the ship and in the air the skyship's banner (client
-- Skyship.lua) is the instruction, so the moves, the coin purse and the objective step aside. At the wheel the boat
-- panel takes over from the stamina bar and the moves a driver cannot make. Toasts move so they never sit on the boat
-- panel or the skyship's banner. V13: in the Port the whole raid HUD steps aside (client/PortHud.lua).
local function modeOf()
	if player:GetAttribute("Zone") == "port" then
		return "port"
	end
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

local TOAST_Y = { foot = -100, boat = -164, ship = -84, flight = -84, port = -130 }
local function applyMode(mode)
	if mode == hudMode then
		return
	end
	hudMode = mode
	local foot, boat, port = mode == "foot", mode == "boat", mode == "port"
	for key, slot in pairs(slots) do
		local want = (key == "keg" or key == "polter") and foot or (foot or boat)
		if key == "polter" and not Config.POLTER_ENABLED then
			want = false -- V13.1: switched off
		end
		slot.frame.Parent.Visible = foot or boat
		if not want then
			slot.shown = false
			slot.frame.Visible = false
		end
	end
	staminaBar.Visible = foot
	staminaIcon.Visible = foot
	dashChip.Visible = foot
	objectiveWanted = foot or boat
	objective.Visible = objectiveWanted and objective.Text ~= ""
	top.Visible = not port
	feedList.Visible = true
	if port then
		board.Visible = false
		coinChip.Visible = false
		boatPanel.Visible = false
		help.Visible = false
	else
		portHelp.Visible = false
	end
	toast.Position = UDim2.new(0.5, 0, 1, TOAST_Y[mode] or -100)
end

function Hud.mode()
	return hudMode
end

-- V13.1: knocked out for `seconds` (nil: up again). `cause` names who did it.
function Hud.knockout(seconds, cause)
	if seconds then
		knockoutUntil = workspace:GetServerTimeNow() + seconds
		knockoutCause = cause
	else
		knockoutUntil = nil
	end
end

local function updateKnockout(now)
	if not knockoutUntil or now >= knockoutUntil + 0.2 then
		knockoutFrame.Visible = false
		return
	end
	knockoutFrame.Visible = true
	local left = math.max(0, math.ceil(knockoutUntil - now))
	knockoutSub.Text = (knockoutCause and ("by " .. knockoutCause .. "  ·  ") or "")
		.. "you dropped your treasure  ·  up in "
		.. left
	knockoutFrame.BackgroundTransparency = 0.4 + 0.1 * math.sin(now * 4)
	knockoutTitle.Rotation = math.sin(now * 3) * 4 -- seeing stars
end

-- V13.1: is there sea at the edge of where this goblin stands (within Config.RECALL_HINT_EDGE)? Checked a few
-- times a second, on terrain only (a dock over the water does not count).
local edgeParams = RaycastParams.new()
edgeParams.FilterType = Enum.RaycastFilterType.Include
edgeParams.FilterDescendantsInstances = { workspace.Terrain }
edgeParams.IgnoreWater = false
local edgeCheckAt, atEdge = 0, false
local function nearSea(root, now)
	if now < edgeCheckAt then
		return atEdge
	end
	edgeCheckAt = now + 0.4
	atEdge = false
	local reach = Config.RECALL_HINT_EDGE
	for _, distance in ipairs({ reach * 0.45, reach }) do
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local from = root.Position + Vector3.new(math.cos(a) * distance, 30, math.sin(a) * distance)
			local hit = workspace:Raycast(from, Vector3.new(0, -90, 0), edgeParams)
			if hit and hit.Material == Enum.Material.Water then
				atEdge = true
				return atEdge
			end
		end
	end
	return atEdge
end

-- The boat this goblin called with B, while it is on its way (client Main tells: Hud.calledBoat).
local calledBoat
function Hud.calledBoat(model)
	calledBoat = model
end

local function myCalledBoat()
	return calledBoat and calledBoat.Parent and calledBoat:GetAttribute("Recalled") == player.UserId
end

local function updateShoreHint(now, phase, root, carrying)
	local show = false
	if phase == "raid" and root and carrying and hudMode == "foot" then
		local hoardFlat = Vector3.new(root.Position.X - hoardPart.Position.X, 0, root.Position.Z - hoardPart.Position.Z)
		if hoardFlat.Magnitude > Objective.WALK_HOME and nearSea(root, now) then
			show = true
			local ready = player:GetAttribute("RecallReadyAt") or 0
			if myCalledBoat() then
				shoreHint.Text = calledBoat:GetAttribute("RecallParked") and "YOUR BOAT IS HERE  ·  E TO CLIMB IN"
					or "YOUR BOAT IS COMING  ·  follow the green beam"
				shoreHint.TextColor3 = Color3.fromRGB(110, 255, 190)
			elseif now < ready then
				shoreHint.Text = string.format("B  ·  A BOAT IN %ds", math.ceil(ready - now))
				shoreHint.TextColor3 = WHITE
			else
				shoreHint.Text = (inputKind == "pad" and "D-PAD DOWN" or (inputKind == "touch" and "TAP BOAT" or "B"))
					.. "  ·  CALL A BOAT"
				shoreHint.TextColor3 = math.sin(now * 5) > 0 and GOLD or WHITE
			end
		end
	end
	shoreHint.Visible = show
end

local KIND_OF_INPUT = {
	[Enum.UserInputType.Touch] = "touch",
	[Enum.UserInputType.Keyboard] = "keys",
	[Enum.UserInputType.MouseButton1] = "keys",
	[Enum.UserInputType.MouseMovement] = "keys",
}
local lastKeys, lastTeaching

function Hud.update(now)
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.6, 1.15)
		helpScale.Scale = scale.Scale
	end
	local last = UserInputService:GetLastInputType()
	inputKind = KIND_OF_INPUT[last] or (string.find(last.Name, "Gamepad") and "pad") or inputKind
	local teaching = (player:GetAttribute("Raids") or 0) < Objective.TEACH_RAIDS
	if inputKind ~= lastKeys or teaching ~= lastTeaching then
		lastKeys, lastTeaching = inputKind, teaching
		updateKeys(teaching)
	end
	local phase = workspace:GetAttribute("RaidPhase") or "port"
	local phaseEndsAt = workspace:GetAttribute("PhaseEndsAt") or now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carrying = player:GetAttribute("CarryingLoot")
	applyMode(modeOf())
	if hudMode ~= "port" then
		updateTop(now, phase, phaseEndsAt)
		updateBoard(now, lootFolder())
		updateMoves(now, root, carrying)
		updateBoatPanel(now)
		updateObjective(now, phase, root, carrying)
		updateShoreHint(now, phase, root, carrying)
	else
		shoreHint.Visible = false
	end
	updateKnockout(now)
	Map.update(now)
	updateWaypoint(root, carrying)
	flushBanner()
end

return Hud

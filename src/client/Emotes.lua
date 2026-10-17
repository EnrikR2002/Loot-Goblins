-- The emote wheel (V11): V on a keyboard, D-pad up on a gamepad, or the dock's button on any screen. A ring of the
-- emotes you own; pick one (click, tap, a number key, or the left stick and A) and your goblin plays it. Moving stops
-- it. The server checks you own it and are standing still on something (server/Emotes.lua); everyone near sees it.
-- While the wheel is open its keys are taken from the game (number keys would otherwise pick tools, A would jump).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local Emotes = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local emoteRemote = remotes:WaitForChild("EmoteRequest")
local C = Ui.C

local GLYPHS = {
	emote_wave = "👋",
	emote_cackle = "😆",
	emote_salute = "🎖",
	emote_panic = "😱",
	emote_jig = "🕺",
	emote_flex = "💪",
	emote_faceplant = "😵",
}

local gui, wheel, slots = nil, nil, {}
local open = false
local choice = nil
local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

local function owned()
	local set = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		set[id] = true
	end
	local list = {}
	for _, item in ipairs(Catalog.sorted("emote")) do
		if Catalog.isFree(item) or set[item.id] then
			table.insert(list, item)
		end
	end
	return list
end

local function highlight(index)
	choice = index
	for i, slot in ipairs(slots) do
		Ui.setStyle(slot.button, i == index and "gold" or "parchment")
	end
end

local close

local function play(item)
	emoteRemote:FireServer(item.id)
	Effects.sound("blip", { speed = 1.5, volume = 0.4 })
	close()
end

local function build()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsEmotes", ResetOnSpawn = false, DisplayOrder = 15, Enabled = false },
		player:WaitForChild("PlayerGui")
	)
	wheel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 360),
		BackgroundTransparency = 1,
	}, gui)
	Ui.make("UIScale", { Scale = 1 }, wheel)
	local hub = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = C.wood,
		BackgroundTransparency = 0.1,
	}, wheel)
	Ui.corner(hub, 60)
	Ui.stroke(hub, C.goldDeep, 3)
	Ui.label(hub, {
		Size = UDim2.fromScale(1, 1),
		Text = "EMOTES\n(V closes)",
		Font = Ui.TITLE,
		TextSize = 17,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
		Name = "HubLabel",
	})
end

local function populate()
	for _, slot in ipairs(slots) do
		slot.button:Destroy()
	end
	table.clear(slots)
	local list = owned()
	local count = math.min(#list, 8)
	for i = 1, count do
		local item = list[i]
		local angle = (i - 1) / count * math.pi * 2 - math.pi / 2
		local button = Ui.button(wheel, {
			text = "",
			style = "parchment",
			size = UDim2.fromOffset(100, 84),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, math.cos(angle) * 134, 0.5, math.sin(angle) * 134),
			name = item.id,
		}, function()
			play(item)
		end)
		Ui.label(button, {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 40),
			Text = GLYPHS[item.id] or "★",
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.label(button, {
			Position = UDim2.new(0, 4, 1, -32),
			Size = UDim2.new(1, -8, 0, 28),
			Text = item.name,
			Font = Ui.TITLE,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.label(button, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(16, 16),
			Text = tostring(i),
			TextSize = 12,
			Font = Ui.BLACK,
			TextColor3 = C.inkSoft,
		})
		table.insert(slots, { button = button, item = item, angle = angle })
	end
end

close = function()
	if not open then
		return
	end
	open = false
	gui.Enabled = false
	ContextActionService:UnbindAction("LootGoblinsEmoteWheel")
end

local function sinkKeys(_, state, input)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	for i, key in ipairs(KEYS) do
		if input.KeyCode == key and slots[i] then
			play(slots[i].item)
			return Enum.ContextActionResult.Sink
		end
	end
	if input.KeyCode == Enum.KeyCode.ButtonA and choice and slots[choice] then
		play(slots[choice].item)
	elseif input.KeyCode == Enum.KeyCode.ButtonB then
		close()
	end
	return Enum.ContextActionResult.Sink
end

local function openWheel()
	if open then
		close()
		return
	end
	open = true
	populate()
	choice = nil
	gui.Enabled = true
	local scale = wheel:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local keys = table.clone(KEYS)
	table.insert(keys, Enum.KeyCode.ButtonA)
	table.insert(keys, Enum.KeyCode.ButtonB)
	table.insert(keys, Enum.KeyCode.Thumbstick1) -- choosing with the stick must not walk the goblin away
	ContextActionService:BindActionAtPriority(
		"LootGoblinsEmoteWheel",
		sinkKeys,
		false,
		Enum.ContextActionPriority.High.Value + 30,
		table.unpack(keys)
	)
end

function Emotes.toggle()
	openWheel()
end

function Emotes.start(dock)
	build()
	if dock then
		local button = Ui.button(dock, {
			text = "😀",
			size = UDim2.fromOffset(60, 60),
			textSize = 30,
			radius = 30,
			order = 2,
			style = "parchment",
			font = Ui.BOLD,
		}, function()
			openWheel()
		end)
		button.Name = "Emotes"
		Ui.label(button, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.fromOffset(58, 16),
			Text = "V",
			TextSize = 12,
			Font = Ui.TITLE,
			TextColor3 = C.inkSoft,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.DPadUp then
			openWheel()
		end
	end)
	-- The left stick points at a slot while the wheel is open.
	UserInputService.InputChanged:Connect(function(input)
		if open and input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.5 and #slots > 0 then
			local angle = math.atan2(-input.Position.Y, input.Position.X)
			local best, bestGap = nil, math.huge
			for i, slot in ipairs(slots) do
				local gap = math.abs(math.atan2(math.sin(slot.angle - angle), math.cos(slot.angle - angle)))
				if gap < bestGap then
					best, bestGap = i, gap
				end
			end
			if best ~= choice then
				highlight(best)
			end
		end
	end)
end

return Emotes

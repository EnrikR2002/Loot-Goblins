-- The end of a raid (V11): who won, the gold table, and what YOU take away: the Shinies the raid paid and why, the
-- balance, and any trophy earned. Shown at the side of the screen (V13: as everyone arrives home in the Goblin Port, so
-- the podium and the winner's dance stay visible), and gone after Results.SHOW_FOR seconds or when the next raid
-- starts. A button opens the wardrobe for anyone who wants to spend; nothing forces it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Ui)

local Results = {}
Results.SHOW_FOR = 22 -- V13: seconds the card stays (the Port's countdown is 60): brief, then the town is yours
local shownToken = 0

local player = Players.LocalPlayer
local C = Ui.C

local gui, card
local reward, rewardAt = nil, 0
local openWardrobe -- set by Main: opens the wardrobe

local function clear()
	if card then
		card:Destroy()
		card = nil
	end
end

local function chip(parent, text, color, order)
	local label = Ui.label(parent, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = text,
		Font = Ui.TITLE,
		TextSize = 14,
		TextColor3 = C.ink,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.corner(label, 13)
	Ui.pad(label, 10, 0, 10, 0)
	return label
end

local function render(results, winners)
	clear()
	card = Ui.make("Frame", {
		Name = "RaidResults",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.56, 0),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.parchment,
	}, gui)
	Ui.corner(card, 16)
	Ui.stroke(card, C.goldDeep, 3)
	Ui.pad(card, 14, 12, 14, 14)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	local scale = Ui.make("UIScale", { Scale = 0.8 }, card)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local title
	if #winners == 0 then
		title = "RAID OVER: NO WINNER"
	elseif #winners == 1 then
		title = "👑 " .. string.upper(winners[1]) .. " WINS!"
	else
		title = "👑 TIE: " .. string.upper(table.concat(winners, " & "))
	end
	Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = title,
		Font = Ui.TITLE,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
	})
	-- The gold table (top five, and you if you are further down).
	local mine
	for i, entry in ipairs(results) do
		if entry.userId == player.UserId then
			mine = i
		end
	end
	local order = 10
	for i, entry in ipairs(results) do
		if i <= 5 or i == mine then
			order += 1
			local row = Ui.make("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = entry.userId == player.UserId and C.goldPale or C.parchmentDark,
				LayoutOrder = order,
			}, card)
			Ui.corner(row, 8)
			Ui.label(row, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -110, 1, 0),
				Text = string.format("%d.  %s", i, entry.name),
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			Ui.label(row, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Size = UDim2.fromOffset(100, 26),
				Text = entry.gold .. " gold",
				Font = Ui.TITLE,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end
	-- What you take away.
	local mineBox = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 100,
		Name = "Reward",
	}, card)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, mineBox)
	Results.fillReward(mineBox)
	-- Buttons and the countdown.
	local buttons =
		Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 200 }, card)
	Ui.button(buttons, { text = "OPEN WARDROBE", size = UDim2.new(0.62, -4, 1, 0), textSize = 17 }, function()
		clear()
		if openWardrobe then
			openWardrobe()
		end
	end)
	Ui.button(buttons, {
		text = "CLOSE",
		style = "ghost",
		size = UDim2.new(0.38, -4, 1, 0),
		position = UDim2.new(0.62, 4, 0, 0),
		textSize = 17,
	}, function()
		clear()
	end)
	local countdown = Ui.label(card, {
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		Font = Ui.BODY,
		TextSize = 13,
		TextColor3 = C.inkSoft,
		LayoutOrder = 300,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local this = card
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if card ~= this or not this.Parent then
			connection:Disconnect()
			return
		end
		local left = (workspace:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
		countdown.Text = left > 0 and string.format("Next raid in %d · walk aboard the Little Goblin", math.ceil(left))
			or ""
	end)
end

function Results.fillReward(box)
	for _, child in ipairs(box:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not reward or time() - rewardAt > 15 then
		return
	end
	if reward.late then
		Ui.label(box, {
			Size = UDim2.new(1, 0, 0, 36),
			Text = "You joined too late in the raid to earn Shinies from it. The next one is all yours.",
			Font = Ui.BODY,
			TextSize = 13,
			TextColor3 = C.inkSoft,
			LayoutOrder = 1,
		})
		return
	end
	local b = reward.breakdown or {}
	local head = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
	Ui.gem(head, 16, UDim2.new(0, 6, 0.5, 0))
	Ui.label(head, {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Text = string.format("+%d SHINIES  (now %d)", b.total or 0, reward.balance or 0),
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.goldDeep,
	})
	local chips = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, box)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 26),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	chip(chips, "Played  +" .. (b.participation or 0), C.parchmentDark, 1)
	chip(chips, string.format("Gold banked  +%d", b.gold or 0), C.parchmentDark, 2)
	if (b.win or 0) > 0 then
		chip(chips, "Won the raid  +" .. b.win, C.goldPale, 3)
	end
	if (b.underdog or 0) > 0 then
		chip(chips, "Underdog  +" .. b.underdog, C.parchmentDark, 4)
	end
	if (b.deeds or 0) > 0 then
		chip(chips, "Deeds  +" .. b.deeds, C.goldPale, 4) -- V13: a steal, an escape, a snatch, clean tricks
	end
	if (b.capped or 0) > 0 then
		chip(chips, string.format("Raid cap %d", Config.PROGRESS.RAID_CAP), C.parchmentDark, 5)
	end
	for i, unlocked in ipairs(reward.achievements or {}) do
		Ui.label(box, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = "🏆 "
				.. unlocked.name
				.. "  +"
				.. unlocked.shinies
				.. (unlocked.rewardName and (": " .. unlocked.rewardName .. "!") or ""),
			Font = Ui.TITLE,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(130, 70, 190),
			LayoutOrder = 10 + i,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	if not reward.kept then
		Ui.label(box, {
			Size = UDim2.new(1, 0, 0, 30),
			Text = "Your saved progress is not open yet: these are added to it as soon as it is.",
			Font = Ui.BODY,
			TextSize = 12,
			TextColor3 = C.danger,
			LayoutOrder = 50,
		})
	end
end

-- The server's personal payout (arrives just before RaidEnd).
function Results.reward(p)
	reward, rewardAt = p, time()
	local box = card and card:FindFirstChild("Reward")
	if box then
		Results.fillReward(box)
	end
end

function Results.show(results, winners)
	render(results or {}, winners or {})
	shownToken += 1
	local token = shownToken
	task.delay(Results.SHOW_FOR, function()
		if token == shownToken and card then
			TweenService:Create(card, TweenInfo.new(0.4), { Position = card.Position + UDim2.fromOffset(420, 0) })
				:Play()
			task.delay(0.45, function()
				if token == shownToken then
					clear()
				end
			end)
		end
	end)
end

function Results.hide()
	clear()
end

function Results.start(onOpenWardrobe)
	openWardrobe = onOpenWardrobe
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsResults", ResetOnSpawn = false, DisplayOrder = 7 },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local scale = Ui.make("UIScale", {}, gui)
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.75, 1.15) -- readable on a phone
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
end

return Results

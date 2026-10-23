-- WHAT'S NEXT (V13.3): a small card on the left as a goblin comes home from a raid, under the next raid's chaos card,
-- with the few things most worth doing next (server/Prospects.lua chooses them): a quest that moved or finished, the
-- boat or pet you can afford now or are saving for, a record or a place on a board, the next raid's chaos, and one
-- thing to try in the Port (SHOW ME points at it). It never blocks anything, slides away by itself, and × closes it.
-- V13.4: the raid boards as places ("#4 BIGGEST HAUL ▲5"), and RAID AGAIN first, gold and gently pulsing.
-- Also the Port screen's one-line goal (◆ 188 to the Wraith), worked out here from what the goblin owns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local NextUp = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local raidRemote = remotes:WaitForChild("RaidRequest")
local C = Ui.C
local rgb = Color3.fromRGB

local gui, card, token = nil, nil, 0
local openQuests -- set by Main: opens the Quest Board panel
local pointAt -- set by Main: (position, text) points the way to a venue

local function close()
	if card then
		card:Destroy()
		card = nil
	end
end

local function line(parent, icon, text, order, color, size)
	local frame = Ui.make(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, size or 24), BackgroundTransparency = 1, LayoutOrder = order },
		parent
	)
	Ui.label(frame, {
		Size = UDim2.fromOffset(26, size or 24),
		Text = icon,
		Font = Ui.TITLE,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.label(frame, {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Text = text,
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = color or C.white,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	return frame
end

local WHY = { quest = "a quest wants it", new = "you haven't tried it yet", best = "beat your best" }

function NextUp.show(p)
	close()
	token += 1
	local mine = token
	-- After the results card has had its moment.
	task.delay(1.6, function()
		if token ~= mine or player:GetAttribute("Zone") == "raid" then
			return
		end
		card = Ui.make("Frame", {
			Name = "NextUp",
			Position = UDim2.fromOffset(12, 172),
			Size = UDim2.fromOffset(300, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.night,
			BackgroundTransparency = 0.15,
		}, gui)
		Ui.corner(card, 14)
		Ui.stroke(card, C.gold, 2)
		Ui.pad(card, 12, 8, 12, 10)
		Ui.make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, card)
		local head =
			Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0 }, card)
		Ui.label(head, {
			Size = UDim2.new(1, -30, 1, 0),
			Text = string.format("WHAT'S NEXT  ·  +%d ◆  (%d)", p.shinies or 0, p.balance or 0),
			Font = Ui.TITLE,
			TextSize = 15,
			TextColor3 = C.goldPale,
		})
		Ui.button(head, {
			text = "×",
			style = "ghost",
			size = UDim2.fromOffset(24, 22),
			position = UDim2.new(1, -24, 0, 1),
			textSize = 16,
		}, close)
		local order = 1
		for _, q in ipairs(p.quests or {}) do
			order += 1
			line(
				card,
				q.done and "✔" or "📜",
				q.done and (q.text .. ": CLAIM +" .. q.shinies .. " at the board")
					or string.format("%s  %d/%d", q.text, q.n, q.goal),
				order,
				q.done and rgb(150, 240, 130) or C.white,
				q.done and 34 or 24
			)
		end
		local goal = p.goal
		if goal then
			order += 1
			local icon = goal.kind == "boat" and "⛵" or "🐾"
			if goal.short <= 0 then
				line(
					card,
					icon,
					string.format(
						"You can afford the %s! (%s)",
						goal.name,
						goal.kind == "boat" and "the Shipyard" or "the Menagerie"
					),
					order,
					C.gold
				)
			else
				line(
					card,
					icon,
					string.format(
						"%s: %d to go (about %d raid%s)",
						goal.name,
						goal.short,
						goal.raids,
						goal.raids == 1 and "" or "s"
					),
					order
				)
			end
		end
		for _, record in ipairs(p.records or {}) do
			order += 1
			if record.kind == "rank" then
				-- V13.4: a place on a raid board, and whether this raid moved it up.
				local up = record.from == nil or record.to < record.from
				line(
					card,
					record.icon or "🏆",
					string.format(
						"#%d %s%s",
						record.to,
						record.name or "",
						up and (record.from and string.format("  ▲%d", record.from - record.to) or "  NEW!") or ""
					),
					order,
					up and rgb(255, 214, 90) or rgb(255, 200, 120)
				)
			else
				line(card, "🏆", record.text, order, rgb(255, 200, 120))
			end
		end
		local chaos = workspace:GetAttribute("ChaosName")
		if chaos then
			order += 1
			line(card, workspace:GetAttribute("ChaosIcon") or "☄", "Next raid: " .. chaos, order, rgb(255, 170, 110))
		end
		local suggest = p.suggest
		local buttons =
			Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 50 }, card)
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, buttons)
		if suggest and PortGames.BY_ID[suggest.game] then
			order += 1
			local def = PortGames.BY_ID[suggest.game]
			line(
				card,
				def.icon,
				string.format("Try %s: %s", def.name, WHY[suggest.why] or ""),
				order,
				rgb(150, 230, 255)
			)
			Ui.button(
				buttons,
				{ text = "SHOW ME", style = "wood", size = UDim2.fromOffset(80, 32), textSize = 12, order = 1 },
				function()
					if pointAt then
						pointAt(PortGames.VENUES[def.id].sign, def.icon .. " " .. string.upper(def.name))
					end
				end
			)
		end
		Ui.button(
			buttons,
			{ text = "📜 QUESTS", style = "wood", size = UDim2.fromOffset(76, 32), textSize = 12, order = 2 },
			function()
				if openQuests then
					openQuests()
				end
			end
		)
		if not player:GetAttribute("RaidOptIn") then
			-- V13.4: the card's main button, first and gold: the reason to begin another.
			local again = Ui.button(buttons, {
				text = "⚔ RAID AGAIN",
				style = "gold",
				size = UDim2.fromOffset(106, 32),
				textSize = 13,
				order = 0,
				name = "RaidAgain",
			}, function()
				raidRemote:FireServer("in")
				Effects.chime({ 1, 1.26, 1.5 }, 0.5)
				close()
			end)
			local pulse = Ui.make("UIScale", {}, again)
			TweenService:Create(
				pulse,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.06 }
			):Play()
		end
		card.Position = UDim2.fromOffset(-320, 172)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(12, 172) })
			:Play()
		Effects.sound("blip", { speed = 1.1, volume = 0.4 })
		local this = card
		task.delay(32, function()
			if card == this then
				TweenService:Create(card, TweenInfo.new(0.4), { Position = UDim2.fromOffset(-320, 172) }):Play()
				task.delay(0.45, function()
					if card == this then
						close()
					end
				end)
			end
		end)
	end)
end

function NextUp.hide()
	token += 1
	close()
end

-- The goal for the Port screen: the boat you can afford now, or the nearest one (or pet) to save for.
function NextUp.goalText()
	local owned = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		owned[id] = true
	end
	local balance = player:GetAttribute("Shinies") or 0
	local afford, nearest
	for _, slot in ipairs({ "boat", "pet" }) do
		for _, item in ipairs(Catalog.bySlot[slot] or {}) do
			if Catalog.forSale(item) and not owned[item.id] and not Catalog.isFree(item) then
				if item.price <= balance then
					if
						not afford
						or (slot == "boat" and afford.slot ~= "boat")
						or (slot == afford.slot and item.price > afford.price)
					then
						afford = item
					end
				elseif
					not nearest
					or (slot == "boat" and nearest.slot ~= "boat" and item.price - balance <= (nearest.price - balance) * 2)
					or (slot == nearest.slot and item.price < nearest.price)
				then
					nearest = item
				end
			end
		end
	end
	if afford then
		return string.format("★ You can afford the %s!", afford.name), afford
	elseif nearest then
		return string.format("◆ %d to the %s", nearest.price - balance, nearest.name), nearest
	end
	return nil
end

function NextUp.start(onOpenQuests, onPointAt)
	openQuests = onOpenQuests
	pointAt = onPointAt
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsNextUp", ResetOnSpawn = false, DisplayOrder = 5 },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local scale = Ui.make("UIScale", {}, gui)
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.15)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
end

return NextUp

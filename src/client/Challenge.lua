-- Challenges on this client (V13.3): ask a goblin in the Port to a game, answer an invitation, rematch.
--
--   THE PICKER     the Port screen's ⚔ CHALLENGE chip: the goblins in the Port, nearest first (friends starred), and
--                  the seven games. Pick one of each, SEND.
--   AN INVITATION  "⚔ Ninety challenges you to the Tiny Boat Regatta!" with ACCEPT and NO THANKS and the time left
--                  (a controller starts on ACCEPT). Silence is a no.
--   AFTERWARDS     the result in a banner; REMATCH on the results card (both must press it).
-- The server decides everything (server/Challenges.lua); this only asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local Challenge = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local challengeRemote = remotes:WaitForChild("ChallengeRequest")
local C = Ui.C
local rgb = Color3.fromRGB

local hud, playHud
local gui, picker, list, gameRow, sendButton
local chosenPlayer, chosenGame = nil, "regatta"
local invite, inviteCard, inviteBar
local sentPill
local friends = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function isFriend(userId)
	if friends[userId] == nil then
		friends[userId] = false
		task.spawn(function()
			local ok, result = pcall(function()
				return player:IsFriendsWith(userId)
			end)
			friends[userId] = ok and result == true
		end)
	end
	return friends[userId]
end

-- The picker ---------------------------------------------------------------------------------------------------------------
local function candidates()
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local out = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("Zone") ~= "raid" then
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local d = (mine and root) and (root.Position - mine.Position).Magnitude or 99999
			table.insert(out, {
				player = other,
				distance = d,
				friend = isFriend(other.UserId),
				busy = other:GetAttribute("PlaySession") ~= nil,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.friend ~= b.friend then
			return a.friend
		end
		return a.distance < b.distance
	end)
	return out
end

local function renderPicker()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local people = candidates()
	for i, entry in ipairs(people) do
		local selected = chosenPlayer == entry.player
		local text = string.format(
			"%s%s%s",
			entry.friend and "★ " or "",
			entry.player.DisplayName,
			entry.busy and "  (playing)"
				or (entry.distance < 9999 and string.format("  ·  %d studs", entry.distance) or "")
		)
		Ui.button(list, {
			text = text,
			style = selected and "gold" or "parchment",
			size = UDim2.new(1, -8, 0, 34),
			textSize = 15,
			order = i,
		}, function()
			chosenPlayer = entry.player
			renderPicker()
		end)
	end
	if #people == 0 then
		Ui.label(list, {
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Nobody else is in the Port right now.",
			Font = Ui.BODY,
			TextSize = 14,
			TextColor3 = C.inkSoft,
			TextWrapped = true,
		})
	end
	for _, child in ipairs(gameRow:GetChildren()) do
		if child:IsA("TextButton") then
			Ui.setStyle(child, child.Name == chosenGame and "gold" or "wood")
		end
	end
	sendButton.Text = chosenPlayer and string.format("⚔ CHALLENGE %s", string.upper(chosenPlayer.DisplayName))
		or "PICK A GOBLIN"
	Ui.setStyle(sendButton, chosenPlayer and "gold" or "ghost")
end

function Challenge.open()
	picker.Visible = true
	chosenPlayer = nil
	renderPicker()
	Effects.sound("blip", { speed = 1.2, volume = 0.4 })
end

function Challenge.close()
	picker.Visible = false
end

function Challenge.isOpen()
	return picker ~= nil and picker.Visible
end

-- An invitation --------------------------------------------------------------------------------------------------------------
local function hideInvite()
	invite = nil
	if inviteCard then
		inviteCard.Visible = false
	end
end

function Challenge.invited(p)
	invite = p
	local def = PortGames.BY_ID[p.game]
	inviteCard.Visible = true
	inviteCard.Message.Text =
		string.format("⚔ %s challenges you to %s!", p.from or "?", def and (def.icon .. " " .. def.name) or "a game")
	Effects.chime({ 1, 1.5, 1, 1.5 }, 0.7)
	Ui.focus(inviteCard.Buttons.Accept)
end

function Challenge.closed(p)
	if invite and invite.id == p.id then
		hideInvite()
	end
	if p.outgoing then
		sentPill.Visible = false
		if p.why == "expired" then
			hud.toast("No answer: the challenge ran out.")
		elseif p.why == "declined" then
			hud.toast("They said no thanks this time.")
		end
	elseif p.why == "expired" or p.why == "cancelled" then
		hud.toast(p.why == "expired" and "The challenge ran out." or "The challenge was taken back.")
	end
end

function Challenge.sent(p)
	local def = PortGames.BY_ID[p.game]
	sentPill.Visible = true
	sentPill.Label.Text = string.format("⚔ Waiting for %s (%s)...", p.to or "?", def and def.name or "")
	Challenge.close()
end

function Challenge.started(p)
	sentPill.Visible = false
	hideInvite()
	if playHud then
		playHud.lastChallenge = p.id
	end
	local def = PortGames.BY_ID[p.game]
	hud.banner(
		string.format(
			"CHALLENGE: YOU vs %s  ·  %s",
			string.upper(p.opponent or "?"),
			def and string.upper(def.name) or ""
		),
		rgb(255, 120, 90),
		3.5,
		3
	)
	Effects.chime({ 1, 1.26, 1.5, 2 }, 0.8)
end

function Challenge.result(p)
	if playHud then
		playHud.lastChallenge = p.id
	end
	local text, color
	if p.result == "win" then
		text = string.format(
			"YOU BEAT %s!%s",
			string.upper(p.opponent or "?"),
			(p.shinies or 0) > 0 and string.format("  +%d ◆", p.shinies) or ""
		)
		color = C.gold
	elseif p.result == "lose" then
		text = string.format("%s WINS THIS ONE! REMATCH?", string.upper(p.opponent or "?"))
		color = rgb(255, 150, 120)
	elseif p.result == "tie" then
		text = "A TIE!" .. ((p.shinies or 0) > 0 and string.format("  +%d ◆", p.shinies) or "")
		color = C.goldPale
	else
		text = string.format("%s LEFT: THE WIN IS YOURS (no Shinies for a walkover)", string.upper(p.opponent or "?"))
		color = C.white
	end
	hud.banner(text, color, 4, 3)
end

function Challenge.rematchAsked(p)
	hud.banner(
		string.format("%s WANTS A REMATCH! (REMATCH on your results)", string.upper(p.from or "?")),
		C.gold,
		4,
		3
	)
end

-- Building ---------------------------------------------------------------------------------------------------------------------
local function build()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsChallenge", ResetOnSpawn = false, DisplayOrder = 10 },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local scale = Ui.make("UIScale", {}, gui)
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	-- The picker.
	picker = Ui.make("Frame", {
		Name = "ChallengePicker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 470),
		BackgroundColor3 = C.wood,
		Visible = false,
	}, gui)
	Ui.corner(picker, 18)
	Ui.stroke(picker, C.goldDeep, 3)
	Ui.label(picker, {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Text = "⚔ CHALLENGE A GOBLIN",
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.goldPale,
	})
	Ui.button(picker, {
		text = "X",
		style = "danger",
		size = UDim2.fromOffset(38, 34),
		position = UDim2.new(1, -50, 0, 10),
		textSize = 18,
	}, Challenge.close)
	local paper = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 0, 230),
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, picker)
	Ui.corner(paper, 12)
	list = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, paper)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	gameRow = Ui.make(
		"Frame",
		{ Position = UDim2.fromOffset(14, 290), Size = UDim2.new(1, -28, 0, 100), BackgroundTransparency = 1 },
		picker
	)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(118, 44),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, gameRow)
	for i, def in ipairs(PortGames.GAMES) do
		local b = Ui.button(gameRow, {
			text = def.icon .. " " .. def.short,
			style = "wood",
			size = UDim2.fromOffset(118, 44),
			textSize = 14,
			order = i,
			name = def.id,
		}, function()
			chosenGame = def.id
			renderPicker()
		end)
		local _ = b
	end
	sendButton = Ui.button(picker, {
		text = "PICK A GOBLIN",
		style = "ghost",
		size = UDim2.new(1, -28, 0, 44),
		position = UDim2.new(0, 14, 1, -58),
		textSize = 18,
		name = "SendChallenge",
	}, function()
		if chosenPlayer and chosenPlayer.Parent then
			challengeRemote:FireServer("ask", chosenPlayer.UserId, chosenGame)
		end
	end)
	-- An invitation.
	inviteCard = Ui.make("Frame", {
		Name = "Invitation",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(440, 118),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	Ui.corner(inviteCard, 16)
	Ui.stroke(inviteCard, rgb(255, 120, 90), 3)
	Ui.label(inviteCard, {
		Name = "Message",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 44),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 19,
		TextWrapped = true,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local buttons = Ui.make("Frame", {
		Name = "Buttons",
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 0, 40),
		BackgroundTransparency = 1,
	}, inviteCard)
	Ui.button(
		buttons,
		{ text = "⚔ ACCEPT", size = UDim2.new(0.55, -4, 1, 0), textSize = 18, name = "Accept" },
		function()
			if invite then
				challengeRemote:FireServer("answer", invite.id, true)
				hideInvite()
			end
		end
	)
	Ui.button(buttons, {
		text = "NO THANKS",
		style = "ghost",
		size = UDim2.new(0.45, -4, 1, 0),
		position = UDim2.new(0.55, 4, 0, 0),
		textSize = 16,
		name = "Decline",
	}, function()
		if invite then
			challengeRemote:FireServer("answer", invite.id, false)
			hideInvite()
		end
	end)
	local barBack = Ui.make(
		"Frame",
		{ Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.woodMid },
		inviteCard
	)
	Ui.corner(barBack, 3)
	inviteBar = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 120, 90) }, barBack)
	Ui.corner(inviteBar, 3)
	-- The pill while waiting for an answer.
	sentPill = Ui.make("Frame", {
		Name = "ChallengeSent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(420, 36),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	Ui.corner(sentPill, 18)
	Ui.label(sentPill, {
		Name = "Label",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -120, 1, 0),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = C.white,
	})
	Ui.button(sentPill, {
		text = "CANCEL",
		style = "ghost",
		size = UDim2.fromOffset(90, 28),
		position = UDim2.new(1, -96, 0.5, -14),
		textSize = 13,
	}, function()
		challengeRemote:FireServer("cancel")
		sentPill.Visible = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			picker.Visible
			and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.X))
		then
			Challenge.close()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if invite and inviteCard.Visible then
			local left = (invite.expiresAt or 0) - now()
			inviteBar.Size = UDim2.fromScale(math.clamp(left / 20, 0, 1), 1)
			if left <= 0 then
				hideInvite()
			end
		end
	end)
end

function Challenge.start(hudModule, playHudModule)
	hud = hudModule
	playHud = playHudModule
	build()
end

return Challenge

-- The Goblin Port's own screen (V13). While a goblin is in the Port (the Zone attribute) the raid HUD steps aside
-- (client/Hud.lua) and this small, calm screen speaks instead:
--   * the top sign: the countdown to the next raid and how many goblins are aboard the Little Goblin (walking up its
--     gangplank is being READY; everyone aboard brings the raid forward), or, while a raid is running, how long it has
--     left with WATCH and JOIN buttons (join only while enough of it is left: shared/Lobby.canJoinLate);
--   * top right: your Shinies, the boat you will sail and the pet you have out (each opens its page of the wardrobe);
--   * the departures board on the pier and a marker over the gangplank say the same thing in the world;
--   * a short fade from black when a goblin is moved between the raid and the Port, so the teleport is not a pop.
-- Everything it shows comes from replicated attributes; JOIN and WATCH ask the server (PortRequest), which decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local PortHud = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local portRemote = remotes:WaitForChild("PortRequest")
local C = Ui.C

local gui, scaler, sign, countdown, subline, buttons, joinButton
local wallet, shiniesLabel, boatChip, petChip
local fade
local plankMarker, plankLabel
local openShop -- set by Main: (focus) -> opens the wardrobe at a page

local function now()
	return workspace:GetServerTimeNow()
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function inPort()
	return player:GetAttribute("Zone") ~= "raid"
end

local function portCore()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("PortCore")
end

-- Building ---------------------------------------------------------------------------------------------------------
local function chip(parent, order, onClick)
	local b = Ui.button(parent, {
		text = "",
		style = "wood",
		size = UDim2.fromOffset(196, 34),
		order = order,
		textSize = 15,
		font = Ui.BOLD,
		radius = 17,
	}, onClick)
	b.TextXAlignment = Enum.TextXAlignment.Left
	Ui.pad(b, 14, 0, 10, 0)
	b.TextTruncate = Enum.TextTruncate.AtEnd
	return b
end

local function build()
	gui = Ui.make("ScreenGui", {
		Name = "LootGoblinsPort",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local root = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	scaler = Ui.make("UIScale", {}, root)

	-- The sign, top centre: a wooden board with the countdown.
	sign = Ui.make("Frame", {
		Name = "Sign",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(440, 92),
		BackgroundColor3 = C.wood,
	}, root)
	Ui.corner(sign, 16)
	Ui.stroke(sign, C.goldDeep, 3)
	Ui.make("UIGradient", { Color = ColorSequence.new(C.woodMid, C.wood), Rotation = 90 }, sign)
	Ui.label(sign, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "THE GOBLIN PORT",
		Font = Ui.TITLE,
		TextSize = 15,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	countdown = Ui.label(sign, {
		Name = "Countdown",
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 38),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 32,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(countdown, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	subline = Ui.label(sign, {
		Name = "Subline",
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = C.parchment,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- WATCH and JOIN, under the sign while a raid is running.
	buttons = Ui.make("Frame", {
		Name = "RaidButtons",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(380, 46),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buttons)
	Ui.button(buttons, {
		text = "👁  WATCH",
		style = "wood",
		size = UDim2.fromOffset(150, 44),
		order = 1,
		textSize = 20,
		name = "Watch",
	}, function()
		portRemote:FireServer("spectate", "start")
		Effects.sound("blip", { speed = 1.2, volume = 0.4 })
	end)
	joinButton = Ui.button(buttons, {
		text = "⚔  JOIN RAID",
		style = "gold",
		size = UDim2.fromOffset(180, 44),
		order = 2,
		textSize = 20,
		name = "Join",
	}, function()
		portRemote:FireServer("join")
		Effects.sound("blip", { speed = 1.4, volume = 0.5 })
	end)

	-- Top right: Shinies, your boat, your pet.
	wallet = Ui.make("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(196, 116),
		BackgroundTransparency = 1,
	}, root)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, wallet)
	local pill = Ui.make("Frame", {
		Size = UDim2.fromOffset(196, 38),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.2,
		LayoutOrder = 0,
	}, wallet)
	Ui.corner(pill, 19)
	Ui.stroke(pill, C.gold, 2)
	Ui.gem(pill, 15, UDim2.new(0, 20, 0.5, 0))
	shiniesLabel = Ui.label(pill, {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = "0",
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.goldPale,
	})
	boatChip = chip(wallet, 1, function()
		if openShop then
			local item = Catalog.get(Catalog.decodeLook(player:GetAttribute("Look")).boat)
			openShop("boat:" .. (item and item.class or "skiff"))
		end
	end)
	boatChip.Name = "BoatChip"
	petChip = chip(wallet, 2, function()
		if openShop then
			openShop("pet")
		end
	end)
	petChip.Name = "PetChip"

	-- The fade, over everything (a goblin moved between the raid and the Port).
	fade = Ui.make(
		"Frame",
		{
			Name = "Fade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 50,
		},
		Ui.make("ScreenGui", {
			Name = "LootGoblinsFade",
			ResetOnSpawn = false,
			DisplayOrder = 40,
			IgnoreGuiInset = true,
		}, player:WaitForChild("PlayerGui"))
	)
end

-- The marker over the gangplank: where to walk to be ready. Hidden once you are aboard.
local function buildMarker()
	local core = portCore()
	local plank = core and core:FindFirstChild("Gangplank")
	if not plank or plankMarker then
		return
	end
	plankMarker = Ui.make("BillboardGui", {
		Name = "ReadyMarker",
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(220, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 10, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 420,
		Adornee = plank,
	}, player:WaitForChild("PlayerGui"))
	plankLabel = Ui.label(plankMarker, {
		Size = UDim2.fromScale(1, 1),
		Text = "⬆ WALK ABOARD TO GET READY",
		Font = Ui.TITLE,
		TextScaled = true,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(plankLabel, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
end

-- The departures board on the pier (built by the server, written here).
local lastBoardText
local function writeBoard(textValue)
	if textValue == lastBoardText then
		return
	end
	local core = portCore()
	local board = core and core:FindFirstChild("DepartureBoard")
	if not board then
		return
	end
	lastBoardText = textValue
	for _, face in ipairs(board:GetChildren()) do
		local label = face:IsA("SurfaceGui") and face:FindFirstChild("Text")
		if label then
			label.Text = textValue
		end
	end
end

-- Each frame -----------------------------------------------------------------------------------------------------------
local shownShinies = nil
local function update()
	local here = inPort()
	gui.Enabled = here and not player:GetAttribute("Spectating")
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scaler.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.15)
	end
	local t = now()
	local phase = workspace:GetAttribute("RaidPhase") or "port"
	local status = Lobby.status(phase, t, workspace:GetAttribute("PhaseEndsAt"), player:GetAttribute("InRaid") == true)
	local count = workspace:GetAttribute("PortCount") or 0
	local ready = workspace:GetAttribute("PortReady") or 0
	local mine = player:GetAttribute("Ready") == true
	local boardText
	if status.state == "raid" then
		countdown.Text = "🏴 RAID UNDER WAY  " .. clock(status.seconds)
		countdown.TextColor3 = C.goldPale
		if status.canJoin then
			subline.Text = "Jump in now (you start with no gold), or watch it."
			boardText = "RAID UNDER WAY: " .. clock(status.seconds) .. "  ·  JOIN AT THE PIER"
		else
			subline.Text = "Too late to join: watch it, the next one is soon."
			boardText = "RAID UNDER WAY: " .. clock(status.seconds)
		end
		buttons.Visible = true
		joinButton.Visible = status.canJoin
	else
		buttons.Visible = false
		local left = status.seconds
		local allAboard = count > 0 and ready >= count
		if status.state == "boarding" then
			countdown.Text = "⛵ ALL ABOARD!"
			boardText = "BOARDING NOW!"
		else
			countdown.Text = "⛵ NEXT RAID  " .. clock(left)
			boardText = "NEXT RAID  " .. clock(left)
		end
		countdown.TextColor3 = (left <= 10 and math.sin(t * 8) > 0) and C.gold or C.white
		if allAboard then
			subline.Text = string.format("Everyone's aboard! Casting off in %d...", math.ceil(left))
		elseif mine then
			subline.Text = string.format("✔ You're aboard  ·  %d of %d ready", ready, count)
		elseif ready > 0 then
			subline.Text = string.format("%d of %d aboard  ·  walk up the gangplank to go sooner", ready, count)
		else
			subline.Text = "Walk up the gangplank when you're ready  ·  H: help"
		end
	end
	if not here then
		return
	end
	writeBoard(boardText)
	buildMarker()
	if plankMarker then
		plankMarker.Enabled = here and not mine and status.state ~= "raid"
	end
	-- The wallet.
	local shinies = player:GetAttribute("Shinies") or 0
	if shownShinies ~= shinies then
		shownShinies = shinies
		shiniesLabel.Text = tostring(shinies)
	end
	local look = Catalog.decodeLook(player:GetAttribute("Look"))
	local boat = Catalog.get(look.boat or "boat_skiff")
	local spec = boat and Config.BOAT_TYPES[boat.class]
	local ability = spec and spec.ability and Config.BOAT_ABILITIES[spec.ability]
	boatChip.Text = string.format("⛵ %s%s", boat and boat.name or "Skiff", ability and ("  " .. ability.glyph) or "")
	local pet = look.pet and Catalog.get(look.pet)
	petChip.Text = pet and ("🐾 " .. pet.name) or "🐾 No pet: adopt one"
end

-- The fade: in from black whenever the Zone changes (a goblin moved to the raid or home to the Port).
local function fadeIn()
	fade.BackgroundTransparency = 0
	TweenService:Create(fade, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
end

function PortHud.start(shop)
	openShop = shop
	build()
	RunService.RenderStepped:Connect(update)
	local lastZone = player:GetAttribute("Zone")
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local zone = player:GetAttribute("Zone")
		if zone ~= lastZone then
			if lastZone ~= nil then
				fadeIn()
			end
			if zone == "port" and lastZone == "raid" then
				Effects.chime({ 1.5, 1.26, 1 }, 0.5)
			end
			lastZone = zone
		end
	end)
	player:GetAttributeChangedSignal("Ready"):Connect(function()
		if player:GetAttribute("Ready") and inPort() then
			Effects.chime({ 1, 1.5 }, 0.5)
		end
	end)
end

-- The welcome home after a raid: a quick fade (the server has already moved the goblin).
PortHud.fadeIn = function()
	if fade then
		fadeIn()
	end
end

return PortHud

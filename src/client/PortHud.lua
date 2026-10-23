-- The Goblin Port's own screen (V13). While a goblin is in the Port (the Zone attribute) the raid HUD steps aside
-- (client/Hud.lua) and this small, calm screen speaks instead:
--   * the top sign: the countdown to the next raid and how many goblins are aboard the Little Goblin (walking up its
--     gangplank is being READY; everyone aboard brings the raid forward), or, while a raid is running, how long it has
--     left with WATCH and JOIN buttons (join only while enough of it is left: shared/Lobby.canJoinLate);
--   * top right: your Shinies, the boat you will sail and the pet you have out (each opens its page of the wardrobe);
--   * the departures board on the pier and a marker over the gangplank say the same thing in the world;
--   * a short fade from black when a goblin is moved between the raid and the Port, so the teleport is not a pop.
-- Everything it shows comes from replicated attributes; JOIN and WATCH ask the server (PortRequest), which decides.
-- V13.2: going is a CHOICE. Under the sign, JOIN NEXT RAID signs you up (walking aboard does too) and STAY IN PORT
-- cancels; AUTO-JOIN keeps you signed up raid after raid. With nobody signed up the sign says it is waiting. On the left,
-- the NEXT RAID card shows the raid's WORLD CHAOS event (its icon, name and line) and the skyship's route with the
-- islands it comes in reach of, before anyone picks a boat. (RaidRequest: the server decides.)
-- V13.3 (the Living Port): under the wallet, one line of what you are saving for (client/NextUp.lua's goal), and three
-- more chips: 📜 QUESTS (how many are ready to claim; opens the Quest Board), ⚔ CHALLENGE (the picker) and 🐾 your
-- SANCTUARY (up to your isle, or the expeditions when a pet is home). While you play a Port game the sign, the sign-up
-- row and the next-raid card step aside for the game's own panel (client/PlayHud.lua).
-- V13.4: a 🏆 LEGENDS chip (your best place on the raid boards; opens the Legends page).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local SkyRoute = require(Shared:WaitForChild("SkyRoute"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local PortHud = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local portRemote = remotes:WaitForChild("PortRequest")
local raidRemote = remotes:WaitForChild("RaidRequest") -- V13.2
local C = Ui.C

local gui, scaler, sign, countdown, subline, buttons, joinButton
local wallet, shiniesLabel, boatChip, petChip
local goalLine, questChip, challengeChip, sanctuaryChip -- V13.3
local legendsChip -- V13.4
local hooks = {} -- V13.3: set by Main (quests, challenge, sanctuary, goal, playing, questReady, petsHome)
local fade
local plankMarker, plankLabel
local signRow, signButton, autoButton -- V13.2: sign up / stay, auto-join
local nextCard, nextTitle, chaosIcon, chaosName, chaosLine, routeLine -- V13.2: the next raid's chaos and route
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

	-- V13.2: signing up for the next raid (while the Port counts down).
	signRow = Ui.make("Frame", {
		Name = "SignUp",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(440, 46),
		BackgroundTransparency = 1,
	}, root)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, signRow)
	signButton = Ui.button(signRow, {
		text = "⚔  JOIN NEXT RAID",
		style = "gold",
		size = UDim2.fromOffset(250, 44),
		order = 1,
		textSize = 19,
		name = "SignUpButton",
	}, function()
		raidRemote:FireServer(player:GetAttribute("RaidOptIn") and "out" or "in")
		Effects.sound("blip", { speed = 1.4, volume = 0.5 })
	end)
	autoButton = Ui.button(signRow, {
		text = "AUTO-JOIN: OFF",
		style = "wood",
		size = UDim2.fromOffset(160, 44),
		order = 2,
		textSize = 14,
		name = "AutoJoinButton",
	}, function()
		raidRemote:FireServer("auto", not player:GetAttribute("AutoJoin"))
		Effects.sound("blip", { speed = 1.1, volume = 0.4 })
	end)

	-- V13.2: the next raid, left side: its WORLD CHAOS event and the skyship's route.
	nextCard = Ui.make("Frame", {
		Name = "NextRaid",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(300, 150),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.15,
	}, root)
	Ui.corner(nextCard, 14)
	Ui.stroke(nextCard, Color3.fromRGB(255, 140, 60), 2)
	nextTitle = Ui.label(nextCard, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "NEXT RAID'S CHAOS",
		Font = Ui.BOLD,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 170, 110),
	})
	chaosIcon = Ui.label(nextCard, {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.fromOffset(46, 46),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 38,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	chaosName = Ui.label(nextCard, {
		Name = "ChaosName",
		Position = UDim2.fromOffset(60, 26),
		Size = UDim2.new(1, -70, 0, 26),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 20,
		TextColor3 = C.goldPale,
	})
	Ui.stroke(chaosName, C.night, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	chaosLine = Ui.label(nextCard, {
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = C.parchment,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	routeLine = Ui.label(nextCard, {
		Name = "Route",
		Position = UDim2.fromOffset(12, 104),
		Size = UDim2.new(1, -24, 0, 40),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = C.white,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Top right: Shinies, your boat, your pet.
	wallet = Ui.make("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(196, 116),
		AutomaticSize = Enum.AutomaticSize.Y,
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
	-- V13.3: what you are saving for, and the Living Port's three chips.
	goalLine = Ui.label(wallet, {
		Name = "Goal",
		Size = UDim2.fromOffset(196, 18),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 13,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Ui.stroke(goalLine, C.night, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	goalLine.LayoutOrder = 0
	pill.LayoutOrder = -1
	questChip = chip(wallet, 3, function()
		if hooks.quests then
			hooks.quests()
		end
	end)
	questChip.Name = "QuestChip"
	-- V13.4: the raid boards, one tap away (your best place on them, when you have one).
	legendsChip = chip(wallet, 4, function()
		if hooks.legends then
			hooks.legends()
		end
	end)
	legendsChip.Name = "LegendsChip"
	challengeChip = chip(wallet, 5, function()
		if hooks.challenge then
			hooks.challenge()
		end
	end)
	challengeChip.Name = "ChallengeChip"
	challengeChip.Text = "⚔ Challenge a goblin"
	sanctuaryChip = chip(wallet, 6, function()
		if hooks.sanctuary then
			hooks.sanctuary()
		end
	end)
	sanctuaryChip.Name = "SanctuaryChip"

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
		Text = "⬆ WALK ABOARD TO SIGN UP",
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

-- V13.2: the next raid's card (its world chaos, its route and the islands the ship comes in reach of).
local routeKey, routeText = nil, ""
local function updateNextCard(raiding)
	local name = workspace:GetAttribute("ChaosName")
	nextCard.Visible = name ~= nil
	if not name then
		return
	end
	nextTitle.Text = raiding and "THIS RAID'S CHAOS" or "NEXT RAID'S CHAOS"
	chaosIcon.Text = workspace:GetAttribute("ChaosIcon") or ""
	chaosName.Text = name
	chaosLine.Text = workspace:GetAttribute("ChaosLine") or ""
	local key = tostring(workspace:GetAttribute("SkyRoute")) .. tostring(workspace:GetAttribute("SkyRouteReversed"))
	if key ~= routeKey then
		routeKey = key
		local points = SkyRoute.current()
		local names = {}
		if points then
			local generated = workspace:FindFirstChild("LootGoblinsGenerated")
			for _, island in ipairs(Archipelago.islands) do
				local info = Config.ISLAND_INFO[island.id]
				if info and info.major then
					local spot = generated and generated:GetAttribute("Land_" .. island.id)
					local x, z, y = island.x, island.z, 0
					if typeof(spot) == "Vector3" then
						x, z, y = spot.X, spot.Z, spot.Y
					end
					local pass = SkyRoute.passBy(points, x, z, SkyRoute.reach(y))
					if pass.from then
						table.insert(names, { name = island.name, at = pass.from })
					end
				end
			end
			table.sort(names, function(a, b)
				return a.at < b.at
			end)
		end
		local list = {}
		for _, entry in ipairs(names) do
			table.insert(list, entry.name)
		end
		routeText = string.format(
			"⛵ %s: %s",
			workspace:GetAttribute("SkyRouteName") or "THE SKYSHIP",
			#list > 0 and table.concat(list, ", ") or "?"
		)
	end
	routeLine.Text = routeText
end

-- Each frame -----------------------------------------------------------------------------------------------------------
local shownShinies = nil
local function update()
	local here = inPort()
	gui.Enabled = here and not player:GetAttribute("Spectating")
	-- V13.3: in a Port game, the game's panel has the top of the screen.
	local playing = hooks.playing and hooks.playing() or false
	sign.Visible = not playing
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scaler.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.15)
	end
	local t = now()
	local phase = workspace:GetAttribute("RaidPhase") or "port"
	local signed = workspace:GetAttribute("PortSigned") or 0
	local status = Lobby.status(
		phase,
		t,
		workspace:GetAttribute("PhaseEndsAt"),
		player:GetAttribute("InRaid") == true,
		phase ~= "raid" and signed or nil
	)
	local ready = workspace:GetAttribute("PortReady") or 0
	local mine = player:GetAttribute("Ready") == true
	local optedIn = player:GetAttribute("RaidOptIn") == true
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
		buttons.Visible = not playing
		joinButton.Visible = status.canJoin
		signRow.Visible = false
	else
		buttons.Visible = false
		signRow.Visible = not playing
		signButton.Text = optedIn and "✔ SIGNED UP  ·  STAY IN PORT" or "⚔  JOIN NEXT RAID"
		autoButton.Text = player:GetAttribute("AutoJoin") and "AUTO-JOIN: ON" or "AUTO-JOIN: OFF"
		local left = status.seconds
		local allAboard = signed > 0 and ready >= signed
		if status.state == "waiting" then
			-- V13.2: nobody has signed up: nothing leaves, the town carries on.
			countdown.Text = "⛵ WAITING FOR RAIDERS"
			boardText = "NEXT RAID: WHEN SOMEONE SIGNS UP"
		elseif status.state == "boarding" then
			countdown.Text = "⛵ ALL ABOARD!"
			boardText = "BOARDING NOW!"
		else
			countdown.Text = "⛵ NEXT RAID  " .. clock(left)
			boardText = "NEXT RAID  " .. clock(left) .. "  ·  " .. signed .. " SIGNED UP"
		end
		countdown.TextColor3 = (status.state ~= "waiting" and left <= 10 and math.sin(t * 8) > 0) and C.gold or C.white
		if status.state == "waiting" then
			subline.Text = "JOIN NEXT RAID (or walk aboard) to set sail  ·  H: help"
		elseif allAboard then
			subline.Text = string.format("Everyone signed up is aboard! Casting off in %d...", math.ceil(left))
		elseif mine then
			subline.Text = string.format("✔ You're aboard  ·  %d of %d signed up aboard", ready, signed)
		elseif optedIn then
			subline.Text =
				string.format("✔ You're going (%d signed up)  ·  shop, then walk aboard to go sooner", signed)
		else
			subline.Text = string.format("%d signed up  ·  JOIN, or stay to shop, watch and chat", signed)
		end
	end
	-- V13.2: the next raid's chaos and route (chosen as the Port opens).
	updateNextCard(status.state == "raid")
	if playing then
		nextCard.Visible = false
	end
	if not here then
		return
	end
	writeBoard(boardText)
	buildMarker()
	if plankMarker then
		plankMarker.Enabled = here and not mine and status.state ~= "raid"
		plankLabel.Text = optedIn and "⬆ WALK ABOARD TO GO SOONER" or "⬆ WALK ABOARD TO SIGN UP"
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
	-- V13.3
	local goal = hooks.goal and hooks.goal() or nil
	goalLine.Text = goal or ""
	goalLine.Visible = goal ~= nil
	local claimable = hooks.questReady and hooks.questReady() or 0
	questChip.Text = claimable > 0 and string.format("📜 Quests: %d to claim!", claimable) or "📜 Quests"
	Ui.setStyle(questChip, claimable > 0 and "gold" or "wood")
	local place = hooks.legendsPlace and hooks.legendsPlace() or nil
	legendsChip.Text = place and string.format("🏆 Legends  #%d %s", place.rank, place.icon) or "🏆 Raid Legends"
	local home = hooks.petsHome and hooks.petsHome() or 0
	sanctuaryChip.Text = home > 0 and string.format("🐾 %d pet%s home: collect!", home, home == 1 and "" or "s")
		or "🐾 My sanctuary"
	Ui.setStyle(sanctuaryChip, home > 0 and "gold" or "wood")
end

-- The fade: in from black whenever the Zone changes (a goblin moved to the raid or home to the Port).
local function fadeIn()
	fade.BackgroundTransparency = 0
	TweenService:Create(fade, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
end

function PortHud.start(shop, extra)
	openShop = shop
	hooks = extra or {}
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
	player:GetAttributeChangedSignal("RaidOptIn"):Connect(function()
		if inPort() then
			Effects.chime(player:GetAttribute("RaidOptIn") and { 1, 1.26, 1.5 } or { 1.2, 1 }, 0.5)
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

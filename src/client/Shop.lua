-- The locker (P): your Shinies, your pets and your starting gear. And the pets themselves: a small
-- companion drawn beside every goblin who has one out (cosmetic only; what a pet DOES is decided on the
-- server from the player's "Pet" attribute, never from anything drawn here).
-- Every price, owned flag and result comes from the server through attributes and toasts; the buttons
-- only send intent ("buy gull").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))

local Shop = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local shopRemote = remotes:WaitForChild("ShopRequest")

local DARK = Color3.fromRGB(16, 16, 22)
local GOLD = Color3.fromRGB(255, 205, 50)
local WHITE = Color3.new(1, 1, 1)

local gui, panel, shiniesLabel, saveLabel, list
local rows = {}
local visible = false

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function owned(csv, id)
	for entry in string.gmatch(csv or "", "[^,]+") do
		if entry == id then
			return true
		end
	end
	return false
end

local function button(parent, text, color, callback)
	local b = make("TextButton", {
		Size = UDim2.fromOffset(104, 28),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = DARK,
		TextSize = 13,
		AutoButtonColor = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	b.MouseButton1Click:Connect(callback)
	return b
end

local function row(order, title, effect, color)
	local frame = make("Frame", {
		Size = UDim2.new(1, -12, 0, 54),
		BackgroundColor3 = Color3.fromRGB(30, 32, 44),
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, list)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	make("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, frame)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -260, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = title,
		TextColor3 = WHITE,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -260, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = effect,
		TextColor3 = Color3.fromRGB(200, 205, 220),
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, frame)
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(232, 30),
		BackgroundTransparency = 1,
	}, frame)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	return holder
end

local function rebuild()
	for _, r in ipairs(rows) do
		r:Destroy()
	end
	rows = {}
	local ownedPets, ownedKits = player:GetAttribute("OwnedPets"), player:GetAttribute("OwnedKits")
	local equipped, kit = player:GetAttribute("Pet"), player:GetAttribute("Kit")
	local shinies = player:GetAttribute("Shinies") or 0
	shiniesLabel.Text = string.format("%d SHINIES", shinies)
	local state = player:GetAttribute("SaveState")
	saveLabel.Text = state == "saved" and "Progress saved"
		or (
			state == "unavailable" and "Saving is off here: progress will not be kept"
			or (state == "unsaved" and "Could not load or save: progress this session will not be kept" or "")
		)
	local order = 0
	local ids = {}
	for id in pairs(Config.PETS) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.PETS[a].price < Config.PETS[b].price
	end)
	for _, id in ipairs(ids) do
		order += 1
		local def = Config.PETS[id]
		local holder = row(order, def.name .. "  -  " .. def.price .. " Shinies", def.effect, def.color)
		table.insert(rows, holder.Parent)
		if owned(ownedPets, id) then
			if equipped == id then
				button(holder, "PUT AWAY", Color3.fromRGB(190, 195, 210), function()
					shopRemote:FireServer("unequip")
				end)
			else
				button(holder, "BRING OUT", Color3.fromRGB(120, 230, 150), function()
					shopRemote:FireServer("equip", id)
				end)
			end
		else
			button(holder, "BUY", shinies >= def.price and GOLD or Color3.fromRGB(120, 120, 130), function()
				shopRemote:FireServer("buy", id)
			end)
			button(holder, "ROBUX", Color3.fromRGB(110, 190, 255), function()
				shopRemote:FireServer("robux", id)
			end)
		end
	end
	for _, id in ipairs({ "Rebreather", "CinderBoots", "FrostClaws" }) do
		order += 1
		local def = Config.GEAR[id]
		local holder = row(
			order,
			"Start with: " .. def.name .. "  -  " .. Config.KIT_PRICE .. " Shinies",
			def.effect .. " (Free in the world too.)",
			def.color
		)
		table.insert(rows, holder.Parent)
		if owned(ownedKits, id) then
			if kit == id then
				button(holder, "STARTING WITH IT", Color3.fromRGB(190, 195, 210), function()
					shopRemote:FireServer("kit", "none")
				end)
			else
				button(holder, "START WITH IT", Color3.fromRGB(120, 230, 150), function()
					shopRemote:FireServer("kit", id)
				end)
			end
		else
			button(holder, "BUY", shinies >= Config.KIT_PRICE and GOLD or Color3.fromRGB(120, 120, 130), function()
				shopRemote:FireServer("buykit", id)
			end)
		end
	end
end

function Shop.toggle()
	visible = not visible
	if panel then
		panel.Visible = visible
		if visible then
			rebuild()
		end
	end
end

local function buildPanel()
	gui = make(
		"ScreenGui",
		{ Name = "LootGoblinsLocker", ResetOnSpawn = false, DisplayOrder = 8 },
		player:WaitForChild("PlayerGui")
	)
	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 470),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = GOLD, Thickness = 2 }, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(300, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "THE LOCKER   (P closes)",
		TextColor3 = GOLD,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	shiniesLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.fromOffset(200, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 150),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Shinies are kept for good. Raid gold is only for winning the raid. Everything here is a sidegrade: a pet does something different, it does not do more.",
		TextColor3 = Color3.fromRGB(190, 195, 210),
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, panel)
	list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.new(1, -20, 1, -102),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 520),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	saveLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -6),
		Size = UDim2.new(1, -32, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Color3.fromRGB(200, 205, 220),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
end

-- Pets ------------------------------------------------------------------------------------------------
local bodies = {} -- player -> { part, id }

local function petPart(id)
	local def = Config.PETS[id]
	local body = make("Part", {
		Name = "Pet_" .. id,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.5, 1.8),
		Color = def and def.color or WHITE,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, workspace)
	for _, side in ipairs({ -1, 1 }) do
		local eye = make("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.5, 0.5),
			Color = Color3.new(0.05, 0.05, 0.08),
			Material = Enum.Material.SmoothPlastic,
			Massless = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, body)
		local weld = make("Weld", { Part0 = body, Part1 = eye }, eye)
		weld.C0 = CFrame.new(side * 0.42, 0.25, -0.78)
	end
	return body
end

local function updatePets(t)
	for _, other in ipairs(Players:GetPlayers()) do
		local id = other:GetAttribute("Pet")
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local entry = bodies[other]
		if id and root and Config.PETS[id] then
			if not entry or entry.id ~= id or not entry.part.Parent then
				if entry then
					entry.part:Destroy()
				end
				entry = { part = petPart(id), id = id, pos = root.Position }
				bodies[other] = entry
			end
			local want = (root.CFrame * CFrame.new(3.2, 1.2 + math.sin(t * 3 + other.UserId) * 0.45, 3.4)).Position
			entry.pos = entry.pos:Lerp(want, 0.18)
			entry.part.CFrame = CFrame.lookAt(entry.pos, root.Position + Vector3.new(0, 1, 0))
		elseif entry then
			entry.part:Destroy()
			bodies[other] = nil
		end
	end
	for other, entry in pairs(bodies) do
		if not other.Parent then
			entry.part:Destroy()
			bodies[other] = nil
		end
	end
end

-- The Scout Gull: how far the nearest treasure that is still waiting is, as a line of text under the
-- compass (the gull points; it does not fetch).
local gullLabel
local function updateGull()
	if player:GetAttribute("Pet") ~= "Gull" then
		if gullLabel then
			gullLabel.Visible = false
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local folder = generated and generated:FindFirstChild("Loot")
	if not root or not folder then
		return
	end
	local best, bestDistance
	for _, def in ipairs(Config.LOOT) do
		if folder:GetAttribute(def.id .. "State") == "spot" then
			local island = Archipelago.byId[def.island]
			if island then
				local distance = Vector3.new(island.x - root.Position.X, 0, island.z - root.Position.Z).Magnitude
				if distance <= Config.PET_GULL_RANGE and (not bestDistance or distance < bestDistance) then
					best, bestDistance = def, distance
				end
			end
		end
	end
	if not gullLabel then
		gullLabel = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 176),
			Size = UDim2.fromOffset(360, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(240, 240, 250),
			TextStrokeTransparency = 0.4,
			TextSize = 14,
		}, gui)
	end
	gullLabel.Visible = best ~= nil
	if best then
		gullLabel.Text = string.format("Gull sees: %s, %d studs", best.name, bestDistance)
		gullLabel.TextColor3 = best.color
	end
end

function Shop.start()
	buildPanel()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P then
			Shop.toggle()
		end
	end)
	for _, attribute in ipairs({ "Shinies", "Pet", "OwnedPets", "OwnedKits", "Kit", "SaveState" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if visible then
				rebuild()
			end
		end)
	end
	local nextGull = 0
	RunService.RenderStepped:Connect(function()
		updatePets(os.clock())
		if os.clock() > nextGull then
			nextGull = os.clock() + 0.5
			updateGull()
		end
	end)
end

return Shop

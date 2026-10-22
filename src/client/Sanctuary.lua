-- The pet sanctuaries on this client (V13.3).
--
--   THE PETS    on every isle near the camera (Config.SANCTUARY.DRAW), the owner's pets wander, pause, do their idle
--               quirk, splash about the pond (swimmers and floaters hover over it), and react to the isle's moments:
--               FED (they run to the trough and eat), a BALL thrown (they race to it), the BELL (they gather round it
--               and hop). Pets out on expeditions are not there. All drawn with the shared animator (PetCrowd).
--   PANELS      DECORATE (the owner's signpost): a theme, upgrades, decorations in four spots, which pets live there.
--               EXPEDITIONS (the isle's dock, or the Port screen's chip): what is out, COLLECT when back, send a pet.
--               VISIT (the lift in the Port): every goblin here and their isle.
-- Everything shown comes from attributes (the isles' and the player's Sanctuary); actions go to the server
-- (ShopRequest "sanctbuy" and friends, SanctuaryRequest "visit"/"home"), which decides.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Habitat = require(Shared:WaitForChild("Habitat"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local PetCrowd = require(script.Parent.PetCrowd)

local Sanctuary = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local shopRemote = remotes:WaitForChild("ShopRequest")
local sanctuaryRemote = remotes:WaitForChild("SanctuaryRequest")
local SC = Config.SANCTUARY
local C = Ui.C
local rgb = Color3.fromRGB
local v3 = Vector3.new

local hud
local crowd
local isles = {} -- model -> { pets = { key -> state }, center, radius, frame }
local gui, window, body, titleLabel
local panel, tab = nil, nil
local residentsDraft = nil
local sendPet, sendTrip = nil, "reef"

local function now()
	return workspace:GetServerTimeNow()
end

local function decode(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	return ok and data or nil
end

local function myData()
	return decode(player:GetAttribute("Sanctuary"))
		or { owned = {}, levels = {}, decor = {}, residents = {}, expeditions = { list = {}, slots = 1 } }
end

local function ownedSet()
	local set = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function petsOwned()
	local owned = ownedSet()
	local list = {}
	for _, item in ipairs(Catalog.bySlot.pet or {}) do
		if owned[item.id] or Catalog.isFree(item) then
			table.insert(list, item)
		end
	end
	return list
end

-- The pets on the isles ------------------------------------------------------------------------------------------------------
local function folder()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Sanctuaries")
end

local function isleFrame(center)
	local I = PortGames.ISLAND
	return CFrame.lookAt(center, v3(I.X, center.Y, I.Z))
end

local function randomSpot(isle, random)
	local a = random:NextNumber(0, math.pi * 2)
	local r = math.sqrt(random:NextNumber()) * (isle.radius - 6)
	return v3(isle.center.X + math.cos(a) * r, isle.center.Y, isle.center.Z + math.sin(a) * r)
end

local function updateIsle(model, isle, dt, t)
	local center = isle.center
	local residents = {}
	local away = {}
	for id in string.gmatch(model:GetAttribute("Away") or "", "[^,]+") do
		away[id] = true
	end
	for id in string.gmatch(model:GetAttribute("Residents") or "", "[^,]+") do
		if not away[id] and #residents < SC.RESIDENTS then
			table.insert(residents, id)
		end
	end
	local owner = model:GetAttribute("Owner") or 0
	local seen = {}
	local fedAt = model:GetAttribute("FedAt") or -1e9
	local toyAt = model:GetAttribute("ToyAt") or -1e9
	local bellAt = model:GetAttribute("BellAt") or -1e9
	local trough = (isle.frame * CFrame.new(4, 0, -12)).Position
	local bell = (isle.frame * CFrame.new(0, 0, 2)).Position
	local pond = (isle.frame * CFrame.new(-6, 0, 10)).Position
	local toy = v3(model:GetAttribute("ToyX") or center.X, center.Y, model:GetAttribute("ToyZ") or center.Z)
	for i, id in ipairs(residents) do
		local key = owner .. ":" .. id
		seen[key] = true
		local pet = crowd:add(key, id)
		if pet then
			crowd:show(pet, true)
			local s = isle.pets[key]
			if not s then
				local random = Random.new(owner * 31 + i)
				s = {
					random = random,
					pos = randomSpot(isle, random),
					waitUntil = t + random:NextNumber(0, 3),
					yaw = random:NextNumber(0, 6.28),
				}
				s.target = s.pos
				isle.pets[key] = s
			end
			-- What it wants to do now.
			local goal, speed = nil, 4.5
			local ring = (i / math.max(1, #residents)) * math.pi * 2
			if t - bellAt < 5 then
				goal, speed = bell + v3(math.cos(ring) * 4, 0, math.sin(ring) * 4), 11
			elseif t - toyAt < 5 then
				goal, speed = toy + v3(math.cos(ring) * (1 + i * 0.3), 0, math.sin(ring) * (1 + i * 0.3)), 12 + (i % 3)
			elseif t - fedAt < 7 then
				goal, speed = trough + v3(-2.2 + (i % 5) * 1.1, 0, -1.6 - (i // 5) * 1.2), 10
			elseif pet.flying and (i % 3 == 0) then
				goal = pond + v3(math.cos(t * 0.4 + i) * 4, 0, math.sin(t * 0.4 + i) * 4)
				speed = 3
			else
				if t >= s.waitUntil and (s.target - s.pos).Magnitude < 0.7 then
					s.target = randomSpot(isle, s.random)
					s.waitUntil = t + s.random:NextNumber(2, 6)
				end
				goal = t >= s.waitUntil and s.target or s.pos
				speed = 4.5
			end
			local to = v3(goal.X - s.pos.X, 0, goal.Z - s.pos.Z)
			local moving = to.Magnitude > 0.5
			local move = 0
			if moving then
				move = math.min(to.Magnitude, speed * dt)
				s.pos += to.Unit * move
				local want = PetCrowd.yawOf(to)
				s.yaw += math.atan2(math.sin(want - s.yaw), math.cos(want - s.yaw)) * math.min(1, dt * 7)
			end
			local lift, extra = 0, nil
			if t - bellAt < 5 and not moving then
				lift = math.abs(math.sin(t * 6 + i)) * 0.8 -- hopping round the bell
			elseif t - fedAt < 7 and not moving then
				extra = CFrame.Angles(math.rad(14 + 8 * math.sin(t * 9 + i)), 0, 0) -- head down, eating
			end
			crowd:place(pet, s.pos, s.yaw, moving and speed or 0, { lift = lift, extra = extra, idle = not moving })
		end
	end
	for key in pairs(isle.pets) do
		if not seen[key] then
			isle.pets[key] = nil
			crowd:remove(key)
		end
	end
	-- The ball, bouncing to where it was thrown.
	if t - toyAt < 1.2 then
		isle.ball = isle.ball
			or Ui.make("Part", {
				Name = "PetBall",
				Shape = Enum.PartType.Ball,
				Size = v3(1.2, 1.2, 1.2),
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Material = Enum.Material.SmoothPlastic,
				Color = rgb(230, 60, 60),
			}, crowd.folder)
		local k = (t - toyAt) / 1.2
		isle.ball.CFrame =
			CFrame.new(center:Lerp(toy, k) + v3(0, 0.6 + math.abs(math.sin(k * math.pi * 2)) * 6 * (1 - k), 0))
	elseif isle.ball and t - toyAt > 5 then
		isle.ball:Destroy()
		isle.ball = nil
	elseif isle.ball then
		isle.ball.CFrame = CFrame.new(toy + v3(0, 0.6, 0))
	end
end

local function updatePets(dt)
	local f = folder()
	local camera = workspace.CurrentCamera
	if not f or not camera then
		return
	end
	local t = now()
	local eye = camera.CFrame.Position
	local live = {}
	for _, model in ipairs(f:GetChildren()) do
		local center = model:GetAttribute("Center")
		if typeof(center) == "Vector3" and (center - eye).Magnitude <= SC.DRAW then
			local isle = isles[model]
			if not isle then
				isle = {
					pets = {},
					center = center,
					radius = model:GetAttribute("Radius") or SC.ISLE,
					frame = isleFrame(center),
				}
				isles[model] = isle
			end
			live[model] = true
			updateIsle(model, isle, dt, t)
		end
	end
	for model, isle in pairs(isles) do
		if not live[model] then
			for key in pairs(isle.pets) do
				crowd:remove(key)
			end
			if isle.ball then
				isle.ball:Destroy()
			end
			isles[model] = nil
		end
	end
	crowd:flush()
end

-- The panels ------------------------------------------------------------------------------------------------------------------
local function clear()
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
end

local function row(order, height)
	local frame = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 44),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.3,
		LayoutOrder = order,
	}, body)
	Ui.corner(frame, 10)
	return frame
end

local function rowText(frame, text, sub)
	Ui.label(frame, {
		Position = UDim2.fromOffset(12, sub and 3 or 0),
		Size = UDim2.new(1, -200, sub and 0 or 1, sub and 22 or 0),
		Text = text,
		Font = Ui.BOLD,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if sub then
		Ui.label(frame, {
			Position = UDim2.fromOffset(12, 23),
			Size = UDim2.new(1, -200, 0, 18),
			Text = sub,
			Font = Ui.BODY,
			TextSize = 12,
			TextColor3 = C.inkSoft,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
end

local function rowButton(frame, text, style, onClick, width, offset)
	return Ui.button(frame, {
		text = text,
		style = style or "gold",
		size = UDim2.fromOffset(width or 120, 34),
		position = UDim2.new(1, -((width or 120) + 8 + (offset or 0)), 0.5, -17),
		textSize = 14,
	}, onClick)
end

local function shinies()
	return player:GetAttribute("Shinies") or 0
end

local function renderDecorate()
	local data = myData()
	local owned = {}
	for _, key in ipairs(data.owned or {}) do
		owned[key] = true
	end
	local tabs = row(0, 40)
	tabs.BackgroundTransparency = 1
	local layout =
		Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabs)
	local _ = layout
	for _, name in ipairs({ "theme", "upgrades", "decor", "residents" }) do
		Ui.button(tabs, {
			text = string.upper(name),
			style = tab == name and "gold" or "wood",
			size = UDim2.fromOffset(118, 36),
			textSize = 14,
		}, function()
			tab = name
			Sanctuary.render()
		end)
	end
	if tab == "theme" then
		for i, theme in ipairs(Habitat.THEMES) do
			local frame = row(i)
			local has = theme.price == nil or owned["theme_" .. theme.id]
			rowText(
				frame,
				theme.name,
				has and (data.theme == theme.id and "Your isle now" or "Yours") or ("◆ " .. theme.price)
			)
			if data.theme == theme.id then
				rowButton(frame, "✔ WEARING", "ghost", nil)
			elseif has then
				rowButton(frame, "USE IT", "wood", function()
					shopRemote:FireServer("sancttheme", theme.id)
				end)
			else
				rowButton(frame, "BUY ◆" .. theme.price, shinies() >= theme.price and "gold" or "ghost", function()
					shopRemote:FireServer("sanctbuy", "theme", theme.id)
				end)
			end
		end
	elseif tab == "upgrades" then
		for i, feature in ipairs(Habitat.FEATURES) do
			local frame = row(i, 50)
			local level = (data.levels and data.levels[feature.id]) or feature.start
			local current = level >= 1 and feature.levels[level] or "None yet"
			local nextName = feature.levels[level + 1]
			local price = feature.prices[level + 1]
			rowText(frame, feature.name .. ": " .. current, nextName and ("Next: " .. nextName) or "As good as it gets")
			if nextName and price then
				rowButton(frame, "◆" .. price, shinies() >= price and "gold" or "ghost", function()
					shopRemote:FireServer("sanctbuy", "feature", feature.id)
				end)
			end
		end
	elseif tab == "decor" then
		for spot = 1, Habitat.SOCKETS do
			local frame = row(spot, 40)
			local id = data.decor and data.decor[spot] or ""
			local decor = Habitat.DECOR_BY_ID[id]
			rowText(frame, string.format("Spot %d: %s", spot, decor and decor.name or "empty"))
			if decor then
				rowButton(frame, "EMPTY", "ghost", function()
					shopRemote:FireServer("sanctplace", spot, "")
				end)
			end
		end
		for i, decor in ipairs(Habitat.DECOR) do
			local frame = row(10 + i, 40)
			local has = owned["decor_" .. decor.id]
			rowText(frame, decor.name .. (has and "  ✔" or ""))
			if has then
				-- Put it in the first spot that is empty (or the first spot).
				rowButton(frame, "PLACE", "wood", function()
					local target = 1
					for spot = 1, Habitat.SOCKETS do
						if (data.decor[spot] or "") == "" then
							target = spot
							break
						end
					end
					shopRemote:FireServer("sanctplace", target, decor.id)
				end)
			else
				rowButton(frame, "◆" .. decor.price, shinies() >= decor.price and "gold" or "ghost", function()
					shopRemote:FireServer("sanctbuy", "decor", decor.id)
				end)
			end
		end
	else
		residentsDraft = residentsDraft or table.clone(data.residents or {})
		local frame = row(1, 40)
		rowText(
			frame,
			string.format("Who lives here: %d of %d chosen", #residentsDraft, SC.RESIDENTS),
			"None chosen: your newest pets"
		)
		rowButton(frame, "SAVE", "gold", function()
			shopRemote:FireServer("residents", residentsDraft)
			residentsDraft = nil
		end)
		for i, item in ipairs(petsOwned()) do
			local petRow = row(10 + i, 36)
			local chosen = table.find(residentsDraft, item.id) ~= nil
			rowText(petRow, item.name)
			rowButton(petRow, chosen and "✔ LIVES HERE" or "ADD", chosen and "good" or "wood", function()
				local index = table.find(residentsDraft, item.id)
				if index then
					table.remove(residentsDraft, index)
				elseif #residentsDraft < SC.RESIDENTS then
					table.insert(residentsDraft, item.id)
				end
				Sanctuary.render()
			end, 140)
		end
	end
end

local function renderExpeditions()
	local data = myData()
	local x = data.expeditions or { list = {}, slots = 1 }
	local t = now()
	local today = (x.day == Seasons.period("day", now())) and (x.today or 0) or 0
	local head = row(0, 40)
	rowText(
		head,
		string.format("Expeditions: %d of %d out", #(x.list or {}), x.slots or 1),
		string.format("Today's haul: %d of %d Shinies", today, Config.EXPEDITIONS.DAILY_CAP)
	)
	local away = {}
	for i, e in ipairs(x.list or {}) do
		away[e.pet] = true
		local item = Catalog.get(e.pet)
		local trip = Habitat.TRIP_BY_ID[e.trip]
		local remaining = math.max(0, (e.back or 0) - now())
		local frame = row(i, 50)
		rowText(
			frame,
			string.format("%s: %s", item and item.name or e.pet, trip and trip.name or e.trip),
			remaining > 0
					and string.format(
						"Back in %dh %02dm  ·  ◆ %d",
						remaining // 3600,
						(remaining % 3600) // 60,
						trip and trip.shinies or 0
					)
				or "BACK HOME!"
		)
		if remaining <= 0 then
			rowButton(frame, "COLLECT", "good", function()
				shopRemote:FireServer("expcollect", e.id)
			end)
		else
			rowButton(frame, "CALL BACK", "ghost", function()
				shopRemote:FireServer("exprecall", e.id)
			end)
		end
	end
	local _ = t
	if #(x.list or {}) < (x.slots or 1) then
		local pick = row(20, 40)
		rowText(pick, "Send a pet scavenging", "Every pet finds the same: rarity is never income.")
		for i, trip in ipairs(Config.EXPEDITIONS.TRIPS) do
			local frame = row(20 + i, 40)
			rowText(frame, string.format("%s  ·  %dh  ·  ◆ %d", trip.name, trip.hours, trip.shinies))
			rowButton(
				frame,
				sendTrip == trip.id and "✔ THIS TRIP" or "CHOOSE",
				sendTrip == trip.id and "good" or "wood",
				function()
					sendTrip = trip.id
					Sanctuary.render()
				end,
				140
			)
		end
		local equipped = Catalog.decodeLook(player:GetAttribute("Look")).pet
		for i, item in ipairs(petsOwned()) do
			if not away[item.id] then
				local frame = row(30 + i, 36)
				rowText(
					frame,
					item.name .. (item.id == equipped and "  (out with you: it will stay at the dock)" or "")
				)
				rowButton(
					frame,
					sendPet == item.id and "✔ SEND" or "PICK",
					sendPet == item.id and "gold" or "wood",
					function()
						if sendPet == item.id then
							shopRemote:FireServer("expsend", item.id, sendTrip)
							sendPet = nil
						else
							sendPet = item.id
							Sanctuary.render()
						end
					end,
					110
				)
			end
		end
		if #petsOwned() == 0 then
			rowText(row(31, 40), "No pets yet: adopt one at Mother Mossback's in the Port.")
		end
	end
end

local function renderVisit()
	local f = folder()
	local frame = row(0, 40)
	rowText(frame, "Your own sanctuary")
	rowButton(frame, "GO HOME", "gold", function()
		sanctuaryRemote:FireServer("home")
		Sanctuary.close()
	end)
	local n = 0
	for _, model in ipairs(f and f:GetChildren() or {}) do
		local owner = model:GetAttribute("Owner")
		if owner and owner ~= player.UserId then
			n += 1
			local count = 0
			for _ in string.gmatch(model:GetAttribute("Residents") or "", "[^,]+") do
				count += 1
			end
			local r = row(n, 40)
			rowText(r, (model:GetAttribute("OwnerName") or "?") .. "'s sanctuary", string.format("%d pets", count))
			rowButton(r, "VISIT", "wood", function()
				sanctuaryRemote:FireServer("visit", owner)
				Sanctuary.close()
			end)
		end
	end
	if n == 0 then
		rowText(row(1, 40), "Nobody else is in the Port right now.")
	end
end

function Sanctuary.render()
	if not window or not window.Visible then
		return
	end
	clear()
	if panel == "sanctuary" then
		titleLabel.Text = "🐾 YOUR SANCTUARY  ·  ◆ " .. shinies()
		renderDecorate()
	elseif panel == "expeditions" then
		titleLabel.Text = "⛵ PET EXPEDITIONS"
		renderExpeditions()
	else
		titleLabel.Text = "🎈 VISIT A SANCTUARY"
		renderVisit()
	end
end

function Sanctuary.open(which)
	panel = which
	tab = tab or "theme"
	residentsDraft = nil
	window.Visible = true
	Sanctuary.render()
	Effects.sound("blip", { speed = 1.2, volume = 0.4 })
end

function Sanctuary.close()
	window.Visible = false
end

function Sanctuary.isOpen()
	return window ~= nil and window.Visible
end

-- For the Port screen: how many expeditions are home and waiting.
function Sanctuary.readyCount()
	local data = myData()
	local n = 0
	for _, e in ipairs(data.expeditions and data.expeditions.list or {}) do
		if (e.back or 0) <= now() then
			n += 1
		end
	end
	return n
end

local function build()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsSanctuary", ResetOnSpawn = false, DisplayOrder = 9 },
		player:WaitForChild("PlayerGui")
	)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local scale = Ui.make("UIScale", {}, gui)
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.6, 1.1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	window = Ui.make("Frame", {
		Name = "SanctuaryWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 520),
		BackgroundColor3 = C.wood,
		Visible = false,
	}, gui)
	Ui.corner(window, 18)
	Ui.stroke(window, C.goldDeep, 3)
	titleLabel = Ui.label(window, {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.goldPale,
	})
	Ui.button(window, {
		text = "X",
		style = "danger",
		size = UDim2.fromOffset(38, 34),
		position = UDim2.new(1, -50, 0, 10),
		textSize = 18,
		name = "CloseSanctuary",
	}, Sanctuary.close)
	local paper = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.new(1, -28, 1, -66),
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window)
	Ui.corner(paper, 12)
	body = Ui.make("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.fromOffset(8, 8),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, paper)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			window.Visible
			and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.X))
		then
			Sanctuary.close()
		end
	end)
	player:GetAttributeChangedSignal("Sanctuary"):Connect(Sanctuary.render)
	player:GetAttributeChangedSignal("Shinies"):Connect(Sanctuary.render)
end

function Sanctuary.start(hudModule)
	hud = hudModule
	crowd = PetCrowd.new("LootGoblinsSanctuaryPets")
	build()
	RunService.RenderStepped:Connect(updatePets)
	-- The expeditions' clocks, redrawn when a minute shown changes (not every second: buttons keep their focus).
	task.spawn(function()
		local shown
		while true do
			task.wait(1)
			if window.Visible and panel == "expeditions" then
				local parts = {}
				for _, e in ipairs(myData().expeditions and myData().expeditions.list or {}) do
					table.insert(parts, tostring(math.max(0, ((e.back or 0) - now())) // 60))
				end
				local signature = table.concat(parts, ",")
				if signature ~= shown then
					shown = signature
					Sanctuary.render()
				end
			end
		end
	end)
end

-- A pet home from its trip.
function Sanctuary.expeditionHome(p)
	local item = Catalog.get(p.pet)
	hud.banner(
		string.format("%s IS HOME!  +%d SHINIES", string.upper(item and item.name or "YOUR PET"), p.shinies or 0),
		C.gold,
		3,
		3
	)
	Effects.chime(Effects.CHIME_GOOD, 0.7)
end

return Sanctuary

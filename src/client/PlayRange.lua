-- Treasure Toss and the Target Ship Gallery on this client (V13.3). Their targets are functions of the server's clock
-- (shared/PortGames.lua: PortGames.TOSS, PortGames.GALLERY), so they are simply drawn where they are, by every client
-- near the booth, with nothing sent over the network. A throw or a shot arrives as a PlayFx event with its start, its
-- velocity and the time it lands; it is animated along that exact arc and its points pop up when it gets there.
--
--   TREASURE TOSS   aim with the camera (the mouse turns it; a crosshair in the middle), click or Q to throw (a
--                   controller's R2 or L1; the THROW button on a touch screen). Every goblin at the line carries a
--                   chest over their head while the round runs.
--   THE GALLERY     the camera stands behind your cannon: look to aim (mouse, the right stick, a finger), click,
--                   Space, R2 or A to fire (FIRE on a touch screen). Ships the server has knocked down keel over.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local PlayRange = {}

local player = Players.LocalPlayer
local G = Config.PLAYGROUND
local C = Ui.C
local rgb = Color3.fromRGB
local v3 = Vector3.new
local toss, gallery = PortGames.TOSS, PortGames.GALLERY

local ctx
local folder
local tossModels = {} -- target index -> model
local galleryModels = {}
local kingMouth
local chests = {} -- player -> chest model over their head
local gui, crosshair, hint
local mode = nil -- "toss" | "gallery" | nil (the input this client has bound)
local aimYaw, aimPitch = 0, math.rad(6)
local stick = Vector2.zero
local touchDrag = Vector2.zero
local nextAimSend = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Little builders (local, anchored, harmless) --------------------------------------------------------------------------------
local function piece(model, name, size, cf, color, material, shape)
	local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = model
	return p
end

local function newModel(name)
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local UP = CFrame.Angles(0, 0, math.rad(90))

local function buildToss()
	for index, target in ipairs(toss.targets) do
		local model = newModel("TossTarget" .. index)
		if target.kind == "barrel" then
			piece(
				model,
				"Barrel",
				v3(3.2, 3, 3),
				CFrame.new(0, -1.5, 0) * UP,
				Palette.WOOD,
				Enum.Material.WoodPlanks,
				"cyl"
			)
			piece(
				model,
				"Hoop",
				v3(0.25, 3.3, 3.3),
				CFrame.new(0, -0.3, 0) * UP,
				rgb(70, 66, 74),
				Enum.Material.Metal,
				"cyl"
			)
			piece(model, "Mouth", v3(0.2, 2.6, 2.6), CFrame.new(0, 0.02, 0) * UP, rgb(40, 30, 24), nil, "cyl")
		elseif target.kind == "rowboat" then
			piece(model, "Boat", v3(4.4, 1.6, 8), CFrame.new(0, -0.8, 0), rgb(200, 80, 60), Enum.Material.WoodPlanks)
			piece(model, "Inside", v3(3.6, 0.3, 7), CFrame.new(0, 0, 0), rgb(110, 70, 44), Enum.Material.WoodPlanks)
			piece(model, "Flag", v3(0.2, 1.8, 2.4), CFrame.new(0, 2.2, -3), rgb(255, 214, 90), Enum.Material.Fabric)
		elseif target.kind == "perch" then
			piece(
				model,
				"Basket",
				v3(3.4, 2, 3.4),
				CFrame.new(0, -1, 0) * UP,
				rgb(214, 170, 100),
				Enum.Material.Fabric,
				"cyl"
			)
			piece(model, "BasketInside", v3(0.2, 2.8, 2.8), CFrame.new(0, 0.02, 0) * UP, rgb(90, 60, 36), nil, "cyl")
			piece(model, "Parrot", v3(1.4, 1.8, 1.4), CFrame.new(0, 1.4, 1.2), rgb(232, 50, 46), nil, "ball")
		else
			-- The King's mouth: a dark hole that opens and shuts.
			piece(model, "MouthBack", v3(0.4, 4, 6), CFrame.new(0.3, 0, 0), rgb(60, 20, 20), nil)
			kingMouth = {
				top = piece(model, "LipTop", v3(1.4, 1, 6.4), CFrame.new(0, 1.6, 0), rgb(150, 70, 60)),
				bottom = piece(model, "LipBottom", v3(1.4, 1, 6.4), CFrame.new(0, -1.6, 0), rgb(150, 70, 60)),
				tongue = piece(model, "Tongue", v3(1.6, 0.6, 3), CFrame.new(-0.2, -1, 0), rgb(230, 100, 120)),
			}
		end
		model.WorldPivot = CFrame.identity -- the target's point is the model's origin
		model:SetAttribute("Kind", target.kind)
		tossModels[index] = model
	end
end

local function sail(model, name, mast, height, width, color)
	piece(
		model,
		name .. "Mast",
		v3(0.6, height, 0.6),
		CFrame.new(0, height / 2, mast),
		Palette.WOOD_DARK,
		Enum.Material.Wood
	)
	piece(model, name, v3(0.3, height * 0.7, width), CFrame.new(0.3, height * 0.55, mast), color, Enum.Material.Fabric)
end

local function buildGallery()
	for index, target in ipairs(gallery.targets) do
		local model = newModel("GalleryTarget" .. index)
		if target.kind == "galleon" or target.kind == "sloop" or target.kind == "skiff" or target.kind == "barge" then
			local scale = ({ galleon = 1.6, sloop = 1.1, skiff = 0.75, barge = 1.2 })[target.kind]
			local hull = target.kind == "barge" and Palette.GOLD or rgb(90, 56, 36)
			-- A cut-out: a flat hull and sails, painted, standing on a float, turned side-on to the cannons.
			piece(
				model,
				"Float",
				v3(3 * scale, 1, 16 * scale),
				CFrame.new(0, -0.5, 0),
				rgb(70, 60, 52),
				Enum.Material.Wood
			)
			piece(
				model,
				"Hull",
				v3(0.6, 4 * scale, 16 * scale),
				CFrame.new(0, 2 * scale, 0),
				hull,
				Enum.Material.WoodPlanks
			)
			piece(
				model,
				"Stripe",
				v3(0.7, 0.7 * scale, 16 * scale),
				CFrame.new(0, 3 * scale, 0),
				target.kind == "barge" and rgb(150, 40, 150) or rgb(230, 190, 80),
				Enum.Material.SmoothPlastic
			)
			sail(
				model,
				"Sail",
				0,
				10 * scale,
				7 * scale,
				target.kind == "barge" and rgb(150, 40, 150) or rgb(30, 28, 34)
			)
			if target.kind == "galleon" then
				sail(model, "Sail2", -5 * scale, 8 * scale, 6 * scale, rgb(30, 28, 34))
			end
			piece(
				model,
				"Skull",
				v3(0.4, 2 * scale, 2 * scale),
				CFrame.new(0.5, 6.4 * scale, 0),
				rgb(246, 244, 238),
				nil,
				"ball"
			)
			piece(
				model,
				"Points",
				v3(0.3, 2.4, 2.4),
				CFrame.new(-0.4, 2 * scale, 0),
				rgb(255, 230, 120),
				Enum.Material.Neon,
				"cyl"
			)
		else
			-- A kraken's tentacle.
			piece(model, "TentacleBase", v3(3, 4, 3), CFrame.new(0, -2, 0), rgb(150, 60, 140), nil, "ball")
			for k = 1, 4 do
				piece(
					model,
					"Tentacle" .. k,
					v3(2.6 - k * 0.4, 3, 2.6 - k * 0.4),
					CFrame.new(math.sin(k) * 0.8, k * 2.6, 0),
					rgb(170, 70, 160),
					nil,
					"ball"
				)
			end
		end
		model.WorldPivot = CFrame.identity -- the target's point is the model's origin
		model:SetAttribute("Kind", target.kind)
		galleryModels[index] = model
	end
end

-- Drawing ---------------------------------------------------------------------------------------------------------------------
local function near(position)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - position).Magnitude <= G.VENUE_DRAW + 120
end

local function drawToss(t)
	local show = near(toss.king) and player:GetAttribute("Zone") ~= "raid"
	for index, model in pairs(tossModels) do
		if not show then
			model.Parent = nil
		else
			model.Parent = folder
			local at, open, target = PortGames.targetAt(toss, index, t)
			if target.kind == "king" then
				local o = open and 1 or 0
				local cf = CFrame.lookAt(at, at + v3(-1, 0, 0))
				model:PivotTo(cf)
				if kingMouth then
					kingMouth.top.CFrame = cf * CFrame.new(0, 1.2 + o * 1.4, 0)
					kingMouth.bottom.CFrame = cf * CFrame.new(0, -1.2 - o * 1.4, 0)
					kingMouth.tongue.Transparency = open and 0 or 1
				end
			elseif target.kind == "perch" then
				model:PivotTo(CFrame.lookAt(at, v3(toss.perch.X, at.Y, toss.perch.Z)))
			else
				model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0))
			end
		end
	end
end

local function drawGallery(t)
	local show = near(gallery.deck) and player:GetAttribute("Zone") ~= "raid"
	-- Ships the server knocked down (the session's public `down`): { [index] = { from, until } }.
	local down = {}
	for _, session in pairs(ctx.sessions or {}) do
		if session.game == "gallery" and session.extra and session.extra.down then
			for key, span in pairs(session.extra.down) do
				down[tonumber(key)] = span
			end
		end
	end
	for index, model in pairs(galleryModels) do
		if not show then
			model.Parent = nil
		else
			local at, open, target = PortGames.targetAt(gallery, index, t)
			local visible = open
			if target.kind == "kraken" then
				local phase = (t % 7) / 2.5
				visible = phase < 1
				at = at + v3(0, (visible and math.sin(math.min(1, phase * 3) * math.pi / 2) or 0) * 2 - 6, 0)
			end
			model.Parent = visible and folder or nil
			if visible then
				local heading = PortGames.GALLERY.across
				local cf = CFrame.lookAt(at, at + heading)
				local span = down[index]
				if span and t >= span[1] and t < span[2] then
					-- Keeled over and sinking a little, then back up.
					local k = math.clamp((t - span[1]) / 0.35, 0, 1) * math.clamp((span[2] - t) / 0.5, 0, 1)
					cf = cf * CFrame.new(0, -2.5 * k, 0) * CFrame.Angles(0, 0, math.rad(80 * k))
				else
					cf = cf * CFrame.Angles(0, 0, math.rad(4 * math.sin(t * 1.6 + index)))
				end
				model:PivotTo(cf)
			end
		end
	end
end

-- The chests over the heads of everyone at the toss line.
local function drawChests()
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local head = character and character:FindFirstChild("Head")
		local want = other:GetAttribute("TossChest") == true and head ~= nil
		local chest = chests[other]
		if want and not chest then
			chest = newModel("TossChest")
			piece(chest, "Chest", v3(2.2, 1.4, 1.5), CFrame.new(), Palette.WOOD, Enum.Material.WoodPlanks)
			piece(chest, "Band", v3(2.3, 0.3, 1.6), CFrame.new(0, 0.3, 0), Palette.GOLD, Enum.Material.Metal)
			chest.WorldPivot = CFrame.identity
			chest.Parent = folder
			chests[other] = chest
		elseif not want and chest then
			chest:Destroy()
			chests[other] = nil
		end
		if want and chest then
			chest:PivotTo(head.CFrame * CFrame.new(0, 2.2, 0))
		end
	end
	for other, chest in pairs(chests) do
		if not other.Parent then
			chest:Destroy()
			chests[other] = nil
		end
	end
end

-- A projectile in flight, drawn along the server's own arc.
local function fly(p, isBall)
	local model = newModel(isBall and "Cannonball" or "ThrownChest")
	if isBall then
		piece(model, "Ball", v3(2.2, 2.2, 2.2), CFrame.new(), rgb(40, 38, 46), Enum.Material.Metal, "ball")
	else
		piece(model, "Chest", v3(2.2, 1.4, 1.5), CFrame.new(), Palette.WOOD, Enum.Material.WoodPlanks)
		piece(model, "Band", v3(2.3, 0.3, 1.6), CFrame.new(0, 0.3, 0), Palette.GOLD, Enum.Material.Metal)
	end
	model.WorldPivot = CFrame.identity
	model.Parent = folder
	local from, v, g, t0, landAt = p.from, p.velocity, p.gravity, p.t0, p.landAt
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.min(now(), landAt)
		local s = math.max(0, t - t0)
		local at = from + v * s + v3(0, -0.5 * g * s * s, 0)
		model:PivotTo(CFrame.new(at) * CFrame.Angles(s * 6, s * 4, 0))
		if now() >= landAt then
			connection:Disconnect()
			model:Destroy()
			local where = p.at or at
			if p.hit then
				Effects.burst(where, C.gold, 30, 26)
				Effects.ring(where, C.goldPale, 8, 0.5)
				Effects.sound(isBall and "boom" or "thud", { position = where, speed = 1.1, volume = 0.9, range = 500 })
				local anchor = Ui.make("Part", {
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Transparency = 1,
					Size = v3(0.2, 0.2, 0.2),
					CFrame = CFrame.new(where + v3(0, 4, 0)),
				}, folder)
				local bill = Ui.make("BillboardGui", {
					Adornee = anchor,
					Size = UDim2.fromOffset(120, 50),
					AlwaysOnTop = true,
					LightInfluence = 0,
					MaxDistance = 600,
				}, anchor)
				local label = Ui.label(bill, {
					Size = UDim2.fromScale(1, 1),
					Text = "+" .. tostring(p.points or 0),
					Font = Ui.TITLE,
					TextScaled = true,
					TextColor3 = p.userId == player.UserId and C.goldPale or C.white,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				Ui.stroke(label, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				task.delay(1.4, function()
					anchor:Destroy()
				end)
				if p.userId == player.UserId then
					Effects.chime({ 1.26, 1.5, 2 }, 0.5)
				end
			elseif isBall or (where.Y <= 3) then
				Effects.spray(where, 0.8)
				Effects.sound("splash", { position = where, volume = 0.6, range = 400 })
			else
				Effects.burst(where, rgb(150, 120, 80), 12, 14)
				Effects.sound("thud", { position = where, volume = 0.6, range = 300 })
			end
		end
	end)
end

function PlayRange.fx(p)
	if p.kind == "toss" and p.from then
		fly(p, false)
		return true
	elseif p.kind == "cannonshot" and p.from then
		Effects.burst(p.from, rgb(255, 200, 120), 18, 22)
		Effects.sound("boom", { position = p.from, speed = 1, volume = 1, range = 700 })
		fly(p, true)
		return true
	end
	return false
end

-- Aiming and firing --------------------------------------------------------------------------------------------------------
local function myStation()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestD
	for _, station in ipairs(gallery.stations) do
		local d = (station.seat - root.Position).Magnitude
		if not bestD or d < bestD then
			best, bestD = station, d
		end
	end
	return bestD and bestD < 12 and best or nil
end

local function galleryLook()
	local base = gallery.facing
	local yawed = PortGames.turn(base, math.deg(aimYaw))
	return (yawed * math.cos(aimPitch) + v3(0, math.sin(aimPitch), 0)).Unit
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function fireAction(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local session = ctx.mine
	if not session or session.state ~= "running" then
		return Enum.ContextActionResult.Pass
	end
	local camera = workspace.CurrentCamera
	if mode == "toss" then
		ctx.remote:FireServer("toss", camera.CFrame.LookVector)
		Effects.sound("whoosh", { speed = 1.4, volume = 0.5 })
		return Enum.ContextActionResult.Sink
	elseif mode == "gallery" then
		local station = myStation()
		if not station then
			return Enum.ContextActionResult.Pass
		end
		aimParams.FilterDescendantsInstances = { player.Character, folder }
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 800, aimParams)
		local point = hit and hit.Position or (camera.CFrame.Position + camera.CFrame.LookVector * 300)
		-- Aimed into the sky: the shot goes to the water under where it was looking.
		if point.Y > 40 then
			point = v3(point.X, gallery.water, point.Z)
		end
		ctx.remote:FireServer("fire", point)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bind(newMode)
	if mode == newMode then
		return
	end
	if mode then
		ContextActionService:UnbindAction("LootGoblinsRangeFire")
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		local camera = workspace.CurrentCamera
		if mode == "gallery" and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
	mode = newMode
	if newMode == "toss" then
		ContextActionService:BindActionAtPriority(
			"LootGoblinsRangeFire",
			fireAction,
			true,
			3100,
			Enum.UserInputType.MouseButton1,
			Enum.KeyCode.Q,
			Enum.KeyCode.ButtonR2,
			Enum.KeyCode.ButtonL1
		)
		ContextActionService:SetTitle("LootGoblinsRangeFire", "THROW")
		hint.Text = "AIM WITH THE CAMERA  ·  CLICK OR Q TO THROW  ·  LOB IT IN"
	elseif newMode == "gallery" then
		aimYaw, aimPitch = 0, math.rad(4)
		ContextActionService:BindActionAtPriority(
			"LootGoblinsRangeFire",
			fireAction,
			true,
			3100,
			Enum.UserInputType.MouseButton1,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonR2,
			Enum.KeyCode.ButtonA
		)
		ContextActionService:SetTitle("LootGoblinsRangeFire", "FIRE")
		hint.Text = "LOOK TO AIM  ·  CLICK OR SPACE TO FIRE  ·  SMALL, FAST SHIPS SCORE MORE"
	end
	if newMode then
		ContextActionService:SetPosition("LootGoblinsRangeFire", UDim2.new(1, -150, 1, -150))
	end
	gui.Enabled = newMode ~= nil
end

function PlayRange.start(context)
	ctx = context
	folder = Instance.new("Folder")
	folder.Name = "LootGoblinsRanges"
	folder.Parent = workspace
	buildToss()
	buildGallery()
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsRange", ResetOnSpawn = false, DisplayOrder = 8, Enabled = false },
		player:WaitForChild("PlayerGui")
	)
	crosshair = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Text = "+",
		Font = Ui.TITLE,
		TextSize = 40,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(crosshair, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	hint = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(560, 24),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(hint, C.night, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	UserInputService.InputChanged:Connect(function(input, processed)
		if mode ~= "gallery" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v = v3(input.Position.X, input.Position.Y, 0)
			stick = v.Magnitude > 0.18 and Vector2.new(v.X, v.Y) or Vector2.zero
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			touchDrag += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
end

function PlayRange.update(dt, context)
	ctx = context
	local t = context.t
	drawToss(t)
	drawGallery(t)
	drawChests()
	local session = context.mine
	local want = nil
	if session and session.state == "running" and (session.game == "toss" or session.game == "gallery") then
		want = session.game
	end
	bind(want)
	if mode == "toss" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	elseif mode == "gallery" then
		local station = myStation()
		if station then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			local delta = UserInputService:GetMouseDelta() + touchDrag
			touchDrag = Vector2.zero
			aimYaw = math.clamp(aimYaw + delta.X * 0.003 + stick.X * dt * 1.2, -math.rad(62), math.rad(62))
			aimPitch = math.clamp(aimPitch - delta.Y * 0.003 + stick.Y * dt * 0.8, math.rad(-12), math.rad(28))
			local look = galleryLook()
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Scriptable
			local eye = station.muzzle - look * 9 + v3(0, 3.4, 0)
			camera.CFrame = CFrame.lookAt(eye, eye + look)
			camera.FieldOfView = 60
			if os.clock() >= nextAimSend then
				nextAimSend = os.clock() + 0.25
				ctx.remote:FireServer("aim", look)
			end
		end
	end
end

return PlayRange

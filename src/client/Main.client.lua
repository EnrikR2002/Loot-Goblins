local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local dropRemote = remotes:WaitForChild("DropRequest")
local grappleRemote = remotes:WaitForChild("GrappleRequest")
local soulRemote = remotes:WaitForChild("SoulUnboundRequest")
local eventRemote = remotes:WaitForChild("GameEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "LootGoblinsHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.035)
status.Size = UDim2.fromOffset(760, 54)
status.BackgroundTransparency = 0.25
status.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.GothamBold
status.TextScaled = true
status.Text = "STEAL THE GOLDEN IDOL"
status.Parent = gui

local help = Instance.new("TextLabel")
help.AnchorPoint = Vector2.new(0.5, 1)
help.Position = UDim2.fromScale(0.5, 0.97)
help.Size = UDim2.fromOffset(760, 38)
help.BackgroundTransparency = 0.35
help.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
help.TextColor3 = Color3.fromRGB(235, 235, 235)
help.Font = Enum.Font.GothamMedium
help.TextScaled = true
help.Text =
	"E = grab / Soul Unbound  |  Click = swing sword  |  F = grapple/steal  |  Q = drop idol  |  Drive the ugly boat home"
help.Parent = gui

local function flash(text, duration)
	status.Text = text
	status.TextTransparency = 0
	status.BackgroundTransparency = 0.12
	local tween = TweenService:Create(status, TweenInfo.new(0.25), { BackgroundTransparency = 0.25 })
	tween:Play()
	if duration then
		task.delay(duration, function()
			if status.Text == text then
				status.Text = "STEAL → ESCAPE → BANK"
			end
		end)
	end
end

local function grappleLine(fromPos, toPos)
	local distance = (toPos - fromPos).Magnitude
	if distance <= 0.1 then
		return
	end
	local beamPart = Instance.new("Part")
	beamPart.Name = "GrappleFX"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.CanTouch = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = Color3.fromRGB(255, 245, 120)
	beamPart.Size = Vector3.new(0.18, 0.18, distance)
	beamPart.CFrame = CFrame.lookAt((fromPos + toPos) / 2, toPos)
	beamPart.Parent = workspace
	Debris:AddItem(beamPart, 0.18)
end

-- Soul Unbound (Yone's E) ----------------------------------------------------
-- The server owns the spirit and reports it through two player attributes. The
-- client only plays its own dash at once, so the key feels instant.
local SPIRIT_COLOR = Color3.fromRGB(110, 205, 255)
local MARK_COLOR = Color3.fromRGB(255, 70, 150)
local camera = workspace.CurrentCamera
local lastSoulCast = -math.huge

local soulSlot = Instance.new("Frame")
soulSlot.Name = "SoulUnbound"
soulSlot.AnchorPoint = Vector2.new(0.5, 1)
soulSlot.Position = UDim2.new(0.5, 0, 0.97, -46)
soulSlot.Size = UDim2.fromOffset(260, 34)
soulSlot.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
soulSlot.BackgroundTransparency = 0.25
soulSlot.ClipsDescendants = true
soulSlot.Parent = gui
Instance.new("UICorner").Parent = soulSlot
local soulStroke = Instance.new("UIStroke")
soulStroke.Color = SPIRIT_COLOR
soulStroke.Thickness = 2
soulStroke.Parent = soulSlot

local soulFill = Instance.new("Frame")
soulFill.BorderSizePixel = 0
soulFill.BackgroundColor3 = SPIRIT_COLOR
soulFill.Size = UDim2.fromScale(1, 1)
soulFill.Parent = soulSlot

local soulText = Instance.new("TextLabel")
soulText.BackgroundTransparency = 1
soulText.Size = UDim2.fromScale(1, 1)
soulText.Font = Enum.Font.GothamBold
soulText.TextSize = 17
soulText.TextColor3 = Color3.new(1, 1, 1)
soulText.TextStrokeTransparency = 0.6
soulText.ZIndex = 2
soulText.Parent = soulSlot

-- The world turns cold and pale while you are a spirit. Lighting effects made here stay local.
local spiritTint = Instance.new("ColorCorrectionEffect")
spiritTint.Name = "SoulUnboundTint"
spiritTint.Parent = Lighting

player:GetAttributeChangedSignal("SoulUnboundEndsAt"):Connect(function()
	local active = player:GetAttribute("SoulUnboundEndsAt") ~= nil
	TweenService:Create(spiritTint, TweenInfo.new(active and 0.15 or 0.35), {
		TintColor = active and Color3.fromRGB(200, 228, 255) or Color3.new(1, 1, 1),
		Saturation = active and -0.45 or 0,
	}):Play()
end)

local function updateSoulHud(now)
	local endsAt = player:GetAttribute("SoulUnboundEndsAt")
	local readyAt = player:GetAttribute("SoulUnboundReadyAt") or 0
	if endsAt then
		local left = math.max(endsAt - now, 0)
		soulFill.Size = UDim2.fromScale(left / Config.SOUL_DURATION, 1)
		soulFill.BackgroundTransparency = 0.35
		soulStroke.Transparency = 0
		soulText.Text = string.format("E  RETURN TO BODY  %.1f", left)
	elseif now < readyAt then
		local left = readyAt - now
		soulFill.Size = UDim2.fromScale(1 - left / Config.SOUL_COOLDOWN, 1)
		soulFill.BackgroundTransparency = 0.75
		soulStroke.Transparency = 0.6
		soulText.Text = string.format("SOUL UNBOUND  %.1f", left)
	else
		soulFill.Size = UDim2.fromScale(1, 1)
		soulFill.BackgroundTransparency = 0.55
		soulStroke.Transparency = 0
		soulText.Text = "E  SOUL UNBOUND"
	end
end

-- E is also the ProximityPrompt key. A visible prompt (idol, sword) gets it first.
local shownPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	shownPrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shownPrompts[prompt] = nil
end)

local function promptOwnsE()
	for prompt in pairs(shownPrompts) do
		if prompt.Parent and prompt.Enabled and prompt.KeyboardKeyCode == Enum.KeyCode.E then
			return true
		end
	end
	return false
end

-- Once you have a sword, its prompt would only eat E, so hide it for you.
local function hideOwnedSwordPrompt()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local pickup = generated and generated:FindFirstChild("SwordPickup")
	local handle = pickup and pickup:FindFirstChild("Handle")
	local swordPrompt = handle and handle:FindFirstChild("GrabPrompt")
	if swordPrompt then
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local ownsSword = (backpack and backpack:FindFirstChild("Sword"))
			or (character and character:FindFirstChild("Sword"))
		swordPrompt.Enabled = not ownsSword
	end
end

local function playSoulDash(root, humanoid)
	-- Dash where you are walking, or where you face when standing still.
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)

	local attachment = Instance.new("Attachment")
	attachment.Name = "SoulDash"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	push.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	push.VectorVelocity = direction * (Config.SOUL_DASH_DISTANCE / Config.SOUL_DASH_TIME)
	push.Parent = attachment
	task.delay(Config.SOUL_DASH_TIME, function()
		attachment:Destroy()
		if root.Parent then
			-- Leave the dash at running speed instead of sliding on.
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				+ direction * humanoid.WalkSpeed
		end
	end)

	camera.FieldOfView = 78
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { FieldOfView = 70 }):Play()
end

local function pressSoulUnbound()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or promptOwnsE() then
		return
	end
	local now = workspace:GetServerTimeNow()
	local endsAt = player:GetAttribute("SoulUnboundEndsAt")
	if endsAt then
		-- E again snaps back early once the recast delay has passed.
		if now >= endsAt - Config.SOUL_DURATION + Config.SOUL_RECAST_DELAY then
			soulRemote:FireServer()
		end
		return
	end
	-- lastSoulCast covers the moment before the server's attributes arrive.
	if
		humanoid.SeatPart
		or now - lastSoulCast < Config.SOUL_RECAST_DELAY
		or now < (player:GetAttribute("SoulUnboundReadyAt") or 0)
	then
		return
	end
	lastSoulCast = now
	soulRemote:FireServer()
	playSoulDash(root, humanoid)
end

local function fxPart(size, cframe, color)
	local p = Instance.new("Part")
	p.Name = "SoulFX"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = workspace
	return p
end

local function fadeOut(p, duration, goal)
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad), goal):Play()
	Debris:AddItem(p, duration)
end

local function soulRing(position, color, radius)
	-- Cylinders run along X, so tip it up to lie flat on the ground.
	local ring = fxPart(Vector3.new(0.2, 2, 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	fadeOut(ring, 0.45, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
end

local function soulStreak(fromPos, toPos)
	local distance = (toPos - fromPos).Magnitude
	if distance < 0.5 then
		return
	end
	local streak = fxPart(Vector3.new(0.6, 0.6, distance), CFrame.lookAt((fromPos + toPos) / 2, toPos), SPIRIT_COLOR)
	streak.Transparency = 0.2
	fadeOut(streak, 0.3, { Size = Vector3.new(0.05, 0.05, distance) })
end

local function soulSlash(position)
	-- An X that faces this player's camera.
	for _, angle in ipairs({ 45, -45 }) do
		local cframe = CFrame.lookAt(position, camera.CFrame.Position) * CFrame.Angles(0, 0, math.rad(angle))
		local slash = fxPart(Vector3.new(0.3, 7, 0.3), cframe, MARK_COLOR)
		fadeOut(slash, 0.4, { Size = Vector3.new(0.05, 9, 0.05) })
	end
	soulRing(position - Vector3.new(0, 2.5, 0), MARK_COLOR, 5)
end

RunService.RenderStepped:Connect(function()
	updateSoulHud(workspace:GetServerTimeNow())
	hideOwnedSwordPrompt()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		dropRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.F then
		local mouse = player:GetMouse()
		grappleRemote:FireServer(mouse.Hit.Position, mouse.Target)
	elseif input.KeyCode == Enum.KeyCode.E then
		pressSoulUnbound()
	end
end)

eventRemote.OnClientEvent:Connect(function(kind, payload)
	if kind == "Message" then
		flash(payload.text or "", payload.duration or 2)
	elseif kind == "Carrier" then
		if payload.userId == player.UserId then
			flash("YOU HAVE THE IDOL — RUN!", 2)
		elseif payload.name then
			flash(string.upper(payload.name) .. " HAS THE IDOL", 2)
		else
			flash("THE IDOL IS LOOSE", 1.5)
		end
	elseif kind == "Banked" then
		flash("BANKED BY " .. string.upper(payload.name) .. " — YESSS", 3.5)
	elseif kind == "GrappleFX" then
		grappleLine(payload.from, payload.to)
	elseif kind == "SoulUnbound" then
		if payload.phase == "cast" then
			soulRing(payload.from - Vector3.new(0, 2.5, 0), SPIRIT_COLOR, 7)
		elseif payload.phase == "return" then
			soulStreak(payload.from, payload.to)
			soulRing(payload.to - Vector3.new(0, 2.5, 0), SPIRIT_COLOR, 9)
		elseif payload.phase == "echo" then
			for _, position in ipairs(payload.hits) do
				soulSlash(position)
			end
		end
	end
end)

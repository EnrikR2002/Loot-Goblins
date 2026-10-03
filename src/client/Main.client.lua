local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local dropRemote = remotes:WaitForChild("DropRequest")
local grappleRemote = remotes:WaitForChild("GrappleRequest")
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
help.Text = "E = grab idol  |  F = grapple/steal  |  Q = drop idol  |  Drive the ugly boat home"
help.Parent = gui

local function flash(text, duration)
	status.Text = text
	status.TextTransparency = 0
	status.BackgroundTransparency = 0.12
	local tween = TweenService:Create(status, TweenInfo.new(0.25), {BackgroundTransparency = 0.25})
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
	if distance <= 0.1 then return end
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

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		dropRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.F then
		local mouse = player:GetMouse()
		grappleRemote:FireServer(mouse.Hit.Position, mouse.Target)
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
	end
end)

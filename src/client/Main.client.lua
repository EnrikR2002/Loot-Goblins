-- Loot Goblins client: input, the bits of movement the client owns (the
-- Poltergoblin dash, ziplines, launch pads), and turning server events into
-- HUD messages and effects. The server decides everything that matters.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local throwRemote = remotes:WaitForChild("ThrowRequest")
local grappleRemote = remotes:WaitForChild("GrappleRequest")
local polterRemote = remotes:WaitForChild("PoltergoblinRequest")
local eventRemote = remotes:WaitForChild("GameEvent")

local generated = workspace:WaitForChild("LootGoblinsGenerated")
local hoardPart = generated:WaitForChild("Ground"):WaitForChild("Hoard")

local SPIRIT_COLOR = Color3.fromRGB(120, 255, 170)
local MARK_COLOR = Color3.fromRGB(190, 90, 255)
local GOLD = Color3.fromRGB(255, 205, 50)
local DANGER = Color3.fromRGB(255, 80, 60)

local LOOT_COLORS = {}
for _, def in ipairs(Config.LOOT) do
	LOOT_COLORS[def.id] = def.color
end

Hud.init(hoardPart)
Hud.showHelp(14)

local function now()
	return workspace:GetServerTimeNow()
end

local function getCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

local function inWard(position)
	local hoard = hoardPart.Position
	return Vector3.new(position.X - hoard.X, 0, position.Z - hoard.Z).Magnitude <= Config.WARD_RADIUS
end

-- E is shared: a visible prompt (loot, zipline) always gets it first ----------------------
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

-- Ziplines (client-driven ride; your own character is yours to move) ---------------------
local ride = nil

local function stopRide(fling)
	if not ride then
		return
	end
	local current = ride
	ride = nil
	local _, _, root = getCharacter()
	if root and fling then
		root.AssemblyLinearVelocity = current.direction * Config.ZIPLINE_SPEED * 0.5 + Vector3.new(0, 12, 0)
	end
end

local function startRide(model)
	local from = model:GetAttribute("ZipFrom")
	local to = model:GetAttribute("ZipTo")
	local _, humanoid, root = getCharacter()
	if ride or not root or humanoid.SeatPart or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	if (root.Position - from).Magnitude > 25 then
		return
	end
	ride = {
		from = from,
		direction = (to - from).Unit,
		length = (to - from).Magnitude,
		travelled = 0,
	}
	Effects.sound("whoosh", { speed = 1.3, volume = 0.5 })
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ZiplinePrompt" then
		local model = prompt:FindFirstAncestorOfClass("Model")
		if model then
			startRide(model)
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	-- Jump lets go of the zipline mid-ride.
	if ride and ride.travelled > 4 then
		stopRide(true)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not ride then
		return
	end
	local _, _, root = getCharacter()
	if not root or player:GetAttribute("PolterEndsAt") then
		stopRide(false)
		return
	end
	ride.travelled = math.min(ride.travelled + Config.ZIPLINE_SPEED * dt, ride.length)
	local position = ride.from + ride.direction * ride.travelled + Vector3.new(0, -3.4, 0)
	local flat = Vector3.new(ride.direction.X, 0, ride.direction.Z)
	root.CFrame = CFrame.lookAt(position, position + flat)
	root.AssemblyLinearVelocity = ride.direction * Config.ZIPLINE_SPEED
	if ride.travelled >= ride.length then
		stopRide(true)
	end
end)

-- Launch pads -------------------------------------------------------------------------
local lastLaunch = 0
local function hookPad(pad)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local character, _, root = getCharacter()
		if not character or not hit:IsDescendantOf(character) or os.clock() - lastLaunch < 0.8 then
			return
		end
		local launch = pad:GetAttribute("Launch")
		if typeof(launch) ~= "Vector3" then
			return
		end
		lastLaunch = os.clock()
		root.AssemblyLinearVelocity = launch
		Effects.sound("whoosh", { speed = 0.7, volume = 0.8 })
		Effects.burst(pad.Position, Color3.fromRGB(120, 255, 130), 25, 20)
		Effects.punchFov(82)
	end)
end
local pads = generated:WaitForChild("LaunchPads")
for _, pad in ipairs(pads:GetChildren()) do
	hookPad(pad)
end
pads.ChildAdded:Connect(hookPad)

-- Poltergoblin --------------------------------------------------------------------------
-- The server owns the spirit. The client only plays its own dash at once so the
-- key feels instant; the server never trusts a position from here.
local lastPolterCast = -math.huge

local function playDash(root, humanoid)
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
	attachment.Name = "PolterDash"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	push.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	push.VectorVelocity = direction * (Config.POLTER_DASH_DISTANCE / Config.POLTER_DASH_TIME)
	push.Parent = attachment
	task.delay(Config.POLTER_DASH_TIME, function()
		attachment:Destroy()
		if root.Parent then
			-- Leave the dash at running speed instead of sliding on.
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				+ direction * humanoid.WalkSpeed
		end
	end)
	Effects.punchFov(80)
end

local function pressPoltergoblin()
	local _, humanoid, root = getCharacter()
	if not root or promptOwnsE() then
		return
	end
	local t = now()
	local endsAt = player:GetAttribute("PolterEndsAt")
	if endsAt then
		-- E again snaps back early once the recast delay has passed.
		if t >= endsAt - Config.POLTER_DURATION + Config.POLTER_RECAST_DELAY then
			polterRemote:FireServer()
		end
		return
	end
	if humanoid.SeatPart or t - lastPolterCast < Config.POLTER_RECAST_DELAY then
		return
	end
	if t < (player:GetAttribute("PolterReadyAt") or 0) then
		Hud.toast("Poltergoblin is recharging")
		return
	end
	if inWard(root.Position) then
		Hud.toast("The Hoard's ward blocks Poltergoblin. Step outside the purple ring.")
		return
	end
	stopRide(false)
	lastPolterCast = t
	polterRemote:FireServer()
	playDash(root, humanoid)
end

-- Spirit form tints the screen for the spirit only.
player:GetAttributeChangedSignal("PolterEndsAt"):Connect(function()
	Effects.setSpirit(player:GetAttribute("PolterEndsAt") ~= nil)
end)

local function soulSlash(position)
	local camera = workspace.CurrentCamera
	for _, angle in ipairs({ 45, -45 }) do
		local cframe = CFrame.lookAt(position, camera.CFrame.Position) * CFrame.Angles(0, 0, math.rad(angle))
		Effects.line(
			cframe.Position - cframe.UpVector * 3.5,
			cframe.Position + cframe.UpVector * 3.5,
			MARK_COLOR,
			0.3,
			0.4
		)
	end
	Effects.ring(position - Vector3.new(0, 2.5, 0), MARK_COLOR, 5)
end

-- Input ------------------------------------------------------------------------------------
local mouse = player:GetMouse()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		if player:GetAttribute("CarryingLoot") then
			throwRemote:FireServer()
		else
			Hud.toast("Nothing to throw. Grab some loot first.")
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		if now() < (player:GetAttribute("GrappleReadyAt") or 0) then
			Hud.toast("Grapple is recharging")
			return
		end
		mouse.TargetFilter = player.Character
		grappleRemote:FireServer(mouse.Hit.Position, mouse.Target)
	elseif input.KeyCode == Enum.KeyCode.E then
		pressPoltergoblin()
	elseif input.KeyCode == Enum.KeyCode.H then
		Hud.toggleHelp()
	end
end)

-- Screen tint follows Heat, including for players who join mid-raid.
local function applyHeatTint()
	Effects.setHeatTier(workspace:GetAttribute("HeatTier") or 1)
end
workspace:GetAttributeChangedSignal("HeatTier"):Connect(applyHeatTint)
applyHeatTint()

RunService.RenderStepped:Connect(function()
	Hud.update(now())
end)

-- Server events --------------------------------------------------------------------------
local function isMe(payload)
	return payload.userId == player.UserId
end

local handlers = {}

function handlers.Message(p)
	Hud.banner(p.text or "", p.color, p.duration)
end

function handlers.Feed(p)
	Hud.feed(p.text or "", p.color)
end

function handlers.Toast(p)
	Hud.toast(p.text or "")
end

function handlers.Stolen(p)
	local color = LOOT_COLORS[p.item] or GOLD
	if isMe(p) then
		Hud.banner("YOU STOLE THE " .. string.upper(p.itemName) .. "! RUN FOR THE HOARD!", color, 3)
		Hud.flash(color, 0.3)
	else
		Hud.banner(string.upper(p.name) .. " STOLE THE " .. string.upper(p.itemName) .. "!", color, 3)
	end
	Effects.chime(Effects.CHIME_STEAL, 0.8)
	Effects.burst(p.position, color, 40, 24)
	Effects.ring(p.position, color, 16, 0.6)
end

function handlers.Snatched(p)
	if isMe(p) then
		Hud.banner("GOT IT! " .. string.upper(p.itemName) .. " IS YOURS", GOLD, 2)
		Effects.chime(Effects.CHIME_GOOD, 0.6)
	elseif p.from == player.DisplayName then
		Hud.banner(string.upper(p.name) .. " GRAPPLED YOUR " .. string.upper(p.itemName) .. "!", DANGER, 2.5)
		Hud.flash(DANGER, 0.35)
		Effects.chime(Effects.CHIME_STEAL, 0.7)
	else
		Hud.banner(string.upper(p.name) .. " GRAPPLED THE " .. string.upper(p.itemName) .. "!", nil, 2)
	end
end

function handlers.Grabbed(p)
	if isMe(p) then
		Hud.banner("YOU GRABBED THE " .. string.upper(p.itemName) .. "!", GOLD, 1.6)
		Effects.chime({ 1, 1.5 }, 0.5)
	end
end

function handlers.LootLoose(p)
	local color = LOOT_COLORS[p.item] or GOLD
	Effects.burst(p.position, color, 25, 16)
	Effects.ring(p.position, color, 8, 0.4)
	Effects.sound("thud", { position = p.position, volume = 0.9, speed = 0.8 })
end

function handlers.Banked(p)
	local color = LOOT_COLORS[p.item] or GOLD
	if isMe(p) then
		Hud.banner(
			string.format("BANKED THE %s! +%d GOLD (%d total)", string.upper(p.itemName), p.value, p.total),
			GOLD,
			3.5
		)
		Hud.flash(GOLD, 0.35)
	else
		Hud.banner(
			string.format("%s BANKED THE %s (+%d)", string.upper(p.name), string.upper(p.itemName), p.value),
			color,
			3
		)
	end
	Effects.chime(Effects.CHIME_GOOD, 0.9)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			Effects.burst(p.position + Vector3.new(0, 3 + i * 3, 0), i == 1 and color or GOLD, 45, 28)
		end)
	end
	Effects.ring(p.position, GOLD, 22, 0.8)
	Effects.sound("boom", { position = p.position, volume = 0.5, speed = 1.4 })
end

function handlers.Trouble(p)
	task.delay(1.1, function()
		Hud.banner(p.text or "TROUBLE!", DANGER, 2.6)
	end)
	if p.kind == "Bell" then
		for i = 0, 2 do
			task.delay(i * 0.5, function()
				Effects.sound("blip", { speed = 0.35, volume = 1 })
			end)
		end
	elseif p.kind == "CaveIn" or p.kind == "Guardian" then
		Effects.sound("boom", { position = p.position, speed = 0.45, volume = 1, range = 600 })
	else
		Effects.chime(Effects.CHIME_ALARM, 0.8)
	end
end

function handlers.HeatTier(p)
	local info = Config.HEAT_TIERS[p.tier]
	local color = info and info.color or DANGER
	Hud.heatHint("HEAT " .. (p.name or "") .. ": " .. (p.hint or ""), color)
	Hud.flash(color, 0.2)
	Effects.chime(Effects.CHIME_ALARM, 0.7)
end

function handlers.GuardianWake(p)
	Effects.sound("boom", { position = p.position, speed = 0.35, volume = 1, range = 800 })
	Effects.shakeAt(p.position, 1.2, 1, 300)
	if p.reason == "heat" then
		Hud.banner("HEAT IS TOO HIGH: THE GUARDIAN AWAKENS!", DANGER, 3)
	end
end

function handlers.GuardianSmash(p)
	Effects.ring(p.position + Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 150, 110), 14, 0.5)
	Effects.sound("boom", { position = p.position, speed = 0.6, volume = 1 })
	Effects.shakeAt(p.position, 1.4, 0.4, 90)
end

function handlers.TotemCharge(p)
	Effects.sound("blip", { position = p.position, speed = 2, volume = 1, range = 200 })
end

function handlers.TotemFire(p)
	Effects.sound("whoosh", { position = p.position, speed = 1.6, volume = 0.9, range = 200 })
	Effects.ball(p.position, Color3.fromRGB(255, 140, 60), 4, 0.25)
end

function handlers.Blast(p)
	Effects.explosion(p.position, p.radius)
	Effects.shakeAt(p.position, 1, 0.35, 60)
end

function handlers.CaveIn(p)
	Effects.shakeAt(p.position, 1.5, 1.2, 160)
	Effects.sound("boom", { position = p.position, speed = 0.5, volume = 1 })
end

function handlers.GrappleFX(p)
	Effects.line(p.from, p.to, p.success and GOLD or Color3.fromRGB(255, 245, 140), 0.22, 0.25)
	if p.success then
		Effects.burst(p.to, GOLD, 15, 12)
	end
end

function handlers.SwordHit(p)
	for _, position in ipairs(p.hits or {}) do
		Effects.ball(position, Color3.new(1, 1, 1), 4, 0.2)
		Effects.sound("ouch", { position = position, volume = 0.7 })
	end
end

function handlers.Polter(p)
	if p.phase == "cast" then
		Effects.ring(p.from - Vector3.new(0, 2.5, 0), SPIRIT_COLOR, 7)
		Effects.sound("whoosh", { position = p.from, speed = 1.8, volume = 0.7 })
	elseif p.phase == "return" or p.phase == "shatter" then
		local color = p.phase == "shatter" and DANGER or SPIRIT_COLOR
		Effects.line(p.from, p.to, color, 0.6, 0.3)
		Effects.ring(p.to - Vector3.new(0, 2.5, 0), color, 9)
		Effects.sound("rise", { position = p.to, speed = 1.5, volume = 0.8 })
		if p.phase == "shatter" then
			Effects.burst(p.to, color, 30, 20)
		end
	elseif p.phase == "echo" then
		for _, position in ipairs(p.hits or {}) do
			soulSlash(position)
		end
	end
end

function handlers.RaidStart()
	Hud.hideResults()
	Hud.banner("RAID START! STEAL LOOT, BRING IT TO THE HOARD", GOLD, 4)
	Effects.chime(Effects.CHIME_GOOD, 0.9)
end

function handlers.RaidEnd(p)
	Hud.showResults(p.results or {}, p.winners or {})
	Hud.banner("RAID OVER!", GOLD, 3)
	Effects.chime({ 2, 1.5, 1.26, 1, 1.5, 2 }, 0.8)
end

function handlers.LastCall(p)
	Hud.banner(string.format("LAST CALL! %d SECONDS - BANK IT OR LOSE IT", p.seconds or 60), DANGER, 3.5)
	Effects.chime(Effects.CHIME_ALARM, 0.9)
end

eventRemote.OnClientEvent:Connect(function(kind, payload)
	local handler = handlers[kind]
	if handler then
		handler(payload or {})
	end
end)

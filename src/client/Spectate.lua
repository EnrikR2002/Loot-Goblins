-- Watching the raid from the Port (V13). The server decides who may be watched and streams the world round them
-- (server/Port.lua: the Spectating attribute and Player.ReplicationFocus); this module only moves the camera and draws
-- the spectator's bar:
--   ◀ NAME ▶   their gold, what they are doing, the raid's clock     JOIN RAID (while late entry is open)   BACK
-- Keys: LEFT / RIGHT (or Q / E, the D-pad, L1 / R1) change who you watch; BACKSPACE (or B on a controller) goes back
-- to the Port. While watching, your own goblin stands still in the Port (its controls are off); everything is put
-- back when you stop, when the raid ends, when you join it, or when you respawn.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Ui = require(script.Parent.Ui)

local Spectate = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local portRemote = remotes:WaitForChild("PortRequest")
local C = Ui.C

local gui, bar, nameLabel, infoLabel, clockLabel, joinButton
local watching = nil -- userId
local controlsOff = false
local toastFn = function(_text) end

local LOOT_NAMES = {}
for _, def in ipairs(Config.LOOT) do
	LOOT_NAMES[def.id] = def.name
end

local function now()
	return workspace:GetServerTimeNow()
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function controls()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	return ok and module or nil
end

local function setControls(on)
	if controlsOff == not on then
		return
	end
	controlsOff = not on
	local c = controls()
	if c then
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end
end

local function ask(action)
	portRemote:FireServer("spectate", action)
end

-- Building ---------------------------------------------------------------------------------------------------------
local function build()
	gui = Ui.make("ScreenGui", {
		Name = "LootGoblinsSpectate",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	local root = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local scaler = Ui.make("UIScale", {}, root)
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		scaler.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.65, 1.15)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	Ui.label(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 30),
		Text = "👁 WATCHING THE RAID",
		Font = Ui.TITLE,
		TextSize = 22,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	clockLabel = Ui.label(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 42),
		Size = UDim2.fromOffset(300, 24),
		Text = "",
		Font = Ui.BLACK,
		TextSize = 18,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(clockLabel, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	bar = Ui.make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(720, 74),
		BackgroundColor3 = C.wood,
	}, root)
	Ui.corner(bar, 18)
	Ui.stroke(bar, C.goldDeep, 3)
	Ui.button(bar, {
		text = "◀",
		style = "wood",
		size = UDim2.fromOffset(52, 52),
		position = UDim2.fromOffset(12, 11),
		textSize = 24,
		radius = 26,
		name = "Back",
	}, function()
		ask("back")
	end)
	nameLabel = Ui.label(bar, {
		Position = UDim2.fromOffset(74, 8),
		Size = UDim2.fromOffset(300, 32),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 26,
		TextColor3 = C.goldPale,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})
	infoLabel = Ui.label(bar, {
		Position = UDim2.fromOffset(74, 40),
		Size = UDim2.fromOffset(300, 24),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = C.parchment,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})
	Ui.button(bar, {
		text = "▶",
		style = "wood",
		size = UDim2.fromOffset(52, 52),
		position = UDim2.fromOffset(382, 11),
		textSize = 24,
		radius = 26,
		name = "Next",
	}, function()
		ask("next")
	end)
	joinButton = Ui.button(bar, {
		text = "⚔ JOIN",
		style = "gold",
		size = UDim2.fromOffset(124, 52),
		position = UDim2.fromOffset(448, 11),
		textSize = 20,
		name = "Join",
	}, function()
		portRemote:FireServer("join")
	end)
	Ui.button(bar, {
		text = "🏠 PORT",
		style = "parchment",
		size = UDim2.fromOffset(124, 52),
		position = UDim2.fromOffset(584, 11),
		textSize = 20,
		name = "Leave",
	}, function()
		ask("stop")
	end)
	local keys = Ui.label(root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -98),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "◀ ▶ (or Q / E) who to watch   ·   BACKSPACE back to the Port",
		Font = Ui.BOLD,
		TextSize = 13,
		TextColor3 = C.white,
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Center,
		Name = "Keys",
	})
	Ui.corner(keys, 11)
	Ui.pad(keys, 12, 0, 12, 0)
end

-- What the watched goblin is doing, in a few words.
local function doing(target)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local loot = target:GetAttribute("CarryingLoot")
	local bits = {}
	local stats = target:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Gold")
	table.insert(bits, string.format("💰 %d", gold and gold.Value or 0))
	if loot then
		table.insert(bits, "carrying the " .. (LOOT_NAMES[loot] or "treasure") .. "!")
	end
	if target:GetAttribute("Diving") then
		table.insert(bits, "flying")
	elseif humanoid and humanoid.SeatPart and humanoid.SeatPart.Parent:GetAttribute("BoatType") then
		local spec = Config.BOAT_TYPES[humanoid.SeatPart.Parent:GetAttribute("BoatType")]
		table.insert(bits, "sailing a " .. (spec and spec.name or "boat"))
	elseif target:GetAttribute("DeployState") == "aboard" or target:GetAttribute("DeployState") == "loaded" then
		table.insert(bits, "on the skyship")
	elseif not humanoid or humanoid.Health <= 0 then
		table.insert(bits, "knocked out")
	end
	return table.concat(bits, "  ·  ")
end

-- Keys while watching.
local function bindKeys(on)
	if on then
		ContextActionService:BindActionAtPriority(
			"LootGoblinsSpectate",
			function(_, state, input)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				local key = input.KeyCode
				if
					key == Enum.KeyCode.Left
					or key == Enum.KeyCode.Q
					or key == Enum.KeyCode.DPadLeft
					or key == Enum.KeyCode.ButtonL1
				then
					ask("back")
				elseif
					key == Enum.KeyCode.Right
					or key == Enum.KeyCode.E
					or key == Enum.KeyCode.DPadRight
					or key == Enum.KeyCode.ButtonR1
				then
					ask("next")
				elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
					ask("stop")
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 30,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.Q,
			Enum.KeyCode.E,
			Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonR1,
			Enum.KeyCode.Backspace,
			Enum.KeyCode.ButtonB
		)
		-- Your own goblin stands still while you watch: its movement keys are caught here too (turning the controls off
		-- alone let a goblin walk away in a Studio test).
		ContextActionService:BindActionAtPriority(
			"LootGoblinsSpectateFreeze",
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 30,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Space,
			Enum.KeyCode.Thumbstick1,
			Enum.KeyCode.ButtonA
		)
	else
		ContextActionService:UnbindAction("LootGoblinsSpectate")
		ContextActionService:UnbindAction("LootGoblinsSpectateFreeze")
	end
end

local function ownHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	local humanoid = ownHumanoid()
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.CameraType = Enum.CameraType.Custom
end

local function setWatching(userId)
	if userId == watching then
		return
	end
	local was = watching
	watching = userId
	if userId then
		gui.Enabled = true
		setControls(false)
		if not was then
			bindKeys(true)
		end
	else
		gui.Enabled = false
		setControls(true)
		bindKeys(false)
		restoreCamera()
	end
end

local function update()
	if not watching then
		return
	end
	local target = Players:GetPlayerByUserId(watching)
	local camera = workspace.CurrentCamera
	if target then
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- The camera follows them once their body has streamed in (the server asked for it round them).
		if humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
		nameLabel.Text = target.DisplayName
		infoLabel.Text = doing(target)
	else
		nameLabel.Text = "..."
		infoLabel.Text = ""
	end
	local phase = workspace:GetAttribute("RaidPhase")
	local t = now()
	local status = Lobby.status(phase, t, workspace:GetAttribute("PhaseEndsAt"), player:GetAttribute("InRaid") == true)
	local clockAt = workspace:GetAttribute("RaidClockAt")
	if phase == "raid" and clockAt and t < clockAt then
		clockLabel.Text = string.format("🚀 LAUNCHING  %d", math.ceil(clockAt - t))
	else
		clockLabel.Text = "⏱ " .. clock(status.seconds or 0)
	end
	joinButton.Visible = status.canJoin == true
end

local WHY = {
	ended = "The raid is over: everyone's coming home!",
	empty = "Nobody left out there to watch.",
	noraid = "No raid is running right now.",
}

-- The server stopped this goblin watching (Port.lua sends why).
function Spectate.ended(p)
	if WHY[p.why] then
		toastFn(WHY[p.why])
	end
	setWatching(nil)
end

-- The goblin being watched is gone: the server moved us to someone else.
function Spectate.switched(_p)
	toastFn("They're out of the raid: watching someone else.")
end

function Spectate.isWatching()
	return watching ~= nil
end

function Spectate.start(toast)
	toastFn = toast or toastFn
	build()
	player:GetAttributeChangedSignal("Spectating"):Connect(function()
		local id = player:GetAttribute("Spectating")
		setWatching(type(id) == "number" and id or nil)
	end)
	-- A respawn while watching: Roblox points the camera at the new body; point it back at the raid.
	player.CharacterAdded:Connect(function()
		if watching then
			task.defer(function()
				controlsOff = false
				setControls(false)
			end)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return Spectate

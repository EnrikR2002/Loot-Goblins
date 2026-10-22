-- Loot Goblins client: input, the bits of movement the client owns (the
-- Poltergoblin dash, ziplines, launch pads, the grapple pull), and turning
-- server events into HUD messages and effects. The server decides everything
-- that matters, including the base run speed and stamina (V13.2: the momentum on top is this client's).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Momentum = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Momentum"))
local Swing = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Swing"))
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local Weather = require(script.Parent.Weather)
local BoatDrive = require(script.Parent.BoatDrive)
local Skyship = require(script.Parent.Skyship)
local Shop = require(script.Parent.Shop)
local Looks = require(script.Parent.Looks)
local Pets = require(script.Parent.Pets)
local Emotes = require(script.Parent.Emotes)
local Results = require(script.Parent.Results)
local Tricks = require(script.Parent.Tricks)
local Twisters = require(script.Parent.Twisters)
local Minimap = require(script.Parent.Minimap)
local Danger = require(script.Parent.Danger)
local TouchControls = require(script.Parent.TouchControls)
local PortHud = require(script.Parent.PortHud)
local Spectate = require(script.Parent.Spectate)
local PortLife = require(script.Parent.PortLife)
local ChaosFx = require(script.Parent.ChaosFx) -- V13.2: the world chaos events, drawn
-- V13.3, the Living Port: the Port's games, the Quest Board and the Hall of Records, the sanctuaries, the card after a
-- raid, challenges, and titles over goblins' heads.
local PlayHud = require(script.Parent.PlayHud)
local PortBoard = require(script.Parent.PortBoard)
local SanctuaryView = require(script.Parent.Sanctuary)
local NextUp = require(script.Parent.NextUp)
local Challenge = require(script.Parent.Challenge)
local Titles = require(script.Parent.Titles)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local throwRemote = remotes:WaitForChild("ThrowRequest")
local grappleRemote = remotes:WaitForChild("GrappleRequest")
local polterRemote = remotes:WaitForChild("PoltergoblinRequest")
local moveRemote = remotes:WaitForChild("MoveRequest")
local boatBoardRemote = remotes:WaitForChild("BoatBoardRequest")
local cannonRemote = remotes:WaitForChild("CannonRequest")
local kegRemote = remotes:WaitForChild("KegRequest")
local recallRemote = remotes:WaitForChild("BoatRecallRequest")
local stealRemote = remotes:WaitForChild("StealRequest")
local eventRemote = remotes:WaitForChild("GameEvent")
local resetRemote = remotes:WaitForChild("ResetRequest")

local generated = workspace:WaitForChild("LootGoblinsGenerated")
local hoardPart = generated:WaitForChild("Landmarks"):WaitForChild("HoardMarker"):WaitForChild("Hoard")

local SPIRIT_COLOR = Color3.fromRGB(120, 255, 170)
local MARK_COLOR = Color3.fromRGB(190, 90, 255)
local GOLD = Color3.fromRGB(255, 205, 50)
local DANGER = Color3.fromRGB(255, 80, 60)
local ROPE_COLOR = Color3.fromRGB(230, 200, 140)

local LOOT_COLORS = {}
local LOOT_WEIGHT = {}
for _, def in ipairs(Config.LOOT) do
	LOOT_COLORS[def.id] = def.color
	LOOT_WEIGHT[def.id] = def.weight or 1
end

Hud.init(hoardPart)
Danger.start() -- V12: whatever is chasing you, at the edge of the screen
Twisters.init()
Minimap.build(hoardPart.Position)

-- Storm warnings: name the heading so the player can steer around it. V12: not from its very edge (V11 said
-- "1 STUDS. SAIL AROUND IT!" to a goblin standing on an island the storm was already over), and only a sailor
-- is told to sail round it. News, not an alarm: it never replaces a bigger banner.
local COMPASS_NAMES = { "NORTH", "NORTH-EAST", "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST" }
Weather.init(function(dx, dz, distance)
	if distance < 80 then
		return
	end
	local degrees = math.deg(math.atan2(dx, -dz)) % 360
	local name = COMPASS_NAMES[math.floor((degrees + 22.5) / 45) % 8 + 1]
	local sailing = Hud.mode() == "boat"
	Hud.banner(
		string.format("STORM %d STUDS TO THE %s%s", distance, name, sailing and ": SAIL AROUND IT!" or ""),
		Color3.fromRGB(170, 190, 255),
		3.5,
		1
	)
end)
-- V12: the controls card (H) no longer opens by itself at every join: it covered the first fourteen seconds of
-- the launch window. The objective line and the skyship's banner teach the first raid as it happens.

local function now()
	return workspace:GetServerTimeNow()
end

-- (V13.1: a goblin who is knocked out counts as down: their keys do nothing until they get up.)
local function getCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or player:GetAttribute("KnockedOutUntil") then
		return nil
	end
	return character, humanoid, root
end

-- V13.1: health 0 is a KNOCKOUT, not a death (server/Knockout.lua). This client owns its humanoid's states, so it
-- switches the Dead state off too (or Roblox would kill the body here and respawn it at home).
local function noDying(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
end
player.CharacterAdded:Connect(noDying)
if player.Character then
	task.spawn(noDying, player.Character)
end
-- The Reset button still gets a stuck goblin out (a real respawn, the server's choice: Knockout.respawn).
do
	local resetEvent = Instance.new("BindableEvent")
	resetEvent.Event:Connect(function()
		resetRemote:FireServer()
	end)
	task.spawn(function()
		for _ = 1, 30 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", resetEvent) then
				return
			end
			task.wait(0.5)
		end
	end)
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

-- Roblox only SHOWS a prompt whose object is on screen. So a goblin standing beside the treasure with the
-- camera turned away saw no prompt, and E (shared with Poltergoblin) sent their spirit flying instead of
-- stealing: "I pressed E and it did the wrong thing". V8: if no prompt is showing, E goes to the nearest
-- enabled E-prompt the goblin is in reach of, held and released exactly as if it were on screen.
local heldPrompt = nil
-- V12: the world's prompts, kept as they stream in and out, so an E press does not walk every instance in the
-- generated world (about 57,000) to find the one in reach.
local worldPrompts = {}
local function trackPrompt(instance)
	if instance:IsA("ProximityPrompt") then
		worldPrompts[instance] = true
	end
end
for _, instance in ipairs(generated:GetDescendants()) do
	trackPrompt(instance)
end
generated.DescendantAdded:Connect(trackPrompt)
generated.DescendantRemoving:Connect(function(instance)
	worldPrompts[instance] = nil
end)

local function reachPrompt()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	local function consider(prompt)
		if not prompt.Enabled or prompt.KeyboardKeyCode ~= Enum.KeyCode.E then
			return
		end
		local parent = prompt.Parent
		local position
		if parent and parent:IsA("BasePart") then
			position = parent.Position
		elseif parent and parent:IsA("Attachment") then
			position = parent.WorldPosition
		end
		if position then
			local distance = (position - root.Position).Magnitude
			if distance <= prompt.MaxActivationDistance and distance < bestDistance then
				best, bestDistance = prompt, distance
			end
		end
	end
	for prompt in pairs(worldPrompts) do
		consider(prompt)
	end
	-- The steal prompt on a goblin who is down lives on their body, not in the world folder.
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local prompt = otherRoot and otherRoot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			consider(prompt)
		end
	end
	return best
end

-- V12: the nearest enabled E-prompt the goblin is ALMOST in reach of (within its range plus `slack` studs).
-- Pressing E a step short of a boat or a cannon used to cast Poltergoblin (the spirit dash): a surprise for a
-- new goblin, who then had to find E again to snap back. Now that press says "closer" instead.
local function almostPrompt(slack)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for instance in pairs(worldPrompts) do
		if instance.Enabled and instance.KeyboardKeyCode == Enum.KeyCode.E then
			local parent = instance.Parent
			local position = parent and parent:IsA("BasePart") and parent.Position
				or (parent and parent:IsA("Attachment") and parent.WorldPosition)
			if position and (position - root.Position).Magnitude <= instance.MaxActivationDistance + slack then
				return instance
			end
		end
	end
	return nil
end

local function promptOwnsE()
	for prompt in pairs(shownPrompts) do
		if prompt.Parent and prompt.Enabled and prompt.KeyboardKeyCode == Enum.KeyCode.E then
			return true
		end
	end
	return false
end

-- V13.1: the boat you are sitting in does not offer you "Board" (its prompt used to take E, so E could not get
-- you out). A local change only: everyone else still sees it.
do
	local hiddenBoard
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local hull = seat and seat.Parent and seat.Parent:FindFirstChild("Hull")
		local prompt = hull and hull:FindFirstChild("BoardPrompt")
		if prompt ~= hiddenBoard then
			if hiddenBoard and hiddenBoard.Parent then
				hiddenBoard.Enabled = true
			end
			hiddenBoard = prompt
			if prompt then
				prompt.Enabled = false
			end
		end
	end)
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
local flight = nil -- A catapult throw in progress (see the loop after `airborne`).
local function hookPad(pad)
	if not pad:IsA("BasePart") or pad.Name == "GeyserVent" then
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
		local carry = pad:GetAttribute("Carry")
		if typeof(carry) == "number" then
			-- A catapult: the throw keeps its sideways speed for this long.
			flight = {
				velocity = Vector3.new(launch.X, 0, launch.Z),
				startedAt = os.clock(),
				untilAt = os.clock() + carry,
			}
		end
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

-- Geysers: a steam vent that fires on a timer anyone can read. Quiet puffs warn a second ahead; then
-- a jet launches whoever stands on it. The server does nothing per frame (the numbers are attributes).
local geyserEmitters = {}
RunService.Heartbeat:Connect(function()
	local t = now()
	local _, _, root = getCharacter()
	for _, vent in ipairs(pads:GetChildren()) do
		if vent.Name == "GeyserVent" then
			local period = vent:GetAttribute("GeyserPeriod") or 8
			local activeTime = vent:GetAttribute("GeyserActive") or 1.8
			local phase = vent:GetAttribute("GeyserPhase") or 0
			local cycle = (t + phase) % period
			local emitter = geyserEmitters[vent]
			if not emitter then
				emitter = Instance.new("ParticleEmitter")
				emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
				emitter.Color = ColorSequence.new(Color3.fromRGB(235, 240, 245))
				emitter.Size =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 12) })
				emitter.Transparency =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				emitter.Lifetime = NumberRange.new(0.9, 1.5)
				emitter.Speed = NumberRange.new(40, 70)
				emitter.EmissionDirection = Enum.NormalId.Top
				emitter.SpreadAngle = Vector2.new(6, 6)
				emitter.Rate = 0
				emitter.Parent = vent
				geyserEmitters[vent] = emitter
			end
			local active = cycle < activeTime
			emitter.Rate = active and 70 or (cycle > period - 1 and 10 or 0)
			if active and root then
				local launch = vent:GetAttribute("Launch")
				local offset = root.Position - vent.Position
				if
					typeof(launch) == "Vector3"
					and Vector3.new(offset.X, 0, offset.Z).Magnitude < 5.5
					and offset.Y > -3
					and offset.Y < 9
					and os.clock() - lastLaunch > 0.8
				then
					lastLaunch = os.clock()
					root.AssemblyLinearVelocity =
						Vector3.new(root.AssemblyLinearVelocity.X * 0.5, launch.Y, root.AssemblyLinearVelocity.Z * 0.5)
					Effects.sound("whoosh", { speed = 0.6, volume = 0.9 })
					Effects.burst(vent.Position, Color3.fromRGB(240, 245, 255), 35, 26)
					Effects.punchFov(84)
				end
			end
		end
	end
end)

-- Grapple ---------------------------------------------------------------------------------
-- F sends where you aim. The pull runs here, because each client moves its own character (like ziplines and launch
-- pads). V13.2: THE GRAPPLE IS HOW A GOBLIN GETS ABOUT ON FOOT. On anything that does not move (a rock, the ground, a
-- wall, a mast) it starts here the moment F is pressed: hooked above you, you SWING (shared/Swing.lua: W A S D pump the
-- swing, hold F to reel in, F again or Space lets go with every bit of the speed); hooked level or below, it reels you
-- to it. The server is told (it checks the reach, sets the cooldown and shows everyone else the rope). Loot, a carrier
-- and a moving boat still go the old way, through the server's choice (GrappleFX), because they are contested.
local pull = nil
local grappleHeld = false
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = false

local function aimRay()
	local camera = workspace.CurrentCamera
	local mouseAt = UserInputService:GetMouseLocation()
	-- V12: with a controller (or a finger) there is no mouse to aim with: aim where the camera looks.
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Gamepad1 or last == Enum.UserInputType.Touch then
		mouseAt = camera.ViewportSize / 2
	end
	return camera:ViewportPointToRay(mouseAt.X, mouseAt.Y)
end

local hookFolder = Instance.new("Folder")
hookFolder.Name = "LootGoblinsHookPreview"
hookFolder.Parent = workspace

local function aimFilter()
	-- Never aim at yourself or at the boat you are sitting in (or at the hook preview).
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	aimParams.FilterDescendantsInstances = { player.Character, seat and seat.Parent, hookFolder }
end

local function aimPoint()
	local ray = aimRay()
	aimFilter()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, aimParams)
	if hit then
		return hit.Position, hit.Instance, hit.Normal
	end
	return ray.Origin + ray.Direction * 1000, nil, nil
end

-- V13.2: is this something the hook may swing from on its own (it does not move, and it is not loot or a goblin)?
local generatedLoot = generated:FindFirstChild("Loot")
local function staticHook(instance, position)
	if not instance or position.Y < -1 then
		return false
	end
	if instance == workspace.Terrain then
		return true
	end
	if not instance:IsA("BasePart") or not instance.Anchored then
		return false
	end
	if generatedLoot and instance:IsDescendantOf(generatedLoot) then
		return false
	end
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and (model:GetAttribute("BoatType") or Players:GetPlayerFromCharacter(model)) then
		return false
	end
	return true
end

-- Is something the server must judge (loose loot, a carrier, a moving boat) close to this aim line?
local function contested(origin, direction)
	local function near(point, range, assist)
		local offset = point - origin
		local along = offset:Dot(direction)
		return along > 0 and offset.Magnitude <= range and (offset - direction * along).Magnitude <= assist
	end
	if generatedLoot and not player:GetAttribute("CarryingLoot") then
		for _, model in ipairs(generatedLoot:GetChildren()) do
			local core = model:IsA("Model") and model.PrimaryPart
			local state = generatedLoot:GetAttribute(model.Name .. "State")
			if core and state == "loose" and near(core.Position, Config.GRAPPLE_RANGE, Config.GRAPPLE_AIM_ASSIST) then
				return true
			end
		end
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other ~= player
				and other:GetAttribute("CarryingLoot")
				and other.Character
				and other.Character:FindFirstChild("HumanoidRootPart")
			if root and near(root.Position, Config.GRAPPLE_PVP_RANGE, Config.GRAPPLE_AIM_ASSIST) then
				return true
			end
		end
	end
	local structures = generated:FindFirstChild("Structures")
	if structures then
		for _, model in ipairs(structures:GetChildren()) do
			local hull = model:GetAttribute("BoatType") and model:FindFirstChild("Hull")
			if
				hull
				and hull.AssemblyLinearVelocity.Magnitude > 12
				and near(hull.Position, Config.GRAPPLE_PULL_RANGE, Config.GRAPPLE_BOAT_ASSIST)
			then
				return true
			end
		end
	end
	return false
end

-- V13.2: a forgiving hook. The aim itself, then a cone of rays round it (Config.SWING.ASSIST): the nearest thing it
-- can swing from or reel to, within reach. Returns position, normal, instance, or nil.
local ASSIST_RINGS = { { 0.5, 6 }, { 1, 10 } }
local function findHook(origin, ray)
	local range = Config.SWING.RANGE
	aimFilter()
	local camera = workspace.CurrentCamera
	local function try(direction)
		local hit = workspace:Raycast(ray.Origin, direction * 1000, aimParams)
		if hit and (hit.Position - origin).Magnitude <= range and staticHook(hit.Instance, hit.Position) then
			return hit
		end
		return nil
	end
	local best = try(ray.Direction)
	if best then
		return best.Position, best.Normal, best.Instance
	end
	local right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
	local bestScore = math.huge
	for _, ring in ipairs(ASSIST_RINGS) do
		local angle = Config.SWING.ASSIST * ring[1]
		for i = 1, ring[2] do
			local a = (i / ring[2]) * math.pi * 2
			local direction = (ray.Direction + (right * math.cos(a) + up * math.sin(a)) * math.tan(angle)).Unit
			local hit = try(direction)
			if hit then
				-- Prefer what is above (a swing) and nearer the middle of the aim.
				local score = ring[1] * 10 - math.clamp(hit.Position.Y - origin.Y, -20, 40) * 0.1
				if score < bestScore then
					best, bestScore = hit, score
				end
			end
		end
		if best then
			return best.Position, best.Normal, best.Instance
		end
	end
	return nil
end

local momentum = Momentum.new() -- V13.2: running builds speed (shared/Momentum.lua)
local swingTips = 0 -- the first few swings say how they work
local function baseSpeed()
	return player:GetAttribute("MoveCap") or Config.WALK_SPEED
end

local airJumpUsed = false -- One air jump per flight; a pull hands it back (see the moves below).

local function stopPull(pop)
	if not pull then
		return
	end
	local current = pull
	pull = nil
	current.holder:Destroy()
	current.rope:Destroy()
	if current.predicted then
		grappleRemote:FireServer(nil, nil, "release")
	end
	local _, _, root = getCharacter()
	if not root or not pop then
		if root and current.swing then
			-- Let go without a pop (snagged, jumped): keep the speed the rope had.
			local v = current.velocity or root.AssemblyLinearVelocity
			local flatV = Vector3.new(v.X, 0, v.Z)
			Momentum.carry(momentum, flatV.Magnitude, flatV, baseSpeed())
		end
		return
	end
	local v = root.AssemblyLinearVelocity
	if current.part and current.part.Parent and current.boat then
		-- Hooked something that moves: let go at its speed, not ours, so it does not sail out
		-- from under us.
		local carry = current.part.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(carry.X, 8, carry.Z)
		return
	end
	if current.swing and current.swing.mode == "swing" then
		-- Let go of a swing: every bit of the speed, and a little lift off the top of an arc.
		v = Swing.release(current.velocity or v)
		root.AssemblyLinearVelocity = v
	else
		-- The end of a pull: a hop, so a hook on a ledge lifts you over its lip. You keep most of the
		-- swing, so a pull flows straight into a run, a jump or a dash.
		local keep = Config.GRAPPLE_KEEP_SPEED
		v = Vector3.new(v.X * keep, Config.GRAPPLE_POP_SPEED, v.Z * keep)
		root.AssemblyLinearVelocity = v
	end
	local flatV = Vector3.new(v.X, 0, v.Z)
	Momentum.carry(momentum, flatV.Magnitude, flatV, baseSpeed())
end

-- Where the hook is right now. A hook on a boat rides the boat.
local function pullGoal(current)
	if not current.part then
		return current.goal
	end
	if not current.part.Parent then
		return nil
	end
	return current.part.CFrame:PointToWorldSpace(current.offset) + Vector3.new(0, 4, 0)
end

-- to, normal: the hook point. part, offset: set when the hook is on something that moves. predicted (V13.2): this
-- client found the hook itself (a swing or a pull on something still) and has told the server.
local function startPull(to, normal, part, offset, tries, predicted)
	local _, humanoid, root = getCharacter()
	if not root then
		return
	end
	if humanoid.SeatPart then
		-- Hooked from a boat seat: the server lets go of the seat; wait for that to arrive.
		humanoid.Sit = false
		if (tries or 0) < 8 then
			task.delay(0.05, startPull, to, normal, part, offset, (tries or 0) + 1, predicted)
		end
		return
	end
	stopRide(false)
	stopPull(false)
	-- Aim a little off the surface: a floor lands you on it, a wall leaves you at it.
	local current = { part = part, offset = offset, goal = to + normal * 2 + Vector3.new(0, 2.5, 0), hook = to }
	-- A hook anywhere on a boat reels you to the middle of its deck, and you take a seat.
	local boatModel = part and part:FindFirstAncestorOfClass("Model")
	local hull = boatModel and boatModel:GetAttribute("BoatType") and boatModel:FindFirstChild("Hull")
	if hull then
		current.part, current.offset, current.boat = hull, Vector3.new(0, hull.Size.Y / 2 - 1, 0), true
	end
	local goal = pullGoal(current)
	if not goal then
		return
	end
	local distance = (goal - root.Position).Magnitude
	if distance < 3 then
		return -- Already there (and .Unit of a zero vector is NaN).
	end
	local holder = Instance.new("Attachment")
	holder.Name = "GrapplePull"
	holder.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = holder
	push.MaxForce = 1e6
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VectorVelocity = (goal - root.Position).Unit * Config.GRAPPLE_PULL_SPEED
	push.Parent = holder
	local t = os.clock()
	current.root = root
	current.holder = holder
	current.push = push
	current.rope = Effects.rope(root, to, ROPE_COLOR, current.boat and 5 or Config.SWING.MAX_TIME + 1, part, offset)
	current.startedAt = t
	current.endsAt = t + distance / Config.GRAPPLE_PULL_SPEED + 0.6
	current.best = distance
	current.bestAt = t
	current.predicted = predicted
	if not current.boat then
		-- V13.2: a swing (the hook is above) or a pull (level or below), played by shared/Swing.lua.
		current.swing = Swing.start(to, root.Position, root.AssemblyLinearVelocity)
		current.velocity = root.AssemblyLinearVelocity
		push.VectorVelocity = current.velocity
		if current.swing.mode == "swing" and swingTips < 3 then
			swingTips += 1
			Hud.toast("SWINGING: W A S D pump the swing, hold F to reel in, F or Space lets go (keeping the speed)")
		end
	end
	pull = current
	airJumpUsed = false
	Effects.sound("whoosh", { speed = 1.5, volume = 0.6 })
	Effects.punchFov(84)
end

RunService.Heartbeat:Connect(function(dt)
	if not pull then
		return
	end
	local _, humanoid, root = getCharacter()
	local goal = pullGoal(pull)
	if root ~= pull.root or humanoid.SeatPart or not goal then
		stopPull(false)
		return
	end
	local offset = goal - root.Position
	local distance = offset.Magnitude
	local t = os.clock()
	local carry = pull.part and pull.part.AssemblyLinearVelocity or Vector3.zero
	if pull.holdUntil then
		-- Over a boat's deck: ride along with it until the server seats us (the top of this
		-- function ends the pull the moment it does), or let go onto the deck if it is full.
		if t > pull.holdUntil then
			stopPull(true)
		else
			pull.push.VectorVelocity = offset * 8 + carry
		end
		return
	end
	if pull.boat then
		if distance < 3 or t > pull.endsAt then
			if distance < 12 then
				pull.holdUntil = t + 0.7
				boatBoardRemote:FireServer()
			else
				stopPull(true)
			end
			return
		end
		if distance < pull.best - 0.5 then
			pull.best, pull.bestAt = distance, t
		elseif t - pull.bestAt > 0.3 then
			-- Snagged on something on the way.
			stopPull(true)
			return
		end
		-- Ease in over the last few studs instead of slamming into the wall. A moving hook adds
		-- its own speed, so you close on a fleeing boat as fast as on a cliff.
		pull.push.VectorVelocity = offset.Unit * math.min(Config.GRAPPLE_PULL_SPEED, 30 + distance * 6) + carry
		return
	end
	-- V13.2: the rope. Start each step from what the body really did (a wall stops a swing), unless it only differs
	-- by a little (then from the rope's own motion, so the arc stays smooth).
	local hook = pull.part and pull.part.Parent and pull.part.CFrame:PointToWorldSpace(pull.offset) or pull.hook
	local actual = root.AssemblyLinearVelocity
	local from = pull.velocity or actual
	if (actual - from).Magnitude > 30 then
		from = actual
	end
	local reel = grappleHeld and t - pull.startedAt > 0.18
	local move = humanoid.MoveDirection
	local v, done = Swing.step(pull.swing, root.Position, from, hook, carry, { move = move, reel = reel }, dt)
	if done then
		stopPull(done == "arrived" or done == "time")
		return
	end
	if pull.swing.mode == "swing" and humanoid.FloorMaterial ~= Enum.Material.Air and not reel then
		-- Standing on the ground with a slack rope: it lets go and you run.
		pull.groundFor = (pull.groundFor or 0) + dt
		if pull.groundFor > Config.SWING.GROUND_LET_GO then
			stopPull(false)
			return
		end
	else
		pull.groundFor = 0
	end
	pull.velocity = v
	pull.push.VectorVelocity = v
	if pull.swing.mode == "swing" and v.Magnitude > 4 then
		-- Face the way the swing goes.
		local flatV = Vector3.new(v.X, 0, v.Z)
		if flatV.Magnitude > 4 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flatV)
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	-- Jump lets go of the rope mid-pull and keeps your swing (V13.2: with the little lift off the top of an arc).
	if pull and os.clock() - pull.startedAt > 0.15 then
		stopPull(not pull.boat)
	end
end)

local function pressGrapple()
	local _, _, root = getCharacter()
	if not root then
		return
	end
	-- V13.2: F again while on a rope lets go.
	if pull and not pull.boat then
		if os.clock() - pull.startedAt > 0.15 then
			stopPull(true)
		end
		return
	end
	if now() < (player:GetAttribute("GrappleReadyAt") or 0) then
		Hud.toast("Grapple is recharging")
		return
	end
	local ray = aimRay()
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	-- Loot, a carrier or a moving boat near the aim: the server chooses (and answers with GrappleFX).
	local hitPosition, target = aimPoint()
	local contestedAim = contested(origin, (hitPosition - origin).Unit)
	if not contestedAim then
		local hook, normal, instance = findHook(origin, ray)
		if hook then
			startPull(hook, normal or Vector3.yAxis, nil, nil, 0, true)
			grappleRemote:FireServer(hook, instance, "swing")
			Effects.ball(hook, ROPE_COLOR, 2.5, 0.3)
			Effects.sound("thud", { position = hook, speed = 1.7, volume = 0.6 })
			return
		end
	end
	grappleRemote:FireServer(hitPosition, target)
	Effects.sound("whoosh", { speed = 2.2, volume = 0.35 })
end

-- V13.2: where the hook would go, shown as a small ring while on foot (green: it will hold; nothing: out of reach).
do
	local dot = Instance.new("Part")
	dot.Name = "HookPreview"
	dot.Shape = Enum.PartType.Cylinder
	dot.Size = Vector3.new(0.2, 3, 3)
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false
	dot.CanTouch = false
	dot.CastShadow = false
	dot.Material = Enum.Material.Neon
	dot.Color = Color3.fromRGB(140, 255, 170)
	dot.Transparency = 0.35
	local nextLook = 0
	RunService.RenderStepped:Connect(function()
		local clock = os.clock()
		if clock < nextLook then
			return
		end
		nextLook = clock + 0.07
		local _, humanoid, root = getCharacter()
		if
			not root
			or humanoid.SeatPart
			or pull
			or player:GetAttribute("Diving")
			or player:GetAttribute("Zone") == "port"
		then
			dot.Parent = nil
			return
		end
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local hook, normal = findHook(origin, aimRay())
		if not hook then
			dot.Parent = nil
			return
		end
		dot.CFrame = CFrame.lookAt(hook + (normal or Vector3.yAxis) * 0.3, hook + (normal or Vector3.yAxis) * 2)
			* CFrame.Angles(0, math.rad(90), 0)
		dot.Color = hook.Y > root.Position.Y + Config.SWING.ABOVE and Color3.fromRGB(140, 255, 170)
			or Color3.fromRGB(255, 230, 140)
		dot.Parent = hookFolder
	end)
end

-- Cannons: E at a cannon's prompt fires it where you aim; the server checks everything.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "CannonPrompt" then
		local hitPosition = aimPoint()
		cannonRemote:FireServer(prompt.Parent, hitPosition)
	end
end)

-- Cannon aiming aid (V7): while a cannon's prompt is showing, a ring marks where the shot will go (green when
-- it can fire, red while it reloads) and the cannon says READY or how long is left. Every cannon in the
-- game works this way (the skyship's deployment cannons have their own aim view: client/Skyship.lua).
do
	local ring, tag
	local function ensure()
		if not ring then
			ring = Instance.new("Part")
			ring.Name = "CannonAimRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.4, 14, 14)
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.45
		end
		if not tag then
			tag = Instance.new("BillboardGui")
			tag.Name = "CannonStatus"
			tag.Size = UDim2.fromOffset(150, 30)
			tag.StudsOffset = Vector3.new(0, 5, 0)
			tag.AlwaysOnTop = true
			tag.MaxDistance = 60
			local label = Instance.new("TextLabel")
			label.Name = "Text"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextSize = 18
			label.TextStrokeTransparency = 0.3
			label.Parent = tag
		end
	end
	RunService.RenderStepped:Connect(function()
		local active
		for prompt in pairs(shownPrompts) do
			if prompt.Name == "CannonPrompt" and prompt.Parent then
				active = prompt
				break
			end
		end
		if not active then
			if ring then
				ring.Parent = nil
				tag.Parent = nil
			end
			return
		end
		ensure()
		local base = active.Parent
		local readyAt = base:GetAttribute("ReadyAt") or 0
		local left = readyAt - now()
		local ready = left <= 0
		local hit = aimPoint()
		ring.Color = ready and Color3.fromRGB(110, 255, 150) or Color3.fromRGB(255, 90, 80)
		ring.CFrame = CFrame.new(hit + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		tag.Adornee = base
		tag.Parent = base
		local text = tag:FindFirstChild("Text")
		text.Text = ready and "READY" or string.format("RELOADING %.1f", left)
		text.TextColor3 = ready and Color3.fromRGB(110, 255, 150) or Color3.fromRGB(255, 120, 100)
	end)
end

-- G throws a powder keg where you aim.
local function pressKeg()
	local _, _, root = getCharacter()
	if not root then
		return
	end
	if (player:GetAttribute("Kegs") or 0) <= 0 then
		Hud.toast("No kegs. Find a keg crate (hold E).")
		return
	end
	kegRemote:FireServer((aimPoint()))
end

-- In a boat's driver seat, Shift boosts the boat (on foot it dashes: V13.2).
local function seatedInBoat()
	local _, humanoid = getCharacter()
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsA("VehicleSeat")
end

-- Momentum (V13.2) ----------------------------------------------------------------------
-- No sprint key: running builds speed by itself (shared/Momentum.lua). The server owns the base speed (MoveCap:
-- carrying, water, a spirit's bonus); this client multiplies it on its own WalkSpeed, every frame.
UserInputService.WindowFocusReleased:Connect(function()
	grappleHeld = false
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E and heldPrompt then
		if heldPrompt.Parent then
			heldPrompt:InputHoldEnd()
		end
		heldPrompt = nil
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		BoatDrive.setDrift(false)
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL2 then
		grappleHeld = false -- V13.2: the reel stops
	end
end)
player.CharacterAdded:Connect(function()
	momentum = Momentum.new()
end)
RunService.Heartbeat:Connect(function(dt)
	local _, humanoid = getCharacter()
	if not humanoid then
		return
	end
	if humanoid.SeatPart or humanoid.PlatformStand or player:GetAttribute("Diving") then
		momentum.m = 0
		return
	end
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	local move = humanoid.MoveDirection
	local flatMove = Vector3.new(move.X, 0, move.Z)
	Momentum.step(momentum, {
		moving = flatMove.Magnitude > 0.1,
		direction = flatMove,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		swimming = swimming,
	}, dt)
	local speed = Momentum.speed(momentum, baseSpeed())
	if math.abs(humanoid.WalkSpeed - speed) > 0.05 then
		humanoid.WalkSpeed = speed
	end
end)
-- For the HUD and the playtest hook: how built-up the run is (0..1) and the speed carried from a swing.
function Hud.momentum()
	return momentum.m, momentum.carried
end

-- Dash and air jump --------------------------------------------------------------------
-- Both are played here at once, on your own character, so the key feels instant. The server
-- takes the stamina and keeps the cooldown (Movement.request).
local lastDash = -math.huge
local lastGroundedAt = os.clock()

-- What a move costs right now: loot makes every stamina cost bigger, by its weight.
local function staminaCost(base)
	local held = player:GetAttribute("CarryingLoot")
	return base * (1 + (held and LOOT_WEIGHT[held] or 0) * Config.CARRY_STAMINA_PER_WEIGHT)
end

local function hasStamina(cost)
	return (player:GetAttribute("Stamina") or Config.STAMINA_MAX) >= cost
end

local function airborne(humanoid)
	return humanoid.FloorMaterial == Enum.Material.Air and humanoid:GetState() ~= Enum.HumanoidStateType.Swimming
end

-- A catapult throw. A goblin's own air control would stop the flight short, so the sideways
-- speed is held until the throw has run its time or they touch down. Dash, air jump, a grapple
-- or a zipline ends it early, so the flight can still be steered out of.
RunService.Heartbeat:Connect(function()
	if not flight then
		return
	end
	local _, humanoid, root = getCharacter()
	local t = os.clock()
	if
		not root
		or ride
		or pull
		or humanoid.SeatPart
		or t >= flight.untilAt
		or (t - flight.startedAt > 0.35 and not airborne(humanoid))
	then
		flight = nil
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(flight.velocity.X, v.Y, flight.velocity.Z)
end)

local function pressDash()
	local _, humanoid, root = getCharacter()
	if not root or humanoid.SeatPart or ride or pull then
		return
	end
	local t = os.clock()
	if t - lastDash < Config.DASH_COOLDOWN then
		return
	end
	if not hasStamina(staminaCost(Config.DASH_COST)) then
		Hud.toast("Not enough stamina to dash")
		return
	end
	-- Dash where you are steering, or where you face when standing still.
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit
	lastDash = t
	flight = nil
	moveRemote:FireServer("dash")

	local inAir = airborne(humanoid)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Dash"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	-- In the air the dash also cancels your fall, so it reaches across gaps.
	push.MaxAxesForce = Vector3.new(1e6, inAir and 1e6 or 0, 1e6)
	push.VectorVelocity = direction * Config.DASH_SPEED + Vector3.new(0, inAir and Config.DASH_AIR_LIFT or 0, 0)
	push.Parent = attachment
	task.delay(Config.DASH_TIME, function()
		attachment:Destroy()
		if root.Parent then
			-- Leave the dash at the top of the run (V13.2: at full momentum), so it flows into the next move.
			local top = baseSpeed() * Config.MOMENTUM.TOP
			Momentum.carry(momentum, top, direction, baseSpeed())
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = direction * top + Vector3.new(0, v.Y, 0)
		end
	end)
	Effects.dash(root.Position, direction)
	Effects.punchFov(82)
end

local function tryAirJump(minAirTime)
	local _, humanoid, root = getCharacter()
	if not root or airJumpUsed or humanoid.SeatPart or ride or pull then
		return
	end
	if not airborne(humanoid) or os.clock() - lastGroundedAt < (minAirTime or 0.1) then
		return
	end
	if not hasStamina(staminaCost(Config.AIR_JUMP_COST)) then
		return
	end
	airJumpUsed = true
	flight = nil
	moveRemote:FireServer("airjump")
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local function lift()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, Config.AIR_JUMP_POWER, v.Z)
		end
	end
	lift()
	task.defer(lift) -- The state change applies its own jump a moment later; ours wins.
	Effects.airJump(root.Position)
end

RunService.Heartbeat:Connect(function()
	local _, humanoid = getCharacter()
	if humanoid and not airborne(humanoid) then
		lastGroundedAt = os.clock()
		airJumpUsed = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	-- Touch has no key-down to catch, so a second tap of the jump button counts once you have
	-- been in the air for a moment.
	if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		tryAirJump(0.3)
	end
end)

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
	-- V13.1: Poltergoblin is switched off (Config.POLTER_ENABLED): E is for prompts. A press a step short of one
	-- still says so.
	if not Config.POLTER_ENABLED then
		local almost = not humanoid.SeatPart and almostPrompt(6)
		if almost then
			local what = almost.ActionText ~= "" and almost.ActionText or "use it"
			Hud.toast(string.format("A step closer to %s (E).", string.lower(what)))
		end
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
	local almost = almostPrompt(6)
	if almost then
		local what = almost.ActionText ~= "" and almost.ActionText or "use it"
		Hud.toast(string.format("A step closer to %s (E).", string.lower(what)))
		return
	end
	stopRide(false)
	stopPull(false)
	lastPolterCast = t
	polterRemote:FireServer()
	playDash(root, humanoid)
end

-- Spirit form tints the screen for the spirit only. Snapping back cuts a grapple.
player:GetAttributeChangedSignal("PolterEndsAt"):Connect(function()
	local spirit = player:GetAttribute("PolterEndsAt") ~= nil
	Effects.setSpirit(spirit)
	if not spirit then
		stopPull(false)
	end
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

-- V13.2: at the wheel, the controller's R2 fires the bow gun (Roblox gives R2 to the sword in hand otherwise).
ContextActionService:BindActionAtPriority("LootGoblinsBoatGun", function(_, state)
	if not BoatDrive.isDriving() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		BoatDrive.fireGun()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonR2)

-- At the wheel, Space hops the boat instead of climbing out of it (X leaves). The binding sits above
-- Roblox's own jump control and only swallows the key while you are driving.
ContextActionService:BindActionAtPriority("LootGoblinsBoatHop", function(_, state)
	if not seatedInBoat() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		BoatDrive.jump()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

local lastTrickHint = -math.huge
local function pressTrick()
	-- V9: a trick, in the air. V13: on the water the same key is the boat's ability (BoatDrive.stunt).
	if BoatDrive.stunt() then
		return
	end
	if os.clock() - lastTrickHint > 1.5 then
		lastTrickHint = os.clock()
		local info = BoatDrive.abilityInfo()
		if info and not info.airborne and now() < info.readyAt then
			Hud.toast(string.format("%s %ds", info.def.name, math.ceil(info.readyAt - now())))
		end
	end
end
BoatDrive.setAimProvider(function()
	return (aimPoint())
end)

local function pressThrow()
	if player:GetAttribute("CarryingLoot") then
		throwRemote:FireServer()
	else
		Hud.toast("Nothing to throw. Grab some loot first.")
	end
end

-- V12: three controller buttons Roblox takes for itself before a script sees them (measured in Studio: they
-- arrive already processed): L1 and R1 switch hotbar tools (with one sword, they only put it away) and R3 is
-- the camera's zoom. So the R1 trick (V9) never worked on a controller. Bound above Roblox's own actions, they
-- throw (L1), trick at the wheel (R1) and open the map (R3). The wardrobe binds L1 and R1 higher still for its
-- tabs while it is open.
ContextActionService:BindActionAtPriority(
	"LootGoblinsPad",
	function(_, state, input)
		if state == Enum.UserInputState.Begin then
			if input.KeyCode == Enum.KeyCode.ButtonL1 then
				pressThrow()
			elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
				if seatedInBoat() then
					pressTrick()
				end
			elseif input.KeyCode == Enum.KeyCode.ButtonR3 then
				Hud.toggleMap()
			end
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.ContextActionPriority.High.Value + 10,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonR1,
	Enum.KeyCode.ButtonR3
)

-- Input ------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	-- V13.2: a click at the wheel fires the bow gun (Config.BOAT_GUN).
	if input.UserInputType == Enum.UserInputType.MouseButton1 and BoatDrive.isDriving() then
		BoatDrive.fireGun()
		return
	end
	-- In the air after a launch the keys belong to the flight (client/Skyship.lua): Space brakes, Shift dives.
	if
		player:GetAttribute("Diving")
		and (
			input.KeyCode == Enum.KeyCode.LeftShift
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.C
		)
	then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		-- V13.2: Shift is "go faster" everywhere: a boost at the wheel, a dash on foot (there is no sprint any more).
		if seatedInBoat() then
			BoatDrive.boost()
		else
			pressDash()
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonX and seatedInBoat() then
		BoatDrive.boost()
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		-- One key, two jobs: a dash on foot, a drift at the wheel.
		if seatedInBoat() then
			BoatDrive.setDrift(true)
		else
			pressDash()
		end
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		if player:GetAttribute("DownedUntil") then
			moveRemote:FireServer("getup") -- caught: the server frees you once the minimum has passed
		else
			tryAirJump()
		end
	elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonY then
		-- Leave the boat. (Space is the boat's hop now, so it no longer climbs out.) V13: Y on foot is the
		-- controller's Poltergoblin (until now a controller had no way to it).
		local _, humanoid = getCharacter()
		if humanoid and humanoid.SeatPart then
			humanoid.Sit = false
			humanoid.Jump = true
		elseif input.KeyCode == Enum.KeyCode.ButtonY and Config.POLTER_ENABLED then
			pressPoltergoblin()
		end
	elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadDown then
		recallRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.DPadLeft then
		pressKeg()
	elseif input.KeyCode == Enum.KeyCode.M then
		-- (A controller clicks the right stick: LootGoblinsPad above. Not Select: Roblox keeps Select for its
		-- own menu navigation.)
		Hud.toggleMap()
	elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
		pressDash() -- V13.2: the stick click was sprint; it dashes now, like B
	elseif input.KeyCode == Enum.KeyCode.Q then
		pressThrow()
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL2 then
		grappleHeld = true -- V13.2: held on a swing, it reels in
		pressGrapple()
	elseif input.KeyCode == Enum.KeyCode.E then
		-- V8: E belongs to whatever is IN REACH, not only to what the camera happens to show (see reachPrompt).
		-- V13.1 (the V13 playtest: "cant press E to get off boat"): in a boat with nothing else in reach, E gets you
		-- out (your own boat's Board prompt is hidden while you sit in it, so it no longer takes the key).
		local prompt = not promptOwnsE() and reachPrompt() or nil
		local _, humanoid = getCharacter()
		if prompt then
			heldPrompt = prompt
			prompt:InputHoldBegin()
		elseif humanoid and humanoid.SeatPart then
			humanoid.Sit = false
			humanoid.Jump = true
		else
			pressPoltergoblin()
		end
	elseif input.KeyCode == Enum.KeyCode.R and seatedInBoat() then
		pressTrick()
	elseif input.KeyCode == Enum.KeyCode.H then
		Hud.toggleHelp()
	elseif input.KeyCode == Enum.KeyCode.T then
		Hud.toggleBoard()
	end
end)

-- V12: touch buttons for the essential loop (only on a touch screen): the same functions the keys call.
TouchControls.start({
	fire = Skyship.fire,
	call = function()
		recallRemote:FireServer()
	end,
	grapple = pressGrapple,
	throw = function()
		if player:GetAttribute("CarryingLoot") then
			throwRemote:FireServer()
		end
	end,
	boost = BoatDrive.boost,
	hop = BoatDrive.jump,
	trick = pressTrick, -- V13: in the air a trick, on the water the boat's ability
	gun = BoatDrive.fireGun, -- V13.2: the bow gun
}, function()
	if player:GetAttribute("DeployState") == "loaded" then
		return "aim"
	end
	return Hud.mode()
end)

-- V12: the treasure you carry rides over your head, and from the camera behind you its glow (bloomed) sat exactly
-- where you look: the way ahead was a white blur. For its own carrier it is dimmed; everyone else still sees a
-- carrier glow (the server already turns its pillar off while it is carried).
local dimmed = nil -- { id, parts = { part = true } }
local function dimCarried()
	local id = player:GetAttribute("CarryingLoot")
	if dimmed and (not id or dimmed.id ~= id) then
		for part in pairs(dimmed.parts) do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
		dimmed = nil
	end
	if not id or dimmed then
		return
	end
	local folder = generated:FindFirstChild("Loot")
	local model = folder and folder:FindFirstChild(id)
	if not model then
		return
	end
	dimmed = { id = id, parts = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = d.Material == Enum.Material.Neon and 0.65 or 0.35
			dimmed.parts[d] = true
		end
	end
end
player:GetAttributeChangedSignal("CarryingLoot"):Connect(dimCarried)

-- Screen tint follows Heat, including for players who join mid-raid.
local function applyHeatTint()
	Effects.setHeatTier(workspace:GetAttribute("HeatTier") or 1)
end
workspace:GetAttributeChangedSignal("HeatTier"):Connect(applyHeatTint)
applyHeatTint()

RunService.RenderStepped:Connect(function()
	Hud.update(now())
	-- The faster you travel (on foot or in a boat), the wider the view.
	local _, _, root = getCharacter()
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	Effects.setSpeed(Vector3.new(v.X, 0, v.Z).Magnitude)
end)

-- Server events --------------------------------------------------------------------------
local function isMe(payload)
	return payload.userId == player.UserId
end

local handlers = {}
Skyship.install(handlers)
Skyship.start()
Shop.start()
-- V11 (Goblin Life): style on boats and emotes, pets, the emote wheel, the raid's results and rewards.
Looks.start()
Pets.start()
Emotes.start(Shop.dock)
Results.start(function()
	Shop.open("shop")
end)
-- V13.3: a marker pointing the way to a place in the Port for a little while (the card after a raid's SHOW ME).
local pointer = { token = 0 }
local function pointAt(position, label)
	pointer.token += 1
	local token = pointer.token
	if not pointer.part then
		pointer.part = Instance.new("Part")
		pointer.part.Name = "PortPointer"
		pointer.part.Anchored = true
		pointer.part.CanCollide = false
		pointer.part.CanQuery = false
		pointer.part.CanTouch = false
		pointer.part.Transparency = 1
		pointer.part.Size = Vector3.new(0.2, 0.2, 0.2)
		pointer.part.Parent = workspace
		pointer.gui = Instance.new("BillboardGui")
		pointer.gui.Adornee = pointer.part
		pointer.gui.Size = UDim2.fromOffset(240, 70)
		pointer.gui.AlwaysOnTop = true
		pointer.gui.LightInfluence = 0
		pointer.gui.MaxDistance = 2000
		pointer.gui.Parent = player:WaitForChild("PlayerGui")
		pointer.label = Instance.new("TextLabel")
		pointer.label.BackgroundTransparency = 1
		pointer.label.Size = UDim2.fromScale(1, 1)
		pointer.label.Font = Enum.Font.FredokaOne
		pointer.label.TextScaled = true
		pointer.label.TextColor3 = GOLD
		pointer.label.TextStrokeTransparency = 0.2
		pointer.label.Parent = pointer.gui
	end
	pointer.part.CFrame = CFrame.new(position + Vector3.new(0, 14, 0))
	pointer.label.Text = "▼ " .. (label or "HERE")
	pointer.gui.Enabled = true
	Effects.chime({ 1, 1.5 }, 0.5)
	task.delay(25, function()
		if pointer.token == token then
			pointer.gui.Enabled = false
		end
	end)
end

-- V13: the Goblin Port's own screen, watching the raid from it, and its menagerie. (V13.3: its new chips.)
local sanctuaryRemote = remotes:WaitForChild("SanctuaryRequest")
local function questsReady()
	local text = player:GetAttribute("Quests")
	local ok, view = pcall(function()
		return game:GetService("HttpService"):JSONDecode(text or "{}")
	end)
	local n = 0
	if ok and type(view) == "table" then
		for _, kind in ipairs({ "day", "week" }) do
			for _, q in ipairs(view[kind] or {}) do
				if not q.claimed and q.n >= q.goal then
					n += 1
				end
			end
		end
	end
	return n
end
PortHud.start(function(focus)
	Shop.open("shop", focus)
end, {
	quests = function()
		PortBoard.open("quests")
	end,
	challenge = function()
		Challenge.open()
	end,
	sanctuary = function()
		if SanctuaryView.readyCount() > 0 then
			SanctuaryView.open("expeditions")
		else
			sanctuaryRemote:FireServer("home")
		end
	end,
	goal = function()
		return (NextUp.goalText())
	end,
	playing = PlayHud.playing,
	questReady = questsReady,
	petsHome = SanctuaryView.readyCount,
})
Titles.start()
PlayHud.start(Hud, PortHud.fadeIn)
PortBoard.start(Hud)
SanctuaryView.start(Hud)
NextUp.start(function()
	PortBoard.open("quests")
end, pointAt)
Challenge.start(Hud, PlayHud)
-- The Living Port's prompts that open a panel (the Quest Board, an isle's signpost and dock, the lift's VISIT).
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local panel = prompt:GetAttribute("OpensPanel")
	if not panel then
		return
	end
	if panel == "quests" then
		PortBoard.open("quests")
	elseif panel == "visit" then
		SanctuaryView.open("visit")
	elseif panel == "sanctuary" or panel == "expeditions" then
		local owner = prompt:GetAttribute("Owner")
		if owner == player.UserId then
			SanctuaryView.open(panel)
		else
			Hud.toast("This isn't your sanctuary: yours is up the lift in the Port.")
		end
	end
end)
Spectate.start(Hud.toast)
PortLife.start()
ChaosFx.start(Hud)

-- V13.3: the Living Port.
function handlers.PlayResult(p)
	PlayHud.result(p)
end
function handlers.PlayFx(p)
	PlayHud.fx(p)
	if p.kind == "expeditionhome" then
		SanctuaryView.expeditionHome(p)
	end
end
function handlers.QuestDone(p)
	PortBoard.questDone(p)
end
function handlers.QuestRollover(p)
	PortBoard.rollover(p)
end
function handlers.QuestClaimed(_p) end
function handlers.SeasonReward(p)
	PortBoard.seasonReward(p)
end
function handlers.BoardBest(p)
	PortBoard.best(p)
end
function handlers.NextUp(p)
	NextUp.show(p)
end
function handlers.ChallengeInvite(p)
	Challenge.invited(p)
end
function handlers.ChallengeSent(p)
	Challenge.sent(p)
end
function handlers.ChallengeClosed(p)
	Challenge.closed(p)
end
function handlers.ChallengeStart(p)
	Challenge.started(p)
end
function handlers.ChallengeResult(p)
	Challenge.result(p)
end
function handlers.ChallengeRematch(p)
	Challenge.rematchAsked(p)
end

-- V13.2: the world's chaos (server/WorldChaos.lua), and coming home early from a raid.
function handlers.Chaos(p)
	ChaosFx.handle(p)
end
function handlers.RaidLeft()
	Hud.toast("Home to the Port. This raid's gold and Shinies stay out there.")
end

function handlers.SpectateEnd(p)
	Spectate.ended(p)
end

function handlers.SpectateSwitch(p)
	Spectate.switched(p)
end

function handlers.RaidJoined()
	Hud.banner("YOU'RE IN! CLIMB INTO A CANNON", GOLD, 3.5, 3)
	Effects.chime(Effects.CHIME_GOOD, 0.8)
end

function handlers.ShopResult(p)
	Shop.result(p)
	if not Shop.isOpen() and p.message and p.action ~= "opened" then
		Hud.toast(p.message)
	end
end

function handlers.Welcome(p)
	Shop.welcome(p)
end

-- A trophy: a moment of celebration, short and out of the way.
function handlers.Achievement(p)
	Hud.banner("TROPHY: " .. string.upper(p.name or ""), Color3.fromRGB(196, 128, 255), 3.5, 2)
	Hud.toast(
		string.format("+%d Shinies", p.shinies or 0)
			.. (p.rewardName and (" and the " .. p.rewardName .. " (in your locker)") or "")
	)
	Effects.chime({ 1, 1.26, 1.5, 2, 2.5 }, 0.8)
	Pets.react(player.UserId, "cheer")
end

function handlers.Premium(p)
	Hud.banner(
		"THANK YOU! " .. string.upper(table.concat(p.names or {}, ", ")) .. " IS YOURS",
		Color3.fromRGB(90, 226, 176),
		4
	)
	Effects.chime(Effects.CHIME_GOOD, 0.8)
end

function handlers.RaidReward(p)
	Results.reward(p)
end

function handlers.Celebrate(p)
	Looks.celebrate(p)
	Pets.react(p.userId, "dance")
end

function handlers.Message(p)
	Hud.banner(p.text or "", p.color, p.duration, p.priority)
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
		Hud.banner("YOU STOLE THE " .. string.upper(p.itemName) .. "! RUN FOR THE HOARD!", color, 3, 3)
		Hud.flash(color, 0.3)
	else
		Hud.banner(string.upper(p.name) .. " STOLE THE " .. string.upper(p.itemName) .. "!", color, 3, 1)
	end
	Effects.chime(Effects.CHIME_STEAL, 0.8)
	Effects.burst(p.position, color, 40, 24)
	Effects.ring(p.position, color, 16, 0.6)
	Pets.react(p.userId, "cheer")
end

function handlers.Snatched(p)
	Pets.react(p.userId, "cheer")
	if isMe(p) then
		Hud.banner("GOT IT! " .. string.upper(p.itemName) .. " IS YOURS", GOLD, 2, 3)
		Effects.chime(Effects.CHIME_GOOD, 0.6)
	elseif p.from == player.DisplayName then
		Hud.banner(string.upper(p.name) .. " GRAPPLED YOUR " .. string.upper(p.itemName) .. "!", DANGER, 2.5, 3)
		Hud.flash(DANGER, 0.35)
		Effects.chime(Effects.CHIME_STEAL, 0.7)
	else
		Hud.banner(string.upper(p.name) .. " GRAPPLED THE " .. string.upper(p.itemName) .. "!", nil, 2, 1)
	end
end

function handlers.Grabbed(p)
	if isMe(p) then
		Hud.banner("YOU GRABBED THE " .. string.upper(p.itemName) .. "!", GOLD, 1.6, 3)
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
	Pets.react(p.userId, "cheer")
	local color = LOOT_COLORS[p.item] or GOLD
	if isMe(p) then
		Hud.banner(
			string.format("BANKED THE %s! +%d GOLD (%d total)", string.upper(p.itemName), p.value, p.total),
			GOLD,
			3.5,
			3
		)
		Hud.flash(GOLD, 0.35)
	else
		Hud.banner(
			string.format("%s BANKED THE %s (+%d)", string.upper(p.name), string.upper(p.itemName), p.value),
			color,
			3,
			1
		)
	end
	Effects.chime(Effects.CHIME_GOOD, 0.9)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			Effects.burst(p.position + Vector3.new(0, 3 + i * 3, 0), i == 1 and color or GOLD, 45, 28)
		end)
	end
	Effects.ring(p.position, GOLD, 22, 0.8)
	for i = 1, 6 do
		task.delay(0.3 + i * 0.28, function()
			Effects.firework(p.position, (i % 2 == 0) and color or GOLD)
		end)
	end
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
		Hud.banner("HEAT IS TOO HIGH: THE GUARDIAN AWAKENS!", DANGER, 3, 2)
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
	Effects.explosion(p.position, p.radius, p.silent)
	Effects.shakeAt(p.position, 1, 0.35, 60)
end

function handlers.CaveIn(p)
	Effects.shakeAt(p.position, 1.5, 1.2, 160)
	Effects.sound("boom", { position = p.position, speed = 0.5, volume = 1 })
end

local otherRopes = {} -- V13.2: userId -> the rope drawn for another goblin's swing
function handlers.GrappleFX(p)
	if p.kind == "rope" then
		-- Another goblin's swing (their own client is flying it).
		local other = Players:GetPlayerByUserId(p.userId or 0)
		local root = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and typeof(p.to) == "Vector3" then
			local old = otherRopes[p.userId]
			if old and old.Parent then
				old:Destroy()
			end
			otherRopes[p.userId] = Effects.rope(root, p.to, ROPE_COLOR, p.duration or 6)
			Effects.ball(p.to, ROPE_COLOR, 2.5, 0.3)
		end
		return
	elseif p.kind == "cut" then
		local old = otherRopes[p.userId]
		otherRopes[p.userId] = nil
		if old and old.Parent then
			old:Destroy()
		end
		return
	elseif p.kind == "throw" then
		-- V13.2: a hook thrown at a carrier: it flies (and can be dodged). The thrower sees it go; the target sees
		-- it coming, with a warning ring where it will arrive.
		if typeof(p.from) == "Vector3" and typeof(p.to) == "Vector3" then
			Effects.line(p.from, p.to, ROPE_COLOR, 0.25, math.max(0.15, p.duration or 0.2))
			if p.victim == player.UserId then
				Effects.ring(
					p.to - Vector3.new(0, 2.5, 0),
					Color3.fromRGB(255, 90, 80),
					Config.CATCH_HOOK_WIDTH,
					p.duration or 0.2
				)
				Hud.toast("HOOK INCOMING! Dash (C) out of its way!")
			end
		end
		return
	end
	if p.kind == "pull" then
		if isMe(p) then
			startPull(p.to, p.normal or Vector3.yAxis, p.part, p.offset)
		else
			local other = Players:GetPlayerByUserId(p.userId or 0)
			local root = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root then
				Effects.rope(root, p.to, ROPE_COLOR, p.duration, p.part, p.offset)
			end
		end
		Effects.ball(p.to, ROPE_COLOR, 2.5, 0.3)
		Effects.sound("thud", { position = p.to, speed = 1.7, volume = 0.6 })
		return
	end
	if p.kind == "catch" then
		-- The hook round a carrier's middle: a rope to them, a ring, stars where they fall.
		Effects.line(p.from, p.to, ROPE_COLOR, 0.3, 0.45)
		Effects.ring(p.to - Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 120, 90), 9, 0.5)
		Effects.burst(p.to, Color3.fromRGB(255, 240, 160), 22, 16)
		Effects.sound("thud", { position = p.to, speed = 1.1, volume = 0.9 })
		if p.victim == player.UserId then
			Effects.shakeAt(p.to, 0.8, 0.4, 40)
			Effects.punchFov(52)
		end
		return
	end
	-- A steal, or a miss that only the thrower sees.
	local color = p.success and GOLD or Color3.fromRGB(255, 245, 140)
	Effects.line(p.from, p.to, color, p.kind == "miss" and 0.12 or 0.22, 0.25)
	if p.success then
		Effects.burst(p.to, GOLD, 15, 12)
	end
end

-- Other players' moves (your own are drawn the moment you press the key).
function handlers.Dash(p)
	if not isMe(p) then
		Effects.dash(p.position, nil)
	end
end

function handlers.AirJump(p)
	if not isMe(p) then
		Effects.airJump(p.position)
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

-- The new world: telegraphs, weather, boats, mechanisms ---------------------------------------
function handlers.Marker(p)
	Effects.marker(p.position, p.radius or 12, p.duration or 1.5, p.color, p.style)
end

function handlers.Bolt(p)
	Effects.bolt(p.position)
end

function handlers.Flare(p)
	local own = isMe(p)
	Effects.flare(p.position, p.color or GOLD, own and 3 or 4.5)
	if not own then
		Hud.feed(string.format("FLARE: %s is carrying!", p.name or "a thief"), p.color)
	end
end

function handlers.Shell(p)
	Effects.shell(p.from, p.to, p.duration or 1.5)
end

function handlers.Tentacle(p)
	Effects.tentacle(p.position, p.delay or 1.5)
end

function handlers.Gulls(p)
	Effects.gulls(p.position)
end

function handlers.NavySpawn(p)
	Effects.sound("boom", { position = p.position, speed = 0.5, volume = 1, range = 1200 })
	Effects.chime(Effects.CHIME_ALARM, 0.8)
end

function handlers.Frenzy()
	Hud.flash(DANGER, 0.3)
	Effects.chime(Effects.CHIME_ALARM, 0.9)
end

function handlers.GuardianLeap(p)
	Effects.sound("boom", { position = p.position, speed = 0.4, volume = 1, range = 700 })
end

function handlers.GuardianThrow(p)
	Effects.shell(p.from, p.to, p.duration or 1.6)
end

function handlers.GuardianStomp(p)
	Effects.shockwave(p.position, p.radius or 70, p.windup or 0.8, p.speed or 55)
	local _, _, root = getCharacter()
	if root and (root.Position - p.position).Magnitude < (p.radius or 70) + 15 then
		Hud.banner("STOMP! BE IN THE AIR WHEN THE RING REACHES YOU", DANGER, 1.6, 4)
	end
end

-- A patrol ship has lined you up and is coming through.
function handlers.NavyRam(p)
	for i = 0, 2 do
		task.delay(i * 0.22, function()
			Effects.sound("rise", { position = p.position, speed = 0.45, volume = 1, range = 900 })
		end)
	end
	if isMe(p) then
		Hud.banner("RAMMING SPEED! TURN HARD OR DRIFT OUT OF ITS WAY", DANGER, 2.2, 4)
		Hud.flash(DANGER, 0.2)
	end
end

-- A waterspout caught something.
function handlers.Spout(p)
	Effects.spray(p.position, 0.8)
	Effects.sound("whoosh", { position = p.position, speed = 0.5, volume = 1, range = 400 })
end

function handlers.CannonFire(p)
	Effects.burst(p.position, Color3.fromRGB(255, 200, 120), 30, 28)
	Effects.ball(p.position, Color3.fromRGB(255, 190, 90), 6, 0.2)
	Effects.sound("boom", { position = p.position, speed = 0.9, volume = 1, range = 700 })
	Effects.shakeAt(p.position, 0.7, 0.25, 60)
end

function handlers.KegLit(p)
	Effects.sound("blip", { position = p.position, speed = 0.8, volume = 0.7, range = 200 })
end

function handlers.TargetHit(p)
	Effects.ring(p.position, GOLD, 12, 0.6)
	Effects.chime(Effects.CHIME_GOOD, 0.6)
end

function handlers.Broke(p)
	Effects.burst(p.position, Color3.fromRGB(190, 170, 140), 40, 28)
	Effects.sound("boom", { position = p.position, speed = 0.6, volume = 0.9, range = 500 })
	Effects.shakeAt(p.position, 0.9, 0.5, 120)
end

function handlers.GateMove(p)
	Effects.sound("thud", { position = p.position, speed = 0.5, volume = 1, range = 300 })
	Effects.shakeAt(p.position, 0.5, 0.8, 80)
end

function handlers.Beacon(p)
	Effects.sound("whoosh", { position = p.position, speed = 0.6, volume = 1, range = 500 })
	Effects.burst(p.position, Color3.fromRGB(255, 160, 70), 40, 30)
end

-- What a boat just did, drawn where it happened. mine: this client is driving that boat, so the
-- camera kicks too. Your own boat reports through BoatDrive the frame it happens; other
-- players' boats arrive from the server.
local MINI_COLORS = { mini1 = Color3.fromRGB(120, 220, 255), mini2 = Color3.fromRGB(255, 170, 70) }

local function boatFx(kind, position, mine, airTime)
	if kind == "mini1" or kind == "mini2" then
		local strong = kind == "mini2"
		Effects.burst(position, MINI_COLORS[kind], strong and 60 or 35, strong and 40 or 28)
		Effects.ring(position, MINI_COLORS[kind], strong and 22 or 14, 0.4)
		Effects.sound("rise", { position = position, speed = strong and 1.5 or 1.9, volume = 0.8, range = 300 })
		if mine then
			Effects.punchFov(strong and 96 or 90)
		end
	elseif kind == "landing" then
		-- V12: the longer the flight, the bigger the landing (a super jump comes down like one).
		local big = math.clamp((airTime or 1) / 2.5, 0.4, 1.3)
		Effects.spray(position, 0.5 + big * 0.5)
		Effects.ring(position, Color3.fromRGB(190, 255, 220), 14 + big * 12, 0.4)
		if mine then
			Effects.punchFov(86 + big * 8)
			Hud.toast("Clean landing! Speed burst.")
		end
	elseif kind == "splash" then
		-- V12: a crooked or hard landing from a real flight is a belly flop: spray (with its slap and its shake,
		-- Effects.spray) to match the fall, a ring, and for your own boat a thud. Through V11 every one was the same
		-- small puff, so a boat thrown fifty studs up by a ramp or a tornado came down with a whisper.
		local fall = airTime or 0
		local power = math.clamp(fall / 2.2, 0.35, 1.5)
		Effects.spray(position, power)
		if fall >= 1.2 then
			Effects.ring(position, Color3.fromRGB(220, 240, 255), 12 + power * 12, 0.45)
			if mine then
				Effects.sound("thud", { speed = 0.7, volume = 0.7 })
			end
		end
	elseif kind == "super" then
		-- The super jump: a wall of spray, a ring, the view thrown wide.
		Effects.spray(position, 1.3)
		Effects.ring(position, Color3.fromRGB(255, 240, 160), 30, 0.6)
		Effects.burst(position, Color3.fromRGB(255, 255, 255), 70, 55)
		Effects.sound("whoosh", { position = position, speed = 0.9, volume = 1, range = 400 })
		Effects.sound("rise", { position = position, speed = 1.3, volume = 0.8, range = 400 })
		if mine then
			Effects.punchFov(108)
			Hud.toast("SUPER JUMP!")
		end
	elseif kind == "jump" then
		Effects.spray(position, 0.45)
		Effects.sound("whoosh", { position = position, speed = 1.4, volume = 0.7, range = 250 })
		if mine then
			Effects.punchFov(84)
		end
	elseif kind == "punch" then
		Effects.burst(position, Color3.fromRGB(255, 240, 200), 30, 26)
		if mine then
			Effects.punchFov(100)
		end
	elseif kind == "hoop" or kind == "boost" then
		Effects.burst(position, Color3.fromRGB(120, 255, 230), 40, 30)
		Effects.sound("rise", { position = position, speed = 1.8, volume = 0.8, range = 300 })
		if mine then
			Effects.punchFov(92)
		end
	elseif kind == "kick" then
		Effects.burst(position, Color3.fromRGB(255, 220, 90), 50, 34)
		Effects.sound("whoosh", { position = position, speed = 0.8, volume = 1, range = 300 })
		if mine then
			Effects.punchFov(94)
		end
	end
end

-- V13: a boat ability, drawn where it happened (yours from BoatDrive, everyone else's from the server's BoatFx).
-- V13.2: the Cutter's Rally Horn, the Anchorjack's anchor, the Wavebreaker's breaker and the Corsair's hook.
local ABILITY_FX = {
	nitro = { Color3.fromRGB(255, 140, 40), "whoosh", 0.7, 104 },
	rally = { Color3.fromRGB(255, 220, 140), "rise", 0.45, 96 },
	spring = { Color3.fromRGB(90, 230, 210), "rise", 1.3, 104 },
	volley = { Color3.fromRGB(255, 190, 90), nil, 1, 94 },
	twister = { Color3.fromRGB(190, 210, 255), "whoosh", 0.5, 100 },
	slip = { Color3.fromRGB(110, 255, 210), "whoosh", 2, 104 },
	plow = { Color3.fromRGB(255, 200, 40), "thud", 0.6, 100 },
	anchor = { Color3.fromRGB(150, 220, 200), "whoosh", 0.8, 96 },
	breaker = { Color3.fromRGB(140, 220, 255), "thud", 0.45, 106 },
	hook = { Color3.fromRGB(255, 120, 110), "whoosh", 1.2, 98 },
}
local CHAIN_COLOR = Color3.fromRGB(150, 150, 160)
local function abilityFx(id, position, mine)
	local fx = ABILITY_FX[id]
	if not fx or typeof(position) ~= "Vector3" then
		return
	end
	Effects.burst(position, fx[1], 50, 40)
	Effects.ring(position, fx[1], id == "rally" and 75 or 24, id == "rally" and 0.9 or 0.5)
	if id == "spring" or id == "plow" or id == "breaker" then
		Effects.spray(position, id == "breaker" and 1.6 or 1.1)
	end
	if id == "rally" then
		-- The horn: two long low notes anyone near can hear.
		Effects.sound("rise", { position = position, speed = 0.32, volume = 1, range = 600 })
	end
	if fx[2] then
		Effects.sound(fx[2], { position = position, speed = fx[3], volume = 1, range = 400 })
	end
	if mine then
		Effects.punchFov(fx[4])
	end
end

local TRICK_SOUND = { 1.25, 1.45, 1.7, 1.95, 2.2 }
BoatDrive.toast = function(text)
	Hud.toast(text)
end
BoatDrive.onEvent(function(kind, position, chain, extra)
	if kind == "ability" then
		abilityFx(chain, position, true)
		-- V13.2: the anchor or the hook flies out to where it went (the chain itself comes from the server: BoatChain).
		local target = type(extra) == "table" and extra or nil
		local to = target and (target.part and target.part.Position or target.point)
		if typeof(to) == "Vector3" then
			Effects.line(position + Vector3.new(0, 3, 0), to + Vector3.new(0, 2, 0), ABILITY_FX[chain][1], 0.5, 0.35)
			Effects.ball(to + Vector3.new(0, 2, 0), ABILITY_FX[chain][1], 6, 0.35)
		end
		if chain == "anchor" then
			Hud.toast(
				target and target.part and "SNAGGED! R lets the chain go."
					or "Swinging round the anchor: R lets go (slingshot)!"
			)
		elseif chain == "hook" then
			Hud.toast(target and target.part and "HOOKED! Reeling in to board..." or "Zipping to the rock!")
		end
		return
	elseif kind == "released" then
		if chain == "sling" then
			Effects.burst(position, Color3.fromRGB(150, 220, 200), 50, 50)
			Effects.sound("whoosh", { speed = 0.7, volume = 1 })
			Effects.punchFov(106)
			Hud.toast("SLINGSHOT!")
		end
		return
	elseif kind == "airhop" then
		Effects.burst(position, Color3.fromRGB(90, 230, 210), 30, 30)
		Effects.sound("rise", { position = position, speed = 1.6, volume = 0.8, range = 300 })
		Effects.punchFov(96)
		return
	end
	if kind == "trickstart" then
		-- V9: the name lands with the motion, loud and tilted (client/Tricks.lua).
		local name = BoatDrive.TRICK_NAMES[chain] or "TRICK"
		if chain == "roll" then
			name = extra == -1 and "PORT ROLL" or "STARBOARD ROLL"
		end
		Tricks.started(name)
		Looks.trick(BoatDrive.model())
		Effects.sound("whoosh", { speed = 1.6, volume = 0.9 })
		return
	elseif kind == "trick" then
		Effects.sound("rise", { speed = TRICK_SOUND[math.clamp(extra or 1, 1, #TRICK_SOUND)], volume = 0.9 })
		Effects.burst(position, Color3.fromRGB(255, 120, 230), 24, 30)
		return
	elseif kind == "trickland" then
		Tricks.landed(chain or 1)
		Looks.landed(BoatDrive.model(), chain or 1)
		Effects.spray(position, 0.9)
		Effects.ring(position, Color3.fromRGB(170, 255, 60), 26, 0.5)
		Effects.chime({ 1, 1.26, 1.5, 2 }, 0.7)
		Effects.punchFov(100)
		return
	elseif kind == "sketchy" then
		Tricks.sketchy()
		Effects.spray(position, 0.8)
		Effects.sound("thud", { speed = 0.7, volume = 1 })
		return
	elseif kind == "bail" then
		Effects.sound("whoosh", { speed = 0.8, volume = 1 })
		Effects.punchFov(104)
		Hud.toast("BAILED OUT OF THE TORNADO!")
		return
	elseif kind == "twister" then
		Hud.toast("IN THE TORNADO! Ride it up and trick (R), or bail out with SPACE.")
		Effects.sound("whoosh", { speed = 0.6, volume = 1 })
		return
	end
	boatFx(kind, position, true, (kind == "splash" or kind == "landing") and chain or nil)
	if kind == "hoop" and (chain or 1) >= 2 then
		-- A chain of hoops: say so (in the boat panel), and let the note climb with it.
		Hud.chain(chain)
		Effects.sound("blip", { speed = 1 + math.min(chain, 8) * 0.14, volume = 0.8 })
	end
end)

-- Stealing from a goblin who has been caught (V7) --------------------------------------------
-- The prompt is made HERE, on this client, on another goblin's body, only while they are down and
-- carrying and you have empty hands: it never shows on your own body and does not exist the rest of
-- the time. Pressing E sends who it is; the server checks the distance, the wall and the hold.
local stealPrompts = {}
task.spawn(function()
	while true do
		local t = now()
		local emptyHanded = player:GetAttribute("CarryingLoot") == nil
		for other, prompt in pairs(stealPrompts) do
			if not other.Parent or not prompt.Parent then
				prompt:Destroy()
				stealPrompts[other] = nil
			end
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				local carried = other:GetAttribute("CarryingLoot")
				local want = root ~= nil
					and emptyHanded
					and carried ~= nil
					and (other:GetAttribute("DownedUntil") or 0) > t
				local prompt = stealPrompts[other]
				if want and (not prompt or prompt.Parent ~= root) then
					if prompt then
						prompt:Destroy()
					end
					prompt = Instance.new("ProximityPrompt")
					prompt.Name = "StealPrompt"
					prompt.ObjectText = other.DisplayName
					prompt.ActionText = "Steal the treasure"
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = Config.STEAL_RANGE + 2
					prompt.RequiresLineOfSight = false
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
					prompt.Parent = root
					prompt.Triggered:Connect(function()
						stealRemote:FireServer(other)
					end)
					stealPrompts[other] = prompt
				elseif not want and prompt then
					prompt:Destroy()
					stealPrompts[other] = nil
				end
			end
		end
		task.wait(0.15)
	end
end)

-- Signs ---------------------------------------------------------------------------------------
-- A floating sign is meant to show within its MaxDistance of the camera. Roblox measures that
-- along the line of sight, not to the sign, so anything far off to one side still showed: from
-- the harbor a dozen island names stood on the horizon, most of them islands a long way away.
-- This hides every sign that is really out of range (the server tags them: WorldKit's sign()).
task.spawn(function()
	while true do
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, sign in ipairs(CollectionService:GetTagged("RangedSign")) do
			local holder = sign.Parent
			if holder and holder:IsA("BasePart") then
				sign.Enabled = (holder.Position - eye).Magnitude <= sign.MaxDistance
			end
		end
		task.wait(0.4)
	end
end)

-- Coins -------------------------------------------------------------------------------------
-- The server decides who took a coin (Coins.lua). So that it feels instant at boat speed, this
-- client hides a coin the moment its own boat or goblin is in reach; the server's answer follows
-- a moment later and makes it real (or, rarely, the coin comes back).
do
	local coinsFolder = generated:WaitForChild("Coins", 600)
	local hidden = {}
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if not coinsFolder or t < nextCheck then
			return
		end
		nextCheck = t + 0.04
		local _, humanoid, root = getCharacter()
		if not root then
			return
		end
		local position, reach = root.Position, Config.COIN_FOOT_REACH
		local seat = humanoid.SeatPart
		local hull = seat and seat.Parent and seat.Parent:FindFirstChild("Hull")
		if hull then
			position, reach = hull.Position, Config.COIN_BOAT_REACH
		end
		for _, coin in ipairs(coinsFolder:GetChildren()) do
			if coin.Name == "Coin" and coin.Transparency < 0.5 and not hidden[coin] then
				local offset = coin.Position - position
				if
					offset.X * offset.X + offset.Z * offset.Z <= reach * reach
					and math.abs(offset.Y) <= Config.COIN_HEIGHT
				then
					hidden[coin] = true
					coin.LocalTransparencyModifier = 1
					task.delay(2, function()
						hidden[coin] = nil
						if coin.Parent then
							coin.LocalTransparencyModifier = 0
						end
					end)
				end
			end
		end
	end)
end

-- Island creatures (Creatures.lua on the server). One sound and one puff per kind of thing they do.
local CREATURE_FX = {
	thud = { "thud", 0.7, 1, Color3.fromRGB(200, 200, 190) },
	stone = { "thud", 0.45, 0.9, Color3.fromRGB(170, 170, 165) },
	shatter = { "blip", 2.6, 0.9, Color3.fromRGB(215, 120, 255) },
	chime = { "blip", 0.7, 0.8, Color3.fromRGB(215, 120, 255) },
	erupt = { "boom", 1.5, 0.8, Color3.fromRGB(230, 200, 140) },
	rumble = { "boom", 0.5, 0.5, Color3.fromRGB(230, 200, 140) },
	bleat = { "rise", 1.6, 0.9, Color3.fromRGB(235, 228, 210) },
	zap = { "blip", 3.2, 0.9, Color3.fromRGB(120, 235, 255) },
	shriek = { "rise", 2.4, 0.9, Color3.fromRGB(96, 190, 84) },
	whistle = { "blip", 2.9, 1, Color3.fromRGB(255, 230, 120) },
	steam = { "splash", 1.8, 0.8, Color3.fromRGB(230, 235, 240) },
	chill = { "blip", 0.5, 0.7, Color3.fromRGB(190, 235, 255) },
	eye = { "rise", 0.5, 0.9, Color3.fromRGB(150, 90, 220) },
	splash = { "splash", 1, 0.8, Color3.fromRGB(220, 240, 255) },
	-- V13.1: the jade frogs and the Chill's hail.
	croak = { "thud", 1.9, 1, Color3.fromRGB(52, 178, 116) },
	hail = { "thud", 2.2, 1, Color3.fromRGB(190, 235, 255) },
}

function handlers.Creature(p)
	local fx = CREATURE_FX[p.kind]
	if not fx or typeof(p.position) ~= "Vector3" then
		return
	end
	Effects.sound(fx[1], { position = p.position, speed = fx[2], volume = fx[3], range = 320 })
	Effects.burst(p.position, fx[4], 14, 18)
	if p.kind == "erupt" or p.kind == "thud" then
		Effects.shakeAt(p.position, 0.4, 0.5, 70)
	end
end

function handlers.Coin(p)
	if p.salvage then
		Effects.chime(Effects.CHIME_GOOD, 0.8)
		Effects.burst(p.position, GOLD, 30, 26)
	else
		Effects.sound("blip", { speed = (p.value or 1) > 1 and 2.4 or 1.9, volume = 0.55 })
		Effects.burst(p.position, GOLD, (p.value or 1) > 1 and 14 or 6, 16)
	end
end

function handlers.CoinsBanked(p)
	Hud.banner(
		string.format("PURSE CASHED IN: +%d GOLD (%d of %d from coins this raid)", p.gold, p.total, p.cap),
		GOLD,
		3
	)
	Effects.chime(Effects.CHIME_GOOD, 0.8)
end

function handlers.Run(p)
	if p.started then
		Hud.toast(
			string.format(p.loop and "%s: GO! one lap, either way. par %.1f s" or "%s: GO! par %.1f s", p.name, p.par)
		)
		Effects.sound("blip", { speed = 1.5, volume = 0.8 })
		return
	end
	local line = string.format("%s in %.1f s", p.name, p.time)
	if p.underPar then
		line ..= "  UNDER PAR!"
	end
	if p.best then
		line ..= "  BEST TIME"
	end
	if (p.coins or 0) > 0 then
		line ..= string.format("  +%d coins", p.coins)
	end
	Hud.banner(line, p.underPar and GOLD or Color3.fromRGB(255, 185, 80), 3)
	Effects.chime(p.underPar and Effects.CHIME_GOOD or { 1, 1.26 }, 0.8)
end

function handlers.GatePass(p)
	-- Our own boat's gate was already drawn by BoatDrive, unless the server is simulating it.
	if isMe(p) then
		return
	end
	local _, _, root = getCharacter()
	local mine = BoatDrive.isDriving() and root ~= nil and (p.position - root.Position).Magnitude < 30
	boatFx(p.kind, p.position, mine)
end

function handlers.RecallCalled(p)
	if p.userId == player.UserId then
		Effects.ring(p.position, Color3.fromRGB(110, 255, 190), 28, 1.2)
		if typeof(p.boat) == "Instance" then
			Hud.calledBoat(p.boat) -- V13.1: the shore hint says it is coming
		end
	end
end

local OTHER_TRICK_NAMES = {
	spin = "SPIN CYCLE!",
	spin2 = "DOUBLE SPIN!",
	roll = "BARREL ROLL!",
	backflip = "KEEL FLIP!",
	frontflip = "BOW FLIP!",
	corkscrew = "CORKSCREW!",
}
function handlers.BoatFx(p)
	if isMe(p) or typeof(p.position) ~= "Vector3" then
		return
	end
	if p.kind == "ability" then
		abilityFx(p.ability, p.position, false)
	elseif p.kind == "trick" then
		-- Someone else's trick, shown over their boat so it reads as deliberate.
		Tricks.other(p.position, OTHER_TRICK_NAMES[p.trick] or "TRICK!", p.userId)
		Looks.trick(Looks.boatOf(p.userId))
		Effects.sound("rise", { position = p.position, speed = 1.6, volume = 0.7, range = 300 })
	elseif p.kind == "trickland" then
		Looks.landed(Looks.boatOf(p.userId), p.tricks or 1)
		Effects.spray(p.position, 0.8)
		Effects.ring(p.position, Color3.fromRGB(170, 255, 60), 22, 0.5)
	elseif p.kind == "sketchy" or p.kind == "bail" then
		Effects.spray(p.position, 0.7)
	else
		boatFx(p.kind, p.position, false)
	end
end

-- V9: the Guardian's stone fist came up under someone.
function handlers.GuardianLaunch(p)
	if typeof(p.position) ~= "Vector3" then
		return
	end
	Pets.react(p.userId, "tumble")
	Effects.sound("boom", { position = p.position, speed = 0.55, volume = 1, range = 700 })
	Effects.spray(p.position, 1.4)
	Effects.shakeAt(p.position, 1, 0.6, 260)
	if isMe(p) then
		Effects.punchFov(110)
		Hud.flash(Color3.fromRGB(255, 205, 40), 0.25)
	end
end

-- V9: tornadoes forming, and throwing a goblin.
function handlers.TwisterBorn(p)
	if typeof(p.position) == "Vector3" then
		Effects.sound("boom", { position = p.position, speed = 0.35, volume = 0.8, range = 1600 })
	end
end

function handlers.TwisterThrow(p)
	if typeof(p.position) == "Vector3" then
		Effects.sound("whoosh", { position = p.position, speed = 0.7, volume = 1, range = 500 })
		Effects.spray(p.position, 1)
	end
end

-- V13.1: knocked out (server/Knockout.lua): the screen dims and counts down; then up again.
function handlers.KnockedOut(p)
	Hud.knockout(p.seconds, p.cause)
	Effects.punchFov(60)
	-- Flat on its back (a goblin at the wheel just slumps there). Its own client owns the body, so it lays it down.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and not humanoid.SeatPart then
		humanoid.PlatformStand = true
		local _, yaw = root.CFrame:ToEulerAnglesYXZ()
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-80), 0, 0)
	end
	stopRide(false)
	stopPull(false)
	momentum = Momentum.new()
end

function handlers.WokeUp()
	Hud.knockout(nil)
end

function handlers.RecallParked()
	Effects.chime(Effects.CHIME_GOOD, 0.6)
end

-- V13.2: chains between boats (an Anchorjack's anchor, a Corsair's hook), drawn on every client until they let go.
local chainBeams = {}
function handlers.BoatChain(p)
	local a = typeof(p.a) == "Instance" and p.a or nil
	if not a then
		return
	end
	local b = typeof(p.b) == "Instance" and p.b or nil
	local to = b and b.Position or p.point
	if typeof(to) ~= "Vector3" then
		return
	end
	local duration = math.max(0.5, (p.untilAt or now()) - now() + 0.5)
	local color = p.kind == "reel" and Color3.fromRGB(230, 120, 100) or CHAIN_COLOR
	chainBeams[p.id] = Effects.rope(a, to, color, duration, b, Vector3.new(0, b and b.Size.Y / 2 or 0, 0))
	if b then
		Effects.sound("thud", { position = to, speed = 0.8, volume = 0.9, range = 400 })
	end
end
function handlers.BoatChainEnd(p)
	local beam = chainBeams[p.id]
	chainBeams[p.id] = nil
	if beam and beam.Parent then
		beam:Destroy()
	end
	if p.why == "nitro" or p.why == "phantom" or p.why == "snapped" then
		Effects.sound("blip", { speed = 0.6, volume = 0.6 })
	end
end
function handlers.BoatTether(p)
	BoatDrive.tether(p)
	if p.tether and p.tether.kind == "towed" then
		Effects.shake(0.5, 0.3)
	end
end
-- V13.2: a Wavebreaker's ring of water.
function handlers.BoatWave(p)
	if typeof(p.position) ~= "Vector3" then
		return
	end
	local at = Vector3.new(p.position.X, 1, p.position.Z)
	Effects.ring(at, Color3.fromRGB(235, 250, 255), p.radius or 110, 0.8)
	Effects.ring(at, Color3.fromRGB(140, 220, 255), (p.radius or 110) * 0.7, 0.6)
	Effects.spray(at, 1.8)
	Effects.shakeAt(at, 0.9, 0.5, 220)
	Effects.sound("thud", { position = at, speed = 0.4, volume = 1, range = 600 })
end
-- V13.2: a Corsair's boarding.
function handlers.Boarded(p)
	if typeof(p.position) ~= "Vector3" then
		return
	end
	Effects.burst(p.position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 110, 100), 60, 40)
	Effects.sound("thud", { position = p.position, speed = 0.6, volume = 1, range = 500 })
	Effects.shakeAt(p.position, 1.1, 0.5, 120)
	if p.userId == player.UserId then
		Hud.banner("BOARDED!", Color3.fromRGB(255, 120, 110), 1.6, 2)
	end
end

function handlers.BoatPush(p)
	BoatDrive.push(p)
end

function handlers.AbilityRefused(p)
	BoatDrive.abilityRefused()
	if p.text then
		Hud.toast(p.text)
	end
end

function handlers.BoatImpact(p)
	Effects.spray(p.position, p.power or 0.3)
end

function handlers.BoatSunk(p)
	Effects.spray(p.position, 1)
	Effects.sound("boom", { position = p.position, speed = 0.7, volume = 1, range = 500 })
end

function handlers.BoatBoost(p)
	Effects.burst(p.position, Color3.fromRGB(255, 200, 120), 30, 30)
	Effects.sound("whoosh", { position = p.position, speed = 1.2, volume = 0.9, range = 300 })
	if isMe(p) then
		Effects.punchFov(94)
	end
end

function handlers.Quake(p)
	Effects.shakeAt(p.position, 1.8, 2.2, 600)
	Effects.sound("boom", { position = p.position, speed = 0.4, volume = 1, range = 900 })
end

function handlers.Rumble(p)
	Effects.shakeAt(p.position, 0.7, 0.8, 300)
	Effects.sound("boom", { position = p.position, speed = 0.45, volume = 0.8, range = 700 })
end

function handlers.Flood(p)
	Effects.sound("splash", { position = p.position, speed = 0.5, volume = 1, range = 300 })
	Effects.shakeAt(p.position, 0.8, 1, 120)
end

-- Something a sea creature did (server/Pursuit.lua, SeaMobs.lua): { sound, pitch, volume, colour, spray }.
local SEA_FX = {
	launch = { "splash", 0.7, 1, Color3.fromRGB(220, 240, 255), 1.2 },
	splash = { "splash", 1, 0.9, Color3.fromRGB(220, 240, 255), 0.9 },
	crash = { "thud", 0.6, 1, Color3.fromRGB(235, 228, 210), 1.3 },
	erupt = { "boom", 1.4, 0.9, Color3.fromRGB(220, 240, 255), 1.7 },
	bleat = { "rise", 1.6, 1, Color3.fromRGB(235, 228, 210) },
	shriek = { "rise", 2.4, 1, Color3.fromRGB(96, 190, 84) },
	snatch = { "blip", 2.9, 1, Color3.fromRGB(96, 190, 84), 0.5 },
	zap = { "blip", 3.2, 1, Color3.fromRGB(120, 235, 255), 0.6 },
	clap = { "thud", 1.6, 0.9, Color3.fromRGB(255, 170, 190), 0.5 },
	chime = { "blip", 0.7, 0.9, Color3.fromRGB(215, 120, 255) },
	shatter = { "blip", 2.6, 1, Color3.fromRGB(215, 120, 255), 0.8 },
	eye = { "rise", 0.5, 1, Color3.fromRGB(255, 80, 60) },
	chill = { "blip", 0.5, 0.9, Color3.fromRGB(190, 235, 255) },
	yelp = { "rise", 2, 1, Color3.fromRGB(255, 240, 200), 0.8 },
	nibble = { "blip", 3.4, 0.9, Color3.fromRGB(170, 200, 215), 0.5 },
	boing = { "rise", 1.2, 1, Color3.fromRGB(255, 205, 90), 1.4 },
	lance = { "whoosh", 1.5, 1, Color3.fromRGB(110, 170, 230), 0.7 },
	-- V9
	stone = { "thud", 0.5, 1, Color3.fromRGB(190, 180, 160), 0.5 },
	dart = { "whoosh", 2.2, 0.8, Color3.fromRGB(230, 160, 255), 0.4 },
	gfist = { "rise", 0.45, 1, Color3.fromRGB(255, 205, 40) },
	quit = { "splash", 0.6, 1, Color3.fromRGB(255, 215, 90), 1 },
	roar = { "boom", 0.3, 1, Color3.fromRGB(150, 90, 220) },
	spout = { "splash", 1.4, 0.7, Color3.fromRGB(220, 240, 255), 0.6 },
	yarr = { "rise", 0.8, 1, Color3.fromRGB(110, 255, 210) },
	cannon = { "boom", 1.1, 0.9, Color3.fromRGB(110, 255, 210) },
	croak = { "thud", 1.9, 1, Color3.fromRGB(52, 178, 116), 0.6 }, -- V13.1: the jade frogs
}

function handlers.SeaFx(p)
	local fx = SEA_FX[p.kind]
	if not fx or typeof(p.position) ~= "Vector3" then
		return
	end
	Effects.sound(fx[1], { position = p.position, speed = fx[2], volume = fx[3], range = 420 })
	Effects.burst(p.position + Vector3.new(0, 2, 0), fx[4], 20, 24)
	if fx[5] then
		Effects.spray(p.position, fx[5])
		Effects.ring(p.position + Vector3.new(0, 1, 0), fx[4], 12 + fx[5] * 10, 0.6)
	end
	if p.kind == "erupt" or p.kind == "crash" or p.kind == "boing" then
		Effects.shakeAt(p.position, 0.6, 0.4, 90)
	end
end

-- The world hit a carrier once (Loot.knockLoose): the treasure is still theirs, for now.
function handlers.GripSlip(_p)
	Hud.flash(Color3.fromRGB(255, 205, 50), 0.35)
	Effects.sound("blip", { speed = 0.6, volume = 0.9 })
end

function handlers.Burn()
	Hud.flash(Color3.fromRGB(255, 110, 40), 0.4)
	Effects.sound("ouch", { volume = 0.9 })
end

function handlers.RaidStart()
	Results.hide()
	NextUp.hide() -- V13.3
	if player:GetAttribute("InRaid") then
		Hud.banner("RAID START! STEAL LOOT, BRING IT HOME", GOLD, 4, 3)
		Effects.chime(Effects.CHIME_GOOD, 0.9)
	end
end

function handlers.RaidEnd(p)
	-- V13: everyone in the raid is home in the Port by now (the winners on the podium); the results card says how it
	-- went to everyone, the Port's watchers too.
	Results.show(p.results or {}, p.winners or {})
	Hud.banner("RAID OVER! HOME TO THE PORT", GOLD, 3, 3)
	Effects.chime({ 2, 1.5, 1.26, 1, 1.5, 2 }, 0.8)
end

function handlers.LastCall(p)
	Hud.banner(string.format("LAST CALL! %d SECONDS - BANK IT OR LOSE IT", p.seconds or 60), DANGER, 3.5, 3)
	Effects.chime(Effects.CHIME_ALARM, 0.9)
end

eventRemote.OnClientEvent:Connect(function(kind, payload)
	local handler = handlers[kind]
	if handler then
		handler(payload or {})
	end
end)

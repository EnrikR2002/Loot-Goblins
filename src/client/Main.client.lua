-- Loot Goblins client: input, the bits of movement the client owns (the
-- Poltergoblin dash, ziplines, launch pads, the grapple pull), and turning
-- server events into HUD messages and effects. The server decides everything
-- that matters, including sprint speed and stamina.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local Weather = require(script.Parent.Weather)
local BoatDrive = require(script.Parent.BoatDrive)
local Skyship = require(script.Parent.Skyship)
local Shop = require(script.Parent.Shop)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local throwRemote = remotes:WaitForChild("ThrowRequest")
local grappleRemote = remotes:WaitForChild("GrappleRequest")
local polterRemote = remotes:WaitForChild("PoltergoblinRequest")
local sprintRemote = remotes:WaitForChild("SprintRequest")
local moveRemote = remotes:WaitForChild("MoveRequest")
local boatBoardRemote = remotes:WaitForChild("BoatBoardRequest")
local cannonRemote = remotes:WaitForChild("CannonRequest")
local kegRemote = remotes:WaitForChild("KegRequest")
local recallRemote = remotes:WaitForChild("BoatRecallRequest")
local stealRemote = remotes:WaitForChild("StealRequest")
local eventRemote = remotes:WaitForChild("GameEvent")

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

-- Storm warnings: name the heading so the player can steer around it.
local COMPASS_NAMES = { "NORTH", "NORTH-EAST", "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST" }
Weather.init(function(dx, dz, distance)
	local degrees = math.deg(math.atan2(dx, -dz)) % 360
	local name = COMPASS_NAMES[math.floor((degrees + 22.5) / 45) % 8 + 1]
	Hud.banner(
		string.format("STORM TO THE %s - %d STUDS. SAIL AROUND IT!", name, distance),
		Color3.fromRGB(170, 190, 255),
		3.5
	)
end)
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

-- Roblox only SHOWS a prompt whose object is on screen. So a goblin standing beside the treasure with the
-- camera turned away saw no prompt, and E (shared with Poltergoblin) sent their spirit flying instead of
-- stealing: "I pressed E and it did the wrong thing". V8: if no prompt is showing, E goes to the nearest
-- enabled E-prompt the goblin is in reach of, held and released exactly as if it were on screen.
local heldPrompt = nil
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
	for _, instance in ipairs(generated:GetDescendants()) do
		if instance:IsA("ProximityPrompt") then
			consider(instance)
		end
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
-- F sends where you aim. The server picks: steal loot near your aim, or hook the
-- first solid thing and pull you to it. The pull runs here, because each client
-- moves its own character (like ziplines and launch pads).
local pull = nil
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = false

local function aimPoint()
	local camera = workspace.CurrentCamera
	local mouseAt = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseAt.X, mouseAt.Y)
	-- Never aim at yourself or at the boat you are sitting in.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	aimParams.FilterDescendantsInstances = { player.Character, seat and seat.Parent }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, aimParams)
	if hit then
		return hit.Position, hit.Instance
	end
	return ray.Origin + ray.Direction * 1000, nil
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
	local _, _, root = getCharacter()
	if not root or not pop then
		return
	end
	local v = root.AssemblyLinearVelocity
	if current.part and current.part.Parent then
		-- Hooked something that moves: let go at its speed, not ours, so it does not sail out
		-- from under us.
		local carry = current.part.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(carry.X, 8, carry.Z)
		return
	end
	-- A hop at the end, so a hook on a ledge lifts you over its lip. You keep most of the
	-- swing, so a pull flows straight into a run, a jump or a dash.
	local keep = Config.GRAPPLE_KEEP_SPEED
	root.AssemblyLinearVelocity = Vector3.new(v.X * keep, Config.GRAPPLE_POP_SPEED, v.Z * keep)
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

-- to, normal: the hook point. part, offset: set when the hook is on something that moves.
local function startPull(to, normal, part, offset, tries)
	local _, humanoid, root = getCharacter()
	if not root then
		return
	end
	if humanoid.SeatPart then
		-- Hooked from a boat seat: the server lets go of the seat; wait for that to arrive.
		humanoid.Sit = false
		if (tries or 0) < 8 then
			task.delay(0.05, startPull, to, normal, part, offset, (tries or 0) + 1)
		end
		return
	end
	stopRide(false)
	stopPull(false)
	-- Aim a little off the surface: a floor lands you on it, a wall leaves you at it.
	local current = { part = part, offset = offset, goal = to + normal * 2 + Vector3.new(0, 2.5, 0) }
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
	current.rope = Effects.rope(root, to, ROPE_COLOR, 5, part, offset)
	current.startedAt = t
	current.endsAt = t + distance / Config.GRAPPLE_PULL_SPEED + 0.6
	current.best = distance
	current.bestAt = t
	pull = current
	airJumpUsed = false
	Effects.sound("whoosh", { speed = 1.5, volume = 0.6 })
	Effects.punchFov(84)
end

RunService.Heartbeat:Connect(function()
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
	if distance < 3 or t > pull.endsAt then
		if pull.boat and distance < 12 then
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
end)

UserInputService.JumpRequest:Connect(function()
	-- Jump lets go of the rope mid-pull and keeps your swing.
	if pull and os.clock() - pull.startedAt > 0.15 then
		stopPull(false)
	end
end)

local function pressGrapple()
	local _, _, root = getCharacter()
	if not root then
		return
	end
	if now() < (player:GetAttribute("GrappleReadyAt") or 0) then
		Hud.toast("Grapple is recharging")
		return
	end
	local hitPosition, target = aimPoint()
	grappleRemote:FireServer(hitPosition, target)
	Effects.sound("whoosh", { speed = 2.2, volume = 0.35 })
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

-- In a boat's driver seat, Shift boosts the boat instead of sprinting.
local function seatedInBoat()
	local _, humanoid = getCharacter()
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsA("VehicleSeat")
end

-- Sprint ------------------------------------------------------------------------------
-- Hold Shift (or click the left stick to toggle). The server owns speed and stamina.
local sprintHeld = false
local function setSprint(held)
	if held ~= sprintHeld then
		sprintHeld = held
		sprintRemote:FireServer(held)
	end
end

UserInputService.WindowFocusReleased:Connect(function()
	setSprint(false)
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E and heldPrompt then
		if heldPrompt.Parent then
			heldPrompt:InputHoldEnd()
		end
		heldPrompt = nil
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(false)
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		BoatDrive.setDrift(false)
	end
end)
player:GetAttributeChangedSignal("Winded"):Connect(function()
	if player:GetAttribute("Winded") then
		Hud.toast("Out of breath! You still run - sprint comes back when stamina refills.")
	end
end)

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
			-- Leave the dash a little faster than a run, so it flows into the next move.
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = direction * humanoid.WalkSpeed * 1.15 + Vector3.new(0, v.Y, 0)
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

-- Input ------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if seatedInBoat() then
			BoatDrive.boost()
		else
			setSprint(true)
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
		-- Leave the boat. (Space is the boat's hop now, so it no longer climbs out.)
		local _, humanoid = getCharacter()
		if humanoid and humanoid.SeatPart then
			humanoid.Sit = false
			humanoid.Jump = true
		end
	elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadDown then
		recallRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		pressKeg()
	elseif input.KeyCode == Enum.KeyCode.M then
		Hud.toggleMap()
	elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
		setSprint(not sprintHeld)
	elseif input.KeyCode == Enum.KeyCode.Q then
		if player:GetAttribute("CarryingLoot") then
			throwRemote:FireServer()
		else
			Hud.toast("Nothing to throw. Grab some loot first.")
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		pressGrapple()
	elseif input.KeyCode == Enum.KeyCode.E then
		-- V8: E belongs to whatever is IN REACH, not only to what the camera happens to show (see reachPrompt).
		local prompt = not promptOwnsE() and reachPrompt() or nil
		if prompt then
			heldPrompt = prompt
			prompt:InputHoldBegin()
		else
			pressPoltergoblin()
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		Hud.toggleHelp()
	elseif input.KeyCode == Enum.KeyCode.T then
		Hud.toggleBoard()
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
	Effects.explosion(p.position, p.radius, p.silent)
	Effects.shakeAt(p.position, 1, 0.35, 60)
end

function handlers.CaveIn(p)
	Effects.shakeAt(p.position, 1.5, 1.2, 160)
	Effects.sound("boom", { position = p.position, speed = 0.5, volume = 1 })
end

function handlers.GrappleFX(p)
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
		Hud.banner("STOMP! BE IN THE AIR WHEN THE RING REACHES YOU", DANGER, 1.6)
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
		Hud.banner("RAMMING SPEED! TURN HARD OR DRIFT OUT OF ITS WAY", DANGER, 2.2)
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

local function boatFx(kind, position, mine)
	if kind == "mini1" or kind == "mini2" then
		local strong = kind == "mini2"
		Effects.burst(position, MINI_COLORS[kind], strong and 60 or 35, strong and 40 or 28)
		Effects.ring(position, MINI_COLORS[kind], strong and 22 or 14, 0.4)
		Effects.sound("rise", { position = position, speed = strong and 1.5 or 1.9, volume = 0.8, range = 300 })
		if mine then
			Effects.punchFov(strong and 96 or 90)
		end
	elseif kind == "landing" then
		Effects.spray(position, 0.5)
		Effects.ring(position, Color3.fromRGB(190, 255, 220), 16, 0.4)
		if mine then
			Effects.punchFov(88)
			Hud.toast("Clean landing! Speed burst.")
		end
	elseif kind == "splash" then
		Effects.spray(position, 0.35)
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

BoatDrive.onEvent(function(kind, position, chain)
	boatFx(kind, position, true)
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
	end
end

function handlers.BoatFx(p)
	if not isMe(p) then
		boatFx(p.kind, p.position, false)
	end
end

function handlers.BoatPush(p)
	BoatDrive.push(p)
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

function handlers.Burn()
	Hud.flash(Color3.fromRGB(255, 110, 40), 0.4)
	Effects.sound("ouch", { volume = 0.9 })
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local sharedFolder = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(sharedFolder:WaitForChild("Config"))

-- Remotes --------------------------------------------------------------------
local oldRemotes = ReplicatedStorage:FindFirstChild("LootGoblinsRemotes")
if oldRemotes then
	oldRemotes:Destroy()
end

local remotes = Instance.new("Folder")
remotes.Name = "LootGoblinsRemotes"
remotes.Parent = ReplicatedStorage

local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "DropRequest"
dropRemote.Parent = remotes

local grappleRemote = Instance.new("RemoteEvent")
grappleRemote.Name = "GrappleRequest"
grappleRemote.Parent = remotes

local gameEvent = Instance.new("RemoteEvent")
gameEvent.Name = "GameEvent"
gameEvent.Parent = remotes

-- Helpers --------------------------------------------------------------------
local generated = workspace:FindFirstChild("LootGoblinsGenerated")
if generated then
	generated:Destroy()
end

generated = Instance.new("Folder")
generated.Name = "LootGoblinsGenerated"
generated.Parent = workspace

local function part(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or generated
	return p
end

local function broadcast(kind, payload)
	gameEvent:FireAllClients(kind, payload)
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	return character, humanoid, root
end

-- World ----------------------------------------------------------------------
local water =
	part("Water", Vector3.new(900, 2, 900), CFrame.new(0, 2, -140), Color3.fromRGB(48, 148, 196), Enum.Material.Glass)
water.Transparency = 0.28
water.CanCollide = true

-- Preserve the prototype's named world references without global lint exemptions.
-- selene: allow(unused_variable)
local homeIsland = part(
	"HomeIsland",
	Vector3.new(115, 12, 115),
	CFrame.new(Config.HOME_CENTER),
	Color3.fromRGB(73, 173, 87),
	Enum.Material.Grass
)
-- selene: allow(unused_variable)
local treasureIsland = part(
	"TreasureIsland",
	Vector3.new(125, 12, 125),
	CFrame.new(Config.TREASURE_CENTER),
	Color3.fromRGB(84, 166, 94),
	Enum.Material.Grass
)

-- Docks
part("HomeDock", Vector3.new(24, 2, 65), CFrame.new(0, 8, -70), Color3.fromRGB(110, 75, 45), Enum.Material.WoodPlanks)
part(
	"TreasureDock",
	Vector3.new(24, 2, 65),
	CFrame.new(0, 8, -230),
	Color3.fromRGB(110, 75, 45),
	Enum.Material.WoodPlanks
)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "HomeSpawn"
spawn.Size = Vector3.new(14, 1, 14)
spawn.CFrame = CFrame.new(0, 14.5, 18)
spawn.Anchored = true
spawn.Neutral = true
spawn.Color = Color3.fromRGB(220, 220, 220)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Parent = generated

local bankPad =
	part("BANK", Vector3.new(26, 1, 26), CFrame.new(0, 14.5, -12), Color3.fromRGB(84, 255, 125), Enum.Material.Neon)
bankPad.Transparency = 0.18

-- selene: allow(unused_variable)
local altar = part(
	"IdolAltar",
	Vector3.new(14, 5, 14),
	CFrame.new(0, 12.5, -300),
	Color3.fromRGB(60, 60, 68),
	Enum.Material.Slate
)

-- Boat -----------------------------------------------------------------------
local boat = Instance.new("Model")
boat.Name = "ShittyBoat"
boat.Parent = generated

local hull =
	part("Hull", Vector3.new(18, 3, 30), Config.BOAT_START, Color3.fromRGB(102, 67, 42), Enum.Material.WoodPlanks, boat)
boat.PrimaryPart = hull

local driver = Instance.new("VehicleSeat")
driver.Name = "Driver"
driver.Size = Vector3.new(4, 1, 4)
driver.CFrame = Config.BOAT_START * CFrame.new(0, 2.2, 6)
driver.Anchored = true
driver.MaxSpeed = Config.BOAT_SPEED
driver.Parent = boat

for i, x in ipairs({ -4.8, 4.8 }) do
	local seat = Instance.new("Seat")
	seat.Name = "Passenger" .. i
	seat.Size = Vector3.new(4, 1, 4)
	seat.CFrame = Config.BOAT_START * CFrame.new(x, 2.2, -3)
	seat.Anchored = true
	seat.Parent = boat
end

-- selene: allow(unused_variable)
local mast = part(
	"Mast",
	Vector3.new(1, 12, 1),
	Config.BOAT_START * CFrame.new(0, 7, 0),
	Color3.fromRGB(90, 58, 35),
	Enum.Material.Wood,
	boat
)
-- selene: allow(unused_variable)
local flag = part(
	"Flag",
	Vector3.new(7, 4, 0.4),
	Config.BOAT_START * CFrame.new(3.5, 10, 0),
	Color3.fromRGB(255, 210, 75),
	Enum.Material.Fabric,
	boat
)

local boatCF = Config.BOAT_START

-- Idol -----------------------------------------------------------------------
local idol = Instance.new("Part")
idol.Name = "GoldenIdol"
idol.Shape = Enum.PartType.Ball
idol.Size = Vector3.new(5, 5, 5)
idol.CFrame = Config.IDOL_SPAWN
idol.Color = Color3.fromRGB(255, 200, 35)
idol.Material = Enum.Material.Metal
idol.Anchored = true
idol.CanCollide = true
idol.Parent = generated

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "GrabPrompt"
prompt.ActionText = "STEAL / GRAB"
prompt.ObjectText = "Golden Idol"
prompt.HoldDuration = 0.05
prompt.MaxActivationDistance = Config.PICKUP_DISTANCE
prompt.RequiresLineOfSight = false
prompt.Parent = idol

local carrier = nil
local carryWeld = nil
local roundActive = false
local resetting = false
local lastGrapple = {}

local function restoreSpeed(player)
	local _, humanoid = getCharacterParts(player)
	if humanoid then
		humanoid.WalkSpeed = Config.NORMAL_WALK_SPEED
	end
end

local function detachIdol(dropCFrame)
	if carryWeld then
		carryWeld:Destroy()
		carryWeld = nil
	end
	if carrier then
		restoreSpeed(carrier)
	end
	carrier = nil
	idol.Massless = false
	idol.CanCollide = true
	idol.Anchored = false
	if dropCFrame then
		idol.CFrame = dropCFrame
	end
	prompt.Enabled = true
	broadcast("Carrier", {})
end

local function attachIdol(player)
	if resetting then
		return false
	end
	local _, humanoid, root = getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return false
	end

	if carrier == player then
		return true
	end
	if carrier then
		restoreSpeed(carrier)
	end
	if carryWeld then
		carryWeld:Destroy()
	end

	carrier = player
	idol.Anchored = false
	idol.CanCollide = false
	idol.Massless = true
	idol.CFrame = root.CFrame * CFrame.new(0, 0.2, -3.4)

	carryWeld = Instance.new("WeldConstraint")
	carryWeld.Name = "CarryWeld"
	carryWeld.Part0 = root
	carryWeld.Part1 = idol
	carryWeld.Parent = idol

	humanoid.WalkSpeed = Config.CARRY_WALK_SPEED
	prompt.Enabled = false

	if not roundActive then
		roundActive = true
		broadcast("Message", { text = "THE GUARDIAN WOKE UP — GET HOME!", duration = 2.5 })
	end
	broadcast("Carrier", { userId = player.UserId, name = player.DisplayName })
	return true
end

prompt.Triggered:Connect(function(player)
	if carrier or resetting then
		return
	end
	local _, _, root = getCharacterParts(player)
	if not root then
		return
	end
	if (root.Position - idol.Position).Magnitude > Config.PICKUP_DISTANCE + 3 then
		return
	end
	attachIdol(player)
end)

dropRemote.OnServerEvent:Connect(function(player)
	if player ~= carrier or resetting then
		return
	end
	local _, _, root = getCharacterParts(player)
	local cf = root and (root.CFrame * CFrame.new(0, 0, -5)) or idol.CFrame
	detachIdol(cf)
end)

grappleRemote.OnServerEvent:Connect(function(player, hitPosition, target)
	if resetting then
		return
	end
	if typeof(hitPosition) ~= "Vector3" then
		return
	end
	local _, _, root = getCharacterParts(player)
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastGrapple[player] or 0) < Config.GRAPPLE_COOLDOWN then
		return
	end
	lastGrapple[player] = now

	local aim = hitPosition - root.Position
	if aim.Magnitude > Config.GRAPPLE_RANGE then
		hitPosition = root.Position + aim.Unit * Config.GRAPPLE_RANGE
	end

	local targetPos = hitPosition
	local successfulSteal = false

	-- Clicking the idol or the current carrier transfers possession.
	if target == idol then
		if (root.Position - idol.Position).Magnitude <= Config.GRAPPLE_RANGE then
			targetPos = idol.Position
			successfulSteal = attachIdol(player)
		end
	elseif target and target:IsA("BasePart") then
		local model = target:FindFirstAncestorOfClass("Model")
		local targetPlayer = model and Players:GetPlayerFromCharacter(model)
		if targetPlayer and targetPlayer == carrier and targetPlayer ~= player then
			local _, _, targetRoot = getCharacterParts(targetPlayer)
			if targetRoot and (root.Position - targetRoot.Position).Magnitude <= Config.GRAPPLE_RANGE then
				targetPos = targetRoot.Position
				successfulSteal = attachIdol(player)
			end
		end
	end

	broadcast("GrappleFX", { from = root.Position + Vector3.new(0, 1.5, 0), to = targetPos })
	if successfulSteal then
		broadcast("Message", { text = player.DisplayName .. " GRAPPLED THE IDOL!", duration = 1.4 })
	end
end)

-- Guardian -------------------------------------------------------------------
local guardian = Instance.new("Model")
guardian.Name = "GiantGuardian"
guardian.Parent = generated

local gRoot = Instance.new("Part")
gRoot.Name = "HumanoidRootPart"
gRoot.Size = Vector3.new(5, 7, 4)
gRoot.CFrame = Config.GUARDIAN_SPAWN
gRoot.Color = Color3.fromRGB(145, 52, 55)
gRoot.Material = Enum.Material.Slate
gRoot.Anchored = false
gRoot.Parent = guardian

guardian.PrimaryPart = gRoot

local gHead = Instance.new("Part")
gHead.Name = "Head"
gHead.Size = Vector3.new(5, 5, 5)
gHead.CFrame = Config.GUARDIAN_SPAWN * CFrame.new(0, 6, 0)
gHead.Color = Color3.fromRGB(180, 68, 55)
gHead.Material = Enum.Material.Slate
gHead.Anchored = false
gHead.Parent = guardian

local gWeld = Instance.new("WeldConstraint")
gWeld.Part0 = gRoot
gWeld.Part1 = gHead
gWeld.Parent = gHead

local gHum = Instance.new("Humanoid")
gHum.Name = "Humanoid"
gHum.WalkSpeed = Config.GUARDIAN_WALK_SPEED
gHum.MaxHealth = 500
gHum.Health = 500
gHum.Parent = guardian

pcall(function()
	gRoot:SetNetworkOwner(nil)
end)
local lastGuardianHit = 0

local function resetGuardian()
	gHum.Health = gHum.MaxHealth
	guardian:PivotTo(Config.GUARDIAN_SPAWN)
	gRoot.AssemblyLinearVelocity = Vector3.zero
	gRoot.AssemblyAngularVelocity = Vector3.zero
end

-- Sword ----------------------------------------------------------------------
-- A pedestal on the home island hands each player one Sword tool. Click swings it.
-- The server finds the targets, so the client never says who got hit.
local GUARD_OFFSET = CFrame.new(0, 0, -1)
local lastSwing = {}

local function makeSwordParts(parent)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 4.5)
	handle.Color = Color3.fromRGB(205, 210, 220)
	handle.Material = Enum.Material.Metal
	handle.Parent = parent

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(2, 0.5, 0.5)
	guard.Color = Color3.fromRGB(255, 200, 35)
	guard.Material = Enum.Material.Metal
	guard.Parent = parent
	return handle, guard
end

local function swingSword(player, tool)
	local _, humanoid, root = getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if now - (lastSwing[player] or 0) < Config.SWORD_COOLDOWN then
		return
	end
	lastSwing[player] = now

	-- Roblox's default animate script plays a slash when it sees this value.
	local slash = Instance.new("StringValue")
	slash.Name = "toolanim"
	slash.Value = "Slash"
	slash.Parent = tool
	Debris:AddItem(slash, 1)

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	for _, other in ipairs(Players:GetPlayers()) do
		local _, otherHumanoid, otherRoot = getCharacterParts(other)
		if other ~= player and otherRoot and otherHumanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if
				offset.Magnitude <= Config.SWORD_RANGE
				and flat.Magnitude > 0.01
				and flat.Unit:Dot(look) >= Config.SWORD_MIN_DOT
			then
				otherHumanoid:TakeDamage(Config.SWORD_DAMAGE)
				otherRoot.AssemblyLinearVelocity += flat.Unit * Config.SWORD_KNOCKBACK + Vector3.new(0, 15, 0)
			end
		end
	end
end

local function newSwordTool()
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.ToolTip = "Click to swing"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- Same grip as Roblox's classic sword: the blade points forward from the fist.
	tool.GripPos = Vector3.new(0, 0, -1.5)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	local handle, guard = makeSwordParts(tool)
	handle.CanCollide = false
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = handle.CFrame * GUARD_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = guard
	weld.Parent = guard

	tool.Activated:Connect(function()
		local owner = Players:GetPlayerFromCharacter(tool.Parent)
		if owner then
			swingSword(owner, tool)
		end
	end)
	return tool
end

local swordPedestal =
	part("SwordPedestal", Vector3.new(5, 2, 5), Config.SWORD_PEDESTAL, Color3.fromRGB(60, 60, 68), Enum.Material.Slate)

-- The display sword is just for show; the real one is built per player in newSwordTool.
local swordDisplay = Instance.new("Model")
swordDisplay.Name = "SwordPickup"
swordDisplay.Parent = generated
local displayHandle, displayGuard = makeSwordParts(swordDisplay)
displayHandle.Anchored = true
displayHandle.CanCollide = false
displayHandle.CFrame = swordPedestal.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
displayGuard.Anchored = true
displayGuard.CanCollide = false
displayGuard.CFrame = displayHandle.CFrame * GUARD_OFFSET

local swordPrompt = Instance.new("ProximityPrompt")
swordPrompt.Name = "GrabPrompt"
swordPrompt.ActionText = "GRAB"
swordPrompt.ObjectText = "Sword"
swordPrompt.HoldDuration = 0.05
swordPrompt.MaxActivationDistance = Config.PICKUP_DISTANCE
swordPrompt.RequiresLineOfSight = false
swordPrompt.Parent = displayHandle

swordPrompt.Triggered:Connect(function(player)
	local character, humanoid, root = getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return
	end
	if (root.Position - displayHandle.Position).Magnitude > Config.PICKUP_DISTANCE + 3 then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Sword") or character:FindFirstChild("Sword") then
		return
	end
	local tool = newSwordTool()
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end)

-- Stats ----------------------------------------------------------------------
local function setupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local banks = leaderstats:FindFirstChild("Banks") or Instance.new("IntValue")
	banks.Name = "Banks"
	banks.Parent = leaderstats

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = Config.NORMAL_WALK_SPEED
		humanoid.Died:Connect(function()
			if player == carrier then
				local root = character:FindFirstChild("HumanoidRootPart")
				detachIdol(root and root.CFrame or idol.CFrame)
			end
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastGrapple[player] = nil
	lastSwing[player] = nil
	if player == carrier then
		detachIdol(idol.CFrame)
	end
end)

-- Reset / banking -------------------------------------------------------------
local function teleportHome()
	local offsets = {
		Vector3.new(-8, 4, 20),
		Vector3.new(0, 4, 22),
		Vector3.new(8, 4, 20),
		Vector3.new(-4, 4, 28),
		Vector3.new(4, 4, 28),
	}
	for i, player in ipairs(Players:GetPlayers()) do
		local _, humanoid, root = getCharacterParts(player)
		if root and humanoid and humanoid.Health > 0 then
			root.CFrame = CFrame.new(Config.HOME_CENTER + offsets[((i - 1) % #offsets) + 1])
			humanoid.WalkSpeed = Config.NORMAL_WALK_SPEED
		end
	end
end

local function resetRound()
	resetting = true
	if carryWeld then
		carryWeld:Destroy()
		carryWeld = nil
	end
	if carrier then
		restoreSpeed(carrier)
	end
	carrier = nil
	roundActive = false
	idol.Anchored = true
	idol.CanCollide = true
	idol.Massless = false
	idol.CFrame = Config.IDOL_SPAWN
	prompt.Enabled = true
	boatCF = Config.BOAT_START
	boat:PivotTo(boatCF)
	resetGuardian()
	teleportHome()
	resetting = false
	broadcast("Message", { text = "NEW ROUND — STEAL THE IDOL", duration = 2 })
end

local function bank(player)
	if resetting or not roundActive or player ~= carrier then
		return
	end
	resetting = true
	local leaderstats = player:FindFirstChild("leaderstats")
	local banks = leaderstats and leaderstats:FindFirstChild("Banks")
	if banks then
		banks.Value += 1
	end
	broadcast("Banked", { name = player.DisplayName, userId = player.UserId })
	task.delay(Config.ROUND_RESET_DELAY, resetRound)
end

-- Main loop ------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	-- Kinematic prototype boat. Intentionally simple/ugly: we are testing the loop.
	local throttle = driver.ThrottleFloat
	local steer = driver.SteerFloat
	if driver.Occupant then
		local rotation = CFrame.Angles(0, -steer * Config.BOAT_TURN_RATE * dt, 0)
		boatCF = boatCF * rotation
		local forward = boatCF.LookVector
		local delta = forward * throttle * Config.BOAT_SPEED * dt
		boatCF = CFrame.new(boatCF.Position + Vector3.new(delta.X, 0, delta.Z)) * boatCF.Rotation
		boat:PivotTo(boatCF)
	end

	if resetting then
		return
	end

	-- Bank check follows the current carrier.
	if carrier then
		local _, _, root = getCharacterParts(carrier)
		if root and (root.Position - bankPad.Position).Magnitude <= Config.BANK_RADIUS then
			bank(carrier)
			return
		end
	end

	-- Guardian pressure follows possession. If loose, it moves toward the idol.
	if roundActive then
		local targetPos = idol.Position
		if carrier then
			local _, humanoid, root = getCharacterParts(carrier)
			if root and humanoid and humanoid.Health > 0 then
				targetPos = root.Position
			end
		end
		gHum:MoveTo(targetPos)

		if carrier and (gRoot.Position - targetPos).Magnitude <= Config.GUARDIAN_HIT_RANGE then
			local now = os.clock()
			if now - lastGuardianHit >= Config.GUARDIAN_HIT_COOLDOWN then
				lastGuardianHit = now
				local victim = carrier
				local _, humanoid, root = getCharacterParts(victim)
				if humanoid and root then
					humanoid:TakeDamage(Config.GUARDIAN_DAMAGE)
					local away = root.Position - gRoot.Position
					if away.Magnitude > 0.1 then
						root.AssemblyLinearVelocity += away.Unit * 42 + Vector3.new(0, 28, 0)
					end
					detachIdol(root.CFrame * CFrame.new(0, 0, -5))
					broadcast("Message", { text = "GUARDIAN SMACKED THE IDOL LOOSE!", duration = 1.6 })
				end
			end
		end
	end
end)

resetRound()

-- The skyship (V7): every raid starts on a flying pirate ship hung 540 studs over the middle of the
-- sea. Goblins stand on the deck, choose an island on the map, climb into a cannon (E), nudge the aim,
-- fire (Space) and are thrown into a dive: PENCIL (fast, head down) or GLIDE (Space held: a long
-- reach), steered with the keys. A dive ends in one of three ways:
--   * a soft landing (a glide, or a slow touch): a puff of dust and control back at once;
--   * the SEA: a big splash and a BOUNCE back up (once), so a bad aim over water is a second chance;
--   * the GROUND at pencil speed: the goblin goes in head first like an ostrich, wiggles for a
--     moment, and is spat back out with control returned.
-- The raid clock runs from the first second; the window is short (Config.SKYSHIP.WINDOW) and anyone
-- still aboard when it ends is fired off automatically, at the island they chose or a near one.
--
-- Who does what: the server places goblins, owns the cannons, decides where they were fired and
-- how every dive ended (it watches the goblin's root: the character's own client flies it, as
-- with a driven boat). The dive controller and the destination picker are the client's
-- (client/Skyship.lua). Late arrivals and deaths in the window start aboard; after it, at home.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Dive = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Dive"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Poltergoblin = require(script.Parent.Poltergoblin)

local Skyship = {}

local S = Config.SKYSHIP
local D = Config.DIVE

local model
local shipCFrame
local cannons = {}
local deckSpawns = {}
local state = {} -- player -> { phase, dest, cannon, yaw, pitch, bounces, fall, diveStart, token }
local opensAt, endsAt = 0, 0
local boardedFor = 0 -- a counter: a straggler is only auto-fired once per window

-- A goblin in a dive passes through the ship (it starts inside a cannon, and falls past a rail), but
-- not through anything else. Two collision groups do it: the ship's parts and a diver's body.
local HULL_GROUP, DIVER_GROUP = "SkyshipHull", "SkyDiver"
pcall(function()
	PhysicsService:RegisterCollisionGroup(HULL_GROUP)
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup(DIVER_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(DIVER_GROUP, HULL_GROUP, false)

local function setBodyGroup(character, group)
	if not character then
		return
	end
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = group
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function now()
	return workspace:GetServerTimeNow()
end

-- Building the ship -----------------------------------------------------------------------------
local WOOD = Color3.fromRGB(122, 84, 52)
local DARK_WOOD = Color3.fromRGB(78, 52, 34)
local SAIL = Color3.fromRGB(240, 232, 205)
local TRIM = Color3.fromRGB(255, 205, 50)

local function part(name, size, cf, color, material, collide, shape)
	local p = Instance.new(shape or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = shipCFrame * cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildCannon(index, x, z, outward)
	local base = part("CannonBase" .. index, Vector3.new(7, 2.4, 9), CFrame.new(x, 2.2, z), DARK_WOOD)
	local yaw = outward > 0 and math.rad(-90) or math.rad(90) -- the barrel's default heading: out over the side
	local baseCF = shipCFrame * CFrame.new(x, 4.6, z) * CFrame.Angles(0, yaw, 0)
	local barrel = Instance.new("Part")
	barrel.Name = "Cannon" .. index
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(11, 4.6, 4.6)
	barrel.Color = Color3.fromRGB(52, 54, 62)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CanTouch = false
	barrel.TopSurface = Enum.SurfaceType.Smooth
	barrel.BottomSurface = Enum.SurfaceType.Smooth
	-- The cylinder's axis is its X: aim X along the launch direction.
	local function aim(direction)
		local from = baseCF.Position
		barrel.CFrame = CFrame.lookAt(from, from + direction) * CFrame.Angles(0, math.rad(90), 0)
	end
	local out = (shipCFrame.RightVector * outward)
	local rest = (out + Vector3.new(0, 0.55, 0)).Unit
	aim(rest)
	barrel.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "CannonRing" .. index
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1, 5.4, 5.4)
	ring.Color = TRIM
	ring.Material = Enum.Material.Metal
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.Parent = model
	local function setRing()
		ring.CFrame = barrel.CFrame * CFrame.new(4.1, 0, 0)
	end
	setRing()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LoadPrompt"
	prompt.ObjectText = "Launch cannon"
	prompt.ActionText = "Climb in"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = barrel
	local cannon = {
		index = index,
		barrel = barrel,
		ring = ring,
		base = base,
		prompt = prompt,
		from = baseCF.Position,
		rest = rest,
		aim = aim,
		setRing = setRing,
		occupant = nil,
	}
	prompt.Triggered:Connect(function(player)
		Skyship.load(player, cannon)
	end)
	table.insert(cannons, cannon)
end

function Skyship.build(_worldRefs)
	local old = workspace:FindFirstChild("LootGoblinsGenerated")
	local landmarks = old and old:FindFirstChild("Landmarks") or workspace
	shipCFrame = CFrame.new(S.POSITION)
	model = Instance.new("Model")
	model.Name = "Skyship"

	-- The deck, bow and stern.
	part("Deck", Vector3.new(S.BEAM, 2, 118), CFrame.new(0, 0, 0), WOOD)
	part("BowDeck", Vector3.new(S.BEAM * 0.62, 2, 22), CFrame.new(0, 0, -70), WOOD)
	part("BowTip", Vector3.new(S.BEAM * 0.3, 2, 18), CFrame.new(0, 0, -89), WOOD)
	part("QuarterDeck", Vector3.new(S.BEAM, 2, 30), CFrame.new(0, 6, 72), WOOD)
	part("QuarterStep", Vector3.new(S.BEAM, 6, 2), CFrame.new(0, 3, 56), DARK_WOOD)
	part("QuarterRamp", Vector3.new(14, 2, 16), CFrame.new(0, 3, 50) * CFrame.Angles(math.rad(22), 0, 0), WOOD)
	part("SternWall", Vector3.new(S.BEAM + 2, 14, 2), CFrame.new(0, 13, 88), DARK_WOOD)
	-- The hull under it: shapes only, nothing to bump into, narrower than the deck so a goblin who
	-- hops the rail falls clear of it.
	part("Keel", Vector3.new(S.BEAM * 0.55, 14, 128), CFrame.new(0, -8, 4), DARK_WOOD, nil, false)
	part("KeelBow", Vector3.new(S.BEAM * 0.3, 10, 24), CFrame.new(0, -6, -76), DARK_WOOD, nil, false)
	part("HullBand", Vector3.new(S.BEAM * 0.8, 2, 124), CFrame.new(0, -1.2, 2), TRIM, Enum.Material.Metal, false)
	-- The rails: low walls along both sides with the cannons set into them.
	for _, side in ipairs({ -1, 1 }) do
		part("Rail", Vector3.new(1, 4, 116), CFrame.new(side * (S.BEAM / 2 - 0.5), 3, 0), DARK_WOOD)
		part(
			"RailBow",
			Vector3.new(1, 4, 26),
			CFrame.new(side * 7, 3, -76) * CFrame.Angles(0, side * math.rad(-24), 0),
			DARK_WOOD
		)
	end
	-- Three masts, their yards and sails; a figurehead.
	for i, z in ipairs({ -42, -4, 40 }) do
		local height = i == 2 and 96 or 78
		local mast = part(
			"Mast" .. i,
			Vector3.new(height, 3.2, 3.2),
			CFrame.new(0, 1 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			DARK_WOOD,
			nil,
			false,
			"Part"
		)
		mast.Shape = Enum.PartType.Cylinder
		local yard =
			part("Yard" .. i, Vector3.new(S.BEAM * 1.5, 1.8, 1.8), CFrame.new(0, height - 6, z), DARK_WOOD, nil, false)
		yard.Shape = Enum.PartType.Cylinder
		yard.CFrame = shipCFrame * CFrame.new(0, height - 6, z) * CFrame.Angles(0, 0, 0)
		local sail = part(
			"Sail" .. i,
			Vector3.new(S.BEAM * 1.3, height * 0.5, 0.8),
			CFrame.new(0, height * 0.52, z - 0.8),
			SAIL,
			Enum.Material.Fabric,
			false
		)
		sail.Transparency = 0.04
		local emblem = part(
			"Emblem" .. i,
			Vector3.new(0.9, 11, 11),
			CFrame.new(0, height * 0.52, z - 1.4),
			Color3.fromRGB(30, 30, 38),
			Enum.Material.Fabric,
			false
		)
		emblem.Shape = Enum.PartType.Cylinder
		emblem.CFrame = shipCFrame * CFrame.new(0, height * 0.52, z - 1.4) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- Wings and lift: two broad sails and a glowing belly, so it reads as a thing that flies.
	for _, side in ipairs({ -1, 1 }) do
		local wing = part(
			"Wing",
			Vector3.new(34, 1.2, 64),
			CFrame.new(side * (S.BEAM / 2 + 14), 2, 2) * CFrame.Angles(0, 0, side * math.rad(-14)),
			SAIL,
			Enum.Material.Fabric,
			false
		)
		wing.Transparency = 0.1
		part(
			"WingSpar",
			Vector3.new(36, 1.6, 2),
			CFrame.new(side * (S.BEAM / 2 + 14), 2.4, -28) * CFrame.Angles(0, 0, side * math.rad(-14)),
			TRIM,
			Enum.Material.Metal,
			false
		)
	end
	local glow = part(
		"Belly",
		Vector3.new(26, 4, 70),
		CFrame.new(0, -15.5, 4),
		Color3.fromRGB(120, 230, 255),
		Enum.Material.Neon,
		false
	)
	glow.Transparency = 0.25
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 26) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.Rate = 14
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = glow
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(150, 235, 255)
	lamp.Range = 40
	lamp.Brightness = 2
	lamp.Parent = glow

	-- Cannons: six a side, set into the rails.
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -50, -30, -10, 10, 30, 50 }) do
			index += 1
			buildCannon(index, side * (S.BEAM / 2 - 5), z, side)
		end
	end
	-- A sign, the way it is in a game: what this is.
	local sign = part("Sign", Vector3.new(26, 7, 1), CFrame.new(0, 12, 86), DARK_WOOD, Enum.Material.WoodPlanks, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "THE GOLDEN GOBLIN"
	label.TextColor3 = TRIM
	label.TextScaled = true
	label.Parent = gui

	-- Where goblins stand when they arrive: a loose grid on the main deck.
	for row = 0, 5 do
		for col = 0, 5 do
			table.insert(deckSpawns, shipCFrame * CFrame.new(-10 + col * 4, 4.4, -22 + row * 7))
		end
	end
	model.PrimaryPart = model:FindFirstChild("Deck")
	model.Parent = landmarks
	-- Everything on the ship is in the Landmarks folder, which streams as persistent, so it is in
	-- view from the first frame wherever the goblin is.
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
			p.CollisionGroup = HULL_GROUP
		end
	end
	for _, c in ipairs(cannons) do
		c.barrel.CastShadow = true
	end
end

-- Goblins ---------------------------------------------------------------------------------------
local function setState(player, phase)
	local s = state[player]
	if not s then
		s = { bounces = 0, fall = 0, token = 0 }
		state[player] = s
	end
	s.phase = phase
	player:SetAttribute("DeployState", phase)
	return s
end

local function release(player)
	local s = state[player]
	if s and s.cannon then
		local cannon = s.cannon
		cannon.occupant = nil
		cannon.aim(cannon.rest)
		cannon.setRing()
		cannon.prompt.Enabled = true
		s.cannon = nil
	end
end

local function endDive(player, humanoid, root)
	local s = state[player]
	if not s then
		return
	end
	s.token += 1
	setBodyGroup(player.Character, "Default")
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DiveGlide", nil)
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root and root.Parent then
		-- Back on its feet: upright, whichever way it was facing.
		local look = root.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 0.05 and flatLook.Unit or Vector3.new(0, 0, -1)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
	end
	setState(player, "landed")
end

-- Put a goblin on the deck.
function Skyship.board(player)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return
	end
	Poltergoblin.finish(player, "cancel")
	local seat = humanoid.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	release(player)
	setBodyGroup(player.Character, "Default")
	local i = (#Players:GetPlayers() > 0 and (player.UserId % #deckSpawns) or 0) + 1
	local spot = deckSpawns[i]
	-- Spread: find a spot nobody is standing on.
	for step = 0, #deckSpawns - 1 do
		local candidate = deckSpawns[(i + step - 1) % #deckSpawns + 1]
		local taken = false
		for other, other_state in pairs(state) do
			if other ~= player and other_state.phase == "aboard" and other_state.spot == candidate then
				taken = true
				break
			end
		end
		if not taken then
			spot = candidate
			break
		end
	end
	local s = setState(player, "aboard")
	s.spot = spot
	s.bounces = 0
	s.fall = 0
	root.Anchored = false
	humanoid.PlatformStand = false
	root.CFrame = spot * CFrame.Angles(0, math.rad(180), 0)
	root.AssemblyLinearVelocity = Vector3.zero
	player:SetAttribute("Diving", nil)
end

function Skyship.boardAll()
	for _, player in ipairs(Players:GetPlayers()) do
		Skyship.board(player)
	end
end

local function boardingTime()
	return workspace:GetAttribute("RaidPhase") == "intermission" or now() < endsAt
end

function Skyship.isDeploying()
	return now() < endsAt
end

-- A character just spawned (first load, or a respawn): aboard if the ship is still in port.
function Skyship.onCharacter(player)
	state[player] = nil
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DeployState", nil)
	if boardingTime() and model then
		task.defer(function()
			if player.Parent then
				Skyship.board(player)
			end
		end)
	end
end

function Skyship.forget(player)
	release(player)
	state[player] = nil
end

-- The raid clock has started: unlock the cannons and open the window.
function Skyship.open()
	local t = now()
	opensAt = t + S.COUNTDOWN
	endsAt = t + S.WINDOW
	workspace:SetAttribute("DeployOpensAt", opensAt)
	workspace:SetAttribute("DeployEndsAt", endsAt)
	boardedFor += 1
	Net.broadcast("DeployOpen", { opensAt = opensAt, endsAt = endsAt })
end

function Skyship.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		release(player)
		state[player] = nil
		setBodyGroup(player.Character, "Default")
		player:SetAttribute("Diving", nil)
		player:SetAttribute("DeployState", nil)
		local root, humanoid = Util.aliveRoot(player)
		if humanoid then
			humanoid.PlatformStand = false
		end
		if root then
			root.Anchored = false
		end
	end
	opensAt, endsAt = 0, 0
	workspace:SetAttribute("DeployOpensAt", nil)
	workspace:SetAttribute("DeployEndsAt", nil)
end

-- What the client may ask for ----------------------------------------------------------------------
local function destinationPosition(id)
	local island = Archipelago.byId[id]
	if not island then
		return nil
	end
	return Vector3.new(island.x, 0, island.z)
end

local function defaultDestination()
	local pool = {}
	for id, info in pairs(Config.ISLAND_INFO) do
		if info.major and info.tier <= 2 then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool[math.random(#pool)] or "Cross"
end

function Skyship.choose(player, id)
	if typeof(id) ~= "string" or not Config.ISLAND_INFO[id] or not Archipelago.byId[id] then
		return
	end
	local s = state[player] or setState(player, nil)
	s.dest = id
	player:SetAttribute("DeployDest", id)
end

function Skyship.load(player, cannon)
	local s = state[player]
	if not s or s.phase ~= "aboard" then
		return
	end
	local t = now()
	if t < opensAt then
		Net.toast(player, "The cannons unlock in " .. math.ceil(opensAt - t) .. "...")
		return
	end
	if cannon.occupant then
		return
	end
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return
	end
	if not s.dest then
		s.dest = player:GetAttribute("DeployDest") or defaultDestination()
		player:SetAttribute("DeployDest", s.dest)
		Net.toast(player, "No island chosen: " .. Archipelago.byId[s.dest].name .. ". (Open the map with M to pick.)")
	end
	cannon.occupant = player
	cannon.prompt.Enabled = false
	s.cannon = cannon
	s.yaw, s.pitch = 0, 0
	setState(player, "loaded")
	root.Anchored = true
	humanoid.PlatformStand = true
	Skyship.refreshAim(player)
end

-- Point the loaded goblin's cannon at their island, with their nudge.
function Skyship.refreshAim(player)
	local s = state[player]
	if not s or s.phase ~= "loaded" or not s.cannon then
		return
	end
	local cannon = s.cannon
	local velocity = Dive.launchVelocity(cannon.from, destinationPosition(s.dest), s.yaw, s.pitch)
	s.velocity = velocity
	cannon.aim(velocity.Unit)
	cannon.setRing()
	local root = Util.aliveRoot(player)
	if root then
		-- inside the breech, head toward the muzzle
		root.CFrame = CFrame.lookAt(cannon.from - velocity.Unit * 1.5, cannon.from + velocity.Unit * 20)
	end
	player:SetAttribute("DeployAim", velocity)
end

function Skyship.nudge(player, yaw, pitch)
	local s = state[player]
	if not s or s.phase ~= "loaded" or typeof(yaw) ~= "number" or typeof(pitch) ~= "number" then
		return
	end
	s.yaw = math.clamp(yaw, -D.NUDGE_YAW, D.NUDGE_YAW)
	s.pitch = math.clamp(pitch, -D.NUDGE_PITCH, D.NUDGE_PITCH)
	Skyship.refreshAim(player)
end

function Skyship.leaveCannon(player)
	local s = state[player]
	if not s or s.phase ~= "loaded" then
		return
	end
	local root, humanoid = Util.aliveRoot(player)
	local cannon = s.cannon
	release(player)
	setState(player, "aboard")
	if root then
		root.Anchored = false
		humanoid.PlatformStand = false
		root.CFrame = cannon
				and (CFrame.new(cannon.from + Vector3.new(0, 1.5, 0)) * CFrame.new(
					shipCFrame.RightVector * -math.sign(cannon.rest.X) * 7
				))
			or root.CFrame
	end
end

-- Start the dive. velocity is where the cannon (or the hop off the rail) sends them.
local function launch(player, velocity, fromCannon)
	local root, humanoid = Util.aliveRoot(player)
	local s = state[player]
	if not root or not s then
		return
	end
	if fromCannon then
		local cannon = s.cannon
		release(player)
		if cannon then
			Net.broadcast("DiveFire", { position = cannon.from, direction = velocity.Unit, userId = player.UserId })
			cannon.barrel.CFrame = cannon.barrel.CFrame * CFrame.new(-2, 0, 0)
			task.delay(0.35, function()
				cannon.aim(cannon.rest)
				cannon.setRing()
			end)
		end
	end
	setState(player, "diving")
	s.bounces = 0
	s.diveStart = now()
	s.fall = math.min(0, velocity.Y)
	s.token += 1
	setBodyGroup(player.Character, DIVER_GROUP)
	root.Anchored = false
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	player:SetAttribute("Diving", true)
	player:SetAttribute("DiveVelocity", velocity)
	-- The character's own client flies it; tell that client where to start.
	Net.send(player, "DiveStart", { velocity = velocity, token = s.token })
end

function Skyship.fire(player)
	local s = state[player]
	if not s or s.phase ~= "loaded" or not s.velocity then
		return
	end
	if now() < opensAt then
		return
	end
	s.phase = "fuse"
	player:SetAttribute("DeployState", "fuse")
	local token = s.token
	task.delay(D.FUSE, function()
		local cur = state[player]
		if cur and cur.phase == "fuse" and cur.token == token then
			launch(player, cur.velocity, true)
		end
	end)
end

-- Landing --------------------------------------------------------------------------------------------
local function groundBelow(root)
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	table.insert(ignore, model)
	rayParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), rayParams)
end

local function soft(player, humanoid, root, position)
	Net.broadcastNear(position, 900, "DiveImpact", { kind = "soft", position = position, userId = player.UserId })
	endDive(player, humanoid, root)
end

local function splash(player, humanoid, root, position)
	local s = state[player]
	Net.broadcastNear(position, 1400, "DiveImpact", { kind = "water", position = position, userId = player.UserId })
	if s.bounces < D.BOUNCES then
		s.bounces += 1
		local v = root.AssemblyLinearVelocity
		local bounce = Vector3.new(v.X * D.BOUNCE_KEEP, D.BOUNCE_UP, v.Z * D.BOUNCE_KEEP)
		s.fall = 0
		s.landAfter = now() + 0.8 -- it is still beside the water for a moment: that is not a second landing
		s.token += 1
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = bounce
		Net.send(player, "DiveBounce", { velocity = bounce, token = s.token })
	else
		root.AssemblyLinearVelocity = Vector3.zero
		endDive(player, humanoid, root)
	end
end

local function ostrich(player, root, hit)
	local s = state[player]
	local position = hit.Position
	Net.broadcastNear(position, 1000, "DiveImpact", { kind = "ground", position = position, userId = player.UserId })
	s.phase = "embedded"
	player:SetAttribute("DeployState", "embedded")
	player:SetAttribute("Diving", nil)
	s.token += 1
	local token = s.token
	-- Head first in the ground, legs in the air.
	local yaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
	local buried = CFrame.new(position + Vector3.new(0, 0.6, 0))
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(math.rad(180), 0, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	root.CFrame = buried
	s.buried = buried
	s.embeddedAt = now()
	task.delay(D.EMBED_TIME, function()
		local cur = state[player]
		if not cur or cur.token ~= token or cur.phase ~= "embedded" then
			return
		end
		local r, h = Util.aliveRoot(player)
		if not r then
			return
		end
		r.Anchored = false
		r.CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0))
		endDive(player, h, r)
		r.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 16, D.POP_SPEED, (math.random() - 0.5) * 16)
		Net.broadcastNear(position, 900, "DiveImpact", { kind = "pop", position = position, userId = player.UserId })
	end)
end

local function resolveLanding(player, humanoid, root)
	local s = state[player]
	local velocity = root.AssemblyLinearVelocity
	local hit = groundBelow(root)
	if not hit then
		return
	end
	local gap = root.Position.Y - hit.Position.Y
	local trigger = 4.2 + math.max(0, -s.fall) * 0.1
	if hit.Material == Enum.Material.Water then
		if gap <= trigger - 1 then
			splash(player, humanoid, root, Vector3.new(root.Position.X, hit.Position.Y, root.Position.Z))
		end
		return
	end
	-- Solid ground: the client's character stops on it, so it is resting near the surface.
	if gap <= 5.2 then
		local impact = math.max(-s.fall, -velocity.Y)
		if impact >= D.OSTRICH_SPEED then
			ostrich(player, root, hit)
		else
			soft(player, humanoid, root, hit.Position)
		end
	end
end

-- Each frame ---------------------------------------------------------------------------------------------
function Skyship.tick(_dt)
	if not model then
		return
	end
	local t = now()
	for player, s in pairs(state) do
		local root, humanoid = Util.aliveRoot(player)
		if not root or not player.Parent then
			if s.phase == "loaded" or s.phase == "fuse" then
				release(player)
			end
			state[player] = nil
		elseif s.phase == "aboard" then
			-- Over the side without a cannon: a free dive.
			local local_ = shipCFrame:PointToObjectSpace(root.Position)
			if local_.Y < -9 and t >= opensAt then
				launch(player, root.AssemblyLinearVelocity + Vector3.new(0, 0, 0), false)
				s.dest = s.dest or defaultDestination()
			elseif local_.Y < -40 then
				-- before the cannons unlock: put them back (nobody falls off before the bell)
				Skyship.board(player)
			elseif
				t >= endsAt
				and endsAt > 0
				and (workspace:GetAttribute("RaidPhase") == "raid")
				and s.autoFor ~= boardedFor
			then
				-- The window is over: fire the straggler at their island from where they stand.
				s.autoFor = boardedFor
				s.dest = s.dest or player:GetAttribute("DeployDest") or defaultDestination()
				local from = root.Position
				launch(player, Dive.launchVelocity(from, destinationPosition(s.dest), 0, 0), false)
				Net.toast(player, "The ship fires you off at " .. Archipelago.byId[s.dest].name .. "!")
			end
		elseif s.phase == "loaded" or s.phase == "fuse" then
			if
				t >= endsAt
				and endsAt > 0
				and (workspace:GetAttribute("RaidPhase") == "raid")
				and s.phase == "loaded"
			then
				Skyship.fire(player)
			end
		elseif s.phase == "diving" then
			local velocity = root.AssemblyLinearVelocity
			-- the fastest fall since the launch or the last bounce: the touchdown itself reads near zero
			s.fall = math.min(s.fall, velocity.Y)
			if t - s.diveStart > 0.6 and t >= (s.landAfter or 0) then
				resolveLanding(player, humanoid, root)
			end
			if root.Position.Y < -45 then
				-- somewhere it should not be: back to the water's edge
				root.CFrame = CFrame.new(root.Position.X, 8, root.Position.Z)
				endDive(player, humanoid, root)
			end
		elseif s.phase == "embedded" and s.buried then
			-- the wiggle
			local k = (t - s.embeddedAt) * 30
			root.CFrame = s.buried * CFrame.Angles(0, 0, math.rad(math.sin(k) * 14))
		end
	end
	-- the window is over for everybody: tidy the attribute so the HUD can let go of it
	if endsAt > 0 and t >= endsAt + 1 and workspace:GetAttribute("DeployEndsAt") then
		local anyone = false
		for _, s in pairs(state) do
			if s.phase == "aboard" or s.phase == "loaded" or s.phase == "fuse" then
				anyone = true
			end
		end
		if not anyone then
			workspace:SetAttribute("DeployEndsAt", nil)
			workspace:SetAttribute("DeployOpensAt", nil)
		end
	end
end

function Skyship.phaseOf(player)
	local s = state[player]
	return s and s.phase
end

function Skyship.cannonCount()
	return #cannons
end

-- For tests: the cannon table.
function Skyship.cannonAt(index)
	return cannons[index]
end

return Skyship

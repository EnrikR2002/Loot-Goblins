-- Pets that follow goblins about (V11, Goblin Life). Drawn on every client from each goblin's Pet and Look attributes;
-- what a pet DOES (its ability) is decided on the server from the Pet attribute, never from anything here.
--
-- How a pet keeps up with a goblin who is very fast and very often airborne:
--   * on foot, the walkers (crab, frog, tortoise) walk, hop or plod beside you on the ground (a springy follow);
--   * in a boat they ride on its deck beside the driver; during a launch, a skydive, a tumble or a swim they cling
--     on (the crab to your back, the frog on your head, the tortoise like a backpack), so a pet is never left behind
--     on an island or flung across the sea;
--   * the fliers (gull, ghost) fly at a spot beside you, kept in YOUR frame of reference, so they hold station at any
--     speed; a sudden burst of speed only makes them sway back a little;
--   * a pet more than 40 studs from where it should be (a respawn, a teleport) reappears there with a puff.
-- Little characters: idle quirks when you stand still (the crab snaps, the gull looks about, the frog catches a fly,
-- the tortoise yawns, the ghost loops the loop), a cheer when you steal or bank, a tumble when you are launched, a
-- tremble when something big is chasing you, and a dance when you win.
-- Performance: anchored parts moved with one BulkMoveTo a frame; no physics, collisions or ray hits; pets beyond
-- Config.PET_DRAW_RANGE are not drawn, and beyond PET_FULL_RATE_RANGE are updated every third frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local PetLook = require(Shared:WaitForChild("PetLook"))
local Effects = require(script.Parent.Effects)

local Pets = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "LootGoblinsPets"
folder.Parent = workspace

local entries = {} -- player -> entry
local frame = 0
-- On low graphics settings only the nearest dozen pets are drawn (your own always is).
local MAX_DRAWN = 32
pcall(function()
	local level = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	if level > 0 and level <= 3 then
		MAX_DRAWN = 12
	end
end)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local nextFilter = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Where each pet walks or flies, relative to its goblin (x right, y up, z back).
local OFFSET = {
	Crab = Vector3.new(2.6, 0, 2.2),
	Frog = Vector3.new(-2.8, 0, 2.0),
	Tortoise = Vector3.new(2.4, 0, 3.4),
	Gull = Vector3.new(-2.6, 3.8, 1.4),
	Ghost = Vector3.new(2.3, 2.2, 0.8),
}
-- Riding on a boat, relative to the driver's seat.
local DECK = {
	Crab = CFrame.new(2.1, -0.35, -2.2),
	Frog = CFrame.new(-2.1, -0.35, -2.4),
	Tortoise = CFrame.new(2.0, -0.35, 2.4) * CFrame.Angles(0, math.pi, 0),
}
-- Clinging on in the air or the water, relative to the goblin's torso or head.
local CLING = {
	Crab = {
		part = "UpperTorso",
		cf = CFrame.new(0, 0.2, 0.95) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-70), 0, 0),
	},
	Frog = { part = "Head", cf = CFrame.new(0, 0.55, 0.05) },
	Tortoise = {
		part = "UpperTorso",
		cf = CFrame.new(0, -0.6, 1.3) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.5, 0),
	},
}

local function lookOf(other)
	local text = other:GetAttribute("Look")
	local entry = entries[other]
	if entry and entry.lookText == text then
		return entry.look
	end
	return Catalog.decodeLook(text), text
end

-- Building ---------------------------------------------------------------------------------------------------------------
local function destroy(other)
	local entry = entries[other]
	if entry then
		entry.rig.model:Destroy()
		entries[other] = nil
	end
end

local function build(other, petId, look, lookText)
	local rig = PetLook.build(petId, look.petskin, look.pethat)
	if not rig then
		return nil
	end
	rig.model.Parent = folder
	local entry = {
		rig = rig,
		petId = petId,
		sig = petId .. "|" .. tostring(look.petskin) .. "|" .. tostring(look.pethat),
		look = look,
		lookText = lookText,
		pos = nil,
		vel = Vector3.zero,
		yaw = 0,
		mode = "ground",
		blend = nil,
		phase = math.random() * 10,
		idleAt = time() + 4 + math.random() * 4,
		quirk = nil,
		react = nil,
		groundY = nil,
		groundAt = 0,
		airSince = nil,
		lastVel = Vector3.zero,
		lag = Vector3.zero,
		local_ = other == player,
		faded = false,
		accum = 0,
	}
	entries[other] = entry
	return entry
end

-- The goblin's situation ---------------------------------------------------------------------------------------------------
local function situation(other, character, root, dt, entry)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local seat = humanoid and humanoid.SeatPart
	local s = { seat = seat, speed = flat.Magnitude, velocity = v, diving = other:GetAttribute("Diving") ~= nil }
	-- On the ground? A short ray under the goblin, a few times a second.
	if time() >= (entry.feetAt or 0) then
		entry.feetAt = time() + 0.12
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), rayParams)
		entry.feet = hit and hit.Position.Y or nil
		entry.feetWater = hit and hit.Material == Enum.Material.Water
	end
	local grounded = entry.feet ~= nil and not entry.feetWater
	if grounded then
		entry.airSince = nil
	else
		entry.airSince = entry.airSince or time()
	end
	s.swimming = entry.feetWater == true and not seat
	s.airborne = not grounded and not seat and (time() - (entry.airSince or time())) > 0.35
	s.feet = entry.feet or (root.Position.Y - 3)
	-- Being chased by something big (a pursuer whose Chasing attribute is this goblin)? Checked twice a second.
	if time() >= (entry.chaseAt or 0) then
		entry.chaseAt = time() + 0.5
		entry.chased = false
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		local threats = generated and generated:FindFirstChild("Threats")
		if threats then
			for _, model in ipairs(threats:GetChildren()) do
				if model:GetAttribute("Chasing") == other.UserId then
					entry.chased = true
					break
				end
			end
		end
	end
	s.chased = entry.chased
	-- How hard did the goblin just speed up (for the fliers' sway)?
	s.accel = dt > 0 and (v - entry.lastVel) / dt or Vector3.zero
	entry.lastVel = v
	return s
end

-- Poses -------------------------------------------------------------------------------------------------------------------
local function A(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- Each kind of pet: group poses for this moment. `move` is how fast the pet itself is going.
local POSES = {}

POSES.walker = function(entry, t, move, s)
	local phase = entry.phase
	local walking = move > 1.5
	local stride = walking and math.sin(phase * 14) or 0
	local snap = 0
	if entry.quirk == "snap" or (s.chased and math.sin(t * 9) > 0.6) then
		snap = math.max(0, math.sin(t * 18))
	end
	return {
		legA = CFrame.new(0, 0.06 * math.max(0, stride), 0) * A(0, 0, 14 * stride),
		legB = CFrame.new(0, 0.06 * math.max(0, -stride), 0) * A(0, 0, -14 * stride),
		clawL = A(0, 6 * math.sin(t * 2.2), 0),
		clawR = A(0, -6 * math.sin(t * 2.2 + 1), 0),
		pinchL = A(-28 * snap, 0, 0),
		pinchR = A(-28 * snap, 0, 0),
		eyes = CFrame.new(0, 0.05 * math.sin(t * 3), 0),
	},
		walking and 0.06 * math.abs(math.sin(phase * 14)) or 0
end

POSES.hopper = function(entry, t, move, s)
	local hopping = move > 1.5 or s.chased
	local p = (entry.phase * 2.2) % 1
	local lift = hopping and math.sin(p * math.pi) or 0
	local tongue = entry.quirk == "tongue"
	if entry.rig.tongue then
		entry.rig.tongue.Transparency = tongue and 0 or 1
	end
	return {
		legBack = A(hopping and (p < 0.5 and -35 or 10) or 0, 0, 0),
		legFront = A(hopping and -20 * lift or 0, 0, 0),
		throat = CFrame.new(0, 0, -0.06 * (0.5 + 0.5 * math.sin(t * 7))),
		head = A(tongue and 8 or 0, 0, 0),
	},
		1.3 * lift
end

POSES.plodder = function(entry, t, move, s)
	local walking = move > 1
	local step = walking and math.sin(entry.phase * 7) or 0
	local yawn = entry.quirk == "yawn" and math.sin(math.clamp((t - entry.quirkAt) / 1.6, 0, 1) * math.pi) or 0
	local glow = entry.rig.glow
	if glow then
		local ready = time() > 0 and now() >= (entry.owner:GetAttribute("ShellReadyAt") or 0)
		glow.Transparency = ready and (0.6 + 0.12 * math.sin(t * 3)) or 1
	end
	return {
		legA = CFrame.new(0, 0.12 * math.max(0, step), 0),
		legB = CFrame.new(0, 0.12 * math.max(0, -step), 0),
		head = CFrame.new(0, 0.04 * step, (s.chased and 0.35 or 0) - 0.08 * yawn) * A(18 * yawn, 0, 0),
	},
		0
end

POSES.flier = function(entry, t, _move, s)
	local fast = s.speed > 30 or s.diving
	local flap = math.sin(t * (fast and 22 or 12))
	local gliding = not fast and math.sin(t * 0.7) > 0.3
	local wing = gliding and 4 or 34 * flap
	local look = entry.quirk == "look" and 50 * math.sin((t - entry.quirkAt) * 3) or 12 * math.sin(t * 0.9)
	return {
		wingL = A(0, 0, -wing),
		wingR = A(0, 0, wing),
		head = A(0, look, 0),
	}, 0.12 * flap
end

POSES.floater = function(_entry, t, _move, s)
	local wave = math.sin(t * 3)
	return {
		tail1 = A(8 * math.sin(t * 2.6), 10 * wave, 0),
		tail2 = A(12 * math.sin(t * 2.6 - 0.8), 16 * math.sin(t * 3 - 0.8), 0),
		tail3 = A(16 * math.sin(t * 2.6 - 1.6), 22 * math.sin(t * 3 - 1.6), 0),
		armL = A(0, 0, -20 - 20 * math.sin(t * 4)),
		armR = A(0, 0, 20 + 20 * math.sin(t * 4 + 1)),
	},
		0.25 * math.sin(t * 2.4) + (s.chased and 0.08 * math.sin(t * 40) or 0)
end

-- Reactions (a cheer, a tumble, a dance) on top of everything else: a hop and a spin.
local REACT = {
	cheer = { duration = 1.1, hop = 1.6, spin = 360 },
	tumble = { duration = 0.9, hop = 0.6, roll = 720 },
	dance = { duration = 3.4, hop = 1.0, spin = 720, hops = 4 },
}

local function reactionCFrame(entry, t)
	local react = entry.react
	if not react then
		return CFrame.new()
	end
	local spec = REACT[react.kind]
	local p = (t - react.at) / spec.duration
	if p >= 1 then
		entry.react = nil
		return CFrame.new()
	end
	local hops = spec.hops or 1
	local hop = math.abs(math.sin(p * math.pi * hops)) * spec.hop
	return CFrame.new(0, hop, 0) * A(0, (spec.spin or 0) * p, 0) * A((spec.roll or 0) * p, 0, 0)
end

-- One pet, one frame -----------------------------------------------------------------------------------------------------
local function groundAt(entry, position, fallback)
	if time() >= entry.groundAt then
		entry.groundAt = time() + 0.15
		local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
		entry.groundY = hit and hit.Position.Y or fallback
	end
	return entry.groundY or fallback
end

local function step(other, entry, character, root, dt, t)
	entry.owner = other
	local s = situation(other, character, root, dt, entry)
	local kind = entry.rig.kind
	local flier = kind == "flier" or kind == "floater"
	local facing = root.CFrame.LookVector
	local ownerYaw = math.atan2(-facing.X, -facing.Z)
	local ownerFrame = CFrame.new(root.Position) * CFrame.Angles(0, ownerYaw, 0)

	-- Idle quirks when the goblin stands still.
	if entry.quirk and t - entry.quirkAt > 1.8 then
		entry.quirk = nil
	end
	if s.speed < 1 and not s.seat and time() > entry.idleAt then
		entry.idleAt = time() + 6 + math.random() * 5
		entry.quirk = ({ walker = "snap", hopper = "tongue", plodder = "yawn", flier = "look", floater = "loop" })[kind]
		entry.quirkAt = t
	end

	local target -- the pet's origin this frame (before its own pose)
	local mode
	if flier then
		mode = "fly"
		local offset = OFFSET[entry.petId]
		if s.seat then
			offset = Vector3.new(offset.X * 1.2, offset.Y + 3.5, offset.Z + 3)
		end
		-- The local Scout Gull's scouting flight, toward the treasure it can see.
		if entry.scout and t - entry.scout.at < 2.4 then
			local p = (t - entry.scout.at) / 2.4
			local out = math.sin(p * math.pi) * 16
			local away = ownerFrame:VectorToObjectSpace(entry.scout.direction)
			offset = offset + away * out + Vector3.new(0, math.sin(p * math.pi) * 4, 0)
		end
		-- Sway back a little when the goblin suddenly speeds up (in the goblin's own frame).
		local push = -s.accel * 0.012
		if push.Magnitude > 3 then
			push = push.Unit * 3
		end
		entry.lag = entry.lag:Lerp(push, math.min(1, dt * 6))
		local bob = Vector3.new(0, math.sin(t * 2.2 + other.UserId % 7) * 0.4, 0)
		target = CFrame.new(ownerFrame:PointToWorldSpace(offset) + entry.lag + bob)
		local toward = (root.Position + Vector3.new(0, 2, 0)) - target.Position
		local yaw = math.atan2(-toward.X, -toward.Z)
		if s.speed > 6 then
			yaw = ownerYaw
		end
		entry.yaw = entry.yaw + math.atan2(math.sin(yaw - entry.yaw), math.cos(yaw - entry.yaw)) * math.min(1, dt * 6)
		local pitch = s.diving and -0.6 or 0
		local loop = entry.quirk == "loop" and A(math.clamp((t - entry.quirkAt) / 1.2, 0, 1) * 360, 0, 0)
			or CFrame.new()
		target = target * CFrame.Angles(0, entry.yaw, 0) * CFrame.Angles(pitch, 0, 0) * loop
		entry.pos = target.Position
	else
		local seat = s.seat
		if seat and DECK[entry.petId] then
			mode = "deck"
			target = seat.CFrame * DECK[entry.petId]
		elseif s.airborne or s.diving or s.swimming or s.speed > 60 then
			mode = "cling"
			local cling = CLING[entry.petId]
			local part = character:FindFirstChild(cling.part) or character:FindFirstChild("Torso") or root
			target = part.CFrame * cling.cf
		else
			mode = "ground"
			local want = ownerFrame:PointToWorldSpace(OFFSET[entry.petId])
			local pos = entry.pos or want
			if (pos - want).Magnitude > 40 then
				pos = want
				Effects.burst(want + Vector3.new(0, 1, 0), Color3.fromRGB(255, 255, 255), 12, 10)
				entry.vel = Vector3.zero
			end
			-- A spring toward the spot beside the goblin, led a little by the goblin's own speed so a walking or
			-- sprinting goblin does not leave its pet ten studs behind (measured: a plain spring trailed by 10).
			local k = kind == "plodder" and 60 or 90
			local lead = Vector3.new(s.velocity.X, 0, s.velocity.Z) * (2 / math.sqrt(k))
			local accel = (want + lead - pos) * k - entry.vel * (2 * math.sqrt(k))
			entry.vel = entry.vel + accel * dt
			local flatVel = Vector3.new(entry.vel.X, 0, entry.vel.Z)
			pos = pos + flatVel * dt
			pos = Vector3.new(pos.X, groundAt(entry, pos, s.feet), pos.Z)
			entry.pos = pos
			local speed = flatVel.Magnitude
			entry.phase += dt * math.min(speed, 30) * 0.12
			local yaw = speed > 1.5 and math.atan2(-flatVel.X, -flatVel.Z) or ownerYaw
			if kind == "walker" and speed > 1.5 then
				yaw += math.pi / 2 -- crabs walk sideways
			end
			entry.yaw = entry.yaw
				+ math.atan2(math.sin(yaw - entry.yaw), math.cos(yaw - entry.yaw)) * math.min(1, dt * 8)
			target = CFrame.new(pos) * CFrame.Angles(0, entry.yaw, 0)
			entry.move = speed
		end
		if mode ~= "ground" then
			entry.vel = Vector3.zero
			entry.pos = target.Position
			entry.move = 0
			entry.phase += dt * 1.2
		end
	end
	-- Changing between walking, riding and clinging: a quick hop across rather than a jump cut.
	if entry.mode ~= mode then
		if entry.origin then
			entry.blend = { from = entry.origin, at = t }
		end
		entry.mode = mode
	end
	if entry.blend then
		local p = (t - entry.blend.at) / 0.35
		if p >= 1 then
			entry.blend = nil
		else
			local e = p * p * (3 - 2 * p)
			target = entry.blend.from:Lerp(target, e) + Vector3.new(0, math.sin(p * math.pi) * 1.6, 0)
		end
	end
	local poses, bounce = POSES[kind](entry, t, entry.move or 0, s)
	if s.chased and not flier then
		bounce += 0.04 * math.sin(t * 45) -- trembling
	end
	local origin = target * CFrame.new(0, bounce, 0) * reactionCFrame(entry, t)
	entry.origin = origin
	return origin, poses
end

-- Every frame: move every visible pet with one BulkMoveTo.
local partsList, cframeList = {}, {}
local function update(dt)
	frame += 1
	local t = time()
	if t >= nextFilter then
		nextFilter = t + 2
		local list = { folder }
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end
	table.clear(partsList)
	table.clear(cframeList)
	local eye = camera.CFrame.Position
	-- Nearest first, so a cap on how many are drawn keeps the ones that matter (your own always first).
	local order = Players:GetPlayers()
	local distanceOf = {}
	for _, other in ipairs(order) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		distanceOf[other] = other == player and -1 or (root and (root.Position - eye).Magnitude or math.huge)
	end
	table.sort(order, function(a, b)
		return distanceOf[a] < distanceOf[b]
	end)
	local drawn = 0
	for _, other in ipairs(order) do
		local petId = other:GetAttribute("Pet")
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not petId or not root or not humanoid or humanoid.Health <= 0 or not Config.PETS[petId] then
			destroy(other)
			continue
		end
		local look, lookText = lookOf(other)
		local entry = entries[other]
		local sig = petId .. "|" .. tostring(look.petskin) .. "|" .. tostring(look.pethat)
		if entry and entry.sig ~= sig then
			destroy(other)
			entry = nil
		end
		if not entry then
			entry = build(other, petId, look, lookText)
			if not entry then
				continue
			end
		end
		entry.look, entry.lookText = look, lookText or entry.lookText
		local distance = (root.Position - eye).Magnitude
		drawn += 1
		if distance > Config.PET_DRAW_RANGE or drawn > MAX_DRAWN then
			entry.rig.model.Parent = nil
			entry.pos = nil
			continue
		end
		entry.rig.model.Parent = folder
		entry.accum += dt
		-- Level of detail: every frame up close, every 2nd frame at middle distance, every 4th far away
		-- (measured: 32 pets moved every frame cost about 2 ms a frame on the development PC).
		local every = (distance <= Config.PET_FULL_RATE_RANGE and 1) or (distance <= 140 and 2) or 4
		if other ~= player and (frame + other.UserId) % every ~= 0 then
			continue
		end
		local stepDt = math.min(entry.accum, 0.1)
		entry.accum = 0
		local origin, poses = step(other, entry, character, root, stepDt, t)
		local rig = entry.rig
		local groupCF = {}
		for i, part in ipairs(rig.parts) do
			local group = rig.groups[i]
			local g = groupCF[group]
			if not g then
				local pose = poses[group]
				if pose then
					local pivot = rig.pivots[group] or Vector3.zero
					g = CFrame.new(pivot) * pose * CFrame.new(-pivot)
				else
					g = CFrame.new()
				end
				groupCF[group] = g
			end
			table.insert(partsList, part)
			table.insert(cframeList, origin * g * rig.rest[i])
		end
		-- Your own pet fades when the camera is pushed right up against it.
		if entry.local_ then
			local close = (origin.Position - eye).Magnitude < 4
			if close ~= entry.faded then
				entry.faded = close
				for _, part in ipairs(rig.parts) do
					part.LocalTransparencyModifier = close and 1 or 0
				end
			end
		end
	end
	if #partsList > 0 then
		workspace:BulkMoveTo(partsList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for other in pairs(entries) do
		if not other.Parent then
			destroy(other)
		end
	end
end

-- A goblin's pet reacts: "cheer" (stole, banked), "tumble" (launched), "dance" (won).
function Pets.react(userId, kind)
	for other, entry in pairs(entries) do
		if other.UserId == userId and REACT[kind] then
			entry.react = { kind = kind, at = time() }
			if kind == "cheer" and entry.origin then
				Effects.burst(entry.origin.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 226, 120), 14, 12)
			end
		end
	end
end

-- The Scout Gull (yours): every few seconds it flies a little way toward the nearest waiting treasure, and a line under
-- the compass says what and how far.
local gullLabel
local nextScout = 0
local function updateGull(gui)
	local entry = entries[player]
	local mine = player:GetAttribute("Pet") == "Gull"
	if not mine then
		if gullLabel then
			gullLabel.Visible = false
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local loot = generated and generated:FindFirstChild("Loot")
	if not root or not loot then
		return
	end
	local best, bestDistance, bestDirection
	for _, def in ipairs(Config.LOOT) do
		if loot:GetAttribute(def.id .. "State") == "spot" then
			local island = Archipelago.byId[def.island]
			if island then
				local offset = Vector3.new(island.x - root.Position.X, 0, island.z - root.Position.Z)
				local distance = offset.Magnitude
				if distance <= Config.PET_GULL_RANGE and (not bestDistance or distance < bestDistance) then
					best, bestDistance, bestDirection = def, distance, distance > 0 and offset.Unit or Vector3.zAxis
				end
			end
		end
	end
	if not gullLabel and gui then
		gullLabel = Instance.new("TextLabel")
		gullLabel.Name = "GullSees"
		gullLabel.AnchorPoint = Vector2.new(0.5, 0)
		gullLabel.Position = UDim2.new(0.5, 0, 0, 176)
		gullLabel.Size = UDim2.fromOffset(380, 20)
		gullLabel.BackgroundTransparency = 1
		gullLabel.Font = Enum.Font.GothamBold
		gullLabel.TextStrokeTransparency = 0.4
		gullLabel.TextSize = 14
		gullLabel.Parent = gui
	end
	if gullLabel then
		gullLabel.Visible = best ~= nil
		if best then
			gullLabel.Text = string.format("Your gull spots the %s: %d studs", best.name, bestDistance)
			gullLabel.TextColor3 = best.color
		end
	end
	if best and entry and time() >= nextScout then
		nextScout = time() + 9
		entry.scout = { at = time(), direction = bestDirection }
	end
end

function Pets.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LootGoblinsPetHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateGull(gui)
		end
	end)
end

-- For the shop: how a pet kind poses (used by its preview).
Pets.POSES = POSES

return Pets

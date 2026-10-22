-- Pets that follow goblins about (V11, Goblin Life; V13 forty-two of them). Drawn on every client from each goblin's
-- Pet and Look attributes; what a pet DOES (its ability) is decided on the server from the Pet attribute, never here.
--
-- How a pet keeps up with a goblin who is very fast and very often airborne:
--   * on foot, the ground pets (walkers, hoppers, plodders, crawlers, the rolling coin) move beside you on the ground
--     (a springy follow);
--   * in a boat they ride on its deck beside the driver; during a launch, a skydive, a tumble or a swim they cling
--     on (to your back, your head, or like a backpack), so a pet is never left behind on an island or flung across
--     the sea;
--   * the air pets (fliers, floaters, swimmers that swim through the air, the slithering serpents) hold a spot beside
--     you, kept in YOUR frame of reference, so they keep station at any speed; a burst of speed only makes them sway;
--   * a pet more than 40 studs from where it should be (a respawn, a teleport) reappears there with a puff.
-- Little characters: idle quirks when you stand still (shared/PetLook.lua: a snap, a loop, a cartwheel, an ink puff,
-- the bat hangs upside down, the shark circles you, the coin flips), a cheer when you steal or bank, a tumble when
-- you are launched, a tremble (and a puffed-up pufferfish) when something big is chasing you, a dance when you win.
-- Peek, the pocket Watcher, only moves while nobody is looking at it.
-- Performance: anchored parts moved with one BulkMoveTo a frame; no physics, collisions or ray hits; pets beyond
-- Config.PET_DRAW_RANGE are not drawn, and beyond PET_FULL_RATE_RANGE are updated every second or fourth frame.
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

local function A(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- Where each pet walks or flies, relative to its goblin (x right, y up, z back): the V11 five keep their own spots,
-- every other pet takes its kind's (pushed out to the side by its own width, so a big pet does not stand in you).
local OFFSET = {
	Crab = Vector3.new(2.6, 0, 2.2),
	Frog = Vector3.new(-2.8, 0, 2.0),
	Tortoise = Vector3.new(2.4, 0, 3.4),
	Gull = Vector3.new(-2.6, 3.8, 1.4),
	Ghost = Vector3.new(2.3, 2.2, 0.8),
}
local KIND_OFFSET = {
	walker = Vector3.new(2.6, 0, 2.2),
	hopper = Vector3.new(-2.8, 0, 2.0),
	plodder = Vector3.new(2.4, 0, 3.4),
	crawler = Vector3.new(-2.4, 0, 2.8),
	roller = Vector3.new(2.6, 0, 2.6),
	flier = Vector3.new(-2.6, 3.8, 1.4),
	floater = Vector3.new(2.3, 2.2, 0.8),
	swimmer = Vector3.new(-2.5, 2.6, 1.0),
	slither = Vector3.new(2.8, 3.4, 1.8),
}
-- Riding on a boat, relative to the driver's seat.
local DECK = {
	walker = CFrame.new(2.1, -0.35, -2.2),
	crawler = CFrame.new(2.1, -0.35, -2.2),
	roller = CFrame.new(2.1, -0.35, -2.2),
	hopper = CFrame.new(-2.1, -0.35, -2.4),
	plodder = CFrame.new(2.0, -0.35, 2.4) * CFrame.Angles(0, math.pi, 0),
}
-- Clinging on in the air or the water, relative to the goblin's torso or head.
local CLING = {
	walker = {
		part = "UpperTorso",
		cf = CFrame.new(0, 0.2, 0.95) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-70), 0, 0),
	},
	hopper = { part = "Head", cf = CFrame.new(0, 0.55, 0.05) },
	plodder = {
		part = "UpperTorso",
		cf = CFrame.new(0, -0.6, 1.3) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.5, 0),
	},
}
CLING.crawler = CLING.walker
CLING.roller = CLING.plodder

-- One-off puffs when a quirk starts.
local QUIRK_FX = {
	ink = function(position)
		Effects.ball(position + Vector3.new(0, 0.6, 0.6), Color3.fromRGB(40, 28, 60), 3.4, 0.9)
	end,
	bubble = function(position)
		Effects.burst(position + Vector3.new(0, 0.6, 0), Color3.fromRGB(190, 236, 255), 8, 4)
	end,
	spores = function(position)
		Effects.burst(position + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 240, 200), 10, 5)
	end,
	sparkle = function(position)
		Effects.burst(position + Vector3.new(0, 2.1, 0), Color3.fromRGB(255, 190, 70), 8, 9)
	end,
	flare = function(position)
		Effects.burst(position + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 120, 30), 10, 8)
	end,
	rattle = function(position)
		Effects.burst(position, Color3.fromRGB(236, 228, 206), 5, 4)
	end,
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
	local kind = rig.kind
	local offset = OFFSET[petId] or KIND_OFFSET[kind] or KIND_OFFSET.walker
	if not OFFSET[petId] then
		local _, size = rig.model:GetBoundingBox()
		local half = math.max(size.X, size.Z) / 2
		local side = offset.X >= 0 and 1 or -1
		offset = Vector3.new(side * math.max(math.abs(offset.X), 1.7 + half), offset.Y, math.max(offset.Z, half))
	end
	local def = Config.PETS[petId]
	local entry = {
		rig = rig,
		petId = petId,
		kind = kind,
		flying = PetLook.FLYING[kind] == true,
		offset = offset,
		deck = DECK[kind],
		cling = CLING[kind] or CLING.walker,
		shell = def and def.ability == "Tortoise",
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

-- Is this spot in plain view of the camera (for Peek)?
local function watched(position)
	local eye = camera.CFrame.Position
	if (position - eye).Magnitude > 160 then
		return false
	end
	local point, onScreen = camera:WorldToViewportPoint(position)
	if not onScreen or point.Z <= 0 then
		return false
	end
	local size = camera.ViewportSize
	return point.X > size.X * 0.06 and point.X < size.X * 0.94 and point.Y > size.Y * 0.06 and point.Y < size.Y * 0.94
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
	local facing = root.CFrame.LookVector
	local ownerYaw = math.atan2(-facing.X, -facing.Z)
	local ownerFrame = CFrame.new(root.Position) * CFrame.Angles(0, ownerYaw, 0)

	-- Idle quirks when the goblin stands still (and some little puff to go with a few of them).
	local started = PetLook.updateQuirk(entry, t, s.speed < 1 and not s.seat)
	if started and QUIRK_FX[started] and entry.pos and (entry.pos - camera.CFrame.Position).Magnitude < 90 then
		QUIRK_FX[started](entry.pos)
	end
	-- The Shell's glow: lit while that goblin's shell is ready.
	local glow = entry.shell and entry.rig.glow
	if glow then
		local ready = now() >= (other:GetAttribute("ShellReadyAt") or 0)
		glow.Transparency = ready and (0.6 + 0.12 * math.sin(t * 3)) or 1
	end

	local target -- the pet's origin this frame (before its own pose)
	local mode
	local frozen = false
	if entry.flying then
		mode = "fly"
		local offset = entry.offset
		if s.seat then
			offset = Vector3.new(offset.X * 1.2, offset.Y + 3.5, offset.Z + 3)
		end
		-- Its quirk may take it around you: the shark circles, the echo darts to your other side and back.
		local q = entry.quirk and (t - entry.quirkAt) or 0
		if entry.quirk == "circle" then
			local angle = math.atan2(offset.Z, offset.X) + math.clamp(q / 2.4, 0, 1) * math.pi * 2
			local r = math.max(3.2, Vector3.new(offset.X, 0, offset.Z).Magnitude)
			offset = Vector3.new(math.cos(angle) * r, offset.Y, math.sin(angle) * r)
		elseif entry.quirk == "dart" then
			offset = Vector3.new(offset.X * math.cos(math.clamp(q / 1.6, 0, 1) * math.pi * 2), offset.Y, offset.Z)
		end
		-- A scout's flight, toward the treasure it can see (your own pet, if its ability is the Gull's).
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
		elseif entry.quirk == "circle" then
			yaw = math.atan2(-toward.Z, toward.X) -- nose along the circle
		end
		entry.yaw = entry.yaw + math.atan2(math.sin(yaw - entry.yaw), math.cos(yaw - entry.yaw)) * math.min(1, dt * 6)
		local pitch = s.diving and -0.6 or 0
		target = target * CFrame.Angles(0, entry.yaw, 0) * CFrame.Angles(pitch, 0, 0)
		entry.pos = target.Position
		entry.move = s.speed
		entry.phase += dt * 1.2
	else
		local seat = s.seat
		if seat and entry.deck then
			mode = "deck"
			target = seat.CFrame * entry.deck
		elseif s.airborne or s.diving or s.swimming or s.speed > 60 then
			mode = "cling"
			local part = character:FindFirstChild(entry.cling.part) or character:FindFirstChild("Torso") or root
			target = part.CFrame * entry.cling.cf
		else
			mode = "ground"
			local want = ownerFrame:PointToWorldSpace(entry.offset)
			local pos = entry.pos or want
			-- Peek: still as a statue while anyone (this camera) is watching it. It catches up while you look away.
			frozen = entry.rig.species.quirk == "freeze" and entry.mode == "ground" and watched(pos)
			if (pos - want).Magnitude > 40 then
				pos = want
				Effects.burst(want + Vector3.new(0, 1, 0), Color3.fromRGB(255, 255, 255), 12, 10)
				entry.vel = Vector3.zero
				frozen = false
			end
			if frozen then
				entry.vel = Vector3.zero
				entry.move = 0
				target = CFrame.new(pos) * CFrame.Angles(0, entry.yaw, 0)
			else
				-- A spring toward the spot beside the goblin, led a little by the goblin's own speed so a walking or
				-- sprinting goblin does not leave its pet ten studs behind (measured: a plain spring trailed by 10).
				local k = (entry.kind == "plodder" or entry.kind == "crawler") and 60 or 90
				if entry.rig.species.quirk == "freeze" then
					k = 160 -- it has a lot of catching up to do
				end
				local lead = Vector3.new(s.velocity.X, 0, s.velocity.Z) * (2 / math.sqrt(k))
				local accel = (want + lead - pos) * k - entry.vel * (2 * math.sqrt(k))
				entry.vel = entry.vel + accel * dt
				local flatVel = Vector3.new(entry.vel.X, 0, entry.vel.Z)
				pos = pos + flatVel * dt
				pos = Vector3.new(pos.X, groundAt(entry, pos, s.feet), pos.Z)
				local speed = flatVel.Magnitude
				entry.phase += dt * math.min(speed, 30) * 0.12
				local yaw = speed > 1.5 and math.atan2(-flatVel.X, -flatVel.Z) or ownerYaw
				if entry.petId == "Crab" and speed > 1.5 then
					yaw += math.pi / 2 -- crabs walk sideways
				end
				entry.yaw = entry.yaw
					+ math.atan2(math.sin(yaw - entry.yaw), math.cos(yaw - entry.yaw)) * math.min(1, dt * 8)
				target = CFrame.new(pos) * CFrame.Angles(0, entry.yaw, 0)
				entry.move = speed
			end
			entry.pos = pos
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
	if frozen then
		entry.origin = target
		return target, {}, nil
	end
	local poses, bounce, extra = PetLook.pose(entry, t, entry.move or 0, s)
	if s.chased and not entry.flying then
		bounce += 0.04 * math.sin(t * 45) -- trembling
	end
	local origin = target * CFrame.new(0, bounce, 0) * reactionCFrame(entry, t)
	entry.origin = origin
	return origin, poses, extra
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
		local origin, poses, extra = step(other, entry, character, root, stepDt, t)
		local rig = entry.rig
		origin = PetLook.apply(rig, origin, poses, extra, partsList, cframeList)
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

-- The scout (your pet, if its ability is the Gull's): every few seconds a flier flies a little way toward the nearest
-- waiting treasure, and a short line under the compass says what and how far.
local scoutLabel
local nextScout = 0
local function updateScout(gui)
	local entry = entries[player]
	local petId = player:GetAttribute("Pet")
	local def = petId and Config.PETS[petId]
	local mine = def ~= nil and def.ability == "Gull" and player:GetAttribute("Zone") ~= "port"
	if not mine then
		if scoutLabel then
			scoutLabel.Visible = false
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
	for _, lootDef in ipairs(Config.LOOT) do
		if loot:GetAttribute(lootDef.id .. "State") == "spot" then
			local island = Archipelago.byId[lootDef.island]
			if island then
				local offset = Vector3.new(island.x - root.Position.X, 0, island.z - root.Position.Z)
				local distance = offset.Magnitude
				if distance <= Config.PET_GULL_RANGE and (not bestDistance or distance < bestDistance) then
					best, bestDistance, bestDirection = lootDef, distance, distance > 0 and offset.Unit or Vector3.zAxis
				end
			end
		end
	end
	if not scoutLabel and gui then
		scoutLabel = Instance.new("TextLabel")
		scoutLabel.Name = "PetSees"
		scoutLabel.AnchorPoint = Vector2.new(0.5, 0)
		scoutLabel.Position = UDim2.new(0.5, 0, 0, 150)
		scoutLabel.Size = UDim2.fromOffset(380, 20)
		scoutLabel.BackgroundTransparency = 1
		scoutLabel.Font = Enum.Font.GothamBold
		scoutLabel.TextStrokeTransparency = 0.4
		scoutLabel.TextSize = 14
		scoutLabel.Parent = gui
	end
	if scoutLabel then
		scoutLabel.Visible = best ~= nil
		if best then
			local item = Catalog.get(petId)
			scoutLabel.Text =
				string.format("%s sees the %s · %d", item and item.name or "Your pet", best.name, bestDistance)
			scoutLabel.TextColor3 = best.color
		end
	end
	if best and entry and entry.flying and time() >= nextScout then
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
			updateScout(gui)
		end
	end)
end

return Pets

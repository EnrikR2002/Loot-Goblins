-- What other goblins' style looks like from here (V11, Goblin Life). All local presentation; nothing here changes
-- game state or anybody's physics:
--   * boats: the boost trail, wake and trick effect of whoever is driving (the boat's Trail / Wake / TrickFx
--     attributes, set by server/BoatStyle.lua), drawn only for boats near the camera (StyleFx.DRAW_RANGE);
--   * emotes and victory dances: every goblin whose Emote attribute is set is posed (shared/EmoteMoves.lua), the same
--     way V8 poses a dive: a joint's Transform each frame, after the animator;
--   * the winner's celebration effects (coins, the self-crowning crown, confetti).
-- The local goblin stops its own emote the moment it moves or jumps (and tells the server).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local StyleFx = require(Shared:WaitForChild("StyleFx"))
local EmoteMoves = require(Shared:WaitForChild("EmoteMoves"))
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))
local Effects = require(script.Parent.Effects)

local Looks = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local emoteRemote = remotes:WaitForChild("EmoteRequest")

local function now()
	return workspace:GetServerTimeNow()
end

-- Lower-power devices (graphics quality 1 to 3) get half the particles.
local function quality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and level and level > 0 and level <= 3 then
		return 0.5
	end
	return 1
end
local QUALITY = quality()

-- Emitters --------------------------------------------------------------------------------------------------------------
local function emitter(parent, spec, lifetime, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.texture
	e.Color = spec.colors or ColorSequence.new(spec.color or Color3.new(1, 1, 1))
	e.LightEmission = spec.light or 0.6
	local size = spec.size or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Rate = 0
	if spec.spin then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-260, 260)
	end
	if spec.float then
		e.Acceleration = Vector3.new(0, 6, 0)
	end
	e.Parent = parent
	return e
end

-- Boats -----------------------------------------------------------------------------------------------------------------
local boats = {} -- model -> entry

local function clearBoat(model)
	local entry = boats[model]
	if not entry then
		return
	end
	for _, item in ipairs(entry.made) do
		item:Destroy()
	end
	boats[model] = nil
end

local function buildBoat(model, hull)
	local entry = { model = model, hull = hull, made = {}, trickUntil = 0 }
	local size = hull.Size
	local trailId, wakeId, trickId =
		model:GetAttribute("Trail"), model:GetAttribute("Wake"), model:GetAttribute("TrickFx")
	entry.sig = tostring(trailId) .. tostring(wakeId) .. tostring(trickId)
	local stern = Instance.new("Attachment")
	stern.Name = "StyleStern"
	stern.Position = Vector3.new(0, 0, size.Z / 2)
	stern.Parent = hull
	table.insert(entry.made, stern)
	local trail = trailId and StyleFx.TRAILS[trailId]
	if trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = Vector3.new(-size.X * 0.36, size.Y * 0.45, size.Z / 2)
		a1.Position = Vector3.new(size.X * 0.36, size.Y * 0.45, size.Z / 2)
		a0.Parent, a1.Parent = hull, hull
		local ribbon = Instance.new("Trail")
		ribbon.Attachment0, ribbon.Attachment1 = a0, a1
		ribbon.Color = trail.colors
		ribbon.LightEmission = trail.light
		ribbon.Lifetime = trail.lifetime
		ribbon.MinLength = 0.5
		ribbon.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		ribbon.WidthScale =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
		ribbon.FaceCamera = true
		ribbon.Enabled = false
		ribbon.Parent = hull
		entry.trail = ribbon
		table.insert(entry.made, a0)
		table.insert(entry.made, a1)
		table.insert(entry.made, ribbon)
		if trail.sparkle then
			entry.sparkle = emitter(stern, trail.sparkle, 0.9, 4)
			entry.sparkleRate = trail.sparkle.rate * QUALITY
		end
	end
	local wake = wakeId and StyleFx.WAKES[wakeId]
	if wake then
		entry.wake = emitter(stern, wake, 1.4, 5)
		entry.wake.EmissionDirection = Enum.NormalId.Top
		entry.wakeRate = wake.rate * QUALITY
	end
	local trick = trickId and StyleFx.TRICKFX[trickId]
	if trick then
		local core = Instance.new("Attachment")
		core.Name = "StyleCore"
		core.Parent = hull
		table.insert(entry.made, core)
		entry.trick = emitter(core, trick.during, 0.8, 8)
		entry.trick.SpreadAngle = Vector2.new(180, 180)
		entry.trickRate = trick.during.rate * QUALITY
		entry.land = emitter(core, trick.land, 1.1, trick.land.speed)
		entry.land.SpreadAngle = Vector2.new(180, 180)
		entry.land.Acceleration = Vector3.new(0, -40, 0)
		entry.landSpec = trick.land
	end
	boats[model] = entry
	return entry
end

local function structures()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Structures")
end

local nextScan = 0
local function scanBoats()
	local folder = structures()
	local eye = camera.CFrame.Position
	local seen = {}
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			local styled = model:GetAttribute("StyleOwner")
			local hull = styled and model:FindFirstChild("Hull")
			if hull and (hull.Position - eye).Magnitude < StyleFx.DRAW_RANGE then
				seen[model] = true
				local entry = boats[model]
				local sig = tostring(model:GetAttribute("Trail"))
					.. tostring(model:GetAttribute("Wake"))
					.. tostring(model:GetAttribute("TrickFx"))
				if entry and (entry.sig ~= sig or entry.hull ~= hull) then
					clearBoat(model)
					entry = nil
				end
				if not entry then
					buildBoat(model, hull)
				end
			end
		end
	end
	for model in pairs(boats) do
		if not seen[model] or not model.Parent then
			clearBoat(model)
		end
	end
end

local function updateBoats()
	local t = now()
	for _, entry in pairs(boats) do
		local hull = entry.hull
		local boosting = (entry.model:GetAttribute("BoostEndsAt") or 0) > t
		if entry.trail then
			entry.trail.Enabled = boosting
		end
		if entry.sparkle then
			entry.sparkle.Rate = boosting and entry.sparkleRate or 0
		end
		if entry.wake then
			local v = hull.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local afloat = hull.Position.Y < 6
			entry.wake.Rate = (afloat and speed > 25) and math.min(60, speed * entry.wakeRate) or 0
		end
		if entry.trick then
			entry.trick.Rate = t < entry.trickUntil and entry.trickRate or 0
		end
	end
end

-- The boat a goblin is driving (by the Pilot attribute the server sets), if it is near.
function Looks.boatOf(userId)
	for model in pairs(boats) do
		if model:GetAttribute("Pilot") == userId or model:GetAttribute("StyleOwner") == userId then
			return model
		end
	end
	return nil
end

-- A trick started on this boat (yours from BoatDrive, others' from the server's BoatFx).
function Looks.trick(model)
	local entry = model and boats[model]
	if entry and entry.trick then
		entry.trickUntil = now() + 0.75
	end
end

-- A clean landing after `count` tricks.
function Looks.landed(model, count)
	local entry = model and boats[model]
	if not entry or not entry.land then
		return
	end
	entry.trickUntil = 0
	local big = (count or 1) >= 3
	local amount = math.min(StyleFx.BURST_CAP, math.floor(entry.landSpec.count * (big and 1 or 0.5) * QUALITY))
	entry.land:Emit(amount)
	if big and entry.landSpec.firework then
		Effects.firework(entry.hull.Position, Color3.fromRGB(255, 180, 80))
	end
end

-- Emotes ----------------------------------------------------------------------------------------------------------------
local jointCache = setmetatable({}, { __mode = "k" })
local function jointsOf(character)
	local joints = jointCache[character]
	if not joints then
		joints = {}
		for _, joint in ipairs(character:GetDescendants()) do
			if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
				joints[joint.Name] = joint
			end
		end
		jointCache[character] = joints
	end
	return joints
end

local function parseEmote(value)
	if type(value) ~= "string" then
		return nil
	end
	local id, at = string.match(value, "^([%w_]+)@([%d%.]+)$")
	return id, tonumber(at)
end

local cancelledAt = nil -- the local goblin's emote start we have already stopped
local function poseAll()
	local eye = camera.CFrame.Position
	local t = now()
	for _, other in ipairs(Players:GetPlayers()) do
		local id, at = parseEmote(other:GetAttribute("Emote"))
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if id and root and (root.Position - eye).Magnitude < 220 and not (other == player and cancelledAt == at) then
			local pose = EmoteMoves.at(id, t - at)
			if pose then
				local joints = jointsOf(character)
				for name, cf in pairs(pose) do
					local joint = joints[name] or joints[EmoteMoves.R6[name] or ""]
					if joint then
						joint.Transform = cf
					end
				end
			end
		end
	end
end

-- The local goblin moved, jumped or sat: stop its emote at once.
local function watchOwnEmote()
	local id, at = parseEmote(player:GetAttribute("Emote"))
	if not id or cancelledAt == at then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local state = humanoid:GetState()
	if
		humanoid.MoveDirection.Magnitude > 0.1
		or humanoid.Jump
		or humanoid.SeatPart ~= nil
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
	then
		cancelledAt = at
		emoteRemote:FireServer("stop")
	end
end

function Looks.emoting()
	local id, at = parseEmote(player:GetAttribute("Emote"))
	return id ~= nil and cancelledAt ~= at and EmoteMoves.at(id, now() - at) ~= nil
end

-- Celebrations ----------------------------------------------------------------------------------------------------------
local function headOf(userId)
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	return character and character:FindFirstChild("Head")
end

local function follow(part, head, offset, duration, onStep)
	local started = time()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = time() - started
		if elapsed > duration or not head.Parent or not part.Parent then
			connection:Disconnect()
			if part.Parent then
				part:Destroy()
			end
			return
		end
		part.CFrame = head.CFrame * offset(elapsed)
		if onStep then
			onStep(elapsed)
		end
	end)
end

function Looks.celebrate(payload)
	local head = headOf(payload.userId)
	if not head or (head.Position - camera.CFrame.Position).Magnitude > 300 then
		return
	end
	Effects.burst(head.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 214, 70), math.floor(50 * QUALITY), 26)
	Effects.ring(head.Position - Vector3.new(0, 4, 0), Color3.fromRGB(255, 214, 70), 8, 0.7)
	if payload.fx == "coins" then
		local holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.Parent = workspace
		local coins = emitter(holder, {
			texture = "rbxasset://textures/particles/SquareParticle.png",
			color = Color3.fromRGB(255, 206, 60),
			size = 0.45,
			light = 0.5,
			spin = true,
		}, 1.6, 22)
		coins.EmissionDirection = Enum.NormalId.Top
		coins.Acceleration = Vector3.new(0, -45, 0)
		coins.Rate = 40 * QUALITY
		follow(
			holder,
			head,
			function()
				return CFrame.new(0, 1.5, 0)
			end,
			3.6,
			function(elapsed)
				if elapsed > 3 then
					coins.Rate = 0
				end
			end
		)
	elseif payload.fx == "crown" then
		local base = Instance.new("Part")
		base.Name = "CelebrationCrown"
		base.Anchored, base.CanCollide, base.CanQuery, base.CanTouch = true, false, false, false
		base.Transparency = 1
		base.Size = head.Size
		base.CFrame = head.CFrame * CFrame.new(0, 4, 0)
		base.Parent = workspace
		Wardrobe.buildOn(base, "hat_crown")
		follow(
			base,
			head,
			function(elapsed)
				local drop = math.clamp((elapsed - 0.5) / 1.5, 0, 1)
				drop = 1 - (1 - drop) * (1 - drop)
				return CFrame.new(0, 4 * (1 - drop) + 0.02, 0) * CFrame.Angles(0, (1 - drop) * 6, 0)
			end,
			4.2,
			function(elapsed)
				if elapsed > 2.05 and elapsed < 2.15 then
					Effects.burst(
						head.Position + Vector3.new(0, 1, 0),
						Color3.fromRGB(255, 226, 120),
						math.floor(40 * QUALITY),
						18
					)
					Effects.chime(Effects.CHIME_GOOD, 0.5)
				end
			end
		)
	end
end

-- Running ------------------------------------------------------------------------------------------------------------------
function Looks.start()
	RunService.PreSimulation:Connect(function()
		watchOwnEmote()
		poseAll()
	end)
	RunService.Heartbeat:Connect(function()
		local t = time()
		if t >= nextScan then
			nextScan = t + 0.5
			scanBoats()
		end
		updateBoats()
	end)
end

return Looks

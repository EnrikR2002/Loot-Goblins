-- Flight (V8): everything that throws a goblin through the air, and how the throw ends. The skyship's
-- cannons and the island catapults are both LAUNCHERS here, so they aim the same way, fly the same
-- way and land the same way (V7 had the dive inside the skyship and the catapults as a separate
-- launch pad with its own little flight on the client).
--
-- A goblin climbs into a launcher (E), looks at where they want to come down, fires, and is thrown:
--   loaded    in the launcher, anchored. The client sends the POINT it is looking at; the server works
--             out the throw (Dive.solve) from the launcher's own numbers. The client never sends a
--             velocity, so a launcher cannot be asked to throw harder than it can.
--   fuse      a short beat, then the throw.
--   diving    in the air. The character's own client flies it (shared/Dive.lua), as with a driven
--             boat; the server watches the root and rules on how it ends:
--               the SEA, fast    a splash and a BOUNCE, up to three, each smaller (Dive.bounce)
--               the SEA, gently  a plain landing in the water
--               the GROUND, fast head first into it like an ostrich, a wiggle, then spat back out
--               the GROUND, slow (braked with a glide) on your feet, control at once
--   embedded  the ostrich moment.
-- Then "landed": the goblin is an ordinary goblin again.
--
-- FLOPPY LIMBS. A tumbling goblin (no keys held) has its arms and legs hung on ball sockets instead
-- of its joints, so they flail behind it; the moment the player takes hold (glide or dive) the joints
-- come back and it strikes the pose. The joints are switched off, never removed, and the neck and
-- waist are left alone, so nothing can break or kill; landing, death, leaving and the raid's reset
-- all put them back. The switch is made here, on the server, so everyone sees the same goblin.
-- Roblox has two kinds of avatar joint and a place can be given either: the newer AnimationConstraint
-- (which comes with its own ball socket: switching the joint off is the whole job) and the older
-- Motor6D (which needs a socket made for it). Both are handled.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Dive = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Dive"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Poltergoblin = require(script.Parent.Poltergoblin)

local Flight = {}

local D = Config.DIVE

local state = {} -- player -> { phase, launcher, velocity, bounces, fall, token, diveStart, landAfter, mode, floppy }
local launchers = {}
local skyship -- the ship's model: a flight passes through it

-- A goblin in the air passes through the skyship (it starts inside a cannon, and falls past a rail
-- and a wing), but not through anything else. Two collision groups do it.
Flight.HULL_GROUP, Flight.DIVER_GROUP = "SkyshipHull", "SkyDiver"
pcall(function()
	PhysicsService:RegisterCollisionGroup(Flight.HULL_GROUP)
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup(Flight.DIVER_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(Flight.DIVER_GROUP, Flight.HULL_GROUP, false)

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

-- Floppy limbs ---------------------------------------------------------------------------------------
local LIMB_JOINTS = {
	LeftShoulder = 85,
	RightShoulder = 85,
	LeftElbow = 60,
	RightElbow = 60,
	LeftHip = 70,
	RightHip = 70,
	LeftKnee = 55,
	RightKnee = 55,
	["Left Shoulder"] = 85,
	["Right Shoulder"] = 85,
	["Left Hip"] = 70,
	["Right Hip"] = 70,
}

local function stiffen(s)
	if not s.floppy then
		return
	end
	for _, entry in ipairs(s.floppy) do
		if entry.joint.Parent then
			entry.joint.Enabled = true
		end
		if entry.socket then
			entry.socket:Destroy()
			entry.a0:Destroy()
			entry.a1:Destroy()
		end
	end
	s.floppy = nil
end

local function flop(player, s)
	if s.floppy then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local list = {}
	for _, joint in ipairs(character:GetDescendants()) do
		local swing = LIMB_JOINTS[joint.Name]
		if swing and joint:IsA("AnimationConstraint") then
			if joint.Enabled then
				joint.Enabled = false -- its own ball socket takes the limb
				table.insert(list, { joint = joint })
			end
		elseif swing and joint:IsA("Motor6D") and joint.Part0 and joint.Part1 and joint.Enabled then
			-- A socket exactly where the motor holds the limb, so the limb starts where it was.
			local a0 = Instance.new("Attachment")
			a0.Name = "FlopSocket"
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "FlopSocket"
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "Flop"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = swing
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -35
			socket.TwistUpperAngle = 35
			socket.Parent = joint.Part0
			joint.Enabled = false
			table.insert(list, { joint = joint, socket = socket, a0 = a0, a1 = a1 })
		end
	end
	s.floppy = list
end

-- Launchers -----------------------------------------------------------------------------------------
-- A launcher: { kind = "cannon" | "catapult", from = Vector3 (where the throw starts), speed, elevation,
--   rest = Vector3 (a point it aims at when nobody has aimed it), restFor = function(player) -> Vector3?,
--   prompt = ProximityPrompt,
--   aim = function(direction), fired = function(direction)?, ready = function(player) -> ok, why?,
--   exit = Vector3 (where a goblin who climbs out is put), back = string (the DeployState to return to) }
-- V13.2, a launcher that MOVES (the skyship's cannons) also has: fromFn / exitFn / restFn (asked each time instead of
-- from / exit / rest), localFrom (its spot in the ship's frame, for the client: LaunchLocal), and mount(player, root),
-- orient(player, direction) and unmount(player): the goblin is welded into it (it rides along) instead of anchored.
local function fromOf(launcher)
	return launcher.fromFn and launcher.fromFn() or launcher.from
end
local function exitOf(launcher)
	return launcher.exitFn and launcher.exitFn() or launcher.exit
end
function Flight.addLauncher(launcher)
	launcher.occupant = nil
	launcher.prompt.Triggered:Connect(function(player)
		Flight.load(player, launcher)
	end)
	table.insert(launchers, launcher)
	return launcher
end

local function release(s)
	local launcher = s.launcher
	if launcher then
		launcher.occupant = nil
		launcher.prompt.Enabled = true
		s.launcher = nil
		if launcher.unmount and s.player then
			launcher.unmount(s.player)
		end
		return launcher
	end
	return nil
end

local function setPhase(player, s, phase)
	s.phase = phase
	player:SetAttribute("DeployState", phase)
end

function Flight.phaseOf(player)
	local s = state[player]
	return s and s.phase
end

-- The flight is over (or never happened): an ordinary goblin again, on its feet.
local function finish(player, s, humanoid, root, phase)
	s.token += 1
	stiffen(s)
	release(s)
	state[player] = nil
	setBodyGroup(player.Character, "Default")
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DiveMode", nil)
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root and root.Parent then
		root.Anchored = false
		local look = root.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 0.05 and flatLook.Unit or Vector3.new(0, 0, -1)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
	end
	player:SetAttribute("DeployState", phase or "landed")
end

-- Climb in.
function Flight.load(player, launcher, target)
	if state[player] or launcher.occupant then
		return false
	end
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return false
	end
	if launcher.ready then
		local ok, why = launcher.ready(player)
		if not ok then
			if why then
				Net.toast(player, why)
			end
			return false
		end
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
	local s = { bounces = 0, fall = 0, token = 0, launcher = launcher, loadedAt = now(), player = player }
	state[player] = s
	launcher.occupant = player
	launcher.prompt.Enabled = false
	humanoid.PlatformStand = true
	if launcher.mount then
		launcher.mount(player, root) -- V13.2: welded into a moving launcher (the skyship), it rides along
	else
		root.Anchored = true
	end
	target = target
		or (launcher.restFor and launcher.restFor(player))
		or (launcher.restFn and launcher.restFn())
		or launcher.rest
	player:SetAttribute("LaunchFrom", fromOf(launcher))
	player:SetAttribute("LaunchLocal", launcher.localFrom) -- V13.2: the client follows the moving ship with it
	player:SetAttribute("LaunchSpeed", launcher.speed)
	player:SetAttribute("LaunchElevation", launcher.elevation)
	player:SetAttribute("LaunchKind", launcher.kind)
	player:SetAttribute("LaunchTarget", target)
	setPhase(player, s, "loaded")
	Flight.aim(player, target)
	return true
end

-- Point the loaded goblin's launcher at a place. The client says WHERE; the server works out the throw.
function Flight.aim(player, target)
	local s = state[player]
	if not s or s.phase ~= "loaded" or typeof(target) ~= "Vector3" then
		return
	end
	local launcher = s.launcher
	local from = fromOf(launcher)
	if target ~= target or (target - from).Magnitude > D.AIM_RANGE then
		return -- not a number, or nowhere this could throw
	end
	local velocity = Dive.solve(from, target, launcher.elevation, launcher.speed)
	s.velocity = velocity
	s.target = target
	launcher.aim(velocity.Unit)
	local root = Util.aliveRoot(player)
	if launcher.orient then
		launcher.orient(player, velocity.Unit)
	elseif root then
		-- inside it, head toward the way out
		root.CFrame = CFrame.lookAt(from - velocity.Unit * 1.5, from + velocity.Unit * 20)
	end
end

function Flight.leave(player)
	local s = state[player]
	if not s or s.phase ~= "loaded" then
		return
	end
	local root, humanoid = Util.aliveRoot(player)
	local launcher = s.launcher
	local exit = exitOf(launcher)
	if launcher.unmount then
		launcher.unmount(player) -- (first: moving a root still welded into the ship would move the ship)
	end
	if root then
		root.Anchored = false
		root.CFrame = CFrame.new(exit)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	finish(player, s, humanoid, root, launcher.back)
end

-- Throw a goblin: from a launcher's fuse, off the side of the skyship, or by the ship itself when the
-- window closes. `launcher` (optional) is only for the bang. `start` (optional, V13.2): where the flight begins (the
-- ship firing a goblin off its moving deck): the goblin is put there, here and on their own client.
function Flight.launch(player, velocity, launcher, start)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return false
	end
	local s = state[player]
	if not s then
		s = { bounces = 0, fall = 0, token = 0 }
		state[player] = s
		Poltergoblin.finish(player, "cancel")
	end
	-- V13.2: a moving launcher's throw is solved again from where it is now, at the place the goblin aimed.
	local from = launcher and fromOf(launcher)
	if launcher and launcher.fromFn and s.target then
		velocity = Dive.solve(from, s.target, launcher.elevation, launcher.speed)
	end
	release(s)
	if launcher then
		Net.broadcastNear(from, 2600, "DiveFire", {
			position = from,
			direction = velocity.Unit,
			userId = player.UserId,
			kind = launcher.kind,
		})
		if launcher.fired then
			launcher.fired(velocity.Unit)
		end
	end
	if launcher and launcher.fromFn then
		root.CFrame = CFrame.new(from) * root.CFrame.Rotation
	elseif typeof(start) == "Vector3" then
		root.CFrame = CFrame.new(start) * root.CFrame.Rotation
	end
	setPhase(player, s, "diving")
	s.bounces = 0
	s.diveStart = now()
	s.fall = math.min(0, velocity.Y)
	s.landAfter = nil
	s.mode = "tumble"
	s.token += 1
	setBodyGroup(player.Character, Flight.DIVER_GROUP)
	root.Anchored = false
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	player:SetAttribute("Diving", true)
	player:SetAttribute("DiveMode", "tumble")
	flop(player, s)
	-- The character's own client flies it; tell that client where to start.
	Net.send(player, "DiveStart", {
		velocity = velocity,
		token = s.token,
		start = (typeof(start) == "Vector3" and start) or (launcher and launcher.fromFn and from) or nil,
	})
	return true
end

function Flight.fire(player)
	local s = state[player]
	if not s or s.phase ~= "loaded" or not s.velocity then
		return
	end
	-- V13.2: the skyship's lock is checked on the server every time, whoever asks (the client, the auto-fire).
	if s.launcher.canFire then
		local ok, why = s.launcher.canFire(player)
		if not ok then
			if why then
				Net.toast(player, why)
			end
			return
		end
	end
	setPhase(player, s, "fuse")
	local token = s.token
	local launcher = s.launcher
	task.delay(D.FUSE, function()
		local cur = state[player]
		if cur and cur.phase == "fuse" and cur.token == token then
			Flight.launch(player, cur.velocity, launcher)
		end
	end)
end

-- The client's hands: tumbling (none), braking (glide) or diving (pencil). It changes the look for
-- everyone (floppy or posed) and whether the sea bounces them; the flying itself is the client's.
function Flight.setMode(player, mode)
	local s = state[player]
	if not s or s.phase ~= "diving" or (mode ~= "tumble" and mode ~= "glide" and mode ~= "pencil") then
		return
	end
	if s.mode == mode then
		return
	end
	s.mode = mode
	player:SetAttribute("DiveMode", mode)
	if mode == "tumble" then
		flop(player, s)
	else
		stiffen(s)
	end
end

-- Landing --------------------------------------------------------------------------------------------
local function groundBelow(root)
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if skyship then
		table.insert(ignore, skyship)
	end
	rayParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), rayParams)
end

local function soft(player, s, humanoid, root, position, kind)
	Net.broadcastNear(
		position,
		900,
		"DiveImpact",
		{ kind = kind or "soft", position = position, userId = player.UserId }
	)
	finish(player, s, humanoid, root)
end

local function splash(player, s, humanoid, root, position)
	local v = root.AssemblyLinearVelocity
	local away = Dive.bounce(Vector3.new(v.X, math.min(v.Y, s.fall), v.Z), s.bounces + 1, s.mode)
	Net.broadcastNear(position, 1400, "DiveImpact", {
		kind = "water",
		position = position,
		userId = player.UserId,
		bounce = away and (s.bounces + 1) or 0,
	})
	if away then
		s.bounces += 1
		s.fall = 0
		s.landAfter = now() + D.BOUNCE_GRACE -- it is still beside the water for a moment: not a second landing
		s.token += 1
		-- The goblin is put on the surface, which can be a jump of many studs for a fast one. Loose limbs
		-- would be left behind for a moment (they stretched 15 studs in a test), so they are hooked back on
		-- for the move and let go again a beat later.
		local loose = s.floppy ~= nil
		stiffen(s)
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = away
		Net.send(player, "DiveBounce", { velocity = away, token = s.token, count = s.bounces })
		if loose then
			local token = s.token
			task.delay(0.12, function()
				if state[player] == s and s.token == token and s.phase == "diving" and s.mode == "tumble" then
					flop(player, s)
				end
			end)
		end
	else
		-- In the water, at the surface, swimming: never left underneath it.
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * root.CFrame.Rotation
		finish(player, s, humanoid, root)
	end
end

local function ostrich(player, s, root, hit)
	local position = hit.Position
	Net.broadcastNear(position, 1000, "DiveImpact", { kind = "ground", position = position, userId = player.UserId })
	stiffen(s)
	setPhase(player, s, "embedded")
	player:SetAttribute("Diving", nil)
	player:SetAttribute("DiveMode", nil)
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
		if cur ~= s or s.token ~= token or s.phase ~= "embedded" then
			return
		end
		local r, h = Util.aliveRoot(player)
		if not r then
			return
		end
		r.Anchored = false
		r.CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0))
		finish(player, s, h, r)
		r.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 16, D.POP_SPEED, (math.random() - 0.5) * 16)
		Net.broadcastNear(position, 900, "DiveImpact", { kind = "pop", position = position, userId = player.UserId })
	end)
end

local function resolveLanding(player, s, humanoid, root)
	local velocity = root.AssemblyLinearVelocity
	local hit = groundBelow(root)
	if not hit then
		return
	end
	local gap = root.Position.Y - hit.Position.Y
	if hit.Material == Enum.Material.Water then
		-- The faster the fall, the sooner it counts: the server sees the goblin a moment late.
		if gap <= 3.2 + math.max(0, -s.fall) * 0.06 then
			-- V12: but only if it really is coming down in the water. A fast fall counts up to about 20 studs early,
			-- and a throw coming in over the sea to a beach was declared a splash that far short of the sand (and
			-- skipped three times away from the island it was aimed at). Where it will be when it has fallen the
			-- gap, going on as it is: if that is dry land, the client will land it there.
			local down = math.max(1, -velocity.Y)
			local ahead = Vector3.new(velocity.X, 0, velocity.Z) * math.min(gap / down, 0.5)
			local landing =
				workspace:Raycast(root.Position + ahead + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), rayParams)
			if gap > 3.2 and landing and landing.Material ~= Enum.Material.Water then
				return
			end
			splash(player, s, humanoid, root, Vector3.new(root.Position.X, hit.Position.Y, root.Position.Z))
		end
		return
	end
	-- Solid ground: the client stops its goblin on it, so it is resting near the surface.
	if gap <= 5.2 then
		local impact = math.max(-s.fall, -velocity.Y)
		if impact >= D.OSTRICH_SPEED and s.mode ~= "glide" then
			ostrich(player, s, root, hit)
		else
			soft(player, s, humanoid, root, hit.Position)
		end
	end
end

-- Each frame ---------------------------------------------------------------------------------------------
function Flight.tick(_dt)
	local t = now()
	for player, s in pairs(state) do
		local root, humanoid = Util.aliveRoot(player)
		if not root or not player.Parent then
			Flight.forget(player)
		elseif s.phase == "loaded" then
			local launcher = s.launcher
			if launcher.kind ~= "cannon" and t - s.loadedAt > D.LOADED_TIMEOUT then
				Net.toast(player, "The catapult tips you out. (Space fires it.)")
				Flight.leave(player)
			end
		elseif s.phase == "diving" then
			local velocity = root.AssemblyLinearVelocity
			-- the fastest fall since the launch or the last bounce: the touchdown itself reads near zero
			s.fall = math.min(s.fall, velocity.Y)
			if t - s.diveStart > 0.5 and t >= (s.landAfter or 0) then
				resolveLanding(player, s, humanoid, root)
			end
			if state[player] == s and s.phase == "diving" then
				if root.Position.Y < -45 then
					-- somewhere it should not be: back to the water's edge
					root.CFrame = CFrame.new(root.Position.X, 8, root.Position.Z)
					root.AssemblyLinearVelocity = Vector3.zero
					finish(player, s, humanoid, root)
				elseif t - s.diveStart > D.MAX_TIME then
					root.AssemblyLinearVelocity = Vector3.zero
					finish(player, s, humanoid, root)
				end
			end
		elseif s.phase == "embedded" and s.buried then
			-- the wiggle
			local k = (t - s.embeddedAt) * 30
			root.CFrame = s.buried * CFrame.Angles(0, 0, math.rad(math.sin(k) * 14))
		end
	end
end

-- A goblin left, died or respawned: let go of everything, quietly.
function Flight.forget(player)
	local s = state[player]
	if not s then
		return
	end
	s.token += 1
	stiffen(s)
	release(s)
	state[player] = nil
	if player.Parent then
		player:SetAttribute("Diving", nil)
		player:SetAttribute("DiveMode", nil)
	end
end

-- The raid is over: everyone out of the air and out of the launchers.
function Flight.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		Flight.forget(player)
		setBodyGroup(player.Character, "Default")
		player:SetAttribute("Diving", nil)
		player:SetAttribute("DiveMode", nil)
		player:SetAttribute("DeployState", nil)
		local root, humanoid = Util.aliveRoot(player)
		if humanoid then
			humanoid.PlatformStand = false
		end
		if root then
			root.Anchored = false
		end
	end
end

-- The island catapults (described by the world's builders in refs.catapults) become launchers.
function Flight.build(refs, shipModel)
	skyship = shipModel
	for _, entry in ipairs(refs.catapults or {}) do
		Flight.addLauncher({
			kind = "catapult",
			from = entry.from,
			speed = D.CATAPULT_SPEED,
			elevation = D.CATAPULT_ELEVATION,
			rest = entry.target,
			prompt = entry.prompt,
			exit = entry.exit,
			back = "landed",
			aim = entry.aim,
			fired = entry.fired,
			ready = function(_player)
				if workspace:GetAttribute("RaidPhase") ~= "raid" then
					return false, "The catapults are tied down between raids."
				end
				return true
			end,
		})
	end
end

-- For tests: what the server thinks a goblin's flight is doing.
function Flight.inspect(player)
	local s = state[player]
	if not s then
		return nil
	end
	return { phase = s.phase, bounces = s.bounces, mode = s.mode, floppy = s.floppy and #s.floppy or 0, fall = s.fall }
end

function Flight.launcherCount()
	return #launchers
end

-- For tests.
function Flight.launcherAt(index)
	return launchers[index]
end

return Flight

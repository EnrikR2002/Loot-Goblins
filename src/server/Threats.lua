-- How the world fights back. Every threat targets loot carriers only, so the
-- danger follows the loot (whoever holds it is the problem now).
--
--   Guardian  wakes when the Golden Idol leaves its altar, or at HUNTED heat.
--             Leashed to the temple until FRENZY. Smashes loot loose.
--   Totems    at ALERT heat and up, charge for a moment, then lob a blast.
--   Trouble   the moment loot leaves its spot: boulder, cave-in, cannon barrage, bell.
--   Reveal    at ALERT and up (or after the bell), carriers glow through walls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local GuardianLook = require(script.Parent.GuardianLook)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Impact = require(script.Parent.Impact)
local Heat = require(script.Parent.Heat)
local Blast = require(script.Parent.Blast)

local Threats = {}
Threats.handlers = {} -- trouble kind -> function(item, player), filled by Troubles.lua
Threats.text = {} -- trouble kind -> banner text
local refs

local EYE_SLEEP = Color3.fromRGB(60, 25, 25)
local EYE_HUNT = Color3.fromRGB(255, 60, 40)
local EYE_FRENZY = Color3.fromRGB(255, 170, 40)
local TOTEM_IDLE = Color3.fromRGB(90, 30, 30)
local TOTEM_ACTIVE = Color3.fromRGB(255, 80, 40)
local BLAST_COLOR = Color3.fromRGB(255, 120, 40)
-- V9: the Guardian is bigger (its reach and its stomp's height check grow with it).
local GS = Config.GUARDIAN_SCALE.Guardian

local function now()
	return workspace:GetServerTimeNow()
end

local function frenzy()
	return Heat.tier >= #Config.HEAT_TIERS
end

local function inWard(position, margin)
	return Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS + (margin or 0)
end

-- Damage + push + loot knocked loose for everyone in a radius. Returns the
-- players hit.
local function hurtArea(center, radius, damage, knockback, lootReason, maxHeight)
	local hit = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			local offset = root.Position - center
			local inRange
			if maxHeight then
				inRange = Util.flatDistance(root.Position, center) <= radius and math.abs(offset.Y) <= maxHeight
			else
				inRange = offset.Magnitude <= radius
			end
			if inRange and Impact.open(player) then
				Impact.damage(humanoid, damage)
				local away = Vector3.new(offset.X, 0, offset.Z)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
				Util.knockback(root, away * knockback + Vector3.new(0, knockback * 0.5, 0), 0.2)
				if lootReason then
					Loot.knockLoose(player, center, lootReason, nil)
				end
				table.insert(hit, player)
			end
		end
	end
	return hit
end

-- Guardian -------------------------------------------------------------------
-- A kinematic stone golem: anchored, non-colliding parts the server poses each
-- frame. It walks on terrain and walkable parts, wades through water, and
-- can't shove loot around (so it can't push the idol off the map).
local guardian = {
	model = nil,
	parts = {},
	position = Vector3.zero,
	yaw = 0,
	state = "sleep", -- "sleep" | "awake" | "board" (leaping onto its boat) | "sail" (in its boat: Pursuit.lua)
	nextHitAt = 0,
	recoverUntil = 0,
	phase = 0,
	wading = false,
	hadTarget = false,
	leap = nil,
	nextLeapAt = 0,
	nextThrowAt = 0,
	stomp = nil,
	nextStompAt = 0,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false

-- Stomp rings racing outward along the ground: { origin, startedAt, last, hit = {} }.
local waves = {}
-- What counts as standing on something when a ring passes (solid things, not the sea).
local standParams = RaycastParams.new()
standParams.FilterType = Enum.RaycastFilterType.Include
standParams.IgnoreWater = true

local function buildGuardian()
	local model = Instance.new("Model")
	model.Name = "Guardian"
	-- V10: the body is GuardianLook's design (the same one rides the speedboat). GS scales it from the feet up.
	local torso, head
	local eyes = {}
	for _, spec in ipairs(GuardianLook.parts()) do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Size = spec.size * GS
		p.Color = spec.color
		p.Material = spec.material
		if spec.shape then
			p.Shape = spec.shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = spec.limb ~= "halo"
		p.Parent = model
		table.insert(guardian.parts, {
			part = p,
			name = spec.name,
			limb = spec.limb,
			pivot = CFrame.new(spec.pivot.Position * GS) * spec.pivot.Rotation,
			hang = CFrame.new(spec.hang.Position * GS) * spec.hang.Rotation,
		})
		if spec.name == "Torso" then
			torso = p
		elseif spec.name == "Head" then
			head = p
		elseif spec.name == "Eye" then
			table.insert(eyes, p)
		end
	end
	model.PrimaryPart = torso
	guardian.eyes = eyes

	local gui = Instance.new("BillboardGui")
	gui.Name = "GuardianTag"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.MaxDistance = 120 -- V9: a close-up label, not a sign across the sea (V8: 400)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 200)
	label.TextStrokeTransparency = 0.2
	label.Text = "GUARDIAN  zzz"
	label.Parent = gui
	gui.Parent = head
	guardian.label = label

	model.Parent = refs.folders.threats
	guardian.model = model
	groundParams.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	standParams.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground, refs.folders.structures }
end

local function poseGuardian()
	local g = guardian
	local sleeping = g.state == "sleep"
	local recovering = now() < g.recoverUntil
	local swing = sleeping and 0 or math.sin(g.phase) * 0.6
	local bob = sleeping and -3 or math.abs(math.sin(g.phase)) * 0.6
	if g.leap and now() < g.leap.jumpAt then
		bob = -4 -- Crouching for the leap.
	end
	local base = CFrame.new(g.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, g.yaw, 0)
	if sleeping then
		base *= CFrame.Angles(math.rad(12), 0, 0)
	end
	local parts, cframes = {}, {}
	-- Both fists high overhead while it winds up a stomp: the tell to get off the ground.
	local raised = (g.stomp ~= nil or g.state == "board") and 2.8 or nil
	-- V10: the sun halo turns slowly (faster when it is hunting), the arms swing wide and heavy.
	local halo = now() * (sleeping and 0.15 or 0.6)
	for _, entry in ipairs(g.parts) do
		local rot = CFrame.new()
		local limb = entry.limb
		if limb == "armL" then
			rot = CFrame.Angles(raised or (recovering and 1.3 or swing), 0, sleeping and 0 or 0.12)
		elseif limb == "armR" then
			rot = CFrame.Angles(raised or (recovering and 1.3 or -swing), 0, sleeping and 0 or -0.12)
		elseif limb == "legL" then
			rot = CFrame.Angles(-swing * 0.8, 0, 0)
		elseif limb == "legR" then
			rot = CFrame.Angles(swing * 0.8, 0, 0)
		elseif limb == "halo" then
			rot = CFrame.Angles(0, 0, halo)
		end
		table.insert(parts, entry.part)
		-- Positive angle swings the limb forward (toward -Z).
		table.insert(cframes, base * entry.pivot * rot * entry.hang)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function setGuardianLook()
	local g = guardian
	local color = g.state == "sleep" and EYE_SLEEP or (frenzy() and EYE_FRENZY or EYE_HUNT)
	for _, eye in ipairs(g.eyes) do
		eye.Color = color
	end
	g.label.Text = g.state == "sleep" and "GUARDIAN  zzz" or (frenzy() and "GUARDIAN  ENRAGED" or "GUARDIAN")
	g.label.TextColor3 = g.state == "sleep" and Color3.fromRGB(255, 220, 200) or color
	workspace:SetAttribute("GuardianState", g.state)
end

function Threats.wakeGuardian(reason)
	if guardian.state ~= "sleep" then
		return
	end
	if reason == "heat" and Threats.guardianAtSea() then
		return
	end
	guardian.state = "awake"
	-- A grace period before its ranged moves, so the opening is a warning, not an ambush.
	guardian.nextLeapAt = now() + 2.5
	guardian.nextThrowAt = now() + 3.5
	guardian.nextStompAt = now() + 2
	setGuardianLook()
	poseGuardian()
	Net.broadcast("GuardianWake", { position = guardian.position, reason = reason })
end

-- Cast from the top of the map, so a ray never starts inside a cliff (the
-- mesa is taller than any step). The Guardian walks over the top of anything.
local function groundAt(x, z)
	local top = Config.BOUNDS_MAX.Y
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, Config.BOUNDS_MIN.Y - top, 0), groundParams)
	if not hit then
		return -2, true
	end
	return hit.Position.Y, hit.Material == Enum.Material.Water
end

local function inLeash(position)
	return frenzy() or Util.flatDistance(position, refs.templeCenter) <= Config.GUARDIAN_LEASH
end

-- The carrier holding the most valuable loot that the Guardian may chase.
local function guardianTarget()
	local best = nil
	for _, carrier in ipairs(Loot.carriers()) do
		local position = carrier.root.Position
		if inLeash(position) and not inWard(position) then
			local value = carrier.item.def.value
			local distance = (position - guardian.position).Magnitude
			if not best or value > best.value or (value == best.value and distance < best.distance) then
				best = { position = position, player = carrier.player, value = value, distance = distance }
			end
		end
	end
	if best then
		return best.position, best.player
	end
	local idol = Loot.byId.Idol
	if idol and idol.state == "loose" and inLeash(idol.core.Position) then
		return idol.core.Position, nil
	end
	return nil, nil
end

-- Returns true while it is still walking. The feet follow the ground every
-- step, even when it has stopped, so it never hangs off a cliff edge.
local function stepGuardianToward(dt, goal, stopDistance)
	local g = guardian
	local flat = Vector3.new(goal.X - g.position.X, 0, goal.Z - g.position.Z)
	local distance = flat.Magnitude
	local walking = distance > stopDistance
	local nextPos = g.position
	if walking then
		local speed = (frenzy() and Config.GUARDIAN_FRENZY_SPEED or Config.GUARDIAN_SPEED)
			* (g.wading and Config.GUARDIAN_WADE_MULT or 1)
		local step = math.min(speed * dt, distance - stopDistance)
		local direction = flat.Unit
		nextPos = g.position + direction * step
		if inWard(nextPos, 6) or not inLeash(nextPos) then
			return false
		end
		g.yaw = math.atan2(-direction.X, -direction.Z)
		g.phase += step * 0.28
	end
	local groundY, water = groundAt(nextPos.X, nextPos.Z)
	g.wading = water
	local targetY = water and groundY - 5 or groundY
	local dy = targetY - g.position.Y
	local y = g.position.Y + math.clamp(dy, -80 * dt, 60 * dt)
	g.position = Vector3.new(nextPos.X, y, nextPos.Z)
	return walking
end

-- The Guardian's moves beyond walking you down. All of them are announced first.
--   STOMP  up close: both fists go up, then a ring races out along the ground. Be in the air.
--   LEAP   a marked circle where you will be; it crouches, then jumps and lands on it.
--   THROW  a marked circle for a boulder from range, which is how it reaches boats and ledges.
local function guardianAttacks(g, targetPlayer, t)
	local root = Util.aliveRoot(targetPlayer)
	if not root then
		return
	end
	local flatDistance = Util.flatDistance(root.Position, g.position)
	local v = root.AssemblyLinearVelocity
	local velocity = Vector3.new(v.X, 0, v.Z)
	if
		t >= g.nextStompAt
		and flatDistance <= Config.GUARDIAN_STOMP_RANGE
		and math.abs(root.Position.Y - 3 - g.position.Y) < 12
	then
		g.nextStompAt = t + (frenzy() and Config.GUARDIAN_STOMP_GAP * 0.7 or Config.GUARDIAN_STOMP_GAP)
		g.stomp = { releaseAt = t + Config.GUARDIAN_STOMP_WINDUP }
		Net.broadcast("GuardianStomp", {
			position = g.position,
			radius = Config.GUARDIAN_STOMP_RADIUS,
			windup = Config.GUARDIAN_STOMP_WINDUP,
			speed = Config.GUARDIAN_STOMP_SPEED,
		})
		return
	end
	if t >= g.nextLeapAt and flatDistance >= Config.GUARDIAN_LEAP_MIN and flatDistance <= Config.GUARDIAN_LEAP_MAX then
		local aim = root.Position + velocity * (Config.GUARDIAN_LEAP_WINDUP + 0.3)
		if not inWard(aim, 6) and inLeash(aim) then
			local floorY, water = groundAt(aim.X, aim.Z)
			if not water then
				local to = Vector3.new(aim.X, floorY, aim.Z)
				local total = Config.GUARDIAN_LEAP_WINDUP + 0.65
				g.leap = { from = g.position, to = to, jumpAt = t + Config.GUARDIAN_LEAP_WINDUP, landAt = t + total }
				g.yaw = math.atan2(-(to.X - g.position.X), -(to.Z - g.position.Z))
				Net.broadcast("Marker", {
					position = to,
					radius = Config.GUARDIAN_LEAP_RADIUS,
					duration = total,
					color = Color3.fromRGB(255, 150, 60),
					style = "stomp",
				})
				Net.broadcast("GuardianLeap", { position = g.position })
				return
			end
		end
	end
	if
		t >= g.nextThrowAt
		and flatDistance >= Config.GUARDIAN_THROW_MIN
		and flatDistance <= Config.GUARDIAN_THROW_MAX
	then
		g.nextThrowAt = t + (frenzy() and Config.GUARDIAN_THROW_GAP * 0.7 or Config.GUARDIAN_THROW_GAP)
		local aim = root.Position + velocity * Config.GUARDIAN_THROW_DELAY * 0.9
		local floorY, water = groundAt(aim.X, aim.Z)
		local to = Vector3.new(aim.X, water and 0 or floorY, aim.Z)
		local from = g.position + Vector3.new(0, 18 * GS, 0)
		Net.broadcast("GuardianThrow", { from = from, to = to, duration = Config.GUARDIAN_THROW_DELAY })
		Blast.strike(to, Config.GUARDIAN_THROW_DELAY, {
			radius = Config.GUARDIAN_THROW_RADIUS,
			damage = 24,
			knockback = 72,
			hullDamage = 65,
			boatPush = 55,
			lootReason = "guardian",
			cause = "the Guardian",
			markerColor = Color3.fromRGB(255, 110, 60),
			style = "stomp",
			color = Color3.fromRGB(190, 120, 80),
		})
	end
end

local function tickGuardian(dt)
	local g = guardian
	local t = now()
	if g.state == "sail" then
		return -- in its boat, out at sea (Pursuit.lua draws it there)
	elseif g.state == "board" then
		-- V9: the leap from the temple onto its boat, in a long, high arc.
		local b = g.boarding
		local a = math.clamp((t - b.startAt) / (b.landAt - b.startAt), 0, 1)
		local p = b.from:Lerp(b.to, a)
		g.position = Vector3.new(p.X, p.Y + math.sin(math.pi * a) * b.height, p.Z)
		g.phase += dt * 12
		if a >= 1 then
			g.state = "sail"
			g.boarding = nil
			-- Out of sight under its island until the chase is over: the one in the boat is the Guardian now.
			g.position = refs.guardianLair.Position - Vector3.new(0, 400, 0)
			workspace:SetAttribute("GuardianState", "sail")
			Net.broadcast("GuardianSmash", { position = b.to })
		end
		poseGuardian()
		return
	elseif g.state == "sleep" then
		-- Asleep it doesn't move, so it isn't re-posed (no replication cost).
		if Heat.tier >= Config.GUARDIAN_WAKE_TIER then
			Threats.wakeGuardian("heat")
		end
		return
	end
	if g.leap then
		local leap = g.leap
		if t < leap.jumpAt then
			poseGuardian()
			return
		elseif t < leap.landAt then
			local a = (t - leap.jumpAt) / (leap.landAt - leap.jumpAt)
			local p = leap.from:Lerp(leap.to, a)
			g.position = Vector3.new(p.X, p.Y + math.sin(math.pi * a) * 24, p.Z)
			poseGuardian()
			return
		end
		g.position = leap.to
		g.leap = nil
		g.recoverUntil = t + 1.1
		g.nextLeapAt = t + (frenzy() and Config.GUARDIAN_LEAP_GAP * 0.7 or Config.GUARDIAN_LEAP_GAP)
		hurtArea(
			leap.to + Vector3.new(0, 5, 0),
			Config.GUARDIAN_LEAP_RADIUS,
			Config.GUARDIAN_LEAP_DAMAGE,
			Config.GUARDIAN_LEAP_KNOCKBACK,
			"guardianleap", -- the one hit of his that drops treasure at once: the marked circle
			16
		)
		Net.broadcast("GuardianSmash", { position = g.position })
		poseGuardian()
		return
	end
	if g.stomp then
		if t >= g.stomp.releaseAt then
			g.stomp = nil
			g.recoverUntil = t + 0.7
			table.insert(waves, { origin = g.position, startedAt = t, last = 0, hit = {} })
			Net.broadcast("GuardianSmash", { position = g.position })
		end
		poseGuardian()
		return
	end
	if t < g.recoverUntil then
		poseGuardian()
		return
	end

	local goal, targetPlayer = guardianTarget()
	if goal then
		g.hadTarget = targetPlayer ~= nil
		stepGuardianToward(dt, goal, targetPlayer and 4 or 7)
		if targetPlayer then
			guardianAttacks(g, targetPlayer, t)
		end
		-- Smash anyone close enough while chasing a carrier.
		if targetPlayer and t >= g.nextHitAt then
			local chest = g.position + Vector3.new(0, 6 * GS, 0)
			local targetRoot = Util.aliveRoot(targetPlayer)
			if
				targetRoot
				and Util.flatDistance(targetRoot.Position, chest) <= Config.GUARDIAN_HIT_RANGE * GS
				and math.abs(targetRoot.Position.Y - chest.Y) <= 14 * GS
			then
				g.nextHitAt = t + Config.GUARDIAN_HIT_COOLDOWN
				g.recoverUntil = t + Config.GUARDIAN_RECOVER
				hurtArea(
					chest,
					Config.GUARDIAN_HIT_RANGE * GS,
					Config.GUARDIAN_DAMAGE,
					Config.GUARDIAN_KNOCKBACK,
					"guardian",
					14
				)
				Net.broadcast("GuardianSmash", { position = g.position })
			end
		end
	else
		if g.hadTarget then
			g.hadTarget = false
			if not frenzy() then
				Net.feed("The Guardian stops at the edge of its temple... for now.", EYE_HUNT)
			end
		end
		local lair = refs.guardianLair.Position
		local idol = Loot.byId.Idol
		local idolOut = idol and (idol.state == "carried" or idol.state == "loose")
		local moving = stepGuardianToward(dt, lair, 2)
		if not moving and Heat.tier < Config.GUARDIAN_WAKE_TIER and not idolOut then
			g.state = "sleep"
			g.yaw = select(2, refs.guardianLair:ToEulerAnglesYXZ())
			setGuardianLook()
			poseGuardian()
			return
		end
	end
	poseGuardian()
end

-- A stomp's ring: it only hurts whoever is standing on the ground as it passes under them.
local function tickWaves(t)
	for i = #waves, 1, -1 do
		local wave = waves[i]
		local radius = (t - wave.startedAt) * Config.GUARDIAN_STOMP_SPEED
		for _, player in ipairs(Players:GetPlayers()) do
			local root, humanoid = Util.aliveRoot(player)
			if root and not wave.hit[player] and not humanoid.SeatPart then
				local distance = Util.flatDistance(root.Position, wave.origin)
				local level = math.abs(root.Position.Y - 3 - wave.origin.Y) < 10
				if level and distance >= wave.last - 3 and distance <= radius + 3 then
					-- A standing goblin's root is 3 studs up; anything higher is a jump.
					if workspace:Raycast(root.Position, Vector3.new(0, -5, 0), standParams) and Impact.open(player) then
						wave.hit[player] = true
						Impact.damage(humanoid, Config.GUARDIAN_STOMP_DAMAGE)
						local away = root.Position - wave.origin
						away = Vector3.new(away.X, 0, away.Z)
						away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
						Util.knockback(root, away * 40 + Vector3.new(0, Config.GUARDIAN_STOMP_KNOCKBACK, 0), 0.2)
						Loot.knockLoose(player, wave.origin, "guardian", nil)
					end
				end
			end
		end
		wave.last = radius
		if radius > Config.GUARDIAN_STOMP_RADIUS then
			table.remove(waves, i)
		end
	end
end

-- V9: the Golden Idol's thief is at sea: the Guardian leaps from wherever it stands onto its speedboat at
-- `point` (Pursuit.lua's forms.Temple), arriving `seconds` later. Until Threats.guardianReturn it is not on
-- its island.
function Threats.guardianBoard(point, seconds)
	local g = guardian
	if g.state == "sleep" then
		g.state = "awake"
		setGuardianLook()
	end
	g.leap, g.stomp = nil, nil
	local from = g.position
	local distance = Util.flatDistance(from, point)
	g.state = "board"
	g.boarding = {
		from = from,
		to = point,
		startAt = now(),
		landAt = now() + seconds,
		height = 40 + distance * 0.18,
	}
	g.yaw = math.atan2(-(point.X - from.X), -(point.Z - from.Z))
	workspace:SetAttribute("GuardianState", "board")
	Net.broadcast("GuardianLeap", { position = from })
end

-- The chase is over: the Guardian is back at its altar (asleep again unless the Idol is still out).
function Threats.guardianReturn()
	local g = guardian
	if g.state ~= "sail" and g.state ~= "board" then
		return
	end
	g.boarding = nil
	g.state = "awake"
	g.position = refs.guardianLair.Position
	g.recoverUntil = now() + 1
	setGuardianLook()
	poseGuardian()
end

function Threats.guardianAtSea()
	return guardian.state == "sail" or guardian.state == "board"
end

-- V13.2: the world's chaos landed near the Guardian (on its island): it reels for `seconds`. Returns true if it did.
function Threats.stagger(position, radius, seconds)
	if guardian.state ~= "awake" or not guardian.model then
		return false
	end
	if Util.flatDistance(guardian.position, position) > radius + 12 then
		return false
	end
	guardian.recoverUntil = math.max(guardian.recoverUntil, now() + seconds)
	return true
end

local function resetGuardian()
	local g = guardian
	g.boarding = nil
	g.stomp = nil
	g.nextStompAt = 0
	table.clear(waves)
	g.state = "sleep"
	g.position = refs.guardianLair.Position
	g.yaw = select(2, refs.guardianLair:ToEulerAnglesYXZ())
	g.nextHitAt = 0
	g.recoverUntil = 0
	g.hadTarget = false
	g.wading = false
	g.leap = nil
	g.nextLeapAt = 0
	g.nextThrowAt = 0
	setGuardianLook()
	poseGuardian()
end

-- Projectiles ----------------------------------------------------------------
local projectiles = {}
local blastParams = RaycastParams.new()
blastParams.FilterType = Enum.RaycastFilterType.Exclude
blastParams.RespectCanCollide = true
blastParams.IgnoreWater = false

local function explode(position)
	hurtArea(position, Config.BLAST_RADIUS, Config.BLAST_DAMAGE, Config.BLAST_KNOCKBACK, nil)
	Net.broadcast("Blast", { position = position, radius = Config.BLAST_RADIUS })
end

local function fireBlast(origin, targetPosition)
	local offset = targetPosition - origin
	if offset.Magnitude < 1 then
		explode(targetPosition)
		return
	end
	local ball = Instance.new("Part")
	ball.Name = "Blast"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.4, 2.4, 2.4)
	ball.Color = BLAST_COLOR
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(origin)
	local light = Instance.new("PointLight")
	light.Color = BLAST_COLOR
	light.Range = 10
	light.Parent = ball
	ball.Parent = refs.folders.fx
	table.insert(projectiles, {
		part = ball,
		position = origin,
		velocity = offset.Unit * Config.BLAST_SPEED,
		expiresAt = now() + math.min(Config.BLAST_MAX_TIME, offset.Magnitude / Config.BLAST_SPEED + 0.4),
	})
	Net.broadcast("TotemFire", { position = origin })
end

local function tickProjectiles(dt)
	local t = now()
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local nextPos = p.position + p.velocity * dt
		local hit = workspace:Raycast(p.position, nextPos - p.position, blastParams)
		local boom = hit and hit.Position
		if not boom then
			for _, player in ipairs(Players:GetPlayers()) do
				local root = Util.aliveRoot(player)
				if root and (root.Position - nextPos).Magnitude < 3 then
					boom = nextPos
					break
				end
			end
		end
		if not boom and t >= p.expiresAt then
			boom = nextPos
		end
		if boom then
			p.part:Destroy()
			table.remove(projectiles, i)
			explode(boom)
		else
			p.position = nextPos
			p.part.CFrame = CFrame.new(nextPos)
		end
	end
end

-- Totems ---------------------------------------------------------------------
local totems = {}
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true
losParams.IgnoreWater = true

local function stopCharge(totem)
	if totem.charging then
		totem.charging.beam:Destroy()
		totem.charging.aim:Destroy()
		totem.charging = nil
	end
end

local function startCharge(totem, player, root, delay, forced)
	stopCharge(totem)
	local aim = Instance.new("Attachment")
	aim.Name = "TotemAim"
	aim.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = totem.eyeAttachment
	beam.Attachment1 = aim
	beam.Color = ColorSequence.new(TOTEM_ACTIVE)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.25
	beam.Width1 = 0.6
	beam.Transparency = NumberSequence.new(0.2, 0.5)
	beam.Parent = totem.eye
	totem.charging = { player = player, aim = aim, beam = beam, fireAt = now() + delay, forced = forced }
	Net.broadcast("TotemCharge", { position = totem.eye.Position })
end

local function canSee(totem, root, ignore)
	losParams.FilterDescendantsInstances = ignore
	local from = totem.eye.Position
	local hit = workspace:Raycast(from, root.Position - from, losParams)
	return hit == nil
end

local function tickTotems()
	local t = now()
	local active = Heat.tier >= Config.TOTEM_TIER
	local interval = Config.TOTEM_INTERVAL[Heat.tier] or 4
	local carriers = Loot.carriers()
	for _, totem in ipairs(totems) do
		local busy = totem.charging ~= nil or totem.barrageLeft > 0
		totem.eye.Color = (active or busy) and TOTEM_ACTIVE or TOTEM_IDLE
		local charge = totem.charging
		if charge then
			local root = Util.aliveRoot(charge.player)
			if not root or (not charge.forced and not Loot.itemOf(charge.player)) then
				stopCharge(totem)
				totem.nextShotAt = t + 1
			elseif t >= charge.fireAt then
				local lead = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
					* Config.TOTEM_LEAD
				stopCharge(totem)
				fireBlast(totem.eye.Position, root.Position + lead)
				totem.nextShotAt = t + (charge.forced and Config.BARRAGE_GAP or interval)
			end
		elseif totem.barrageLeft > 0 and t >= totem.nextShotAt then
			local root = totem.barrageTarget and Util.aliveRoot(totem.barrageTarget)
			if root and (root.Position - totem.eye.Position).Magnitude < 250 then
				totem.barrageLeft -= 1
				startCharge(totem, totem.barrageTarget, root, 0.6, true)
			else
				totem.barrageLeft = 0
			end
		elseif active and t >= totem.nextShotAt then
			local best, bestDistance = nil, Config.TOTEM_RANGE
			for _, carrier in ipairs(carriers) do
				local distance = (carrier.root.Position - totem.eye.Position).Magnitude
				if distance < bestDistance and not inWard(carrier.root.Position) then
					local ignore = {
						totem.model,
						carrier.player.Character,
						refs.folders.loot,
						refs.folders.fx,
						refs.folders.bodies,
						refs.folders.threats,
					}
					if canSee(totem, carrier.root, ignore) then
						best, bestDistance = carrier, distance
					end
				end
			end
			if best then
				startCharge(totem, best.player, best.root, Config.TOTEM_TELEGRAPH, false)
			else
				totem.nextShotAt = t + 0.4 -- Look again soon.
			end
		end
	end
end

-- Trouble --------------------------------------------------------------------
local rollers = {} -- Boulders and falling rocks: hurt whoever they touch, once each.
local plug, plugUntil = nil, 0
local generation = 0 -- Bumped on reset, so delayed trouble from an old raid never lands.
local revealUntil = {} -- item -> time
local highlights = {} -- player -> Highlight

local function addRoller(part, radius, damage, knockback, dangerFor, lifetime)
	local t = now()
	table.insert(rollers, {
		part = part,
		radius = radius,
		damage = damage,
		knockback = knockback,
		dangerousUntil = t + dangerFor,
		expiresAt = t + lifetime,
		hit = {},
	})
end

local function spawnBoulder()
	local size = Config.BOULDER_SIZE
	local boulder = Instance.new("Part")
	boulder.Name = "Boulder"
	boulder.Shape = Enum.PartType.Ball
	boulder.Size = Vector3.new(size, size, size)
	boulder.Color = Color3.fromRGB(120, 100, 80)
	boulder.Material = Enum.Material.Slate
	boulder.CFrame = refs.boulderStart
	boulder.CustomPhysicalProperties = PhysicalProperties.new(2.5, 0.5, 0.1)
	boulder.Parent = refs.folders.fx
	pcall(function()
		boulder:SetNetworkOwner(nil)
	end)
	local direction = refs.boulderDirection
	boulder.AssemblyLinearVelocity = direction * Config.BOULDER_SPEED
	boulder.AssemblyAngularVelocity = Vector3.new(0, 1, 0):Cross(direction) * (Config.BOULDER_SPEED / (size / 2))
	addRoller(
		boulder,
		size / 2,
		Config.BOULDER_DAMAGE,
		Config.BOULDER_KNOCKBACK,
		Config.BOULDER_LIFETIME,
		Config.BOULDER_LIFETIME
	)
end

local function caveIn()
	local c = refs.caveIn
	local t = now()
	-- Seal the west tunnel, unless someone is standing exactly there.
	local occupied = false
	for _, player in ipairs(Players:GetPlayers()) do
		local root = Util.aliveRoot(player)
		if root then
			local p = c.plug:PointToObjectSpace(root.Position)
			if
				math.abs(p.X) < c.plugSize.X / 2 + 2
				and math.abs(p.Z) < c.plugSize.Z / 2 + 2
				and math.abs(p.Y) < c.plugSize.Y / 2 + 3
			then
				occupied = true
			end
		end
	end
	if not occupied and not plug then
		plug = Util.part(
			"CaveInPlug",
			c.plugSize,
			c.plug,
			Color3.fromRGB(80, 70, 90),
			Enum.Material.Slate,
			refs.folders.fx
		)
		plugUntil = t + Config.CAVE_IN_BLOCK_TIME
	end
	for _ = 1, Config.CAVE_IN_ROCKS do
		local size = 2 + math.random() * 2
		local position = Vector3.new(
			c.rockMin.X + math.random() * (c.rockMax.X - c.rockMin.X),
			c.rockMin.Y + math.random() * (c.rockMax.Y - c.rockMin.Y),
			c.rockMin.Z + math.random() * (c.rockMax.Z - c.rockMin.Z)
		)
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.new(size, size, size)
		rock.Color = Color3.fromRGB(90, 80, 100)
		rock.Material = Enum.Material.Slate
		rock.CFrame = CFrame.new(position)
		rock.Parent = refs.folders.fx
		addRoller(rock, size / 2, Config.CAVE_IN_DAMAGE, 25, 2, 6)
	end
	Net.broadcast("CaveIn", { position = c.plug.Position })
end

local function tickRollers()
	local t = now()
	for i = #rollers, 1, -1 do
		local r = rollers[i]
		local part = r.part
		if t >= r.expiresAt or not part.Parent or part.Position.Y < -40 then
			part:Destroy()
			table.remove(rollers, i)
		elseif t < r.dangerousUntil then
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if
					root
					and not r.hit[player]
					and (root.Position - part.Position).Magnitude <= r.radius + 2.5
					and Impact.open(player)
				then
					r.hit[player] = true
					Impact.damage(humanoid, r.damage)
					local away = root.Position - part.Position
					away = Vector3.new(away.X, 0, away.Z)
					away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
					Util.knockback(root, away * r.knockback + Vector3.new(0, r.knockback * 0.4, 0), 0.2)
					Loot.knockLoose(player, part.Position, "boulder", nil)
				end
			end
		end
	end
	if plug and t >= plugUntil then
		plug:Destroy()
		plug = nil
		Net.feed("The Crystal Isle tunnel is clear again.", Color3.fromRGB(215, 110, 255))
	end
end

local function updateReveal()
	local t = now()
	local byTier = Heat.tier >= Config.REVEAL_TIER
	local revealed = {}
	local bellRinging = false
	for _, carrier in ipairs(Loot.carriers()) do
		local bell = (revealUntil[carrier.item] or 0) > t
		bellRinging = bellRinging or bell
		local on = byTier or bell
		Loot.setRevealed(carrier.item, on)
		if on then
			revealed[carrier.player] = carrier.item
		end
	end
	for player, highlight in pairs(highlights) do
		if not revealed[player] or highlight.Parent ~= player.Character then
			highlight:Destroy()
			highlights[player] = nil
		end
	end
	for player, item in pairs(revealed) do
		if not highlights[player] and player.Character then
			local highlight = Instance.new("Highlight")
			highlight.Name = "CarrierReveal"
			highlight.FillColor = item.def.color
			highlight.FillTransparency = 0.7
			highlight.OutlineColor = item.def.color
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = player.Character
			highlights[player] = highlight
		end
	end
	if refs.lighthouseLamp then
		refs.lighthouseLamp.Color = bellRinging and Color3.fromRGB(255, 60, 50) or Color3.fromRGB(255, 240, 160)
	end
end

local TROUBLE_TEXT = {
	Guardian = "THE GUARDIAN AWAKENS!",
	CaveIn = "THE CAVE IS COLLAPSING!",
	Barrage = "THE WRECK'S CANNON OPENS FIRE!",
	Bell = "THE BELL TOLLS - THE THIEF IS REVEALED!",
}

-- Called when loot leaves its spot.
function Threats.onTaken(item, player)
	local trouble = item.def.trouble
	if trouble == "Guardian" then
		Threats.wakeGuardian("idol")
		-- A beat of rumble first, so the boulder is a warning, not a cheap shot.
		local current = generation
		task.delay(0.8, function()
			if current == generation then
				spawnBoulder()
			end
		end)
	elseif trouble == "CaveIn" then
		caveIn()
	elseif trouble == "Barrage" then
		local cannon = refs.wreckCannon
		if cannon then
			for _, totem in ipairs(totems) do
				if totem.model == cannon.model then
					totem.barrageLeft = Config.BARRAGE_SHOTS
					totem.barrageTarget = player
					totem.nextShotAt = now() + 0.3
				end
			end
		end
	elseif trouble == "Bell" then
		revealUntil[item] = now() + Config.BELL_REVEAL_TIME
	elseif Threats.handlers[trouble] then
		Threats.handlers[trouble](item, player)
	end
	Net.broadcast("Trouble", {
		kind = trouble,
		position = item.spot.Position,
		text = TROUBLE_TEXT[trouble] or Threats.text[trouble],
	})
end

-- Lifecycle ------------------------------------------------------------------
function Threats.build(worldRefs)
	refs = worldRefs
	buildGuardian()
	for _, info in ipairs(refs.totems) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "TotemEye"
		attachment.Parent = info.eye
		table.insert(totems, {
			model = info.model,
			eye = info.eye,
			eyeAttachment = attachment,
			kind = info.kind,
			nextShotAt = 0,
			charging = nil,
			barrageLeft = 0,
			barrageTarget = nil,
		})
	end
	local exclude = { refs.folders.fx, refs.folders.threats, refs.folders.loot, refs.folders.bodies }
	for _, totem in ipairs(totems) do
		table.insert(exclude, totem.model)
	end
	blastParams.FilterDescendantsInstances = exclude
	Heat.TierChanged:Connect(function(tier, old)
		if tier > old then
			local info = Heat.tierInfo(tier)
			Net.broadcast("HeatTier", { tier = tier, name = info.name, hint = info.hint })
		end
	end)
	resetGuardian()
end

function Threats.tick(dt)
	tickGuardian(dt)
	tickWaves(now())
	tickTotems()
	tickProjectiles(dt)
	tickRollers()
	updateReveal()
end

function Threats.reset()
	generation += 1
	resetGuardian()
	for _, p in ipairs(projectiles) do
		p.part:Destroy()
	end
	table.clear(projectiles)
	for _, r in ipairs(rollers) do
		r.part:Destroy()
	end
	table.clear(rollers)
	if plug then
		plug:Destroy()
		plug = nil
	end
	for _, totem in ipairs(totems) do
		stopCharge(totem)
		totem.nextShotAt = 0
		totem.barrageLeft = 0
		totem.barrageTarget = nil
		totem.eye.Color = TOTEM_IDLE
	end
	table.clear(revealUntil)
	for _, highlight in pairs(highlights) do
		highlight:Destroy()
	end
	table.clear(highlights)
	if refs.lighthouseLamp then
		refs.lighthouseLamp.Color = Color3.fromRGB(255, 240, 160)
	end
end

-- Hooks for Troubles.lua.
function Threats.reveal(item, seconds)
	revealUntil[item] = now() + seconds
end

function Threats.generation()
	return generation
end

Threats.addRoller = addRoller

return Threats

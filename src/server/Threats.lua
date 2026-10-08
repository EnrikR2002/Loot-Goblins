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
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)

local Threats = {}
local refs

local GUARDIAN_STONE = Color3.fromRGB(150, 70, 60)
local GUARDIAN_DARK = Color3.fromRGB(90, 45, 40)
local EYE_SLEEP = Color3.fromRGB(60, 25, 25)
local EYE_HUNT = Color3.fromRGB(255, 60, 40)
local EYE_FRENZY = Color3.fromRGB(255, 170, 40)
local TOTEM_IDLE = Color3.fromRGB(90, 30, 30)
local TOTEM_ACTIVE = Color3.fromRGB(255, 80, 40)
local BLAST_COLOR = Color3.fromRGB(255, 120, 40)

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
			if inRange then
				Util.damage(humanoid, damage)
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
	state = "sleep", -- "sleep" | "awake"
	nextHitAt = 0,
	recoverUntil = 0,
	phase = 0,
	wading = false,
	hadTarget = false,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false

local function buildGuardian()
	local model = Instance.new("Model")
	model.Name = "Guardian"
	local function gpart(name, size, color, material, pivot, hang)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		-- pivot: joint position in the rig; hang: offset from joint to part center.
		table.insert(guardian.parts, { part = p, name = name, pivot = pivot, hang = hang or CFrame.new() })
		return p
	end
	-- The rig's origin is between the feet.
	local torso = gpart("Torso", Vector3.new(9, 9, 6), GUARDIAN_STONE, Enum.Material.Slate, CFrame.new(0, 11.5, 0))
	local head = gpart("Head", Vector3.new(6, 5, 5), GUARDIAN_STONE, Enum.Material.Slate, CFrame.new(0, 18.5, -0.5))
	gpart("Brow", Vector3.new(6.4, 1.2, 1.4), GUARDIAN_DARK, Enum.Material.Slate, CFrame.new(0, 20, -2.6))
	local eyeL = gpart("Eye", Vector3.new(1.3, 0.9, 0.4), EYE_SLEEP, Enum.Material.Neon, CFrame.new(-1.4, 19, -3.05))
	local eyeR = gpart("Eye", Vector3.new(1.3, 0.9, 0.4), EYE_SLEEP, Enum.Material.Neon, CFrame.new(1.4, 19, -3.05))
	gpart(
		"ArmL",
		Vector3.new(3, 9, 3),
		GUARDIAN_DARK,
		Enum.Material.Slate,
		CFrame.new(-6.2, 15.5, 0),
		CFrame.new(0, -4.5, 0)
	)
	gpart(
		"ArmR",
		Vector3.new(3, 9, 3),
		GUARDIAN_DARK,
		Enum.Material.Slate,
		CFrame.new(6.2, 15.5, 0),
		CFrame.new(0, -4.5, 0)
	)
	gpart(
		"FistL",
		Vector3.new(3.6, 3.6, 3.6),
		GUARDIAN_STONE,
		Enum.Material.Slate,
		CFrame.new(-6.2, 15.5, 0),
		CFrame.new(0, -9.5, 0)
	)
	gpart(
		"FistR",
		Vector3.new(3.6, 3.6, 3.6),
		GUARDIAN_STONE,
		Enum.Material.Slate,
		CFrame.new(6.2, 15.5, 0),
		CFrame.new(0, -9.5, 0)
	)
	gpart(
		"LegL",
		Vector3.new(3.4, 7, 3.4),
		GUARDIAN_DARK,
		Enum.Material.Slate,
		CFrame.new(-2.4, 7, 0),
		CFrame.new(0, -3.5, 0)
	)
	gpart(
		"LegR",
		Vector3.new(3.4, 7, 3.4),
		GUARDIAN_DARK,
		Enum.Material.Slate,
		CFrame.new(2.4, 7, 0),
		CFrame.new(0, -3.5, 0)
	)
	gpart("Moss", Vector3.new(9.2, 1.5, 6.2), Color3.fromRGB(70, 140, 60), Enum.Material.Grass, CFrame.new(0, 16.3, 0))
	model.PrimaryPart = torso
	guardian.eyes = { eyeL, eyeR }

	local gui = Instance.new("BillboardGui")
	gui.Name = "GuardianTag"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.MaxDistance = 400
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
end

local function poseGuardian()
	local g = guardian
	local sleeping = g.state == "sleep"
	local recovering = now() < g.recoverUntil
	local swing = sleeping and 0 or math.sin(g.phase) * 0.6
	local bob = sleeping and -3 or math.abs(math.sin(g.phase)) * 0.6
	local base = CFrame.new(g.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, g.yaw, 0)
	if sleeping then
		base *= CFrame.Angles(math.rad(12), 0, 0)
	end
	local parts, cframes = {}, {}
	for _, entry in ipairs(g.parts) do
		local angle = 0
		if entry.name == "ArmL" or entry.name == "FistL" then
			angle = recovering and 1.3 or swing
		elseif entry.name == "ArmR" or entry.name == "FistR" then
			angle = recovering and 1.3 or -swing
		elseif entry.name == "LegL" then
			angle = -swing * 0.8
		elseif entry.name == "LegR" then
			angle = swing * 0.8
		end
		table.insert(parts, entry.part)
		-- Positive angle swings the limb forward (toward -Z).
		table.insert(cframes, base * entry.pivot * CFrame.Angles(angle, 0, 0) * entry.hang)
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
	guardian.state = "awake"
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

local function tickGuardian(dt)
	local g = guardian
	local t = now()
	if g.state == "sleep" then
		-- Asleep it doesn't move, so it isn't re-posed (no replication cost).
		if Heat.tier >= Config.GUARDIAN_WAKE_TIER then
			Threats.wakeGuardian("heat")
		end
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
		-- Smash anyone close enough while chasing a carrier.
		if targetPlayer and t >= g.nextHitAt then
			local chest = g.position + Vector3.new(0, 6, 0)
			local targetRoot = Util.aliveRoot(targetPlayer)
			if
				targetRoot
				and Util.flatDistance(targetRoot.Position, chest) <= Config.GUARDIAN_HIT_RANGE
				and math.abs(targetRoot.Position.Y - chest.Y) <= 14
			then
				g.nextHitAt = t + Config.GUARDIAN_HIT_COOLDOWN
				g.recoverUntil = t + Config.GUARDIAN_RECOVER
				hurtArea(
					chest,
					Config.GUARDIAN_HIT_RANGE,
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

local function resetGuardian()
	local g = guardian
	g.state = "sleep"
	g.position = refs.guardianLair.Position
	g.yaw = select(2, refs.guardianLair:ToEulerAnglesYXZ())
	g.nextHitAt = 0
	g.recoverUntil = 0
	g.hadTarget = false
	g.wading = false
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
				if root and not r.hit[player] and (root.Position - part.Position).Magnitude <= r.radius + 2.5 then
					r.hit[player] = true
					Util.damage(humanoid, r.damage)
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
	end
	Net.broadcast("Trouble", { kind = trouble, position = item.spot.Position, text = TROUBLE_TEXT[trouble] })
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

return Threats

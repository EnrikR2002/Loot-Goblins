-- Cannons: the heavy interference tool. They stand on islands (Fort Barnacle's wall, the home
-- practice range) and ride on the Cutter and the Navy's patrol ships. Stand at one, press its
-- prompt (E) and the cannon fires where you aim. The client only sends the aim point; the server
-- checks you are really at the cannon, enforces the cooldown, solves the arc, flies the ball and
-- decides what it hits.
--
-- A cannonball is a Blast with the biggest numbers in the game: it opens gates, snaps bridges,
-- wrecks boats, knocks loot loose and throws people. It is also how players sink the Navy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Blast = require(script.Parent.Blast)

local Cannons = {}
Cannons.entries = {}

local refs
local shots = {}
local flightParams = RaycastParams.new()
flightParams.FilterType = Enum.RaycastFilterType.Exclude
flightParams.IgnoreWater = true
flightParams.RespectCanCollide = true

local function now()
	return workspace:GetServerTimeNow()
end

local function finite(v)
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e5
		and math.abs(v.Y) < 1e5
		and math.abs(v.Z) < 1e5
end

-- The world position of an entry's breech.
local function pivotOf(entry)
	if entry.boat then
		return entry.boat.hull.CFrame:PointToWorldSpace(entry.localPivot)
	end
	return entry.pivot
end

-- The low arc that lands on the target with the cannon's muzzle speed, or 45 degrees if it is
-- out of range. Returns a unit direction.
local function solve(origin, target)
	local g, speed = Config.CANNON_GRAVITY, Config.CANNON_SPEED
	local delta = target - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = flat.Magnitude
	if distance < 1 then
		return Vector3.yAxis
	end
	local v2 = speed * speed
	local disc = v2 * v2 - g * (g * distance * distance + 2 * delta.Y * v2)
	local angle = disc < 0 and math.rad(45) or math.atan2(v2 - math.sqrt(disc), g * distance)
	angle = math.clamp(angle, math.rad(-6), math.rad(62))
	return flat.Unit * math.cos(angle) + Vector3.yAxis * math.sin(angle)
end

local function aimBarrel(entry, direction)
	local pivot = pivotOf(entry)
	local desired = CFrame.lookAt(pivot, pivot + direction) * CFrame.new(0, 0, -3)
	if entry.boat then
		entry.weld.C0 = entry.base.CFrame:ToObjectSpace(desired)
		entry.weld.C1 = CFrame.new()
	else
		entry.barrel.CFrame = desired
	end
end

local function exclusions(entry)
	local list = { refs.folders.fx, refs.folders.loot, refs.folders.bodies, refs.folders.threats, refs.folders.decor }
	if entry.boat then
		table.insert(list, entry.boat.model)
	else
		table.insert(list, entry.model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Fires a ball from the entry toward a world point. Returns true if it fired.
function Cannons.launch(entry, aimPoint, owner)
	local pivot = pivotOf(entry)
	local direction = solve(pivot, aimPoint)
	aimBarrel(entry, direction)
	local muzzle = pivot + direction * 6
	local ball = Instance.new("Part")
	ball.Name = "Cannonball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.2, 2.2, 2.2)
	ball.Color = Color3.fromRGB(30, 30, 34)
	ball.Material = Enum.Material.Metal
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CFrame = CFrame.new(muzzle)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a1.Position = Vector3.new(0, -0.9, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120))
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = ball
	ball.Parent = refs.folders.fx
	local inherit = entry.boat and entry.boat.hull.AssemblyLinearVelocity or Vector3.zero
	table.insert(shots, {
		part = ball,
		position = muzzle,
		velocity = direction * Config.CANNON_SPEED + Vector3.new(inherit.X, 0, inherit.Z) * 0.5,
		owner = owner,
		entry = entry,
		expiresAt = now() + 6,
		ignore = exclusions(entry),
	})
	Net.broadcast("CannonFire", { position = muzzle, direction = direction })
	return true
end

local function explodeShot(shot, position)
	shot.part:Destroy()
	Blast.at(position, {
		radius = Config.CANNON_RADIUS,
		damage = Config.CANNON_DAMAGE,
		knockback = Config.CANNON_KNOCKBACK,
		hullDamage = Config.CANNON_HULL_DAMAGE,
		boatPush = Config.CANNON_BOAT_PUSH,
		breakPower = 2,
		lootReason = "cannon",
		owner = shot.owner,
		cause = shot.owner and (shot.owner.DisplayName .. "'s cannon") or "a cannon",
		color = Color3.fromRGB(255, 170, 70),
	})
	if refs.targets then
		for _, target in ipairs(refs.targets) do
			if (target.Position - position).Magnitude < 9 then
				Net.feed(
					(shot.owner and shot.owner.DisplayName or "Someone") .. " hit a target!",
					Color3.fromRGB(255, 220, 120)
				)
				Net.broadcast("TargetHit", { position = target.Position })
				break
			end
		end
	end
end

function Cannons.tick(dt)
	local t = now()
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local nextPosition = shot.position + shot.velocity * dt
		local nextVelocity = shot.velocity - Vector3.new(0, Config.CANNON_GRAVITY * dt, 0)
		flightParams.FilterDescendantsInstances = shot.ignore
		local hit = workspace:Raycast(shot.position, nextPosition - shot.position, flightParams)
		local boom
		if hit then
			boom = hit.Position
		elseif nextPosition.Y <= 0.3 and shot.velocity.Y < 0 then
			-- The sea: the splash still wrecks boats it lands on.
			boom = Vector3.new(nextPosition.X, 0.3, nextPosition.Z)
		elseif t >= shot.expiresAt then
			boom = nextPosition
		end
		if boom then
			table.remove(shots, i)
			explodeShot(shot, boom)
		else
			shot.position = nextPosition
			shot.velocity = nextVelocity
			shot.part.CFrame = CFrame.new(nextPosition)
		end
	end
end

local function findEntry(base)
	for _, entry in ipairs(Cannons.entries) do
		if entry.base == base then
			return entry
		end
	end
	return nil
end

local function onFire(player, base, aimPoint)
	if typeof(base) ~= "Instance" or typeof(aimPoint) ~= "Vector3" or not finite(aimPoint) then
		return
	end
	local entry = findEntry(base)
	local root = Util.aliveRoot(player)
	if not entry or not root or not base.Parent then
		return
	end
	if entry.boat and entry.boat.state ~= "float" then
		return
	end
	if (root.Position - base.Position).Magnitude > 18 then
		return
	end
	local t = now()
	if t < (entry.readyAt or 0) then
		return
	end
	-- The aim has to be somewhere in front of the world, not a number to crash the solver.
	if (aimPoint - base.Position).Magnitude > 3000 then
		return
	end
	entry.readyAt = t + Config.CANNON_COOLDOWN
	base:SetAttribute("ReadyAt", entry.readyAt)
	Cannons.launch(entry, aimPoint, player)
end

-- Boat-mounted cannons ride on the hull: welded parts and a weld whose offset aims the barrel.
function Cannons.mountOnBoat(boat)
	local hull = boat.hull
	local size = boat.spec.size
	local spots = boat.typeName == "navy" and { Vector3.new(-4.5, 0, -8), Vector3.new(4.5, 0, -8) }
		or { Vector3.new(0, 0, -size.Z * 0.26) }
	for _, spot in ipairs(spots) do
		local pivot = Vector3.new(spot.X, size.Y / 2 + 2.6, spot.Z)
		local base = Instance.new("Part")
		base.Name = "CannonBase"
		base.Size = Vector3.new(4.6, 1.4, 5.4)
		base.Color = Color3.fromRGB(70, 48, 32)
		base.Material = Enum.Material.WoodPlanks
		base.CFrame = hull.CFrame * CFrame.new(spot.X, size.Y / 2 + 0.7, spot.Z)
		base.CanCollide = false
		base.Massless = true
		local weldBase = Instance.new("WeldConstraint")
		weldBase.Part0, weldBase.Part1 = hull, base
		weldBase.Parent = base
		base.Parent = boat.model
		local barrel = Instance.new("Part")
		barrel.Name = "CannonBarrel"
		barrel.Size = Vector3.new(2.4, 2.4, 7)
		barrel.Color = Color3.fromRGB(58, 58, 66)
		barrel.Material = Enum.Material.Metal
		barrel.CanCollide = false
		barrel.Massless = true
		barrel.CFrame = hull.CFrame * CFrame.new(pivot) * CFrame.new(0, 0, -3)
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = base, barrel
		weld.C0 = base.CFrame:ToObjectSpace(barrel.CFrame)
		weld.Parent = barrel
		barrel.Parent = boat.model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CannonPrompt"
		prompt.ObjectText = boat.spec.name .. " cannon"
		prompt.ActionText = "Fire cannon"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = base
		table.insert(
			Cannons.entries,
			{ base = base, barrel = barrel, weld = weld, boat = boat, localPivot = pivot, name = prompt.ObjectText }
		)
		boat.cannons = boat.cannons or {}
		table.insert(boat.cannons, Cannons.entries[#Cannons.entries])
	end
end

function Cannons.build(worldRefs)
	refs = worldRefs
	for _, entry in ipairs(refs.cannons) do
		table.insert(Cannons.entries, entry)
	end
	for _, boat in ipairs(Boats.list) do
		if boat.spec.cannons then
			Cannons.mountOnBoat(boat)
		end
	end
	Net.Cannon.OnServerEvent:Connect(onFire)
end

-- An AI boat (the Navy) fires one of its cannons at a point.
function Cannons.fireAI(boat, aimPoint)
	for _, entry in ipairs(boat.cannons or {}) do
		if now() >= (entry.readyAt or 0) then
			entry.readyAt = now() + Config.CANNON_COOLDOWN * 1.6
			Cannons.launch(entry, aimPoint, nil)
			return true
		end
	end
	return false
end

-- A boat built later (an AI ship) gets its guns when it spawns.
function Cannons.mountIfArmed(boat)
	if boat.spec.cannons and not boat.cannons then
		Cannons.mountOnBoat(boat)
	end
end

function Cannons.reset()
	for _, shot in ipairs(shots) do
		shot.part:Destroy()
	end
	table.clear(shots)
	for _, entry in ipairs(Cannons.entries) do
		entry.readyAt = 0
	end
end

return Cannons

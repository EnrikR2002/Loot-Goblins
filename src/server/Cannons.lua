-- Cannons: the heavy interference tool. They stand on islands (Fort Barnacle's wall, the home
-- practice range) and ride on the Cutter and the Navy's patrol ships. Stand at one, press its
-- prompt (E) and the cannon fires where you aim. The client only sends the aim point; the server
-- checks you are really at the cannon, enforces the cooldown, solves the arc, flies the ball and
-- decides what it hits.
--
-- A cannonball is a Blast with the biggest numbers in the game: it opens gates, snaps bridges,
-- wrecks boats, knocks loot loose and throws people. It is also how players sink the Navy.
--
-- V13.2: EVERY BOAT HAS A BOW GUN its driver fires with a click (gamepad R2, the touch GUN button): Cannons.driverFire.
-- It is light (Config.BOAT_GUN): it shoves and splashes, never knocks treasure loose, never sinks a boat by itself, and
-- a hull it hit a moment ago takes the next shot at half strength (no juggling). It never fires from the Port or the
-- Hoard's ward, and never reaches anyone standing in either (Blast.safe).
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

-- Fires a ball from the entry toward a world point. Returns true if it fired. V13: `profile` (optional) is a table of
-- blast numbers (Config.BOAT_SHOT: the light, shoving shot of the Broadside and the Cutter's bow gun); an entry may
-- carry its own (entry.profile). Without one it is a full cannonball (Config.CANNON_*).
function Cannons.launch(entry, aimPoint, owner, profile)
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
		profile = profile or entry.profile,
		expiresAt = now() + 6,
		ignore = exclusions(entry),
	})
	Net.broadcast("CannonFire", { position = muzzle, direction = direction })
	return true
end

-- V13.2: a bow gun's shot that lands within BOAT_GUN.sameBoatGrace of the last one on the same hull is halved.
local gunHitAt = setmetatable({}, { __mode = "k" }) -- boat -> server time a bow gun last hit it

local function explodeShot(shot, position)
	shot.part:Destroy()
	local p = shot.profile
	if p and p.bowGun then
		-- Its own little blast: shove and splash only (no loot, no sinking: the world floor applies).
		local G = Config.BOAT_GUN
		local t = now()
		local scaled = {}
		for _, boat in ipairs(Boats.list) do
			if boat ~= shot.entry.boat and boat.state == "float" and not Cannons.inSafeZone(boat.hull.Position) then
				local reach = G.radius + boat.spec.size.Z * 0.4
				if (boat.hull.Position - position).Magnitude < reach then
					scaled[boat] = t - (gunHitAt[boat] or -math.huge) < G.sameBoatGrace and 0.5 or 1
					gunHitAt[boat] = t
				end
			end
		end
		for boat, k in pairs(scaled) do
			local offset = boat.hull.Position - position
			local falloff = math.clamp(1 - offset.Magnitude / (G.radius + boat.spec.size.Z * 0.4), 0.3, 1) * k
			local away = Vector3.new(offset.X, 0, offset.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
			Boats.damage(
				boat,
				math.min(G.hullDamage * falloff, math.max(0, boat.health - boat.spec.health * 0.25)),
				nil
			)
			Boats.shove(boat, (away * G.boatPush + Vector3.new(0, G.boatPush * 0.45, 0)) * falloff)
		end
		Blast.at(position, {
			radius = G.radius,
			damage = G.damage,
			knockback = G.knockback,
			owner = shot.owner,
			wardSafe = true,
			cause = shot.owner and (shot.owner.DisplayName .. "'s bow gun") or "a bow gun",
			color = Color3.fromRGB(255, 200, 110),
		})
		return
	end
	Blast.at(position, {
		radius = p and p.radius or Config.CANNON_RADIUS,
		damage = p and p.damage or Config.CANNON_DAMAGE,
		knockback = p and p.knockback or Config.CANNON_KNOCKBACK,
		hullDamage = p and p.hullDamage or Config.CANNON_HULL_DAMAGE,
		boatPush = p and p.boatPush or Config.CANNON_BOAT_PUSH,
		breakPower = p and 1 or 2,
		lootReason = "cannon",
		owner = shot.owner,
		-- V13: another goblin's boat gun cannot reach someone standing at home or in the Port.
		wardSafe = shot.owner ~= nil and shot.entry.boat ~= nil,
		exceptBoat = shot.entry.boat,
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
	if not entry or not root or not base.Parent or entry.driver then
		return -- (V13.2: a driver's bow gun is fired through Cannons.driverFire, never through a prompt)
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
	-- V13: a side gun (the Broadside's) only fires out over its own side.
	if entry.side and entry.boat then
		local hull = entry.boat.hull
		local out = hull.CFrame.RightVector * entry.side
		local toward = Vector3.new(aimPoint.X - base.Position.X, 0, aimPoint.Z - base.Position.Z)
		if toward.Magnitude < 1 or toward.Unit:Dot(Vector3.new(out.X, 0, out.Z).Unit) < 0.15 then
			Net.toast(player, "This gun fires over its own side.")
			return
		end
	end
	entry.readyAt = t + (entry.cooldown or Config.CANNON_COOLDOWN)
	base:SetAttribute("ReadyAt", entry.readyAt)
	Cannons.launch(entry, aimPoint, player)
end

-- Boat-mounted cannons ride on the hull: welded parts and a weld whose offset aims the barrel.
-- V13.2: every player class gets a small driver's bow gun (no prompt: the driver clicks), on top of the Cutter's deck
-- cannon and the Broadside's two side guns, which friends still man with E.
function Cannons.mountOnBoat(boat)
	local hull = boat.hull
	local size = boat.spec.size
	local spots = {}
	local sides = {}
	local drivers = {}
	if boat.typeName == "navy" then
		spots = { Vector3.new(-4.5, 0, -8), Vector3.new(4.5, 0, -8) }
	else
		if boat.spec.class then
			table.insert(spots, Vector3.new(0, 0, -size.Z * 0.4))
			drivers[#spots] = true
		end
		if boat.spec.cannons then
			table.insert(spots, Vector3.new(0, 0, -size.Z * 0.26))
		end
		-- V13: the Broadside's two gunner cannons, one each side by a passenger seat, firing the light shot.
		if boat.spec.broadside then
			table.insert(spots, Vector3.new(-(size.X / 2 - 2.2), 0, 2.5))
			sides[#spots] = -1
			table.insert(spots, Vector3.new(size.X / 2 - 2.2, 0, 2.5))
			sides[#spots] = 1
		end
	end
	for index, spot in ipairs(spots) do
		local driver = drivers[index] == true
		local scale = driver and 0.6 or 1
		local pivot = Vector3.new(spot.X, size.Y / 2 + (driver and 1.6 or 2.6), spot.Z)
		local base = Instance.new("Part")
		base.Name = driver and "BowGunBase" or "CannonBase"
		base.Size = Vector3.new(4.6, 1.4, 5.4) * scale
		base.Color = Color3.fromRGB(70, 48, 32)
		base.Material = Enum.Material.WoodPlanks
		base.CFrame = hull.CFrame * CFrame.new(spot.X, size.Y / 2 + 0.7 * scale, spot.Z)
		base.CanCollide = false
		base.CanQuery = false
		base.Massless = true
		local weldBase = Instance.new("WeldConstraint")
		weldBase.Part0, weldBase.Part1 = hull, base
		weldBase.Parent = base
		base.Parent = boat.model
		local barrel = Instance.new("Part")
		barrel.Name = driver and "BowGunBarrel" or "CannonBarrel"
		barrel.Size = Vector3.new(2.4, 2.4, 7) * scale
		barrel.Color = Color3.fromRGB(58, 58, 66)
		barrel.Material = Enum.Material.Metal
		barrel.CanCollide = false
		barrel.CanQuery = false
		barrel.Massless = true
		barrel.CFrame = hull.CFrame * CFrame.new(pivot) * CFrame.new(0, 0, -3 * scale)
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = base, barrel
		weld.C0 = base.CFrame:ToObjectSpace(barrel.CFrame)
		weld.Parent = barrel
		barrel.Parent = boat.model
		if driver then
			-- The driver's gun: no prompt (a click fires it), the light shot, its own cooldown on the model.
			local entry = {
				base = base,
				barrel = barrel,
				weld = weld,
				boat = boat,
				localPivot = pivot,
				name = "Bow gun",
				driver = true,
				profile = { bowGun = true },
				cooldown = Config.BOAT_GUN.cooldown,
			}
			table.insert(Cannons.entries, entry)
			boat.cannons = boat.cannons or {}
			table.insert(boat.cannons, entry)
			continue
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CannonPrompt"
		prompt.ObjectText = boat.spec.name .. " cannon"
		prompt.ActionText = "Fire cannon"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = base
		local side = sides[index]
		if side then
			prompt.ObjectText = (side < 0 and "Port" or "Starboard") .. " gun"
			-- Its barrel points out over its side until someone aims it.
			weld.C0 = base.CFrame:ToObjectSpace(
				CFrame.lookAt(barrel.Position, barrel.Position + hull.CFrame.RightVector * side) * CFrame.new(0, 0, -1)
			)
		end
		table.insert(Cannons.entries, {
			base = base,
			barrel = barrel,
			weld = weld,
			boat = boat,
			localPivot = pivot,
			name = prompt.ObjectText,
			side = side,
			profile = side and Config.BOAT_SHOT or nil,
			cooldown = side and 3.4 or nil,
		})
		boat.cannons = boat.cannons or {}
		table.insert(boat.cannons, Cannons.entries[#Cannons.entries])
	end
end

-- V13: a boat's own gun fired by its driver (the Broadside's volley): server/BoatAbilities.lua. `side` picks the
-- Broadside's gun (-1 port, 1 starboard); nil picks the deck cannon (V13.2: never the driver's bow gun). Returns the
-- entry used, or nil.
function Cannons.boatGun(boat, side)
	for _, entry in ipairs(boat.cannons or {}) do
		if entry.side == side and not entry.driver then
			return entry
		end
	end
	return nil
end

-- V13.2: the driver's bow gun on this boat, or nil.
function Cannons.bowGun(boat)
	for _, entry in ipairs(boat.cannons or {}) do
		if entry.driver then
			return entry
		end
	end
	return nil
end

-- V13.2: the driver clicked. aimPoint: where they were looking. The server checks they drive this boat, it floats, the
-- gun is loaded, the shot goes forward of the bow and the boat is not in the Port or at home; a far aim is brought in
-- to the gun's range. Returns true if it fired, or false and a reason for the driver.
Cannons.inSafeZone = function(_position)
	return false
end
function Cannons.driverFire(player, boat, aimPoint)
	if not boat or boat.state ~= "float" then
		return false, nil
	end
	local entry = Cannons.bowGun(boat)
	if not entry then
		return false, nil
	end
	local t = now()
	if t < (entry.readyAt or 0) - 0.1 then
		return false, nil
	end
	local G = Config.BOAT_GUN
	local hull = boat.hull
	if Cannons.inSafeZone(hull.Position) then
		return false, "No cannons in the Port or at home."
	end
	local look = Vector3.new(hull.CFrame.LookVector.X, 0, hull.CFrame.LookVector.Z)
	look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
	local from = pivotOf(entry)
	local toward = typeof(aimPoint) == "Vector3"
			and finite(aimPoint)
			and Vector3.new(aimPoint.X - from.X, 0, aimPoint.Z - from.Z)
		or look * G.range
	if toward.Magnitude < 12 or toward.Unit:Dot(look) < G.arc then
		-- Behind or beside the arc: it fires straight ahead instead (a click is never wasted).
		toward = look * math.min(G.range, math.max(60, toward.Magnitude))
	elseif toward.Magnitude > G.range then
		toward = toward.Unit * G.range
	end
	local target = Vector3.new(
		from.X + toward.X,
		math.max(0, typeof(aimPoint) == "Vector3" and aimPoint.Y or 0),
		from.Z + toward.Z
	)
	if target.Y > from.Y + 40 then
		target = Vector3.new(target.X, from.Y + 40, target.Z)
	end
	entry.readyAt = t + G.cooldown
	boat.model:SetAttribute("GunReadyAt", entry.readyAt)
	Cannons.launch(entry, target, player, entry.profile)
	return true, nil
end

function Cannons.build(worldRefs)
	refs = worldRefs
	for _, entry in ipairs(refs.cannons) do
		table.insert(Cannons.entries, entry)
	end
	for _, boat in ipairs(Boats.list) do
		if boat.spec.class or boat.spec.cannons or boat.spec.broadside then
			Cannons.mountOnBoat(boat)
		end
	end
	Net.Cannon.OnServerEvent:Connect(onFire)
end

-- An AI boat (the Navy) fires one of its cannons at a point.
function Cannons.fireAI(boat, aimPoint)
	for _, entry in ipairs(boat.cannons or {}) do
		if now() >= (entry.readyAt or 0) and not entry.driver then
			entry.readyAt = now() + Config.CANNON_COOLDOWN * 1.6
			Cannons.launch(entry, aimPoint, nil)
			return true
		end
	end
	return false
end

-- A boat built later (an AI ship) gets its guns when it spawns.
function Cannons.mountIfArmed(boat)
	if (boat.spec.class or boat.spec.cannons or boat.spec.broadside) and not boat.cannons then
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
		if entry.driver and entry.boat and entry.boat.model then
			entry.boat.model:SetAttribute("GunReadyAt", nil)
		end
	end
end

return Cannons

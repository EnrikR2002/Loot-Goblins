-- Pursuit (V8): what lives on an island follows a thief out to sea.
--
-- Until now every island's creature stopped at its own shore: reach the boat and the island was over.
-- V8 gives each one a SEA FORM, a way of its own to chase the goblin carrying its island's treasure
-- once they are on the water. They are meant to be funny and escapable, not lethal:
--   * a hit THROWS the boat about (Boats.shove) far more than it hurts it, and a creature can never
--     sink a boat on its own (hull damage stops at Config.IMPACT.HULL_FLOOR of the hull);
--   * the treasure follows the grip rule (Loot.knockLoose: a first hit loosens it, it is never taken
--     outright), and a goblin is only hit as often as Impact allows;
--   * every form has a tell before it strikes and a rest after, a leash (studs from its island), a
--     time limit, and it is driven off by an explosion (a keg, a cannonball): two and it goes home.
-- One pursuer per island at a time, Config.PURSUIT.MAX at once in the whole sea.
--
-- Three kinds of body:
--   SWIMMERS and RIDERS  a small model moved over (or under) the waves from here, steering round land
--                        with SeaNav. Bramble the ram in a washtub, the imps' raft, Old Clacker under
--                        the surface, the Warden eel, the clam, the Maw's whirlpool, the Echo.
--   LOBBERS              creatures that cannot leave their island throw things after the boat instead:
--                        the Guardian's boulders, the Watchers' walking beam, the Cinderlings' fire,
--                        the Chill's ice. Each shot is marked on the water before it lands.
-- The Leviathan (Bone) and the Ghost Fleet (Skull) and the Navy (Fort) are pursuers already, in their
-- own modules; the Fort also sends its garrison's launch from here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Loot = require(script.Parent.Loot)
local SeaNav = require(script.Parent.SeaNav)
local Blast = require(script.Parent.Blast)
local Creatures = require(script.Parent.Creatures)

local Pursuit = {}

local P = Config.PURSUIT

local forms = {} -- island id -> form
local active = {} -- pursuers out now
local readyAt = {} -- island id -> when it may set out again
local zones = {} -- patches left on the water (fire, ice): { position, radius, untilAt, kind, part }
local folder
local nextCheck = 0
local generation = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function turned(direction, radians)
	local c, s = math.cos(radians), math.sin(radians)
	return Vector3.new(direction.X * c - direction.Z * s, 0, direction.X * s + direction.Z * c)
end

-- Shared tools (the sea mobs use them too) ----------------------------------------------------------
-- A goblin's body, and the boat they are sitting in (if any).
function Pursuit.vessel(player)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return nil, nil, nil
	end
	local seat = humanoid.SeatPart
	return root, humanoid, seat and Boats.boatOf(seat) or nil
end

-- Is this goblin out on the water (in a boat, or swimming) rather than on an island?
function Pursuit.atSea(player)
	local root, _, boat = Pursuit.vessel(player)
	if not root then
		return false
	end
	if boat then
		return boat.state == "float" and SeaNav.depthAt(boat.hull.Position.X, boat.hull.Position.Z) > 3
	end
	return root.Position.Y < 6 and SeaNav.depthAt(root.Position.X, root.Position.Z) > 4
end

-- Hull damage from a creature: it batters a boat, it never sinks one.
function Pursuit.batter(boat, amount, cause)
	local room = boat.health - boat.spec.health * Config.IMPACT.HULL_FLOOR
	if room > 0 and amount > 0 then
		Boats.damage(boat, math.min(amount, room), cause)
	end
end

-- Hit a goblin, or the boat under them. opts: push (studs/s away), lift (studs/s up), spin, hull,
-- damage, reason (the grip rule), text, away (a direction, instead of straight away from `from`).
function Pursuit.hit(player, from, opts)
	local root, humanoid, boat = Pursuit.vessel(player)
	if not root then
		return false
	end
	local away = opts.away or flat(root.Position - from)
	away = away.Magnitude > 0.5 and away.Unit or Vector3.new(0, 0, 1)
	local throw = away * (opts.push or 0) + Vector3.new(0, opts.lift or 0, 0)
	if boat then
		Boats.shove(boat, throw, opts.spin and Vector3.new(0, opts.spin, 0) or nil)
		Pursuit.batter(boat, opts.hull or 0, opts.cause)
	end
	return Creatures.strike({ player = player, root = root, humanoid = humanoid }, from, {
		damage = opts.damage,
		push = not boat and throw or nil,
		reason = opts.reason,
		text = opts.text,
	})
end

-- A sound and a splash where something happened at sea (client: handlers.SeaFx).
function Pursuit.fx(kind, position, extra)
	local payload = extra or {}
	payload.kind = kind
	payload.position = position
	Net.broadcastNear(position, 1400, "SeaFx", payload)
end

-- A body: an anchored root with everything else welded to it, so one CFrame moves the lot.
-- parts: { { name, size, offset (CFrame from the root), color, material, shape, transparency } }
function Pursuit.body(name, parts)
	local model, root = Creatures.body(name, parts, folder)
	return model, root
end

-- One step over the water toward `goal`, steering round land. Returns false if there is no way on.
function Pursuit.swim(mover, goal, speed, dt, turnRate)
	local to = flat(goal - mover.position)
	if to.Magnitude < 1 then
		return true
	end
	local want = to.Unit
	local draft = mover.draft or 1.5
	local function open(direction)
		local probe = mover.position + direction * 28
		return SeaNav.passable(probe.X, probe.Z, draft)
	end
	if not open(want) then
		local found = false
		for _, degrees in ipairs({ 35, -35, 70, -70, 110, -110 }) do
			local option = turned(want, math.rad(degrees))
			if open(option) then
				want, found = option, true
				break
			end
		end
		if not found then
			return false
		end
	end
	-- Turn toward it at its own rate (a charge that cannot turn is what makes it dodgeable).
	local heading = mover.heading or want
	local angle = math.atan2(heading.X * want.Z - heading.Z * want.X, heading:Dot(want))
	local step = math.clamp(angle, -(turnRate or 3) * dt, (turnRate or 3) * dt)
	heading = turned(heading, step)
	mover.heading = heading
	local p = mover.position + heading * speed * dt
	mover.position = Vector3.new(p.X, 0, p.Z)
	return true
end

-- Put a mover's body on the waves (ride: studs above the surface, negative for under it).
function Pursuit.place(mover, ride, extra)
	local p = mover.position
	local y = Sea.waveAt(p.X, p.Z, now()) + (ride or 0)
	local heading = mover.heading or Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X + heading.X, y, p.Z + heading.Z))
	if extra then
		frame *= extra
	end
	mover.root.CFrame = frame
end

-- Where a goblin (or their boat) will be in `seconds`.
function Pursuit.lead(player, seconds)
	local root, _, boat = Pursuit.vessel(player)
	if not root then
		return nil
	end
	local part = boat and boat.hull or root
	local v = part.AssemblyLinearVelocity
	return flat(part.Position) + flat(v) * seconds, flat(v), boat
end

-- A patch on the water that does something to whatever sits in it for a while.
function Pursuit.zone(kind, position, radius, seconds, color)
	local disc = Instance.new("Part")
	disc.Name = "SeaPatch"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.6, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(position.X, 0.6, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = kind == "fire" and Enum.Material.Neon or Enum.Material.Ice
	disc.Color = color
	disc.Transparency = kind == "fire" and 0.45 or 0.2
	disc.Parent = folder
	if kind == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = radius * 1.2
		fire.Heat = 12
		fire.Parent = disc
	end
	table.insert(
		zones,
		{ kind = kind, position = flat(position), radius = radius, untilAt = now() + seconds, part = disc }
	)
end

-- Forms -----------------------------------------------------------------------------------------------
local WOOD = Color3.fromRGB(122, 84, 52)
local DARK_WOOD = Color3.fromRGB(78, 52, 34)

local function ball(name, size, offset, color, material, transparency)
	return { name, Vector3.new(size, size, size), offset, color, material, Enum.PartType.Ball, transparency }
end

local function block(name, size, offset, color, material, transparency)
	return { name, size, offset, color, material, nil, transparency }
end

-- Every swimmer/rider shares this life: chase, then (close enough) a tell, a strike, a rest.
-- A form supplies numbers and may replace any step with its own function.
local function defaults(form)
	form.speed = form.speed or 120
	form.turn = form.turn or 2.6
	form.leash = form.leash or P.LEASH
	form.time = form.time or P.TIME
	form.reach = form.reach or 16 -- start the tell this close
	form.tell = form.tell or 0.8
	form.rest = form.rest or 3.5
	form.ride = form.ride or 0
	form.size = form.size or 8
	return form
end

-- BRAMBLE (Windmill Hills): the ram, in a washtub, rowing with its horns down. It lines up and CHARGES
-- in a straight line it cannot turn out of: a turn or a jump and it thunders past.
forms.Windmill = defaults({
	name = "Bramble's Tub",
	say = "BRAMBLE THE RAM HAS PUT TO SEA IN A WASHTUB!",
	gone = "Bramble rows home, furious.",
	color = Color3.fromRGB(235, 228, 210),
	speed = 150, -- a cruising skiff does 135: he gains on one that does nothing about it
	reach = 105,
	tell = 0.75,
	rest = 3.2,
	body = {
		block("Tub", Vector3.new(9, 3.4, 11), nil, WOOD, Enum.Material.WoodPlanks),
		block("TubRim", Vector3.new(9.8, 0.8, 11.8), CFrame.new(0, 1.9, 0), DARK_WOOD, Enum.Material.Wood),
		ball("Fleece", 6.4, CFrame.new(0, 4.4, 0.6), Color3.fromRGB(240, 236, 224), Enum.Material.Fabric),
		ball("Head", 3.4, CFrame.new(0, 5.4, -3.4), Color3.fromRGB(58, 48, 44), Enum.Material.SmoothPlastic),
		block(
			"HornL",
			Vector3.new(1, 1, 3.2),
			CFrame.new(-1.6, 6.4, -4.4) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(230, 215, 170),
			Enum.Material.Slate
		),
		block(
			"HornR",
			Vector3.new(1, 1, 3.2),
			CFrame.new(1.6, 6.4, -4.4) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(230, 215, 170),
			Enum.Material.Slate
		),
		block("OarL", Vector3.new(7, 0.5, 1.2), CFrame.new(-6.5, 1.4, 0), DARK_WOOD, Enum.Material.Wood),
		block("OarR", Vector3.new(7, 0.5, 1.2), CFrame.new(6.5, 1.4, 0), DARK_WOOD, Enum.Material.Wood),
	},
	-- The tell: horns down, a bleat. Then the charge: straight, fast, no steering.
	onTell = function(p)
		Pursuit.fx("bleat", p.position)
		p.chargeUntil = now() + p.form.tell + 1.9
	end,
	strike = function(p, target, dt)
		local t = now()
		p.position += p.heading * 240 * dt
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 10 + (boat and boat.spec.size.X * 0.5 or 0) then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 85,
				lift = 28,
				spin = 2.4,
				hull = 10,
				damage = 8,
				reason = "ram",
				cause = "Bramble the ram",
				text = "RAMMED BY BRAMBLE!",
			})
			Pursuit.fx("crash", p.position)
			return true
		end
		local probe = p.position + p.heading * 20
		return t > p.chargeUntil or not SeaNav.passable(probe.X, probe.Z, 1)
	end,
})

-- THE IMPS (Tangle Isle): three of them on a raft of lashed barrels, faster than a cruising skiff. They
-- do not ram: they pull alongside and one LEAPS the gap for the treasure. Stay away from the raft's
-- side for a moment (boost, jump, turn) and the leap is called off.
forms.Tangle = defaults({
	name = "The Imps' Raft",
	say = "THE IMPS ARE AFTER YOU ON A RAFT OF BARRELS!",
	gone = "The imps paddle off, cackling.",
	color = Color3.fromRGB(96, 190, 84),
	speed = 158,
	turn = 3.4,
	reach = 17,
	tell = 0.9,
	rest = 4.5,
	body = {
		block("Raft", Vector3.new(10, 1, 12), nil, WOOD, Enum.Material.WoodPlanks),
		block("BarrelL", Vector3.new(3, 3, 12), CFrame.new(-4, -1.2, 0), DARK_WOOD, Enum.Material.Wood),
		block("BarrelR", Vector3.new(3, 3, 12), CFrame.new(4, -1.2, 0), DARK_WOOD, Enum.Material.Wood),
		ball("ImpA", 3, CFrame.new(-2.4, 2.2, -2), Color3.fromRGB(96, 190, 84), Enum.Material.SmoothPlastic),
		ball("ImpB", 3, CFrame.new(2.4, 2.2, -1), Color3.fromRGB(110, 205, 96), Enum.Material.SmoothPlastic),
		ball("ImpC", 3, CFrame.new(0, 2.2, 3), Color3.fromRGB(84, 170, 74), Enum.Material.SmoothPlastic),
		block("Mast", Vector3.new(0.6, 9, 0.6), CFrame.new(0, 5, 0), DARK_WOOD, Enum.Material.Wood),
		block("Rag", Vector3.new(5, 4, 0.3), CFrame.new(0, 7, 0.4), Color3.fromRGB(190, 60, 60), Enum.Material.Fabric),
	},
	onTell = function(p)
		Pursuit.fx("shriek", p.position)
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 22 then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 18,
				reason = "imp",
				cause = "the imps",
				text = "AN IMP IS ON YOUR TREASURE! Shake the raft off!",
			})
			Pursuit.fx("snatch", at)
		end
		return true
	end,
})

-- OLD CLACKER (Shipwreck Shoals): the crab goes UNDER. All you see is the top of its shell and a wake,
-- then a ring under your boat, then it comes up beneath you and the boat goes into the air.
forms.Shoals = defaults({
	name = "Old Clacker",
	say = "OLD CLACKER IS UNDER THE WATER, COMING FOR YOU!",
	gone = "Old Clacker sinks back to the shoals.",
	color = Color3.fromRGB(214, 84, 60),
	speed = 150,
	reach = 20,
	tell = 0.95,
	rest = 4,
	ride = -3.2,
	body = {
		block("Shell", Vector3.new(11, 4, 9), nil, Color3.fromRGB(214, 84, 60), Enum.Material.Slate),
		ball("EyeL", 1.6, CFrame.new(-2, 3, -3.6), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic),
		ball("EyeR", 1.6, CFrame.new(2, 3, -3.6), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic),
		block(
			"ClawL",
			Vector3.new(3.4, 2.4, 6),
			CFrame.new(-7.5, 0.6, -4),
			Color3.fromRGB(232, 104, 74),
			Enum.Material.Slate
		),
		block(
			"ClawR",
			Vector3.new(3.4, 2.4, 6),
			CFrame.new(7.5, 0.6, -4),
			Color3.fromRGB(232, 104, 74),
			Enum.Material.Slate
		),
	},
	onTell = function(p, target)
		local spot = Pursuit.lead(target, p.form.tell * 0.6)
		p.strikeAt = spot or p.position
		Creatures.mark(Vector3.new(p.strikeAt.X, 0.5, p.strikeAt.Z), 17, p.form.tell, p.form.color)
	end,
	-- During the tell it slides under the mark.
	telling = function(p, _target, dt)
		Pursuit.swim(p, p.strikeAt, 150, dt, 6)
	end,
	strike = function(p, target)
		p.position = p.strikeAt
		p.popUntil = now() + 1.2 -- it shows itself, claws up
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.strikeAt).Magnitude < 17 + (boat and boat.spec.size.Z * 0.3 or 0) then
			p.landed = true
			Pursuit.hit(target, p.strikeAt, {
				push = 22,
				lift = 84,
				spin = 1.4,
				hull = 8,
				damage = 6,
				reason = "crab",
				cause = "Old Clacker",
				text = "TOSSED BY THE CRAB!",
			})
		end
		Pursuit.fx("erupt", Vector3.new(p.strikeAt.X, 1, p.strikeAt.Z))
		return true
	end,
})

-- THE WARDEN (Tide Vault): the eel. The fastest thing in these waters over a short way, and it does not
-- bite the boat: it goes under the bow and LASHES it round. You end up pointing the wrong way.
forms.Tide = defaults({
	name = "The Warden",
	say = "THE WARDEN EEL IS LOOSE IN THE OPEN WATER!",
	gone = "The Warden turns back for its vault.",
	color = Color3.fromRGB(70, 210, 190),
	speed = 170,
	turn = 3,
	leash = 800,
	time = 40,
	reach = 26,
	tell = 0.55,
	rest = 3.6,
	ride = -1.2,
	body = {
		block("Body", Vector3.new(3.4, 3, 20), nil, Color3.fromRGB(40, 120, 120), Enum.Material.Slate),
		ball("Head", 5, CFrame.new(0, 0.4, -11), Color3.fromRGB(54, 150, 146), Enum.Material.Slate),
		block(
			"Fin",
			Vector3.new(0.5, 3.4, 14),
			CFrame.new(0, 2.6, 1),
			Color3.fromRGB(70, 210, 190),
			Enum.Material.Neon,
			0.3
		),
		ball("EyeL", 1.2, CFrame.new(-1.7, 1.4, -12.6), Color3.fromRGB(255, 240, 120), Enum.Material.Neon),
		ball("EyeR", 1.2, CFrame.new(1.7, 1.4, -12.6), Color3.fromRGB(255, 240, 120), Enum.Material.Neon),
		block("Tail", Vector3.new(2.2, 2, 9), CFrame.new(0, 0, 14), Color3.fromRGB(40, 120, 120), Enum.Material.Slate),
	},
	onTell = function(p)
		Pursuit.fx("zap", p.position)
		p.side = (p.side or 1) * -1
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 34 then
			local across = turned(p.heading, math.rad(90 * p.side))
			p.landed = true
			Pursuit.hit(target, p.position, {
				away = across,
				push = 62,
				lift = 14,
				spin = 3.4 * p.side,
				hull = 5,
				damage = 6,
				reason = "eel",
				cause = "the Warden",
				text = "LASHED ROUND BY THE EEL!",
			})
			Pursuit.fx("splash", at)
		end
		return true
	end,
})

-- THE CLAM (Coral Atoll): it swims the way a scallop does, in clapping jets, and when it reaches you it
-- CLAMPS onto the hull and drags. It cannot hold on to a boat that leaves the water: jump.
forms.Coral = defaults({
	name = "The Clam",
	say = "THE GIANT CLAM IS JETTING AFTER YOU!",
	gone = "The clam claps off home.",
	color = Color3.fromRGB(255, 170, 190),
	speed = 165, -- in jets: about 150 over a whole stroke
	leash = 750,
	time = 40,
	reach = 12,
	tell = 0.35,
	rest = 5,
	ride = -0.6,
	body = {
		block("Lower", Vector3.new(9, 2, 9), nil, Color3.fromRGB(240, 225, 215), Enum.Material.Slate),
		block(
			"Upper",
			Vector3.new(9, 2, 9),
			CFrame.new(0, 2.6, 2) * CFrame.Angles(math.rad(28), 0, 0),
			Color3.fromRGB(240, 225, 215),
			Enum.Material.Slate
		),
		ball("Flesh", 5, CFrame.new(0, 1.4, 0.6), Color3.fromRGB(255, 170, 190), Enum.Material.SmoothPlastic),
	},
	-- Jets: a burst, then a glide.
	pace = function(_p, t)
		return (t % 2.1) < 0.95 and 1.35 or 0.3
	end,
	onTell = function(p)
		Pursuit.fx("clap", p.position)
	end,
	strike = function(p, target, dt)
		-- Clamped on: ride the hull and drag it, until it jumps, time runs out or something goes bang.
		local t = now()
		p.clampUntil = p.clampUntil or (t + 4)
		p.landed = true
		local root, _, boat = Pursuit.vessel(target)
		local hull = boat and boat.hull or root
		if not hull or t > p.clampUntil then
			p.clampUntil = nil
			return true
		end
		local wave = Sea.waveAt(hull.Position.X, hull.Position.Z, t)
		if hull.Position.Y - wave > 6.5 then
			p.clampUntil = nil
			Net.toast(target, "The clam lost its grip!")
			Pursuit.fx("splash", p.position)
			return true
		end
		p.position = flat(hull.Position) - flat(hull.CFrame.LookVector) * 4
		p.dragAt = (p.dragAt or 0) - dt
		if p.dragAt <= 0 then
			p.dragAt = 0.25
			if not p.told then
				p.told = true
				Net.toast(target, "THE CLAM HAS YOUR HULL! Jump (SPACE) to shake it off!")
			end
			if boat then
				Boats.shove(boat, -flat(hull.AssemblyLinearVelocity) * 0.3)
			end
		end
		return false
	end,
	afterStrike = function(p)
		p.told = nil
	end,
})

-- THE MAW (Maelstrom Rock): its whirlpool gets up and WALKS. It is slow, so you can always outrun it,
-- but anything within reach is pulled in and round, and the middle spits you into the air.
forms.Maelstrom = defaults({
	name = "The Wandering Maw",
	say = "THE MAELSTROM HAS LEFT ITS ROCK. IT IS FOLLOWING YOU!",
	gone = "The Maw drifts home.",
	color = Color3.fromRGB(120, 170, 255),
	speed = 74,
	turn = 1.6,
	leash = 900,
	reach = 0, -- no tell of its own: the pull is the warning
	rest = 5,
	ride = 0.4,
	size = 30,
	body = {
		block("Core", Vector3.new(1, 1, 1), nil, Color3.fromRGB(30, 70, 120), Enum.Material.SmoothPlastic, 1),
		{
			"Pool",
			Vector3.new(0.8, 96, 96),
			CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 70, 120),
			Enum.Material.Glass,
			Enum.PartType.Cylinder,
			0.35,
		},
		{
			"Ring",
			Vector3.new(1, 60, 60),
			CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(190, 225, 255),
			Enum.Material.Neon,
			Enum.PartType.Cylinder,
			0.6,
		},
		{
			"Eye",
			Vector3.new(1.2, 22, 22),
			CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(8, 20, 40),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder,
			0,
		},
		block(
			"Fin",
			Vector3.new(1, 9, 7),
			CFrame.new(0, 4, -20) * CFrame.Angles(math.rad(-20), 0, 0),
			Color3.fromRGB(60, 70, 90),
			Enum.Material.Slate
		),
	},
	-- Everything on the water near it is drawn in (every boat, not only the thief's).
	always = function(p, _target, dt)
		p.pullAt = (p.pullAt or 0) - dt
		if p.pullAt > 0 then
			return
		end
		p.pullAt = 0.25
		local t = now()
		for _, boat in ipairs(Boats.list) do
			if boat.state == "float" and not boat.ai then
				local offset = flat(p.position - boat.hull.Position)
				local distance = offset.Magnitude
				if distance < 170 and distance > 1 then
					if distance < 24 and t >= (p.spatAt or 0) then
						p.spatAt = t + 5
						local out = turned(offset.Unit, math.rad(140))
						Boats.shove(boat, out * 70 + Vector3.new(0, 78, 0), Vector3.new(0, 2, 0))
						Pursuit.batter(boat, 8, "the Maw")
						Pursuit.fx("erupt", boat.hull.Position)
					elseif t >= (p.spatAt or 0) - 3.5 then
						local strength = (1 - distance / 170) * 26
						Boats.shove(boat, (offset.Unit + turned(offset.Unit, math.rad(90)) * 0.8) * strength * 0.25)
					end
				end
			end
		end
	end,
})

-- THE ECHO (Crystal Isle): it does not chase you, it REPEATS you. It runs the exact way your boat went,
-- a few seconds behind, and the gap closes the longer it follows. Keep moving and it never arrives;
-- stop, dither or double back and you sail into yourself.
forms.Crystal = defaults({
	name = "The Echo",
	say = "YOUR ECHO IS FOLLOWING YOUR WAKE. DO NOT SLOW DOWN!",
	gone = "The Echo fades.",
	color = Color3.fromRGB(215, 120, 255),
	leash = 1100,
	time = 45,
	reach = 10,
	tell = 0.3,
	rest = 5,
	ride = 2.5,
	body = {
		block("Hull", Vector3.new(6, 2.4, 13), nil, Color3.fromRGB(215, 120, 255), Enum.Material.Neon, 0.45),
		ball("Rider", 3.4, CFrame.new(0, 3.2, 1), Color3.fromRGB(240, 190, 255), Enum.Material.Neon, 0.35),
		block(
			"Sail",
			Vector3.new(0.4, 8, 5),
			CFrame.new(0, 5.4, -1),
			Color3.fromRGB(240, 190, 255),
			Enum.Material.Neon,
			0.6
		),
	},
	-- Its own way of moving: along the trail.
	move = function(p, target, dt)
		local t = now()
		local spot = Pursuit.lead(target, 0)
		if not spot then
			return
		end
		p.trail = p.trail or {}
		p.trailAt = (p.trailAt or 0) - dt
		if p.trailAt <= 0 then
			p.trailAt = 0.1
			table.insert(p.trail, { t = t, position = spot })
			while #p.trail > 60 do
				table.remove(p.trail, 1)
			end
		end
		-- How far behind it runs: 3.4 s at first, closing to 1 s.
		p.delay = math.max(1, (p.delay or 3.4) - dt * 0.07)
		local want = t - p.delay
		if p.trail[1].t > want then
			return -- it has not been following long enough to have anywhere to be: it waits where it rose
		end
		local at = p.trail[1].position
		for _, sample in ipairs(p.trail) do
			if sample.t <= want then
				at = sample.position
			else
				break
			end
		end
		local step = flat(at - p.position)
		if step.Magnitude > 0.5 then
			p.heading = step.Unit
			p.position += step.Unit * math.min(step.Magnitude, 260 * dt)
		end
	end,
	onTell = function(p)
		Pursuit.fx("chime", p.position)
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 16 then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 58,
				lift = 20,
				spin = 1.2,
				damage = 8,
				reason = "echo",
				cause = "the Echo",
				text = "YOU SAILED INTO YOUR OWN ECHO!",
			})
			Pursuit.fx("shatter", at)
		end
		p.delay = 3.4
		return true
	end,
})

-- THE GARRISON'S LAUNCH (Fort Barnacle): two marines in a rowing boat with a swivel gun. It keeps its
-- distance and drops shot ahead of you, each one marked on the water first.
forms.Fort = defaults({
	name = "The Garrison's Launch",
	say = "THE GARRISON HAS LAUNCHED A GUNBOAT AFTER YOU!",
	gone = "The launch turns back for the fort.",
	color = Color3.fromRGB(245, 245, 250),
	speed = 140,
	reach = 0,
	ride = 0,
	body = {
		block("Hull", Vector3.new(7, 2.6, 15), nil, Color3.fromRGB(245, 245, 250), Enum.Material.WoodPlanks),
		block(
			"Stripe",
			Vector3.new(7.3, 0.6, 15.3),
			CFrame.new(0, 1, 0),
			Color3.fromRGB(190, 40, 50),
			Enum.Material.SmoothPlastic
		),
		ball("MarineA", 3, CFrame.new(0, 3, 3), Color3.fromRGB(200, 40, 50), Enum.Material.SmoothPlastic),
		ball("MarineB", 3, CFrame.new(0, 3, -1), Color3.fromRGB(200, 40, 50), Enum.Material.SmoothPlastic),
		block("Gun", Vector3.new(1.4, 1.4, 5), CFrame.new(0, 3, -6.5), Color3.fromRGB(52, 54, 62), Enum.Material.Metal),
	},
	keepOff = 95, -- it hangs back this far
	always = function(p, target, dt)
		p.fireAt = (p.fireAt or 3) - dt
		if p.fireAt > 0 then
			return
		end
		p.fireAt = 3.4
		local spot = Pursuit.lead(target, 1.25)
		if spot and flat(spot - p.position).Magnitude < 260 then
			local at = Vector3.new(spot.X, 0.5, spot.Z)
			Net.broadcastNear(at, 1200, "Shell", { from = p.position + Vector3.new(0, 4, 0), to = at, duration = 1.25 })
			Blast.strike(at, 1.25, {
				radius = 10,
				damage = 10,
				knockback = 42,
				hullDamage = 6,
				boatPush = 46,
				cause = "the garrison's swivel gun",
				color = Color3.fromRGB(255, 220, 160),
			})
		end
	end,
})

-- Lobbers: they stay ashore and throw. `shot(form, island, target)` is called every form.every seconds.
local function lobber(form)
	form.lob = true
	form.leash = form.leash or 950
	form.time = form.time or 45
	form.every = form.every or 3.2
	return form
end

-- THE GUARDIAN (Sun Temple): it will not swim. It tears stone out of its temple and throws it.
forms.Temple = lobber({
	name = "The Guardian's Boulders",
	say = "THE GUARDIAN IS THROWING BOULDERS AFTER YOU!",
	gone = "The Guardian lowers its arms.",
	color = Color3.fromRGB(255, 205, 40),
	every = 3.1,
	shot = function(form, island, target)
		local spot = Pursuit.lead(target, 1.75)
		if not spot then
			return
		end
		local at = Vector3.new(spot.X, 0.5, spot.Z)
		Net.broadcastNear(at, 1500, "Shell", { from = Vector3.new(island.x, 70, island.z), to = at, duration = 1.75 })
		Blast.strike(at, 1.75, {
			radius = 18,
			damage = 14,
			knockback = 64,
			hullDamage = 9,
			boatPush = 74,
			lootReason = "boulder",
			cause = "the Guardian's boulder",
			color = form.color,
			markerColor = form.color,
		})
	end,
})

-- THE WATCHERS (Crossroads Ruins): the stone eyes turn seaward and WALK their beam across the water at
-- you: a row of marks, one after another. Turn across the line and it passes.
forms.Cross = lobber({
	name = "The Watchers' Gaze",
	say = "THE WATCHERS HAVE TURNED THEIR EYES OUT TO SEA!",
	gone = "The Watchers look away.",
	color = Color3.fromRGB(255, 80, 60),
	leash = 800,
	every = 4.2,
	shot = function(form, island, target)
		local spot = Pursuit.lead(target, 1.5)
		if not spot then
			return
		end
		local from = Vector3.new(island.x, 0, island.z)
		local along = flat(spot - from)
		if along.Magnitude < 40 then
			return
		end
		local direction = along.Unit
		for i = 0, 4 do
			local at = spot + direction * (i - 3) * 26
			Blast.strike(Vector3.new(at.X, 0.5, at.Z), 0.9 + i * 0.2, {
				radius = 9,
				damage = 6,
				knockback = 46,
				boatPush = 50,
				cause = "the Watchers' gaze",
				color = form.color,
				markerColor = form.color,
			})
		end
		Pursuit.fx("eye", Vector3.new(spot.X, 2, spot.Z))
	end,
})

-- THE CINDERLINGS (Ember Isle): they spit fire that goes on BURNING on the water. The patch is the
-- danger, not the splash: steer round it.
forms.Ember = lobber({
	name = "The Cinderlings' Fire",
	say = "THE CINDERLINGS ARE SPITTING FIRE ACROSS THE WATER!",
	gone = "The fires on the water die down.",
	color = Color3.fromRGB(255, 120, 50),
	every = 2.7,
	shot = function(form, island, target)
		local spot = Pursuit.lead(target, 1.5)
		if not spot then
			return
		end
		local at = Vector3.new(spot.X, 0.5, spot.Z)
		Net.broadcastNear(at, 1500, "Shell", { from = Vector3.new(island.x, 90, island.z), to = at, duration = 1.5 })
		Creatures.mark(at, 14, 1.5, form.color)
		local current = generation
		task.delay(1.5, function()
			if current == generation then
				Pursuit.zone("fire", at, 14, 7, form.color)
				Pursuit.fx("erupt", at)
			end
		end)
	end,
})

-- THE CHILL (Frost Spire): it breathes on the sea AHEAD of you and the water there sets. A boat that
-- runs onto the ice is held for as long as it stays on it.
forms.Frost = lobber({
	name = "The Chill's Breath",
	say = "THE CHILL IS FREEZING THE SEA IN FRONT OF YOU!",
	gone = "The ice on the water breaks up.",
	color = Color3.fromRGB(190, 235, 255),
	every = 3.6,
	shot = function(form, _island, target)
		local spot = Pursuit.lead(target, 2.5)
		if not spot then
			return
		end
		local at = Vector3.new(spot.X, 0.5, spot.Z)
		Creatures.mark(at, 24, 1.5, form.color)
		Pursuit.fx("chill", at)
		local current = generation
		task.delay(1.5, function()
			if current == generation then
				Pursuit.zone("ice", at, 24, 5.5, form.color)
			end
		end)
	end,
})

-- Running them -----------------------------------------------------------------------------------------
local function carrierOf(islandId)
	for _, entry in ipairs(Loot.carriers()) do
		if entry.item.def.island == islandId then
			return entry.player
		end
	end
	return nil
end

local function finish(p, word)
	p.done = true
	if p.model then
		p.model:Destroy()
		p.model = nil
	end
	readyAt[p.form.id] = now() + P.COOLDOWN
	if word ~= false and p.target and p.target.Parent then
		Net.toast(p.target, word or p.form.gone)
	end
end

local function setOut(form, island, target)
	local root = Pursuit.vessel(target)
	if not root then
		return
	end
	local p = {
		form = form,
		island = island,
		target = target,
		bornAt = now(),
		state = "chase",
		stateUntil = 0,
		flinches = 0,
		draft = 1.5,
	}
	if not form.lob then
		-- Off the island's shore, on the side the thief left by.
		local center = Vector3.new(island.x, 0, island.z)
		local toward = flat(root.Position - center)
		toward = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, 1)
		local shore = center + toward * (island.r + 30)
		local water = SeaNav.nearestWater(shore.X, shore.Z, 2)
		p.position = water and Vector3.new(water.X, 0, water.Z) or shore
		p.heading = toward
		p.model, p.root = Pursuit.body(form.name, form.body)
		Pursuit.place(p, form.ride)
		Pursuit.fx("launch", p.position)
	else
		p.position = Vector3.new(island.x, 0, island.z)
		p.nextShot = now() + 1.5
	end
	table.insert(active, p)
	Net.send(target, "Message", { text = form.say, duration = 3.5, color = form.color })
	Net.feed(form.name .. " is after " .. target.DisplayName .. "!", form.color)
end

local function considerNew(t)
	if #active >= P.MAX then
		return
	end
	for id, form in pairs(forms) do
		if t >= (readyAt[id] or 0) then
			local busy = false
			for _, p in ipairs(active) do
				if p.form == form then
					busy = true
					break
				end
			end
			local target = not busy and carrierOf(id) or nil
			local island = Archipelago.byId[id]
			if target and island and Pursuit.atSea(target) then
				local root = Pursuit.vessel(target)
				-- (Measured from the island's SHORE: the big islands are 450 studs across.)
				local off = Util.flatDistance(root.Position, Vector3.new(island.x, 0, island.z)) - island.r
				if off > P.CLEAR and off < form.leash * 0.8 then
					setOut(form, island, target)
					if #active >= P.MAX then
						return
					end
				end
			end
		end
	end
end

local function tickSwimmer(p, dt, t)
	local form = p.form
	local target = p.target
	local root, _, boat = Pursuit.vessel(target)
	local targetAt = boat and boat.hull.Position or (root and root.Position)
	if form.always then
		form.always(p, target, dt)
	end
	if p.state == "flinch" or p.state == "rest" then
		-- Reeling from a blast, or winded after a strike: it wallows where it is.
		if t >= p.stateUntil then
			p.state = "chase"
		end
	elseif p.state == "tell" then
		if form.telling then
			form.telling(p, target, dt)
		elseif targetAt then
			-- Line up on them, slowly.
			Pursuit.swim(p, targetAt, form.speed * 0.25, dt, form.turn)
		end
		if t >= p.stateUntil then
			p.state = "strike"
		end
	elseif p.state == "strike" then
		if not form.strike or form.strike(p, target, dt) then
			if form.afterStrike then
				form.afterStrike(p)
			end
			-- A strike that connected earns its full rest (the thief's chance to get away). One that missed
			-- does not: it comes round again quickly, so dodging once is not the end of the chase.
			p.state = "rest"
			p.stateUntil = t + (p.landed and form.rest or math.min(form.rest, P.MISS_REST))
			p.landed = false
		end
	elseif targetAt then
		if form.move then
			form.move(p, target, dt)
		else
			local pace = form.pace and form.pace(p, t) or 1
			local goal = targetAt
			if form.keepOff then
				local off = flat(p.position - targetAt)
				if off.Magnitude < form.keepOff then
					pace = 0.25
				end
			end
			Pursuit.swim(p, goal, form.speed * pace, dt, form.turn)
		end
		local gap = flat(targetAt - p.position).Magnitude - (boat and boat.spec.size.Z * 0.4 or 0)
		if form.reach > 0 and gap <= form.reach then
			p.state = "tell"
			p.stateUntil = t + form.tell
			if form.onTell then
				form.onTell(p, target)
			end
		end
	end
	local extra
	if p.state == "flinch" then
		extra = CFrame.Angles(0, 0, math.sin(t * 22) * 0.35)
	elseif p.state == "tell" then
		extra = CFrame.Angles(math.rad(-10), 0, 0)
	end
	local ride = form.ride
	if p.popUntil and t < p.popUntil then
		ride = 3 -- up out of the water for a moment
	end
	Pursuit.place(p, ride, extra)
end

function Pursuit.tick(dt)
	local t = now()
	dt = math.min(dt, 0.1)
	if t >= nextCheck then
		nextCheck = t + P.CHECK
		considerNew(t)
	end
	for index = #active, 1, -1 do
		local p = active[index]
		local form = p.form
		local target = p.target
		local root = target.Parent and Pursuit.vessel(target) or nil
		local island = p.island
		local reason
		if not root then
			reason = false
		elseif not p.forced and carrierOf(form.id) ~= target then
			-- Banked, dropped or taken from them: the island has no quarrel with this goblin now.
			p.lostAt = p.lostAt or t
			if t - p.lostAt > 3 then
				reason = form.gone
			end
		elseif t - p.bornAt > form.time then
			reason = form.gone
		elseif
			not p.forced
			and Util.flatDistance(root.Position, Vector3.new(island.x, 0, island.z)) - island.r > form.leash
		then
			reason = form.gone .. " (too far from its island)"
		elseif not Pursuit.atSea(target) then
			p.ashoreAt = p.ashoreAt or t
			if t - p.ashoreAt > 5 then
				reason = form.gone
			end
		else
			p.lostAt, p.ashoreAt = nil, nil
		end
		if reason == nil and p.flinches >= 2 then
			reason = form.name .. " has had enough of explosions!"
		end
		if reason ~= nil then
			finish(p, reason)
			table.remove(active, index)
		elseif form.lob then
			if t >= p.nextShot then
				p.nextShot = t + form.every
				form.shot(form, island, target)
			end
		else
			tickSwimmer(p, dt, t)
		end
	end
	-- Patches on the water.
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if t >= zone.untilAt then
			zone.part:Destroy()
			table.remove(zones, index)
		elseif t >= (zone.nextAt or 0) then
			zone.nextAt = t + 0.3
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not boat.ai then
					local offset = flat(boat.hull.Position - zone.position)
					if offset.Magnitude < zone.radius + 4 and boat.hull.Position.Y < 9 then
						if zone.kind == "fire" then
							Pursuit.batter(boat, 2.5, "fire on the water")
						else
							Boats.shove(boat, -flat(boat.hull.AssemblyLinearVelocity) * 0.32)
						end
					end
				end
			end
			if zone.kind == "fire" then
				for _, player in ipairs(Players:GetPlayers()) do
					local root, humanoid = Util.aliveRoot(player)
					if
						root
						and not humanoid.SeatPart
						and root.Position.Y < 9
						and flat(root.Position - zone.position).Magnitude < zone.radius
					then
						Creatures.strike(
							{ player = player, root = root, humanoid = humanoid },
							zone.position,
							{ damage = 8 }
						)
					end
				end
			end
		end
	end
end

-- Something went bang: a pursuer near it flinches (and after two, goes home). The lobbers are on their
-- islands, out of reach of this; their answer is to get out of range.
local function onBlast(position, radius)
	local t = now()
	for _, p in ipairs(active) do
		if
			not p.form.lob
			and p.state ~= "flinch"
			and flat(p.position - position).Magnitude <= radius + p.form.size + 6
		then
			p.state = "flinch"
			p.stateUntil = t + P.FLINCH
			p.flinches += 1
			p.clampUntil = nil
			Pursuit.fx("yelp", p.position)
			if p.target.Parent then
				Net.toast(p.target, p.form.name .. " reels from the blast!")
			end
		end
	end
end

function Pursuit.build(worldRefs)
	folder = worldRefs.folders.threats
	for id, form in pairs(forms) do
		form.id = id
	end
	Blast.Hit:Connect(onBlast)
end

function Pursuit.reset()
	generation += 1
	for _, p in ipairs(active) do
		if p.model then
			p.model:Destroy()
		end
	end
	table.clear(active)
	table.clear(readyAt)
	for _, zone in ipairs(zones) do
		zone.part:Destroy()
	end
	table.clear(zones)
end

-- For tests and the report: what is out, and the roster.
function Pursuit.active()
	return active
end

function Pursuit.forms()
	return forms
end

-- For tests: send an island's pursuer after a goblin now, whatever they are carrying and wherever
-- they are. `from` (optional) is where it starts instead of its island's shore.
function Pursuit.force(islandId, target, from)
	local form, island = forms[islandId], Archipelago.byId[islandId]
	if not form or not island then
		return nil
	end
	local before = #active
	setOut(form, island, target)
	local p = active[#active]
	if #active == before or not p then
		return nil
	end
	p.forced = true
	if from and not form.lob then
		p.position = Vector3.new(from.X, 0, from.Z)
	end
	return p
end

return Pursuit

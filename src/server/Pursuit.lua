-- Pursuit: what lives on an island follows a thief out to sea, almost all the way home.
--
-- V8 gave each island's creature a SEA FORM. The playtest found the best moments were a creature right behind
-- a fleeing boat, and the worst was it giving up after 50 seconds, a leash or a global cap of five. V9:
--
--   * A pursuit ends at the SANCTUARY (Config.SANCTUARY: the water round Goblin Cove, ringed with lantern buoys),
--     not on a timer or a leash. The pursuer stops at the edge with a show of it and goes. It never enters.
--   * PACING, not distance, keeps it fair. Far behind it SURGES; closing, it gains steadily; close, it HANGS just
--     behind at its `follow` distance, matching the thief's speed. It has momentum (it speeds up and slows
--     down at its own rates), so a thief who keeps their speed is shadowed and one who loses it (a rock, a
--     missed hoop, a rival, a landing) is caught. Every so often it LUNGES, which is when its tell shows.
--   * A pursuer that falls hopelessly far behind, or is blocked by land, RESURFACES behind the thief along
--     their wake, out of sight (CATCH_UP_TO): never in front, never in view of their bow.
--   * Each thief has at most PER_TARGET island pursuers; one per island; MAX in the whole sea.
--   * Pursuers are kinematic bodies, but they fly: a ramp throws them, a tornado lifts and spins them (and a
--     pursuer in the air cannot strike). See Pursuit.air.
--   * A hit THROWS the boat (Boats.shove) far more than it hurts it, never below the hull floor; the treasure
--     follows the grip rule; and a goblin the world hit a moment ago cannot be hit again (Impact). After the
--     Guardian's launch, nothing from the world lands until they are down (P.LIFT_GRACE).
--
-- Forms (one per island, each a different kind of chase; numbers beside each):
--   Windmill  Bramble in a washtub: lines up and CHARGES in a straight line. Turn or jump when he bleats.
--   Tangle    the JADE FROGS (V13.1): bound over the waves after you; one pounces on a ringed boat. Get off the ring.
--   Shoals    Old Clacker under the water: a ring opens where you are going, then up he comes.
--   Tide      the Warden eel: goes under the bow and lashes the boat round.
--   Coral     the clam, in jets: clamps on and drags. Jump: it cannot hold a boat in the air.
--   Maelstrom the Maw's whirlpool follows you, pulling everything in. Slow: it drains away and reforms behind you.
--   Crystal   the ECHO: tiny, crystal, absurdly quick. It runs your own wake a moment behind, then darts.
--   Fort      the garrison's gunboat: hangs back and drops marked shot ahead of you.
--   Temple    the GUARDIAN leaps into a tiny stone speedboat and chases at "Mach 7"; every so often a stone fist
--             punches up under the thief and LAUNCHES them twenty feet up (marked first).
--   Cross     a WATCHER rides a stone slab after you, and like the statues it only moves while nobody faces it.
--   Ember     the cinderlings race AHEAD on a lava-rock raft and lay burning patches across your way.
--   Frost     the Chill (V13.1) flies down after you, locks on and bursts ICE SPIKES up under you; freezes the odd patch.
-- The Leviathan (Bone) and the Ghost Fleet (Skull) are pursuers too, in their own modules, under the same rules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Twister = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Twister"))
local Util = require(script.Parent.Util)
local GuardianLook = require(script.Parent.GuardianLook)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Loot = require(script.Parent.Loot)
local SeaNav = require(script.Parent.SeaNav)
local Blast = require(script.Parent.Blast)
local Impact = require(script.Parent.Impact)
local Creatures = require(script.Parent.Creatures)
local Threats = require(script.Parent.Threats)

local Pursuit = {}
-- V13: (player, islandId): a pursuit of this goblin ended because they reached the sanctuary (an escape). The
-- Leviathan ("Bone") and the Ghost Fleet ("Skull") fire it too.
Pursuit.Escaped = Util.signal()

local P = Config.PURSUIT
-- V13: the Wraith's ghost. While one runs for a goblin, a pursuer within its `fool` range chases the ghost instead.
local decoys = {} -- player -> { at = Vector3, velocity = Vector3, untilAt, fool }
local GB = Config.GUARDIAN_BOAT
local SEA_SCALE = Config.GUARDIAN_SCALE.SeaForm

local forms = {} -- island id -> form
local active = {} -- pursuers out now
local readyAt = {} -- island id -> when it may set out again
local zones = {} -- patches left on the water (fire, ice): { position, radius, untilAt, kind, part }
local folder
local refs
local kickers = {} -- the sea's ramps, as { x, z, r }: a pursuer that crosses one fast is thrown
local nextCheck = 0
local generation = 0
local random = Random.new()

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

-- Shared tools (the sea mobs, the Leviathan and the Ghost Fleet use them too) --------------------------
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

-- V9: the sanctuary round Goblin Cove. No pursuer follows a thief into it.
function Pursuit.hoard()
	return refs and refs.hoard.position or Vector3.zero
end

function Pursuit.inSanctuary(position, margin)
	if not refs then
		return false
	end
	local hoard = refs.hoard.position
	local dx, dz = position.X - hoard.X, position.Z - hoard.Z
	local r = Config.SANCTUARY.RADIUS + (margin or 0)
	return dx * dx + dz * dz < r * r
end

-- Hull damage from a creature: it batters a boat, it never sinks one.
function Pursuit.batter(boat, amount, cause)
	local room = boat.health - boat.spec.health * Config.IMPACT.HULL_FLOOR
	if room > 0 and amount > 0 then
		Boats.damage(boat, math.min(amount, room), cause)
	end
end

-- Hit a goblin, or the boat under them. opts: push (studs/s away), lift (studs/s up), spin, hull,
-- damage, reason (the grip rule), text, away (a direction, instead of straight away from `from`),
-- along (studs/s along the boat's own way). V9: nothing at all happens to a goblin the world hit a
-- moment ago (Impact), boat included: one thing at a time, never a juggle.
function Pursuit.hit(player, from, opts)
	local root, humanoid, boat = Pursuit.vessel(player)
	if not root or humanoid.Health <= 0 then
		return false
	end
	if not Impact.open(player) then
		return false
	end
	local away = opts.away or flat(root.Position - from)
	away = away.Magnitude > 0.5 and away.Unit or Vector3.new(0, 0, 1)
	local throw = away * (opts.push or 0) + Vector3.new(0, opts.lift or 0, 0)
	if opts.along then
		local part = boat and boat.hull or root
		local v = flat(part.AssemblyLinearVelocity)
		throw += (v.Magnitude > 5 and v.Unit or away) * opts.along
	end
	if boat then
		Boats.shove(boat, throw, opts.spin and Vector3.new(0, opts.spin, 0) or nil, opts.tumble)
		Pursuit.batter(boat, opts.hull or 0, opts.cause)
	end
	return Creatures.strike({ player = player, root = root, humanoid = humanoid }, from, {
		damage = opts.damage,
		push = not boat and throw or nil,
		reason = opts.reason,
		cause = opts.cause,
		harmless = opts.harmless,
		text = opts.text,
		opened = true,
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
-- parts: { { name, size, offset (CFrame from the root), color, material, shape, transparency } }.
-- V9: `scale` grows the whole body (sizes and offsets) for the bigger guardians.
function Pursuit.body(name, parts, scale)
	scale = scale or 1
	if scale ~= 1 then
		local grown = {}
		for i, spec in ipairs(parts) do
			local copy = table.clone(spec)
			copy[2] = spec[2] * scale
			if spec[3] then
				copy[3] = CFrame.new(spec[3].Position * scale) * spec[3].Rotation
			end
			grown[i] = copy
		end
		parts = grown
	end
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
	-- V13.1: a GHOST (the Ghost Fleet's ships) sails straight through rocks and islands: it never steers round
	-- land, so it can never be stuck behind it (they were, and stopped following).
	if not mover.ghost and not open(want) then
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
	-- V9: nothing chases into the sanctuary.
	if mover.keepOut ~= false and Pursuit.inSanctuary(p) then
		return true
	end
	mover.position = Vector3.new(p.X, 0, p.Z)
	return true
end

-- Put a mover's body on the waves (ride: studs above the surface, negative for under it). V9: plus its
-- altitude when something has thrown it, spinning while a tornado has it.
function Pursuit.place(mover, ride, extra)
	local p = mover.position
	local y = Sea.waveAt(p.X, p.Z, now()) + (ride or 0) + (mover.alt or 0)
	local heading = mover.heading or Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X + heading.X, y, p.Z + heading.Z))
	if mover.spin then
		frame *= CFrame.Angles(0, mover.spin, 0)
	end
	if extra then
		frame *= extra
	end
	mover.root.CFrame = frame
end

-- V9: a kinematic body in the air. A ramp throws it, a tornado lifts and spins it, gravity brings it down.
-- Returns true while it is up (high enough that it should not strike or be struck).
function Pursuit.air(mover, dt, t)
	mover.alt = mover.alt or 0
	mover.vy = mover.vy or 0
	mover.push = mover.push or Vector3.zero
	local p = mover.position
	local wave = Sea.waveAt(p.X, p.Z, t)
	local moving = (mover.heading or Vector3.zero) * (mover.speed or 0) + mover.push
	local accel =
		Twister.accel(Vector3.new(p.X, wave + mover.alt + 2, p.Z), moving + Vector3.new(0, mover.vy, 0), t, P.GRAVITY)
	if accel then
		mover.vy += accel.Y * dt
		mover.push += Vector3.new(accel.X, 0, accel.Z) * dt
		mover.twistedAt = t
	end
	-- Ramps: a fast pursuer that crosses one is thrown like a boat.
	if mover.alt < 2 and (mover.speed or 0) > 60 and t - (mover.rampAt or -10) > 1.5 then
		for _, k in ipairs(kickers) do
			local dx, dz = p.X - k.x, p.Z - k.z
			if dx * dx + dz * dz < (k.r + 6) ^ 2 then
				mover.rampAt = t
				mover.vy = math.max(mover.vy, 70 + (mover.speed or 0) * 0.12)
				Pursuit.fx("splash", Vector3.new(p.X, 1, p.Z))
				break
			end
		end
	end
	if mover.alt > 0 or mover.vy > 0 then
		mover.vy -= P.GRAVITY * dt
		mover.alt += mover.vy * dt
		if mover.alt <= 0 then
			local fall = -mover.vy
			mover.alt, mover.vy = 0, 0
			if fall > 60 then
				mover.splashedAt = t
				Pursuit.fx("splash", Vector3.new(p.X, 1, p.Z))
			end
		end
	end
	if mover.push.Magnitude > 0.5 then
		local step = mover.position + mover.push * dt
		if not Pursuit.inSanctuary(step) then
			mover.position = Vector3.new(step.X, 0, step.Z)
		end
		mover.push *= math.max(0, 1 - (mover.alt > 1 and 0.35 or 1.8) * dt)
	end
	-- Round and round while a funnel has it; level again once it is down.
	if mover.twistedAt and t - mover.twistedAt < 0.3 then
		mover.spin = (mover.spin or 0) + 7 * dt
	elseif mover.spin and mover.alt < 1 then
		mover.spin = nil
	end
	return mover.alt > 4
end

-- V13: a decoy for `player` (the Wraith's Phantom slip): pursuers within `fool` studs follow it until `untilAt`.
-- server/BoatAbilities.lua moves it (Pursuit.moveDecoy) along the boat's old course.
function Pursuit.decoy(player, at, velocity, untilAt, fool)
	decoys[player] = { at = flat(at), velocity = flat(velocity), untilAt = untilAt, fool = fool }
end

function Pursuit.moveDecoy(player, at, velocity)
	local d = decoys[player]
	if d then
		d.at, d.velocity = flat(at), flat(velocity)
	end
end

-- The ghost a pursuer at `from` is fooled by, or nil.
function Pursuit.decoyOf(player, from)
	local d = decoys[player]
	if not d then
		return nil
	end
	if workspace:GetServerTimeNow() >= d.untilAt then
		decoys[player] = nil
		return nil
	end
	if from and flat(from - d.at).Magnitude > d.fool then
		return nil
	end
	return d
end

-- V13: the Ironbelly's Ram Plow: pursuers it runs into are shoved aside and wallow for a moment (it does not count
-- as an explosion: nothing is sent home by being plowed). Returns how many it moved.
function Pursuit.shoveAt(position, radius, push, away)
	local moved = 0
	local t = workspace:GetServerTimeNow()
	for _, p in ipairs(active) do
		if
			p.state ~= "quit"
			and p.state ~= "board"
			and flat(p.position - position).Magnitude <= radius + p.form.size
		then
			local dir = away or flat(p.position - position)
			dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
			p.push = (p.push or Vector3.zero) + dir * push
			p.vy = math.max(p.vy or 0, 40)
			if p.state ~= "flinch" then
				p.state = "rest"
				p.stateUntil = t + 1.6
			end
			Pursuit.fx("crash", p.position)
			moved += 1
		end
	end
	return moved
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
local GOLD = Color3.fromRGB(255, 205, 40)

local function ball(name, size, offset, color, material, transparency)
	return { name, Vector3.new(size, size, size), offset, color, material, Enum.PartType.Ball, transparency }
end

local function block(name, size, offset, color, material, transparency)
	return { name, size, offset, color, material, nil, transparency }
end

-- Every form shares this life: chase (paced, see the header), then, close enough, a tell, a strike and a
-- rest. A form supplies numbers and may replace any step with its own function.
local function defaults(form)
	form.speed = form.speed or 150 -- Its own pace when it has no thief to match (and the least it closes at).
	form.surge = form.surge or form.speed * 1.7 -- Its top speed: when far behind.
	form.close = form.close or 40 -- Studs/s it gains on a thief while closing.
	form.accel = form.accel or 170
	form.decel = form.decel or 75 -- It cannot stop as quickly as a boat can: a thief who slows is caught.
	form.turn = form.turn or 2.6
	form.reach = form.reach or 16 -- start the tell this close
	form.follow = form.follow or (form.reach > 0 and form.reach + 28 or 70) -- where it hangs, between lunges
	form.lunge = form.lunge or 55 -- a lunge: this much faster than the thief...
	form.lungeEvery = form.lungeEvery or 6 -- ...about this often...
	form.lungeTime = form.lungeTime or 1.1 -- ...for this long (long enough to reach striking range)
	form.leash = form.leash or P.LEASH
	form.time = form.time or P.TIME
	form.tell = form.tell or 0.8
	form.rest = form.rest or 3.5
	form.ride = form.ride or 0
	form.scale = form.scale or SEA_SCALE
	form.size = (form.size or 8) * form.scale
	form.startDelay = form.startDelay or 1.5 -- no strike this soon after it sets out
	return form
end

-- BRAMBLE (Windmill Hills): the ram, in a washtub, rowing with its horns down. It lines up and CHARGES
-- in a straight line it cannot turn out of: a turn or a jump and it thunders past.
forms.Windmill = defaults({
	name = "Bramble's Tub",
	say = "BRAMBLE THE RAM HAS PUT TO SEA IN A WASHTUB!",
	gone = "Bramble rows home, furious.",
	quit = "Bramble stops at the cove lights and bleats at you. Then he rows home.",
	color = Color3.fromRGB(235, 228, 210),
	speed = 160,
	surge = 270,
	reach = 105,
	follow = 135,
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
		p.chargeSpeed = math.max(260, (p.speed or 0) + 70) -- fixed for the whole charge
	end,
	strike = function(p, target, dt)
		local t = now()
		local charge = p.chargeSpeed or 260
		local step = p.position + p.heading * charge * dt
		if not Pursuit.inSanctuary(step) then
			p.position = step
		end
		p.speed = charge
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 16 + (boat and boat.spec.size.X * 0.5 or 0) then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 85,
				lift = 30,
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
		local probe = p.position + p.heading * 24
		return t > p.chargeUntil or not SeaNav.passable(probe.X, probe.Z, 1)
	end,
})

-- THE IMPS (Tangle Isle): three of them on a raft of lashed barrels. They do not ram: they pull alongside
-- and one LEAPS the gap for the treasure. Stay away from the raft's side for a moment and it is called off.
-- THE JADE FROGS (Tangle Isle, V13.1): the island's frogs plop into the sea after the thief and BOUND over the waves
-- after them, three abreast, splashing down every hop. Close up, one pounces: a ring opens under your boat (the tell:
-- they lock on and match your speed) and it lands on you (a hit: Config.KNOCKOUT). Boost, turn or jump off the ring.
-- (V8 to V13: the imps' raft, whose imps leapt for the treasure itself.)
local JADE = Color3.fromRGB(52, 178, 116)
local JADE_DARK = Color3.fromRGB(30, 118, 80)
local function frogParts(prefix, at)
	local o = CFrame.new(at)
	return {
		ball(prefix .. "Body", 3, o, JADE, Enum.Material.SmoothPlastic),
		ball(prefix .. "Head", 2.3, o * CFrame.new(0, 0.9, -1.3), JADE, Enum.Material.SmoothPlastic),
		ball(prefix .. "EyeL", 1, o * CFrame.new(-0.7, 1.9, -1.4), GOLD, Enum.Material.Neon),
		ball(prefix .. "EyeR", 1, o * CFrame.new(0.7, 1.9, -1.4), GOLD, Enum.Material.Neon),
		block(
			prefix .. "LegL",
			Vector3.new(0.8, 0.9, 2.4),
			o * CFrame.new(-1.4, -0.9, 0.6),
			JADE_DARK,
			Enum.Material.SmoothPlastic
		),
		block(
			prefix .. "LegR",
			Vector3.new(0.8, 0.9, 2.4),
			o * CFrame.new(1.4, -0.9, 0.6),
			JADE_DARK,
			Enum.Material.SmoothPlastic
		),
	}
end
local function frogPack()
	-- The first part is the root (an invisible float); then three frogs in a wedge.
	local parts = { block("Pack", Vector3.new(2, 1, 2), nil, JADE, Enum.Material.SmoothPlastic, 1) }
	for _, spec in ipairs({
		{ "A", Vector3.new(0, 1, -3) },
		{ "B", Vector3.new(-4.5, 1, 2) },
		{ "C", Vector3.new(4.5, 1, 2) },
	}) do
		for _, part in ipairs(frogParts(spec[1], spec[2])) do
			table.insert(parts, part)
		end
	end
	return parts
end
-- Where a sea form sets out from: the nearest of an island creature's bodies to the thief (`prefix` names them).
local function creatureNear(prefix, target, within)
	local root = Pursuit.vessel(target)
	if not root then
		return nil
	end
	local best, bestDistance
	for _, creature in ipairs(Creatures.list) do
		if string.sub(creature.name, 1, #prefix) == prefix and creature.position and not creature.hidden then
			local distance = Util.flatDistance(creature.position, root.Position)
			if distance < within and (not bestDistance or distance < bestDistance) then
				best, bestDistance = creature.position, distance
			end
		end
	end
	if best then
		-- Into the water on the thief's side of it: the water nearest a point a little way from the thief back
		-- toward the creature (the water nearest the creature itself could be across the island).
		local back = Vector3.new(best.X - root.Position.X, 0, best.Z - root.Position.Z)
		local step = math.min(70, back.Magnitude * 0.5)
		local probe = root.Position + (back.Magnitude > 1 and back.Unit * step or Vector3.zero)
		local water = SeaNav.nearestWater(probe.X, probe.Z, 2)
		return water and Vector3.new(water.X, 0, water.Z) or nil
	end
	return nil
end

forms.Tangle = defaults({
	name = "The Jade Frogs",
	say = "THE JADE FROGS HAVE HOPPED IN AFTER YOU!",
	gone = "The jade frogs croak and paddle home.",
	quit = "The jade frogs bob at the cove lights, croak at you, and hop home.",
	color = JADE,
	speed = 175,
	surge = 290,
	turn = 3.6,
	reach = 24,
	tell = 0.75,
	rest = 2.2,
	follow = 55,
	clear = -math.huge, -- after you the moment you are in the water
	scale = 1.5,
	body = frogPack(),
	from = function(_island, target)
		return creatureNear("JadeFrog", target, 600)
	end,
	-- Bounding over the waves: a hop every 0.55 s (faster when it is faster), a splash each time it comes down.
	always = function(p, _target, dt, t)
		p.hopPhase = (p.hopPhase or 0) + dt * (1.2 + (p.speed or 0) / 150)
		local s = math.abs(math.sin(p.hopPhase * math.pi))
		p.bob = p.state == "tell" and 0 or s * 9
		if p.hopPhase - (p.lastSplash or 0) >= 1 then
			p.lastSplash = math.floor(p.hopPhase)
			if t - (p.splashFxAt or 0) > 0.9 then
				p.splashFxAt = t
				Pursuit.fx("splash", p.position)
			end
		end
	end,
	onTell = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at then
			Creatures.mark(Vector3.new(at.X, 0.5, at.Z), 18, p.form.tell, JADE)
		end
		Pursuit.fx("croak", p.position)
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 30 then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 40,
				lift = 55,
				spin = 2,
				hull = 6,
				damage = 12,
				reason = "frog",
				cause = "the jade frogs",
				text = "A JADE FROG POUNCED ON YOUR BOAT!",
			})
			Pursuit.fx("crash", at)
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
	quit = "Old Clacker clacks his claws at the cove lights and sinks out of sight.",
	color = Color3.fromRGB(214, 84, 60),
	speed = 160,
	surge = 280,
	reach = 22,
	tell = 0.95,
	rest = 4,
	ride = -3.4,
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
		Creatures.mark(Vector3.new(p.strikeAt.X, 0.5, p.strikeAt.Z), 22, p.form.tell, p.form.color)
	end,
	-- During the tell it slides under the mark.
	telling = function(p, _target, dt)
		Pursuit.swim(p, p.strikeAt, 220, dt, 6)
	end,
	strike = function(p, target)
		p.position = p.strikeAt
		p.popUntil = now() + 1.2 -- it shows itself, claws up
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.strikeAt).Magnitude < 22 + (boat and boat.spec.size.Z * 0.3 or 0) then
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

-- THE WARDEN (Tide Vault): the eel. It does not bite the boat: it goes under the bow and LASHES it round.
-- You end up pointing the wrong way.
forms.Tide = defaults({
	name = "The Warden",
	say = "THE WARDEN EEL IS LOOSE IN THE OPEN WATER!",
	gone = "The Warden turns back for its vault.",
	quit = "The Warden circles once at the cove lights, crackling, and slides away.",
	color = Color3.fromRGB(70, 210, 190),
	speed = 175,
	surge = 290,
	turn = 3,
	reach = 30,
	tell = 0.55,
	rest = 3.6,
	ride = -1.4,
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
		if at and flat(at - p.position).Magnitude < 40 then
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
	quit = "The clam snaps shut at the cove lights and sinks in a sulk.",
	color = Color3.fromRGB(255, 170, 190),
	speed = 170,
	surge = 260,
	reach = 14,
	tell = 0.35,
	rest = 5,
	ride = -0.8,
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
	-- Jets: a burst, then a glide (on top of its pacing).
	pace = function(_p, t)
		return (t % 2.1) < 0.95 and 1.3 or 0.75
	end,
	onTell = function(p)
		Pursuit.fx("clap", p.position)
	end,
	strike = function(p, target, dt)
		-- Clamped on: ride the hull and drag it, until it jumps, time runs out or something goes bang.
		local t = now()
		if not p.clampUntil then
			-- It has to actually get its shell on the hull first.
			local root0, _, boat0 = Pursuit.vessel(target)
			local hull0 = boat0 and boat0.hull or root0
			if
				not hull0
				or flat(hull0.Position - p.position).Magnitude > 22 + (boat0 and boat0.spec.size.Z * 0.5 or 0)
				or not Impact.open(target)
			then
				return true
			end
			p.clampUntil = t + 4
		end
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
		p.position = flat(hull.Position) - flat(hull.CFrame.LookVector) * 5
		p.speed = flat(hull.AssemblyLinearVelocity).Magnitude
		p.dragAt = (p.dragAt or 0) - dt
		if p.dragAt <= 0 then
			p.dragAt = 0.25
			if not p.told then
				p.told = true
				Net.toast(target, "THE CLAM HAS YOUR HULL! Jump (SPACE) to shake it off!")
			end
			if boat then
				Boats.shove(boat, -flat(hull.AssemblyLinearVelocity) * 0.28)
			end
		end
		return false
	end,
	afterStrike = function(p)
		p.told = nil
	end,
})

-- THE MAW (Maelstrom Rock): its whirlpool gets up and FOLLOWS. Anything within reach is pulled in and round,
-- and the middle spits you into the air. It is slow; left far behind it drains away and reforms behind you.
forms.Maelstrom = defaults({
	name = "The Wandering Maw",
	say = "THE MAELSTROM HAS LEFT ITS ROCK. IT IS FOLLOWING YOU!",
	gone = "The Maw drifts home.",
	quit = "The Maw spins down to nothing at the cove lights.",
	color = Color3.fromRGB(120, 170, 255),
	speed = 110,
	surge = 195,
	close = 30,
	turn = 1.6,
	reach = 0, -- no tell of its own: the pull is the warning
	follow = 95,
	lunge = 0,
	rest = 5,
	ride = 0.4,
	size = 30,
	scale = Config.GUARDIAN_SCALE.Maw,
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
		local reach = 170 * Config.GUARDIAN_SCALE.Maw
		for _, boat in ipairs(Boats.list) do
			if boat.state == "float" and not boat.ai then
				local offset = flat(p.position - boat.hull.Position)
				local distance = offset.Magnitude
				if distance < reach and distance > 1 and not Pursuit.inSanctuary(boat.hull.Position) then
					if distance < 32 and t >= (p.spatAt or 0) then
						p.spatAt = t + 5
						local out = turned(offset.Unit, math.rad(140))
						Boats.shove(boat, out * 70 + Vector3.new(0, 78, 0), Vector3.new(0, 2, 0))
						Pursuit.batter(boat, 8, "the Maw")
						Pursuit.fx("erupt", boat.hull.Position)
					elseif t >= (p.spatAt or 0) - 3.5 then
						local strength = (1 - distance / reach) * 30
						Boats.shove(boat, (offset.Unit + turned(offset.Unit, math.rad(90)) * 0.8) * strength * 0.25)
					end
				end
			end
		end
	end,
})

-- THE ECHO (Crystal Isle): the exception to "bigger". A tiny crystal imp on a sliver of crystal, the
-- fastest, sharpest-turning thing in the sea. It still REPEATS you: it runs your own wake a moment behind
-- (so it takes every turn you took), until it is close enough to dart straight at you, skipping across
-- the water. Its hit is small: it slams the hull sideways and saps its speed. It never takes the treasure.
forms.Crystal = defaults({
	name = "The Echo",
	say = "YOUR ECHO IS CHASING YOUR WAKE. IT IS TINY. IT IS SO FAST.",
	gone = "The Echo fades.",
	quit = "The Echo shatters into sparkles at the cove lights.",
	color = Color3.fromRGB(215, 120, 255),
	speed = 230,
	surge = 340,
	close = 75,
	accel = 480, -- it is hyperactive: up to speed in half a second...
	decel = 380, -- ...and it can stop on a coin
	turn = 9,
	reach = 13,
	follow = 26,
	lunge = 0, -- it darts instead (below)
	tell = 0.45, -- (a quick tell, but long enough to boost or turn away)
	rest = 3.5,
	ride = 1.2,
	scale = 1, -- small, on purpose (its parts are already tiny)
	size = 3,
	startDelay = 2.5, -- never an attack the moment it appears
	trail = Color3.fromRGB(230, 160, 255),
	-- V10: still tiny, now a character. A crystal imp crouched on a sliver of crystal like a surfer: a faceted
	-- violet body round a glowing core, a diamond head with two cyan eyes and crystal horns, a crown of three
	-- shards down its back, arms thrown out for balance. The board glows cyan underneath; the trail is violet.
	body = {
		block("Shard", Vector3.new(2, 0.6, 5.4), nil, Color3.fromRGB(176, 110, 255), Enum.Material.Glass, 0.15),
		block(
			"ShardNose",
			Vector3.new(1.42, 0.6, 1.42),
			CFrame.new(0, 0, -2.7) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(176, 110, 255),
			Enum.Material.Glass,
			0.15
		),
		block(
			"ShardGlow",
			Vector3.new(1.6, 0.2, 5),
			CFrame.new(0, -0.38, 0),
			Color3.fromRGB(110, 230, 255),
			Enum.Material.Neon,
			0.1
		),
		block(
			"Body",
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(0, 1.3, 0.5) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color3.fromRGB(196, 140, 255),
			Enum.Material.Glass,
			0.2
		),
		ball("Core", 0.8, CFrame.new(0, 1.3, 0.5), Color3.fromRGB(255, 230, 255), Enum.Material.Neon, 0),
		block(
			"Head",
			Vector3.new(1, 1, 1),
			CFrame.new(0, 2.5, 0.2) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color3.fromRGB(214, 170, 255),
			Enum.Material.Glass,
			0.1
		),
		block(
			"EyeL",
			Vector3.new(0.22, 0.22, 0.12),
			CFrame.new(-0.25, 2.55, -0.38),
			Color3.fromRGB(110, 240, 255),
			Enum.Material.Neon,
			0
		),
		block(
			"EyeR",
			Vector3.new(0.22, 0.22, 0.12),
			CFrame.new(0.25, 2.55, -0.38),
			Color3.fromRGB(110, 240, 255),
			Enum.Material.Neon,
			0
		),
		block(
			"HornL",
			Vector3.new(0.2, 1, 0.2),
			CFrame.new(-0.4, 3.2, 0.2) * CFrame.Angles(0, 0, math.rad(25)),
			Color3.fromRGB(240, 200, 255),
			Enum.Material.Neon,
			0.1
		),
		block(
			"HornR",
			Vector3.new(0.2, 1, 0.2),
			CFrame.new(0.4, 3.2, 0.2) * CFrame.Angles(0, 0, math.rad(-25)),
			Color3.fromRGB(240, 200, 255),
			Enum.Material.Neon,
			0.1
		),
		block(
			"ArmL",
			Vector3.new(1.3, 0.25, 0.25),
			CFrame.new(-1, 1.5, 0.4) * CFrame.Angles(0, 0, math.rad(-20)),
			Color3.fromRGB(196, 140, 255),
			Enum.Material.Glass,
			0.2
		),
		block(
			"ArmR",
			Vector3.new(1.3, 0.25, 0.25),
			CFrame.new(1, 1.7, 0.4) * CFrame.Angles(0, 0, math.rad(30)),
			Color3.fromRGB(196, 140, 255),
			Enum.Material.Glass,
			0.2
		),
		block(
			"Spike",
			Vector3.new(0.3, 1.6, 0.3),
			CFrame.new(0, 1.9, 1.3) * CFrame.Angles(math.rad(35), 0, 0),
			Color3.fromRGB(240, 190, 255),
			Enum.Material.Neon,
			0.15
		),
		block(
			"Spike",
			Vector3.new(0.25, 1.2, 0.25),
			CFrame.new(-0.35, 1.6, 1.4) * CFrame.Angles(math.rad(40), 0, math.rad(20)),
			Color3.fromRGB(240, 190, 255),
			Enum.Material.Neon,
			0.15
		),
		block(
			"Spike",
			Vector3.new(0.25, 1.2, 0.25),
			CFrame.new(0.35, 1.6, 1.4) * CFrame.Angles(math.rad(40), 0, math.rad(-20)),
			Color3.fromRGB(240, 190, 255),
			Enum.Material.Neon,
			0.15
		),
	},
	-- Its own way of moving. Far off it cuts straight at you, taking every angle; close, it REPEATS you,
	-- running your exact wake a fraction of a second behind (every turn you took, it takes); and every second
	-- or two it DARTS, skipping across the water straight at where you are now.
	move = function(p, _target, dt, t, info)
		local spot = info.at
		p.trail = p.trail or {}
		p.trailAt = (p.trailAt or 0) - dt
		if p.trailAt <= 0 then
			p.trailAt = 0.05
			table.insert(p.trail, { t = t, position = spot })
			while #p.trail > 40 do
				table.remove(p.trail, 1)
			end
		end
		-- How far behind your wake it runs: 0.6 s at first, closing to 0.3 s.
		p.delay = math.max(0.3, (p.delay or 0.6) - dt * 0.02)
		local goal = spot + info.velocity * 0.25
		if info.gap < 110 then
			local want = t - p.delay
			goal = p.trail[1].position
			for _, sample in ipairs(p.trail) do
				if sample.t <= want then
					goal = sample.position
				else
					break
				end
			end
		end
		if t >= (p.nextDart or 0) and info.gap > 18 and info.gap < 220 and (p.alt or 0) < 1 then
			p.nextDart = t + random:NextNumber(0.9, 1.7)
			p.dartUntil = t + 0.3
			p.vy = 26
			Pursuit.fx("dart", p.position)
		end
		local wantSpeed
		if p.dartUntil and t < p.dartUntil then
			goal = spot
			wantSpeed = info.targetSpeed + 240
		else
			wantSpeed = info.pace
		end
		local rate = wantSpeed > p.speed and p.form.accel or p.form.decel
		p.speed += math.clamp(wantSpeed - p.speed, -rate * dt, rate * dt)
		return Pursuit.swim(p, goal, p.speed, dt, p.form.turn)
	end,
	onTell = function(p)
		Pursuit.fx("chime", p.position)
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 15 + (boat and boat.spec.size.Z * 0.35 or 0) then
			p.landed = true
			local part = boat and boat.hull or root
			local across = turned(p.heading, math.rad(90 * (random:NextNumber() < 0.5 and 1 or -1)))
			Pursuit.hit(target, p.position, {
				away = across,
				push = 46,
				lift = 16,
				spin = 2,
				hull = 2,
				damage = 4,
				cause = "the Echo",
				text = "THE ECHO SLAMS YOUR HULL! Keep moving!",
			})
			if boat then
				Boats.shove(boat, -flat(part.AssemblyLinearVelocity) * 0.25)
			end
			Pursuit.fx("shatter", at)
			-- It bounces off, back down your wake.
			p.speed = 0
			p.delay = 0.6
			table.clear(p.trail or {})
		end
		return true
	end,
})

-- THE GARRISON'S LAUNCH (Fort Barnacle): two marines in a gunboat with a swivel gun. It keeps its distance and
-- drops shot ahead of you, each one marked on the water first.
forms.Fort = defaults({
	name = "The Garrison's Gunboat",
	say = "THE GARRISON HAS LAUNCHED A GUNBOAT AFTER YOU!",
	gone = "The gunboat turns back for the fort.",
	quit = "The gunboat fires a last flare at the cove lights and turns for home.",
	color = Color3.fromRGB(245, 245, 250),
	speed = 160,
	surge = 260,
	reach = 0,
	follow = 100,
	lunge = 0,
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
	always = function(p, target, dt)
		p.fireAt = (p.fireAt or 3) - dt
		if p.fireAt > 0 or (p.alt or 0) > 2 then
			return
		end
		p.fireAt = 3.4
		local spot = Pursuit.lead(target, 1.25)
		if spot and flat(spot - p.position).Magnitude < 280 and not Pursuit.inSanctuary(spot) then
			local at = Vector3.new(spot.X, 0.5, spot.Z)
			Net.broadcastNear(at, 1200, "Shell", { from = p.position + Vector3.new(0, 6, 0), to = at, duration = 1.25 })
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

-- THE SUN TEMPLE GUARDIAN: it LEAPS from its temple into a tiny stone speedboat and comes after you faster than
-- anything else on the sea. It turns wide and overshoots, so a hard turn buys a moment. Every GB.COOLDOWN
-- seconds, close enough, it raises its fists, a gold ring opens where you are going, and a stone fist punches up
-- out of the sea: whatever is on the ring goes about twenty feet up. It keeps you, and your treasure, in one piece.
local GUARDIAN_RIDER_SCALE = 1.15
-- V10: the speedboat is a racing toy (a gold-striped stone hull with a big 7 on each side, a windshield, a
-- chrome motor with a flame), and the rider is the island's own Guardian (GuardianLook), squeezed in up to its
-- belt. Two sets of arms: gripping the gunwales, and (shown only for the launch) both fists overhead.
local function guardianRider()
	local s = GUARDIAN_RIDER_SCALE
	local deck = 1.4
	local HULL = Color3.fromRGB(132, 120, 108)
	local parts = {
		block("Hull", Vector3.new(8, 2.4, 13), nil, HULL, Enum.Material.Slate),
		block(
			"Keel",
			Vector3.new(5.6, 1.4, 12),
			CFrame.new(0, -1.6, 0.4),
			Color3.fromRGB(96, 86, 80),
			Enum.Material.Slate
		),
		block("Trim", Vector3.new(8.4, 0.6, 13.4), CFrame.new(0, 1.3, 0), GOLD, Enum.Material.Metal),
		block(
			"Stripe",
			Vector3.new(8.5, 0.7, 9),
			CFrame.new(0, 0.1, 1.5),
			Color3.fromRGB(226, 64, 52),
			Enum.Material.SmoothPlastic
		),
		block(
			"Bow",
			Vector3.new(6, 2, 4.6),
			CFrame.new(0, 0.5, -7.6) * CFrame.Angles(math.rad(-25), 0, 0),
			HULL,
			Enum.Material.Slate
		),
		block(
			"BowTip",
			Vector3.new(3.4, 1.4, 3),
			CFrame.new(0, 0.1, -9.8) * CFrame.Angles(math.rad(-38), 0, 0),
			GOLD,
			Enum.Material.Metal
		),
		block(
			"Motor",
			Vector3.new(3, 4, 2.4),
			CFrame.new(0, 2, 7.4),
			Color3.fromRGB(196, 200, 210),
			Enum.Material.DiamondPlate
		),
		block(
			"MotorCap",
			Vector3.new(3.4, 1, 2.8),
			CFrame.new(0, 4.4, 7.4),
			Color3.fromRGB(226, 64, 52),
			Enum.Material.SmoothPlastic
		),
		block(
			"Flame",
			Vector3.new(2, 2, 3),
			CFrame.new(0, 0.6, 9.6),
			Color3.fromRGB(255, 150, 40),
			Enum.Material.Neon,
			0.2
		),
		block(
			"Windshield",
			Vector3.new(6, 2.4, 0.4),
			CFrame.new(0, 2.6, -4.4) * CFrame.Angles(math.rad(-20), 0, 0),
			Color3.fromRGB(180, 220, 255),
			Enum.Material.Glass,
			0.4
		),
	}
	for _, spec in ipairs(GuardianLook.posed(1.15, 0)) do
		if spec.name ~= "LegL" and spec.name ~= "LegR" and spec.name ~= "FootL" and spec.name ~= "FootR" then
			local cf = spec.cframe
			table.insert(parts, {
				"Rider" .. spec.name,
				spec.size * s,
				CFrame.new(cf.Position.X * s, deck + (cf.Position.Y - 6) * s, cf.Position.Z * s + 0.5) * cf.Rotation,
				spec.name == "Eye" and Color3.fromRGB(255, 60, 40) or spec.color, -- awake, and furious
				spec.material,
				spec.shape,
				0,
			})
		end
	end
	-- ...and the raised arms for the launch (shown only during its tell).
	for _, spec in ipairs(GuardianLook.posed(2.8, 0)) do
		if spec.limb == "armL" or spec.limb == "armR" then
			local cf = spec.cframe
			table.insert(parts, {
				"RiderUp" .. spec.name,
				spec.size * s,
				CFrame.new(cf.Position.X * s, deck + (cf.Position.Y - 6) * s, cf.Position.Z * s + 0.5) * cf.Rotation,
				spec.color,
				spec.material,
				spec.shape,
				1,
			})
		end
	end
	return parts
end

-- Show the rider (it has landed in the boat), and its arms down or up.
local function riderLook(p, visible, armsUp)
	if not p.model then
		return
	end
	for _, part in ipairs(p.model:GetChildren()) do
		local name = part.Name
		if part:IsA("BasePart") and string.sub(name, 1, 5) == "Rider" then
			local up = string.find(name, "Up", 6, true) ~= nil
			part.Transparency = (visible and (up == (armsUp == true))) and 0 or 1
		end
	end
	local flame = p.model:FindFirstChild("Flame")
	if flame then
		flame.Transparency = visible and 0.2 or 1
	end
end

local function launchFist(at, color)
	local fist = Instance.new("Part")
	fist.Name = "GuardianFist"
	fist.Size = Vector3.new(14, 26, 14)
	fist.Material = Enum.Material.Slate
	fist.Color = GuardianLook.STONE
	fist.Anchored = true
	fist.CanCollide = false
	fist.CanQuery = false
	fist.CanTouch = false
	fist.CFrame = CFrame.new(at.X, -16, at.Z)
	fist.Parent = folder
	local knuckles = fist:Clone()
	knuckles.Name = "GuardianKnuckles"
	knuckles.Size = Vector3.new(16, 6, 16)
	knuckles.Color = color
	knuckles.Material = Enum.Material.Metal
	knuckles.Parent = fist
	local current = generation
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < 1.3 and current == generation and fist.Parent do
			local k = (os.clock() - started) / 1.3
			local rise = k < 0.18 and (k / 0.18) or (k < 0.65 and 1 or 1 - (k - 0.65) / 0.35)
			local y = -16 + rise * 26
			fist.CFrame = CFrame.new(at.X, y, at.Z)
			knuckles.CFrame = CFrame.new(at.X, y + 14, at.Z)
			task.wait()
		end
		fist:Destroy()
	end)
end

forms.Temple = defaults({
	name = "The Guardian's Speedboat",
	say = "THE GUARDIAN HAS A BOAT. IT IS COMING AT YOU AT MACH 7!",
	gone = "The Guardian turns its boat for the temple.",
	quit = "The Guardian's boat skids to a stop at the cove lights. It shakes a stone fist at you. Then it sails home, slowly.",
	color = GOLD,
	speed = GB.SPEED,
	surge = GB.SURGE,
	close = 80,
	accel = GB.ACCEL,
	decel = 85,
	turn = GB.TURN,
	reach = 0, -- its own tell (the launch), below
	follow = GB.FOLLOW,
	lunge = 0,
	tell = GB.TELL,
	rest = 1.2,
	ride = 0.4,
	size = 10,
	scale = Config.GUARDIAN_SCALE.SeaForm,
	startDelay = GB.LEAP_TIME + 2.5,
	trail = Color3.fromRGB(255, 220, 140),
	body = guardianRider(),
	-- It leaps aboard from wherever it stands on its island (Threats.guardianBoard).
	setOut = function(p)
		p.state = "board"
		p.stateUntil = now() + GB.LEAP_TIME
		p.nextLaunch = now() + GB.LEAP_TIME + 3
		riderLook(p, false)
		Threats.guardianBoard(Vector3.new(p.position.X, 2, p.position.Z), GB.LEAP_TIME)
	end,
	boarded = function(p)
		riderLook(p, true, false)
		Pursuit.fx("erupt", p.position)
		if p.target.Parent then
			Net.send(p.target, "Message", { text = p.form.say, duration = 3.5, color = GOLD })
		end
	end,
	finish = function(_p)
		Threats.guardianReturn()
	end,
	-- The launch: fists up, a ring where the thief is going, then the fist.
	always = function(p, target, _dt, t, info)
		if p.state ~= "chase" or (p.alt or 0) > 2 or t < (p.nextLaunch or 0) or t < p.bornAt + p.form.startDelay then
			return
		end
		if info.gap > GB.REACH then
			return
		end
		local spot = Pursuit.lead(target, GB.TELL * 0.85)
		if not spot or Pursuit.inSanctuary(spot) then
			return
		end
		p.state = "tell"
		p.stateUntil = t + GB.TELL
		p.strikeAt = spot
		riderLook(p, true, true)
		Creatures.mark(Vector3.new(spot.X, 0.5, spot.Z), GB.RADIUS, GB.TELL, GOLD)
		Pursuit.fx("gfist", p.position)
		Net.toast(target, "THE GUARDIAN RAISES ITS FISTS! Turn or boost off the ring!")
	end,
	strike = function(p, target)
		local t = now()
		riderLook(p, true, false)
		local at = p.strikeAt
		launchFist(at, GOLD)
		Pursuit.fx("erupt", Vector3.new(at.X, 1, at.Z))
		local root, _, boat = Pursuit.vessel(target)
		local where = boat and boat.hull.Position or (root and root.Position)
		if where and flat(where - at).Magnitude < GB.RADIUS + (boat and boat.spec.size.Z * 0.45 or 2) then
			p.landed = true
			-- V13.1: sky high and spinning, end over end the whole flight (the V13 playtest asked for it).
			local airtime = 2 * GB.LIFT / workspace.Gravity
			local landed = Pursuit.hit(target, at, {
				away = Vector3.new(0, 0, 0),
				push = 0,
				along = GB.PUSH,
				lift = GB.LIFT,
				spin = 1.2,
				hull = GB.HULL,
				damage = 2,
				cause = "the Guardian",
				tumble = { seconds = airtime * 0.96, altitude = GB.ALTITUDE, allow = GB.LAUNCH_ALLOW },
				text = "LAUNCHED BY THE GUARDIAN!",
			})
			if landed then
				Impact.protect(target, math.max(P.LIFT_GRACE, airtime + 0.6))
				Net.broadcastNear(at, 1400, "GuardianLaunch", { position = at, userId = target.UserId })
			end
			p.nextLaunch = t + GB.COOLDOWN
		else
			p.nextLaunch = t + GB.COOLDOWN * 0.5
		end
		return true
	end,
})

-- THE WATCHERS (Crossroads Ruins): one of the stone Watchers stands on a slab of its ruins and SURFS after you.
-- The statues' rule holds at sea: it only moves while no goblin within WATCH_RANGE is facing it. Turn your
-- boat to face it and it freezes, eyes dark (a friend can hold it for you); look away and it comes.
local WATCH_RANGE = 280
forms.Cross = defaults({
	name = "The Watcher on the Waves",
	say = "A WATCHER IS SURFING AFTER YOU. IT ONLY MOVES WHILE NOBODY FACES IT!",
	gone = "The Watcher sinks back toward its ruins.",
	quit = "The Watcher halts at the cove lights, eyes dark, and sinks like a stone.",
	color = Color3.fromRGB(255, 80, 60),
	speed = 180,
	surge = 300,
	reach = 22,
	tell = 0.6,
	rest = 4,
	ride = 0.6,
	scale = Config.GUARDIAN_SCALE.Watcher,
	body = {
		block("Slab", Vector3.new(8, 1.6, 12), nil, Color3.fromRGB(150, 145, 135), Enum.Material.Cobblestone),
		block(
			"Base",
			Vector3.new(4.4, 1.4, 4.4),
			CFrame.new(0, 1.5, 0),
			Color3.fromRGB(110, 105, 100),
			Enum.Material.Slate
		),
		block(
			"Body",
			Vector3.new(3, 7, 2.4),
			CFrame.new(0, 5.7, 0),
			Color3.fromRGB(170, 165, 150),
			Enum.Material.Cobblestone
		),
		block(
			"Head",
			Vector3.new(2.6, 2.6, 2.6),
			CFrame.new(0, 10.5, 0),
			Color3.fromRGB(170, 165, 150),
			Enum.Material.Slate
		),
		block(
			"EyeL",
			Vector3.new(0.6, 0.5, 0.3),
			CFrame.new(-0.6, 10.7, -1.36),
			Color3.fromRGB(255, 60, 50),
			Enum.Material.Neon
		),
		block(
			"EyeR",
			Vector3.new(0.6, 0.5, 0.3),
			CFrame.new(0.6, 10.7, -1.36),
			Color3.fromRGB(255, 60, 50),
			Enum.Material.Neon
		),
		block(
			"ArmL",
			Vector3.new(1, 4.4, 1),
			CFrame.new(-2.1, 7.3, -1.4) * CFrame.Angles(math.rad(-72), 0, 0),
			Color3.fromRGB(170, 165, 150),
			Enum.Material.Cobblestone
		),
		block(
			"ArmR",
			Vector3.new(1, 4.4, 1),
			CFrame.new(2.1, 7.3, -1.4) * CFrame.Angles(math.rad(-72), 0, 0),
			Color3.fromRGB(170, 165, 150),
			Enum.Material.Cobblestone
		),
	},
	-- Is any goblin near enough facing it? (A goblin in a boat faces where the boat points.)
	watched = function(p)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = Util.aliveRoot(player)
			if root then
				local to = flat(p.position - root.Position)
				if to.Magnitude < WATCH_RANGE and to.Magnitude > 1 then
					if flat(root.CFrame.LookVector).Unit:Dot(to.Unit) > 0.45 then
						return true
					end
				end
			end
		end
		return false
	end,
	move = function(p, _target, dt, _t, info)
		local frozen = p.form.watched(p)
		if frozen ~= p.frozen then
			p.frozen = frozen
			for _, name in ipairs({ "EyeL", "EyeR" }) do
				local eye = p.model and p.model:FindFirstChild(name)
				if eye then
					eye.Color = frozen and Color3.fromRGB(60, 20, 20) or Color3.fromRGB(255, 60, 50)
				end
			end
			if frozen then
				Pursuit.fx("stone", p.position)
			end
		end
		if frozen then
			p.speed = 0 -- a statue does not coast
			return true
		end
		local rate = info.pace > p.speed and p.form.accel * 1.6 or p.form.decel
		p.speed += math.clamp(info.pace - p.speed, -rate * dt, rate * dt)
		return Pursuit.swim(p, info.goal, p.speed, dt, p.form.turn)
	end,
	onTell = function(p)
		Pursuit.fx("eye", p.position)
	end,
	strike = function(p, target)
		if p.frozen then
			return true -- caught looking: it cannot move to strike
		end
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at and flat(at - p.position).Magnitude < 30 then
			p.landed = true
			Pursuit.hit(target, p.position, {
				push = 40,
				lift = 22,
				spin = 1.5,
				hull = 4,
				damage = 6,
				reason = "watcher",
				cause = "a Watcher",
				text = "A WATCHER GRABBED YOUR BOAT! Turn and face it to freeze it.",
			})
			Pursuit.fx("stone", at)
		end
		return true
	end,
})

-- THE CINDERLINGS (Ember Isle): three of them on a raft of smoking lava rock, racing AHEAD of you (they always
-- did run to where a carrier was going) and leaving burning patches across your way.
forms.Ember = defaults({
	name = "The Cinderlings' Lava Raft",
	say = "THE CINDERLINGS ARE RACING AHEAD OF YOU ON A RAFT OF LAVA ROCK!",
	gone = "The lava raft hisses and sinks.",
	quit = "The lava raft fizzles out at the cove lights in a cloud of steam.",
	color = Color3.fromRGB(255, 120, 50),
	speed = 175,
	surge = 285,
	close = 55,
	reach = 0,
	follow = 40,
	lunge = 0,
	scale = 1.3, -- the cinderlings are minions; the raft grows a little
	body = {
		block("Rock", Vector3.new(9, 2, 11), nil, Color3.fromRGB(40, 34, 32), Enum.Material.Basalt),
		block("Glow", Vector3.new(7, 0.4, 9), CFrame.new(0, 1.1, 0), Color3.fromRGB(255, 110, 30), Enum.Material.Neon),
		ball("CinderA", 2.4, CFrame.new(-2.4, 2.4, -2), Color3.fromRGB(255, 140, 40), Enum.Material.Neon),
		ball("CinderB", 2.4, CFrame.new(2.4, 2.4, 0), Color3.fromRGB(255, 170, 60), Enum.Material.Neon),
		ball("CinderC", 2.4, CFrame.new(0, 2.4, 3), Color3.fromRGB(255, 120, 30), Enum.Material.Neon),
	},
	-- Where it heads: ahead of the thief, a little to one side.
	goal = function(p, info)
		p.side = p.side or (random:NextNumber() < 0.5 and 1 or -1)
		local v = info.velocity
		local way = v.Magnitude > 10 and v.Unit or flat(info.at - p.position).Unit
		return info.at + v * 1.8 + turned(way, math.rad(90)) * 30 * p.side
	end,
	always = function(p, _target, dt, _t, info)
		p.fireAt = (p.fireAt or 1.5) - dt
		if p.fireAt > 0 or (p.alt or 0) > 2 then
			return
		end
		p.fireAt = 1.5
		-- Only when it is ahead of the thief and near their line: a patch behind them is no use.
		local v = info.velocity
		local ahead = v.Magnitude > 10 and flat(p.position - info.at):Dot(v.Unit) or 0
		if ahead > 20 and info.gap < 260 and not Pursuit.inSanctuary(p.position, 40) then
			local at = Vector3.new(p.position.X, 0.5, p.position.Z)
			Creatures.mark(at, 15, 0.7, p.form.color)
			Pursuit.fx("erupt", at)
			local current = generation
			task.delay(0.7, function()
				if current == generation then
					Pursuit.zone("fire", at, 15, 6, p.form.color)
				end
			end)
			p.side = -(p.side or 1) -- weave across the line
		end
	end,
})

-- THE CHILL (Frost Spire): the cold itself drifts after you, a pale, glittering fog, and breathes on the sea
-- AHEAD of you: the water there sets. A boat that runs onto the ice is held for as long as it stays on it.
forms.Frost = defaults({
	-- V13.1 (the V13 playtest: "the aurora gem island and boss needs a rework and how it chases you after getting into
	-- water"): the Chill comes down off the mountain the moment the thief is in the water (from beside the island
	-- Chill), flies after them low over the waves, and ATTACKS: close up it locks on (the tell: an icy ring under the
	-- boat) and ICE SPIKES burst up through the sea (a hit). It still freezes the odd patch of sea ahead (rarer).
	-- V9 to V13 it only froze patches: it never touched anyone.
	name = "The Chill",
	say = "THE CHILL HAS COME DOWN TO THE SEA AFTER YOU!",
	gone = "The Chill thins away to nothing.",
	quit = "The Chill shivers at the cove lights and melts into mist.",
	color = Color3.fromRGB(190, 235, 255),
	speed = 185,
	surge = 320,
	turn = 3,
	reach = 26,
	tell = 0.9,
	rest = 2.6,
	follow = 70,
	ride = 8,
	clear = -math.huge, -- after you the moment you are in the water
	scale = Config.GUARDIAN_SCALE.Chill,
	body = {
		ball("Core", 10, nil, Color3.fromRGB(220, 245, 255), Enum.Material.Glass, 0.35),
		ball("PuffA", 8, CFrame.new(-5, -1, 2), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, 0.45),
		ball("PuffB", 8, CFrame.new(5, -1, 1), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, 0.45),
		ball("PuffC", 7, CFrame.new(0, 3, 4), Color3.fromRGB(235, 250, 255), Enum.Material.Glass, 0.5),
		ball("EyeL", 1.4, CFrame.new(-1.8, 1, -4.6), Color3.fromRGB(110, 200, 255), Enum.Material.Neon),
		ball("EyeR", 1.4, CFrame.new(1.8, 1, -4.6), Color3.fromRGB(110, 200, 255), Enum.Material.Neon),
		block(
			"Shard",
			Vector3.new(1, 6, 1),
			CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(15)),
			Color3.fromRGB(170, 230, 255),
			Enum.Material.Ice
		),
	},
	from = function(_island, target)
		return creatureNear("Chill", target, 700)
	end,
	onTell = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if at then
			Creatures.mark(Vector3.new(at.X, 0.5, at.Z), 20, p.form.tell, p.form.color)
		end
		Pursuit.fx("chill", p.position)
		Net.toast(target, "THE CHILL IS FREEZING THE SEA UNDER YOU! Boost or turn off the ring!")
	end,
	strike = function(p, target)
		local root, _, boat = Pursuit.vessel(target)
		local at = boat and boat.hull.Position or (root and root.Position)
		if not at then
			return true
		end
		-- Ice spikes burst up through the sea where the ring was (scenery for a moment).
		local folderNow = folder
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local spike = Instance.new("Part")
			spike.Name = "IceSpike"
			spike.Size = Vector3.new(2.4, 14, 2.4)
			spike.Color = Color3.fromRGB(190, 235, 255)
			spike.Material = Enum.Material.Ice
			spike.Transparency = 0.1
			spike.Anchored = true
			spike.CanCollide, spike.CanQuery, spike.CanTouch = false, false, false
			spike.CFrame = CFrame.new(at.X + math.cos(a) * 9, 3, at.Z + math.sin(a) * 9)
				* CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35)
			spike.Parent = folderNow
			game:GetService("Debris"):AddItem(spike, 1.4)
		end
		Pursuit.fx("chill", at)
		if flat(at - p.position).Magnitude < 34 then
			p.landed = true
			Pursuit.hit(target, at, {
				away = Vector3.new(0, 0, 0),
				push = 0,
				lift = 85,
				spin = 1.6,
				hull = 8,
				damage = 12,
				reason = "chill",
				cause = "the Chill",
				text = "ICE SPIKES! The Chill froze the sea under you.",
			})
		end
		return true
	end,
	-- And now and then a frozen patch ahead (a boat on one is held).
	always = function(p, target, dt, _t, info)
		p.fireAt = (p.fireAt or 4) - dt
		if p.fireAt > 0 or (p.alt or 0) > 2 or info.gap > 300 or p.state == "tell" then
			return
		end
		p.fireAt = 6.5
		local spot = Pursuit.lead(target, 2.2)
		if not spot or Pursuit.inSanctuary(spot, 40) then
			return
		end
		local at = Vector3.new(spot.X, 0.5, spot.Z)
		Creatures.mark(at, 24, 1.4, p.form.color)
		local current = generation
		task.delay(1.4, function()
			if current == generation then
				Pursuit.zone("ice", at, 24, 5, p.form.color)
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

local function chasing(player)
	local count = 0
	for _, p in ipairs(active) do
		if p.target == player and not p.done and p.state ~= "quit" then
			count += 1
		end
	end
	return count
end

local function setAttributes(p)
	if p.model then
		p.model:SetAttribute("Pursuer", p.form.name)
		p.model:SetAttribute("Chasing", p.target and p.target.UserId or nil)
	end
end

-- A form's own clean-up (the Guardian goes back to its temple), exactly once per pursuit.
local function formFinish(p)
	if p.form.finish and not p.finishCalled then
		p.finishCalled = true
		p.form.finish(p)
	end
end

local function finish(p, word)
	p.done = true
	if Creatures.seaOut[p.form.id] == p then
		Creatures.seaOut[p.form.id] = nil
	end
	formFinish(p)
	if p.model then
		p.model:Destroy()
		p.model = nil
	end
	readyAt[p.form.id] = now() + P.COOLDOWN
	if word ~= false and p.target and p.target.Parent then
		Net.toast(p.target, word or p.form.gone)
	end
end

-- V9: the end of a chase at the sanctuary: it stops at the edge, makes a show of it, and sinks away.
local function retire(p, text)
	if p.state == "quit" then
		return
	end
	p.state = "quit"
	p.quitAt = now()
	p.speed = 0
	formFinish(p)
	if p.target and p.target.Parent then
		Net.toast(p.target, text or p.form.quit or p.form.gone)
		Pursuit.Escaped:Fire(p.target, p.form.id) -- V13: got away to the sanctuary
	end
	Pursuit.fx("quit", p.position, { color = p.form.color })
end

local function addTrail(p, color)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-1.5, 0.5, 2)
	a0.Parent = p.root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(1.5, 0.5, 2)
	a1.Parent = p.root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.8
	trail.Lifetime = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = p.root
end

local function setOut(form, island, target)
	local root = Pursuit.vessel(target)
	if not root then
		return nil
	end
	local t = now()
	local p = {
		form = form,
		island = island,
		target = target,
		bornAt = t,
		state = "chase",
		stateUntil = 0,
		flinches = 0,
		draft = 1.5,
		speed = 0,
		alt = 0,
		vy = 0,
		nextLunge = t + random:NextNumber(2, 4),
	}
	-- Off the island's shore, on the side the thief left by.
	local center = Vector3.new(island.x, 0, island.z)
	local toward = flat(root.Position - center)
	toward = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, 1)
	local shore = center + toward * (island.r + 30)
	local water = SeaNav.nearestWater(shore.X, shore.Z, 2)
	p.position = water and Vector3.new(water.X, 0, water.Z) or shore
	p.heading = toward
	p.model, p.root = Pursuit.body(form.name, form.body, form.scale)
	if form.trail then
		addTrail(p, form.trail)
	end
	-- V13.1: a form may set out from where its island creature is (the jade frogs hop in off the beach, the Chill
	-- drifts down off the mountain), and the island creature knows its sea form is out (Creatures.seaOut).
	if form.from then
		local from = form.from(island, target)
		if from then
			p.position = Vector3.new(from.X, 0, from.Z)
		end
	end
	Creatures.seaOut[form.id] = p
	Pursuit.place(p, form.ride)
	Pursuit.fx("launch", p.position)
	setAttributes(p)
	table.insert(active, p)
	if form.setOut then
		form.setOut(p)
	else
		Net.send(target, "Message", { text = form.say, duration = 3.5, color = form.color })
	end
	Net.feed(form.name .. " is after " .. target.DisplayName .. "!", form.color)
	return p
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
			if target and island and chasing(target) < P.PER_TARGET and Pursuit.atSea(target) then
				local root = Pursuit.vessel(target)
				-- (Measured from the island's SHORE: the big islands are 450 studs across.)
				local off = Util.flatDistance(root.Position, Vector3.new(island.x, 0, island.z)) - island.r
				if off > (form.clear or P.CLEAR) and off < form.leash and not Pursuit.inSanctuary(root.Position) then
					setOut(form, island, target)
					if #active >= P.MAX then
						return
					end
				end
			end
		end
	end
end

-- V9: resurface behind the thief along their wake, out of their sight (a pursuer left hopelessly far behind,
-- or one land has blocked).
local function resurface(p, info)
	local back = info.velocity.Magnitude > 10 and -info.velocity.Unit or flat(p.position - info.at)
	back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
	local spot = info.at + back * P.CATCH_UP_TO
	local water = SeaNav.nearestWater(spot.X, spot.Z, 2)
	if not water then
		return false
	end
	local at = Vector3.new(water.X, 0, water.Z)
	if Pursuit.inSanctuary(at) or flat(at - info.at).Magnitude < P.CATCH_UP_TO * 0.6 then
		return false
	end
	p.position = at
	p.heading = -back
	p.speed = info.targetSpeed
	p.stuckFor = 0
	p.alt, p.vy, p.push = 0, 0, Vector3.zero
	Pursuit.fx("launch", at)
	return true
end

local function tickMover(p, dt, t)
	local form = p.form
	local target = p.target
	local root, _, boat = Pursuit.vessel(target)
	local part = boat and boat.hull or root
	if not part then
		return
	end
	local at = flat(part.Position)
	local velocity = flat(part.AssemblyLinearVelocity)
	-- V13: a Wraith's ghost: chase that instead, and no wind-up while fooled (it cannot strike a ghost).
	local decoy = Pursuit.decoyOf(target, p.position)
	local fooled = decoy ~= nil
	if fooled then
		at, velocity = decoy.at, decoy.velocity
		if p.state == "tell" then
			p.state = "chase"
		end
	end
	local targetSpeed = velocity.Magnitude
	local gap = flat(at - p.position).Magnitude - (boat and boat.spec.size.Z * 0.4 or 0)
	-- Pacing (see the header): surge, close, hang behind, lunge.
	local pace
	if gap > P.SURGE_GAP then
		pace = form.surge
	elseif p.lungeUntil and t < p.lungeUntil then
		pace = targetSpeed + form.lunge
	elseif gap > form.follow + 18 then
		pace = math.clamp(targetSpeed + form.close, form.speed * 0.55, form.surge)
	else
		pace = math.clamp(targetSpeed + (gap - form.follow) * 2.2, 0, form.surge)
	end
	if form.pace then
		pace *= form.pace(p, t)
	end
	if form.lunge > 0 and t >= p.nextLunge and gap < form.follow + 30 and p.state == "chase" then
		p.nextLunge = t + form.lungeEvery * random:NextNumber(0.75, 1.3)
		p.lungeUntil = t + form.lungeTime
	end
	local info = {
		at = at,
		velocity = velocity,
		targetSpeed = targetSpeed,
		gap = gap,
		pace = pace,
		boat = boat,
	}
	info.goal = form.goal and form.goal(p, info) or (at + velocity * 0.35)
	local airborne = Pursuit.air(p, dt, t)
	if form.always and p.state ~= "quit" and not fooled then
		form.always(p, target, dt, t, info)
	end
	if p.state == "board" then
		-- The Guardian is in the air on its way to its boat; the boat waits, engine idling.
		if t >= p.stateUntil then
			p.state = "chase"
			if form.boarded then
				form.boarded(p)
			end
		end
	elseif p.state == "flinch" or p.state == "rest" then
		-- Reeling from a blast, or winded after a strike: it wallows, losing speed.
		p.speed = math.max(0, p.speed - form.decel * 1.5 * dt)
		if p.speed > 1 then
			Pursuit.swim(p, info.goal, p.speed, dt, form.turn * 0.5)
		end
		if t >= p.stateUntil then
			p.state = "chase"
		end
	elseif p.state == "tell" then
		if form.telling then
			form.telling(p, target, dt)
		else
			-- While it winds up it locks onto the hull and matches its speed (aiming ahead with its momentum
			-- flew a quick one straight through the boat: measured 28 studs past it when the strike came).
			-- So the strike lands unless the thief does something about it: boosts, turns or jumps.
			-- (A long-reach form, Bramble, keeps pace and lines up instead: his charge is the strike.)
			if form.reach <= 40 then
				local press = targetSpeed + math.clamp((gap - 4) * 3, -60, 40)
				p.speed = math.clamp(press, 0, form.surge) -- no momentum through the tell: it is holding on
				Pursuit.swim(p, at, p.speed, dt, form.turn * 1.5)
			else
				p.speed = math.min(p.speed, targetSpeed)
				Pursuit.swim(p, at, p.speed, dt, form.turn)
			end
		end
		if t >= p.stateUntil then
			p.state = airborne and "rest" or "strike"
			p.stateUntil = t + 0.6
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
			p.lungeUntil = nil
		end
	else
		local moved
		if form.move then
			moved = form.move(p, target, dt, t, info)
		else
			local rate = pace > p.speed and form.accel or form.decel
			p.speed += math.clamp(pace - p.speed, -rate * dt, rate * dt)
			moved = Pursuit.swim(p, info.goal, p.speed, dt, form.turn)
		end
		-- Blocked by land for a while, or hopelessly far behind: it resurfaces behind the thief.
		if moved == false then
			p.stuckFor = (p.stuckFor or 0) + dt
		else
			p.stuckFor = 0
		end
		local behind = info.velocity.Magnitude < 10 or flat(p.position - at):Dot(info.velocity) < 0
		if (p.stuckFor > P.STUCK_TIME or (gap > P.FAR_GAP and behind)) and t - (p.resurfacedAt or -10) > 4 then
			if resurface(p, info) then
				p.resurfacedAt = t
			end
		end
		if
			form.reach > 0
			and gap <= form.reach
			and not airborne
			and not fooled
			and t >= p.bornAt + form.startDelay
			and not Pursuit.inSanctuary(at)
		then
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
	elseif (p.alt or 0) > 1 then
		extra = CFrame.Angles(math.rad(math.clamp(p.vy * 0.4, -35, 35)), 0, 0) -- nose up going up, down coming down
	end
	local ride = form.ride + (p.bob or 0) -- (V13.1: the jade frogs bound)
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
		local reason
		if p.state == "quit" then
			-- Sinking away at the sanctuary's edge.
			local k = (t - p.quitAt) / 1.6
			if k >= 1 then
				finish(p, false)
				table.remove(active, index)
			elseif p.root then
				Pursuit.place(p, form.ride - k * 14, CFrame.Angles(0, k * 3, math.sin(t * 16) * 0.2))
			end
			continue
		end
		-- V13.1: a thief who has been KNOCKED OUT (server/Knockout.lua) is down, not gone: their treasure lies loose
		-- beside them and the pursuer circles, in case they get up and grab it again, for KNOCKOUT.WAIT seconds.
		local knocked = target.Parent and target:GetAttribute("KnockedOutAt")
		local downLately = knocked and now() - knocked < Config.KNOCKOUT.WAIT
		if not root and downLately and target:GetAttribute("KnockedOutUntil") then
			p.speed = math.max(0, p.speed - form.decel * dt)
			Pursuit.air(p, dt, t)
			Pursuit.place(p, form.ride)
			continue
		end
		if not root then
			reason = false -- died, left, or between bodies
		else
			local holder = carrierOf(form.id)
			if not p.forced and holder ~= target then
				if holder and holder.Parent and Pursuit.atSea(holder) and chasing(holder) < P.PER_TARGET then
					-- Snatched by a rival at sea: it changes its quarry.
					p.target = holder
					target = holder
					setAttributes(p)
					Net.toast(holder, form.name .. " is after YOU now!")
					p.lostAt = nil
				else
					-- Banked, dropped or taken ashore: the island has no quarrel with anyone at sea now. (V13.1: just after
					-- a knockout it waits longer: the thief may get up and take it back.)
					p.lostAt = p.lostAt or t
					if t - p.lostAt > (downLately and Config.KNOCKOUT.WAIT or 3) then
						reason = form.gone
					end
				end
			elseif t - p.bornAt > form.time then
				reason = form.gone
			elseif Pursuit.inSanctuary(root.Position) then
				retire(p)
				continue
			elseif not Pursuit.atSea(target) then
				p.ashoreAt = p.ashoreAt or t
				if t - p.ashoreAt > 12 then
					reason = form.gone
				end
			else
				p.lostAt, p.ashoreAt = nil, nil
			end
		end
		if reason == nil and p.flinches >= 2 then
			reason = form.name .. " has had enough of explosions!"
		end
		if reason ~= nil then
			finish(p, reason)
			table.remove(active, index)
		elseif p.ashoreAt then
			-- Waiting offshore for them to come back to the water.
			p.speed = math.max(0, p.speed - form.decel * dt)
			Pursuit.air(p, dt, t)
			Pursuit.place(p, form.ride)
		else
			tickMover(p, dt, t)
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

-- Something went bang: a pursuer near it flinches (and after two, goes home).
local function onBlast(position, radius)
	local t = now()
	for _, p in ipairs(active) do
		if
			p.state ~= "flinch"
			and p.state ~= "quit"
			and p.state ~= "board"
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
	refs = worldRefs
	folder = worldRefs.folders.threats
	for id, form in pairs(forms) do
		form.id = id
	end
	table.clear(kickers)
	for _, gate in ipairs(worldRefs.boostGates or {}) do
		if gate.kind == "kick" then
			table.insert(kickers, { x = gate.position.X, z = gate.position.Z, r = gate.radius })
		end
	end
	Blast.Hit:Connect(onBlast)
end

function Pursuit.reset()
	generation += 1
	for _, p in ipairs(active) do
		formFinish(p)
		if p.model then
			p.model:Destroy()
		end
	end
	table.clear(active)
	table.clear(readyAt)
	table.clear(decoys)
	for _, zone in ipairs(zones) do
		zone.part:Destroy()
	end
	table.clear(zones)
end

-- A goblin left: anything chasing them goes.
function Pursuit.forget(player)
	decoys[player] = nil
	for index = #active, 1, -1 do
		local p = active[index]
		if p.target == player then
			finish(p, false)
			table.remove(active, index)
		end
	end
end

-- For tests and the report: what is out, and the roster.
function Pursuit.active()
	return active
end

function Pursuit.forms()
	return forms
end

-- For tests: a short summary of each pursuer.
function Pursuit.inspect()
	local out = {}
	for _, p in ipairs(active) do
		local root, _, boat = Pursuit.vessel(p.target)
		local part = boat and boat.hull or root
		table.insert(out, {
			name = p.form.name,
			island = p.form.id,
			state = p.state,
			speed = math.floor(p.speed or 0),
			alt = math.floor(p.alt or 0),
			gap = part and math.floor(flat(part.Position - p.position).Magnitude) or -1,
			target = p.target and p.target.Name,
			age = math.floor(now() - p.bornAt),
		})
	end
	return out
end

-- For tests: send an island's pursuer after a goblin now, whatever they are carrying and wherever
-- they are. `from` (optional) is where it starts instead of its island's shore.
function Pursuit.force(islandId, target, from)
	local form, island = forms[islandId], Archipelago.byId[islandId]
	if not form or not island then
		return nil
	end
	local p = setOut(form, island, target)
	if not p then
		return nil
	end
	p.forced = true
	if from then
		p.position = Vector3.new(from.X, 0, from.Z)
	end
	return p
end

return Pursuit

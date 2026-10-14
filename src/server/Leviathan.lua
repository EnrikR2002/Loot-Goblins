-- The Leviathan: the thing the Sleeper's eye belongs to.
--
-- V7 gave it a body: seven humps circling off the east dock of Leviathan's Rest and a head that came
-- down on a marked circle when the Sleeper struck. It never left its circle. V8 makes it the sea's one
-- real monster: more than twice the size, and it HUNTS.
--   LURK   as before: the ridge of its back swims a slow circle and rises with the Sleeper's awareness.
--   HUNT   it leaves the circle and swims after a boat, faster than a cruising skiff (L.SPEED against
--          135) and slower than a boost, in wide turns it cannot tighten (L.TURN); when the boat gets
--          well ahead it SURGES (L.SURGE_SPEED) until it is close again. A long ridge of humps follows
--          the head. Two things happen to boats near it:
--            the WAKE    passing close throws a bow wave: boats beside the head are shoved aside. No
--                        damage, a lot of motion.
--            the BREACH  when it is close behind, the ridge sinks, a wide ring opens on the water where
--                        the boat is GOING to be, and L.BREACH_DELAY seconds later the head comes straight
--                        up through it, jaws open. A boat on the ring is thrown into the air and battered
--                        (never sunk: Boats.hitAt's floor). A boat that boosted, turned or jumped out of
--                        the ring is missed entirely. Then it needs L.RECOVER seconds to come round.
--          It picks the nearest crewed boat again after every breach, so two crews can pass it between
--          them, and a second boat is never safe to sit and watch from.
--   What ends a hunt: L.HUNT_TIME seconds; the boat getting L.LEASH from its home, or into water too
--          shallow for it (L.SHALLOW: run for any beach); three explosions on its head (a keg, a
--          cannonball: it flinches for L.FLINCH each time and gives up on the third); nobody left to
--          chase. It then sinks and goes home.
-- How to start one (all three are in the game description):
--   1. make NOISE: drive a boat faster than the Sleeper's `quiet` speed inside its range for about two
--      seconds (its awareness reaches 1), or
--   2. steal the Leviathan Tooth and put to sea with it (the Kraken trouble calls Leviathan.huntThief).
-- It has no health bar and cannot be killed.
--
-- The head is the server's (its position decides every hit); the body is plain anchored parts moved
-- from here each frame while a goblin is near enough for the Sleeper to be awake, or a hunt is on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local SeaNav = require(script.Parent.SeaNav)
local Blast = require(script.Parent.Blast)
local Pursuit = require(script.Parent.Pursuit)

local Leviathan = {}

local L = Config.LEVIATHAN
local DEEP = Color3.fromRGB(46, 86, 96)
local BELLY = Color3.fromRGB(150, 205, 190)
local PURPLE = Color3.fromRGB(150, 90, 220)

local folder
local center -- the middle of its circle
local humps = {}
local neck = {}
local head
local jawTop, jawBottom, eyes
local phase = 0
local striking = false -- the head is out of the water (a breach): it can be hit
local headAt = nil
local generation = 0
local hunt = nil -- the hunt in progress
local pendingThief = nil -- a goblin who took the Tooth and has not put to sea yet
local pendingUntil = 0
local updated = false -- has update run this frame? (the Sleeper sleeps when nobody is near; a hunt must not)

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function part(name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Slate
	p.Shape = shape or Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(0, -400, 0)
	p.Parent = folder
	return p
end

function Leviathan.build(threatsFolder, home)
	folder = threatsFolder
	center = home
	local s = L.SCALE
	for i = 1, L.HUMPS do
		humps[i] = part("LeviathanHump", Vector3.new(1, 1, 1) * (13 - i * 0.7) * s, DEEP)
	end
	for i = 1, L.NECK do
		neck[i] = part("LeviathanNeck", Vector3.new(1, 1, 1) * (11 - i * 0.3) * s, DEEP)
	end
	head = part("LeviathanHead", Vector3.new(22, 14, 26) * s, DEEP)
	jawTop = part("LeviathanJawTop", Vector3.new(15, 4, 18) * s, BELLY, Enum.PartType.Block)
	jawBottom = part("LeviathanJawBottom", Vector3.new(13, 3, 16) * s, BELLY, Enum.PartType.Block)
	eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		local eye = part("LeviathanEye", Vector3.new(4, 4, 4) * s, Color3.fromRGB(255, 190, 70))
		eye.Material = Enum.Material.Neon
		eyes[side] = eye
	end
end

local AWAY = CFrame.new(0, -400, 0)

local function hideNeck()
	for _, p in ipairs(neck) do
		p.CFrame = AWAY
	end
end

local function hide()
	for _, p in ipairs(humps) do
		p.CFrame = AWAY
	end
	hideNeck()
	head.CFrame = AWAY
	jawTop.CFrame = AWAY
	jawBottom.CFrame = AWAY
	for _, eye in pairs(eyes) do
		eye.CFrame = AWAY
	end
	headAt = nil
end

local function placeHead(cf, open)
	local s = L.SCALE
	head.CFrame = cf
	jawTop.CFrame = cf * CFrame.new(0, (3 + open * 3) * s, -15 * s) * CFrame.Angles(math.rad(-6 - open * 14), 0, 0)
	jawBottom.CFrame = cf * CFrame.new(0, (-5 - open * 3) * s, -12 * s) * CFrame.Angles(math.rad(8 + open * 16), 0, 0)
	for side, eye in pairs(eyes) do
		eye.CFrame = cf * CFrame.new(side * 7 * s, 4 * s, -9 * s)
	end
	headAt = cf.Position
end

-- Lurking: the ridge on its circle. awareness is 0 to 1.
local function lurk(dt, awareness)
	phase += dt * L.SWIM_SPEED / L.RADIUS
	local rise = L.LURK_MIN + (1 - L.LURK_MIN) * awareness
	for i, p in ipairs(humps) do
		local angle = phase - (i - 1) * L.GAP
		local x, z = center.X + math.cos(angle) * L.RADIUS, center.Z + math.sin(angle) * L.RADIUS
		local wave = math.max(0, math.sin(phase * 3 - i * 1.1))
		local size = p.Size.X
		p.CFrame = CFrame.new(x, -size * 0.55 + size * 0.9 * wave * rise, z)
	end
	-- The head follows the first hump, just under the surface.
	local angle = phase + 0.2
	local x, z = center.X + math.cos(angle) * L.RADIUS, center.Z + math.sin(angle) * L.RADIUS
	local tangent = CFrame.lookAt(
		Vector3.new(x, -20 + 12 * awareness, z),
		Vector3.new(center.X + math.cos(angle + 0.1) * L.RADIUS, -20, center.Z + math.sin(angle + 0.1) * L.RADIUS)
	)
	hideNeck()
	placeHead(tangent, awareness * 0.4)
	headAt = nil
end

-- Hunting ------------------------------------------------------------------------------------------
-- The nearest crewed boat to a point (not a patrol ship), within `range`.
local function nearestBoat(position, range)
	local best, bestDistance, bestPlayer = nil, range, nil
	for _, player in ipairs(Players:GetPlayers()) do
		local root, _, boat = Pursuit.vessel(player)
		if root and boat and boat.state == "float" and not boat.ai then
			local distance = flat(boat.hull.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance, bestPlayer = boat, distance, player
			end
		end
	end
	return best, bestDistance, bestPlayer
end

local function endHunt(why)
	local h = hunt
	if not h then
		return
	end
	hunt = nil
	striking = false
	generation += 1
	if why then
		Net.feed(why, PURPLE)
	end
	-- back to its circle: the lurk picks the body up from there
	phase = math.atan2(h.position.Z - center.Z, h.position.X - center.X)
	hide()
end

-- Start a hunt after this goblin's boat. Returns true if it set out.
function Leviathan.hunt(player)
	if hunt or not head then
		return false
	end
	local root, _, boat = Pursuit.vessel(player)
	if not root or not boat then
		return false
	end
	local start = Vector3.new(center.X + math.cos(phase) * L.RADIUS, 0, center.Z + math.sin(phase) * L.RADIUS)
	local toward = flat(boat.hull.Position - start)
	hunt = {
		target = player,
		boat = boat,
		position = start,
		heading = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, 1),
		trail = {},
		state = "swim",
		untilAt = 0,
		bornAt = now(),
		flinches = 0,
		nextWake = 0,
		nextBreach = now() + 2.5,
		shallowSince = nil,
	}
	Net.message("THE LEVIATHAN IS AWAKE. IT IS COMING.", 4, PURPLE)
	Net.send(player, "Toast", { text = "RUN! Boost, turn hard, or make for shallow water. Jump when the ring opens." })
	Pursuit.fx("erupt", start)
	return true
end

function Leviathan.hunting()
	return hunt ~= nil
end

-- The Tooth has been taken: hunt the thief as soon as they are on the water (for a while).
function Leviathan.huntThief(player)
	pendingThief = player
	pendingUntil = now() + L.THIEF_WINDOW
end

-- The head comes straight up through `at`, `delay` seconds from now.
local function breach(h, at, delay)
	local g = generation
	h.state = "dive"
	h.untilAt = now() + delay + L.BREACH_SHOW + 0.4
	h.breachAt = at
	h.ownBlastAt = now() + delay -- its own splash is not an explosion it flinches from
	Blast.strike(Vector3.new(at.X, 0.5, at.Z), delay, {
		radius = L.BREACH_RADIUS,
		damage = L.BREACH_DAMAGE,
		knockback = 90,
		hullDamage = L.BREACH_HULL,
		boatPush = L.BREACH_PUSH,
		lootReason = "leviathan",
		cause = "the Leviathan",
		markerColor = PURPLE,
		style = "kraken",
		color = PURPLE,
	})
	Net.broadcastNear(at, 1600, "Tentacle", { position = Vector3.new(at.X, 0, at.Z), delay = delay })
	task.spawn(function()
		local started = os.clock()
		-- under, while the ring closes
		while os.clock() - started < delay - 0.25 do
			RunService.Heartbeat:Wait()
			if g ~= generation then
				return
			end
		end
		-- up: the head on a column of neck
		striking = true
		local size = head.Size.Y
		local rise = L.BREACH_HEIGHT
		local up0 = os.clock()
		local show = L.BREACH_SHOW
		while os.clock() - up0 < show do
			RunService.Heartbeat:Wait()
			if g ~= generation then
				return
			end
			local k = (os.clock() - up0) / show
			-- out fast, hang, fall back
			local height = k < 0.25 and (k / 0.25) or (k < 0.6 and 1 or (1 - (k - 0.6) / 0.4))
			local y = -size + height * rise
			local facing = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X, y + 10, at.Z + 0.01))
				* CFrame.Angles(0, 0, k * 1.2)
			placeHead(facing, k < 0.6 and 1 or 0.2)
			for i, p in ipairs(neck) do
				p.CFrame = CFrame.new(at.X, y - i * size * 0.55, at.Z)
			end
		end
		striking = false
		headAt = nil
		hideNeck()
		if hunt == h then
			h.position = Vector3.new(at.X, 0, at.Z)
			h.state = "recover"
			h.untilAt = now() + L.RECOVER
			table.clear(h.trail)
		end
	end)
end

local function huntTick(dt, t)
	local h = hunt
	-- Who it is after: the nearest crewed boat, re-chosen whenever it is free to choose.
	if h.state == "swim" and t >= (h.nextPick or 0) then
		h.nextPick = t + 1.5
		local boat, _, player = nearestBoat(h.position, L.SIGHT)
		if boat and boat ~= h.boat then
			h.boat, h.target = boat, player
			Net.send(player, "Toast", { text = "THE LEVIATHAN HAS TURNED ON YOU!" })
		end
	end
	local boat = h.boat
	local alive = boat and boat.state == "float" and Boats.occupied(boat)
	if not alive then
		local other, _, player = nearestBoat(h.position, L.SIGHT)
		if other then
			h.boat, h.target, boat = other, player, other
		elseif h.state == "swim" or h.state == "recover" then
			endHunt("The Leviathan sinks back into the deep.")
			return
		end
	end
	local hullAt = (boat and boat.hull.Parent) and flat(boat.hull.Position) or h.position
	if h.state == "swim" then
		-- Reasons to stop.
		local reason
		if t - h.bornAt > L.HUNT_TIME then
			reason = "The Leviathan tires of the chase and sinks away."
		elseif flat(hullAt - Vector3.new(center.X, 0, center.Z)).Magnitude > L.LEASH then
			reason = "The Leviathan turns back: too far from its deep."
		elseif h.flinches >= 3 then
			reason = "The Leviathan has had enough: it dives and is gone!"
		elseif SeaNav.depthAt(hullAt.X, hullAt.Z) < L.SHALLOW then
			h.shallowSince = h.shallowSince or t
			if t - h.shallowSince > 3 then
				reason = "The Leviathan cannot follow into the shallows."
			end
		else
			h.shallowSince = nil
		end
		if reason then
			endHunt(reason)
			return
		end
		-- Swim: wide turns, steering round land.
		local mover = h
		mover.draft = 6
		local lead = hullAt + flat(boat.hull.AssemblyLinearVelocity) * 0.6
		local pace = flat(hullAt - h.position).Magnitude > L.SURGE_GAP and L.SURGE_SPEED or L.SPEED
		if not Pursuit.swim(mover, lead, pace, dt, L.TURN) then
			h.stuck = (h.stuck or 0) + dt
			if h.stuck > 4 then
				endHunt("The Leviathan loses you among the rocks.")
				return
			end
		else
			h.stuck = 0
		end
		local gap = flat(hullAt - h.position).Magnitude
		-- The wake: boats beside the head are thrown aside.
		if t >= h.nextWake then
			for _, other in ipairs(Boats.list) do
				if other.state == "float" and not other.ai then
					local offset = flat(other.hull.Position - h.position)
					if offset.Magnitude < L.WAKE_RADIUS and offset.Magnitude > 1 then
						h.nextWake = t + 2.2
						Boats.shove(other, offset.Unit * L.WAKE_PUSH + Vector3.new(0, 26, 0), Vector3.new(0, 1.2, 0))
						Pursuit.fx("crash", other.hull.Position)
					end
				end
			end
		end
		-- The breach: close behind, and rested.
		if gap < L.BREACH_RANGE and t >= h.nextBreach then
			h.nextBreach = t + L.BREACH_GAP
			local at = hullAt + flat(boat.hull.AssemblyLinearVelocity) * L.BREACH_DELAY * 0.92
			breach(h, at, L.BREACH_DELAY)
		end
	elseif h.state == "flinch" then
		if t >= h.untilAt then
			h.state = "swim"
		end
	elseif h.state == "recover" then
		if t >= h.untilAt then
			h.state = "swim"
			h.nextPick = 0
			local away = flat(hullAt - h.position)
			if away.Magnitude > 1 then
				h.heading = away.Unit
			end
		end
	end
	-- The body.
	if h.state == "dive" then
		-- under, except for what the breach itself is drawing
		for _, p in ipairs(humps) do
			p.CFrame = p.CFrame:Lerp(CFrame.new(p.Position.X, -p.Size.X * 1.6, p.Position.Z), math.min(1, dt * 5))
		end
		if not striking then
			placeHead(CFrame.new(h.position.X, -80, h.position.Z), 0)
			headAt = nil
		end
		return
	end
	local trail = h.trail
	local last = trail[#trail]
	if not last or flat(h.position - last).Magnitude > 7 then
		table.insert(trail, h.position)
		if #trail > 90 then
			table.remove(trail, 1)
		end
	end
	local low = h.state == "recover" or h.state == "flinch"
	local wave = Sea.waveAt(h.position.X, h.position.Z, t)
	local s = L.SCALE
	local headY = wave + (low and -9 or 3) * s + math.sin(t * 2.4) * 2
	placeHead(
		CFrame.lookAt(
			Vector3.new(h.position.X, headY, h.position.Z),
			Vector3.new(h.position.X + h.heading.X, headY, h.position.Z + h.heading.Z)
		) * (h.state == "flinch" and CFrame.Angles(0, 0, math.sin(t * 18) * 0.25) or CFrame.new()),
		low and 0.1 or 0.55
	)
	if low then
		headAt = nil
	end
	hideNeck()
	for i, p in ipairs(humps) do
		local at = trail[#trail - i * 4] or trail[1] or h.position
		local size = p.Size.X
		local bob = math.max(0, math.sin(t * 4 - i * 0.9))
		p.CFrame = CFrame.new(at.X, -size * 0.5 + size * (low and 0.25 or 0.8) * bob, at.Z)
	end
end

-- Each tick from the Sleeper. awareness is 0 to 1.
function Leviathan.update(dt, awareness)
	if not head then
		return
	end
	updated = true
	local t = now()
	if pendingThief and not hunt then
		if t > pendingUntil or not pendingThief.Parent then
			pendingThief = nil
		elseif Pursuit.atSea(pendingThief) then
			local _, _, boat = Pursuit.vessel(pendingThief)
			if boat and Leviathan.hunt(pendingThief) then
				pendingThief = nil
			end
		end
	end
	if hunt then
		huntTick(dt, t)
	else
		lurk(dt, awareness)
	end
end

-- Called every frame by Main: keeps a hunt (or a thief it is waiting for) going when the Sleeper,
-- which normally drives this, has gone back to sleep because nobody is near its eye.
function Leviathan.tick(dt)
	if (hunt or pendingThief) and not updated then
		Leviathan.update(dt, 0)
	end
	updated = false
end

-- Where the head is, if it is up and can be hit.
function Leviathan.headPosition()
	if hunt and (striking or hunt.state == "swim") then
		return headAt or hunt.position
	end
	return nil
end

-- An explosion on its head: it flinches, and after three it gives up.
function Leviathan.recoil()
	local h = hunt
	if not h or h.state == "flinch" or math.abs(now() - (h.ownBlastAt or -10)) < 0.2 then
		return
	end
	h.flinches += 1
	Net.feed("The Leviathan recoils from the blast! (" .. h.flinches .. " of 3)", Color3.fromRGB(255, 200, 110))
	if h.state == "swim" then
		h.state = "flinch"
		h.untilAt = now() + L.FLINCH
		h.nextBreach = math.max(h.nextBreach, now() + L.FLINCH + 2)
	end
end

function Leviathan.reset()
	generation += 1
	striking = false
	hunt = nil
	pendingThief = nil
	if head then
		hide()
	end
end

-- For tests.
function Leviathan.inspect()
	local h = hunt
	if not h then
		return nil
	end
	return { state = h.state, position = h.position, target = h.target, flinches = h.flinches, age = now() - h.bornAt }
end

return Leviathan

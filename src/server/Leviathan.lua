-- The Leviathan: the thing the Sleeper's eye belongs to.
--
-- V7 gave it a body; V8 made it hunt boats and BREACH (a marked ring, then the head up through it). The V8
-- playtest found the breach the least of it: the funniest thing was the monster right behind a fleeing boat,
-- breathing down its neck. V9 removes the breach as an attack entirely. What is left is the chase:
--   LURK   as before: the ridge of its back swims a slow circle and rises with the Sleeper's awareness.
--   HUNT   it leaves the circle and swims after a boat. It SHADOWS it: its snout L.FOLLOW studs behind the
--          stern, matching the boat's speed, all the way to the sanctuary round Goblin Cove. It has momentum
--          (L.ACCEL up, L.DECEL down: a monster does not brake like a skiff), so:
--            a boat that KEEPS ITS SPEED is never touched. Every L.LUNGE_GAP seconds it roars and lunges, jaws
--                     open, and the lunge stops short of a boat holding its speed (a near miss, every time).
--            a boat that LOSES SPEED (a rock, a missed hoop, a rival, a bad landing, a brake) is RUN INTO: a
--                     catch. It bumps the boat on, throws it aside, or lifts its bow and tosses it, and then
--                     drops back to its following distance. A catch is a world hit (Impact: grace, the grip
--                     rule, a hull never sunk), and the same boat cannot be caught again for L.CONTACT_REST.
--          Far behind, it surges (L.SURGE_SPEED, faster than anything). Boats beside its head are shoved aside
--          by its bow wave. It still breaches now and then for the look of it, well away from any boat: a
--          splash, never a hit.
--   What ends a hunt: the boat reaching the sanctuary (it stops at the lights, roars, and sinks away); the boat
--          staying in water too shallow for it (L.SHALLOW) for L.SHALLOW_GIVE_UP; three explosions on its head;
--          nobody left to chase; L.HUNT_TIME as a backstop.
-- How to start one (both in the game description):
--   1. make NOISE: drive a boat faster than the Sleeper's `quiet` speed inside its range for about two
--      seconds (its awareness reaches 1), or
--   2. steal the Leviathan Tooth and put to sea with it (the Kraken trouble calls Leviathan.huntThief).
-- It has no health bar and cannot be killed.
--
-- The snout is the server's (its position decides every catch); the body is plain anchored parts moved
-- from here each frame while a goblin is near enough for the Sleeper to be awake, or a hunt is on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local SeaNav = require(script.Parent.SeaNav)
local Pursuit = require(script.Parent.Pursuit)

local Leviathan = {}

local L = Config.LEVIATHAN
local DEEP = Color3.fromRGB(38, 82, 98)
local DEEP_DARK = Color3.fromRGB(24, 52, 66)
local BELLY = Color3.fromRGB(150, 205, 190)
local FIN = Color3.fromRGB(64, 186, 170)
local HORN = Color3.fromRGB(236, 226, 196)
local MOUTH = Color3.fromRGB(96, 26, 40)
local PURPLE = Color3.fromRGB(150, 90, 220)

local folder
local center -- the middle of its circle
local humps = {}
local neck = {}
local head
local jawTop, jawBottom, eyes
local headParts = {} -- V10: { part, offset (scaled), on = "head" | "top" | "bottom" }
local fins = {} -- hump index -> its dorsal fin
local flukes = {}
local wakes = {}
local phase = 0
local headAt = nil
local generation = 0
local hunt = nil -- the hunt in progress
local pendingThief = nil -- a goblin who took the Tooth and has not put to sea yet
local pendingUntil = 0
local updated = false -- has update run this frame? (the Sleeper sleeps when nobody is near; a hunt must not)
local random = Random.new()

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

-- V10: an ellipsoid (a block with a sphere mesh): skull, snout, body segments. Organic shapes, no assets.
local function shell(name, size, color)
	local p = part(name, size, color, Enum.PartType.Block)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- V10: one creature, not a string of balls. A broad skull and a long snout (both ellipsoids), heavy brows,
-- swept-back bone horns, a pair of frills, glowing amber eyes with black slit pupils in deep sockets, a dark
-- mouth with teeth in both jaws, and a body of overlapping segments (each lying along the path) that rises
-- and falls as one travelling wave, with dorsal fins and a tail fluke. Foam breaks round its head when it
-- runs at the surface. About fifty plain parts, all moved with one BulkMoveTo a frame.
function Leviathan.build(threatsFolder, home)
	folder = threatsFolder
	center = home
	local s = L.SCALE
	for i = 1, L.HUMPS do
		local d = (13 - i * 0.6) * s
		humps[i] = shell("LeviathanHump", Vector3.new(d, d * 0.8, d * 1.6), DEEP)
		if i % 2 == 0 and i < L.HUMPS then
			local fin = part("LeviathanFin", Vector3.new(0.9, d * 0.62, d * 0.95), FIN, Enum.PartType.Block)
			fin.Shape = Enum.PartType.Block
			fins[i] = fin
		end
	end
	local tailD = (13 - L.HUMPS * 0.6) * s
	for _, side in ipairs({ -1, 1 }) do
		flukes[side] = part("LeviathanFluke", Vector3.new(tailD * 1.3, 1.2 * s, tailD * 0.7), FIN, Enum.PartType.Block)
	end
	for i = 1, L.NECK do
		neck[i] = part("LeviathanNeck", Vector3.new(1, 1, 1) * (11 - i * 0.3) * s, DEEP)
	end
	head = shell("LeviathanHead", Vector3.new(24, 15, 28) * s, DEEP)
	jawTop = shell("LeviathanJawTop", Vector3.new(16, 7, 21) * s, DEEP)
	jawBottom = shell("LeviathanJawBottom", Vector3.new(13, 4.4, 17) * s, BELLY)
	eyes = {}
	local function attach(name, size, color, offset, on, material, shape)
		local p
		if shape == "shell" then
			p = shell(name, size * s, color)
		else
			p = part(name, size * s, color, shape or Enum.PartType.Block)
		end
		p.Material = material or Enum.Material.Slate
		table.insert(
			headParts,
			{ part = p, offset = CFrame.new(offset.Position * s) * offset.Rotation, on = on or "head" }
		)
		return p
	end
	for _, side in ipairs({ -1, 1 }) do
		attach(
			"LeviathanBrow",
			Vector3.new(7, 3, 13),
			DEEP_DARK,
			CFrame.new(side * 6.4, 6.4, -6) * CFrame.Angles(-0.15, side * 0.12, side * 0.3)
		)
		attach(
			"LeviathanHorn",
			Vector3.new(3, 3, 11),
			HORN,
			CFrame.new(side * 7.2, 8, 5) * CFrame.Angles(0.55, side * 0.28, 0)
		)
		attach(
			"LeviathanHorn",
			Vector3.new(1.8, 1.8, 8),
			HORN,
			CFrame.new(side * 9.2, 12.2, 12) * CFrame.Angles(0.95, side * 0.34, 0)
		)
		attach(
			"LeviathanFrill",
			Vector3.new(0.8, 9, 13),
			FIN,
			CFrame.new(side * 12.4, 1.5, 4) * CFrame.Angles(0, side * 0.35, side * 0.35)
		)
		attach(
			"LeviathanSocket",
			Vector3.new(6, 5, 6),
			DEEP_DARK,
			CFrame.new(side * 8.4, 3.6, -8.6),
			"head",
			nil,
			"shell"
		)
		attach(
			"LeviathanPupil",
			Vector3.new(0.7, 3.6, 1.2),
			Color3.fromRGB(10, 10, 12),
			CFrame.new(side * 12, 3.9, -10.3),
			"head",
			Enum.Material.SmoothPlastic
		)
		local eye = part("LeviathanEye", Vector3.new(4.6, 4.6, 4.6) * s, Color3.fromRGB(255, 190, 70))
		eye.Material = Enum.Material.Neon
		eyes[side] = eye
	end
	attach("LeviathanCrest", Vector3.new(1.2, 6, 10), FIN, CFrame.new(0, 8.6, 3) * CFrame.Angles(-0.2, 0, 0))
	attach(
		"LeviathanMouth",
		Vector3.new(11, 5, 15),
		MOUTH,
		CFrame.new(0, -2.6, -13),
		"head",
		Enum.Material.SmoothPlastic
	)
	for i, x in ipairs({ -5.2, -2, 2, 5.2 }) do
		local z = (i == 2 or i == 3) and -8 or -5
		attach(
			"LeviathanTooth",
			Vector3.new(1.5, 3.2, 1.5),
			HORN,
			CFrame.new(x, -3.2, z) * CFrame.Angles(math.pi, 0, 0),
			"top",
			Enum.Material.SmoothPlastic,
			Enum.PartType.Wedge
		)
		attach(
			"LeviathanTooth",
			Vector3.new(1.2, 2.4, 1.2),
			HORN,
			CFrame.new(x * 0.85, 2.2, z + 1),
			"bottom",
			Enum.Material.SmoothPlastic,
			Enum.PartType.Wedge
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		local foam = shell("LeviathanWake", Vector3.new(12, 1.2, 30) * s, Color3.fromRGB(240, 250, 255))
		foam.Material = Enum.Material.SmoothPlastic
		foam.Transparency = 0.3
		wakes[side] = foam
	end
	head:SetAttribute("Pursuer", "The Leviathan")
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
	for _, list in ipairs({ fins, flukes, wakes }) do
		for _, p in pairs(list) do
			p.CFrame = AWAY
		end
	end
	for _, entry in ipairs(headParts) do
		entry.part.CFrame = AWAY
	end
	hideNeck()
	head.CFrame = AWAY
	jawTop.CFrame = AWAY
	jawBottom.CFrame = AWAY
	for _, eye in pairs(eyes) do
		eye.CFrame = AWAY
	end
	headAt = nil
	head:SetAttribute("Chasing", nil)
end

local function placeHead(cf, open, foam)
	local s = L.SCALE
	local top = cf * CFrame.new(0, (2.5 + open * 3) * s, -15 * s) * CFrame.Angles(math.rad(-6 - open * 14), 0, 0)
	local bottom = cf * CFrame.new(0, (-5 - open * 3) * s, -12 * s) * CFrame.Angles(math.rad(8 + open * 16), 0, 0)
	local parts, cframes = { head, jawTop, jawBottom }, { cf, top, bottom }
	for side, eye in pairs(eyes) do
		table.insert(parts, eye)
		table.insert(cframes, cf * CFrame.new(side * 9.6 * s, 3.8 * s, -9.6 * s))
	end
	for _, entry in ipairs(headParts) do
		local basis = entry.on == "top" and top or (entry.on == "bottom" and bottom or cf)
		table.insert(parts, entry.part)
		table.insert(cframes, basis * entry.offset)
	end
	-- Foam either side of the head while it runs at the surface: you see it coming before you see it.
	for side, wake in pairs(wakes) do
		table.insert(parts, wake)
		if foam then
			local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
			local right = Vector3.new(-look.Z, 0, look.X)
			local at = cf.Position + right * side * 11 * s + look * 2 * s
			table.insert(
				cframes,
				CFrame.lookAt(Vector3.new(at.X, foam, at.Z), Vector3.new(at.X, foam, at.Z) + look)
					* CFrame.Angles(0, side * 0.25, 0)
			)
		else
			table.insert(cframes, AWAY)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	headAt = cf.Position
end

-- The body along `points` (flat positions, nearest the head first): every segment lies along the path and
-- rides one wave that travels down its length, so it reads as one animal arching through the sea. `sink`
-- (0 to 1) pulls it under (lurking unaware, or flinching).
local function placeBody(points, headFlat, t, sink)
	local parts, cframes = {}, {}
	local count = #humps
	for i, p in ipairs(humps) do
		local at = points[i]
		local ahead = points[i - 1] or headFlat
		local d = p.Size.X
		local phaseAt = t * 2.2 - i * 0.75
		local wave = math.sin(phaseAt)
		local y = d * (-0.36 + 0.42 * wave) - sink * d * 0.5
		local dir = Vector3.new(ahead.X - at.X, 0, ahead.Z - at.Z)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
		local spot = Vector3.new(at.X, y, at.Z)
		local cf = CFrame.lookAt(spot, spot + dir) * CFrame.Angles(math.cos(phaseAt) * 0.28, 0, 0)
		table.insert(parts, p)
		table.insert(cframes, cf)
		local fin = fins[i]
		if fin then
			table.insert(parts, fin)
			table.insert(cframes, cf * CFrame.new(0, d * 0.42, d * 0.1))
		end
		if i == count then
			for side, fluke in pairs(flukes) do
				table.insert(parts, fluke)
				table.insert(
					cframes,
					cf * CFrame.new(side * d * 0.55, d * 0.05, d * 0.95) * CFrame.Angles(0, side * 0.55, side * 0.12)
				)
			end
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- The snout runs at h.position; the head's middle sits this far behind it (so the jaws reach the snout).
local function headBack()
	return 22 * L.SCALE
end

-- Lurking: the ridge on its circle. awareness is 0 to 1.
local function lurk(dt, awareness)
	phase += dt * L.SWIM_SPEED / L.RADIUS
	local rise = L.LURK_MIN + (1 - L.LURK_MIN) * awareness
	local points = {}
	for i = 1, #humps do
		local angle = phase - (i - 1) * L.GAP
		points[i] = Vector3.new(center.X + math.cos(angle) * L.RADIUS, 0, center.Z + math.sin(angle) * L.RADIUS)
	end
	local headAngle = phase + 0.2
	local headFlat =
		Vector3.new(center.X + math.cos(headAngle) * L.RADIUS, 0, center.Z + math.sin(headAngle) * L.RADIUS)
	placeBody(points, headFlat, now(), 1 - rise)
	-- The head follows the first hump, just under the surface.
	local angle = phase + 0.2
	local x, z = center.X + math.cos(angle) * L.RADIUS, center.Z + math.sin(angle) * L.RADIUS
	local tangent = CFrame.lookAt(
		Vector3.new(x, -22 + 12 * awareness, z),
		Vector3.new(center.X + math.cos(angle + 0.1) * L.RADIUS, -22, center.Z + math.sin(angle + 0.1) * L.RADIUS)
	)
	hideNeck()
	placeHead(tangent, awareness * 0.4)
	headAt = nil
end

-- Hunting ------------------------------------------------------------------------------------------
-- The nearest crewed boat to a point (not a patrol ship, not in the sanctuary), within `range`.
local function nearestBoat(position, range)
	local best, bestDistance, bestPlayer = nil, range, nil
	for _, player in ipairs(Players:GetPlayers()) do
		local root, _, boat = Pursuit.vessel(player)
		if root and boat and boat.state == "float" and not boat.ai and not Pursuit.inSanctuary(boat.hull.Position) then
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
	if not root or not boat or Pursuit.inSanctuary(boat.hull.Position) then
		return false
	end
	local start = Vector3.new(center.X + math.cos(phase) * L.RADIUS, 0, center.Z + math.sin(phase) * L.RADIUS)
	local toward = flat(boat.hull.Position - start)
	local t = now()
	hunt = {
		target = player,
		boat = boat,
		position = start,
		heading = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, 1),
		speed = 40,
		trail = {},
		state = "swim",
		untilAt = 0,
		bornAt = t,
		flinches = 0,
		nextWake = 0,
		nextLunge = t + 4,
		contactReadyAt = t + 2.5,
		nextShow = t + 9,
		nextSpout = t + 3,
		switchedAt = t,
		avgSpeed = flat(boat.hull.AssemblyLinearVelocity).Magnitude,
		draft = 6,
		keepOut = true,
	}
	head:SetAttribute("Chasing", player.UserId)
	Net.message("THE LEVIATHAN IS AWAKE. IT IS COMING.", 4, PURPLE)
	Net.send(player, "Toast", { text = "RUN! Keep your speed up: it catches whatever slows down." })
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

-- A catch: it has run into the boat. How it throws the boat depends on how slow the boat was.
local function contact(h, boat, player, t)
	h.contactReadyAt = t + L.CONTACT_REST
	local hullV = flat(boat.hull.AssemblyLinearVelocity)
	local speed = hullV.Magnitude
	local opts = {
		hull = L.CONTACT_HULL,
		damage = L.CONTACT_DAMAGE,
		reason = "leviathan",
		cause = "the Leviathan",
	}
	local roll = random:NextNumber()
	if speed < 60 then
		-- Stopped dead in front of it: up goes the bow, and the boat is tossed over its head.
		opts.away = h.heading
		opts.push = 55
		opts.lift = 95
		opts.spin = 2.2
		opts.text = "THE LEVIATHAN TOSSED YOU! (It catches whatever slows down.)"
	elseif roll < 0.5 then
		-- A bump from behind: shoved on, nose up.
		opts.away = h.heading
		opts.push = 70
		opts.lift = 42
		opts.spin = 0.8
		opts.text = "BUMPED BY THE LEVIATHAN! Speed up!"
	else
		-- A swipe of the head: thrown sideways.
		local side = random:NextNumber() < 0.5 and 1 or -1
		opts.away = Vector3.new(-h.heading.Z, 0, h.heading.X) * side
		opts.push = 82
		opts.lift = 30
		opts.spin = 3 * side
		opts.text = "THE LEVIATHAN SWIPED YOU ASIDE!"
	end
	local landed = Pursuit.hit(player, h.position, opts)
	Pursuit.fx("crash", boat.hull.Position)
	Pursuit.fx("roar", h.position)
	-- It recoils from the bite and drops back to following distance.
	h.speed = math.max(L.MIN_SPEED, speed * 0.55)
	h.openUntil = t + 0.6
	return landed
end

local function huntTick(dt, t)
	local h = hunt
	local boat = h.boat
	local alive = boat and boat.state == "float" and Boats.occupied(boat) and h.target.Parent
	if not alive then
		local other, _, player = nearestBoat(h.position, L.SIGHT)
		if other then
			h.boat, h.target, boat = other, player, other
			h.switchedAt = t
			head:SetAttribute("Chasing", player.UserId)
			Net.send(player, "Toast", { text = "THE LEVIATHAN HAS TURNED ON YOU!" })
		else
			endHunt("The Leviathan sinks back into the deep.")
			return
		end
	end
	-- Another boat much nearer than its quarry? It may switch, but not every moment.
	if h.state == "swim" and t - h.switchedAt > L.SWITCH_GAP then
		local other, distance, player = nearestBoat(h.position, L.SIGHT)
		local current = flat(boat.hull.Position - h.position).Magnitude
		if other and other ~= boat and distance < current * L.SWITCH_RATIO then
			h.boat, h.target, boat = other, player, other
			h.switchedAt = t
			head:SetAttribute("Chasing", player.UserId)
			Net.send(player, "Toast", { text = "THE LEVIATHAN HAS TURNED ON YOU!" })
		end
	end
	local hull = boat.hull
	local hullAt = flat(hull.Position)
	local hullV = flat(hull.AssemblyLinearVelocity)
	local boatSpeed = hullV.Magnitude
	h.avgSpeed += (boatSpeed - h.avgSpeed) * math.min(1, dt * 1.2)
	-- Reasons to stop.
	local reason
	if Pursuit.inSanctuary(hull.Position) then
		Pursuit.fx("roar", h.position)
		Net.send(h.target, "Toast", { text = "The Leviathan stops at the cove lights, roars... and sinks away." })
		reason = "The Leviathan turns back at the lights of Goblin Cove."
	elseif t - h.bornAt > L.HUNT_TIME then
		reason = "The Leviathan tires of the chase and sinks away."
	elseif h.flinches >= 3 then
		reason = "The Leviathan has had enough: it dives and is gone!"
	elseif SeaNav.depthAt(hullAt.X, hullAt.Z) < L.SHALLOW then
		h.shallowSince = h.shallowSince or t
		if t - h.shallowSince > L.SHALLOW_GIVE_UP then
			reason = "The Leviathan cannot follow into the shallows."
		end
	else
		h.shallowSince = nil
	end
	if reason then
		endHunt(reason)
		return
	end
	if h.state == "flinch" then
		h.speed = math.max(0, h.speed - L.DECEL * 2 * dt)
		if t >= h.untilAt then
			h.state = "swim"
		end
	end
	-- Where the stern is, and how far its snout is from it.
	local look = flat(hull.CFrame.LookVector)
	look = look.Magnitude > 0.05 and look.Unit or (boatSpeed > 5 and hullV.Unit or h.heading)
	local halfLength = boat.spec.size.Z * 0.5
	local stern = hullAt - look * halfLength
	local gap = flat(hullAt - h.position).Magnitude - halfLength
	-- Did the boat lose speed? Then nothing holds the monster back.
	local slowing = boatSpeed < 80 or boatSpeed < h.avgSpeed * 0.78
	-- Pacing.
	local want
	if h.state ~= "swim" then
		want = 0
	elseif t < h.contactReadyAt and gap < L.FOLLOW then
		want = boatSpeed * 0.8 -- just bit: dropping back
	elseif gap > L.SURGE_GAP then
		want = L.SURGE_SPEED
	elseif h.lungeUntil and t < h.lungeUntil then
		want = boatSpeed + L.LUNGE_SPEED
	elseif gap > L.FOLLOW + 15 then
		want = boatSpeed + L.CLOSE_RATE
	else
		want = boatSpeed + (gap - L.FOLLOW) * 2
	end
	local resting = t < h.contactReadyAt
	if h.state == "swim" and not resting then
		want = math.max(want, L.MIN_SPEED)
	end
	local rate = want > h.speed and L.ACCEL or L.DECEL
	h.speed += math.clamp(want - h.speed, -rate * dt, rate * dt)
	-- A boat that keeps its speed is never caught: however it got there, the snout does not close past
	-- CONTACT + 8 on one. (A boat that slows gets no such mercy: the momentum carries it in.)
	if not slowing and gap < L.CONTACT + 8 then
		h.speed = math.min(h.speed, boatSpeed)
	end
	-- The lunge: a roar and open jaws, a near miss on a boat that holds its speed.
	if h.state == "swim" and t >= h.nextLunge and gap < L.FOLLOW + 30 and t >= h.contactReadyAt then
		h.nextLunge = t + L.LUNGE_GAP * random:NextNumber(0.8, 1.25)
		h.lungeUntil = t + L.LUNGE_TIME
		h.openUntil = t + L.LUNGE_TIME + 0.3
		Pursuit.fx("roar", h.position)
		Net.send(h.target, "Toast", { text = "THE LEVIATHAN LUNGES! Don't slow down!" })
	end
	-- Swim: wide turns, steering round land, never into the sanctuary or the shallows.
	if h.speed > 1 then
		local goal = stern - look * 8 + hullV * 0.25
		if resting then
			-- Just bit: it swerves off alongside rather than swimming through the boat, then falls in behind.
			h.side = h.side or (random:NextNumber() < 0.5 and 1 or -1)
			goal = hullAt + Vector3.new(-look.Z, 0, look.X) * 80 * h.side - look * 40
		else
			h.side = nil
		end
		if not Pursuit.swim(h, goal, h.speed, dt, L.TURN) then
			h.stuck = (h.stuck or 0) + dt
			h.speed = math.max(L.MIN_SPEED * 0.5, h.speed - L.DECEL * dt)
		else
			h.stuck = 0
		end
		-- Hopelessly far behind, or stuck behind land: it dives, and surfaces again behind them.
		if (gap > 1100 or (h.stuck or 0) > 4) and t - (h.resurfacedAt or -10) > 6 then
			local back = boatSpeed > 10 and -hullV.Unit or flat(h.position - hullAt).Unit
			local spot = hullAt + back * 420
			local water = SeaNav.nearestWater(spot.X, spot.Z, 6)
			if water and not Pursuit.inSanctuary(water) then
				h.resurfacedAt = t
				h.position = Vector3.new(water.X, 0, water.Z)
				h.heading = -back
				h.speed = boatSpeed
				h.stuck = 0
				table.clear(h.trail)
				Pursuit.fx("erupt", h.position)
			end
		end
	end
	-- The catch.
	if h.state == "swim" and t >= h.contactReadyAt and gap < L.CONTACT then
		contact(h, boat, h.target, t)
	end
	-- The wake: other boats beside the head are thrown aside.
	if t >= h.nextWake then
		for _, other in ipairs(Boats.list) do
			if other ~= boat and other.state == "float" and not other.ai then
				local offset = flat(other.hull.Position - h.position)
				if offset.Magnitude < L.WAKE_RADIUS and offset.Magnitude > 1 then
					h.nextWake = t + 2.2
					Boats.shove(other, offset.Unit * L.WAKE_PUSH + Vector3.new(0, 26, 0), Vector3.new(0, 1.2, 0))
					Pursuit.fx("crash", other.hull.Position)
				end
			end
		end
	end
	-- Breathing: a spout from its blowhole now and then.
	if t >= h.nextSpout then
		h.nextSpout = t + random:NextNumber(4, 7)
		Pursuit.fx("spout", h.position - h.heading * headBack() * 2.2)
	end
	-- For the look of it: well clear of any boat, it surges up out of the water and crashes down. No ring,
	-- no hit: a splash.
	if t >= h.nextShow and gap > 140 and h.state == "swim" then
		h.nextShow = t + random:NextNumber(10, 16)
		h.showUntil = t + 1.4
		h.showAt = t
	end
	if h.showAt and h.showUntil and t >= h.showUntil and not h.showSplashed then
		h.showSplashed = true
		Pursuit.fx("erupt", h.position)
	elseif h.showUntil and t < h.showUntil then
		h.showSplashed = false
	end

	-- The body.
	local trail = h.trail
	local last = trail[#trail]
	if not last or flat(h.position - last).Magnitude > 8 then
		table.insert(trail, h.position)
		if #trail > 110 then
			table.remove(trail, 1)
		end
	end
	local low = h.state == "flinch"
	local s = L.SCALE
	local wave = Sea.waveAt(h.position.X, h.position.Z, t)
	local rise = 0
	if h.showUntil and t < h.showUntil then
		local k = (t - h.showAt) / (h.showUntil - h.showAt)
		rise = math.sin(k * math.pi) * 34 * s
	end
	local headY = wave + (low and -9 or 3) * s + math.sin(t * 2.4) * 2 + rise
	local open = (h.openUntil and t < h.openUntil) and 1 or 0.35
	local headCenter = h.position - h.heading * headBack()
	placeHead(
		CFrame.lookAt(
			Vector3.new(headCenter.X, headY, headCenter.Z),
			Vector3.new(headCenter.X + h.heading.X, headY + rise * 0.02, headCenter.Z + h.heading.Z)
		)
			* CFrame.Angles(rise > 0 and math.rad(25) or 0, 0, 0)
			* (h.state == "flinch" and CFrame.Angles(0, 0, math.sin(t * 18) * 0.25) or CFrame.new()),
		low and 0.1 or open,
		(not low and rise < 1) and (wave + 0.5) or nil
	)
	if low then
		headAt = nil
	end
	hideNeck()
	local points = {}
	for i = 1, #humps do
		local at = trail[#trail - i * 4] or trail[1] or h.position
		points[i] = at - h.heading * headBack()
	end
	placeBody(points, headCenter, t, low and 0.7 or 0)
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
		huntTick(math.min(dt, 0.1), t)
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
	if hunt and hunt.state == "swim" then
		return headAt or hunt.position
	end
	return nil
end

-- An explosion on its head: it flinches, and after three it gives up.
function Leviathan.recoil()
	local h = hunt
	if not h or h.state == "flinch" then
		return
	end
	h.flinches += 1
	Net.feed("The Leviathan recoils from the blast! (" .. h.flinches .. " of 3)", Color3.fromRGB(255, 200, 110))
	h.state = "flinch"
	h.untilAt = now() + L.FLINCH
	h.contactReadyAt = math.max(h.contactReadyAt, now() + L.FLINCH + 1)
end

function Leviathan.reset()
	generation += 1
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
	local gap
	if h.boat and h.boat.hull.Parent then
		gap = flat(h.boat.hull.Position - h.position).Magnitude - h.boat.spec.size.Z * 0.5
	end
	return {
		state = h.state,
		position = h.position,
		target = h.target,
		flinches = h.flinches,
		age = now() - h.bornAt,
		speed = h.speed,
		gap = gap,
		contactReadyAt = h.contactReadyAt,
	}
end

return Leviathan

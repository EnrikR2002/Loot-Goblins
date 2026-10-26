-- CANNON GOLF (V13.3; V13.5: six holes of water-skipping golf, in strokes): fire yourself off the Port's south-west
-- jetty at six targets out on the sea. The tee cannons are real launchers (server/Flight.lua) marked `skim`, so the
-- throw, the tumble, the glide (Space), the dive (Shift) and the head-first landings are all the game's own, and the
-- sea skips you like a stone (Config.DIVE.SKIM): a SHALLOW arrival bounces on, lower and flatter each time; a steep one
-- plops. The client says only a direction (its height is the elevation: look up to lob, down to skim) and a power; the
-- server turns them into the throw (PortGames.golfVelocity).
--
--   THE HOLES   (shared/PortGames.lua: PortGames.GOLF.holes) the Puddle Jump (a lob), the Skipping Stone (too far to
--               fly), the Bend (stacks in the way: skim wide and curve), the Lily Pad (small and close), Over the Top
--               (lob the ridge or skip round it) and the Kraken's Crown (an islet in a reef: through the gap, then a
--               glide to stop on it).
--   SCORING     Flight.Landed says where a goblin came down for good and whether on something solid. On the hole's
--               target: in its cup is that stroke (an ace on the first), elsewhere on it one putt more. In the sea it
--               costs the stroke and you are back in the cannon at once. After par + 1 shots without holing out the
--               caddy picks your ball up (par + PICKUP). The round is the strokes of all six (par 16): fewest wins.
--   PLAYERS     three tees side by side: three goblins can play at once (each round is its own; a challenge takes two).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Net = require(script.Parent.Net)
local Flight = require(script.Parent.Flight)
local Minigames = require(script.Parent.Minigames)

local GF = Config.PLAYGROUND.GOLF
local golf = PortGames.GOLF
local rgb = Color3.fromRGB
local v3 = Vector3.new

local CannonGolf = {
	id = "golf",
	concurrent = true,
	limit = GF.TEES,
	max = 2,
	duration = GF.LIMIT,
}

local tees = {} -- { launcher, user (player or nil), barrel }

local function now()
	return workspace:GetServerTimeNow()
end

local function freeTees()
	local n = 0
	for _, tee in ipairs(tees) do
		if not tee.user or not tee.user.Parent then
			tee.user = nil
			n += 1
		end
	end
	return n
end

function CannonGolf.canJoin(_player)
	if freeTees() < 1 then
		return false, "All three tees are busy: try again in a moment."
	end
	return true
end

-- Building ------------------------------------------------------------------------------------------------------------------
local function disc(kit, name, center, radius, thick, color, material, opts)
	opts = opts or {}
	opts.cyl = true
	local fn = opts.solid and kit.part or kit.deco
	opts.solid = nil
	return fn(
		name,
		v3(thick, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		opts
	)
end

local function flag(kit, center, index, hole)
	kit.deco("Pin", v3(0.3, 12, 0.3), CFrame.new(center + v3(0, 6, 0)), rgb(246, 244, 238), Enum.Material.SmoothPlastic)
	local cloth = kit.deco(
		"PinFlag",
		v3(0.15, 2.4, 3.4),
		CFrame.new(center + v3(0, 10.8, 1.7)),
		rgb(230, 50, 46),
		Enum.Material.Fabric
	)
	kit.light(cloth, rgb(255, 120, 100), 18, 0.8)
	kit.board(
		"HoleSign",
		v3(14, 3.4, 0.3),
		CFrame.lookAt(center + v3(0, 16, 0), center + v3(0, 16, 0) - golf.facing),
		string.format("%d · %s · PAR %d", index, hole.name, hole.par),
		Palette.GOLD
	)
end

-- The target a hole is played to, and the cup and flag on it.
local function target(kit, hole, index)
	local c = hole.center
	if hole.kind == "isle" then
		-- A sand islet: a skirt of sand to the water, a crown of grass on top.
		disc(
			kit,
			"IsleSand",
			c - v3(0, 2.6, 0),
			hole.radius + 7,
			5,
			rgb(232, 210, 160),
			Enum.Material.Sand,
			{ solid = true }
		)
		disc(
			kit,
			"IsleTop",
			c - v3(0, 0.3, 0),
			hole.radius,
			0.8,
			rgb(110, 200, 90),
			Enum.Material.Grass,
			{ solid = true }
		)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			kit.deco(
				"CrownSpike",
				v3(2, 6, 2),
				CFrame.new(c + v3(math.cos(a) * (hole.radius + 3), 1.5, math.sin(a) * (hole.radius + 3))),
				Palette.GOLD,
				Enum.Material.Metal,
				{ wedge = true }
			)
		end
	elseif hole.kind == "pad" then
		disc(kit, "Pad", c - v3(0, 0.6, 0), hole.radius, 1.2, rgb(90, 170, 80), Enum.Material.Grass, { solid = true })
		-- Lily pads round it: pretty, and not the target.
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + 0.4
			disc(
				kit,
				"LilyPad",
				c + v3(math.cos(a) * 17, -1.2, math.sin(a) * 17),
				4 + (k % 3),
				0.4,
				rgb(70, 150, 70),
				Enum.Material.Grass
			)
		end
	else
		disc(
			kit,
			"Green",
			c - v3(0, 0.6, 0),
			hole.radius,
			1.2,
			rgb(110, 200, 90),
			Enum.Material.Grass,
			{ solid = true }
		)
		disc(
			kit,
			"Raft",
			c - v3(0, 1.6, 0),
			hole.radius + 1,
			1.6,
			Palette.WOOD,
			Enum.Material.WoodPlanks,
			{ solid = true }
		)
	end
	disc(
		kit,
		"Cup",
		c + v3(0, 0.05, 0),
		hole.cup,
		0.2,
		rgb(246, 244, 238),
		Enum.Material.SmoothPlastic,
		{ shadow = false }
	)
	disc(kit, "Hole", c + v3(0, 0.1, 0), 0.8, 0.25, rgb(20, 18, 22), Enum.Material.SmoothPlastic, { shadow = false })
	flag(kit, c, index, hole)
end

local function obstacles(kit, hole)
	for _, stack in ipairs(hole.rocks or {}) do
		kit.part(
			"SeaStack",
			v3(stack.radius * 2, stack.height + 10, stack.radius * 2),
			CFrame.new(stack.at + v3(0, stack.height / 2 - 5, 0)),
			Palette.ROCK or rgb(120, 112, 118),
			Enum.Material.Slate
		)
		kit.deco(
			"StackCap",
			v3(stack.radius * 1.4, 3, stack.radius * 1.4),
			CFrame.new(stack.at + v3(0, stack.height, 0)),
			rgb(236, 230, 214),
			Enum.Material.Slate
		)
	end
	local ridge = hole.ridge
	if ridge then
		local d = v3(ridge.to.X - ridge.from.X, 0, ridge.to.Z - ridge.from.Z)
		local mid = (ridge.from + ridge.to) / 2
		kit.part(
			"Ridge",
			v3(ridge.thick, ridge.height + 10, d.Magnitude),
			CFrame.lookAt(v3(mid.X, ridge.height / 2 - 5, mid.Z), v3(mid.X, ridge.height / 2 - 5, mid.Z) + d),
			Palette.ROCK or rgb(120, 112, 118),
			Enum.Material.Slate
		)
		kit.deco(
			"RidgeGrass",
			v3(ridge.thick * 0.8, 2, d.Magnitude * 0.9),
			CFrame.lookAt(v3(mid.X, ridge.height, mid.Z), v3(mid.X, ridge.height, mid.Z) + d),
			rgb(110, 170, 80),
			Enum.Material.Grass
		)
	end
	local reef = hole.reef
	if reef then
		-- A ring of low rocks round the islet, open towards the tee: a gap `gap` studs wide.
		local toward = v3(golf.jettyEnd.X - reef.center.X, 0, golf.jettyEnd.Z - reef.center.Z).Unit
		local count = 22
		for k = 0, count - 1 do
			local a = k / count * math.pi * 2
			local dir = v3(math.cos(a), 0, math.sin(a))
			local p = reef.center + dir * reef.radius
			local sideways = (p - (reef.center + toward * reef.radius))
			if v3(sideways.X, 0, sideways.Z).Magnitude > reef.gap then
				kit.part(
					"ReefRock",
					v3(14, reef.height + 6, 10),
					CFrame.lookAt(
						v3(p.X, reef.height / 2 - 3, p.Z),
						v3(reef.center.X, reef.height / 2 - 3, reef.center.Z)
					),
					rgb(96, 88, 100),
					Enum.Material.Slate
				)
			end
		end
	end
end

local function tee(kit, entry, index)
	local base = entry.cframe
	kit.part("TeeStand", v3(5, 2.2, 5), base * CFrame.new(0, -1.1, 0), Palette.WOOD_DARK, Enum.Material.Wood)
	local barrel = kit.deco(
		"TeeCannon",
		v3(6, 2.6, 2.6),
		base * CFrame.new(0, 1.4, 0) * CFrame.Angles(math.rad(42), 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		rgb(56, 52, 62),
		Enum.Material.Metal,
		{ cyl = true }
	)
	for _, side in ipairs({ -1, 1 }) do
		kit.deco(
			"TeeWheel",
			v3(0.6, 3, 3),
			base * CFrame.new(side * 1.8, 0.4, 0.6),
			Palette.WOOD,
			Enum.Material.Wood,
			{ cyl = true }
		)
	end
	kit.board(
		"TeeNumber",
		v3(3, 2, 0.3),
		base * CFrame.new(0, 0.4, 2.7) * CFrame.Angles(0, math.rad(180), 0),
		"TEE " .. index,
		Palette.GOLD
	)
	-- The launcher's prompt is never pressed (the game loads goblins itself), but Flight wants one.
	local holder = kit.deco(
		"TeePromptHolder",
		v3(1, 1, 1),
		base * CFrame.new(0, 2, 0),
		rgb(255, 255, 255),
		Enum.Material.SmoothPlastic,
		{ transparency = 1 }
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeePrompt"
	prompt.ObjectText = "Cannon Golf"
	prompt.ActionText = "Play at the jetty's sign"
	prompt.MaxActivationDistance = 0 -- never shown: the game loads goblins itself
	prompt.Enabled = false
	prompt.Parent = holder
	local record = { barrel = barrel, base = base }
	local launcher = Flight.addLauncher({
		kind = "golf",
		port = true, -- the raid's resets leave it alone (Flight.reset)
		skim = true, -- V13.5: the sea skips a golf shot like a stone (Config.DIVE.SKIM)
		from = entry.from,
		speed = GF.MAX_SPEED,
		elevation = GF.ELEVATION,
		rest = golf.holes[1].center,
		prompt = prompt,
		exit = (base * CFrame.new(0, 3, 4)).Position,
		back = "landed",
		timeout = 40,
		timeoutText = "The caddy tips you out of the cannon: that shot counts. (Hold, then let go, to fire.)",
		aim = function(direction)
			local flat = v3(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.05 then
				local from = base.Position + v3(0, 1.4, 0)
				local pitch =
					math.clamp(math.asin(math.clamp(direction.Unit.Y, -1, 1)), GF.ELEVATION_MIN, GF.ELEVATION_MAX)
				barrel.CFrame = CFrame.lookAt(from, from + flat.Unit)
					* CFrame.Angles(pitch, 0, 0)
					* CFrame.Angles(0, math.rad(90), 0)
			end
		end,
		fired = function(_direction) end,
		ready = function(player)
			if record.user == player then
				return true
			end
			return false, nil
		end,
		-- The ordinary "fire where you aim" is not golf: only the power shot (CannonGolf.input) throws.
		canFire = function()
			return false, nil
		end,
	})
	record.launcher = launcher
	prompt.Enabled = false
	tees[index] = record
end

function CannonGolf.build(kit)
	-- The jetty out over the water, its sign, and the three tees at its end.
	local root, finish = golf.jettyRoot, golf.jettyEnd
	local mid = (root + finish) / 2
	kit.floor(
		"GolfJetty",
		v3(30, 1.4, (finish - root).Magnitude + 8),
		CFrame.lookAt(v3(mid.X, 5.3, mid.Z), v3(finish.X, 5.3, finish.Z)),
		Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	kit.board(
		"GolfSign",
		v3(16, 4, 0.5),
		CFrame.lookAt(PortGames.VENUES.golf.sign, PortGames.VENUES.golf.sign + golf.facing),
		"CANNON GOLF",
		rgb(150, 240, 130)
	)
	for i, entry in ipairs(golf.tees) do
		tee(kit, entry, i)
	end
	for i, hole in ipairs(golf.holes) do
		target(kit, hole, i)
		obstacles(kit, hole)
	end
end

-- Running ---------------------------------------------------------------------------------------------------------------------
local function teeOf(player)
	for _, record in ipairs(tees) do
		if record.user == player then
			return record
		end
	end
	return nil
end

local function holeOf(entry)
	return golf.holes[entry.data.hole]
end

local function showOf(entry)
	local hole = holeOf(entry)
	return {
		hole = entry.data.hole,
		of = #golf.holes,
		par = hole and hole.par or 0,
		shot = entry.data.shots + 1,
		max = hole and hole.par + 1 or 0,
		card = entry.data.card,
		total = entry.data.total,
		played = entry.data.parPlayed, -- the par of the holes finished (for "+2 after 3")
	}
end

local function load(entry)
	local record = entry.data.tee
	local hole = holeOf(entry)
	if not record or not hole then
		return
	end
	Minigames.place(entry.player, CFrame.new(record.base.Position + v3(0, 4, 2)), false)
	task.defer(function()
		if entry.player.Parent and not entry.left and not entry.done then
			Flight.load(entry.player, record.launcher, hole.center)
			entry.data.loadedAt = now()
			entry.data.state = "aiming"
			Net.send(entry.player, "PlayFx", {
				kind = "golfhole",
				game = "golf",
				hole = entry.data.hole,
				shot = entry.data.shots + 1,
			})
		end
	end)
end

function CannonGolf.prepare(session)
	for _, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry then
			for _, record in ipairs(tees) do
				if not record.user then
					record.user = player
					entry.data.tee = record
					break
				end
			end
			entry.data.hole = 1
			entry.data.shots = 0
			entry.data.card = {}
			entry.data.total = 0
			entry.data.parPlayed = 0
			entry.data.greens = 0
			entry.data.bestSkips = 0
			entry.show = showOf(entry)
			if entry.data.tee then
				load(entry)
			else
				Minigames.leave(player, "full")
			end
		end
	end
end

function CannonGolf.go(session, t)
	session.endsAt = t + GF.LIMIT
end

-- The hole is over with `strokes`: on to the next, or the round is done.
local function holeDone(session, entry, strokes)
	local hole = holeOf(entry)
	table.insert(entry.data.card, strokes)
	entry.data.total += strokes
	entry.data.parPlayed += hole.par
	if entry.data.hole >= #golf.holes then
		entry.data.state = "done"
		entry.show = showOf(entry)
		Minigames.done(session, entry.player, entry.data.total, entry.show)
		return false
	end
	entry.data.hole += 1
	entry.data.shots = 0
	entry.show = showOf(entry)
	session.dirty = true
	return true
end

-- A shot came down (or never went: `position` nil). Judges it, says so, and moves the round on after a moment.
local function shotOver(session, entry, position, water, bounces)
	local hole = holeOf(entry)
	entry.data.shots += 1
	entry.data.bestSkips = math.max(entry.data.bestSkips, bounces or 0)
	local grade, distance = PortGames.golfJudge(hole, position, water)
	local strokes = PortGames.golfStrokes(hole, entry.data.shots, grade)
	if grade ~= "miss" then
		entry.data.greens += 1
	end
	local fx = {
		kind = "golfland",
		position = position,
		userId = entry.player.UserId,
		grade = strokes and grade == "miss" and "pickup" or grade,
		distance = distance and math.floor(distance * 10 + 0.5) / 10 or nil,
		skips = bounces or 0,
		shot = entry.data.shots,
		strokes = strokes,
		par = hole.par,
		hole = entry.data.hole,
	}
	if position then
		Net.broadcastNear(position, 600, "PlayFx", fx)
	end
	if not position or not entry.player.Parent then
		Net.send(entry.player, "PlayFx", fx)
	end
	if strokes then
		holeDone(session, entry, strokes)
	else
		entry.show = showOf(entry)
	end
	session.dirty = true
	if entry.data.state == "done" then
		return
	end
	entry.data.state = "landed"
	local token = entry.data.hole * 100 + entry.data.shots
	task.delay(GF.RETURN, function()
		if
			session.state == "running"
			and not entry.left
			and not entry.done
			and entry.data.state == "landed"
			and entry.data.hole * 100 + entry.data.shots == token
		then
			load(entry)
		end
	end)
end

Flight.Landed:Connect(function(player, position, launcher, info)
	if not launcher or launcher.kind ~= "golf" then
		return
	end
	local entry, session = Minigames.entryOf(player)
	if not entry or not session or session.game ~= "golf" or entry.data.state ~= "flying" then
		return
	end
	shotOver(session, entry, position, info == nil or info.water, info and info.bounces or 0)
end)

-- The client's shot: a direction (its height is the elevation) and a power (0..1). The barrel turns as it aims.
function CannonGolf.input(session, player, action, a, b)
	local entry = session.entries[player]
	if not entry or entry.data.state ~= "aiming" then
		return
	end
	local record = entry.data.tee
	if action == "golfaim" and typeof(a) == "Vector3" and a == a and record then
		record.launcher.aim(a)
	elseif action == "golf" and record and Flight.phaseOf(player) == "loaded" then
		local velocity = PortGames.golfVelocity(a, b)
		entry.data.state = "flying"
		entry.data.firedAt = now()
		if not Flight.launch(player, velocity, record.launcher) then
			entry.data.state = "aiming"
		end
	end
end

function CannonGolf.tick(session, _dt, t)
	for player, entry in pairs(session.entries) do
		if not entry.done and not entry.left and Flight.phaseOf(player) == nil then
			-- Tipped out of the cannon (sat too long: that shot counts, as a miss), or a flight that ended without a
			-- landing (Landed fires first in every ordinary one: this is the safety net).
			local tipped = entry.data.state == "aiming" and t - (entry.data.loadedAt or t) > 1.5
			local lost = entry.data.state == "flying" and t - (entry.data.firedAt or t) > 2
			if tipped or lost then
				shotOver(session, entry, nil, true, 0)
			end
		end
	end
end

local function freeTee(player)
	local record = teeOf(player)
	if record then
		record.user = nil
	end
	local phase = Flight.phaseOf(player)
	if phase == "loaded" or phase == "fuse" then
		Flight.leave(player)
	end
end

function CannonGolf.drop(_session, player)
	freeTee(player)
end

function CannonGolf.stop(session)
	for player in pairs(session.entries) do
		freeTee(player)
	end
end

function CannonGolf.spot(_session, _player)
	local spot = golf.jettyRoot + v3(0, 3.5, 0)
	return CFrame.lookAt(spot, spot + golf.facing)
end

function CannonGolf.public(_session)
	return { holes = #golf.holes, par = golf.par }
end

return CannonGolf

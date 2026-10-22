-- CANNON GOLF (V13.3): fire yourself at three floating greens off the Port's south-west jetty, one shot each, and score
-- by how close to the pin you come to rest. The tee cannons are real launchers (server/Flight.lua), so the throw, the
-- tumble, the glide (Space), the dive (Shift), the skips across the water and the head-first landings are all the
-- game's own: only the aim is different. Instead of looking at where you want to land, you AIM THE WAY YOU LOOK and
-- HOLD to charge the power (client/PlayHud.lua draws the meter); the server turns (direction, power) into the throw
-- (PortGames.golfVelocity: a fixed elevation, the speed between MIN_SPEED and MAX_SPEED), so a client can ask for a
-- direction and a power, never a velocity.
--
--   SCORING     Flight.Landed says where a goblin came down for good (after any skips): the flat distance to the
--               pin is points (PortGames.golfPoints): in the cup 100, so close 70, the green 45, the fringe 20,
--               a splash 0. Three holes, 300 at most. A goblin who sits in the cannon too long has that hole skipped.
--   PLAYERS     three tees side by side: three goblins can play at once (each run is its own; a challenge takes two).
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
local function green(kit, g, index)
	local c = g.center
	local disc = kit.part(
		"Green",
		v3(1.2, g.radius * 2, g.radius * 2),
		CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(110, 200, 90),
		Enum.Material.Grass
	)
	disc.Shape = Enum.PartType.Cylinder
	local fringe = kit.deco(
		"Fringe",
		v3(1, GF.FRINGE * 2, GF.FRINGE * 2),
		CFrame.new(c - v3(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(150, 220, 120),
		Enum.Material.SmoothPlastic,
		{ cyl = true, transparency = 0.55, shadow = false }
	)
	local _ = fringe
	local raft = kit.deco(
		"Raft",
		v3(1.6, g.radius * 2 + 2, g.radius * 2 + 2),
		CFrame.new(c - v3(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.WOOD,
		Enum.Material.WoodPlanks,
		{ cyl = true }
	)
	local _r = raft
	kit.deco(
		"Cup",
		v3(0.2, GF.CUP * 2, GF.CUP * 2),
		CFrame.new(c + v3(0, 0.62, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(246, 244, 238),
		Enum.Material.SmoothPlastic,
		{ cyl = true, shadow = false }
	)
	kit.deco(
		"Hole",
		v3(0.25, 1.6, 1.6),
		CFrame.new(c + v3(0, 0.66, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(20, 18, 22),
		Enum.Material.SmoothPlastic,
		{ cyl = true, shadow = false }
	)
	kit.deco("Pin", v3(0.3, 12, 0.3), CFrame.new(c + v3(0, 6.6, 0)), rgb(246, 244, 238), Enum.Material.SmoothPlastic)
	local flag = kit.deco(
		"PinFlag",
		v3(0.15, 2.4, 3.4),
		CFrame.new(c + v3(0, 11.4, 1.7)),
		rgb(230, 50, 46),
		Enum.Material.Fabric
	)
	kit.light(flag, rgb(255, 120, 100), 18, 0.8)
	kit.board(
		"HoleSign",
		v3(10, 2.6, 0.3),
		CFrame.lookAt(c + v3(0, 15.5, 0), c + v3(0, 15.5, 0) - golf.facing),
		index .. ": " .. g.name,
		Palette.GOLD
	)
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
		from = entry.from,
		speed = GF.MAX_SPEED,
		elevation = GF.ELEVATION,
		rest = golf.greens[1].center,
		prompt = prompt,
		exit = (base * CFrame.new(0, 3, 4)).Position,
		back = "landed",
		timeout = 40,
		timeoutText = "The caddy tips you out of the cannon. (Hold, then let go, to fire.)",
		aim = function(direction)
			local flat = v3(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.05 then
				local at = base.Position + v3(0, 1.4, 0)
				barrel.CFrame = CFrame.lookAt(at, at + flat.Unit)
					* CFrame.Angles(math.rad(42), 0, 0)
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
	for i, g in ipairs(golf.greens) do
		green(kit, g, i)
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

local function load(entry)
	local record = entry.data.tee
	local hole = golf.greens[entry.data.hole]
	if not record or not hole then
		return
	end
	Minigames.place(entry.player, CFrame.new(record.base.Position + v3(0, 4, 2)), false)
	task.defer(function()
		if entry.player.Parent and not entry.left and not entry.done then
			Flight.load(entry.player, record.launcher, hole.center)
			entry.data.loadedAt = now()
			entry.data.state = "aiming"
			Net.send(entry.player, "PlayFx", { kind = "golfhole", game = "golf", hole = entry.data.hole })
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
			entry.data.shots = {}
			entry.score = 0
			entry.show = { hole = 1, of = #golf.greens, shots = {} }
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

local function nextHole(session, entry)
	if entry.data.hole >= #golf.greens then
		entry.data.state = "done"
		Minigames.done(session, entry.player, entry.score or 0, entry.show)
		return
	end
	entry.data.hole += 1
	entry.show.hole = entry.data.hole
	session.dirty = true
	load(entry)
end

local function scoreShot(session, entry, position)
	local hole = golf.greens[entry.data.hole]
	local flat = v3(position.X - hole.center.X, 0, position.Z - hole.center.Z).Magnitude
	local points, kind = PortGames.golfPoints(flat)
	entry.data.shots[entry.data.hole] = points
	table.insert(entry.show.shots, points)
	Minigames.points(session, entry.player, points, entry.show)
	Net.broadcastNear(position, 600, "PlayFx", {
		kind = "golfland",
		position = position,
		userId = entry.player.UserId,
		points = points,
		grade = kind,
		distance = math.floor(flat * 10 + 0.5) / 10,
	})
	if points >= GF.POINTS.green then
		entry.data.greens = (entry.data.greens or 0) + 1
	end
end

Flight.Landed:Connect(function(player, position, launcher)
	if not launcher or launcher.kind ~= "golf" then
		return
	end
	local entry, session = Minigames.entryOf(player)
	if not entry or not session or session.game ~= "golf" or entry.data.state ~= "flying" then
		return
	end
	entry.data.state = "landed"
	scoreShot(session, entry, position)
	local token = entry.data.hole
	task.delay(GF.RETURN, function()
		if
			session.state == "running"
			and not entry.left
			and entry.data.hole == token
			and entry.data.state == "landed"
		then
			nextHole(session, entry)
		end
	end)
end)

-- The client's shot: a flat direction and a power (0..1). The barrel turns as it aims ("golfaim").
function CannonGolf.input(session, player, action, a, b)
	local entry = session.entries[player]
	if not entry or entry.data.state ~= "aiming" then
		return
	end
	local record = entry.data.tee
	if action == "golfaim" and typeof(a) == "Vector3" and record then
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
		if not entry.done and not entry.left then
			-- Tipped out of the cannon (sat too long), or the flight ended without a landing: that hole is skipped.
			if
				entry.data.state == "aiming"
				and Flight.phaseOf(player) == nil
				and t - (entry.data.loadedAt or t) > 1.5
			then
				entry.data.state = "landed"
				table.insert(entry.show.shots, 0)
				entry.data.shots[entry.data.hole] = 0
				Net.send(player, "PlayFx", { kind = "golfskip", game = "golf" })
				nextHole(session, entry)
			elseif
				entry.data.state == "flying"
				and Flight.phaseOf(player) == nil
				and t - (entry.data.firedAt or t) > 2
			then
				-- (Landed fires first in every ordinary landing; this is the safety net.)
				entry.data.state = "landed"
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				scoreShot(session, entry, root and root.Position or golf.jettyEnd)
				nextHole(session, entry)
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
	local at = golf.jettyRoot + v3(0, 3.5, 0)
	return CFrame.lookAt(at, at + golf.facing)
end

function CannonGolf.public(_session)
	return { holes = #golf.greens }
end

-- For Progress (quests): how many greens a finished round landed on.
function CannonGolf.greensOf(entry)
	return entry and entry.data and entry.data.greens or 0
end

return CannonGolf

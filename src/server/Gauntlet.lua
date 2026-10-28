-- THE GRAPPLE GAUNTLET (V13.3): a timed course in the air over the Port's north-west water, built for V13.2's
-- momentum and swinging grapple. Every run is its own (a challenge starts two together), so any number can play.
--
--   THE COURSE  (shared/PortGames.lua: PortGames.GAUNTLET) the start deck's bounce pad throws you up to the first
--               platform; a swing hook over the gap; a narrow beam; another pad; two swings in a row; a zipline;
--               a last swing; a pad up to the bell. Hooks are gold balls: hook one (F) and swing, W to pump, F or
--               Space to let go. Nothing here is new movement: it is the game's own.
--   THE CLOCK   starts at GO (everyone held on the start deck until then) and stops at the bell. The server watches
--               every runner ten times a second and only counts a platform once the one before it was reached.
--   FALLING     a runner who drops into the water (Config.PLAYGROUND.GAUNTLET.FALL_Y) is put back on the last
--               platform they reached, and the clock runs on: falling costs time, never the run. (V13.5: put back
--               facing the next platform, the splashes counted on the panel.)
--   V13.5       targeted polish, the course itself unchanged: each hook has a big invisible catch round it (a hook
--               aimed near the gold ball swings from the ball itself: client/Main.lua), the hooks of the leg ahead
--               light up (client/PlayHud.lua), a shortcut says how many platforms it skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Minigames = require(script.Parent.Minigames)

local GA = Config.PLAYGROUND.GAUNTLET
local course = PortGames.GAUNTLET
local rgb = Color3.fromRGB
local v3 = Vector3.new

local Gauntlet = {
	id = "gauntlet",
	concurrent = true,
	limit = GA.MAX_RUNNERS,
	max = 2,
	duration = GA.LIMIT,
}

local HOOK_GOLD = rgb(255, 205, 70)

local function now()
	return workspace:GetServerTimeNow()
end

-- Building ------------------------------------------------------------------------------------------------------------------
local function platform(kit, p, color, label)
	local top = p.center
	kit.part(
		"GauntletDeck",
		v3(p.size, 1.4, p.size),
		CFrame.new(top - v3(0, 0.7, 0)),
		color or Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	-- A post down to the water (scenery: it does not catch a falling goblin).
	kit.deco(
		"GauntletPost",
		v3(1.8, top.Y + 30, 1.8),
		CFrame.new(top.X, (top.Y - 30) / 2 - 1, top.Z),
		Palette.WOOD_DARK,
		Enum.Material.Wood
	)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			kit.deco(
				"DeckLantern",
				v3(0.9, 1.2, 0.9),
				CFrame.new(top + v3(sx * (p.size / 2 - 0.6), 0.6, sz * (p.size / 2 - 0.6))),
				rgb(255, 214, 130),
				Enum.Material.Neon,
				{ shadow = false }
			)
		end
	end
	if label then
		local flag = kit.deco(
			"CheckFlag",
			v3(0.2, 2.2, 3.4),
			CFrame.new(top + v3(0, 5, p.size / 2 - 1)),
			rgb(255, 96, 170),
			Enum.Material.Fabric
		)
		kit.deco(
			"FlagPole",
			v3(0.3, 6, 0.3),
			CFrame.new(top + v3(0, 3, p.size / 2 - 1 + 1.7)),
			Palette.WOOD_DARK,
			Enum.Material.Wood
		)
		local _ = flag
	end
end

local function hook(kit, position)
	local ball = kit.part("GauntletHook", v3(5, 5, 5), CFrame.new(position), HOOK_GOLD, Enum.Material.Metal)
	ball.Shape = Enum.PartType.Ball
	ball.CanCollide = false -- hookable (the grapple's ray finds it), never something to bonk into
	ball.CanQuery = true
	-- V13.5: a catch round it, so a hook aimed near the ball takes (the client swings from the ball's middle).
	local catch = kit.part("HookTarget", v3(15, 15, 15), CFrame.new(position), HOOK_GOLD, Enum.Material.SmoothPlastic, {
		ball = true,
		transparency = 1,
		shadow = false,
	})
	catch.CanCollide = false
	catch.CanQuery = true
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		kit.deco(
			"HookGlow",
			v3(1, 1, 1),
			CFrame.new(position + v3(math.cos(a) * 4.4, 0, math.sin(a) * 4.4)),
			rgb(255, 240, 160),
			Enum.Material.Neon,
			{ shadow = false }
		)
	end
	kit.light(ball, rgb(255, 214, 120), 16, 1)
end

local function pad(kit, at, launch)
	local p = Instance.new("Part")
	p.Name = "LaunchPad"
	p.Shape = Enum.PartType.Cylinder
	p.Size = v3(0.8, 7, 7)
	p.CFrame = CFrame.new(at + v3(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = rgb(230, 60, 60)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p:SetAttribute("Launch", launch)
	p.Parent = kit.refs.folders.launchPads
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		kit.deco(
			"PadSpot",
			v3(0.2, 1.2, 1.2),
			CFrame.new(at + v3(math.cos(a) * 2.2, 0.9, math.sin(a) * 2.2)) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(255, 250, 236),
			Enum.Material.SmoothPlastic,
			{ cyl = true, shadow = false }
		)
	end
end

function Gauntlet.build(kit)
	platform(kit, course.start, rgb(196, 160, 110), nil)
	kit.board(
		"GauntletSign",
		v3(18, 4, 0.5),
		CFrame.lookAt(PortGames.VENUES.gauntlet.sign, PortGames.VENUES.gauntlet.sign + v3(1, 0, 1)),
		"GRAPPLE GAUNTLET",
		HOOK_GOLD
	)
	for i, p in ipairs(course.platforms) do
		platform(kit, p, p.name == "FINISH" and rgb(255, 214, 90) or nil, i < #course.platforms)
	end
	-- The beam from P2 to P3.
	local beam = course.beam
	local mid = (beam.from + beam.to) / 2
	kit.part(
		"GauntletBeam",
		v3(beam.width, 1, (beam.to - beam.from).Magnitude + 2),
		CFrame.lookAt(mid - v3(0, 0.5, 0), beam.to - v3(0, 0.5, 0)),
		Palette.WOOD,
		Enum.Material.Wood
	)
	for _, h in ipairs(course.hooks) do
		hook(kit, h.at)
	end
	for _, entry in ipairs(course.pads) do
		pad(kit, entry.at, entry.launch)
	end
	local Kit = kit.worldKit
	Kit.setShift(Vector3.zero)
	Kit.zipline("GauntletZip", course.zip.from, course.zip.to)
	Kit.zipline("GauntletHome", course.home.from, course.home.to)
	-- The bell at the finish.
	local finish = course.platforms[#course.platforms].center
	kit.part("BellFrame", v3(1, 10, 1), CFrame.new(finish + v3(-4, 5, 0)), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.part("BellFrame", v3(1, 10, 1), CFrame.new(finish + v3(4, 5, 0)), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.deco("BellBeam", v3(9, 1, 1), CFrame.new(finish + v3(0, 10, 0)), Palette.WOOD_DARK, Enum.Material.Wood)
	local bell = kit.deco(
		"FinishBell",
		v3(4, 4.4, 4),
		CFrame.new(finish + v3(0, 7.4, 0)),
		HOOK_GOLD,
		Enum.Material.Metal,
		{ egg = true }
	)
	kit.light(bell, rgb(255, 220, 140), 30, 1.4)
	kit.board(
		"FinishSign",
		v3(14, 3, 0.4),
		CFrame.lookAt(finish + v3(0, 14, 0), finish + v3(0, 14, 0) + v3(1, 0, 1)),
		"RING THE BELL!",
		HOOK_GOLD
	)
end

-- Running ------------------------------------------------------------------------------------------------------------------
local function startSpot(index)
	local base = course.startSpot
	return base * CFrame.new((index - 1) * 4 - 2, 0, 0)
end

local function putBack(session, entry, t)
	local index = entry.data.cp - 1
	local cf = index >= 1 and course.checkpoints[index].respawn or startSpot(1)
	Minigames.place(entry.player, cf, true)
	entry.data.heldUntil = t + 0.5
	entry.data.falls = (entry.data.falls or 0) + 1
	entry.show = { cp = index, of = #course.checkpoints, falls = entry.data.falls }
	session.dirty = true
	Net.send(entry.player, "PlayFx", { kind = "fall", game = "gauntlet", position = cf.Position })
end

function Gauntlet.prepare(session)
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry then
			entry.data.cp = 1
			entry.data.slot = i
			entry.show = { cp = 0, of = #course.checkpoints }
			Minigames.place(player, startSpot(i), true)
		end
	end
end

function Gauntlet.go(session, t)
	session.endsAt = t + GA.LIMIT
	session.data.nextCheck = t
	for player in pairs(session.entries) do
		Minigames.release(player)
	end
end

function Gauntlet.tick(session, _dt, t)
	if t < (session.data.nextCheck or 0) then
		return
	end
	session.data.nextCheck = t + 0.1
	for player, entry in pairs(session.entries) do
		if not entry.done and not entry.left then
			if entry.data.heldUntil and t >= entry.data.heldUntil then
				entry.data.heldUntil = nil
				Minigames.release(player)
			end
			local root = Util.aliveRoot(player)
			if root then
				local p = root.Position
				-- V13.4: any platform further on counts, so a daring swing that skips one is a SHORTCUT, not a
				-- wasted jump (the platforms between are counted as passed).
				local reached = PortGames.gauntletReached(p, entry.data.cp)
				if reached then
					local skipped = reached - entry.data.cp
					entry.data.cp = reached + 1
					entry.show = { cp = reached, of = #course.checkpoints, falls = entry.data.falls }
					session.dirty = true
					Net.send(player, "PlayFx", {
						kind = "checkpoint",
						game = "gauntlet",
						n = reached,
						shortcut = skipped > 0 or nil,
						skipped = skipped > 0 and skipped or nil,
					})
					if entry.data.cp > #course.checkpoints then
						local time = math.floor((t - session.goAt) * 100 + 0.5) / 100
						if time < GA.MIN_TIME then
							warn(string.format("[Gauntlet] %s's run of %.1f s was not believed", player.Name, time))
							Minigames.done(session, player, nil, entry.show)
						else
							Minigames.done(session, player, time, entry.show)
							Net.broadcastNear(p, 600, "PlayFx", { kind = "bell", position = p, userId = player.UserId })
						end
					end
				elseif p.Y < GA.FALL_Y and not entry.data.heldUntil and not PortGames.inBox(p, course.startBox) then
					putBack(session, entry, t)
				end
			end
		end
	end
end

function Gauntlet.input(session, player, action)
	local entry = session.entries[player]
	if action == "reset" and entry and not entry.done then
		local t = now()
		if t - (entry.data.resetAt or 0) > 2 then
			entry.data.resetAt = t
			putBack(session, entry, t)
		end
	end
end

function Gauntlet.drop(_session, player)
	Minigames.release(player)
end

function Gauntlet.stop(session)
	for player in pairs(session.entries) do
		Minigames.release(player)
	end
end

-- Afterwards: the beach by the start (a finished runner rides the zipline home, or is put there).
function Gauntlet.spot(session, player)
	local entry = session.entries[player]
	local i = entry and entry.data.slot or 1
	return CFrame.new(PortGames.world(-96 + i * 3, 9.5, -88))
end

return Gauntlet

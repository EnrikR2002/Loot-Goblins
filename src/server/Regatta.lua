-- THE TINY BOAT REGATTA (V13.3; V13.5: a new circuit and test drives): one lap of a circuit in the Port's east water,
-- up to eight goblins at once. The course is shared/PortGames.lua's (PortGames.REGATTA); this module builds it and runs
-- a race through server/Minigames.lua.
--
--   THE BOATS     every goblin picks their boat in the lobby (PlayRequest "choose"): the RACING TUB (everyone in the
--                 same boat: the FASTEST REGATTA board's race), or a TEST DRIVE in any of the ten classes, owned or
--                 not. Either way it is a LOANER the Port builds for the lap (Boats.spawnPortBoat) and takes back after
--                 it: nobody keeps it, nothing is granted. Each class drives as it does in a raid (its own handling and
--                 its R ability: the Regatta's water is the one place in the Port abilities work); the bow gun stays
--                 a raid's (no cannons in the Port). A lap's record is that boat's own (PortGames.recordKey).
--   THE START     boats on a grid behind the line, held by the server (Boats.hold) until GO. V13.4: throttle down
--                 right on GO (not held through the countdown) is a ROCKET START, a short boost ("launch").
--   THE LAP       the server watches every hull (10 times a second, swept between looks, so a fast boat cannot slip
--                 past a checkpoint) through the checkpoints in order; crossing the line after the last is the finish.
--                 THE TEETH has two ways: the narrow channel (the shortcut, with a hoop) or the long way round. A lap
--                 faster than Config.PLAYGROUND.REGATTA.MIN_TIME is not believed.
--   THE COURSE    the Pier Straight's two hoops, the Lighthouse Bend, the Leap (a ramp, a reef across the lane with
--                 gaps at its edges, a high hoop only a jump reaches), the Flume (a hairpin whose current carries you
--                 round), Barrel Alley, the Teeth, the Bumper Chicane, Cannon Corner (a splash cannon) and home.
--   FALLING OUT   a goblin out of their boat for REJOIN_AFTER seconds (or pressing RESET) is put back at their last
--                 checkpoint, seated, at rest, facing on along the lap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Cannons = require(script.Parent.Cannons)
local Port = require(script.Parent.Port)
local Minigames = require(script.Parent.Minigames)

local RG = Config.PLAYGROUND.REGATTA
local R = PortGames.REGATTA
local heading, at = PortGames.regattaHeading, PortGames.regattaAt
local rgb = Color3.fromRGB
local v3 = Vector3.new

local Regatta = { id = "regatta", max = RG.MAX, duration = RG.LIMIT }

local HOOP = rgb(255, 96, 170)
local ROCK, ROCK_DARK = Palette.ROCK or rgb(120, 112, 118), rgb(84, 78, 90)
local cannons = {} -- { muzzle, nextAt, pending = { at, point } }
local picks = setmetatable({}, { __mode = "k" }) -- player -> the boat they last chose (a class id or "racer")
Regatta.lights = {} -- the start gantry's lamps (the clients light them from the session's clock)

-- The boats a goblin may race: the Racing Tub and every class (Config.BOAT_CLASSES order).
local CHOICES = { racer = true }
for _, entry in ipairs(Config.BOAT_CLASSES) do
	CHOICES[entry.id] = Config.BOAT_TYPES[entry.id] ~= nil
end

local function now()
	return workspace:GetServerTimeNow()
end

local function flatUnit(v)
	local f = v3(v.X, 0, v.Z)
	return f.Magnitude > 1e-6 and f.Unit or v3(0, 0, -1)
end

-- The hoops, the ramp and the Flume's current are part of the sea every boat sails: they must exist before Boats.build
-- sends every client the gates and the currents (Main calls this between building the sea grid and the boats).
function Regatta.addGates(Kit)
	Kit.setShift(Vector3.zero)
	for _, h in ipairs(R.hoops) do
		Kit.hoop(v3(h.at.X, 5, h.at.Z), h.dir, h.small and 8 or 12, HOOP, true)
	end
	Kit.hoop(R.highHoop.at, R.highHoop.dir, 12, rgb(255, 214, 90), true)
	Kit.kicker(v3(R.ramp.at.X, 0, R.ramp.at.Z), R.ramp.dir, R.ramp.width)
	-- THE FLUME: a current along the hairpin (the banked turn: it carries you round if you ride it).
	for i = R.flume.from, R.flume.to - 1 do
		Kit.stream(i == R.flume.from and "THE FLUME" or "", R.line[i].p, R.line[i + 1].p, R.line[i].w, RG.FLUME)
	end
end

-- Building the course -----------------------------------------------------------------------------------------------------
local function rock(kit, name, size, cframe, color)
	return kit.part(name, size, cframe, color or ROCK, Enum.Material.Slate)
end

local function buoy(kit, position, color)
	local b =
		kit.deco("CourseBuoy", v3(3, 4, 3), CFrame.new(position + v3(0, 1.2, 0)), color, Enum.Material.SmoothPlastic, {
			egg = true,
		})
	kit.deco(
		"BuoyFlag",
		v3(0.2, 2, 2.6),
		CFrame.new(position + v3(0, 4.4, 1)),
		rgb(255, 250, 240),
		Enum.Material.Fabric
	)
	return b
end

local function sign(kit, position, facing, text, color)
	local cf = CFrame.lookAt(position, position + facing)
	kit.board("RegattaSign", v3(18, 4, 0.5), cf, text, color or Palette.GOLD)
	kit.part(
		"SignPost",
		v3(1, position.Y + 6, 1),
		CFrame.new(position.X, position.Y / 2 - 5, position.Z),
		Palette.WOOD_DARK,
		Enum.Material.Wood
	)
end

-- A row of rock blocks from a to b (flat), `thick` across, `height` above the water, with teeth on top if jagged.
local function rockRow(kit, name, a, b, thick, height, jagged)
	local d = flatUnit(b - a)
	local length = v3(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local steps = math.max(1, math.ceil(length / 22))
	for i = 0, steps - 1 do
		local p = a + d * ((i + 0.5) * length / steps)
		local h = height + (jagged and ((i * 37) % 9) or 0)
		local cf = CFrame.lookAt(v3(p.X, h / 2 - 8, p.Z), v3(p.X, h / 2 - 8, p.Z) + d)
		rock(kit, name, v3(thick, h + 8, length / steps + 3), cf, i % 2 == 0 and ROCK or ROCK_DARK)
		if jagged then
			kit.deco(
				"Tooth",
				v3(thick * 0.5, 7 + (i % 3) * 3, 6),
				cf * CFrame.new(0, (h + 8) / 2 + 3, 0) * CFrame.Angles(0, 0, math.rad((i % 2 == 0) and 10 or -10)),
				rgb(236, 230, 214),
				Enum.Material.Slate,
				{ wedge = true }
			)
		end
	end
end

-- A chevron board on the outside of a corner, facing the boats coming in: which way it bends.
local function chevrons(kit, position, facing, text)
	local cf = CFrame.lookAt(position + v3(0, 9, 0), position + v3(0, 9, 0) + facing)
	kit.board("CornerChevrons", v3(16, 5, 0.4), cf, text, rgb(255, 255, 255), rgb(230, 50, 46))
	kit.part("ChevronPost", v3(1.2, 16, 1.2), CFrame.new(position + v3(0, 1, 0)), Palette.WOOD_DARK, Enum.Material.Wood)
end

local function buildStart(kit)
	local a, b = R.startLine.a, R.startLine.b
	for _, p in ipairs({ a, b }) do
		kit.part("StartPylon", v3(3, 46, 3), CFrame.new(p.X, 14, p.Z), rgb(246, 244, 238), Enum.Material.SmoothPlastic)
		kit.deco("PylonCap", v3(4, 2, 4), CFrame.new(p.X, 38, p.Z), Palette.GOLD, Enum.Material.Metal)
		-- Pennants down each pylon: the line is something to aim at from far down the Home Straight.
		for k = 0, 3 do
			kit.deco(
				"PylonPennant",
				v3(0.2, 2.4, 3.4),
				CFrame.new(p.X, 18 + k * 4.5, p.Z + 2),
				k % 2 == 0 and HOOP or Palette.GOLD,
				Enum.Material.Fabric
			)
		end
	end
	local mid = (a + b) / 2
	local across = b - a
	local banner = CFrame.lookAt(v3(mid.X, 32, mid.Z), v3(mid.X, 32, mid.Z) + heading(1))
	for i = 0, 11 do
		for row = 0, 1 do
			kit.deco(
				"Chequer",
				v3(across.Magnitude / 12, 3, 0.3),
				banner
					* CFrame.new(-across.Magnitude / 2 + (i + 0.5) * across.Magnitude / 12, row == 0 and 1.5 or -1.5, 0),
				((i + row) % 2 == 0) and rgb(28, 26, 32) or rgb(246, 244, 238),
				Enum.Material.Fabric
			)
		end
	end
	kit.board("StartBanner", v3(40, 5, 0.4), banner * CFrame.new(0, 6, 0), "START · FINISH", Palette.GOLD)
	-- The start lights: four lamps over the line. Three go red at 3, 2, 1 and all four green at GO (client/PlayHud).
	for i = 1, 4 do
		local lamp = kit.deco(
			"StartLight",
			v3(3.2, 3.2, 1.2),
			banner * CFrame.new((i - 2.5) * 5, -5.4, -0.4),
			rgb(40, 36, 44),
			Enum.Material.SmoothPlastic,
			{ ball = true }
		)
		Regatta.lights[i] = lamp
		lamp:SetAttribute("StartLight", i)
	end
end

function Regatta.build(kit)
	local C = kit.center
	local function rel(x, y, z)
		return v3(C.X + x, y, C.Z + z)
	end
	-- The dock on the east shore, where heats gather.
	kit.floor(
		"RegattaDock",
		v3(80, 1.4, 14),
		CFrame.new(rel(203, 5.3, 62)),
		Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	for x = 170, 238, 12 do
		for _, side in ipairs({ -1, 1 }) do
			kit.part(
				"DockPost",
				v3(1.4, 12, 1.4),
				CFrame.new(rel(x, -0.5, 62 + side * 7.2)),
				Palette.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	kit.arch(170, 62, -90, "TINY BOAT REGATTA", rgb(120, 210, 255))
	for i = 0, 3 do
		kit.deco(
			"DockTub",
			v3(5, 2, 9),
			CFrame.new(rel(186 + i * 14, 1.2, 72)) * CFrame.Angles(0, math.rad(8 * (i % 2 == 0 and 1 or -1)), 0),
			({ rgb(255, 96, 170), rgb(90, 200, 255), rgb(255, 214, 90), rgb(120, 230, 120) })[i + 1],
			Enum.Material.SmoothPlastic,
			{ egg = true }
		)
	end
	-- The week's CLASS RECORDS: a board on the dock, written by every client (client/PlayHud.lua) from the workspace's
	-- RegattaRecords attribute (server/Leaderboards.lua).
	local records = kit.board(
		"RegattaRecordsBoard",
		v3(13, 15, 0.5),
		CFrame.lookAt(rel(196, 13.5, 54), rel(196, 13.5, 30)),
		"",
		Palette.GOLD,
		rgb(36, 26, 22),
		kit.core
	)
	records:SetAttribute("RegattaRecords", true)
	for _, x in ipairs({ -7.2, 7.2 }) do
		kit.part(
			"RecordsPost",
			v3(1, 16, 1),
			CFrame.lookAt(rel(196, 13.5, 54), rel(196, 13.5, 30)) * CFrame.new(x, -1.5, 0.6),
			Palette.WOOD_DARK,
			Enum.Material.Wood
		)
	end
	buildStart(kit)
	-- Checkpoint gates: a pair of buoys at the lane's edges.
	for index, cp in ipairs(R.checkpoints) do
		if index < R.finish then
			for _, disc in ipairs(cp.discs) do
				if disc.line then
					local d = heading(disc.line - 1 >= 1 and disc.line - 1 or #R.line)
					local right = v3(-d.Z, 0, d.X)
					buoy(kit, disc.center + right * (disc.radius - 6), HOOP)
					buoy(kit, disc.center - right * (disc.radius - 6), HOOP)
				end
			end
		end
	end
	-- Lane floats on both edges, every few dozen studs, so the way round reads from a boat (not along the Teeth's
	-- channel: its rocks are its edges).
	for i, point in ipairs(R.line) do
		local length = v3(R.line[i % #R.line + 1].p.X - point.p.X, 0, R.line[i % #R.line + 1].p.Z - point.p.Z).Magnitude
		for along = 12, length - 12, 34 do
			for _, side in ipairs({ -1, 1 }) do
				local p = at(i, along, side * (point.w + 4))
				kit.deco(
					"LaneFloat",
					v3(2, 1.4, 2),
					CFrame.new(p.X, 0.9, p.Z),
					(math.floor(along / 34) % 2 == 0) and rgb(255, 250, 236) or HOOP,
					Enum.Material.SmoothPlastic,
					{ egg = true }
				)
			end
		end
	end
	-- THE LIGHTHOUSE on its rock inside the first bend.
	local L = R.lighthouse
	rock(kit, "LighthouseRock", v3(L.radius * 2, 12, L.radius * 2), CFrame.new(L.center + v3(0, -1, 0)), ROCK_DARK)
	for k = 0, 4 do
		kit.part(
			"Lighthouse",
			v3(7 - k * 0.6, 6, 7 - k * 0.6),
			CFrame.new(L.center + v3(0, 8 + k * 6, 0)),
			k % 2 == 0 and rgb(246, 244, 238) or rgb(230, 50, 46),
			Enum.Material.SmoothPlastic
		)
	end
	local lantern =
		kit.deco("LighthouseLamp", v3(4, 4, 4), CFrame.new(L.center + v3(0, 40, 0)), Palette.GOLD, Enum.Material.Neon)
	kit.light(lantern, rgb(255, 220, 140), 60, 2)
	chevrons(kit, at(2, 70, -(R.line[2].w + 16)), heading(1) * -1, "▶ ▶ ▶")
	-- THE LEAP: the reef across the middle of the lane just past the ramp (its edges are gaps for the careful).
	local reef = R.reef
	local across = v3(-reef.dir.Z, 0, reef.dir.X)
	rockRow(kit, "Reef", reef.center - across * reef.half, reef.center + across * reef.half, 10, 2.5, false)
	sign(
		kit,
		at(5, 30, -(R.line[5].w + 14)) + v3(0, 22, 0),
		heading(5) * -1,
		"THE LEAP ▲ RAMP OR THE GAPS",
		rgb(255, 200, 90)
	)
	-- THE FLUME: the rock the hairpin goes round, and a berm of rocks on the outside to catch the brave.
	local F = R.flumeRock
	rock(kit, "FlumeRock", v3(F.radius * 2, 22, F.radius * 2), CFrame.new(F.center + v3(0, 2, 0)), ROCK_DARK)
	kit.deco(
		"FlumeRockCap",
		v3(F.radius * 1.4, 4, F.radius * 1.4),
		CFrame.new(F.center + v3(0, 14, 0)),
		rgb(120, 170, 90),
		Enum.Material.Grass
	)
	for i = 8, 9 do
		rockRow(kit, "FlumeBerm", at(i, 25, R.line[i].w + 14), at(i, 85, R.line[i].w + 14), 8, 4, false)
	end
	chevrons(kit, at(7, 60, -(R.line[7].w + 18)), heading(7) * -1, "▶ ▶ THE FLUME ▶ ▶")
	-- Barrels to weave through.
	for i, p in ipairs(R.barrels) do
		local barrel = kit.part(
			"CourseBarrel",
			v3(5, 4.2, 4.2),
			CFrame.new(p.X, 1, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
			(i % 3 == 0) and rgb(200, 60, 50) or Palette.WOOD,
			Enum.Material.WoodPlanks
		)
		barrel.Shape = Enum.PartType.Cylinder
	end
	-- THE TEETH: rocks either side of the channel (the shortcut), and its sign.
	local T = R.shortcut
	local a0, a1 = T.from + T.along * T.startAt, T.from + T.along * T.endAt
	local nearOff, farOff = T.toward * (T.half + T.near / 2), T.toward * -(T.half + T.far / 2)
	rockRow(kit, "TeethRock", a0 + nearOff, a1 + nearOff, T.near, 20, true)
	rockRow(kit, "TeethRock", a0 + farOff, a1 + farOff, T.far, 18, true)
	sign(
		kit,
		at(12, 40, R.line[12].w + 14) + v3(0, 26, 0),
		heading(12) * -1,
		"THE TEETH: GAP ◀ OR GO ROUND ▶",
		rgb(255, 120, 90)
	)
	-- The chicane's bumper buoys: big, red and white, and bouncy.
	for i, p in ipairs(R.buoys) do
		local ball = kit.part(
			"BumperBuoy",
			v3(9, 9, 9),
			CFrame.new(p.X, 2.4, p.Z),
			(i % 2 == 0) and rgb(230, 50, 46) or rgb(246, 244, 238),
			Enum.Material.SmoothPlastic
		)
		ball.Shape = Enum.PartType.Ball
		ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 1, 1, 100)
	end
	chevrons(kit, at(18, 60, -(R.line[18].w + 16)), heading(18) * -1, "▶ ▶ ▶")
	-- The splash cannons on their rocks, outside the lane.
	for _, c in ipairs(R.cannons) do
		local p = c.rock
		rock(kit, "CannonRock", v3(26, 16, 26), CFrame.new(p.X, 0, p.Z), ROCK_DARK)
		local muzzle = v3(p.X, 11, p.Z)
		kit.deco(
			"SplashCannon",
			v3(9, 3.4, 3.4),
			CFrame.lookAt(muzzle, muzzle + v3(0, 0.4, -1)) * CFrame.Angles(0, math.rad(90), 0),
			rgb(46, 44, 52),
			Enum.Material.Metal,
			{ cyl = true }
		)
		table.insert(cannons, { muzzle = muzzle, nextAt = 0 })
	end
end

-- Choosing a boat -------------------------------------------------------------------------------------------------------------
function Regatta.optionOf(player)
	return picks[player] or "racer"
end

-- A goblin picks a boat (before joining, or while the lobby waits). Anything not on the list is the Racing Tub.
function Regatta.choose(player, class, session)
	if type(class) ~= "string" or not CHOICES[class] then
		return
	end
	picks[player] = class
	local entry = session and session.entries[player]
	if entry and session.state == "lobby" then
		entry.option = class
		local ok, best = pcall(Minigames.bestOf, player, "regatta", class)
		entry.best = ok and type(best) == "number" and best or nil
		Minigames.publish(session)
	end
end

-- Running a race ----------------------------------------------------------------------------------------------------------
local function seat(entry, boat)
	local player = entry.player
	local humanoid, root = Port.freeOf(player)
	if not root then
		return
	end
	local character = player.Character
	pcall(function()
		player:RequestStreamAroundAsync(boat.hull.Position, 2)
	end)
	character:PivotTo(boat.driver.CFrame + v3(0, 3, 0))
	task.defer(function()
		if boat.driver and boat.driver.Parent and humanoid.Parent and not humanoid.SeatPart then
			boat.driver:Sit(humanoid)
		end
	end)
end

local function spawnBoat(entry, cframe, holdUntil)
	local boat = Boats.spawnPortBoat(entry.data.class or "racer", cframe)
	if boat.spec.class then
		Cannons.mountIfArmed(boat) -- the Broadside's volley needs its side guns; the bow gun refuses in the Port
	end
	if holdUntil then
		Boats.hold(boat, holdUntil)
	end
	entry.data.boat = boat
	seat(entry, boat)
	return boat
end

local function removeBoat(entry)
	local boat = entry.data.boat
	entry.data.boat = nil
	if boat and boat.state ~= "gone" then
		Boats.remove(boat)
	end
end

-- Back at the last checkpoint passed, seated, at rest.
local function putBack(session, entry, t)
	local index = entry.data.cp - 1
	local cf = index >= 1 and PortGames.regattaRespawn(index) or R.grid[entry.data.slot or 1]
	local boat = entry.data.boat
	if not boat or boat.state ~= "float" or not boat.model.Parent then
		removeBoat(entry)
		boat = spawnBoat(entry, cf, t + 0.6)
	else
		local spec = boat.spec
		Boats.place(boat, CFrame.new(cf.X, spec.size.Y / 2 - spec.draft, cf.Z) * cf.Rotation)
		Boats.hold(boat, t + 0.6)
		seat(entry, boat)
	end
	entry.data.lastPos = boat.hull.Position
	entry.data.outSince = nil
	entry.data.resetAt = t
	Net.send(entry.player, "PlayFx", { kind = "reset", game = "regatta" })
	local _ = session
end

function Regatta.prepare(session)
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry and not entry.left then
			entry.data.cp = 1
			entry.data.slot = i
			entry.data.class = entry.option or Regatta.optionOf(player)
			local boat = spawnBoat(entry, R.grid[i], session.goAt)
			entry.data.lastPos = boat.hull.Position
			entry.show = { cp = 0, of = R.finish, boat = entry.data.class }
		end
	end
end

function Regatta.go(session, t)
	session.endsAt = t + RG.LIMIT
	session.data.nextCheck = t
	for _, c in ipairs(cannons) do
		c.nextAt = t + RG.SPLASH_EVERY * 0.6
		c.pending = nil
	end
end

-- The splash cannons: ring the water ahead of the nearest boat in the race, then throw whatever is in the ring.
local function cannonTick(session, t)
	for _, c in ipairs(cannons) do
		if c.pending and t >= c.pending.at then
			local point = c.pending.point
			c.pending = nil
			for _, boat in ipairs(Boats.list) do
				if boat.portGame and boat.state == "float" then
					local offset = boat.hull.Position - point
					local flat = v3(offset.X, 0, offset.Z)
					if flat.Magnitude <= RG.SPLASH_RADIUS then
						local away = flat.Magnitude > 0.5 and flat.Unit or flatUnit(point - c.muzzle)
						Boats.shove(boat, away * RG.SPLASH_PUSH + v3(0, RG.SPLASH_LIFT, 0), v3(0, 1.6, 0))
					end
				end
			end
			Net.broadcastNear(point, 900, "PlayFx", { kind = "splash", position = point, radius = RG.SPLASH_RADIUS })
		elseif not c.pending and t >= c.nextAt then
			c.nextAt = t + RG.SPLASH_EVERY
			-- The nearest boat in the race within reach, and where it will be.
			local best, bestDistance
			for _, entry in pairs(session.entries) do
				local boat = entry.data.boat
				if boat and not entry.done and not entry.left and boat.state == "float" then
					local d = (boat.hull.Position - c.muzzle).Magnitude
					if d < 280 and (not bestDistance or d < bestDistance) then
						best, bestDistance = boat, d
					end
				end
			end
			if best then
				local v = best.hull.AssemblyLinearVelocity
				local point = best.hull.Position + v3(v.X, 0, v.Z) * RG.SPLASH_LEAD
				point = v3(point.X, 0.5, point.Z)
				c.pending = { at = t + RG.SPLASH_WARN, point = point }
				Net.broadcastNear(point, 900, "Marker", {
					position = point,
					radius = RG.SPLASH_RADIUS,
					duration = RG.SPLASH_WARN,
					color = rgb(90, 200, 255),
				})
				Net.broadcastNear(
					c.muzzle,
					900,
					"CannonFire",
					{ position = c.muzzle, direction = (point - c.muzzle).Unit }
				)
			end
		end
	end
end

function Regatta.tick(session, _dt, t)
	cannonTick(session, t)
	if t < (session.data.nextCheck or 0) then
		return
	end
	session.data.nextCheck = t + 0.1
	local order = {}
	for player, entry in pairs(session.entries) do
		local boat = entry.data.boat
		if not entry.done and not entry.left and boat then
			-- Seated? A goblin out of their boat is put back after a moment.
			local _, humanoid = Util.aliveRoot(player)
			local seated = humanoid and boat.driver and humanoid.SeatPart == boat.driver
			if not seated then
				entry.data.outSince = entry.data.outSince or t
				if t - entry.data.outSince >= RG.REJOIN_AFTER then
					putBack(session, entry, t)
				end
			else
				entry.data.outSince = nil
			end
			if boat.state ~= "float" or not boat.model.Parent then
				putBack(session, entry, t)
			end
			boat = entry.data.boat
			-- The next checkpoint, swept from the last look.
			local here = boat.hull.Position
			local last = entry.data.lastPos or here
			local cp = R.checkpoints[entry.data.cp]
			if cp and (here - last).Magnitude < 400 then
				for _, disc in ipairs(cp.discs) do
					if PortGames.crossed(last, here, disc.center, disc.radius) then
						entry.data.cp += 1
						entry.show = { cp = entry.data.cp - 1, of = R.finish, boat = entry.data.class }
						session.dirty = true
						if entry.data.cp > R.finish then
							local time = math.floor((t - session.goAt) * 100 + 0.5) / 100
							if time < RG.MIN_TIME then
								warn(string.format("[Regatta] %s's lap of %.1f s was not believed", player.Name, time))
								Minigames.done(session, player, nil, entry.show)
							else
								Minigames.done(session, player, time, entry.show)
								Net.broadcastNear(here, 900, "PlayFx", {
									kind = "finish",
									position = here,
									userId = player.UserId,
									boat = entry.data.class,
								})
							end
							removeBoat(entry)
							-- Off the course and back on the dock to watch the others come in.
							if player.Parent and player:GetAttribute("Zone") ~= "raid" then
								Port.arrive(player, Regatta.spot(session, player))
							end
						else
							Net.send(player, "PlayFx", {
								kind = "gate",
								game = "regatta",
								position = disc.center,
								shortcut = cp.teeth and disc == cp.discs[1] or nil,
							})
						end
						break
					end
				end
			end
			entry.data.lastPos = here
			if not entry.done then
				local next = R.checkpoints[entry.data.cp]
				local gap = next and (here - next.discs[#next.discs].center).Magnitude or 0
				table.insert(order, { entry = entry, cp = entry.data.cp, gap = gap })
			end
		end
	end
	-- The running order (for each goblin's screen): checkpoints passed, then nearest the next.
	table.sort(order, function(x, y)
		if x.cp ~= y.cp then
			return x.cp > y.cp
		end
		return x.gap < y.gap
	end)
	local finished = 0
	for _, entry in pairs(session.entries) do
		if entry.done then
			finished += 1
		end
	end
	for i, row in ipairs(order) do
		local show = row.entry.show
		local pos = finished + i
		if type(show) == "table" and show.pos ~= pos then
			show.pos = pos
			session.dirty = true
		end
	end
end

function Regatta.input(session, player, action)
	local entry = session.entries[player]
	if action == "reset" and entry and not entry.done then
		local t = now()
		if t - (entry.data.resetAt or 0) > 3 then
			putBack(session, entry, t)
		end
	elseif action == "launch" and entry and not entry.data.launched then
		-- V13.4: a ROCKET START. The client sends it the moment GO comes if the throttle went down on time (not
		-- held through the countdown); the server takes it only once and only just after GO.
		entry.data.launched = true
		local t = now()
		local boat = entry.data.boat
		if t - session.goAt <= RG.LAUNCH_LATE and boat and boat.state == "float" then
			boat.boostUntil = math.max(boat.boostUntil or 0, t + RG.LAUNCH)
			boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
		end
	end
end

function Regatta.drop(session, player)
	local entry = session.entries[player]
	if entry then
		removeBoat(entry)
	end
end

function Regatta.stop(session)
	for _, entry in pairs(session.entries) do
		removeBoat(entry)
	end
	for _, c in ipairs(cannons) do
		c.pending = nil
	end
end

-- Back on the dock afterwards, spread along it.
function Regatta.spot(session, player)
	local entry = session.entries[player]
	local i = entry and entry.data.slot or 1
	return CFrame.lookAt(PortGames.world(176 + (i % 6) * 9, 9.5, 62), PortGames.world(176 + (i % 6) * 9, 9.5, 40))
end

function Regatta.public(_session)
	return { finish = R.finish }
end

return Regatta

-- THE TINY BOAT REGATTA (V13.3): one lap of the water round the Port in a Racing Tub (Config.BOAT_TYPES.racer), up to
-- eight goblins at once. The course is shared/PortGames.lua's (PortGames.REGATTA); this module builds it and runs a
-- race through server/Minigames.lua.
--
--   THE TUBS    real boats (server/Boats.lua: Boats.spawnPortBoat, so the raid's resets leave them alone), driven by
--               their goblin's own client with the same physics as every boat, dressed in the driver's paint and flag.
--               Boost, drift, hop, ramps and tricks all work; nothing sinks; the bow gun and abilities are the raid's.
--   THE START   tubs on a grid behind the line, held still by the server (Boats.hold) until GO. V13.4: throttle down
--               right on GO (not held through the countdown) is a ROCKET START, a short boost ("launch").
--   THE LAP     the server watches every hull (10 times a second, swept between looks, so a fast tub cannot slip
--               past a checkpoint) through 13 checkpoints in order; crossing the line after the last is the finish.
--               THE TEETH has two ways: the narrow channel through the rocks (the shortcut, with a hoop) or round
--               the outside. A lap faster than Config.PLAYGROUND.REGATTA.MIN_TIME is not believed.
--   TROUBLE     barrels to weave through, bumper buoys, a reef with a ramp over it, a high hoop only a jump reaches,
--               and two SPLASH CANNONS that ring the water ahead of the nearest tub and throw everything in the ring.
--   FALLING OUT a goblin out of their tub for REJOIN_AFTER seconds (or pressing RESET) is put back at their last
--               checkpoint, seated, at rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Port = require(script.Parent.Port)
local Minigames = require(script.Parent.Minigames)

local RG = Config.PLAYGROUND.REGATTA
local R = PortGames.REGATTA
local ring, heading = PortGames.ring, PortGames.ringHeading
local rgb = Color3.fromRGB
local v3 = Vector3.new

local Regatta = { id = "regatta", max = RG.MAX, duration = RG.LIMIT }

local HOOP = rgb(255, 96, 170)
local ROCK, ROCK_DARK = Palette.ROCK or rgb(120, 112, 118), rgb(84, 78, 90)
local cannons = {} -- { rock, point, nextAt, pending = { at, point } }

local function now()
	return workspace:GetServerTimeNow()
end

-- The hoops and ramps are BoatSim gates: they must exist before Boats.build sends every client the list (Main calls
-- this between building the sea grid and the boats).
function Regatta.addGates(Kit)
	Kit.setShift(Vector3.zero)
	for _, h in ipairs(R.hoops) do
		local p = ring(h.theta, h.r)
		Kit.hoop(v3(p.X, 5, p.Z), heading(h.theta), h.small and 9 or 12, HOOP, true)
	end
	local hh = R.highHoop
	local hp = ring(hh.theta, hh.r)
	Kit.hoop(v3(hp.X, hh.y, hp.Z), heading(hh.theta), 12, rgb(255, 214, 90), true)
	for _, ramp in ipairs(R.ramps) do
		local q = ring(ramp.theta, ramp.r)
		Kit.kicker(v3(q.X, 0, q.Z), heading(ramp.theta), ramp.width)
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

-- A wall of rock blocks along an arc of the ring, from radius `inner` to `outer`, between two angles.
local function arcWall(kit, from, to, inner, outer, height, jagged)
	local mid = (inner + outer) / 2
	local thick = outer - inner
	local steps = math.max(2, math.ceil((to - from) * math.pi / 180 * mid / 24))
	for i = 0, steps - 1 do
		local a = from + (i + 0.5) * (to - from) / steps
		local p = ring(a, mid)
		local h = height + (jagged and ((i * 37) % 11) or 0)
		local length = (to - from) * math.pi / 180 * mid / steps + 4
		local cf = CFrame.lookAt(v3(p.X, h / 2 - 8, p.Z), v3(p.X, h / 2 - 8, p.Z) + heading(a))
		rock(kit, "TeethRock", v3(thick, h + 8, length), cf, i % 2 == 0 and ROCK or ROCK_DARK)
		if jagged then
			kit.deco(
				"Tooth",
				v3(thick * 0.5, 8 + (i % 3) * 3, 6),
				cf * CFrame.new(0, (h + 8) / 2 + 3, 0) * CFrame.Angles(0, 0, math.rad((i % 2 == 0) and 10 or -10)),
				rgb(236, 230, 214),
				Enum.Material.Slate,
				{ wedge = true }
			)
		end
	end
end

local function sign(kit, position, facing, text, color)
	local cf = CFrame.lookAt(position, position + facing)
	kit.board("RegattaSign", v3(16, 4, 0.5), cf, text, color or Palette.GOLD)
	kit.part(
		"SignPost",
		v3(1, position.Y + 6, 1),
		CFrame.new(position.X, position.Y / 2 - 5, position.Z),
		Palette.WOOD_DARK,
		Enum.Material.Wood
	)
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
	-- The start line: two pylons and a chequered banner between them, high over the water.
	local a, b = R.startLine.a, R.startLine.b
	for _, p in ipairs({ a, b }) do
		kit.part("StartPylon", v3(3, 46, 3), CFrame.new(p.X, 14, p.Z), rgb(246, 244, 238), Enum.Material.SmoothPlastic)
		kit.deco("PylonCap", v3(4, 2, 4), CFrame.new(p.X, 38, p.Z), Palette.GOLD, Enum.Material.Metal)
	end
	local mid = (a + b) / 2
	local across = (b - a)
	local banner = CFrame.lookAt(v3(mid.X, 32, mid.Z), v3(mid.X, 32, mid.Z) + heading(0))
	for i = 0, 11 do
		kit.deco(
			"Chequer",
			v3(across.Magnitude / 12, 3, 0.3),
			banner
				* CFrame.new(-across.Magnitude / 2 + (i + 0.5) * across.Magnitude / 12, (i % 2 == 0) and 1.5 or -1.5, 0),
			(i % 2 == 0) and rgb(28, 26, 32) or rgb(246, 244, 238),
			Enum.Material.Fabric
		)
		kit.deco(
			"Chequer",
			v3(across.Magnitude / 12, 3, 0.3),
			banner
				* CFrame.new(-across.Magnitude / 2 + (i + 0.5) * across.Magnitude / 12, (i % 2 == 0) and -1.5 or 1.5, 0),
			(i % 2 == 0) and rgb(246, 244, 238) or rgb(28, 26, 32),
			Enum.Material.Fabric
		)
	end
	kit.board("StartBanner", v3(40, 5, 0.4), banner * CFrame.new(0, 6, 0), "START · FINISH", Palette.GOLD)
	-- Checkpoint gates: a pair of buoys at the lane's edges, with the checkpoint's number between them.
	for index, cp in ipairs(R.checkpoints) do
		if index < R.finish then
			for _, disc in ipairs(cp.discs) do
				if disc.radius > 20 then
					local inner = ring(cp.theta, (disc.center - PortGames.ISLAND).Magnitude - disc.radius + 6)
					local outer = ring(cp.theta, (disc.center - PortGames.ISLAND).Magnitude + disc.radius - 6)
					buoy(kit, inner, rgb(255, 96, 170))
					buoy(kit, outer, rgb(255, 96, 170))
				end
			end
		end
	end
	-- THE LEAP: a low reef across the lane; the ramp before it throws a tub over it.
	local reef = R.reef
	local reefTheta = (reef.from + reef.to) / 2
	for r = reef.inner, reef.outer - 1, 18 do
		local p = ring(reefTheta, r + 9)
		-- Five studs above the water: too tall for a tub's bow skid to ride over (it is a wall, not a beach).
		local at = v3(p.X, 0, p.Z)
		rock(
			kit,
			"Reef",
			v3(16, 10, 19),
			CFrame.lookAt(at, at + heading(reefTheta)) * CFrame.Angles(0, math.rad(90), 0),
			rgb(200, 150, 120)
		)
	end
	sign(kit, ring(57, 680) + v3(0, 22, 0), -heading(57), "THE LEAP ▲ RAMP", rgb(255, 200, 90))
	-- THE TEETH: a rock mass inside, a wall outside, the channel between.
	local teeth = R.teeth
	arcWall(kit, teeth.from, teeth.to, teeth.inner, teeth.channel[1], 18, false)
	arcWall(kit, teeth.from, teeth.to, teeth.channel[2], teeth.outer, 20, true)
	sign(kit, ring(182, 600) + v3(0, 30, 0), heading(182), "THE TEETH: SHORTCUT ▶ OR GO ROUND", rgb(255, 120, 90))
	-- Barrels to weave through and bumper buoys that bounce.
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
	-- The splash cannons on their rocks, outside the lane.
	for _, c in ipairs(R.cannons) do
		local p = c.rock
		rock(kit, "CannonRock", v3(26, 16, 26), CFrame.new(p.X, 0, p.Z), ROCK_DARK)
		local muzzle = v3(p.X, 11, p.Z)
		local toward = (ring(c.theta, 600) - p)
		kit.deco(
			"SplashCannon",
			v3(9, 3.4, 3.4),
			CFrame.lookAt(muzzle, muzzle + v3(toward.X, 4, toward.Z).Unit) * CFrame.Angles(0, math.rad(90), 0),
			rgb(46, 44, 52),
			Enum.Material.Metal,
			{ cyl = true }
		)
		table.insert(cannons, { theta = c.theta, muzzle = muzzle, nextAt = 0 })
	end
	-- Lane markers: a little float every few degrees on both edges, so the way round reads from a tub.
	for theta = 6, 354, 8 do
		if theta < 184 or theta > 208 then
			for _, r in ipairs({ RG.RADIUS - 64, RG.RADIUS + 64 }) do
				local p = ring(theta, r)
				kit.deco(
					"LaneFloat",
					v3(2, 1.4, 2),
					CFrame.new(p.X, 0.9, p.Z),
					rgb(255, 250, 236),
					Enum.Material.SmoothPlastic,
					{ egg = true }
				)
			end
		end
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

local function spawnTub(entry, cframe, holdUntil)
	local boat = Boats.spawnPortBoat("racer", cframe)
	if holdUntil then
		Boats.hold(boat, holdUntil)
	end
	entry.data.boat = boat
	seat(entry, boat)
	return boat
end

local function removeTub(entry)
	local boat = entry.data.boat
	entry.data.boat = nil
	if boat and boat.state ~= "gone" then
		Boats.remove(boat)
	end
end

-- Back at the last checkpoint passed, seated, at rest.
local function putBack(session, entry, t)
	local index = entry.data.cp - 1
	local cf = index >= 1 and PortGames.regattaRespawn(index) or R.grid[1]
	local boat = entry.data.boat
	if not boat or boat.state ~= "float" or not boat.model.Parent then
		removeTub(entry)
		boat = spawnTub(entry, cf, t + 0.6)
	else
		local spec = Config.BOAT_TYPES.racer
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
			local boat = spawnTub(entry, R.grid[i], session.goAt)
			entry.data.lastPos = boat.hull.Position
			entry.show = { cp = 0, of = R.finish }
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

-- The splash cannons: ring the water ahead of the nearest tub, then throw whatever is in the ring.
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
						local away = flat.Magnitude > 0.5 and flat.Unit or heading(c.theta)
						Boats.shove(boat, away * RG.SPLASH_PUSH + v3(0, RG.SPLASH_LIFT, 0), v3(0, 1.6, 0))
					end
				end
			end
			Net.broadcastNear(point, 900, "PlayFx", { kind = "splash", position = point, radius = RG.SPLASH_RADIUS })
		elseif not c.pending and t >= c.nextAt then
			c.nextAt = t + RG.SPLASH_EVERY
			-- The nearest tub in the race within reach, and where it will be.
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
				local ahead = best.hull.Position + v3(v.X, 0, v.Z) * RG.SPLASH_LEAD
				-- Kept on the lane.
				local fromIsland = v3(ahead.X - PortGames.ISLAND.X, 0, ahead.Z - PortGames.ISLAND.Z)
				local r = math.clamp(fromIsland.Magnitude, RG.RADIUS - 60, RG.RADIUS + 60)
				local point = PortGames.ISLAND + fromIsland.Unit * r + v3(0, 0.5, 0)
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
			-- Seated? A goblin out of their tub is put back after a moment.
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
			-- The next checkpoint, swept from the last look.
			local here = boat.hull.Position
			local last = entry.data.lastPos or here
			local cp = R.checkpoints[entry.data.cp]
			if cp and (here - last).Magnitude < 400 then
				for _, disc in ipairs(cp.discs) do
					if PortGames.crossed(last, here, disc.center, disc.radius) then
						entry.data.cp += 1
						entry.show = { cp = entry.data.cp - 1, of = R.finish }
						session.dirty = true
						if entry.data.cp > R.finish then
							local time = math.floor((t - session.goAt) * 100 + 0.5) / 100
							if time < RG.MIN_TIME then
								warn(string.format("[Regatta] %s's lap of %.1f s was not believed", player.Name, time))
								Minigames.done(session, player, nil, { cp = R.finish, of = R.finish })
							else
								Minigames.done(session, player, time, { cp = R.finish, of = R.finish })
								Net.broadcastNear(
									here,
									900,
									"PlayFx",
									{ kind = "finish", position = here, userId = player.UserId }
								)
							end
							removeTub(entry)
							-- Off the course and back on the dock to watch the others come in.
							if player.Parent and player:GetAttribute("Zone") ~= "raid" then
								Port.arrive(player, Regatta.spot(session, player))
							end
						end
						break
					end
				end
			end
			entry.data.lastPos = here
			if not entry.done then
				local next = R.checkpoints[entry.data.cp]
				local gap = next and (here - next.discs[1].center).Magnitude or 0
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
		removeTub(entry)
	end
end

function Regatta.stop(session)
	for _, entry in pairs(session.entries) do
		removeTub(entry)
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

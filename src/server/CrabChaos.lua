-- CRAB CHAOS (V13.3): a crate of crabs bursts open on the Port's south-west beach and sixteen crabs (and two golden
-- ones) scatter. Run into a crab to catch it (a dash helps); a golden crab is worth three. Crabs wander until a goblin
-- comes close, then flee and zigzag; cornered, one may burrow and pop up somewhere else. 45 seconds; catch them all
-- before the end and everyone in the round gets a bonus. Up to eight at once, all after the same crabs: it is as much
-- a scramble with each other as a hunt (and a round with friends is a team effort for the bonus).
--
-- The crabs are the server's (ten steps a second): each one's place, heading and state, published on the session's fast
-- channel (Minigames.live). Clients draw them with the pets' own animator (the Crab species from shared/PetLook.lua)
-- and smooth between steps: client/PlayHud.lua. Catching is the server's: a goblin's middle within CATCH of a crab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Minigames = require(script.Parent.Minigames)

local K = Config.PLAYGROUND.CRABS
local field = PortGames.CRABS
local rgb = Color3.fromRGB
local v3 = Vector3.new

local CrabChaos = { id = "crabs", max = K.MAX, duration = K.ROUND }

local FLOOR_Y = 6.2

-- Building ------------------------------------------------------------------------------------------------------------------
function CrabChaos.build(kit)
	local c = field.center
	kit.part(
		"CrabSand",
		v3(1, field.fence * 2 + 4, field.fence * 2 + 4),
		CFrame.new(c.X, 5.6, c.Z) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(236, 214, 160),
		Enum.Material.Sand
	).Shape =
		Enum.PartType.Cylinder
	-- A driftwood fence round the beach with gaps to run in by.
	local posts = 36
	for i = 0, posts - 1 do
		if i % 9 ~= 0 then
			local a = i / posts * math.pi * 2
			local at = v3(c.X + math.cos(a) * field.fence, 7, c.Z + math.sin(a) * field.fence)
			kit.part(
				"DriftPost",
				v3(1, 2.4 + (i % 3) * 0.5, 1),
				CFrame.new(at) * CFrame.Angles(0, a, math.rad((i % 2) * 8)),
				rgb(176, 150, 118),
				Enum.Material.Wood
			)
			local b = (i + 0.5) / posts * math.pi * 2
			kit.deco(
				"DriftRail",
				v3(0.5, 0.5, field.fence * 2 * math.pi / posts + 0.6),
				CFrame.lookAt(
					v3(c.X + math.cos(b) * field.fence, 7.4, c.Z + math.sin(b) * field.fence),
					v3(c.X + math.cos(b) * field.fence, 7.4, c.Z + math.sin(b) * field.fence)
						+ v3(-math.sin(b), 0, math.cos(b))
				),
				rgb(176, 150, 118),
				Enum.Material.Wood
			)
		end
	end
	-- The crate in the middle, its lid already off, and a few nets and buckets.
	kit.part(
		"CrabCrate",
		v3(6, 4, 6),
		CFrame.new(c.X, 8, c.Z) * CFrame.Angles(0, math.rad(20), 0),
		Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	kit.deco(
		"CrateLid",
		v3(6.4, 0.6, 6.4),
		CFrame.new(c.X + 4, 6.6, c.Z + 2) * CFrame.Angles(math.rad(12), math.rad(50), 0),
		Palette.WOOD,
		Enum.Material.WoodPlanks
	)
	for k = 0, 2 do
		local a = k * 2.1 + 0.4
		kit.deco(
			"Bucket",
			v3(1.6, 2, 1.6),
			CFrame.new(c.X + math.cos(a) * (field.fence + 3), 7, c.Z + math.sin(a) * (field.fence + 3)),
			rgb(90, 140, 200),
			Enum.Material.Metal,
			{ cyl = false }
		)
	end
	kit.board(
		"CrabSign",
		v3(14, 4, 0.5),
		CFrame.lookAt(PortGames.VENUES.crabs.sign, PortGames.VENUES.crabs.sign + v3(0.7, 0, -0.7)),
		"CRAB CHAOS",
		rgb(255, 130, 110)
	)
end

-- The crabs ------------------------------------------------------------------------------------------------------------------
local function inside(x, z, margin)
	local dx, dz = x - field.center.X, z - field.center.Z
	return dx * dx + dz * dz <= (field.radius - (margin or 0)) ^ 2
end

local function clampInside(x, z)
	local dx, dz = x - field.center.X, z - field.center.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local r = field.radius - 1
	if d > r then
		return field.center.X + dx / d * r, field.center.Z + dz / d * r
	end
	return x, z
end

local function randomSpot(random, near, minD, maxD)
	for _ = 1, 12 do
		local a = random:NextNumber(0, math.pi * 2)
		local d = random:NextNumber(minD, maxD)
		local x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
		if inside(x, z, 2) then
			return x, z
		end
	end
	return clampInside(near.X, near.Z)
end

function CrabChaos.prepare(session)
	session.data.random = Random.new(math.floor(workspace:GetServerTimeNow() * 1000) % 2147483647)
	session.data.crabs = {}
	local count = #session.order
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry then
			local a = (i - 1) / math.max(1, count) * math.pi * 2
			local at = field.center + v3(math.cos(a) * 14, 3.4, math.sin(a) * 14)
			entry.score = 0
			entry.data.crabs = 0
			Minigames.place(player, CFrame.lookAt(at, v3(field.center.X, at.Y, field.center.Z)), true)
		end
	end
end

function CrabChaos.go(session, t)
	session.endsAt = t + K.ROUND
	session.data.nextStep = t
	session.data.nextLive = t
	local random = session.data.random
	for player in pairs(session.entries) do
		Minigames.release(player)
	end
	for i = 1, K.COUNT + K.GOLDEN do
		local a = random:NextNumber(0, math.pi * 2)
		table.insert(session.data.crabs, {
			id = i,
			golden = i > K.COUNT,
			x = field.center.X + math.cos(a) * 2,
			z = field.center.Z + math.sin(a) * 2,
			heading = a,
			state = "scatter",
			untilAt = t + random:NextNumber(0.6, 1.2),
			burrowReadyAt = t + 2,
		})
	end
	Net.broadcastNear(field.center, 400, "PlayFx", { kind = "crate", position = field.center + v3(0, 3, 0) })
end

local function catch(session, crab, player, t)
	crab.state = "caught"
	crab.caughtAt = t
	local points = crab.golden and K.GOLDEN_POINTS or 1
	local entry = session.entries[player]
	entry.data.crabs = (entry.data.crabs or 0) + 1
	Minigames.points(session, player, points, { crabs = entry.data.crabs })
	Net.broadcastNear(v3(crab.x, FLOOR_Y, crab.z), 400, "PlayFx", {
		kind = "crabcaught",
		position = v3(crab.x, FLOOR_Y + 1, crab.z),
		golden = crab.golden,
		userId = player.UserId,
		points = points,
	})
end

local function step(session, dt, t)
	local random = session.data.random
	-- Where the goblins are (flat).
	local goblins = {}
	for player, entry in pairs(session.entries) do
		if not entry.left then
			local root = Util.aliveRoot(player)
			if root then
				table.insert(
					goblins,
					{ player = player, x = root.Position.X, z = root.Position.Z, y = root.Position.Y }
				)
			end
		end
	end
	local left = 0
	for _, crab in ipairs(session.data.crabs) do
		if crab.state ~= "caught" then
			left += 1
			-- Its nearest goblin.
			local near, nearD
			for _, g in ipairs(goblins) do
				local d = math.sqrt((g.x - crab.x) ^ 2 + (g.z - crab.z) ^ 2)
				if not nearD or d < nearD then
					near, nearD = g, d
				end
			end
			if crab.state == "burrowed" then
				if t >= crab.untilAt then
					local x, z = randomSpot(random, v3(crab.x, 0, crab.z), 12, 20)
					crab.x, crab.z = x, z
					crab.state = "wander"
					crab.popAt = t
				end
			else
				-- Caught? (Not while it is still scattering out of the crate.)
				if near and nearD <= K.CATCH and math.abs(near.y - FLOOR_Y - 3) < 6 and crab.state ~= "scatter" then
					catch(session, crab, near.player, t)
					left -= 1
				else
					local speed, direction
					if crab.state == "scatter" then
						speed = K.FLEE * 1.1
						direction = crab.heading
						if t >= crab.untilAt then
							crab.state = "wander"
						end
					elseif near and nearD <= K.SCARE then
						-- Cornered and close: maybe dig in.
						if nearD <= K.BURROW_NEAR and t >= crab.burrowReadyAt then
							crab.burrowReadyAt = t + 0.6
							if random:NextNumber() < K.BURROW_CHANCE * (crab.golden and 1.6 or 1) then
								crab.state = "burrowed"
								crab.untilAt = t + K.BURROW_TIME
								crab.burrowReadyAt = t + K.BURROW_REST
								Net.broadcastNear(
									v3(crab.x, FLOOR_Y, crab.z),
									300,
									"PlayFx",
									{ kind = "burrow", position = v3(crab.x, FLOOR_Y, crab.z) }
								)
							end
						end
						if crab.state ~= "burrowed" then
							crab.state = "flee"
							local away = math.atan2(crab.z - near.z, crab.x - near.x)
							if t >= (crab.jinkAt or 0) then
								crab.jinkAt = t + K.JINK
								crab.jink = random:NextNumber(-0.9, 0.9)
							end
							direction = away + (crab.jink or 0)
							speed = crab.golden and K.GOLD_FLEE or K.FLEE
						end
					else
						crab.state = "wander"
						if not crab.tx or math.sqrt((crab.tx - crab.x) ^ 2 + (crab.tz - crab.z) ^ 2) < 1.5 then
							crab.tx, crab.tz = randomSpot(random, v3(crab.x, 0, crab.z), 6, 14)
						end
						direction = math.atan2(crab.tz - crab.z, crab.tx - crab.x)
						speed = K.WANDER
					end
					if direction then
						local nx = crab.x + math.cos(direction) * speed * dt
						local nz = crab.z + math.sin(direction) * speed * dt
						if not inside(nx, nz, 1) then
							-- Along the fence instead of through it.
							local toCenter = math.atan2(field.center.Z - crab.z, field.center.X - crab.x)
							local along = toCenter
								+ math.pi / 2 * ((direction - toCenter) % (2 * math.pi) < math.pi and -1 or 1)
							nx = crab.x + math.cos(along) * speed * dt
							nz = crab.z + math.sin(along) * speed * dt
							nx, nz = clampInside(nx, nz)
							direction = along
						end
						crab.x, crab.z = nx, nz
						crab.heading = direction
					end
				end
			end
		end
	end
	if left == 0 and session.state == "running" then
		-- Every crab caught: everyone in the round shares the bonus.
		for player, entry in pairs(session.entries) do
			if not entry.left then
				Minigames.points(session, player, K.ALL_BONUS, entry.show)
			end
		end
		Net.broadcastNear(field.center, 500, "PlayFx", { kind = "allcrabs", position = field.center + v3(0, 6, 0) })
		Minigames.finish(session, "allcaught")
	end
end

local function publishLive(session, t)
	local rows = {}
	for _, crab in ipairs(session.data.crabs) do
		if crab.state ~= "caught" or t - (crab.caughtAt or 0) < 0.5 then
			table.insert(rows, {
				crab.id,
				math.floor(crab.x * 10 + 0.5) / 10,
				math.floor(crab.z * 10 + 0.5) / 10,
				math.floor((crab.heading or 0) * 100 + 0.5) / 100,
				string.sub(crab.state, 1, 1),
				crab.golden and 1 or 0,
			})
		end
	end
	Minigames.live(session, { t = t, c = rows })
end

function CrabChaos.tick(session, _dt, t)
	if t >= session.data.nextStep then
		local dt = 0.1 + math.max(0, t - session.data.nextStep)
		session.data.nextStep = t + 0.1
		step(session, math.min(dt, 0.25), t)
	end
	if session.state == "running" and t >= session.data.nextLive then
		session.data.nextLive = t + 0.12
		publishLive(session, t)
	end
end

function CrabChaos.drop(_session, player)
	Minigames.release(player)
end

function CrabChaos.stop(session)
	for player in pairs(session.entries) do
		Minigames.release(player)
	end
end

function CrabChaos.public(_session)
	return { floor = FLOOR_Y }
end

return CrabChaos

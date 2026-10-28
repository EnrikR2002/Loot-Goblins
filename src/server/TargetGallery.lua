-- THE TARGET SHIP GALLERY (V13.3): four shore cannons on a pier off the Port's north-east corner, and a cut-out pirate
-- fleet sailing to and fro on the water beyond: a slow galleon (1), two sloops (2), a darting skiff (4), a kraken's
-- tentacle that bursts up somewhere new every few seconds (6) and, now and then, the Goblin King's barge racing across
-- far out (10). Aim with the camera, fire (click, Space, a controller's R2 or A, the FIRE button on a touch screen);
-- a hit ship keels over with a splash and rights itself a few seconds later. 45 seconds; up to four at once.
--
-- The ships' courses are functions of the server's clock (shared/PortGames.lua: PortGames.GALLERY), drawn by every
-- client; the server flies every cannonball with the island cannons' own speed and gravity (PortGames.cannonVelocity,
-- PortGames.shotHit), knocks the ship it meets down (for everyone: the session's public `down`), and pays when the
-- ball arrives. The client sends only where it aims.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Net = require(script.Parent.Net)
local Minigames = require(script.Parent.Minigames)

local A = Config.PLAYGROUND.GALLERY
local gallery = PortGames.GALLERY
local rgb = Color3.fromRGB
local v3 = Vector3.new

local TargetGallery = { id = "gallery", max = A.STATIONS, duration = A.ROUND }

local barrels = {} -- station -> the barrel part (turned to the aim, for everyone)

local function now()
	return workspace:GetServerTimeNow()
end

-- Building ------------------------------------------------------------------------------------------------------------------
function TargetGallery.build(kit)
	local deck = gallery.deck
	local facing, across = gallery.facing, gallery.across
	local frame = CFrame.lookAt(deck, deck + facing)
	-- The pier from the shore, and the gallery deck at its end.
	local shore = PortGames.world(116, 6, -82)
	local mid = (shore + deck) / 2
	kit.part(
		"GalleryWalk",
		v3(8, 1.2, (deck - shore).Magnitude),
		CFrame.lookAt(v3(mid.X, 6.8, mid.Z), v3(deck.X, 6.8, deck.Z)),
		Palette.WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	kit.part("GalleryDeck", v3(48, 1.4, 14), frame * CFrame.new(0, -0.7, 0), Palette.WOOD, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -23, -12, 0, 12, 23 }) do
		for _, z in ipairs({ -6, 6 }) do
			kit.deco(
				"GalleryPost",
				v3(1.4, 16, 1.4),
				frame * CFrame.new(x, -8, z),
				Palette.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	kit.part("GalleryRail", v3(48, 2.4, 0.6), frame * CFrame.new(0, 1.2, -7), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.board(
		"GallerySign",
		v3(18, 4, 0.5),
		frame * CFrame.new(0, 12, 6.5) * CFrame.Angles(0, math.rad(180), 0),
		"TARGET SHIP GALLERY",
		rgb(255, 140, 100)
	)
	for _, x in ipairs({ -22, 22 }) do
		kit.part("SignPost", v3(1, 12, 1), frame * CFrame.new(x, 6, 6.5), Palette.WOOD_DARK, Enum.Material.Wood)
	end
	-- The four cannons.
	for i, station in ipairs(gallery.stations) do
		local base = station.cframe
		kit.part("GalleryStand", v3(4, 1.6, 5), base * CFrame.new(0, 0.2, 0), Palette.WOOD_DARK, Enum.Material.Wood)
		local barrel = kit.deco(
			"GalleryCannon",
			v3(6.4, 2.4, 2.4),
			base * CFrame.new(0, 2.2, -1) * CFrame.Angles(0, math.rad(90), 0),
			rgb(50, 48, 56),
			Enum.Material.Metal,
			{ cyl = true }
		)
		barrels[i] = { part = barrel, base = base }
		kit.board(
			"StationNumber",
			v3(2.4, 1.6, 0.2),
			base * CFrame.new(0, 1, 2.6) * CFrame.Angles(0, math.rad(180), 0),
			tostring(i),
			Palette.GOLD
		)
		for k = 0, 2 do
			kit.deco(
				"CannonBall",
				v3(1.4, 1.4, 1.4),
				base * CFrame.new(2.8, 1.6 + (k == 2 and 1.1 or 0), 1 + (k == 1 and 1.2 or 0)),
				rgb(40, 38, 46),
				Enum.Material.Metal,
				{ ball = true }
			)
		end
	end
	-- Lane buoys out on the water, so the ranges read.
	for _, dist in ipairs({ 110, 150, 205, 255 }) do
		for _, side in ipairs({ -95, 95 }) do
			local at = deck + facing * dist + across * side
			kit.deco(
				"RangeBuoy",
				v3(2.4, 3, 2.4),
				CFrame.new(at.X, 1.2, at.Z),
				rgb(255, 140, 100),
				Enum.Material.SmoothPlastic,
				{ egg = true }
			)
		end
	end
	local _ = across
end

-- Playing --------------------------------------------------------------------------------------------------------------------
local function aimBarrel(station, direction)
	local record = barrels[station]
	if not record or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		return
	end
	local at = (record.base * CFrame.new(0, 2.2, -1)).Position
	local d = direction.Unit
	if d:Dot(gallery.facing) < 0.1 then
		return
	end
	record.part.CFrame = CFrame.lookAt(at, at + d) * CFrame.Angles(0, math.rad(90), 0)
end

function TargetGallery.prepare(session)
	session.data.down = {}
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry then
			entry.data.station = i
			entry.data.readyAt = 0
			entry.data.hits = 0
			entry.score = 0
			local station = gallery.stations[i]
			Minigames.place(player, CFrame.lookAt(station.seat, station.seat + gallery.facing), true)
		end
	end
end

function TargetGallery.go(session, t)
	session.endsAt = t + A.ROUND
end

function TargetGallery.tick(_session, _dt, _t) end

function TargetGallery.input(session, player, action, aim)
	local entry = session.entries[player]
	if not entry then
		return
	end
	local station = gallery.stations[entry.data.station]
	if not station then
		return
	end
	if action == "aim" and typeof(aim) == "Vector3" then
		aimBarrel(entry.data.station, aim)
		return
	end
	if action ~= "fire" or typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Magnitude > 1e5 then
		return
	end
	local t = now()
	if t < entry.data.readyAt then
		return
	end
	local from = station.muzzle
	local offset = aim - from
	if offset.Magnitude > 700 or offset.Magnitude < 5 or v3(offset.X, 0, offset.Z).Unit:Dot(gallery.facing) < 0.15 then
		return
	end
	entry.data.readyAt = t + A.RELOAD
	local velocity = PortGames.cannonVelocity(from, aim)
	aimBarrel(entry.data.station, velocity)
	local down = session.data.down
	local index, hitAt, at = PortGames.shotHit(
		gallery,
		from,
		velocity,
		A.GRAVITY,
		t,
		A.BALL,
		gallery.water,
		5,
		function(i, when)
			return down[i] ~= nil and when < down[i]
		end
	)
	local target = index and gallery.targets[index]
	if target then
		-- It is down from the moment the ball arrives (so a second ball in the air at it now finds nothing).
		down[index] = hitAt + A.DOWN_TIME
		session.data.downStart = session.data.downStart or {}
		session.data.downStart[index] = hitAt
		session.dirty = true
	end
	Net.broadcastNear(from, 900, "PlayFx", {
		kind = "cannonshot",
		from = from,
		velocity = velocity,
		gravity = A.GRAVITY,
		t0 = t,
		landAt = hitAt,
		at = at,
		hit = index,
		points = target and target.points or 0,
		userId = player.UserId,
	})
	-- When the ball lands: points (and the streak's bonus, V13.4), or the streak ends.
	task.delay(math.max(0, hitAt - t), function()
		if session.state ~= "running" or entry.left then
			return
		end
		local points
		entry.data.streak, points = PortGames.rangeShot(entry.data.streak, target ~= nil, target and target.points or 0)
		if target then
			entry.data.hits += 1
			Minigames.points(session, player, points, { hits = entry.data.hits })
			if entry.data.streak >= Config.PLAYGROUND.STREAK.FROM then
				Net.send(player, "PlayFx", { kind = "streak", game = "gallery", n = entry.data.streak })
			end
		end
	end)
end

function TargetGallery.drop(_session, player)
	Minigames.release(player)
end

function TargetGallery.stop(session)
	for player in pairs(session.entries) do
		Minigames.release(player)
	end
end

function TargetGallery.spot(_session, player)
	local i = (player.UserId % 4) + 1
	local at = PortGames.world(118 + i * 2, 9.5, -84)
	return CFrame.new(at)
end

-- Which ships are keeled over, and since when (every client draws the same).
function TargetGallery.public(session)
	local down = {}
	for index, untilAt in pairs(session.data.down or {}) do
		down[tostring(index)] =
			{ session.data.downStart and session.data.downStart[index] or untilAt - A.DOWN_TIME, untilAt }
	end
	return { down = down }
end

return TargetGallery

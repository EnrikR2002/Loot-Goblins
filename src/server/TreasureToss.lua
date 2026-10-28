-- TREASURE TOSS (V13.3): a 40-second round at a booth on the Port's south-east lawn. Up to six goblins stand at the
-- throwing line with a chest over their heads (the same carry as a raid's treasure) and throw it, the way they look
-- (click or Q; a controller's R2 or L1; the THROW button on a touch screen), at targets that move:
--   three BARRELS sliding on a rail (1), a ROWBOAT bobbing across a pond (2), a basket on the end of the PARROT'S
--   swinging PERCH (4), and the GOBLIN KING, whose mouth opens now and then (8: it only eats when open).
-- A basket only counts a chest coming DOWN into it (lob it). Everyone throws at the same targets at once; the most
-- points wins.
--
-- The targets are functions of the server's clock (shared/PortGames.lua), so every client draws them where they are
-- and the server judges every throw from them: the client sends only a direction (held inside the booth's limits), the
-- server flies the chest (PortGames.shotHit) and pays when it lands. Nothing is sent per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Minigames = require(script.Parent.Minigames)

local T = Config.PLAYGROUND.TOSS
local toss = PortGames.TOSS
local rgb = Color3.fromRGB
local v3 = Vector3.new

local TreasureToss = { id = "toss", max = T.MAX, duration = T.ROUND }

local function now()
	return workspace:GetServerTimeNow()
end

-- Building ------------------------------------------------------------------------------------------------------------------
function TreasureToss.build(kit)
	local function rel(x, y, z)
		return PortGames.world(x, y, z)
	end
	-- The throwing line: a raised wooden stage with six marked spots.
	kit.part("TossStage", v3(12, 1.4, 42), CFrame.new(rel(78, 5.4, 118)), Palette.WOOD_LIGHT, Enum.Material.WoodPlanks)
	for i, spot in ipairs(toss.spots) do
		kit.deco(
			"TossSpot",
			v3(0.2, 3.6, 3.6),
			CFrame.new(spot.Position.X, 6.15, spot.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(255, 214, 90),
			Enum.Material.SmoothPlastic,
			{ cyl = true, shadow = false }
		)
		kit.board(
			"SpotNumber",
			v3(2, 1.4, 0.2),
			CFrame.lookAt(
				v3(spot.Position.X - 5.4, 7.2, spot.Position.Z),
				v3(spot.Position.X - 10, 7.2, spot.Position.Z)
			),
			tostring(i),
			Palette.GOLD
		)
	end
	kit.part("TossRail", v3(0.6, 3, 42), CFrame.new(rel(84.2, 7.1, 118)), Palette.WOOD_DARK, Enum.Material.Wood)
	-- A heap of chests behind the line.
	for k = 0, 5 do
		kit.deco(
			"ChestHeap",
			v3(2.6, 1.8, 1.8),
			CFrame.new(rel(70 - (k % 2) * 3, 6.8 + (k // 2) * 1.6, 106 + k * 2)) * CFrame.Angles(0, math.rad(k * 23), 0),
			Palette.WOOD,
			Enum.Material.WoodPlanks
		)
	end
	kit.board(
		"TossSign",
		v3(16, 4, 0.5),
		CFrame.lookAt(PortGames.VENUES.toss.sign, PortGames.VENUES.toss.sign + v3(-1, 0, 0)),
		"TREASURE TOSS",
		rgb(255, 214, 90)
	)
	-- The barrels' rail, the rowboat's pond, the parrot's post, the King's throne: the moving parts are each client's.
	kit.deco("BarrelRail", v3(1, 0.6, 40), CFrame.new(rel(106, 6.3, 118)), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.deco(
		"Pond",
		v3(10, 0.5, 52),
		CFrame.new(rel(122, 6.1, 118)),
		rgb(70, 170, 210),
		Enum.Material.Glass,
		{ transparency = 0.25 }
	)
	kit.part("PerchPost", v3(1.4, 16, 1.4), CFrame.new(toss.perch + v3(0, 8, 0)), Palette.WOOD_DARK, Enum.Material.Wood)
	kit.deco("PerchCap", v3(2.4, 1.2, 2.4), CFrame.new(toss.perch + v3(0, 16.2, 0)), Palette.GOLD, Enum.Material.Metal)
	-- The Goblin King: a great head on a stone throne, facing the line.
	local K = toss.king
	local face = CFrame.lookAt(K + v3(0, 10, 0), K + v3(-20, 10, 0))
	kit.part("Throne", v3(16, 6, 12), CFrame.new(K + v3(2, 3, 0)), Palette.STONE, Enum.Material.Cobblestone)
	kit.deco("KingHead", v3(13, 13, 11), face, rgb(116, 170, 70), Enum.Material.SmoothPlastic, { egg = true })
	for _, side in ipairs({ -1, 1 }) do
		kit.deco(
			"KingEar",
			v3(1.6, 4, 9),
			face * CFrame.new(side * 6.4, 2.4, 1) * CFrame.Angles(0, math.rad(side * 25), side * math.rad(-50)),
			rgb(116, 170, 70),
			Enum.Material.SmoothPlastic,
			{ wedge = true }
		)
		kit.deco(
			"KingEye",
			v3(2.4, 2.4, 1.2),
			face * CFrame.new(side * 2.6, 2.6, -5.2),
			rgb(255, 250, 236),
			Enum.Material.SmoothPlastic,
			{ egg = true }
		)
		kit.deco(
			"KingPupil",
			v3(1, 1, 0.6),
			face * CFrame.new(side * 2.6, 2.6, -5.8),
			rgb(30, 26, 30),
			Enum.Material.SmoothPlastic,
			{ egg = true }
		)
	end
	kit.deco(
		"KingNose",
		v3(3, 3, 4),
		face * CFrame.new(0, 0.6, -6.2),
		rgb(104, 156, 62),
		Enum.Material.SmoothPlastic,
		{ egg = true }
	)
	kit.deco(
		"KingCrown",
		v3(10, 4, 10),
		face * CFrame.new(0, 7.6, 0),
		Palette.GOLD,
		Enum.Material.Metal,
		{ cyl = false }
	)
	for k = 0, 4 do
		kit.deco(
			"CrownPoint",
			v3(1.6, 3, 1.6),
			face * CFrame.new(-4 + k * 2, 10.6, -4),
			Palette.GOLD,
			Enum.Material.Metal,
			{ wedge = true }
		)
	end
	kit.board("KingScore", v3(8, 2, 0.3), CFrame.lookAt(K + v3(-7, 2.6, 0), K + v3(-20, 2.6, 0)), "8", Palette.GOLD)
end

-- Playing -------------------------------------------------------------------------------------------------------------------
function TreasureToss.prepare(session)
	for i, player in ipairs(session.order) do
		local entry = session.entries[player]
		if entry then
			entry.data.spot = toss.spots[((i - 1) % #toss.spots) + 1]
			entry.data.readyAt = 0
			entry.data.hits = 0
			entry.score = 0
			Minigames.place(player, entry.data.spot, false)
			player:SetAttribute("TossChest", true)
		end
	end
end

function TreasureToss.go(session, t)
	session.endsAt = t + T.ROUND
end

function TreasureToss.tick(_session, _dt, _t) end

function TreasureToss.input(session, player, action, aim)
	if action ~= "toss" then
		return
	end
	local entry = session.entries[player]
	local t = now()
	if not entry or t < (entry.data.readyAt or 0) then
		return
	end
	local root = Util.aliveRoot(player)
	if not root or (root.Position - entry.data.spot.Position).Magnitude > 9 then
		Net.toast(player, "Throw from your spot on the line!")
		return
	end
	local direction = PortGames.tossDirection(aim)
	if not direction then
		return
	end
	entry.data.readyAt = t + T.RELOAD
	local from = root.Position + v3(0, 2.6, 0)
	local velocity = direction * T.SPEED
	local index, hitAt, at = PortGames.shotHit(toss, from, velocity, T.GRAVITY, t, T.CHEST, toss.ground, 3)
	local target = index and toss.targets[index]
	Net.broadcastNear(from, 500, "PlayFx", {
		kind = "toss",
		from = from,
		velocity = velocity,
		gravity = T.GRAVITY,
		t0 = t,
		landAt = hitAt,
		at = at,
		hit = index,
		points = target and target.points or 0,
		userId = player.UserId,
	})
	if target then
		local points = target.points
		task.delay(math.max(0, hitAt - t), function()
			if session.state == "running" and not entry.left then
				entry.data.hits += 1
				Minigames.points(session, player, points, { hits = entry.data.hits })
			end
		end)
	end
end

local function clear(player)
	if player.Parent then
		player:SetAttribute("TossChest", nil)
	end
end

function TreasureToss.drop(_session, player)
	clear(player)
end

function TreasureToss.stop(session)
	for player in pairs(session.entries) do
		clear(player)
	end
end

return TreasureToss

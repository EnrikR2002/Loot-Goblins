-- The Pet Derby's racers and Crab Chaos's crabs on this client (V13.3), drawn with the pets' own animator
-- (client/PetCrowd.lua, shared/PetLook.lua) from what the server publishes: who races where (the session's `extra`)
-- and where everyone is (its fast `.live` channel, about ten times a second, smoothed in between).
--
--   THE DERBY   every pet hops each hurdle; one that missed its cheer tumbles after it; a clean one zooms off in a
--               sparkle. Your own pet has a gold ring under it and a timing cue: NOW! is the moment to CHEER (Space,
--               E, a click, A on a controller, or CHEER on a touch screen). Cheering with no hurdle near is a stumble.
--               V13.4: a TIMING BAR (red too soon, green clean, gold perfect) under the cue; a perfect cheer makes the
--               pet somersault the hurdle; a pet on a streak of three is ON FIRE (flames, a 🔥 on its name).
--   THE CRABS   scuttling, fleeing, burrowing, popping up; golden ones in gold. A catch is a poof and a number.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local PetCrowd = require(script.Parent.PetCrowd)

local PlayCritters = {}

local player = Players.LocalPlayer
local DG = Config.PLAYGROUND.DERBY
local DRAW = Config.PLAYGROUND.VENUE_DRAW
local track = PortGames.DERBY
local C = Ui.C
local v3 = Vector3.new

local ctx
local derbyCrowd, crabCrowd
local tags = {} -- racer id -> { anchor, gui, label }
local myRing
local cheerGui, cheerCue
local timingBar, timingMark -- V13.4: the hurdle timing bar (early red, clean green, perfect gold)
local cheering = false
local derbyDrawn = {} -- racer id -> { p, state }
local flips = {} -- V13.4: racer id -> when a perfect cheer was heard (the pet flips over that hurdle)
local BAR_SPAN = DG.TOO_EARLY + 0.6 -- seconds before a hurdle that the bar starts to show
local function barAt(tth)
	return math.clamp((BAR_SPAN - tth) / (BAR_SPAN + DG.LATE), 0, 1)
end
local crabs = {} -- crab id -> { x, z, h, tx, tz, th, s, g, seen }

local function sessionOf(game)
	for id, session in pairs(ctx.sessions or {}) do
		if
			session.game == game
			and (session.state == "countdown" or session.state == "running" or session.state == "results")
		then
			return session, id
		end
	end
	return nil
end

-- The Derby ------------------------------------------------------------------------------------------------------------------
local function tagFor(id, text, mine)
	local tag = tags[id]
	if not tag then
		local anchor = Ui.make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = v3(0.2, 0.2, 0.2),
		}, derbyCrowd.folder)
		local gui = Ui.make(
			"BillboardGui",
			{ Adornee = anchor, Size = UDim2.fromOffset(150, 30), LightInfluence = 0, MaxDistance = 160 },
			anchor
		)
		local label = Ui.label(gui, {
			Size = UDim2.fromScale(1, 1),
			Text = text,
			Font = Ui.TITLE,
			TextScaled = true,
			TextColor3 = mine and C.goldPale or C.white,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.stroke(label, C.night, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		tag = { anchor = anchor, label = label }
		tags[id] = tag
	end
	return tag
end

local function clearDerby()
	derbyCrowd:clear()
	for id, tag in pairs(tags) do
		tag.anchor:Destroy()
		tags[id] = nil
	end
	table.clear(derbyDrawn)
	table.clear(flips)
	if myRing then
		myRing.Transparency = 1
	end
end

-- My racer's id and its next hurdle, for the cue and the panel.
local function myRacer(session)
	local extra = session and session.extra
	for _, racer in ipairs(extra and extra.racers or {}) do
		if racer.u == player.UserId then
			return racer
		end
	end
	return nil
end

local function liveRow(id, live)
	for _, row in ipairs(live and live.r or {}) do
		if row.i == id then
			return row
		end
	end
	return nil
end

local function extrapolate(row, live, t)
	if not row then
		return 0
	end
	local p = row.p + (row.v or 0) * math.max(0, t - (live.t or t)) / track.length
	return math.min(1, p)
end

function PlayCritters.derbyLine(session, t)
	local racer = myRacer(session)
	if not racer then
		return nil
	end
	local live = ctx.lives[session.id]
	local row = liveRow(racer.i, live)
	if not row then
		return "CHEER (SPACE) as your pet reaches a hurdle!"
	end
	local p = extrapolate(row, live, t)
	local passed = 0
	for _, h in ipairs(track.hurdles) do
		if p >= h then
			passed += 1
		end
	end
	if row.s == "done" then
		return "Over the line!"
	end
	return string.format(
		"HURDLE %d/%d  ·  %s",
		math.min(passed + 1, #track.hurdles),
		#track.hurdles,
		row.s == "zoom" and "ZOOM!" or (row.s == "trip" and "TUMBLE!" or "CHEER at the hurdles")
	)
end

local function drawDerby(t)
	local session, id = sessionOf("derby")
	local camera = workspace.CurrentCamera
	local close = camera and (camera.CFrame.Position - track.center).Magnitude < DRAW
	if not session or not close or not session.extra or not session.extra.racers then
		if next(derbyCrowd.pets) then
			clearDerby()
		end
		return nil
	end
	local live = ctx.lives[id]
	local seen = {}
	local mine = myRacer(session)
	for _, racer in ipairs(session.extra.racers) do
		seen[racer.i] = true
		local pet = derbyCrowd:add(racer.i, racer.pet, racer.skin, racer.hat)
		if pet then
			derbyCrowd:show(pet, true)
			local row = liveRow(racer.i, live)
			local p = session.state == "countdown" and 0 or extrapolate(row, live, t)
			local position, heading = PortGames.derbyPoint(p, racer.lane or 1)
			local state = row and row.s or "run"
			local speed = row and row.v or 0
			local lift = 0
			local hop -- how far through a hop it is (0..1), over the hurdle it is crossing
			local extra
			-- A hop over every hurdle.
			for _, h in ipairs(track.hurdles) do
				local d = (p - h) * track.length
				if d > -2.2 and d < 2.2 then
					lift = math.max(lift, math.cos(d / 2.2 * math.pi / 2) * 1.8)
					hop = (d + 2.2) / 4.4
				end
			end
			local since = t - (row and row.a or t)
			local flipAge = flips[racer.i] and t - flips[racer.i]
			if flipAge and flipAge < 1.6 and hop then
				-- A perfect cheer: a somersault over the hurdle.
				lift += 0.8
				extra = CFrame.new(0, 0.6, 0) * CFrame.Angles(-math.rad(hop * 360), 0, 0) * CFrame.new(0, -0.6, 0)
			elseif state == "trip" and since < 0.8 then
				extra = CFrame.new(0, 0.6, 0)
					* CFrame.Angles(-math.rad(since / 0.8 * 360), 0, 0)
					* CFrame.new(0, -0.6, 0)
			elseif state == "stumble" then
				extra = CFrame.Angles(0, 0, math.rad(14 * math.sin(since * 30)))
			elseif state == "sniff" then
				extra = CFrame.Angles(math.rad(18), 0, 0)
			elseif state == "zoom" and math.random() < 0.3 then
				local onFire = (row and row.k or 0) >= DG.STREAK
				Effects.burst(
					position + v3(0, 1, 0),
					onFire and Color3.fromRGB(255, 120, 40) or C.goldPale,
					onFire and 5 or 2,
					onFire and 9 or 6
				)
			end
			local origin = derbyCrowd:place(
				pet,
				position + v3(0, 0.1, 0),
				PetCrowd.yawOf(heading),
				speed,
				{ lift = lift, extra = extra, grounded = false }
			)
			local tag =
				tagFor(racer.i, racer.n .. (racer.loan and " (a loaned crab)" or ""), mine and mine.i == racer.i)
			tag.anchor.CFrame = CFrame.new(origin.Position + v3(0, 3.6, 0))
			local streak = row and row.k or 0
			tag.label.Text = (streak >= DG.STREAK and "🔥 " or "")
				.. racer.n
				.. (racer.loan and " (a loaned crab)" or "")
			if mine and mine.i == racer.i and myRing then
				myRing.Transparency = 0.25
				myRing.CFrame = CFrame.new(position.X, position.Y + 0.15, position.Z)
					* CFrame.Angles(0, 0, math.rad(90))
			end
			-- A tumble's dust and a finish's cheer, once each.
			local before = derbyDrawn[racer.i]
			if before and before.state ~= state then
				if state == "trip" then
					Effects.burst(position + v3(0, 0.6, 0), Color3.fromRGB(190, 150, 100), 10, 10)
				elseif state == "done" then
					Effects.firework(position + v3(0, 6, 0), Color3.fromRGB(255, 160, 200))
				end
			end
			derbyDrawn[racer.i] = { state = state }
		end
	end
	for _, key in ipairs(derbyCrowd:keys()) do
		if not seen[key] then
			derbyCrowd:remove(key)
			if tags[key] then
				tags[key].anchor:Destroy()
				tags[key] = nil
			end
		end
	end
	return mine, live, session
end

-- The cue for my own pet: how soon its next hurdle is, and NOW! in the window.
local function updateCue(mine, live, session, t)
	local running = session and session.state == "running" and mine ~= nil
	cheerGui.Enabled = running
	if running ~= cheering then
		cheering = running
		if running then
			ContextActionService:BindActionAtPriority("LootGoblinsCheer", function(_, state)
				if state == Enum.UserInputState.Begin then
					ctx.remote:FireServer("cheer")
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, true, 3100, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1)
			ContextActionService:SetTitle("LootGoblinsCheer", "CHEER!")
			ContextActionService:SetPosition("LootGoblinsCheer", UDim2.new(1, -150, 1, -150))
		else
			ContextActionService:UnbindAction("LootGoblinsCheer")
		end
	end
	if not running then
		return
	end
	local row = liveRow(mine.i, live)
	local p = extrapolate(row, live, t)
	local nextH
	for _, h in ipairs(track.hurdles) do
		if h + 0.002 > p then
			nextH = h
			break
		end
	end
	local speed = math.max(row and row.v or DG.SPEED, DG.SPEED * 0.3)
	local tth = nextH and (nextH - p) * track.length / speed or nil
	-- V13.4: the bar fills towards the hurdle; cheer while the marker is in the green (gold: perfect).
	local streak = row and row.k or 0
	timingBar.Visible = tth ~= nil and tth <= BAR_SPAN and row ~= nil and row.s ~= "done"
	if timingBar.Visible then
		timingMark.Position = UDim2.fromScale(barAt(tth), 0.5)
	end
	if tth and tth <= DG.PERFECT_EARLY and tth >= -DG.PERFECT_LATE then
		cheerCue.Text = "NOW!"
		cheerCue.TextColor3 = C.gold
		cheerCue.TextSize = 52
	elseif tth and tth <= DG.EARLY and tth >= -DG.LATE then
		cheerCue.Text = "NOW!"
		cheerCue.TextColor3 = Color3.fromRGB(150, 240, 130)
		cheerCue.TextSize = 44
	elseif tth and tth <= BAR_SPAN then
		cheerCue.Text = streak >= DG.STREAK and "🔥 ON FIRE"
			or (streak > 0 and string.format("STREAK x%d", streak) or "")
		cheerCue.TextColor3 = streak >= DG.STREAK and Color3.fromRGB(255, 150, 60) or C.white
		cheerCue.TextSize = 28
	else
		cheerCue.Text = row and row.s == "done" and "FINISHED!" or (streak >= DG.STREAK and "🔥 ON FIRE" or "RUN!")
		cheerCue.TextColor3 = streak >= DG.STREAK and Color3.fromRGB(255, 150, 60) or C.parchment
		cheerCue.TextSize = 26
	end
end

-- Crab Chaos -------------------------------------------------------------------------------------------------------------------
local CRAB_FLOOR = 6.2
local function drawCrabs(dt, t)
	local session, id = sessionOf("crabs")
	local camera = workspace.CurrentCamera
	local field = PortGames.CRABS
	local close = camera and (camera.CFrame.Position - field.center).Magnitude < DRAW
	local live = id and ctx.lives[id]
	if not session or not close or not live or session.state == "results" then
		if next(crabCrowd.pets) then
			crabCrowd:clear()
			table.clear(crabs)
		end
		return
	end
	local seen = {}
	for _, row in ipairs(live.c or {}) do
		local key = row[1]
		seen[key] = true
		local crab = crabs[key]
		if not crab then
			crab = { x = row[2], z = row[3], h = row[4] }
			crabs[key] = crab
		end
		crab.tx, crab.tz, crab.th, crab.s, crab.g = row[2], row[3], row[4], row[5], row[6] == 1
	end
	for key, crab in pairs(crabs) do
		if not seen[key] or crab.s == "c" then
			crabCrowd:remove(key)
			crabs[key] = nil
		else
			local k = math.min(1, dt * 9)
			local px, pz = crab.x, crab.z
			crab.x += (crab.tx - crab.x) * k
			crab.z += (crab.tz - crab.z) * k
			local moved = math.sqrt((crab.x - px) ^ 2 + (crab.z - pz) ^ 2) / math.max(dt, 1e-3)
			local pet = crabCrowd:add(key, "Crab", crab.g and "petskin_crab_gold" or nil, nil)
			if pet then
				local hidden = crab.s == "b"
				crabCrowd:show(pet, not hidden)
				if not hidden then
					-- The crab scuttles sideways: its side faces the way it runs.
					local yaw = PetCrowd.yawOf(v3(math.cos(crab.th), 0, math.sin(crab.th))) + math.pi / 2
					crabCrowd:place(
						pet,
						v3(crab.x, CRAB_FLOOR, crab.z),
						yaw,
						moved,
						{ chased = crab.s == "f", grounded = true }
					)
				end
			end
		end
	end
	local _ = t
end

-- V13.4: how many crabs are still loose in a round (the co-op goal: catch them all and everyone scores more).
function PlayCritters.crabsLeft(sessionId)
	local live = ctx and ctx.lives[sessionId]
	if not live or not live.c then
		return nil
	end
	local n = 0
	for _, row in ipairs(live.c) do
		if row[5] ~= "c" then
			n += 1
		end
	end
	return n
end

-- Events ----------------------------------------------------------------------------------------------------------------------------
local function popup(position, text, color)
	local anchor = Ui.make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = v3(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position + v3(0, 3, 0)),
	}, workspace)
	local gui = Ui.make("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromOffset(110, 44),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 300,
	}, anchor)
	local label = Ui.label(gui, {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		Font = Ui.TITLE,
		TextScaled = true,
		TextColor3 = color or C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(label, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function PlayCritters.fx(p)
	local kind = p.kind
	if kind == "crabcaught" and p.position then
		Effects.burst(p.position, p.golden and C.gold or Color3.fromRGB(255, 120, 100), p.golden and 30 or 16, 18)
		Effects.sound("blip", { position = p.position, speed = p.golden and 1.8 or 1.4, volume = 0.8, range = 250 })
		popup(p.position, "+" .. tostring(p.points or 1), p.userId == player.UserId and C.goldPale or C.white)
		return true
	elseif kind == "burrow" and p.position then
		Effects.burst(p.position + v3(0, 0.5, 0), Color3.fromRGB(220, 190, 140), 14, 10)
		return true
	elseif kind == "crate" and p.position then
		Effects.burst(p.position, Color3.fromRGB(180, 130, 80), 40, 30)
		Effects.sound("boom", { position = p.position, speed = 1.6, volume = 0.6, range = 300 })
		ctx.hud.banner("CRABS! CATCH THEM!", Color3.fromRGB(255, 130, 110), 2.2, 3)
		return true
	elseif kind == "allcrabs" and p.position then
		Effects.firework(p.position, C.gold)
		Effects.firework(p.position + v3(8, 0, 0), Color3.fromRGB(255, 130, 110))
		ctx.hud.banner("EVERY CRAB CAUGHT! BONUS FOR EVERYONE!", C.gold, 3, 3)
		return true
	elseif kind == "cheer" then
		local pet = derbyCrowd and derbyCrowd:get(p.racer)
		local verdict = p.verdict
		local good = verdict == "clean" or verdict == "perfect"
		if verdict == "perfect" then
			flips[p.racer] = workspace:GetServerTimeNow()
		end
		if pet and pet.origin then
			popup(
				pet.origin.Position + v3(0, 2, 0),
				verdict == "perfect" and "PERFECT!" or (good and "GO!" or (verdict == "early" and "TOO SOON!" or "?!")),
				good and C.gold or C.white
			)
		end
		if p.userId == player.UserId then
			Effects.sound("blip", { speed = verdict == "perfect" and 2.2 or (good and 1.8 or 0.9), volume = 0.5 })
			if verdict == "perfect" then
				Effects.chime({ 1.5, 2 }, 0.4)
			end
		end
		return true
	end
	return false
end

function PlayCritters.start(context)
	ctx = context
	derbyCrowd = PetCrowd.new("LootGoblinsDerbyPets")
	crabCrowd = PetCrowd.new("LootGoblinsCrabs")
	myRing = Instance.new("Part")
	myRing.Name = "MyRacerRing"
	myRing.Shape = Enum.PartType.Cylinder
	myRing.Size = v3(0.2, 4, 4)
	myRing.Anchored = true
	myRing.CanCollide = false
	myRing.CanQuery = false
	myRing.CanTouch = false
	myRing.Material = Enum.Material.Neon
	myRing.Color = C.gold
	myRing.Transparency = 1
	myRing.Parent = derbyCrowd.folder
	cheerGui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsCheer", ResetOnSpawn = false, DisplayOrder = 8, Enabled = false },
		player:WaitForChild("PlayerGui")
	)
	cheerCue = Ui.label(cheerGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(400, 60),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 30,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(cheerCue, C.night, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	-- V13.4: the timing bar under the cue. The marker runs left to right as the hurdle comes; cheer in the green.
	timingBar = Ui.make("Frame", {
		Name = "TimingBar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.69),
		Size = UDim2.fromOffset(360, 18),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, cheerGui)
	Ui.corner(timingBar, 9)
	local function zone(from, to, color)
		local a, b = barAt(from), barAt(to)
		Ui.corner(
			Ui.make("Frame", {
				Position = UDim2.fromScale(a, 0.15),
				Size = UDim2.fromScale(b - a, 0.7),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, timingBar),
			5
		)
	end
	zone(DG.TOO_EARLY, DG.EARLY, Color3.fromRGB(220, 80, 70))
	zone(DG.EARLY, -DG.LATE, Color3.fromRGB(110, 210, 100))
	zone(DG.PERFECT_EARLY, -DG.PERFECT_LATE, C.gold)
	timingMark = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 28),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, timingBar)
	Ui.corner(timingMark, 3)
end

function PlayCritters.update(dt, context)
	ctx = context
	local t = context.t
	local mine, live, session = drawDerby(t)
	updateCue(mine, live, session, t)
	drawCrabs(dt, t)
	derbyCrowd:flush()
	crabCrowd:flush()
end

return PlayCritters

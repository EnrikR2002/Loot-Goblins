-- The Port's menagerie, alive (V13). Mother Mossback's four pens (server/Port.lua builds the fences and publishes
-- where they are in PortCore's Pens attribute) are filled here, on every client, with the pets of their theme: they
-- wander, pause, do their idle quirk (shared/PetLook.lua animates every one of them), turn to look at a goblin who
-- comes close and skip out of the way of one who walks into them. Stand next to one and its name and price show.
-- Nothing here is physical or replicated: anchored parts moved with one BulkMoveTo, only while the camera is near
-- the pens (DRAW_RANGE), at most PER_PEN pets a pen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local PetLook = require(Shared:WaitForChild("PetLook"))
local Ui = require(script.Parent.Ui)

local PortLife = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PER_PEN = 10
local DRAW_RANGE = 260 -- studs from the camera to a pen's middle
local FULL_RATE = 110 -- nearer than this: every frame; farther: every third

local folder = Instance.new("Folder")
folder.Name = "LootGoblinsPortPets"
local pens = {} -- { center, half, theme, pets = { entry... }, shown }
local label, labelText, labelAnchor
local frame = 0

local function rng(seed)
	return Random.new(seed)
end

local function pick(random, pen)
	local half = pen.half
	return Vector3.new(
		pen.center.X + random:NextNumber(-half, half),
		pen.center.Y,
		pen.center.Z + random:NextNumber(-half, half)
	)
end

local function fill(pen, index)
	local ids = {}
	for _, item in ipairs(Catalog.sorted("pet")) do
		local species = PetLook.SPECIES[item.id]
		if species and species.theme == pen.theme and not item.retired then
			table.insert(ids, item.id)
		end
	end
	local random = rng(1300 + index)
	for i = 1, math.min(PER_PEN, #ids) do
		local id = ids[i]
		local rig = PetLook.build(id)
		if rig then
			if rig.glow then
				rig.glow.Transparency = 1
			end
			rig.model.Parent = folder
			local start = pick(random, pen)
			table.insert(pen.pets, {
				id = id,
				rig = rig,
				random = rng(index * 100 + i),
				pos = start,
				target = start,
				yaw = random:NextNumber(0, math.pi * 2),
				waitUntil = time() + random:NextNumber(0, 4),
				phase = random:NextNumber(0, 10),
				idleAt = time() + random:NextNumber(2, 9),
				flying = PetLook.FLYING[rig.kind] == true,
				speed = 0,
			})
		end
	end
end

local function load(core)
	local ok, list = pcall(function()
		return HttpService:JSONDecode(core:GetAttribute("Pens") or "[]")
	end)
	if not ok or type(list) ~= "table" then
		return
	end
	for index, p in ipairs(list) do
		local pen = {
			center = Vector3.new(p.x, p.y, p.z),
			half = (p.size or 20) / 2,
			theme = p.theme,
			pets = {},
			shown = true,
		}
		table.insert(pens, pen)
		fill(pen, index)
	end
end

-- The name tag over the nearest pet (one tag, moved about).
local function buildLabel()
	labelAnchor = Ui.make("Part", {
		Name = "PenPetTagAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
	}, folder)
	label = Ui.make("BillboardGui", {
		Name = "PenPetTag",
		Adornee = labelAnchor,
		Size = UDim2.fromOffset(200, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 40,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	labelText = Ui.label(label, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = Ui.TITLE,
		TextScaled = true,
		TextColor3 = Ui.C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(labelText, Ui.C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
end

local function tagFor(id)
	local item = Catalog.get(id)
	if not item then
		return id
	end
	local owned = string.find("," .. (player:GetAttribute("Owned") or "") .. ",", "," .. id .. ",", 1, true)
	if owned or Catalog.isFree(item) then
		return item.name .. "  ✔"
	elseif item.price then
		return string.format("%s  ◆%d", item.name, item.price)
	elseif item.unlock then
		return item.name .. "  🏆"
	end
	return item.name
end

local A = CFrame.Angles
local partsList, cframeList = {}, {}
local function step(pen, dt, t, goblins)
	for _, pet in ipairs(pen.pets) do
		-- Wandering: walk to a spot, wait, pick another.
		local toTarget = Vector3.new(pet.target.X - pet.pos.X, 0, pet.target.Z - pet.pos.Z)
		local moving = toTarget.Magnitude > 0.6 and t >= pet.waitUntil
		if not moving and t >= pet.waitUntil then
			if toTarget.Magnitude <= 0.6 then
				pet.waitUntil = t + pet.random:NextNumber(1.5, 6)
				pet.target = pick(pet.random, pen)
			end
		end
		-- A goblin close by: look at them; one right on top: skip aside.
		local nearest, nearestDistance
		for _, position in ipairs(goblins) do
			local d = Vector3.new(position.X - pet.pos.X, 0, position.Z - pet.pos.Z).Magnitude
			if not nearestDistance or d < nearestDistance then
				nearest, nearestDistance = position, d
			end
		end
		local speed = 0
		local wantYaw = pet.yaw
		if nearest and nearestDistance < 3.2 then
			local away = Vector3.new(pet.pos.X - nearest.X, 0, pet.pos.Z - nearest.Z)
			away = away.Magnitude > 0.01 and away.Unit or Vector3.xAxis
			local spot = pet.pos + away * 4
			local half = pen.half
			spot = Vector3.new(
				math.clamp(spot.X, pen.center.X - half, pen.center.X + half),
				pen.center.Y,
				math.clamp(spot.Z, pen.center.Z - half, pen.center.Z + half)
			)
			pet.target, pet.waitUntil = spot, t
			moving = true
		end
		if moving then
			local dir = Vector3.new(pet.target.X - pet.pos.X, 0, pet.target.Z - pet.pos.Z)
			local distance = dir.Magnitude
			speed = (pet.rig.kind == "plodder" or pet.rig.kind == "crawler") and 3 or 5.5
			local move = math.min(distance, speed * dt)
			if distance > 0.01 then
				pet.pos += dir.Unit * move
				wantYaw = math.atan2(-dir.X, -dir.Z)
			end
		elseif nearest and nearestDistance < 12 then
			wantYaw = math.atan2(-(nearest.X - pet.pos.X), -(nearest.Z - pet.pos.Z))
		end
		pet.yaw += math.atan2(math.sin(wantYaw - pet.yaw), math.cos(wantYaw - pet.yaw)) * math.min(1, dt * 6)
		pet.phase += dt * speed * 0.12 + (pet.flying and dt * 1.2 or 0)
		PetLook.updateQuirk(pet, t, not moving)
		local poses, bounce, extra = PetLook.pose(pet, t, speed, { speed = 0, chased = false, diving = false })
		local lift = pet.flying and (2.4 + 0.3 * math.sin(t * 1.7 + pet.phase)) or 0
		local origin = CFrame.new(pet.pos + Vector3.new(0, lift + (bounce or 0), 0)) * A(0, pet.yaw, 0)
		pet.origin = PetLook.apply(pet.rig, origin, poses, extra, partsList, cframeList)
	end
end

local function update(dt)
	if #pens == 0 then
		return
	end
	frame += 1
	local eye = camera.CFrame.Position
	local t = time()
	table.clear(partsList)
	table.clear(cframeList)
	-- Goblins near the pens (their feet), for the pets to notice.
	local goblins = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(goblins, root.Position)
		end
	end
	local best, bestDistance
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, pen in ipairs(pens) do
		local distance = (pen.center - eye).Magnitude
		local show = distance <= DRAW_RANGE and player:GetAttribute("Zone") ~= "raid"
		if show ~= pen.shown then
			pen.shown = show
			for _, pet in ipairs(pen.pets) do
				pet.rig.model.Parent = show and folder or nil
			end
		end
		if show then
			pen.accum = (pen.accum or 0) + dt
			if distance <= FULL_RATE or frame % 3 == 0 then
				step(pen, math.min(pen.accum, 0.1), t, goblins)
				pen.accum = 0
			end
			if myRoot then
				for _, pet in ipairs(pen.pets) do
					local d = (pet.pos - myRoot.Position).Magnitude
					if d < 9 and (not bestDistance or d < bestDistance) then
						best, bestDistance = pet, d
					end
				end
			end
		end
	end
	if #partsList > 0 then
		workspace:BulkMoveTo(partsList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- The tag over the nearest pet.
	if best and best.origin then
		label.Enabled = true
		labelAnchor.CFrame = CFrame.new(best.origin.Position)
		labelText.Text = tagFor(best.id)
	else
		label.Enabled = false
	end
end

function PortLife.start()
	folder.Parent = workspace
	buildLabel()
	task.spawn(function()
		local generated = workspace:WaitForChild("LootGoblinsGenerated")
		local core = generated:WaitForChild("PortCore", 60)
		if not core then
			return
		end
		if not core:GetAttribute("Pens") then
			core:GetAttributeChangedSignal("Pens"):Wait()
		end
		load(core)
		RunService.RenderStepped:Connect(update)
	end)
end

return PortLife

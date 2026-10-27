-- Renaissance (V14, The Visual Renaissance): the Blender-made art layer, drawn by this client only.
--
-- Where V14 has art (Art14/Layouts: the Port's Harbour District, Pebble Isle's coast) this client builds it while the
-- camera is near, and hides the V10/V13 parts it replaces (LocalTransparencyModifier, on this client only): their
-- collision, prompts and everything the server knows stay exactly as they were. New buildings bring collision boxes,
-- also on this client only, so a goblin who sees a wall cannot walk through it. Every skiff wears the Hero Skiff
-- (welded, massless, never solid: the hull, seats and physics are untouched). V14's light replaces V10's fair-weather
-- light (Weather eases storms from it). In Studio, K flips between V14 and V10 to compare them, and a small label says
-- which is showing; Config.ART.V14 = false turns V14 off everywhere (the rollback switch).
--
-- If editable meshes are unavailable or this device's budget runs out, an asset that cannot be built is simply not
-- placed and the V10 part it would have replaced stays visible: the game always looks like V10 at worst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local MeshKit = require(script.Parent.MeshKit)

local Art = script.Parent:WaitForChild("Art14")
local ART = Config.ART

local Renaissance = {}

local player = Players.LocalPlayer
local root -- workspace.Art14: this client's V14 parts
local zones = {} -- one per layout: { layout, anchor, radius, state, folder, assets, hides }
local enabled = false
local weather
local motions = {} -- { model, cf, kind, phase, parts }
local hideIndex = {} -- part name -> true, for every hide of a built zone
local hidden = {} -- part -> true (parts this client is hiding)
local usage = {} -- asset id -> zones using it (an asset is released when none do)
local label

local function cframeOf(c)
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

-- Hiding what V14 replaces -------------------------------------------------------------------------------------------
local function insideAny(part)
	local pos = part.Position
	for _, zone in ipairs(zones) do
		if zone.state == "built" then
			for _, hide in ipairs(zone.hides) do
				if hide.names[part.Name] then
					local p = hide.cf:PointToObjectSpace(pos)
					if
						math.abs(p.X) <= hide.size.X / 2
						and math.abs(p.Y) <= hide.size.Y / 2
						and math.abs(p.Z) <= hide.size.Z / 2
					then
						return true
					end
				end
			end
		end
	end
	return false
end

local function consider(inst)
	if hideIndex[inst.Name] and inst:IsA("BasePart") and not inst:IsDescendantOf(root) and insideAny(inst) then
		inst.LocalTransparencyModifier = 1
		hidden[inst] = true
	end
end

local function rehide()
	for part in pairs(hidden) do
		if part.Parent and not insideAny(part) then
			part.LocalTransparencyModifier = 0
			hidden[part] = nil
		end
	end
	table.clear(hideIndex)
	for _, zone in ipairs(zones) do
		if zone.state == "built" then
			for _, hide in ipairs(zone.hides) do
				for name in pairs(hide.names) do
					hideIndex[name] = true
				end
			end
		end
	end
	if next(hideIndex) then
		for _, inst in ipairs(workspace:GetDescendants()) do
			consider(inst)
		end
	end
end

-- Painted lettering (a transparent board with a SurfaceGui on its front, and its back if it hangs) ------------------
local function lettering(parent, cframe, text)
	local part = Instance.new("Part")
	part.Name = "Lettering"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(text.size[1], text.size[2], 0.05)
	part.CFrame = cframe * cframeOf(text.cf)
	for _, face in ipairs(text.double and { Enum.NormalId.Front, Enum.NormalId.Back } or { Enum.NormalId.Front }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0.4
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 260
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.Text = text.text
		t.TextColor3 = Color3.fromRGB(text.color[1], text.color[2], text.color[3])
		t.TextScaled = true
		t.TextStrokeColor3 = Color3.fromRGB(40, 24, 14)
		t.TextStrokeTransparency = 0.35
		t.Parent = gui
		gui.Parent = part
	end
	part.Parent = parent
end

-- Zones ----------------------------------------------------------------------------------------------------------------
local function use(assetId)
	usage[assetId] = (usage[assetId] or 0) + 1
end

local function unuse(assetId)
	usage[assetId] = (usage[assetId] or 1) - 1
	if usage[assetId] <= 0 then
		usage[assetId] = nil
		MeshKit.release(assetId)
	end
end

local function build(zone)
	zone.token += 1
	local token = zone.token
	zone.state = "building"
	local layout = zone.layout
	local folder = Instance.new("Folder")
	folder.Name = layout.set
	folder.Parent = root
	zone.folder = folder
	local used = {}
	zone.assets = used -- (teardown releases these, even halfway through a build)
	local ok = {}
	for _, item in ipairs(layout.items) do
		local id = item.asset
		if ok[id] == nil then
			local built = MeshKit.load(id) ~= nil
			if zone.token ~= token then -- torn down while it loaded
				if built and not usage[id] then
					MeshKit.release(id)
				end
				return
			end
			ok[id] = built
			if built then
				use(id)
				table.insert(used, id)
			end
			task.wait() -- one asset a frame: no hitch while the district appears
			if zone.token ~= token then
				return
			end
		end
		if ok[id] then
			local info = MeshKit.info(id)
			local cf = zone.anchor * cframeOf(item.cf)
			local scale = Vector3.new(item.scale[1], item.scale[2], item.scale[3])
			local model = MeshKit.spawn(id, cf, scale, folder)
			if model then
				MeshKit.solids(info.solids, cf, scale, model)
				for _, text in ipairs(info.texts or {}) do
					lettering(model, cf, text)
				end
				local kind = item.motion or info.motion
				if kind and kind ~= "" then
					local parts = {}
					for _, p in ipairs(model:GetChildren()) do
						if p:IsA("BasePart") and p.Name ~= "Solid" then
							table.insert(parts, { part = p, rel = cf:ToObjectSpace(p.CFrame), alpha = p.Transparency })
						end
					end
					table.insert(motions, { zone = zone, cf = cf, kind = kind, phase = item.phase or 0, parts = parts })
				end
			end
		end
	end
	MeshKit.solids(layout.solids, zone.anchor, Vector3.one, folder)
	zone.hides = {}
	for _, hide in ipairs(layout.hides) do
		if hide.asset == nil or ok[hide.asset] then
			local names = {}
			for _, n in ipairs(hide.names) do
				names[n] = true
			end
			table.insert(zone.hides, {
				names = names,
				cf = zone.anchor * cframeOf(hide.cf),
				size = Vector3.new(hide.size[1], hide.size[2], hide.size[3]),
			})
		end
	end
	zone.state = "built"
	rehide()
end

local function teardown(zone)
	zone.token += 1
	zone.state = "idle"
	for i = #motions, 1, -1 do
		if motions[i].zone == zone then
			table.remove(motions, i)
		end
	end
	if zone.folder then
		zone.folder:Destroy()
		zone.folder = nil
	end
	for _, id in ipairs(zone.assets or {}) do
		unuse(id)
	end
	zone.assets = {}
	zone.hides = {}
	rehide()
end

-- Ambient motion: moored boats bob, the surf breathes. Only near the camera. ----------------------------------------
local function animate()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	for _, m in ipairs(motions) do
		if (m.cf.Position - eye).Magnitude < 500 then
			if m.kind == "bob" then
				local wave = CFrame.new(0, 0.28 * math.sin(t * 1.3 + m.phase), 0)
					* CFrame.Angles(0.045 * math.sin(t * 0.9 + m.phase), 0, 0.05 * math.sin(t * 1.1 + m.phase * 1.7))
				local cf = m.cf * wave
				for _, p in ipairs(m.parts) do
					p.part.CFrame = cf * p.rel
				end
			elseif m.kind == "surf" then
				local k = 0.5 + 0.5 * math.sin(t * 0.7 + m.phase)
				for _, p in ipairs(m.parts) do
					p.part.Transparency = math.min(0.95, p.alpha + 0.3 * k)
					p.part.CFrame = m.cf * CFrame.new(0, 0.05 * k, 0) * p.rel
				end
			end
		end
	end
end

-- Light ---------------------------------------------------------------------------------------------------------------
-- V14's fair-weather light: a warmer, softer late afternoon with cooler shade (warm light, cool shadow), a little
-- more sky fill and bloom, a bluer, clearer sea. Only properties nothing else animates are set directly; the ones
-- Weather eases (brightness, outdoor ambient, haze) go through Weather.setBase so storms still darken from them.
local LIGHT = {
	lighting = {
		ColorShift_Top = Color3.fromRGB(255, 226, 188),
		ColorShift_Bottom = Color3.fromRGB(104, 136, 178),
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.35,
		ShadowSoftness = 0.45,
		ExposureCompensation = 0.1,
	},
	weather = {
		brightness = 2.9,
		outdoor = Color3.fromRGB(166, 172, 196),
		density = 0.17,
		offset = 0.26,
		color = Color3.fromRGB(206, 226, 255),
		haze = 1.1,
	},
	atmosphere = { Decay = Color3.fromRGB(110, 150, 204), Glare = 0.55 },
	effects = {
		LootGoblinsGrade = { Saturation = 0.2, Contrast = 0.1, TintColor = Color3.fromRGB(255, 246, 232) },
		LootGoblinsBloom = { Intensity = 0.42, Size = 28, Threshold = 0.9 },
		LootGoblinsSunRays = { Intensity = 0.07 },
	},
	water = {
		WaterColor = Color3.fromRGB(16, 108, 144),
		WaterReflectance = 0.38,
		WaterTransparency = 0.66,
	},
}
local saved -- V10's values, to put back

local function capture()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local s = { lighting = {}, atmosphere = {}, effects = {}, water = {}, weather = {} }
	for k in pairs(LIGHT.lighting) do
		s.lighting[k] = Lighting[k]
	end
	if atmosphere then
		for k in pairs(LIGHT.atmosphere) do
			s.atmosphere[k] = atmosphere[k]
		end
		s.weather.density, s.weather.offset = atmosphere.Density, atmosphere.Offset
		s.weather.color, s.weather.haze = atmosphere.Color, atmosphere.Haze
	end
	s.weather.brightness, s.weather.outdoor = Lighting.Brightness, Lighting.OutdoorAmbient
	for name, props in pairs(LIGHT.effects) do
		local effect = Lighting:FindFirstChild(name)
		if effect then
			s.effects[name] = {}
			for k in pairs(props) do
				s.effects[name][k] = effect[k]
			end
		end
	end
	for k in pairs(LIGHT.water) do
		s.water[k] = workspace.Terrain[k]
	end
	return s
end

local function applyLight(values)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	for k, v in pairs(values.lighting) do
		Lighting[k] = v
	end
	if atmosphere then
		for k, v in pairs(values.atmosphere) do
			atmosphere[k] = v
		end
	end
	for name, props in pairs(values.effects) do
		local effect = Lighting:FindFirstChild(name)
		if effect then
			for k, v in pairs(props) do
				effect[k] = v
			end
		end
	end
	for k, v in pairs(values.water) do
		workspace.Terrain[k] = v
	end
	if weather and weather.setBase then
		weather.setBase(values.weather)
	end
end

-- On and off ----------------------------------------------------------------------------------------------------------
local function refreshLabel()
	if label then
		label.Text = enabled and "ART: V14  (K: compare)" or "ART: V10  (K: compare)"
		label.TextColor3 = enabled and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(200, 210, 230)
	end
end

function Renaissance.set(on)
	on = on and ART.V14 == true
	if on == enabled then
		return
	end
	enabled = on
	if on then
		saved = saved or capture()
		applyLight(LIGHT)
	else
		for _, zone in ipairs(zones) do
			teardown(zone)
		end
		if saved then
			applyLight(saved)
		end
	end
	Renaissance.skins(on)
	refreshLabel()
end

function Renaissance.enabled()
	return enabled
end

-- The Hero Skiff (Showcase B) ------------------------------------------------------------------------------------------
-- Every skiff this client can see wears SK_HeroSkiff, built in the hull part's frame and moved with it each frame
-- (anchored, never solid: nothing joins the boat's assembly). V10's skiff parts are hidden here only; the paint job's
-- colours (BoatLook) are read off them, so the Hero Skiff wears whatever livery the boat has.
local SKIFF = "SK_HeroSkiff"
local SKIFF_HIDES = {
	Hull = true,
	Prow = true,
	Strake = true,
	CapRail = true,
	Transom = true,
	BowLamp = true,
	Mast = true,
	MastCap = true,
	Sail = true,
	SailStripe = true,
	Yard = true,
	Driver = true,
	Passenger1 = true,
}
local TINT_FROM =
	{ hull = "Hull", stripe = "Strake", trim = "CapRail", mast = "Mast", sail = "Sail", sailStripe = "Sail" }
local skins = {} -- boat model -> { hull, model, parts, rels, conns }
local skinning = false
local skinFolder
local watching

local function unskin(boat)
	local skin = skins[boat]
	if not skin then
		return
	end
	skins[boat] = nil
	for _, c in ipairs(skin.conns) do
		c:Disconnect()
	end
	skin.model:Destroy()
	for _, p in ipairs(boat:GetChildren()) do
		if SKIFF_HIDES[p.Name] and p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0
		end
	end
end

local pendingSkins = {}

local function skin(boat)
	if skins[boat] or pendingSkins[boat] or not skinning then
		return
	end
	local hull = boat:FindFirstChild("Hull")
	if not hull or not boat:IsDescendantOf(workspace) then
		return -- not streamed in yet: its Hull arriving brings us back here
	end
	pendingSkins[boat] = true
	local at = hull.CFrame -- (the first spawn yields while the mesh builds: the hull may move meanwhile)
	local model = MeshKit.spawn(SKIFF, at, Vector3.one, skinFolder)
	pendingSkins[boat] = nil
	if model and (not skinning or not hull:IsDescendantOf(workspace)) then
		model:Destroy()
		return
	end
	if not model then
		return -- no room for it: this skiff keeps V10's look
	end
	local entry = { hull = hull, model = model, parts = {}, rels = {}, conns = {} }
	skins[boat] = entry
	local info = MeshKit.info(SKIFF)
	local tinted = {} -- V10 part name -> skin parts that take its colour
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(entry.parts, p)
			table.insert(entry.rels, at:ToObjectSpace(p.CFrame))
			local index = tonumber(string.match(p.Name, "_(%d+)$"))
			local role = index and info.groups[index] and info.groups[index].tint
			if role then
				-- a sail's band takes SailStripe's colour when the boat has one, else the sail's
				for _, name in ipairs(role == "sailStripe" and { "Sail", "SailStripe" } or { TINT_FROM[role] }) do
					tinted[name] = tinted[name] or {}
					table.insert(tinted[name], p)
				end
			end
		end
	end
	-- Parts stream in one by one: whatever arrives later is hidden and lends its colour then.
	local function adopt(part)
		if not part:IsA("BasePart") then
			return
		end
		if SKIFF_HIDES[part.Name] then
			part.LocalTransparencyModifier = 1
		end
		local skinParts = tinted[part.Name]
		if skinParts then
			local function paint()
				for _, sp in ipairs(skinParts) do
					if part.Name == "Sail" and sp.Name:match("_(%d+)$") and boat:FindFirstChild("SailStripe") then
						local index = tonumber(sp.Name:match("_(%d+)$"))
						if info.groups[index].tint == "sailStripe" then
							continue
						end
					end
					sp.Color = part.Color
				end
			end
			paint()
			table.insert(entry.conns, part:GetPropertyChangedSignal("Color"):Connect(paint))
		end
	end
	for _, p in ipairs(boat:GetChildren()) do
		adopt(p)
	end
	table.insert(entry.conns, boat.ChildAdded:Connect(adopt))
	table.insert(
		entry.conns,
		hull.AncestryChanged:Connect(function()
			if not hull:IsDescendantOf(workspace) then
				unskin(boat)
			end
		end)
	)
end

local function isSkiff(inst)
	return inst:IsA("Model") and inst:GetAttribute("BoatType") == "skiff"
end

function Renaissance.skins(on)
	skinning = on
	if on then
		skinFolder = skinFolder or Instance.new("Folder")
		skinFolder.Name = "Skiffs"
		skinFolder.Parent = root
		if not watching then
			watching = workspace.DescendantAdded:Connect(function(inst)
				if not skinning then
					return
				end
				if isSkiff(inst) then
					task.spawn(skin, inst)
				elseif inst.Name == "Hull" and inst.Parent and isSkiff(inst.Parent) then
					task.spawn(skin, inst.Parent)
				end
			end)
		end
		for _, inst in ipairs(workspace:GetDescendants()) do
			if isSkiff(inst) then
				task.spawn(skin, inst)
			end
		end
	else
		for boat in pairs(skins) do
			unskin(boat)
		end
		if MeshKit.loaded(SKIFF) then
			MeshKit.release(SKIFF)
		end
	end
end

local function moveSkins()
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	local parts, cframes = {}, {}
	for _, entry in pairs(skins) do
		local cf = entry.hull.CFrame
		if (cf.Position - eye).Magnitude < 900 then
			for i, p in ipairs(entry.parts) do
				parts[#parts + 1] = p
				cframes[#cframes + 1] = cf * entry.rels[i]
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function tick()
	if not enabled then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	for _, zone in ipairs(zones) do
		local d = (eye - zone.anchor.Position).Magnitude
		if zone.state == "idle" and d < zone.radius then
			task.spawn(build, zone)
		elseif zone.state ~= "idle" and d > zone.radius + 300 then
			teardown(zone)
		end
	end
end

function Renaissance.start(weatherModule)
	weather = weatherModule
	if not ART or not ART.V14 then
		return
	end
	root = Instance.new("Folder")
	root.Name = "Art14"
	root.Parent = workspace
	for _, module in ipairs(Art:WaitForChild("Layouts"):GetChildren()) do
		local layout = require(module)
		local a = layout.anchor
		table.insert(zones, {
			layout = layout,
			anchor = CFrame.new(a[1], a[2], a[3]),
			radius = (ART.RADIUS and ART.RADIUS[layout.set]) or 1100,
			state = "idle",
			token = 0,
			assets = {},
			hides = {},
		})
	end
	workspace.DescendantAdded:Connect(function(inst)
		if hideIndex[inst.Name] then
			consider(inst)
		end
	end)
	if RunService:IsStudio() or ART.COMPARE_LIVE then
		local gui = Instance.new("ScreenGui")
		gui.Name = "ArtCompare"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 10, 1, -8)
		label.Size = UDim2.fromOffset(190, 22)
		label.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
		label.BackgroundTransparency = 0.35
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		gui.Parent = player:WaitForChild("PlayerGui")
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode[ART.COMPARE_KEY or "K"] then
				Renaissance.set(not enabled)
			end
		end)
	end
	-- Wait for the world's own light (World.buildEnvironment) before laying V14's over it.
	task.spawn(function()
		Lighting:WaitForChild("LootGoblinsGrade", 60)
		Renaissance.set(true)
	end)
	RunService.RenderStepped:Connect(function()
		animate()
		moveSkins()
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.5)
		end
	end)
end

return Renaissance

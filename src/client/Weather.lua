-- Storms and fog as the player sees them. The server publishes the weather cells as one attribute
-- (workspace.StormData: server time, then "id,x,z,r,strength,vx,vz,isFog" per cell). Here each cell
-- becomes a wall of dark cloud you can see from the horizon, and inside one the sky darkens, fog
-- closes in, rain falls and the sea runs choppy. Nothing here affects gameplay; the server's waves,
-- wind and lightning do that. This is how the player READS the weather in time to react to it.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Weather = {}

local cells = {} -- id -> { x, z, r, s, vx, vz, fog, clouds = Folder, t }
local parsedAt = ""
local camera = workspace.CurrentCamera
local atmosphere = Lighting:WaitForChild("Atmosphere", 20)
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
local terrain = workspace.Terrain

local base = {}
local rainPart, rain
local warnAt = {}
local onWarn -- function(text) set by Main

local function now()
	return workspace:GetServerTimeNow()
end

local function captureBase()
	if base.density then
		return
	end
	base.density = atmosphere.Density
	base.offset = atmosphere.Offset
	base.color = atmosphere.Color
	base.haze = atmosphere.Haze
	base.brightness = Lighting.Brightness
	base.ambient = Lighting.Ambient
	base.outdoor = Lighting.OutdoorAmbient
	base.waveSize = terrain.WaterWaveSize
	base.waveSpeed = terrain.WaterWaveSpeed
	local sky = terrain:FindFirstChildOfClass("Clouds")
	if sky then
		base.clouds = sky
		base.cloudCover = sky.Cover
		base.cloudColor = sky.Color
	end
end

-- V10: a storm is a tall billowing cloud you can read from the horizon, lit like one: bright on top,
-- slate underneath, an anvil spreading at the top. (V9's were dark spheres: from a boat they read as
-- floating black balls.) Each billow is three stacked puffs, dark to light. Fog banks are pale and low.
local STORM_SHADES = {
	{ color = Color3.fromRGB(92, 100, 122), squash = 0.5, lift = 0, scale = 1.0, transparency = 0 },
	{ color = Color3.fromRGB(152, 160, 178), squash = 0.62, lift = 0.42, scale = 0.86, transparency = 0 },
	{ color = Color3.fromRGB(222, 226, 234), squash = 0.7, lift = 0.86, scale = 0.66, transparency = 0 },
}

-- A puff is an ellipsoid (a block with a sphere mesh: a Ball part can't be squashed). Storm billows are opaque:
-- see-through puffs show each other's insides and read as soap bubbles.
local function cloudPuff(folder, name, size, color, transparency, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transparency
	p:SetAttribute("OffsetX", offset.X)
	p:SetAttribute("OffsetZ", offset.Z)
	p:SetAttribute("OffsetY", offset.Y)
	p.Parent = folder
	return p
end

local function makeClouds(cell)
	local folder = Instance.new("Folder")
	folder.Name = "StormClouds" .. cell.id
	local random = Random.new(cell.id * 31)
	if cell.fog then
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
			local r = cell.r * random:NextNumber(0.5, 0.9)
			local size = random:NextNumber(110, 170)
			cloudPuff(
				folder,
				"Cloud",
				Vector3.new(size * 1.8, size * 0.42, size * 1.8),
				Color3.fromRGB(226, 234, 238),
				0.58,
				Vector3.new(math.cos(a) * r, random:NextNumber(10, 34), math.sin(a) * r)
			)
		end
	else
		-- Billows round the cell, and a few in the middle, each a dark-to-light stack.
		local billows = 10
		for i = 1, billows do
			local inner = i > 7
			local a = i / billows * math.pi * 2 + random:NextNumber(-0.3, 0.3)
			local r = inner and cell.r * random:NextNumber(0.05, 0.3) or cell.r * random:NextNumber(0.45, 0.78)
			local size = random:NextNumber(120, 180) * (inner and 1.2 or 1)
			local baseY = random:NextNumber(70, 110) + (inner and 40 or 0)
			for _, shade in ipairs(STORM_SHADES) do
				local s = size * shade.scale
				cloudPuff(
					folder,
					"Cloud",
					Vector3.new(s * 1.5, s * shade.squash * 1.4, s * 1.5),
					shade.color,
					shade.transparency,
					Vector3.new(
						math.cos(a) * r + random:NextNumber(-12, 12),
						baseY + size * shade.lift,
						math.sin(a) * r + random:NextNumber(-12, 12)
					)
				)
			end
		end
		-- The anvil: a wide pale shelf spreading over the top.
		for _ = 1, 4 do
			local size = random:NextNumber(200, 280)
			cloudPuff(
				folder,
				"CloudCap",
				Vector3.new(size * 1.9, size * 0.28, size * 1.9),
				Color3.fromRGB(206, 212, 224),
				0,
				Vector3.new(
					random:NextNumber(-cell.r * 0.45, cell.r * 0.45),
					random:NextNumber(255, 290),
					random:NextNumber(-cell.r * 0.45, cell.r * 0.45)
				)
			)
		end
	end
	folder.Parent = workspace
	return folder
end

local function parse(raw)
	local fields = string.split(raw, ";")
	local stamp = tonumber(fields[1]) or now()
	local seen = {}
	for i = 2, #fields do
		local v = string.split(fields[i], ",")
		local id = tonumber(v[1])
		if id then
			seen[id] = true
			local cell = cells[id]
			if not cell then
				cell = { id = id, fog = tonumber(v[8]) == 1 }
				cells[id] = cell
				cell.clouds = makeClouds({ id = id, r = tonumber(v[4]) or 280, fog = cell.fog })
			end
			cell.x, cell.z, cell.r = tonumber(v[2]), tonumber(v[3]), tonumber(v[4])
			cell.s, cell.vx, cell.vz = tonumber(v[5]), tonumber(v[6]), tonumber(v[7])
			cell.t = stamp
		end
	end
	for id, cell in pairs(cells) do
		if not seen[id] then
			cell.clouds:Destroy()
			cells[id] = nil
		end
	end
end

-- The cell's position right now, extrapolated from its last update.
local function positionOf(cell, t)
	local dt = math.clamp(t - (cell.t or t), 0, 2)
	return cell.x + cell.vx * dt, cell.z + cell.vz * dt
end

function Weather.cells()
	return cells
end

-- How strong this weather is at a point, 0..1 (storms, then fog separately).
function Weather.intensityAt(x, z)
	local storm, fog = 0, 0
	local t = now()
	for _, cell in pairs(cells) do
		local cx, cz = positionOf(cell, t)
		local distance = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
		if distance < cell.r then
			local edge = math.min(1, (1 - distance / cell.r) * 2.2)
			if cell.fog then
				fog = math.max(fog, cell.s * edge)
			else
				storm = math.max(storm, cell.s * edge)
			end
		end
	end
	return storm, fog
end

function Weather.init(warn)
	onWarn = warn
	captureBase()
	rainPart = Instance.new("Part")
	rainPart.Name = "RainEmitter"
	rainPart.Size = Vector3.new(90, 1, 90)
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Parent = workspace
	rain = Instance.new("ParticleEmitter")
	rain.Rate = 0
	rain.Lifetime = NumberRange.new(0.5, 0.7)
	rain.Speed = NumberRange.new(150, 190)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Size = NumberSequence.new(0.35)
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 215, 235))
	rain.Transparency = NumberSequence.new(0.4, 0.8)
	rain.LightEmission = 0.2
	rain.Parent = rainPart

	RunService.RenderStepped:Connect(function(dt)
		local raw = workspace:GetAttribute("StormData") or ""
		if raw ~= parsedAt then
			parsedAt = raw
			if raw ~= "" then
				parse(raw)
			else
				for id, cell in pairs(cells) do
					cell.clouds:Destroy()
					cells[id] = nil
				end
			end
		end
		camera = workspace.CurrentCamera or camera
		local t = now()
		-- Cloud walls follow their cells.
		for _, cell in pairs(cells) do
			local cx, cz = positionOf(cell, t)
			local grow = math.clamp(cell.s * 1.4, 0, 1)
			for _, puff in ipairs(cell.clouds:GetChildren()) do
				puff.Position = Vector3.new(
					cx + puff:GetAttribute("OffsetX"),
					puff:GetAttribute("OffsetY") * (0.4 + 0.6 * grow),
					cz + puff:GetAttribute("OffsetZ")
				)
			end
		end
		local camPos = camera.CFrame.Position
		local storm, fog = Weather.intensityAt(camPos.X, camPos.Z)
		local blend = math.min(1, dt * 1.6)
		local function ease(current, target)
			return current + (target - current) * blend
		end
		atmosphere.Density = ease(atmosphere.Density, base.density + storm * 0.22 + fog * 0.6)
		atmosphere.Offset = ease(atmosphere.Offset, base.offset)
		atmosphere.Haze = ease(atmosphere.Haze, base.haze + storm * 3 + fog * 6)
		atmosphere.Color = atmosphere.Color:Lerp(
			base.color:Lerp(Color3.fromRGB(110, 118, 135), math.clamp(storm * 0.8 + fog * 0.2, 0, 1)),
			blend
		)
		Lighting.Brightness = ease(Lighting.Brightness, base.brightness * (1 - 0.5 * storm - 0.2 * fog))
		Lighting.OutdoorAmbient =
			Lighting.OutdoorAmbient:Lerp(base.outdoor:Lerp(Color3.fromRGB(70, 74, 88), storm), blend)
		-- The sky's own clouds close in and go slate under a storm.
		local sky = base.clouds
		if sky and sky.Parent then
			sky.Cover = ease(sky.Cover, math.min(1, base.cloudCover + storm * 0.4 + fog * 0.2))
			sky.Color = sky.Color:Lerp(base.cloudColor:Lerp(Color3.fromRGB(120, 128, 146), storm), blend)
		end
		terrain.WaterWaveSize = ease(terrain.WaterWaveSize, base.waveSize + storm * 0.65)
		terrain.WaterWaveSpeed = ease(terrain.WaterWaveSpeed, base.waveSpeed + storm * 22)
		rainPart.CFrame = CFrame.new(camPos + Vector3.new(0, 38, 0))
		rain.Rate = 700 * storm

		-- A heads-up when weather is brewing within sight but not on you yet.
		if storm < 0.05 then
			for id, cell in pairs(cells) do
				if not cell.fog and cell.s > 0.3 then
					local cx, cz = positionOf(cell, t)
					local distance = math.sqrt((camPos.X - cx) ^ 2 + (camPos.Z - cz) ^ 2) - cell.r
					if distance < 700 and distance > 0 and (warnAt[id] or 0) < t - 45 then
						warnAt[id] = t
						if onWarn then
							local dx, dz = cx - camPos.X, cz - camPos.Z
							onWarn(dx, dz, math.floor(distance + 0.5))
						end
					end
				end
			end
		end
	end)
end

return Weather

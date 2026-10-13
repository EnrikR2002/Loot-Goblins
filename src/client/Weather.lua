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
end

local function makeClouds(cell)
	local folder = Instance.new("Folder")
	folder.Name = "StormClouds" .. cell.id
	local random = Random.new(cell.id * 31)
	local color = cell.fog and Color3.fromRGB(215, 225, 230) or Color3.fromRGB(58, 62, 76)
	local count = cell.fog and 10 or 16
	for i = 1, count do
		local a = i / count * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local r = cell.r * random:NextNumber(0.55, 0.9)
		local size = random:NextNumber(90, 150)
		local puff = Instance.new("Part")
		puff.Name = "Cloud"
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(size * 1.7, size * 0.55, size * 1.7)
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = color
		puff.Transparency = cell.fog and 0.6 or 0.4
		puff:SetAttribute("OffsetX", math.cos(a) * r)
		puff:SetAttribute("OffsetZ", math.sin(a) * r)
		puff:SetAttribute("OffsetY", cell.fog and random:NextNumber(10, 40) or random:NextNumber(70, 150))
		puff.Parent = folder
	end
	if not cell.fog then
		for _ = 1, 6 do
			local size = random:NextNumber(160, 240)
			local cap = Instance.new("Part")
			cap.Name = "CloudCap"
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.new(size * 1.8, size * 0.35, size * 1.8)
			cap.Anchored = true
			cap.CanCollide = false
			cap.CanQuery = false
			cap.CanTouch = false
			cap.CastShadow = false
			cap.Material = Enum.Material.SmoothPlastic
			cap.Color = Color3.fromRGB(44, 48, 62)
			cap.Transparency = 0.2
			cap:SetAttribute("OffsetX", random:NextNumber(-cell.r * 0.5, cell.r * 0.5))
			cap:SetAttribute("OffsetZ", random:NextNumber(-cell.r * 0.5, cell.r * 0.5))
			cap:SetAttribute("OffsetY", random:NextNumber(170, 210))
			cap.Parent = folder
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

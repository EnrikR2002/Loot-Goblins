-- MeshKit (V14, The Visual Renaissance): turns the art pipeline's assets into MeshParts on this client.
--
-- Every asset made in Blender (art/blender, exported by art/blender/scripts/lgexport.py) is listed in
-- Art14/Manifest.lua and its geometry is in Art14/Meshes/<asset>/<group>.lua. An asset is one or more groups (by Roblox
-- material, big ones cut in pieces); each group becomes one MeshPart. A group with a current uploaded mesh id in the manifest loads that mesh;
-- otherwise it is built here from the repository's data with an EditableMesh, so no upload, asset id or account is
-- needed to see the art (the experience must allow Mesh / Image APIs: see art/README.md).
--
-- Editable meshes count against a per-device memory budget (measured in Studio: about 36,000 vertices of this kind of
-- mesh). So each asset is built once and every copy of it shares that mesh (a clone keeps the reference), sets are
-- released when their zone is left, and anything that does not fit returns nil: the caller keeps V10's look there.
local AssetService = game:GetService("AssetService")

local Art = script.Parent:WaitForChild("Art14")
local Manifest = require(Art:WaitForChild("Manifest"))

local MeshKit = {}

local templates = {} -- asset id -> { parts = {MeshPart}, meshes = {EditableMesh} } | false (could not be built)
local building = {} -- asset id -> true while its groups are being made
local stats = { built = 0, failed = 0, verts = 0, tris = 0, uploaded = 0, lastError = nil }
MeshKit.stats = stats

local function readGroup(data)
	local p, n, c, f = data.p, data.n, data.c, data.f
	local positions = table.create(#p // 3)
	for i = 1, #p, 3 do
		positions[#positions + 1] = Vector3.new(p[i], p[i + 1], p[i + 2])
	end
	local normals = table.create(#n // 3)
	for i = 1, #n, 3 do
		normals[#normals + 1] = Vector3.new(n[i], n[i + 1], n[i + 2])
	end
	local colors, alphas = table.create(#c // 3), table.create(#c // 3)
	for i = 1, #c, 3 do
		colors[#colors + 1] = Color3.fromRGB(c[i], c[i + 1], c[i + 2])
		alphas[#alphas + 1] = 1
	end
	return positions, normals, colors, alphas, f
end

-- One group's EditableMesh, copied into a fixed-size mesh (the cheaper kind) once it is filled.
local function editable(data)
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then
		return nil, "the editable mesh budget is used up (or Mesh / Image APIs are off)"
	end
	local ok, err = pcall(function()
		local positions, normals, colors, alphas, f = readGroup(data)
		local vIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
		local nIds = mesh:BatchAdd(Enum.MeshAttribute.Normal, normals)
		local cIds = mesh:BatchAdd(Enum.MeshAttribute.Color, colors, alphas)
		local corners, cornerNormals, cornerColors = {}, {}, {}
		for i = 1, #f, 9 do
			corners[#corners + 1] = { vIds[f[i]], vIds[f[i + 1]], vIds[f[i + 2]] }
			cornerNormals[#cornerNormals + 1] = { nIds[f[i + 3]], nIds[f[i + 4]], nIds[f[i + 5]] }
			cornerColors[#cornerColors + 1] = { cIds[f[i + 6]], cIds[f[i + 7]], cIds[f[i + 8]] }
		end
		local fIds = mesh:BatchAdd(Enum.MeshAttribute.Face, corners)
		mesh:BatchSetFaceAttributes(fIds, cornerNormals)
		mesh:BatchSetFaceAttributes(fIds, cornerColors)
	end)
	if not ok then
		mesh:Destroy()
		return nil, tostring(err)
	end
	local okFixed, fixed = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(mesh), { FixedSize = true })
	end)
	mesh:Destroy()
	if not okFixed or not fixed then
		return nil, okFixed and "no room for the fixed copy" or tostring(fixed)
	end
	return fixed
end

local function style(part, info, name)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Material = Enum.Material[info.material] or Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = info.alpha or 0
	part.CastShadow = not info.glow and (info.alpha or 0) < 0.5
	part.Size = Vector3.new(info.size[1], info.size[2], info.size[3])
end

-- Builds an asset's MeshParts once (yields). Returns the template or nil (and why).
function MeshKit.load(assetId)
	while building[assetId] do
		task.wait()
	end
	local cached = templates[assetId]
	if cached ~= nil then
		return cached or nil
	end
	local info = Manifest[assetId]
	if not info then
		return nil, "not in the manifest"
	end
	building[assetId] = true
	local template = { parts = {}, meshes = {}, info = info }
	local ok, err = pcall(function()
		local folder
		for index, group in ipairs(info.groups) do
			local part
			if group.assetId then
				part = AssetService:CreateMeshPartAsync(
					Content.fromUri(group.assetId),
					{ CollisionFidelity = Enum.CollisionFidelity.Box }
				)
				stats.uploaded += 1
			else
				folder = folder or Art.Meshes:WaitForChild(assetId)
				local mesh, why = editable(require(folder:WaitForChild(tostring(index))))
				if not mesh then
					error(why, 0)
				end
				table.insert(template.meshes, mesh)
				part = AssetService:CreateMeshPartAsync(
					Content.fromObject(mesh),
					{ CollisionFidelity = Enum.CollisionFidelity.Box }
				)
			end
			style(part, group, assetId .. "_" .. index)
			template.parts[index] = part
		end
	end)
	building[assetId] = nil
	if not ok then
		for _, mesh in ipairs(template.meshes) do
			mesh:Destroy()
		end
		for _, part in pairs(template.parts) do
			part:Destroy()
		end
		templates[assetId] = false
		stats.failed += 1
		stats.lastError = assetId .. ": " .. tostring(err)
		return nil, tostring(err)
	end
	templates[assetId] = template
	stats.built += 1
	stats.verts += info.verts
	stats.tris += info.tris
	return template
end

-- A placed copy: a Model of MeshParts (sharing the template's meshes) at cframe, scaled per axis. Lights become
-- PointLights. Returns nil if the asset could not be built.
function MeshKit.spawn(assetId, cframe, scale, parent)
	local template = MeshKit.load(assetId)
	if not template then
		return nil
	end
	scale = scale or Vector3.one
	local model = Instance.new("Model")
	model.Name = assetId
	for index, source in ipairs(template.parts) do
		local group = template.info.groups[index]
		local part = source:Clone()
		local offset = Vector3.new(group.offset[1], group.offset[2], group.offset[3]) * scale
		part.Size = source.Size * scale
		part.CFrame = cframe * CFrame.new(offset)
		part.Parent = model
	end
	local first = model:FindFirstChildWhichIsA("BasePart")
	for i, light in ipairs(template.info.lights or {}) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Light" .. i
		attachment.WorldPosition =
			cframe:PointToWorldSpace(Vector3.new(light.pos[1], light.pos[2], light.pos[3]) * scale)
		attachment.Parent = first
		local lamp = Instance.new("PointLight")
		lamp.Color = Color3.fromRGB(light.color[1], light.color[2], light.color[3])
		lamp.Range = light.range
		lamp.Brightness = light.brightness
		lamp.Shadows = false
		lamp.Parent = attachment
	end
	model.WorldPivot = cframe
	model.Parent = parent
	return model
end

-- Invisible boxes this client's goblin collides with (an asset's COL_ proxies or a layout's solids).
function MeshKit.solids(list, cframe, scale, parent)
	scale = scale or Vector3.one
	for _, s in ipairs(list or {}) do
		local c = s.cf
		local part = Instance.new("Part")
		part.Name = "Solid"
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(s.size[1], s.size[2], s.size[3]) * scale
		local local_ = CFrame.new(
			c[1] * scale.X,
			c[2] * scale.Y,
			c[3] * scale.Z,
			c[4],
			c[5],
			c[6],
			c[7],
			c[8],
			c[9],
			c[10],
			c[11],
			c[12]
		)
		part.CFrame = cframe * local_
		part.Parent = parent
	end
end

-- Frees an asset's meshes (only once nothing placed from it is left).
function MeshKit.release(assetId)
	local template = templates[assetId]
	if template then
		for _, part in ipairs(template.parts) do
			part:Destroy()
		end
		for _, mesh in ipairs(template.meshes) do
			mesh:Destroy()
		end
		stats.built -= 1
		stats.verts -= template.info.verts
		stats.tris -= template.info.tris
	end
	templates[assetId] = nil
end

function MeshKit.loaded(assetId)
	return templates[assetId] and true or false
end

function MeshKit.info(assetId)
	return Manifest[assetId]
end

return MeshKit

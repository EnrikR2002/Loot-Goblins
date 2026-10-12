-- Natural land from a short description: hills, ridges, cliff-walled mesas, sandbars, shoals
-- and channels, written straight into the Terrain voxels.
--
-- A landform is a list of lobes. Each lobe is a point or a line (its spine) with a radius and
-- a height; the ground at any spot is the highest lobe there, and cuts are dug out afterwards.
-- The coastline wobbles with noise, so nothing comes out as a circle, and the seabed shelves
-- away from every shore, so shallows appear by themselves. Everything is deterministic (a seed):
-- the sea looks the same every raid, so players can learn it.
--
--   hill   a rounded rise: height h at the spine, sloping to the sea at the edge
--   mesa   a flat top at height h with sheer sides (too tall to jump: grapple, ramp or ladder)
--   cut    a channel or cove dug to `floor` (below 0 it fills with sea)
--
-- A hill lower than the tide line is a sandbar; one with a negative h is a shoal (it never breaks
-- the surface: skiffs cross it, deep hulls cannot). Land is only ever ADDED to what is already
-- there, so a landform can overlap another, and the island builders that run afterwards lay their
-- own ground on top and carve their own harbors out of it.
--
-- Landform.silhouette turns a finished island into a few plain blocks that never stream out, so
-- its shape stays on the horizon from across the sea.
local Landform = {}

-- Set by World.lua: called with the bounds (minX, minZ, maxX, maxZ) of everything a landform
-- raises, so SeaNav knows where the seabed is no longer flat.
Landform.touch = nil

local terrain = workspace.Terrain

local CELL = 4
local FLOOR = -28 -- The sea floor's top; nothing is written below it.
local TILE = 64 -- Columns per side of one voxel write.
local BEACH_Y = 2.6 -- Ground lower than this is shore.
-- The engine draws (and collides with) a voxel column about two studs above the height its fill
-- alone would suggest: a block filled to -28 is found at -26 by a raycast. Columns are written
-- this much lower, so the heights in a landform are the heights you get. It matters most under
-- water, where half a stud decides which hulls can pass.
local LIFT = 2
local AIR = Enum.Material.Air

local function smooth(t)
	return t * t * (3 - 2 * t)
end

-- Fills in a lobe's defaults and the numbers the height function needs.
local function prepare(lobe, index)
	lobe.wob = lobe.wob or 0.3
	lobe.slope = lobe.slope or 0.3
	lobe.phase = index * 17.31
	if lobe.kind == "cut" then
		lobe.floor = lobe.floor or -10
		lobe.reach = lobe.r * (1 + lobe.wob)
	else
		lobe.e = lobe.e or math.min(-4, lobe.h - 5)
		lobe.rough = lobe.rough or (lobe.kind == "mesa" and 0.6 or 3)
		lobe.flat = lobe.kind == "mesa" and (lobe.flat or math.max(0.6, 1 - 5 / lobe.r)) or nil
		lobe.reach = lobe.r * (1 + lobe.wob) + (lobe.e - FLOOR) / lobe.slope + CELL
	end
	if lobe.x2 then
		lobe.sx, lobe.sz = lobe.x2 - lobe.x, lobe.z2 - lobe.z
		lobe.inv = 1 / math.max(lobe.sx * lobe.sx + lobe.sz * lobe.sz, 0.001)
	end
	lobe.minX = math.min(lobe.x, lobe.x2 or lobe.x) - lobe.reach
	lobe.maxX = math.max(lobe.x, lobe.x2 or lobe.x) + lobe.reach
	lobe.minZ = math.min(lobe.z, lobe.z2 or lobe.z) - lobe.reach
	lobe.maxZ = math.max(lobe.z, lobe.z2 or lobe.z) + lobe.reach
end

-- Distance from (x, z) to the lobe's spine, measured in wobbling radii (1 = the lobe's edge), and
-- the same distance in studs with the radius it was measured against.
local function reachOf(lobe, x, z, seed)
	local dx, dz = x - lobe.x, z - lobe.z
	if lobe.sx then
		local along = math.clamp((dx * lobe.sx + dz * lobe.sz) * lobe.inv, 0, 1)
		dx -= lobe.sx * along
		dz -= lobe.sz * along
	end
	local d = math.sqrt(dx * dx + dz * dz)
	if d > lobe.reach then
		return nil
	end
	local n = math.noise(x * 0.012 + lobe.phase, z * 0.012, seed)
		+ 0.5 * math.noise(x * 0.031, z * 0.031 + lobe.phase, seed)
	local radius = lobe.r * (1 + lobe.wob * n)
	return d / radius, d, radius
end

-- spec: { seed, body, cliff, shore, top, topFrom, lobes = { { kind, x, z, x2, z2, r, h, ... } } }
-- Positions are world studs. A lobe may carry its own `body` material. Returns the tall round
-- crags it made as { x, z, r, h } (the solid core of each), for Landform.mark.
function Landform.build(spec)
	local seed = spec.seed or 1
	local body = spec.body or Enum.Material.Grass
	local cliff = spec.cliff or Enum.Material.Rock
	local shore = spec.shore or Enum.Material.Sand
	local cliffSlope = spec.cliffSlope or 1.25

	local lobes, cuts = {}, {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for index, lobe in ipairs(spec.lobes) do
		prepare(lobe, index)
		table.insert(lobe.kind == "cut" and cuts or lobes, lobe)
		if lobe.kind ~= "cut" then
			minX, maxX = math.min(minX, lobe.minX), math.max(maxX, lobe.maxX)
			minZ, maxZ = math.min(minZ, lobe.minZ), math.max(maxZ, lobe.maxZ)
			if Landform.touch then
				Landform.touch(lobe.minX, lobe.minZ, lobe.maxX, lobe.maxZ)
			end
		end
	end
	if #lobes == 0 then
		return {}
	end
	local marks = {}
	for _, lobe in ipairs(lobes) do
		if lobe.kind == "mesa" and not lobe.x2 and lobe.h >= 24 then
			local core = lobe.r * (1 - 0.75 * lobe.wob) * lobe.flat - 2
			if core >= 3 then
				table.insert(marks, { x = lobe.x, z = lobe.z, r = core, h = lobe.h - 4 })
			end
		end
	end
	minX, minZ = math.floor(minX / CELL) * CELL, math.floor(minZ / CELL) * CELL
	local nx, nz = math.ceil((maxX - minX) / CELL), math.ceil((maxZ - minZ) / CELL)

	-- Pass 1: the height of every column, and which lobe made it.
	local heights = table.create(nx * nz, FLOOR - 1)
	local owner = table.create(nx * nz, 0)
	for iz = 0, nz - 1 do
		local z = minZ + iz * CELL + CELL / 2
		for ix = 0, nx - 1 do
			local x = minX + ix * CELL + CELL / 2
			local best, bestLobe = FLOOR - 1, 0
			for index, lobe in ipairs(lobes) do
				if x > lobe.minX and x < lobe.maxX and z > lobe.minZ and z < lobe.maxZ then
					local t, d, radius = reachOf(lobe, x, z, seed)
					if t then
						local h
						if t >= 1 then
							h = lobe.e - (d - radius) * lobe.slope
						elseif lobe.flat then
							h = t < lobe.flat and lobe.h
								or lobe.h + (lobe.e - lobe.h) * (t - lobe.flat) / (1 - lobe.flat)
						else
							h = lobe.e + (lobe.h - lobe.e) * (1 - smooth(t))
						end
						if t < 1 and h > 1 then
							h += lobe.rough * 2 * math.noise(x * 0.037, z * 0.037, seed + 7) * math.min((h - 1) / 8, 1)
						end
						if h > best then
							best, bestLobe = h, index
						end
					end
				end
			end
			if best > FLOOR then
				for _, lobe in ipairs(cuts) do
					if x > lobe.minX and x < lobe.maxX and z > lobe.minZ and z < lobe.maxZ and best > lobe.floor then
						local t = reachOf(lobe, x, z, seed)
						if t and t < 1 then
							local depth = 1 - smooth(math.clamp((t - 0.55) / 0.45, 0, 1))
							best += (lobe.floor - best) * depth
						end
					end
				end
			end
			local i = iz * nx + ix + 1
			heights[i] = best
			owner[i] = bestLobe
		end
	end

	-- Pass 2: write the voxels, a tile at a time. Existing terrain is read first and kept.
	for tz = 0, nz - 1, TILE do
		for tx = 0, nx - 1, TILE do
			local sx, sz = math.min(TILE, nx - tx), math.min(TILE, nz - tz)
			local top = FLOOR
			for iz = tz, tz + sz - 1 do
				for ix = tx, tx + sx - 1 do
					top = math.max(top, heights[iz * nx + ix + 1])
				end
			end
			if top > FLOOR then
				local sy = math.ceil((top - FLOOR) / CELL) + 1
				local region = Region3.new(
					Vector3.new(minX + tx * CELL, FLOOR, minZ + tz * CELL),
					Vector3.new(minX + (tx + sx) * CELL, FLOOR + sy * CELL, minZ + (tz + sz) * CELL)
				)
				local materials, occupancy = terrain:ReadVoxels(region, CELL)
				for ix = 0, sx - 1 do
					local gx = tx + ix
					local matColumn, occColumn = materials[ix + 1], occupancy[ix + 1]
					for iz = 0, sz - 1 do
						local gz = tz + iz
						local i = gz * nx + gx + 1
						local h = heights[i]
						if h > FLOOR then
							-- The steepest drop to a neighbour decides whether this is a cliff face.
							local steep = 0
							if gx > 0 then
								steep = math.max(steep, math.abs(h - heights[i - 1]))
							end
							if gx < nx - 1 then
								steep = math.max(steep, math.abs(h - heights[i + 1]))
							end
							if gz > 0 then
								steep = math.max(steep, math.abs(h - heights[i - nx]))
							end
							if gz < nz - 1 then
								steep = math.max(steep, math.abs(h - heights[i + nx]))
							end
							local lobe = lobes[owner[i]]
							local surface
							if h < BEACH_Y then
								surface = (lobe and lobe.shore) or shore
							elseif steep / CELL > cliffSlope then
								surface = cliff
							elseif spec.top and h >= (spec.topFrom or math.huge) then
								surface = spec.top
							else
								surface = (lobe and lobe.body) or body
							end
							local under = surface == cliff and cliff or ((lobe and lobe.shore) or shore)
							local written = h - LIFT
							for iy = 1, math.min(sy, math.ceil((written - FLOOR) / CELL)) do
								local y0 = FLOOR + (iy - 1) * CELL
								local fill = math.clamp((written - y0) / CELL, 0, 1)
								if fill > occColumn[iy][iz + 1] then
									occColumn[iy][iz + 1] = fill
									matColumn[iy][iz + 1] = y0 < 0 and under or surface
								end
							end
						end
					end
				end
				terrain:WriteVoxels(region, CELL, materials, occupancy)
			end
		end
	end
	return marks
end

-- Leaves a plain pillar buried inside each crag from Landform.build, in a model that never streams
-- out: sea stacks are too thin for Landform.silhouette's grid, and they are the best landmarks.
function Landform.mark(marks, name, color, parent)
	if #marks == 0 then
		return 0
	end
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, mark in ipairs(marks) do
		local pillar = Instance.new("Part")
		pillar.Name = "Silhouette"
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(mark.h - 2, mark.r * 2, mark.r * 2)
		pillar.CFrame = CFrame.new(mark.x, (mark.h + 2) / 2, mark.z) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.CanTouch = false
		pillar.CastShadow = false
		pillar.Color = color
		pillar.Material = Enum.Material.SmoothPlastic
		pillar.Parent = model
	end
	model.Parent = parent
	return #marks
end

-- A shaper collects lobes in an island's own coordinates (offsets from its center) and builds
-- them in one go. Sizes are studs; every method returns the shaper so calls can be chained.
function Landform.shaper(cx, cz, spec)
	local shaper = {}
	spec = spec or {}
	spec.lobes = {}

	local function add(lobe, options)
		for key, value in pairs(options or {}) do
			lobe[key] = value
		end
		lobe.x, lobe.z = cx + lobe.x, cz + lobe.z
		if lobe.x2 then
			lobe.x2, lobe.z2 = cx + lobe.x2, cz + lobe.z2
		end
		table.insert(spec.lobes, lobe)
		return shaper
	end

	function shaper.hill(x, z, r, h, options)
		return add({ kind = "hill", x = x, z = z, r = r, h = h }, options)
	end
	function shaper.ridge(x, z, x2, z2, r, h, options)
		return add({ kind = "hill", x = x, z = z, x2 = x2, z2 = z2, r = r, h = h }, options)
	end
	function shaper.mesa(x, z, r, h, options)
		return add({ kind = "mesa", x = x, z = z, r = r, h = h }, options)
	end
	function shaper.wall(x, z, x2, z2, r, h, options)
		return add({ kind = "mesa", x = x, z = z, x2 = x2, z2 = z2, r = r, h = h }, options)
	end
	-- Sand that only just clears the water, or (negative h) stays under it.
	function shaper.bar(x, z, x2, z2, r, h, options)
		return add(
			{ kind = "hill", x = x, z = z, x2 = x2, z2 = z2, r = r, h = h or 1.8, rough = 0, slope = 0.22 },
			options
		)
	end
	function shaper.cut(x, z, x2, z2, r, floor, options)
		return add({ kind = "cut", x = x, z = z, x2 = x2, z2 = z2, r = r, floor = floor }, options)
	end
	-- Builds everything added so far. Returns the crags (see Landform.build).
	function shaper.build()
		return Landform.build(spec)
	end
	return shaper
end

-- Silhouettes ---------------------------------------------------------------------------
local skyParams = RaycastParams.new()
skyParams.FilterType = Enum.RaycastFilterType.Include
skyParams.FilterDescendantsInstances = { terrain }
skyParams.IgnoreWater = true

local GRID = 32
local BASE_Y = 4 -- Blocks start just above the tide line; `solid` keeps them out of caves and tunnels.
local STEP = 8 -- Block tops snap down to this, so neighbours merge.

local function topAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -640, 0), skyParams)
	return hit and hit.Position.Y or FLOOR
end

-- True when every voxel in the box is solid ground: a block there can never be seen from inside
-- a cave or poke out of a slope.
local function solid(minCorner, maxCorner)
	local materials, occupancy = terrain:ReadVoxels(Region3.new(minCorner, maxCorner), CELL)
	local size = materials.Size
	for ix = 1, size.X do
		for iy = 1, size.Y do
			local matRow, occRow = materials[ix][iy], occupancy[ix][iy]
			for iz = 1, size.Z do
				if matRow[iz] == AIR or matRow[iz] == Enum.Material.Water or occRow[iz] < 0.95 then
					return false
				end
			end
		end
	end
	return true
end

-- Samples the finished terrain within `radius` of (cx, cz) and leaves a model of buried blocks
-- that follows its tall shapes. Returns the model and how many blocks it took. With a `budget`
-- (seconds) it yields whenever it has worked that long, so it can run while people play.
function Landform.silhouette(name, cx, cz, radius, color, parent, budget)
	local sliceStart = os.clock()
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local count = 0
	local x0 = math.floor((cx - radius) / GRID) * GRID
	local z0 = math.floor((cz - radius) / GRID) * GRID
	local cells = math.ceil(radius * 2 / GRID) + 1
	local inset = 8
	for iz = 0, cells - 1 do
		local z = z0 + iz * GRID
		local run -- { x, top } of the block being grown along X
		local function flush(endX)
			if run then
				local minCorner = Vector3.new(run.x, BASE_Y - 2, z)
				local maxCorner = Vector3.new(endX, run.top, z + GRID)
				if solid(minCorner + Vector3.new(0, 2, 0), maxCorner + Vector3.new(0, 4, 0)) then
					local block = Instance.new("Part")
					block.Name = "Silhouette"
					block.Size = maxCorner - minCorner
					block.CFrame = CFrame.new((minCorner + maxCorner) / 2)
					block.Anchored = true
					block.CanCollide = false
					block.CanQuery = false
					block.CanTouch = false
					block.CastShadow = false
					block.Color = color
					block.Material = Enum.Material.SmoothPlastic
					block.TopSurface = Enum.SurfaceType.Smooth
					block.BottomSurface = Enum.SurfaceType.Smooth
					block.Parent = model
					count += 1
				end
				run = nil
			end
		end
		for ix = 0, cells - 1 do
			local x = x0 + ix * GRID
			-- The lowest of nine samples, less a margin, is safely underground everywhere in the cell.
			-- Most cells are sea or low ground: one sample in the middle rules those out.
			local low = topAt(x + GRID / 2, z + GRID / 2)
			if low >= BASE_Y + STEP + 7 then
				for ox = 0, 2 do
					for oz = 0, 2 do
						low = math.min(
							low,
							topAt(x + inset * 0.5 + ox * (GRID - inset) / 2, z + inset * 0.5 + oz * (GRID - inset) / 2)
						)
					end
				end
			end
			local top = math.floor((low - 7 - BASE_Y) / STEP) * STEP + BASE_Y
			if top >= BASE_Y + STEP then
				if run and run.top ~= top then
					flush(x)
				end
				run = run or { x = x, top = top }
			else
				flush(x)
			end
			if budget and os.clock() - sliceStart > budget then
				task.wait()
				sliceStart = os.clock()
			end
		end
		flush(x0 + cells * GRID)
	end
	model.Parent = parent
	return model, count
end

return Landform

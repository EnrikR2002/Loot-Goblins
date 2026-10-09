-- A coarse navigation grid over the whole sea, built once from the finished terrain.
--
--   * Each cell remembers how deep the water is (and whether it is land).
--   * Distance-to-land becomes the "shelter" map that calms the swell beside coasts (Sea.lua).
--   * A* finds routes for ships. A deep-hulled patrol ship can only use deep cells, so a skiff
--     that slips through a reef or a shallow channel really does leave it behind.
--
-- The grid is deliberately coarse (CELL studs) and conservative: a cell counts as land if any of
-- five probes finds shallow rock, so paths keep clear of reefs, never graze them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Sea = require(script.Parent.Sea)

local SeaNav = {}

local CELL = 40
local PROBE = 14
local LAND_FLOOR = -1.5 -- A seabed higher than this is land.

local minX, minZ, cols, rows
local depth = {} -- index -> water depth in studs (0 = land)
local shelter = {} -- index -> 0..1
local ready = false

local function index(cx, cz)
	return cz * cols + cx + 1
end

local function cellOf(x, z)
	local cx = math.clamp(math.floor((x - minX) / CELL), 0, cols - 1)
	local cz = math.clamp(math.floor((z - minZ) / CELL), 0, rows - 1)
	return cx, cz
end

local function centerOf(cx, cz)
	return Vector3.new(minX + (cx + 0.5) * CELL, 0, minZ + (cz + 0.5) * CELL)
end

function SeaNav.build(refs)
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	minX, minZ = min.X, min.Z
	cols = math.ceil((max.X - min.X) / CELL)
	rows = math.ceil((max.Z - min.Z) / CELL)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	params.IgnoreWater = true

	local probes = {
		Vector2.new(0, 0),
		Vector2.new(PROBE, 0),
		Vector2.new(-PROBE, 0),
		Vector2.new(0, PROBE),
		Vector2.new(0, -PROBE),
	}
	local landCount = 0
	for cz = 0, rows - 1 do
		for cx = 0, cols - 1 do
			local center = centerOf(cx, cz)
			local shallowest = -math.huge
			for _, probe in ipairs(probes) do
				local hit = workspace:Raycast(
					Vector3.new(center.X + probe.X, 200, center.Z + probe.Y),
					Vector3.new(0, -260, 0),
					params
				)
				local floorY = hit and hit.Position.Y or -40
				shallowest = math.max(shallowest, floorY)
			end
			local d = shallowest > LAND_FLOOR and 0 or -shallowest
			depth[index(cx, cz)] = d
			if d == 0 then
				landCount += 1
			end
		end
		-- Yield now and then so a big map never freezes the server at start-up.
		if cz % 12 == 0 then
			task.wait()
		end
	end

	-- Distance to the nearest land, by a two-pass chamfer transform (in studs).
	local far = 1e9
	local distance = {}
	for i = 1, cols * rows do
		distance[i] = depth[i] == 0 and 0 or far
	end
	local function relax(cx, cz, ox, oz, cost)
		local nx, nz = cx + ox, cz + oz
		if nx >= 0 and nx < cols and nz >= 0 and nz < rows then
			local candidate = distance[index(nx, nz)] + cost
			local i = index(cx, cz)
			if candidate < distance[i] then
				distance[i] = candidate
			end
		end
	end
	for cz = 0, rows - 1 do
		for cx = 0, cols - 1 do
			relax(cx, cz, -1, 0, CELL)
			relax(cx, cz, 0, -1, CELL)
			relax(cx, cz, -1, -1, CELL * 1.414)
			relax(cx, cz, 1, -1, CELL * 1.414)
		end
	end
	for cz = rows - 1, 0, -1 do
		for cx = cols - 1, 0, -1 do
			relax(cx, cz, 1, 0, CELL)
			relax(cx, cz, 0, 1, CELL)
			relax(cx, cz, 1, 1, CELL * 1.414)
			relax(cx, cz, -1, 1, CELL * 1.414)
		end
	end
	for i = 1, cols * rows do
		shelter[i] = math.clamp(1 - distance[i] / Config.SEA_SHELTER_DISTANCE, 0, 1)
	end
	Sea.shelterFn = function(x, z)
		local cx, cz = cellOf(x, z)
		return shelter[index(cx, cz)]
	end
	ready = true
	return { cells = cols * rows, land = landCount }
end

-- Is this point open water a ship with this draft can sit in?
function SeaNav.passable(x, z, draft)
	if not ready then
		return true
	end
	local cx, cz = cellOf(x, z)
	return depth[index(cx, cz)] >= (draft or 1) + 1.8
end

function SeaNav.depthAt(x, z)
	local cx, cz = cellOf(x, z)
	return depth[index(cx, cz)] or 0
end

-- The closest passable cell center to a point (for targets standing on land).
function SeaNav.nearestWater(x, z, draft)
	local cx, cz = cellOf(x, z)
	local need = (draft or 1) + 1.8
	for ring = 0, 30 do
		local best, bestD = nil, math.huge
		for dz = -ring, ring do
			for dx = -ring, ring do
				if math.max(math.abs(dx), math.abs(dz)) == ring then
					local nx, nz = cx + dx, cz + dz
					if nx >= 0 and nx < cols and nz >= 0 and nz < rows and depth[index(nx, nz)] >= need then
						local d = dx * dx + dz * dz
						if d < bestD then
							best, bestD = centerOf(nx, nz), d
						end
					end
				end
			end
		end
		if best then
			return best
		end
	end
	return nil
end

-- A binary min-heap on f-score for the A* open set.
local function heapPush(heap, node, f)
	table.insert(heap, { node = node, f = f })
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent].f <= heap[i].f then
			break
		end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function heapPop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local left, right, smallest = i * 2, i * 2 + 1, i
			if left <= #heap and heap[left].f < heap[smallest].f then
				smallest = left
			end
			if right <= #heap and heap[right].f < heap[smallest].f then
				smallest = right
			end
			if smallest == i then
				break
			end
			heap[smallest], heap[i] = heap[i], heap[smallest]
			i = smallest
		end
	end
	return top.node
end

local function lineClear(a, b, need)
	local steps = math.ceil((b - a).Magnitude / (CELL * 0.5))
	for i = 1, steps - 1 do
		local p = a:Lerp(b, i / steps)
		local cx, cz = cellOf(p.X, p.Z)
		if depth[index(cx, cz)] < need then
			return false
		end
	end
	return true
end

-- A route from `from` to `to` for a hull with this draft: a list of Vector3 waypoints (the
-- last is the goal's nearest water cell), or nil if there is no way through.
function SeaNav.path(from, to, draft)
	if not ready then
		return { to }
	end
	local need = (draft or 1) + 1.8
	local goalWater = SeaNav.nearestWater(to.X, to.Z, draft)
	local startWater = SeaNav.nearestWater(from.X, from.Z, draft)
	if not goalWater or not startWater then
		return nil
	end
	local sx, sz = cellOf(startWater.X, startWater.Z)
	local gx, gz = cellOf(goalWater.X, goalWater.Z)
	local startNode, goalNode = index(sx, sz), index(gx, gz)

	local open, cost, came, closed = {}, { [startNode] = 0 }, {}, {}
	heapPush(open, startNode, 0)
	local expanded = 0
	while #open > 0 and expanded < 6000 do
		local node = heapPop(open)
		if node == goalNode then
			break
		end
		if not closed[node] then
			closed[node] = true
			expanded += 1
			local cx, cz = (node - 1) % cols, (node - 1) // cols
			for oz = -1, 1 do
				for ox = -1, 1 do
					if ox ~= 0 or oz ~= 0 then
						local nx, nz = cx + ox, cz + oz
						if nx >= 0 and nx < cols and nz >= 0 and nz < rows then
							local n = index(nx, nz)
							local d = depth[n]
							-- Diagonals must not clip a land corner.
							local corner = ox ~= 0
								and oz ~= 0
								and (depth[index(cx + ox, cz)] < need or depth[index(cx, cz + oz)] < need)
							if d >= need and not closed[n] and not corner then
								-- Prefer open water: a gentle penalty near coasts.
								local penalty = shelter[n] * 0.8
								local step = (ox ~= 0 and oz ~= 0 and 1.414 or 1) * (1 + penalty)
								local newCost = cost[node] + step
								if not cost[n] or newCost < cost[n] then
									cost[n] = newCost
									came[n] = node
									local hx, hz = nx - gx, nz - gz
									heapPush(open, n, newCost + math.sqrt(hx * hx + hz * hz))
								end
							end
						end
					end
				end
			end
		end
	end
	if not came[goalNode] and goalNode ~= startNode then
		return nil
	end
	-- Rebuild, then string-pull: skip waypoints whenever the straight line is clear.
	local nodes = { goalNode }
	local walk = goalNode
	while came[walk] do
		walk = came[walk]
		table.insert(nodes, 1, walk)
	end
	local points = {}
	for _, n in ipairs(nodes) do
		table.insert(points, centerOf((n - 1) % cols, (n - 1) // cols))
	end
	local smooth = { from }
	local anchor = from
	local i = 1
	while i <= #points do
		local furthest = i
		for j = #points, i, -1 do
			if lineClear(anchor, points[j], need) then
				furthest = j
				break
			end
		end
		table.insert(smooth, points[furthest])
		anchor = points[furthest]
		i = furthest + 1
	end
	return smooth
end

return SeaNav

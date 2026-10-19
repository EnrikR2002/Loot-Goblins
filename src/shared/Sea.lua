-- The sea as math: waves, currents, wind and storm influence, all pure functions
-- of position and time. Boats sample them every frame. Nothing here touches the
-- Terrain water, which is only the pretty surface that boats appear to float on.
--
--   waveAt(x, z, t)    surface height in studs above sea level
--   currentAt(x, z)    horizontal flow in studs/s (wind drift + streams + whirlpools)
--   stormAt(x, z)      0..1 storm strength
--   shelterAt(x, z)    0..1, how protected the water is by nearby land (SeaNav fills it)
--
-- Swell is calmer beside land and wild inside a storm, so the geography decides
-- where sailing is easy: sheltered channels are safe, open water is not.
--
-- This module is shared because a boat's physics run on whichever machine owns the hull:
-- the server for empty and AI boats, the driver's own client for a boat being driven
-- (BoatSim.lua). Both must float it on the same sea. The server fills in the map's streams,
-- whirlpools and shelter grid and exports them once (Sea.export); a client imports that and
-- then follows the live weather through two workspace attributes (Sea.follow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Sea = {}

Sea.storms = {} -- { { x, z, r, s } } written by Storms.lua each frame (server) or Sea.follow (client)
Sea.streams = {} -- Rivers in the sea.
Sea.whirls = {} -- Whirlpools.
Sea.shelterFn = nil -- (x, z) -> 0..1, set by SeaNav once the map exists.
Sea.rough = 0 -- Global extra roughness (Heat's FRENZY raises it).
-- V13.2, WORLD CHAOS on the water (server/WorldChaos.lua writes these; a client follows them from workspace.ChaosSea):
--   waves   rogue waves: a long ridge of water travelling across the sea. Boats float on it (waveAt), it carries
--           whatever is on its face along with it (currentAt), and it breaks to nothing beside land (shelter).
--           { x, z (where its middle starts), dx, dz (its heading), speed, born, life, height, width (its thickness),
--             half (half its length along the front) }
--   whirls  moving whirlpools: water circles and is sucked toward the eye, and the surface dips into a funnel there.
--           { x, z (where it starts), vx, vz (how it wanders), born, life, r, spin, pull, dip }
-- Both are pure functions of time once published, so every machine floats every boat on the same water.
Sea.chaos = { waves = {}, whirls = {} }
Sea.clock = function()
	return workspace:GetServerTimeNow()
end

local TWO_PI = math.pi * 2
-- Three crossing wave trains. speed is how fast the pattern travels, in studs/s.
local TRAINS = {
	{ dx = 0.866, dz = 0.5, length = 96, amp = 1.0, speed = 10 },
	{ dx = 0.29, dz = -0.957, length = 54, amp = 0.55, speed = 12 },
	{ dx = -0.72, dz = 0.694, length = 29, amp = 0.28, speed = 8 },
}

function Sea.stormAt(x, z)
	local best = 0
	for _, storm in ipairs(Sea.storms) do
		local dx, dz = x - storm.x, z - storm.z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < storm.r then
			local edge = math.min(1, (1 - distance / storm.r) * 2.2)
			best = math.max(best, storm.s * edge)
		end
	end
	return best
end

function Sea.shelterAt(x, z)
	local fn = Sea.shelterFn
	return fn and fn(x, z) or 0
end

-- How strong the swell is here, as a multiplier.
function Sea.waveScale(x, z)
	local storm = Sea.stormAt(x, z)
	local calm = 1 - Sea.shelterAt(x, z) * (1 - Config.SEA_SHELTER_CALM)
	return Config.SEA_WAVE_AMP * (1 + Config.SEA_STORM_WAVES * storm + Sea.rough) * calm
end

-- How much of a chaos event is there at time t (it swells in and dies away): 0..1.
local function envelope(born, life, t)
	local age = t - born
	if age < 0 or age > life then
		return 0
	end
	return math.min(1, age / 1.5, (life - age) / 2)
end

-- V13.2: the chaos events' share of the surface height and of the water's flow at (x, z, t).
function Sea.chaosAt(x, z, t)
	local height, fx, fz = 0, 0, 0
	local chaos = Sea.chaos
	if #chaos.waves == 0 and #chaos.whirls == 0 then
		return 0, 0, 0
	end
	for _, w in ipairs(chaos.waves) do
		local k = envelope(w.born, w.life, t)
		if k > 0 then
			local travelled = w.speed * (t - w.born)
			local cx, cz = w.x + w.dx * travelled, w.z + w.dz * travelled
			local along = (x - cx) * w.dx + (z - cz) * w.dz
			local across = math.abs(-(x - cx) * w.dz + (z - cz) * w.dx)
			if math.abs(along) < w.width * 3 and across < w.half then
				local edge = math.clamp((w.half - across) / (w.half * 0.25), 0, 1)
				-- It breaks against land: right beside a shore it is a ripple, in a sheltered channel half its height.
				local open = (1 - Sea.shelterAt(x, z) * 0.8) ^ 1.5
				local profile = math.exp(-(along / w.width) ^ 2) * edge * open * k
				height += w.height * profile
				-- The face carries what is on it the way the wave goes (a boat on it surfs).
				local carry = w.speed * 0.6 * profile
				fx += w.dx * carry
				fz += w.dz * carry
			end
		end
	end
	for _, wh in ipairs(chaos.whirls) do
		local k = envelope(wh.born, wh.life, t)
		if k > 0 then
			local age = t - wh.born
			local cx, cz = wh.x + wh.vx * age, wh.z + wh.vz * age
			local ox, oz = x - cx, z - cz
			local distance = math.sqrt(ox * ox + oz * oz)
			if distance < wh.r and distance > 0.5 then
				local strength = math.sin(math.pi * math.min(1, distance / wh.r * 1.15)) * k
				local ux, uz = ox / distance, oz / distance
				fx += (-uz * wh.spin - ux * wh.pull) * strength
				fz += (ux * wh.spin - uz * wh.pull) * strength
				local rim = 1 - distance / wh.r
				height -= wh.dip * rim * rim * k
			end
		end
	end
	return height, fx, fz
end

-- Just the flow part (BoatSim: a Wavebreaker surfs a rogue wave harder).
function Sea.chaosFlow(x, z, t)
	local _, fx, fz = Sea.chaosAt(x, z, t or Sea.clock())
	return fx, fz
end

function Sea.waveAt(x, z, t)
	local height = 0
	for _, wave in ipairs(TRAINS) do
		local phase = ((wave.dx * x + wave.dz * z) - wave.speed * t) * TWO_PI / wave.length
		height += wave.amp * math.sin(phase)
	end
	height *= Sea.waveScale(x, z)
	if #Sea.chaos.waves > 0 or #Sea.chaos.whirls > 0 then
		height += (Sea.chaosAt(x, z, t))
	end
	return height
end

-- Distance from a point to a segment on the XZ plane, and the 0..1 position along it.
local function segmentDistance(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local lengthSq = abx * abx + abz * abz
	local along = lengthSq > 0 and math.clamp(((px - ax) * abx + (pz - az) * abz) / lengthSq, 0, 1) or 0
	local cx, cz = ax + abx * along, az + abz * along
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2), along
end

-- A river of fast water. a, b: Vector3 ends. speed flows from a to b.
function Sea.addStream(name, a, b, halfWidth, speed)
	local direction = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	table.insert(Sea.streams, {
		name = name,
		ax = a.X,
		az = a.Z,
		bx = b.X,
		bz = b.Z,
		dx = direction.X,
		dz = direction.Z,
		halfWidth = halfWidth,
		speed = speed,
	})
end

-- A whirlpool: water circles the center and is sucked toward it.
function Sea.addWhirl(name, center, radius, spin, pull)
	table.insert(Sea.whirls, { name = name, x = center.X, z = center.Z, r = radius, spin = spin, pull = pull })
end

-- t (optional, V13.2): the time, for the chaos events' flow (now if not given).
function Sea.currentAt(x, z, t)
	local storm = Sea.stormAt(x, z)
	local drift = Config.SEA_WIND_DRIFT * (0.5 + storm * 2.4 + Sea.rough * 2)
	local vx, vz = Config.SEA_WIND.X * drift, Config.SEA_WIND.Z * drift
	for _, stream in ipairs(Sea.streams) do
		local distance = segmentDistance(x, z, stream.ax, stream.az, stream.bx, stream.bz)
		if distance < stream.halfWidth then
			local falloff = 1 - (distance / stream.halfWidth) ^ 2
			vx += stream.dx * stream.speed * falloff
			vz += stream.dz * stream.speed * falloff
		end
	end
	for _, whirl in ipairs(Sea.whirls) do
		local ox, oz = x - whirl.x, z - whirl.z
		local distance = math.sqrt(ox * ox + oz * oz)
		if distance < whirl.r and distance > 0.5 then
			-- Strongest at mid-radius, calm in the eye and at the rim.
			local strength = math.sin(math.pi * distance / whirl.r)
			local ux, uz = ox / distance, oz / distance
			-- Counter-clockwise spin plus a pull toward the eye.
			vx += (-uz * whirl.spin - ux * whirl.pull) * strength
			vz += (ux * whirl.spin - uz * whirl.pull) * strength
		end
	end
	if #Sea.chaos.waves > 0 or #Sea.chaos.whirls > 0 then
		local _, fx, fz = Sea.chaosAt(x, z, t or Sea.clock())
		vx += fx
		vz += fz
	end
	return vx, vz
end

function Sea.reset()
	table.clear(Sea.storms)
	Sea.rough = 0
	Sea.setChaos(nil)
end

-- V13.2: the chaos events on the water, as one string (server: WorldChaos publishes it as workspace.ChaosSea). Every
-- number is rounded: the events are functions of time, so this only changes when one starts or ends.
--   "W,x,z,dx,dz,speed,born,life,height,width,half;H,x,z,vx,vz,born,life,r,spin,pull,dip;..."
function Sea.encodeChaos(chaos)
	local parts = {}
	for _, w in ipairs(chaos.waves) do
		table.insert(
			parts,
			string.format(
				"W,%.1f,%.1f,%.4f,%.4f,%.1f,%.2f,%.1f,%.1f,%.1f,%.1f",
				w.x,
				w.z,
				w.dx,
				w.dz,
				w.speed,
				w.born,
				w.life,
				w.height,
				w.width,
				w.half
			)
		)
	end
	for _, h in ipairs(chaos.whirls) do
		table.insert(
			parts,
			string.format(
				"H,%.1f,%.1f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f",
				h.x,
				h.z,
				h.vx,
				h.vz,
				h.born,
				h.life,
				h.r,
				h.spin,
				h.pull,
				h.dip
			)
		)
	end
	return table.concat(parts, ";")
end

function Sea.decodeChaos(text)
	local chaos = { waves = {}, whirls = {} }
	for _, entry in ipairs(string.split(text or "", ";")) do
		local v = string.split(entry, ",")
		local n = {}
		for i = 2, #v do
			n[i - 1] = tonumber(v[i]) or 0
		end
		if v[1] == "W" and #n >= 10 then
			table.insert(chaos.waves, {
				x = n[1],
				z = n[2],
				dx = n[3],
				dz = n[4],
				speed = n[5],
				born = n[6],
				life = n[7],
				height = n[8],
				width = n[9],
				half = n[10],
			})
		elseif v[1] == "H" and #n >= 10 then
			table.insert(chaos.whirls, {
				x = n[1],
				z = n[2],
				vx = n[3],
				vz = n[4],
				born = n[5],
				life = n[6],
				r = n[7],
				spin = n[8],
				pull = n[9],
				dip = n[10],
			})
		end
	end
	return chaos
end

function Sea.setChaos(chaos)
	Sea.chaos = chaos or { waves = {}, whirls = {} }
end

-- Server -> client ------------------------------------------------------------------------
-- The parts of the sea that never change after the map is built, as plain tables.
-- shelter: { minX, minZ, cols, rows, cell, data } where data is one digit (0-9) per grid cell.
function Sea.export(shelter)
	return { streams = Sea.streams, whirls = Sea.whirls, shelter = shelter }
end

function Sea.import(data)
	Sea.streams = data.streams or {}
	Sea.whirls = data.whirls or {}
	local grid = data.shelter
	if grid and grid.data then
		local bytes = grid.data
		local zero = string.byte("0")
		Sea.shelterFn = function(x, z)
			local cx = math.clamp(math.floor((x - grid.minX) / grid.cell), 0, grid.cols - 1)
			local cz = math.clamp(math.floor((z - grid.minZ) / grid.cell), 0, grid.rows - 1)
			return ((string.byte(bytes, cz * grid.cols + cx + 1) or zero) - zero) / 9
		end
	end
end

-- Client: keep the storm cells and the global roughness in step with what the server
-- publishes (workspace.StormData is "time;id,x,z,r,strength,vx,vz,isFog;..." four times a
-- second; fog cells are not storms).
function Sea.follow()
	local function readStorms()
		local fields = string.split(workspace:GetAttribute("StormData") or "", ";")
		local list = {}
		for i = 2, #fields do
			local v = string.split(fields[i], ",")
			if tonumber(v[1]) and tonumber(v[8]) ~= 1 then
				table.insert(list, {
					x = tonumber(v[2]) or 0,
					z = tonumber(v[3]) or 0,
					r = tonumber(v[4]) or 1,
					s = tonumber(v[5]) or 0,
				})
			end
		end
		Sea.storms = list
	end
	local function readRough()
		Sea.rough = workspace:GetAttribute("SeaRough") or 0
	end
	local function readChaos()
		Sea.setChaos(Sea.decodeChaos(workspace:GetAttribute("ChaosSea") or ""))
	end
	workspace:GetAttributeChangedSignal("StormData"):Connect(readStorms)
	workspace:GetAttributeChangedSignal("SeaRough"):Connect(readRough)
	workspace:GetAttributeChangedSignal("ChaosSea"):Connect(readChaos)
	readStorms()
	readRough()
	readChaos()
end

return Sea

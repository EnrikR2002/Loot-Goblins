-- Regional alerts (V7): the islands know each other.
--
-- Taking a treasure puts its island on guard, and the islands it is linked to (Config.ALERT.LINKS:
-- allies by geography and by who they answer to) a little less. An island on guard is a harder island
-- for a while, and what it does is the opposite of what a global Heat tier does:
--   * what lives there wakes from farther away (Creatures asks Alerts.wakeFactor), so a creature
--     that was asleep at the edge of its range is up before you arrive;
--   * at level 2 the Navy comes: every patrol ship within range stops what it was doing and sails to
--     that island's waters for a while (Navy.distract). SO the water everywhere else is quieter: a
--     robbery in the Navy's own waters is a window for a thief on the far side of the map.
-- Levels decay on their own (Config.ALERT.DECAY), so nothing stays hard because of one robbery long
-- ago. They are published as workspace attributes ("Alert_<island id>", 0 to 3) for the map to tint
-- and the HUD to read. Global Heat is untouched: it still decides the hunters, the blockers and the
-- tempest. An alert decides what the ISLANDS and the patrol do about a theft in their neighbourhood.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Net = require(script.Parent.Net)
local Navy = require(script.Parent.Navy)

local Alerts = {}

local A = Config.ALERT
local raw = {} -- island id -> number (0 to 3)
local published = {}
local callAt = {} -- island id -> time the Navy was last called there

local function now()
	return workspace:GetServerTimeNow()
end

function Alerts.level(id)
	return math.min(3, math.floor(raw[id] or 0))
end

-- How much farther a creature of this island notices goblins.
function Alerts.wakeFactor(id)
	return 1 + A.WAKE_PER_LEVEL * Alerts.level(id)
end

local function publish(id)
	local level = Alerts.level(id)
	if published[id] ~= level then
		published[id] = level
		workspace:SetAttribute("Alert_" .. id, level > 0 and level or nil)
	end
end

local function callNavy(id, level)
	local island = Archipelago.byId[id]
	local t = now()
	if not island or t - (callAt[id] or -math.huge) < A.CALL_GAP then
		return
	end
	callAt[id] = t
	local turned = Navy.distract(Vector3.new(island.x, 0, island.z), A.NAVY_RANGE, A.NAVY_TIME)
	if turned > 0 then
		Net.feed(
			string.format(
				"The Navy is drawn to %s: %d ship%s turn that way.",
				island.name,
				turned,
				turned > 1 and "s" or ""
			),
			Color3.fromRGB(255, 150, 90)
		)
		Net.message(
			island.name .. " IS ON GUARD  -  THE PATROL IS OUT OF POSITION ELSEWHERE",
			3.2,
			Color3.fromRGB(255, 190, 90)
		)
	end
	return level
end

local function raise(id, amount, source)
	local before = Alerts.level(id)
	raw[id] = math.min(3.99, (raw[id] or 0) + amount)
	local after = Alerts.level(id)
	publish(id)
	if after > before then
		local island = Archipelago.byId[id]
		if island then
			Net.broadcast("AlertRaised", { island = id, level = after, source = source })
		end
		if after >= A.NAVY_LEVEL then
			callNavy(id, after)
		end
	end
end

-- A treasure was taken from its spot on this island.
function Alerts.stolen(islandId, player)
	local island = Archipelago.byId[islandId]
	if not island then
		return
	end
	raise(islandId, A.STEAL, player.DisplayName)
	for other, weight in pairs(A.LINKS[islandId] or {}) do
		raise(other, A.STEAL * weight, player.DisplayName)
	end
	Net.feed(
		string.format("%s is on guard (alert %d), and so are its neighbours.", island.name, Alerts.level(islandId)),
		Color3.fromRGB(255, 200, 100)
	)
end

function Alerts.tick(dt)
	for id, value in pairs(raw) do
		if value > 0 then
			raw[id] = math.max(0, value - A.DECAY * dt)
			publish(id)
		end
	end
end

function Alerts.reset()
	for id in pairs(raw) do
		raw[id] = 0
		publish(id)
	end
	table.clear(callAt)
end

return Alerts

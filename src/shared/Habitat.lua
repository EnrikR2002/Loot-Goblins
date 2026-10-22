-- The pet sanctuary and pet expeditions (V13.3, The Living Port), as data and pure functions over a saved profile.
-- Shared, so the server (server/Sanctuary.lua) decides with the same rows the client's sanctuary panel shows, and the
-- tests (tests/luau/Specs/HabitatSpec.lua) can run every case.
--
-- THE SANCTUARY is a little floating isle over the Port, one for every goblin in the server, where the pets they own
-- wander about (client/Sanctuary.lua). It can be made a goblin's own, modestly: a THEME (the ground and its colours),
-- four FEATURES with a few levels each (the pond, the nests, the lights, the expedition dock), and DECORATIONS in four
-- spots. Everything is bought with Shinies, once, and is only how the isle looks, except the dock's level, which is the
-- number of expeditions a goblin can have out at once (one to three).
--
-- EXPEDITIONS: send a pet you own on a trip; it comes back after the trip's hours on the server's clock, whether you
-- are online or not, with the trip's Shinies. Every pet earns the same (a rare pet is never a better earner), and a
-- goblin collects at most Config.EXPEDITIONS.DAILY_CAP a UTC day however many pets they have. A pet that is away does
-- not follow anyone or appear on the isle; it can be called back early for nothing. An expedition is collected once:
-- collecting removes it from the profile in the same change that pays it.
local Config = require(script.Parent:WaitForChild("Config"))
local Seasons = require(script.Parent:WaitForChild("Seasons"))

local Habitat = {}

local rgb = Color3.fromRGB

-- Themes: the isle's ground, rim and grass colours.
Habitat.THEMES = {
	{
		id = "meadow",
		name = "Meadow",
		price = nil,
		grass = rgb(118, 186, 84),
		rim = rgb(150, 120, 86),
		rock = rgb(120, 108, 98),
		accent = rgb(255, 230, 120),
	},
	{
		id = "beach",
		name = "Beach Cove",
		price = 150,
		grass = rgb(236, 214, 160),
		rim = rgb(206, 180, 128),
		rock = rgb(170, 150, 120),
		accent = rgb(90, 200, 220),
	},
	{
		id = "blossom",
		name = "Blossom Garden",
		price = 220,
		grass = rgb(150, 206, 110),
		rim = rgb(250, 190, 210),
		rock = rgb(170, 130, 140),
		accent = rgb(255, 150, 190),
	},
	{
		id = "crystal",
		name = "Crystal Grotto",
		price = 300,
		grass = rgb(120, 110, 170),
		rim = rgb(170, 150, 240),
		rock = rgb(90, 80, 130),
		accent = rgb(150, 240, 255),
	},
	{
		id = "haunted",
		name = "Haunted Grove",
		price = 300,
		grass = rgb(70, 90, 80),
		rim = rgb(60, 54, 66),
		rock = rgb(50, 46, 56),
		accent = rgb(130, 255, 200),
	},
}

-- Features: level 1 (or 0) is free; each level after costs its price. The dock's level is the expedition slots.
Habitat.FEATURES = {
	{
		id = "pond",
		name = "Pond",
		levels = { "Puddle", "Lily Pond", "Lagoon & Fountain" },
		prices = { nil, 120, 260 },
		start = 1,
	},
	{
		id = "nest",
		name = "Nests",
		levels = { "A Bed", "Three Beds", "The Burrow Mound" },
		prices = { nil, 90, 200 },
		start = 1,
	},
	{
		id = "lights",
		name = "Lights",
		levels = { "Lanterns", "String Lights & Fireflies" },
		prices = { 80, 180 },
		start = 0,
	},
	{
		id = "dock",
		name = "Expedition Dock",
		levels = { "Rowboat (1 expedition)", "Sloop (2 at once)", "Little Galleon (3 at once)" },
		prices = { nil, 220, 480 },
		start = 1,
	},
}

-- Decorations: owned once each, placed in one of SOCKETS spots.
Habitat.SOCKETS = 4
Habitat.DECOR = {
	{ id = "flowers", name = "Flower Bed", price = 30 },
	{ id = "mushrooms", name = "Mushroom Ring", price = 40 },
	{ id = "palm", name = "Palm Tree", price = 50 },
	{ id = "torches", name = "Tiki Torches", price = 60 },
	{ id = "hammock", name = "Hammock", price = 80 },
	{ id = "totem", name = "Goblin Totem", price = 100 },
	{ id = "treasure", name = "Treasure Pile", price = 120 },
	{ id = "statue", name = "Your Statue", price = 150 },
}

local function index(list)
	local out = {}
	for _, row in ipairs(list) do
		out[row.id] = row
	end
	return out
end
Habitat.THEME_BY_ID = index(Habitat.THEMES)
Habitat.FEATURE_BY_ID = index(Habitat.FEATURES)
Habitat.DECOR_BY_ID = index(Habitat.DECOR)
Habitat.TRIP_BY_ID = index(Config.EXPEDITIONS.TRIPS)

local function result(ok, code, extra)
	local out = extra or {}
	out.ok = ok
	out.code = code
	return out
end

-- The isle ---------------------------------------------------------------------------------------------------------------
function Habitat.level(profile, featureId)
	local feature = Habitat.FEATURE_BY_ID[featureId]
	local level = profile.sanctuary.levels[featureId]
	if type(level) ~= "number" then
		return feature and feature.start or 0
	end
	return level
end

function Habitat.ownsTheme(profile, themeId)
	local theme = Habitat.THEME_BY_ID[themeId]
	return theme ~= nil and (theme.price == nil or profile.sanctuary.owned["theme_" .. themeId] == true)
end

-- Buying. kind "theme" (id) | "feature" (id: the next level) | "decor" (id, socket: where to put it, or the first free).
-- Codes: ok, unknown, owned, max, funds (short = how many more), socket.
function Habitat.buy(profile, kind, id, socket)
	local s = profile.sanctuary
	local price, apply
	if kind == "theme" then
		local theme = Habitat.THEME_BY_ID[id]
		if not theme then
			return result(false, "unknown")
		end
		if Habitat.ownsTheme(profile, id) then
			return result(false, "owned")
		end
		price = theme.price
		apply = function()
			s.owned["theme_" .. id] = true
			s.theme = id
		end
	elseif kind == "feature" then
		local feature = Habitat.FEATURE_BY_ID[id]
		if not feature then
			return result(false, "unknown")
		end
		-- levels[n] names level n and prices[n] is what reaching it costs (nil: where it starts, free).
		local nextLevel = Habitat.level(profile, id) + 1
		if nextLevel > #feature.levels then
			return result(false, "max")
		end
		price = feature.prices[nextLevel]
		if price == nil then
			return result(false, "unknown")
		end
		apply = function()
			s.levels[id] = nextLevel
		end
	elseif kind == "decor" then
		local decor = Habitat.DECOR_BY_ID[id]
		if not decor then
			return result(false, "unknown")
		end
		if s.owned["decor_" .. id] then
			return result(false, "owned")
		end
		if
			socket ~= nil and (type(socket) ~= "number" or socket < 1 or socket > Habitat.SOCKETS or socket % 1 ~= 0)
		then
			return result(false, "socket")
		end
		price = decor.price
		apply = function()
			s.owned["decor_" .. id] = true
			local spot = socket
			if not spot then
				for i = 1, Habitat.SOCKETS do
					if (s.decor[i] or "") == "" then
						spot = i
						break
					end
				end
			end
			if spot then
				Habitat.place(profile, spot, id)
			end
		end
	else
		return result(false, "unknown")
	end
	if profile.shinies < price then
		return result(false, "funds", { short = price - profile.shinies, price = price })
	end
	profile.shinies -= price
	apply()
	return result(true, "ok", { price = price, balance = profile.shinies })
end

-- Wear a theme you own.
function Habitat.setTheme(profile, themeId)
	if not Habitat.THEME_BY_ID[themeId] then
		return result(false, "unknown")
	end
	if not Habitat.ownsTheme(profile, themeId) then
		return result(false, "notowned")
	end
	profile.sanctuary.theme = themeId
	return result(true, "ok")
end

-- Put an owned decoration in a spot (moving it if it was elsewhere); id "" or nil empties the spot.
function Habitat.place(profile, socket, decorId)
	local s = profile.sanctuary
	if type(socket) ~= "number" or socket < 1 or socket > Habitat.SOCKETS or socket % 1 ~= 0 then
		return result(false, "socket")
	end
	if decorId == nil or decorId == "" then
		s.decor[socket] = ""
		return result(true, "ok")
	end
	if not Habitat.DECOR_BY_ID[decorId] then
		return result(false, "unknown")
	end
	if not s.owned["decor_" .. decorId] then
		return result(false, "notowned")
	end
	for i = 1, Habitat.SOCKETS do
		if s.decor[i] == decorId then
			s.decor[i] = ""
		end
	end
	s.decor[socket] = decorId
	return result(true, "ok")
end

-- The pets shown on the isle: owned (owns(petId) -> bool), not repeated, at most Config.PET_ISLES.RESIDENTS.
function Habitat.setResidents(profile, list, owns)
	local out, seen = {}, {}
	for _, id in ipairs(type(list) == "table" and list or {}) do
		if type(id) == "string" and not seen[id] and owns(id) and #out < Config.PET_ISLES.RESIDENTS then
			seen[id] = true
			table.insert(out, id)
		end
	end
	profile.sanctuary.residents = out
	return result(true, "ok", { residents = out })
end

-- Expeditions ------------------------------------------------------------------------------------------------------------
function Habitat.slots(profile)
	return math.clamp(Habitat.level(profile, "dock"), 1, 3)
end

-- Which pets are away (a set).
function Habitat.away(profile)
	local out = {}
	for _, e in ipairs(profile.expeditions.list) do
		out[e.pet] = true
	end
	return out
end

local function dayOf(profile, unix)
	local x = profile.expeditions
	local day = Seasons.period("day", unix)
	if x.day ~= day then
		x.day = day
		x.collected = 0
	end
	return x
end

-- Send `petId` (owned: owns is true) on trip `tripId`. Codes: ok, unknown, notowned, away, full.
function Habitat.send(profile, petId, tripId, unix, owned)
	local trip = Habitat.TRIP_BY_ID[tripId]
	if not trip or type(petId) ~= "string" then
		return result(false, "unknown")
	end
	if not owned then
		return result(false, "notowned")
	end
	local x = profile.expeditions
	if Habitat.away(profile)[petId] then
		return result(false, "away")
	end
	if #x.list >= Habitat.slots(profile) then
		return result(false, "full")
	end
	local id = x.nextId
	x.nextId = id + 1
	local entry =
		{ id = id, pet = petId, trip = tripId, at = math.floor(unix), back = math.floor(unix + trip.hours * 3600) }
	table.insert(x.list, entry)
	return result(true, "ok", { expedition = entry })
end

-- Bring expedition `id` home. Before it is back: "early" (nothing happens). After: it is removed and paid, up to the
-- day's cap. Returns { ok, code, shinies, capped, pet, trip }. Codes: ok, unknown, early.
function Habitat.collect(profile, id, unix)
	local x = dayOf(profile, unix)
	for i, e in ipairs(x.list) do
		if e.id == id then
			if unix < e.back then
				return result(false, "early", { left = e.back - unix })
			end
			table.remove(x.list, i)
			local trip = Habitat.TRIP_BY_ID[e.trip]
			local want = trip and trip.shinies or 0
			local room = math.max(0, Config.EXPEDITIONS.DAILY_CAP - x.collected)
			local pay = math.min(want, room)
			x.collected += pay
			profile.shinies += pay
			profile.stats.expeditions = (profile.stats.expeditions or 0) + 1
			return result(true, "ok", { shinies = pay, capped = pay < want, pet = e.pet, trip = e.trip })
		end
	end
	return result(false, "unknown")
end

-- Call a pet back early: no reward, the slot is free again. Codes: ok, unknown.
function Habitat.recall(profile, id)
	local x = profile.expeditions
	for i, e in ipairs(x.list) do
		if e.id == id then
			table.remove(x.list, i)
			return result(true, "ok", { pet = e.pet })
		end
	end
	return result(false, "unknown")
end

-- For the client: every expedition with its seconds left, the slots, and today's haul and cap.
function Habitat.view(profile, unix)
	local x = dayOf(profile, unix)
	local list = {}
	for _, e in ipairs(x.list) do
		local trip = Habitat.TRIP_BY_ID[e.trip]
		table.insert(list, {
			id = e.id,
			pet = e.pet,
			trip = e.trip,
			name = trip and trip.name or e.trip,
			left = math.max(0, e.back - unix),
			total = trip and trip.hours * 3600 or 1,
			shinies = trip and trip.shinies or 0,
		})
	end
	return { list = list, slots = Habitat.slots(profile), today = x.collected, cap = Config.EXPEDITIONS.DAILY_CAP }
end

return Habitat

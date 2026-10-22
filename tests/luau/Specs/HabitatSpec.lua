-- V13.3: the pet sanctuary's goods and pet expeditions (shared/Habitat.lua): buying and placing, the residents, and
-- expeditions on the server's clock: slots, early and late collection, the daily cap, paying once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Habitat = require(Shared.Habitat)
local ProfileSchema = require(ServerScriptService:WaitForChild("LootGoblinsServer").ProfileSchema)

local HOUR, DAY = 3600, 86400
local NOW = 20747 * DAY + 2 * HOUR

local function fresh(shinies)
	local profile = ProfileSchema.load(nil, nil, 0)
	profile.shinies = shinies or 0
	return profile
end

return function(t)
	t.test("themes, feature levels and decorations: bought once, in order, never on credit", function()
		local profile = fresh(1000)
		t.eq(Habitat.buy(profile, "theme", "meadow").code, "owned", "the free theme is owned")
		t.ok(Habitat.buy(profile, "theme", "beach").ok, "buy a theme")
		t.eq(profile.sanctuary.theme, "beach", "and wear it")
		t.eq(Habitat.buy(profile, "theme", "beach").code, "owned", "not twice")
		t.ok(Habitat.setTheme(profile, "meadow").ok, "back to the meadow")
		t.eq(Habitat.setTheme(profile, "haunted").code, "notowned", "a theme not bought")
		t.eq(Habitat.level(profile, "dock"), 1, "the dock starts at the rowboat")
		t.eq(Habitat.level(profile, "lights"), 0, "no lights at first")
		t.ok(Habitat.buy(profile, "feature", "lights").ok, "lanterns")
		t.ok(Habitat.buy(profile, "feature", "lights").ok, "string lights")
		t.eq(Habitat.buy(profile, "feature", "lights").code, "max", "no third level")
		t.ok(Habitat.buy(profile, "feature", "dock").ok, "a sloop")
		t.eq(Habitat.slots(profile), 2, "two expeditions at once")
		t.eq(Habitat.buy(profile, "feature", "nonsense").code, "unknown", "unknown")
		local poor = fresh(10)
		local refused = Habitat.buy(poor, "decor", "statue")
		t.eq(refused.code, "funds", "not enough Shinies")
		t.eq(refused.short, 140, "and how many more")
		t.eq(poor.shinies, 10, "nothing taken")
		t.ok(Habitat.buy(profile, "decor", "palm").ok, "a palm")
		t.eq(profile.sanctuary.decor[1], "palm", "goes in the first free spot")
		t.ok(Habitat.buy(profile, "decor", "hammock", 3).ok, "a hammock in spot 3")
		t.eq(profile.sanctuary.decor[3], "hammock", "spot 3")
		t.ok(Habitat.place(profile, 4, "palm").ok, "move the palm")
		t.eq(profile.sanctuary.decor[1], "", "it left spot 1")
		t.eq(profile.sanctuary.decor[4], "palm", "for spot 4")
		t.eq(Habitat.place(profile, 2, "statue").code, "notowned", "only what you own")
		t.eq(Habitat.place(profile, 9, "palm").code, "socket", "only real spots")
		t.ok(Habitat.place(profile, 4, "").ok, "empty a spot")
		t.eq(Habitat.buy(profile, "decor", "palm").code, "owned", "one of each")
	end)

	t.test("the residents are pets you own, once each, up to the isle's limit", function()
		local profile = fresh()
		local owned = { Crab = true, Gull = true, Inky = true }
		Habitat.setResidents(profile, { "Crab", "Crab", "Whelp", "Gull", 7 }, function(id)
			return owned[id] == true
		end)
		t.eq(#profile.sanctuary.residents, 2, "Crab and Gull")
		local many = {}
		for i = 1, 30 do
			many[i] = "Pet" .. i
		end
		Habitat.setResidents(profile, many, function()
			return true
		end)
		t.eq(#profile.sanctuary.residents, Config.PET_ISLES.RESIDENTS, "capped")
	end)

	t.test("an expedition comes back on the server's clock and is paid once", function()
		local profile = fresh()
		local trip = Config.EXPEDITIONS.TRIPS[1]
		t.eq(Habitat.send(profile, "Crab", trip.id, NOW, false).code, "notowned", "only a pet you own")
		local sent = Habitat.send(profile, "Crab", trip.id, NOW, true)
		t.ok(sent.ok, sent.code)
		t.eq(Habitat.send(profile, "Crab", "reef", NOW, true).code, "away", "a pet on one trip at a time")
		t.eq(Habitat.send(profile, "Gull", "reef", NOW, true).code, "full", "one slot with a rowboat")
		t.ok(Habitat.away(profile).Crab, "the crab is away")
		local id = sent.expedition.id
		local early = Habitat.collect(profile, id, NOW + 60)
		t.eq(early.code, "early", "not back yet")
		t.ok(early.left > 0, "and how long")
		local back = Habitat.collect(profile, id, NOW + trip.hours * HOUR)
		t.ok(back.ok, "back")
		t.eq(back.shinies, trip.shinies, "paid the trip")
		t.eq(profile.shinies, trip.shinies, "into the balance")
		t.eq(profile.stats.expeditions, 1, "counted")
		t.eq(Habitat.collect(profile, id, NOW + DAY).code, "unknown", "never twice")
		t.eq(profile.shinies, trip.shinies, "still paid once")
		t.ok(not Habitat.away(profile).Crab, "home again")
	end)

	t.test("expeditions pay at most the daily cap, whatever the pets; a new day pays again", function()
		local profile = fresh(10000)
		Habitat.buy(profile, "feature", "dock")
		Habitat.buy(profile, "feature", "dock")
		t.eq(Habitat.slots(profile), 3, "three slots with the galleon")
		local start = profile.shinies
		local long = "voyage"
		local hours = 0
		for _, trip in ipairs(Config.EXPEDITIONS.TRIPS) do
			if trip.id == long then
				hours = trip.hours
			end
		end
		local ids = {}
		for _, pet in ipairs({ "Crab", "Whelp", "Levi" }) do
			table.insert(ids, Habitat.send(profile, pet, long, NOW, true).expedition.id)
		end
		local paid = 0
		for _, id in ipairs(ids) do
			paid += Habitat.collect(profile, id, NOW + hours * HOUR).shinies
		end
		t.eq(paid, Config.EXPEDITIONS.DAILY_CAP, "three long voyages pay the cap, not 60")
		t.eq(profile.shinies - start, Config.EXPEDITIONS.DAILY_CAP, "exactly")
		-- The next day pays again.
		local again = Habitat.send(profile, "Crab", "shore", NOW + DAY, true).expedition.id
		local nextDay = Habitat.collect(profile, again, NOW + DAY + 3 * HOUR)
		t.ok(nextDay.shinies > 0, "a new day")
		-- Calling a pet back early: no reward, the slot is free.
		local recalled = Habitat.send(profile, "Gull", "voyage", NOW + DAY, true).expedition.id
		t.ok(Habitat.recall(profile, recalled).ok, "called back")
		t.ok(not Habitat.away(profile).Gull, "home")
		local view = Habitat.view(profile, NOW + DAY)
		t.eq(view.slots, 3, "slots")
		t.eq(view.cap, Config.EXPEDITIONS.DAILY_CAP, "cap")
	end)

	t.test("passive income stays small: a day of expeditions is well under one raid hour", function()
		local P = Config.PROGRESS
		local typicalRaid = P.PARTICIPATION + 10 * P.PER_GOLD + P.DEEDS.steal + P.DEEDS.trick
		local raidsPerHour = 3600 / (Config.PORT.DURATION + Config.SKYSHIP.WINDOW + Config.RAID_DURATION)
		t.ok(
			Config.EXPEDITIONS.DAILY_CAP < typicalRaid * raidsPerHour / 4,
			"a day's cap is under a quarter of a raid hour"
		)
		for _, trip in ipairs(Config.EXPEDITIONS.TRIPS) do
			t.ok(trip.shinies / trip.hours <= 3, trip.id .. ": at most a few Shinies an hour")
		end
	end)
end

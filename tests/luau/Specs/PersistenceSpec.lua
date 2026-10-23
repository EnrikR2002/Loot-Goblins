-- Saved profiles: migration from V7, repair of damaged data, and the session-locked store under failures
-- (server/ProfileSchema.lua, server/ProfileStore.lua). Runs on ProfileStore.mock(), an in-memory DataStore stand-in
-- that copies values in and out and can be told to fail: this proves the logic, not Roblox's live DataStore.
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LootGoblinsServer")
local ProfileSchema = require(Server.ProfileSchema)
local ProfileStore = require(Server.ProfileStore)

local LIMITS = { presets = 3, receipts = 500, history = 40 }

local function harness(store, startTime)
	local clock = { t = startTime or 1000 }
	local function make(job)
		return ProfileStore.new({
			store = store,
			job = job,
			now = function()
				return clock.t
			end,
			wait = function(seconds)
				clock.t += seconds
			end,
			limits = LIMITS,
			lockStale = 180,
			tries = 4,
		})
	end
	return make, clock
end

local V7 = {
	v = 1,
	shinies = 345,
	pets = { Gull = true, Tortoise = true },
	kits = { CinderBoots = true },
	pet = "Gull",
	kit = "CinderBoots",
	raids = 12,
	wins = 3,
	banked = 88,
	receipts = { ["abc-1"] = true, ["abc-2"] = true },
}

return function(t)
	t.test("a V7 profile migrates without losing anything", function()
		local profile, how = ProfileSchema.load(ProfileSchema.copy(V7), LIMITS, 5)
		t.eq(how, "migrated", "how")
		t.eq(profile.v, ProfileSchema.VERSION, "version")
		t.eq(profile.shinies, 345, "shinies")
		t.ok(profile.owned.Gull and profile.owned.Tortoise, "pets")
		t.ok(profile.owned.kit_CinderBoots, "kit")
		t.eq(profile.equipped.pet, "Gull", "pet out")
		t.eq(profile.equipped.kit, "kit_CinderBoots", "kit chosen")
		t.eq(profile.stats.raids, 12, "raids")
		t.eq(profile.stats.wins, 3, "wins")
		t.eq(profile.stats.banked, 88, "banked")
		t.eq(#profile.receipts, 2, "receipts kept")
		t.eq(profile.welcomed, false, "migrated goblins get the V11 welcome too")
	end)

	t.test("V13: a version 2 profile upgrades keeping every item, Shiny, stat and achievement", function()
		local v2 = {
			v = 2,
			shinies = 412,
			owned = { Gull = true, hat_tricorn = true, livery_starlit = true },
			equipped = { pet = "Gull", hat = "hat_tricorn", livery = "livery_starlit" },
			stats = {
				raids = 30,
				wins = 4,
				banked = 300,
				treasures = 21,
				snatches = 2,
				bestCombo = 3,
				bankedFrom = { Idol = 2 },
			},
			achievements = { first_haul = 100, old_salt = 200 },
			receipts = { "r-1" },
			presets = {},
			history = {},
			welcomed = true,
		}
		local profile, how = ProfileSchema.load(v2, LIMITS, 5)
		t.eq(how, "upgraded", "how")
		t.eq(profile.v, ProfileSchema.VERSION, "the current version")
		t.eq(profile.shinies, 412, "shinies")
		t.ok(profile.owned.Gull and profile.owned.hat_tricorn and profile.owned.livery_starlit, "everything owned")
		t.eq(profile.equipped.pet, "Gull", "pet out")
		t.eq(profile.equipped.boat, nil, "no boat chosen yet: the Skiff, the default")
		t.eq(profile.stats.raids, 30, "raids")
		t.eq(profile.stats.bankedFrom.Idol, 2, "per-island banks")
		t.eq(profile.stats.steals, 0, "new stat starts at 0")
		t.eq(profile.stats.escapes, 0, "new stat starts at 0")
		t.eq(type(profile.stats.escapedFrom), "table", "new map")
		t.eq(type(profile.stats.classBanks), "table", "new map")
		t.eq(profile.achievements.old_salt, 200, "achievements kept")
		t.eq(#profile.receipts, 1, "receipts kept")
		t.eq(profile.welcomed, true, "not welcomed twice")
	end)

	t.test("damaged fields are repaired, unknown ids are kept", function()
		local damaged = {
			v = 2,
			shinies = "lots",
			owned = { hat_tricorn = true, future_item_v12 = true, [5] = true },
			equipped = { hat = 7, eyes = "eyes_patch" },
			stats = { raids = -4, wins = 0 / 0, banked = math.huge, bankedFrom = { Idol = 2, bad = -1 } },
			achievements = "none",
			receipts = { "a", "a", "b", 9 },
			presets = { { name = string.rep("x", 100), look = { hat = "hat_tricorn" } }, "junk" },
			history = 12,
			somethingNew = { kept = true },
		}
		local profile, how = ProfileSchema.load(damaged, LIMITS, 5)
		t.eq(how, "upgraded", "how (a version 2 profile, upgraded)")
		t.eq(profile.shinies, 0, "bad number to 0")
		t.ok(profile.owned.hat_tricorn and profile.owned.future_item_v12, "owned kept, including unknown ids")
		t.eq(profile.owned[5], nil, "a non-string key is dropped")
		t.eq(profile.equipped.hat, nil, "a bad equipped value is dropped")
		t.eq(profile.equipped.eyes, "eyes_patch", "a good one kept")
		t.eq(profile.stats.raids, 0, "negative")
		t.eq(profile.stats.wins, 0, "NaN")
		t.eq(profile.stats.banked, 0, "infinite")
		t.eq(profile.stats.bankedFrom.Idol, 2, "good count kept")
		t.eq(profile.stats.bankedFrom.bad, nil, "bad count dropped")
		t.eq(type(profile.achievements), "table", "achievements reset to a table")
		t.eq(#profile.receipts, 2, "duplicate and non-string receipts dropped")
		t.eq(#profile.presets, 1, "junk preset dropped")
		t.eq(#profile.presets[1].name, 24, "long name trimmed")
		t.eq(type(profile.history), "table", "history")
		t.ok(profile.somethingNew and profile.somethingNew.kept, "unknown top-level data kept")
	end)

	t.test("V13.3: a version 3 profile upgrades to 4 keeping everything, with empty Port tables", function()
		local v3 = {
			v = 3,
			shinies = 640,
			owned = { boat_wraith = true, Inky = true, hat_crown = true },
			equipped = { boat = "boat_wraith", pet = "Inky", hat = "hat_crown" },
			stats = {
				raids = 41,
				wins = 6,
				banked = 410,
				treasures = 33,
				steals = 9,
				escapes = 5,
				escapedFrom = { Bone = 1 },
			},
			achievements = { first_haul = 10, leviathan_friend = 20 },
			receipts = { "r-9" },
			presets = {},
			history = {},
			welcomed = true,
		}
		local profile, how = ProfileSchema.load(v3, LIMITS, 5)
		t.eq(how, "upgraded", "how")
		t.eq(profile.v, 4, "version 4")
		t.eq(profile.migratedFrom, 3, "from 3")
		t.eq(profile.shinies, 640, "shinies")
		t.ok(profile.owned.boat_wraith and profile.owned.Inky and profile.owned.hat_crown, "owned")
		t.eq(profile.equipped.boat, "boat_wraith", "boat")
		t.eq(profile.stats.escapedFrom.Bone, 1, "escape trophies' stat")
		t.eq(profile.achievements.leviathan_friend, 20, "achievements")
		t.eq(profile.stats.questsDone, 0, "new stat")
		t.eq(profile.stats.expeditions, 0, "new stat")
		t.eq(type(profile.games.best), "table", "games")
		t.eq(#profile.quests.daily, 0, "no quests dealt yet")
		t.eq(profile.quests.day, nil, "no quest day yet")
		t.eq(type(profile.season.best), "table", "season")
		t.eq(profile.sanctuary.theme, "meadow", "the free theme")
		t.eq(#profile.sanctuary.decor, 4, "four empty decoration spots")
		t.eq(#profile.expeditions.list, 0, "no expeditions")
		t.eq(profile.expeditions.nextId, 1, "first expedition id")
		t.eq(type(profile.milestones), "table", "milestones")
	end)

	t.test("V13.3: damaged Port tables are repaired, never trusted", function()
		local damaged = ProfileSchema.new(5)
		damaged.games = {
			day = "today",
			runs = { regatta = 3, golf = -2, [4] = 1 },
			earned = 0 / 0,
			best = { regatta = 41.5, golf = -10, toss = math.huge },
			plays = "lots",
		}
		damaged.quests = {
			day = 20383,
			daily = { { id = "d_bank2", n = 1.7, claimed = "yes" }, "junk", { n = 4 } },
			week = "x",
			weekly = 7,
		}
		damaged.season = {
			best = { ["haul@w2911"] = 18, ["bad@x"] = -3 },
			paid = "no",
			raids = { key = 5, list = { 12, -1, "x", 9 } },
			trophies = { { board = "haul", key = "w2910", tier = "gold", rank = 3.6 }, { board = 4 } },
		}
		damaged.sanctuary = {
			theme = 9,
			owned = { decor_palm = true, [2] = true },
			levels = { dock = 7.9, pond = "big" },
			decor = { "palm", 4, "" },
			residents = { "Crab", 5, "Gull" },
		}
		damaged.expeditions = {
			list = { { id = 4, pet = "Crab", trip = "reef", at = 100, back = 200 }, { id = 2, pet = 7 } },
			nextId = 1,
			collected = -5,
		}
		damaged.milestones = { FirstRaid = 12, bad = "x" }
		damaged.challenges = "none"
		local profile = ProfileSchema.load(damaged, LIMITS, 5)
		t.eq(profile.games.day, 0, "bad day")
		t.eq(profile.games.runs.regatta, 3, "good count kept")
		t.eq(profile.games.runs.golf, nil, "negative count dropped")
		t.eq(profile.games.earned, 0, "NaN")
		t.eq(profile.games.best.regatta, 41.5, "a best time keeps its fraction")
		t.eq(profile.games.best.golf, nil, "negative best dropped")
		t.eq(profile.games.best.toss, nil, "infinite best dropped")
		t.eq(type(profile.games.plays), "table", "plays")
		t.eq(#profile.quests.daily, 1, "only the well-formed quest kept")
		t.eq(profile.quests.daily[1].n, 1, "whole progress")
		t.eq(profile.quests.daily[1].claimed, false, "claimed only when true")
		t.eq(profile.quests.week, nil, "bad week")
		t.eq(#profile.quests.weekly, 0, "bad list")
		t.eq(profile.season.best["haul@w2911"], 18, "a season best kept")
		t.eq(profile.season.best["bad@x"], nil, "a bad one dropped")
		t.eq(type(profile.season.paid), "table", "paid")
		t.eq(profile.season.raids.key, "", "bad month key")
		t.eq(#profile.season.raids.list, 2, "good hauls kept")
		-- V13.4: a V13.3 profile has no week of raids yet: it gets an empty one.
		t.eq(profile.season.week.key, "", "no week's raids yet")
		t.eq(#profile.season.week.list, 0, "an empty week")
		t.eq(#profile.season.trophies, 1, "a bad trophy dropped")
		t.eq(profile.season.trophies[1].rank, 3, "whole rank")
		t.eq(profile.sanctuary.theme, "meadow", "bad theme")
		t.ok(profile.sanctuary.owned.decor_palm, "owned decor kept")
		t.eq(profile.sanctuary.levels.dock, 7, "a level is whole")
		t.eq(profile.sanctuary.levels.pond, nil, "a bad level dropped")
		t.eq(profile.sanctuary.decor[2], "", "a bad decoration spot emptied")
		t.eq(#profile.sanctuary.decor, 4, "always four spots")
		t.eq(#profile.sanctuary.residents, 2, "bad resident dropped")
		t.eq(#profile.expeditions.list, 1, "bad expedition dropped")
		t.eq(profile.expeditions.nextId, 5, "the next id is past every id in use")
		t.eq(profile.expeditions.collected, 0, "negative")
		t.eq(profile.milestones.FirstRaid, 12, "milestone kept")
		t.eq(profile.milestones.bad, nil, "bad milestone dropped")
		t.eq(type(profile.challenges.pairs), "table", "challenges reset")
	end)

	t.test("a value that is not a table becomes a fresh profile; a newer version is left alone", function()
		local profile, how = ProfileSchema.load("garbage", LIMITS, 5)
		t.eq(how, "repaired", "how")
		t.eq(profile.shinies, 0, "fresh")
		local none, why = ProfileSchema.load({ v = ProfileSchema.VERSION + 1, shinies = 999 }, LIMITS, 5)
		t.eq(none, nil, "not loaded")
		t.eq(why, "newer", "why")
	end)

	t.test("first open creates a locked profile; a second server sees it locked", function()
		local store = ProfileStore.mock()
		local make = harness(store)
		local a, b = make("A"), make("B")
		local status, profile, how = a:open("u1", "s1")
		t.eq(status, "ok", "A opens")
		t.eq(how, "new", "new")
		t.eq(store.data.u1.lock.session, "s1", "locked to A")
		profile.shinies = 50
		t.eq(a:save("u1", "s1", profile, false), "ok", "A saves")
		t.eq(b:open("u1", "s2"), "locked", "B is refused while A holds it")
		t.eq(store.data.u1.shinies, 50, "B wrote nothing")
	end)

	t.test("releasing on leave lets the next server open at once, with everything", function()
		local store = ProfileStore.mock()
		local make = harness(store)
		local a, b = make("A"), make("B")
		local _, profile = a:open("u1", "s1")
		profile.shinies = 120
		profile.owned.hat_tricorn = true
		t.eq(a:save("u1", "s1", profile, true), "ok", "save and release")
		t.eq(store.data.u1.lock, nil, "released")
		local status, again = b:open("u1", "s2")
		t.eq(status, "ok", "B opens")
		t.eq(again.shinies, 120, "shinies")
		t.ok(again.owned.hat_tricorn, "items")
	end)

	t.test("a crashed server's stale lock is taken over, and its late save is refused", function()
		local store = ProfileStore.mock()
		local make, clock = harness(store)
		local a, b = make("A"), make("B")
		local _, profileA = a:open("u1", "s1")
		profileA.shinies = 10
		a:save("u1", "s1", profileA, false)
		clock.t += 60
		t.eq(b:open("u1", "s2"), "locked", "still fresh after a minute")
		clock.t += 200
		local status, profileB = b:open("u1", "s2")
		t.eq(status, "ok", "taken over when stale")
		profileB.shinies = 999
		b:save("u1", "s2", profileB, false)
		-- Server A comes back to life and tries to save its old copy.
		profileA.shinies = 11
		t.eq(a:save("u1", "s1", profileA, false), "lost", "A is told it lost the profile")
		t.eq(store.data.u1.shinies, 999, "B's newer data is intact")
	end)

	t.test("a deleted key is not re-created by a late save", function()
		local store = ProfileStore.mock()
		local make = harness(store)
		local a = make("A")
		local _, profile = a:open("u1", "s1")
		store.data.u1 = nil
		t.eq(a:save("u1", "s1", profile, false), "lost", "refused")
		t.eq(store.data.u1, nil, "still gone")
	end)

	t.test("transient store failures are retried; persistent ones report an error and change nothing", function()
		local store = ProfileStore.mock()
		local make = harness(store)
		local a = make("A")
		store.failNext = 2
		local status, profile = a:open("u1", "s1")
		t.eq(status, "ok", "opened after two failures")
		profile.shinies = 77
		store.failNext = 3
		t.eq(a:save("u1", "s1", profile, false), "ok", "saved after three failures")
		t.eq(store.data.u1.shinies, 77, "on disk")
		profile.shinies = 78
		store.failNext = 10
		t.eq(a:save("u1", "s1", profile, false), "error", "gives up after its tries")
		t.eq(store.data.u1.shinies, 77, "the stored value is untouched")
		store.failNext = 0
		t.eq(a:save("u1", "s1", profile, false), "ok", "and saves later")
		t.eq(store.data.u1.shinies, 78, "latest")
	end)

	t.test("a newer game version's profile is never opened or written", function()
		local store = ProfileStore.mock()
		local newer = ProfileSchema.VERSION + 1
		store.data.u1 = { v = newer, shinies = 5000, lock = nil }
		local make = harness(store)
		local status = make("A"):open("u1", "s1")
		t.eq(status, "newer", "refused")
		t.eq(store.data.u1.shinies, 5000, "untouched")
		t.eq(store.data.u1.v, newer, "still the newer version")
	end)

	t.test("a V7 profile in the store is migrated when opened and saved at the current version", function()
		local store = ProfileStore.mock()
		store.data.u7 = ProfileSchema.copy(V7)
		local make = harness(store)
		local a = make("A")
		local status, profile, how = a:open("u7", "s1")
		t.eq(status, "ok", "opened")
		t.eq(how, "migrated", "migrated")
		t.eq(store.data.u7.v, ProfileSchema.VERSION, "stored at the current version at once")
		t.eq(store.data.u7.shinies, 345, "shinies on disk")
		t.ok(profile.owned.Gull, "pets")
	end)

	t.test("the game's copy and the stored copy are separate tables", function()
		local store = ProfileStore.mock()
		local make = harness(store)
		local a = make("A")
		local _, profile = a:open("u1", "s1")
		profile.shinies = 5
		t.ok(store.data.u1.shinies ~= 5, "changing the game's copy does not change the store until a save")
		a:save("u1", "s1", profile, false)
		profile.shinies = 6
		t.eq(store.data.u1.shinies, 5, "a save stores a snapshot")
	end)

	t.test("an exhausted request budget is waited out before writing", function()
		local store = ProfileStore.mock()
		local clock = { t = 0 }
		local budget = 0
		local s = ProfileStore.new({
			store = store,
			now = function()
				return clock.t
			end,
			wait = function(seconds)
				clock.t += seconds
				budget = 5
			end,
			budget = function()
				return budget
			end,
		})
		t.eq(s:open("u1", "s1"), "ok", "opened once budget returned")
		t.ok(clock.t >= 1, "it waited")
	end)
end

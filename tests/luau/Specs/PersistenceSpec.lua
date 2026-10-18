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
		t.eq(profile.v, 2, "version")
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
		t.eq(how, "loaded", "how")
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

	t.test("a value that is not a table becomes a fresh profile; a newer version is left alone", function()
		local profile, how = ProfileSchema.load("garbage", LIMITS, 5)
		t.eq(how, "repaired", "how")
		t.eq(profile.shinies, 0, "fresh")
		local none, why = ProfileSchema.load({ v = 3, shinies = 999 }, LIMITS, 5)
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
		store.data.u1 = { v = 3, shinies = 5000, lock = nil }
		local make = harness(store)
		local status = make("A"):open("u1", "s1")
		t.eq(status, "newer", "refused")
		t.eq(store.data.u1.shinies, 5000, "untouched")
		t.eq(store.data.u1.v, 3, "still v3")
	end)

	t.test("a V7 profile in the store is migrated when opened and saved as version 2", function()
		local store = ProfileStore.mock()
		store.data.u7 = ProfileSchema.copy(V7)
		local make = harness(store)
		local a = make("A")
		local status, profile, how = a:open("u7", "s1")
		t.eq(status, "ok", "opened")
		t.eq(how, "migrated", "migrated")
		t.eq(store.data.u7.v, 2, "stored as v2 at once")
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

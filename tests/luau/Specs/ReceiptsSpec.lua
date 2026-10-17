-- Robux receipts (server/Receipts.lua) with simulated receipts: idempotent, never granted blind, confirmed only after
-- a save, never lost when a save fails. No real purchase is made; MarketplaceService is not involved.
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("LootGoblinsServer")
local Receipts = require(Server.Receipts)
local Economy = require(Server.Economy)
local ProfileSchema = require(Server.ProfileSchema)

local PRODUCT = 1111 -- a stand-in Developer Product id for the test only
local ENTRY = { key = "livery_starlit", entry = { kind = "product", id = PRODUCT, grants = { "livery_starlit" } } }

local function setup()
	local world = {
		profile = ProfileSchema.new(0),
		ready = true,
		here = true,
		saveWorks = true,
		saves = 0,
		grants = 0,
		disk = nil,
	}
	world.deps = {
		keep = 500,
		product = function(productId)
			return productId == PRODUCT and ENTRY or nil
		end,
		session = function(userId)
			if userId ~= 42 or not world.here then
				return nil
			end
			return { profile = world.profile, ready = world.ready }
		end,
		grant = function(session, product)
			local fresh = Economy.grant(session.profile, product.entry.grants, "robux", 1)
			if #fresh == 0 then
				Economy.addShinies(session.profile, 150) -- the duplicate-payment rule
				return "duplicate"
			end
			world.grants += #fresh
			return table.concat(fresh, ",")
		end,
		save = function(_session)
			world.saves += 1
			if world.saveWorks then
				world.disk = ProfileSchema.copy(world.profile)
				return true
			end
			return false
		end,
	}
	return world
end

local function receipt(id)
	return { PurchaseId = id, PlayerId = 42, ProductId = PRODUCT }
end

return function(t)
	t.test("a valid receipt grants the item and is confirmed only once saved", function()
		local world = setup()
		local decision = Receipts.process(receipt("p1"), world.deps)
		t.eq(decision, "granted", "decision")
		t.ok(world.profile.owned.livery_starlit, "owned")
		t.ok(world.disk and world.disk.owned.livery_starlit, "on disk")
		t.ok(Receipts.has(world.disk, "p1"), "receipt recorded on disk with the grant")
	end)

	t.test("the same receipt again grants nothing more and is still confirmed", function()
		local world = setup()
		Receipts.process(receipt("p1"), world.deps)
		local shinies = world.profile.shinies
		local decision = Receipts.process(receipt("p1"), world.deps)
		t.eq(decision, "granted", "confirmed again")
		t.eq(world.grants, 1, "granted once")
		t.eq(world.profile.shinies, shinies, "no compensation for a repeat of the same receipt")
	end)

	t.test("an unknown product is never granted", function()
		local world = setup()
		local decision = Receipts.process({ PurchaseId = "x", PlayerId = 42, ProductId = 999 }, world.deps)
		t.eq(decision, "retry", "left for later")
		t.eq(world.grants, 0, "nothing")
		t.eq(#world.profile.receipts, 0, "not recorded")
	end)

	t.test("a goblin who is not here, or whose profile is not open, is not granted here", function()
		local world = setup()
		world.here = false
		t.eq(Receipts.process(receipt("p2"), world.deps), "retry", "not here")
		world.here, world.ready = true, false
		t.eq(Receipts.process(receipt("p2"), world.deps), "retry", "not open")
		t.eq(world.grants, 0, "nothing granted")
		t.eq(#world.profile.receipts, 0, "nothing recorded")
	end)

	t.test("a failed save is retried later without granting twice, and nothing is lost", function()
		local world = setup()
		world.saveWorks = false
		t.eq(Receipts.process(receipt("p3"), world.deps), "retry", "not confirmed")
		t.ok(world.profile.owned.livery_starlit, "granted in memory (goes out with the next save)")
		t.eq(world.disk, nil, "nothing on disk yet")
		world.saveWorks = true
		t.eq(Receipts.process(receipt("p3"), world.deps), "granted", "confirmed on the retry")
		t.eq(world.grants, 1, "granted once")
		t.ok(Receipts.has(world.disk, "p3"), "recorded on disk")
	end)

	t.test("a second payment for an owned permanent item becomes Shinies, not nothing", function()
		local world = setup()
		Receipts.process(receipt("p4"), world.deps)
		local before = world.profile.shinies
		t.eq(Receipts.process(receipt("p5"), world.deps), "granted", "a different purchase id")
		t.eq(world.grants, 1, "the item is not granted twice")
		t.eq(world.profile.shinies, before + 150, "compensated")
	end)

	t.test("malformed receipts are not processed", function()
		local world = setup()
		t.eq(Receipts.process(nil, world.deps), "retry", "nil")
		t.eq(Receipts.process({ PlayerId = 42, ProductId = PRODUCT }, world.deps), "retry", "no purchase id")
	end)

	t.test("the receipt list keeps the newest when it is full", function()
		local profile = ProfileSchema.new(0)
		for i = 1, 510 do
			Receipts.add(profile, "r" .. i, 500)
		end
		t.eq(#profile.receipts, 500, "capped")
		t.ok(Receipts.has(profile, "r510"), "newest kept")
		t.ok(not Receipts.has(profile, "r1"), "oldest dropped")
	end)
end

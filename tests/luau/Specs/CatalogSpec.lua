-- The catalogue: every row is valid, consistent with the achievements and Robux tables, and has a real look that builds
-- within its part budget and obeys the collision contract.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Wardrobe = require(Shared.Wardrobe)
local BoatLook = require(Shared.BoatLook)
local PetLook = require(Shared.PetLook)
local StyleFx = require(Shared.StyleFx)
local EmoteMoves = require(Shared.EmoteMoves)

local BUDGET = { hat = 18, eyes = 9, face = 9, outfit = 24, back = 12, ears = 10, nose = 5 }

local function covered(item)
	local slot = item.slot
	if slot == "boat" then
		-- V13: a boat is a class (Config.BOAT_TYPES) with a showroom row and an ability.
		local spec = Config.BOAT_TYPES[item.class]
		local row = false
		for _, entry in ipairs(Config.BOAT_CLASSES) do
			row = row or entry.id == item.class
		end
		return spec ~= nil and spec.class == true and row and Config.BOAT_ABILITIES[spec.ability] ~= nil
	elseif Catalog.slot(slot).group == "goblin" then
		return Wardrobe.covers(item)
	elseif slot == "livery" or slot == "flag" or slot == "figurehead" then
		return BoatLook.covers(item)
	elseif slot == "pet" or slot == "petskin" or slot == "pethat" then
		return PetLook.covers(item)
	elseif slot == "trail" or slot == "wake" or slot == "trickfx" or slot == "callout" then
		return StyleFx.covers(item)
	elseif slot == "emote" or slot == "victory" then
		return EmoteMoves.covers(item)
	elseif slot == "kit" then
		return Config.GEAR[item.gear] ~= nil
	end
	return false
end

local function contract(parts, label)
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			assert(p.CanCollide == false, label .. ": " .. p.Name .. " collides")
			assert(p.CanQuery == false, label .. ": " .. p.Name .. " is hit by rays")
			assert(p.CanTouch == false, label .. ": " .. p.Name .. " can be touched")
		end
	end
end

-- A stand-in player boat with the parts BoatLook paints (the real ones are built at runtime).
local function fakeBoat()
	local model = Instance.new("Model")
	local function part(name, size, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.Parent = model
		return p
	end
	part("Hull", Vector3.new(9, 3, 20), CFrame.new())
	part("Strake", Vector3.new(0.35, 1, 15), CFrame.new(4.6, 0.3, 0))
	part("Sail", Vector3.new(0.25, 8.5, 7), CFrame.new(0, 8.5, 1.2))
	part("Mast", Vector3.new(0.7, 12, 0.7), CFrame.new(0, 7.5, -2))
	part("Flag", Vector3.new(0.3, 2.4, 3.6), CFrame.new(0, 13.9, -0.2))
	return model
end

return function(t)
	t.test("catalogue ids are unique and every row is well formed", function()
		local seen = {}
		for _, item in ipairs(Catalog.items) do
			t.ok(type(item.id) == "string" and #item.id > 0, "id")
			t.ok(not seen[item.id], "duplicate id " .. item.id)
			seen[item.id] = true
			t.ok(Catalog.slot(item.slot) ~= nil, item.id .. ": unknown slot " .. tostring(item.slot))
			t.ok(Catalog.RARITIES[item.rarity] ~= nil, item.id .. ": unknown rarity")
			t.ok(type(item.name) == "string" and #item.name > 0, item.id .. ": no name")
			t.ok(type(item.blurb) == "string" and #item.blurb > 10, item.id .. ": no description")
			if item.price ~= nil then
				t.ok(
					type(item.price) == "number" and item.price > 0 and item.price == math.floor(item.price),
					item.id .. ": bad price"
				)
			end
		end
	end)

	t.test("every item has exactly one way to be obtained", function()
		for _, item in ipairs(Catalog.items) do
			local ways = (Catalog.isFree(item) and 1 or 0) + (item.price and 1 or 0) + (item.unlock and 1 or 0)
			if item.rarity == "premium" then
				t.eq(ways, 0, item.id .. ": a premium-only item must have no Shinies price, unlock or free flag")
				t.ok(item.premium ~= nil, item.id .. ": premium without a product key")
			else
				t.eq(ways, 1, item.id .. ": ways to obtain")
			end
			if item.rarity == "trophy" then
				t.ok(item.unlock ~= nil, item.id .. ": trophy without an achievement")
			end
		end
	end)

	t.test("trophies and achievements point at each other", function()
		for _, achievement in ipairs(Catalog.ACHIEVEMENTS) do
			t.ok(achievement.goal > 0, achievement.id .. ": goal")
			t.ok(achievement.shinies >= 0, achievement.id .. ": shinies")
			if achievement.reward then
				local item = Catalog.get(achievement.reward)
				t.ok(item ~= nil, achievement.id .. ": reward does not exist")
				t.eq(item.unlock, achievement.id, achievement.id .. ": reward's unlock")
			end
		end
		for _, item in ipairs(Catalog.items) do
			if item.unlock then
				local achievement = Catalog.achievementById[item.unlock]
				t.ok(achievement ~= nil, item.id .. ": unknown achievement")
				t.eq(achievement.reward, item.id, item.id .. ": achievement's reward")
			end
		end
	end)

	t.test("every Robux key is configured and grants its item, with no invented ids", function()
		for _, item in ipairs(Catalog.items) do
			if item.premium then
				local entry = Config.MONETIZATION.PRODUCTS[item.premium]
				t.ok(entry ~= nil, item.id .. ": no Config.MONETIZATION entry")
				local grants = false
				for _, id in ipairs(entry.grants) do
					grants = grants or id == item.id
				end
				t.ok(grants, item.id .. ": its product does not grant it")
			end
		end
		local configured = 0
		for key, entry in pairs(Config.MONETIZATION.PRODUCTS) do
			-- No id is ever made up: an id is either absent or a real whole number pasted from the Creator Dashboard.
			t.ok(
				entry.id == nil or (type(entry.id) == "number" and entry.id > 0 and entry.id == math.floor(entry.id)),
				key .. ": id"
			)
			t.ok(entry.kind == "pass" or entry.kind == "product", key .. ": kind")
			if entry.id then
				configured += 1
			end
		end
		if configured == 0 then
			t.eq(Config.MONETIZATION.SALES_ENABLED, false, "sales must stay off while no product is configured")
		end
	end)

	t.test("pets match Config.PETS; every pet with an ability is earnable, and a Robux-only pet has none", function()
		local count = 0
		for petId, def in pairs(Config.PETS) do
			count += 1
			local item = Catalog.get(petId)
			t.ok(item ~= nil and item.slot == "pet", petId .. ": not in the catalogue")
			t.ok(PetLook.SPECIES[petId] ~= nil, petId .. ": no species (how it moves, its theme)")
			t.eq(item.theme, PetLook.SPECIES[petId].theme, petId .. ": shop theme differs from its species")
			if def.ability then
				t.ok(Config.PET_ABILITIES[def.ability] ~= nil, petId .. ": unknown ability " .. tostring(def.ability))
				t.ok(Catalog.forSale(item) or item.unlock ~= nil, petId .. ": a pet with an ability must be earnable")
			else
				t.eq(item.rarity, "premium", petId .. ": a pet with no ability is a show pet (premium)")
			end
		end
		for _, item in ipairs(Catalog.bySlot.pet) do
			t.ok(Config.PETS[item.id] ~= nil, item.id .. ": a catalogue pet missing from Config.PETS")
		end
		t.ok(count >= 35 and count <= 45, "V13 asks for about forty species, there are " .. count)
	end)

	t.test("V13: every boat class is in the shop, the free ones free, the rest earnable with Shinies", function()
		local seen = {}
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local item = Catalog.get("boat_" .. row.id)
			t.ok(item ~= nil and item.slot == "boat" and item.class == row.id, row.id .. ": no shop item")
			seen[row.id] = true
			if row.id == "skiff" or row.id == "cutter" then
				t.ok(Catalog.isFree(item), row.id .. " should be free")
			else
				t.ok(Catalog.forSale(item), row.id .. " must be earnable with Shinies, not only Robux")
			end
		end
		for _, item in ipairs(Catalog.bySlot.boat) do
			t.ok(seen[item.class], item.id .. ": a boat with no showroom row")
		end
		t.eq(Catalog.slot("boat").default, "boat_skiff", "everyone starts with the Skiff")
	end)

	t.test("slot defaults exist, fit their slot and are free", function()
		for _, slot in ipairs(Catalog.SLOTS) do
			if slot.default then
				local item = Catalog.get(slot.default)
				t.ok(item ~= nil and item.slot == slot.id, slot.id .. ": bad default")
				t.ok(Catalog.isFree(item), slot.id .. ": default not free")
			end
		end
	end)

	t.test("every item has a real look", function()
		for _, item in ipairs(Catalog.items) do
			t.ok(covered(item), item.id .. " has no look")
		end
	end)

	t.test("a look survives encoding, and junk is dropped", function()
		local look = Catalog.withDefaults({
			hat = "hat_tricorn",
			eyes = "eyes_patch",
			pet = "Crab",
			petskin = "petskin_crab_hermit",
		})
		local back = Catalog.decodeLook(Catalog.encodeLook(look))
		for slot, id in pairs(look) do
			t.eq(back[slot], id, "round trip " .. slot)
		end
		local junk = Catalog.decodeLook(
			"hat=eyes_patch;eyes=nonsense;outfit=outfit_captain;skin=;;=;pet=Frog;petskin=petskin_crab_hermit"
		)
		t.eq(junk.hat, nil, "an item in the wrong slot is dropped")
		t.eq(junk.eyes, nil, "an unknown item is dropped")
		t.eq(junk.outfit, "outfit_captain", "a good one is kept")
		t.eq(junk.skin, "skin_classic", "a default fills an empty slot")
		t.eq(junk.petskin, nil, "a pet look on the wrong pet is dropped")
		t.eq(Catalog.decodeLook(nil).ears, "ears_long", "nil decodes to defaults")
	end)

	t.test("goblin items build within budget and obey the collision contract", function()
		for _, item in ipairs(Catalog.items) do
			local slot = Catalog.slot(item.slot)
			if slot.group == "goblin" then
				local model = Wardrobe.mannequin()
				local look = Catalog.withDefaults({ [item.slot] = item.id })
				local made = Wardrobe.dress(model, look)
				local folder = model:FindFirstChild(Wardrobe.FOLDER)
				t.ok(folder ~= nil, item.id .. ": nothing built")
				-- Minus the default ears and nose.
				local budget = BUDGET[item.slot]
				if budget then
					local base = Wardrobe.dress(Wardrobe.mannequin(), Catalog.withDefaults({}))
					t.ok(made - base <= budget, string.format("%s: %d parts (budget %d)", item.id, made - base, budget))
				end
				contract(folder:GetDescendants(), item.id)
				for _, p in ipairs(folder:GetDescendants()) do
					if p:IsA("BasePart") then
						t.ok(p.Massless, item.id .. ": " .. p.Name .. " has mass")
					end
				end
				-- Dressing twice changes nothing.
				t.eq(Wardrobe.dress(model, look), 0, item.id .. ": dressing again rebuilt")
				model:Destroy()
			end
		end
	end)

	t.test("boat items build on a boat and obey the collision contract", function()
		for _, item in ipairs(Catalog.items) do
			if item.slot == "livery" or item.slot == "flag" or item.slot == "figurehead" then
				local boat = fakeBoat()
				local hull = boat.Hull
				local size, color = hull.Size, hull.Color
				BoatLook.apply(boat, { [item.slot] = item.id })
				t.eq(hull.Size, size, item.id .. ": hull size changed")
				t.ok(boat:FindFirstChild(BoatLook.FOLDER) ~= nil, item.id .. ": no cosmetics folder")
				contract(boat[BoatLook.FOLDER]:GetDescendants(), item.id)
				-- Class colours put back exactly what was there.
				BoatLook.apply(boat, {})
				t.eq(hull.Color, color, item.id .. ": classic did not restore the hull")
				boat:Destroy()
			end
		end
	end)

	t.test("every pet, look and hat builds, anchored and harmless", function()
		for petId in pairs(Config.PETS) do
			for _, item in ipairs(Catalog.items) do
				local skin = (item.slot == "petskin" and item.pet == petId) and item.id or nil
				local hat = item.slot == "pethat" and item.id or nil
				if skin or hat or item.id == petId then
					local rig = PetLook.build(petId, skin, hat)
					t.ok(rig ~= nil, petId .. " with " .. item.id)
					t.ok(#rig.parts >= 8 and #rig.parts <= 40, petId .. ": " .. #rig.parts .. " parts")
					t.eq(#rig.parts, #rig.rest, "rest per part")
					for _, p in ipairs(rig.parts) do
						t.ok(p.Anchored, petId .. ": " .. p.Name .. " unanchored")
					end
					contract(rig.parts, petId)
					rig.model:Destroy()
				end
			end
		end
	end)

	t.test("every emote and victory dance poses without error from start to end", function()
		for _, item in ipairs(Catalog.items) do
			if item.slot == "emote" or item.slot == "victory" then
				local move = EmoteMoves.get(item.id)
				for i = 0, 40 do
					local pose = EmoteMoves.at(item.id, move.duration * i / 40)
					t.ok(pose ~= nil, item.id .. " at " .. i)
					for joint, cf in pairs(pose) do
						t.ok(typeof(cf) == "CFrame", item.id .. ": " .. joint)
					end
				end
				t.eq(EmoteMoves.at(item.id, move.duration + 0.1), nil, item.id .. ": does not end")
			end
		end
	end)
end

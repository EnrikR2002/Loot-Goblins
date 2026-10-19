-- V13, the bestiary: forty-two pets that each build, move and do their quirk through the one shared animator, look
-- different from one another, and share a handful of abilities so no pet (however rare, or bought) is stronger.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local PetLook = require(Shared.PetLook)

local KINDS = {
	walker = true,
	hopper = true,
	plodder = true,
	crawler = true,
	roller = true,
	flier = true,
	floater = true,
	swimmer = true,
	slither = true,
}
-- Every quirk the animator (shared/PetLook.pose) or the follower (client/Pets.lua) knows.
local QUIRKS = {}
for _, q in ipairs({
	"snap",
	"yawn",
	"tongue",
	"look",
	"loop",
	"ink",
	"puff",
	"circle",
	"bubble",
	"pulse",
	"cartwheel",
	"wiggle",
	"flip",
	"lure",
	"float",
	"sniff",
	"hang",
	"clap",
	"sparkle",
	"chomp",
	"spin",
	"stomp",
	"spores",
	"dart",
	"headbutt",
	"brandish",
	"freeze",
	"slide",
	"flare",
	"rattle",
}) do
	QUIRKS[q] = true
end

local function signature(rig)
	local bits = {}
	for _, p in ipairs(rig.parts) do
		table.insert(
			bits,
			string.format("%s%.1f%.1f%.1f%d", p.Name, p.Size.X, p.Size.Y, p.Size.Z, math.floor(p.Color.R * 255))
		)
	end
	table.sort(bits)
	return table.concat(bits, "|")
end

return function(t)
	t.test("every species has a known kind, theme and quirk", function()
		local themes = {}
		for _, theme in ipairs(PetLook.THEMES) do
			themes[theme] = 0
		end
		for id, species in pairs(PetLook.SPECIES) do
			t.ok(KINDS[species.kind], id .. ": kind " .. tostring(species.kind))
			t.ok(themes[species.theme] ~= nil, id .. ": theme " .. tostring(species.theme))
			t.ok(QUIRKS[species.quirk], id .. ": quirk " .. tostring(species.quirk))
			themes[species.theme] += 1
			t.ok(Config.PETS[id] ~= nil, id .. ": a species with no Config.PETS row")
		end
		for theme, count in pairs(themes) do
			t.ok(count >= 6, theme .. " has only " .. count .. " pets (the Port's pen and the shop filter need some)")
		end
	end)

	t.test("every pet builds, looks unlike every other, and poses through every situation", function()
		local seen = {}
		local states = {
			{ speed = 0, chased = false, diving = false },
			{ speed = 20, chased = false, diving = false },
			{ speed = 80, chased = true, diving = false },
			{ speed = 120, chased = false, diving = true },
		}
		for id, species in pairs(PetLook.SPECIES) do
			local rig = PetLook.build(id)
			t.ok(rig ~= nil, id .. ": does not build")
			t.ok(#rig.parts >= 8 and #rig.parts <= 40, id .. ": " .. #rig.parts .. " parts")
			local sig = signature(rig)
			t.ok(not seen[sig], id .. " looks exactly like " .. tostring(seen[sig]))
			seen[sig] = id
			local entry = { rig = rig, phase = 0, quirk = nil, quirkAt = 0, idleAt = 0 }
			for step = 0, 60 do
				local time = step * 0.1
				entry.phase += 0.15
				local state = states[step % #states + 1]
				if step == 20 then
					entry.quirk, entry.quirkAt = species.quirk, time
				end
				local poses, bounce, extra = PetLook.pose(entry, time, step % 2 == 0 and 0 or 6, state)
				t.ok(type(poses) == "table", id .. ": poses")
				t.ok(type(bounce) == "number" and bounce == bounce, id .. ": bounce")
				t.ok(extra == nil or typeof(extra) == "CFrame", id .. ": extra")
				for group, cf in pairs(poses) do
					t.ok(typeof(cf) == "CFrame", id .. ": " .. tostring(group))
				end
				local origin = PetLook.apply(rig, CFrame.new(0, 2, 0), poses, extra)
				t.ok(typeof(origin) == "CFrame", id .. ": placed")
			end
			for _, p in ipairs(rig.parts) do
				t.ok(p.Position.Magnitude < 30, id .. ": " .. p.Name .. " flew off to " .. tostring(p.Position))
			end
			rig.model:Destroy()
		end
	end)

	t.test("a quirk starts when the goblin stands still and ends on time", function()
		local rig = PetLook.build("Crab")
		local entry = { rig = rig, idleAt = 0 }
		t.eq(PetLook.updateQuirk(entry, 1, false), nil, "not while moving")
		t.eq(PetLook.updateQuirk(entry, 1, true), "snap", "standing still: its quirk")
		t.eq(entry.quirk, "snap", "on")
		PetLook.updateQuirk(entry, 1 + (PetLook.QUIRK_TIME.snap or 1.8) + 0.1, false)
		t.eq(entry.quirk, nil, "over")
		t.ok(entry.idleAt > 1, "and not again at once")
		rig.model:Destroy()
		-- Peek's freeze is a rule, never a timed quirk.
		local peek = PetLook.build("Peek")
		local p = { rig = peek, idleAt = 0 }
		t.eq(PetLook.updateQuirk(p, 1, true), nil, "Peek has no idle moment: it freezes when watched")
		peek.model:Destroy()
	end)

	t.test("abilities are a few shared archetypes: none belongs only to rare, trophy or premium pets", function()
		local byAbility = {}
		for id, def in pairs(Config.PETS) do
			if def.ability then
				byAbility[def.ability] = byAbility[def.ability] or { count = 0, cheap = false }
				local b = byAbility[def.ability]
				b.count += 1
				local item = Catalog.get(id)
				if item.price and (item.rarity == "common" or item.rarity == "uncommon") then
					b.cheap = true
				end
			end
		end
		for ability in pairs(Config.PET_ABILITIES) do
			local b = byAbility[ability]
			t.ok(b ~= nil and b.count >= 3, ability .. ": too few pets have it")
			t.ok(b.cheap, ability .. ": no common or uncommon pet has it, so it would be a rare-only power")
		end
	end)

	t.test("pet looks dress their own pet only", function()
		for _, item in ipairs(Catalog.bySlot.petskin) do
			local skin = PetLook.SKINS[item.id]
			t.ok(skin ~= nil and skin.pet == item.pet, item.id .. ": no look for its pet")
			t.ok(PetLook.build(item.pet, item.id) ~= nil, item.id .. ": does not build")
		end
	end)
end

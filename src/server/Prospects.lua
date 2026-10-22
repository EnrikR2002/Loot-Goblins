-- WHAT'S NEXT (V13.3): the short card a goblin sees as they come home from a raid (client/NextUp.lua), so the second
-- raid, or something else worth doing, is right in front of them. Built by the server from the profile after the
-- raid's payout, quests and boards have all been updated (Progress.AfterRaid), and sent to that goblin only:
--   the Shinies the raid paid and the balance;
--   up to two QUESTS that moved (finished ones first: claim them at the board);
--   a GOAL: a boat (or pet) you can afford right now, or the nearest one to save for and about how many raids away;
--   RECORDS: the week's best haul, a place on a board;
--   one SUGGESTION from the Port: a game a quest wants, one never tried, or one with a best to beat.
-- The next raid's world chaos is shown by the client itself (it is chosen a moment after this is sent).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Economy = require(script.Parent.Economy)
local Leaderboards = require(script.Parent.Leaderboards)

local Prospects = {}

local TYPICAL_RAID = 24 -- Shinies a typical raid pays (Config.PROGRESS's model: docs/GAME_DESIGN.md)

-- The thing most worth saving for: a boat you can afford now, else the nearest boat or pet.
function Prospects.goal(profile)
	local balance = profile.shinies
	local bestAfford, bestNext
	for _, slot in ipairs({ "boat", "pet" }) do
		for _, item in ipairs(Catalog.bySlot[slot] or {}) do
			if Catalog.forSale(item) and not Economy.owns(profile, item.id) then
				if item.price <= balance then
					-- The dearest boat you can afford is the most exciting; pets after boats.
					local better = not bestAfford
						or (slot == "boat" and bestAfford.slot ~= "boat")
						or (slot == bestAfford.slot and item.price > bestAfford.price)
					if better then
						bestAfford = item
					end
				else
					local short = item.price - balance
					local better = not bestNext
						or (slot == "boat" and bestNext.slot ~= "boat" and short <= (bestNext.price - balance) * 2)
						or (slot == bestNext.slot and short < bestNext.price - balance)
					if better then
						bestNext = item
					end
				end
			end
		end
	end
	local item = bestAfford or bestNext
	if not item then
		return nil
	end
	local short = math.max(0, item.price - balance)
	return {
		kind = item.slot,
		id = item.id,
		name = item.name,
		price = item.price,
		short = short,
		raids = short > 0 and math.max(1, math.ceil(short / TYPICAL_RAID)) or 0,
		class = item.class,
	}
end

local function quests(profile)
	local view = Seasons.questView(profile, os.time())
	local list = {}
	for _, kind in ipairs({ "day", "week" }) do
		for _, q in ipairs(view[kind]) do
			if not q.claimed and q.n > 0 then
				table.insert(list, {
					kind = kind,
					text = q.text,
					n = q.n,
					goal = q.goal,
					done = q.n >= q.goal,
					shinies = q.shinies,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		if a.done ~= b.done then
			return a.done
		end
		return a.n / a.goal > b.n / b.goal
	end)
	while #list > 2 do
		table.remove(list)
	end
	return list, view
end

local function suggestion(profile, view)
	-- A Port game one of today's quests wants.
	for _, kind in ipairs({ "day", "week" }) do
		for _, q in ipairs(view[kind]) do
			if q.go and not q.claimed and q.n < q.goal then
				local def = PortGames.BY_ID[q.go]
				if def then
					return { game = def.id, name = def.name, icon = def.icon, why = "quest" }
				end
			end
		end
	end
	-- One never tried.
	for _, def in ipairs(PortGames.GAMES) do
		if not profile.games.plays[def.id] then
			return { game = def.id, name = def.name, icon = def.icon, why = "new" }
		end
	end
	-- A best to beat (a different one each time).
	local list = {}
	for _, def in ipairs(PortGames.GAMES) do
		if profile.games.best[def.id] then
			table.insert(list, def)
		end
	end
	if #list > 0 then
		local def = list[(profile.stats.raids % #list) + 1]
		return {
			game = def.id,
			name = def.name,
			icon = def.icon,
			why = "best",
			best = profile.games.best[def.id],
			unit = def.unit,
		}
	end
	return nil
end

function Prospects.init()
	Progress.AfterRaid:Connect(function(player, s, result)
		local profile = s.profile
		local questList, view = quests(profile)
		local records = {}
		if (result.gold or 0) > 0 then
			local best = Seasons.best(profile, "haul", os.time())
			if best and best == result.gold then
				table.insert(
					records,
					{ kind = "haul", text = string.format("Best haul this week: %d gold", result.gold) }
				)
			end
			local rank = Leaderboards.rankOf(player, "haul")
			if rank and rank <= Config.SEASONS.HALL then
				table.insert(records, { kind = "rank", text = string.format("#%d on this week's Biggest Haul", rank) })
			end
			local champ = Seasons.best(profile, "champion", os.time())
			if champ and #records < 2 then
				table.insert(
					records,
					{ kind = "champion", text = string.format("Pirate Championship: %d gold so far this month", champ) }
				)
			end
		end
		Net.send(player, "NextUp", {
			shinies = result.breakdown and result.breakdown.total or 0,
			balance = profile.shinies,
			gold = result.gold,
			place = result.place,
			raiders = result.raiders,
			quests = questList,
			goal = Prospects.goal(profile),
			records = records,
			suggest = suggestion(profile, view),
		})
	end)
end

return Prospects

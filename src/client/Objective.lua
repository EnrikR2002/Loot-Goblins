-- The objective chip (V12; V13 shorter): one short line at the bottom that says what to do next, with the key for it.
-- It is the main way a first raid is taught; V11 said "find a boat!" to a goblin walking into the Hoard and never how.
-- V13, PROGRESSIVE: for a goblin's first Objective.TEACH_RAIDS raids it says everything, with keys. After that it only
-- speaks when the moment matters (carrying treasure, in the water, a treasure right here, spirit form) and stays quiet
-- the rest of the time (an empty line: Hud.lua hides the chip).
-- Pure: Hud.lua gathers the goblin's state and draws the result; tests/luau/Specs/CohesionSpec.lua checks it.
--
-- state = {
--   phase,          "raid" or anything else (the Port: no chip, client/PortHud.lua speaks there)
--   raids,          raids this goblin has played (the Raids attribute)
--   carrying,       the carried treasure's { name, value } or nil
--   bonus,          its interest so far
--   hoardDistance,  studs to the Hoard, across the ground
--   nearHoard,      within running distance of the gold ring (and not at the wheel)
--   inBoat, swimming, inWard, spirit,
--   recallLeft,     seconds until B can call a boat (0: now)
--   nearest,        the nearest waiting treasure { name, distance, way } or nil (way: how to reach one under a roof)
-- }
-- Returns the text ("" for nothing to say) and a tone: "carry", "spirit", "home", "water", "treasure" or "plain".
local Objective = {}

Objective.NEAR_TREASURE = 170 -- studs: close enough to name the treasure
Objective.WALK_HOME = 320 -- studs: a carrier on foot this near the Hoard is on (or just off) Goblin Cove: walk
Objective.TEACH_RAIDS = 3 -- raids during which the chip teaches everything

local function callBoat(state, teaching)
	if (state.recallLeft or 0) > 0 then
		return string.format("boat in %ds (B)", math.ceil(state.recallLeft))
	end
	return teaching and "B calls a boat to you" or "B: boat"
end

function Objective.line(state)
	if state.phase ~= "raid" then
		return "", "plain"
	end
	local teaching = (state.raids or 0) < Objective.TEACH_RAIDS
	local carrying = state.carrying
	if carrying then
		local how
		if state.nearHoard then
			how = "RUN INTO THE GOLD RING"
		elseif state.inBoat then
			how = teaching and "follow the gold arrow · SHIFT boost" or "SHIFT boost"
		elseif (state.hoardDistance or math.huge) <= Objective.WALK_HOME then
			how = "walk to the GOLD RING"
		else
			how = teaching and "B: call a boat, follow the gold arrow" or "B: boat"
			if (state.recallLeft or 0) > 0 then
				how = callBoat(state, teaching)
			end
		end
		return string.format(
			"%s (%dg) · HOARD %d · %s",
			string.upper(carrying.name),
			carrying.value + (state.bonus or 0),
			state.hoardDistance or 0,
			how
		),
			"carry"
	elseif state.spirit then
		return "👻 SPIRIT: grab loot, E snaps you back", "spirit"
	end
	local nearest = state.nearest
	local near = nearest and nearest.distance < Objective.NEAR_TREASURE
	-- A treasure under a roof says the way in, even to a goblin swimming there (Skull Rock's is past a lagoon).
	if near and nearest.way then
		return string.format("%s · %d studs · %s: HOLD E", nearest.name, math.floor(nearest.distance), nearest.way),
			"treasure"
	elseif state.swimming then
		return "In the water: " .. callBoat(state, teaching), "water"
	end
	if near then
		if nearest.distance < 25 then
			return nearest.name .. " · right here: HOLD E", "treasure"
		end
		return string.format("%s · %d studs · HOLD E at it", nearest.name, math.floor(nearest.distance)), "treasure"
	end
	if not teaching then
		return "", "plain"
	end
	if state.inWard then
		return "HOME · E at a boat (or B) · M: pick a treasure", "home"
	elseif state.inBoat then
		return "Sail to a treasure beam (M) · SHIFT boost · SPACE jump · R ability", "plain"
	end
	return "Find a treasure beam (M: map) · HOLD E · bring it to the HOARD", "plain"
end

return Objective

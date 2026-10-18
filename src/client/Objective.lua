-- The objective line (V12): one line at the bottom that always says what to do next, with the key for it. It is
-- the main way a first raid is taught; V11 said "find a boat!" to a goblin walking into the Hoard and never how.
-- Pure: Hud.lua gathers the goblin's state and draws the result; tests/luau/Specs/CohesionSpec.lua checks it.
--
-- state = {
--   phase,          "raid" or anything else (between raids)
--   carrying,       the carried treasure's { name, value } or nil
--   bonus,          its interest so far
--   hoardDistance,  studs to the Hoard, across the ground
--   nearHoard,      within running distance of the gold ring (and not at the wheel)
--   inBoat, swimming, inWard, spirit,
--   recallLeft,     seconds until B can call a boat (0: now)
--   nearest,        the nearest waiting treasure { name, distance, way } or nil (way: how to reach one under a roof)
-- }
-- Returns the text and a tone: "carry", "spirit", "home", "water", "treasure" or "plain".
local Objective = {}

Objective.NEAR_TREASURE = 170 -- studs: close enough to name the treasure
Objective.WALK_HOME = 320 -- studs: a carrier on foot this near the Hoard is on (or just off) Goblin Cove: walk

local function callBoat(state)
	if (state.recallLeft or 0) > 0 then
		return string.format("a boat can be called in %ds (B)", math.ceil(state.recallLeft))
	end
	return "B calls a boat to you"
end

function Objective.line(state)
	if state.phase ~= "raid" then
		return "Raid starting soon. Pick an island on the map (M), then climb into a cannon (E).", "plain"
	end
	local carrying = state.carrying
	if carrying then
		local how
		if state.nearHoard then
			how = "RUN INTO THE GOLD RING"
		elseif state.inBoat then
			how = "follow the gold arrow, keep your speed (SHIFT)"
		elseif (state.hoardDistance or math.huge) <= Objective.WALK_HOME then
			how = "follow the gold arrow to the GOLD RING"
		else
			how = "B: call a boat, then follow the gold arrow"
			if (state.recallLeft or 0) > 0 then
				how = callBoat(state) .. ", then the gold arrow"
			end
		end
		return string.format(
			"YOU HAVE THE %s (%dg)!  HOARD %d  -  %s",
			string.upper(carrying.name),
			carrying.value + (state.bonus or 0),
			state.hoardDistance or 0,
			how
		),
			"carry"
	elseif state.spirit then
		return "SPIRIT FORM: grab loot and snap back with it (E). Guard your body!", "spirit"
	elseif state.inWard then
		return "You're home. E at a boat at the docks (or B calls one), then M: pick a treasure to go for.", "home"
	elseif state.inBoat then
		return "Sail to a treasure beam (M: map).  SHIFT boost  -  SPACE jump  -  R tricks in the air", "plain"
	end
	local nearest = state.nearest
	local near = nearest and nearest.distance < Objective.NEAR_TREASURE
	-- A treasure under a roof says the way in, even to a goblin swimming there (Skull Rock's is past a lagoon).
	if near and nearest.way then
		return string.format(
			"The %s is %d studs away, %s: HOLD E at it.",
			nearest.name,
			math.floor(nearest.distance),
			nearest.way
		),
			"treasure"
	elseif state.swimming then
		return "In the water: " .. callBoat(state) .. " (or swim ashore).", "water"
	end
	if near then
		return string.format(
			"The %s is %d studs away: find its glowing beam and HOLD E at it.",
			nearest.name,
			math.floor(nearest.distance)
		),
			"treasure"
	end
	return "Find a treasure beam (M: map) and HOLD E at it. Then bring it to the HOARD.", "plain"
end

return Objective

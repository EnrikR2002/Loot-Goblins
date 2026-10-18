-- Where a goblin who picks an island comes down (V12). Pure: points and numbers, no instances, so the rule is
-- testable (tests/luau/Specs/CohesionSpec.lua) and the server (server/Skyship.lua) only does the raycasts.
--
-- One spot per island: dry, level, open ground as near the island's treasure as there is. The search walks
-- rings out from the treasure, trying the side facing the skyship first (the arc comes in over the sea, not
-- over a mountain), then turning both ways in 30 degree steps.
local Landing = {}

-- Studs from the treasure. The outer rings are for islands whose treasure stands on a scrap of ground (Coral
-- Atoll's clam sits on a tiny islet in its lagoon): better a short walk than a landing in the water.
Landing.RINGS = { 14, 24, 36, 50, 66, 85, 105, 130 }
Landing.STEPS = 12 -- bearings tried per ring
Landing.LEVEL = 0.8 -- the ground's normal must point at least this much up
Landing.ABOVE = 14 -- no higher than this above the treasure (Ember Peak's crater rim, not a peak over it)...
Landing.BELOW = 30 -- ...and no lower than this below it (the far side of a cliff)
-- Two passes: first STRICT (well above the sea, a wide apron of good ground round it), then, for an island with no
-- such ground near its treasure, LOOSE. A throw can be a few studs out, and a spot on a thin sand bar or right at
-- the waterline put the goblin in the water beside it, to skip three times away from the island.
-- `approach`: back toward the skyship there must be no water this far out (anything dry will do): a throw from
-- the ship comes down steeply and a few studs short of where it was aimed (measured in Studio: 3 to 13 studs once
-- server/Flight.lua stopped counting splashes early over a beach).
Landing.PASSES = {
	{ sea = 5, apron = 14, approach = 12 },
	{ sea = 1.5, apron = 8, approach = 0 },
}
-- The (x, z) points to try, in order. `spot` is the treasure's position, `toward` the skyship's.
function Landing.candidates(spot, toward)
	local out = {}
	local dir = Vector3.new(toward.X - spot.X, 0, toward.Z - spot.Z)
	dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(0, 0, -1)
	for _, radius in ipairs(Landing.RINGS) do
		for step = 0, Landing.STEPS - 1 do
			local turn = math.ceil(step / 2) * (step % 2 == 0 and 1 or -1) * (2 * math.pi / Landing.STEPS)
			local cos, sin = math.cos(turn), math.sin(turn)
			-- A turn about the vertical (the same sense as CFrame.Angles(0, turn, 0)).
			local x = dir.X * cos + dir.Z * sin
			local z = -dir.X * sin + dir.Z * cos
			table.insert(out, Vector3.new(spot.X + x * radius, 0, spot.Z + z * radius))
		end
	end
	return out
end

-- The points round a candidate that must be good ground too (eight bearings, `radius` studs out).
function Landing.apron(point, radius)
	local out = {}
	for i = 0, 7 do
		local a = i * math.pi / 4
		table.insert(out, Vector3.new(point.X + math.cos(a) * radius, 0, point.Z + math.sin(a) * radius))
	end
	return out
end

-- The points back toward the skyship (`toward`) from a candidate, every 12 studs out to `reach`.
function Landing.approach(point, toward, reach)
	local out = {}
	local dir = Vector3.new(toward.X - point.X, 0, toward.Z - point.Z)
	if dir.Magnitude < 1 then
		return out
	end
	dir = dir.Unit
	for distance = 12, reach or 0, 12 do
		table.insert(out, Vector3.new(point.X + dir.X * distance, 0, point.Z + dir.Z * distance))
	end
	return out
end

-- Is what a downward ray found a good place to come down? `hit` is a plain table:
-- { y, normalY, water, structure, lava } (structure: a built thing such as a hut roof or a dock post).
-- `sea`: how far above the sea it must be (a pass's `sea`; the strict pass's when omitted).
function Landing.acceptable(hit, spotY, sea)
	if not hit or hit.water or hit.structure or hit.lava then
		return false
	end
	return hit.normalY > Landing.LEVEL
		and hit.y > (sea or Landing.PASSES[1].sea)
		and hit.y <= spotY + Landing.ABOVE
		and hit.y >= spotY - Landing.BELOW
end

return Landing

-- The rules of the round between raids (V13, the Goblin Port), as pure functions. Shared, so the server
-- (server/Raid.lua, server/Port.lua), the client's Port screen and the tests (tests/luau/Specs/LobbySpec.lua) agree.
--
--   PORT  ->  skyship launch window  ->  raid  ->  PORT ...
--
-- A goblin is in one of two places: the PORT (the harbour town between raids, and anyone who joined while a raid was
-- running) or the RAID (aboard the skyship, flying, or out on the archipelago). Only goblins in the raid score, earn a
-- raid's Shinies, can be hit by the world or rob each other.
local Config = require(script.Parent:WaitForChild("Config"))

local Lobby = {}

local P = Config.PORT

-- Is a world position inside the Port's zone?
function Lobby.inPort(position)
	if typeof(position) ~= "Vector3" then
		return false
	end
	local dx, dz = position.X - P.CENTER.X, position.Z - P.CENTER.Z
	return dx * dx + dz * dz < P.RADIUS * P.RADIUS
end

-- Seconds of raid left at time `now` (nil when no raid runs). phaseEndsAt is the raid's end.
function Lobby.raidLeft(phase, now, phaseEndsAt)
	if phase ~= "raid" or type(phaseEndsAt) ~= "number" then
		return nil
	end
	return math.max(0, phaseEndsAt - now)
end

-- May a goblin in the Port join the raid that is running? Returns ok, and a short reason when not.
-- Late joiners go through the skyship like everyone else (with its deck grace), start with no gold and earn only
-- what they actually play for, so the only rule is that enough raid is left to be worth it.
function Lobby.canJoinLate(phase, now, phaseEndsAt, alreadyIn)
	if alreadyIn then
		return false, "in"
	end
	local left = Lobby.raidLeft(phase, now, phaseEndsAt)
	if not left then
		return false, "noraid"
	end
	if left < P.LATE_JOIN_MIN then
		return false, "late"
	end
	return true, nil
end

-- When the Port's countdown should end, given who is ready. `endsAt` is the countdown as it stands; with every
-- goblin in the Port on the boarding plank (and at least one goblin there) it is brought forward to READY_SECONDS
-- from now, never pushed back. With nobody in the server at all it is held (EMPTY_HOLD): returns now + DURATION.
function Lobby.portEndsAt(now, endsAt, inPort, ready, inServer)
	if P.EMPTY_HOLD and (inServer or 0) == 0 then
		return now + P.DURATION
	end
	if (inPort or 0) > 0 and (ready or 0) >= inPort then
		return math.min(endsAt, now + P.READY_SECONDS)
	end
	return endsAt
end

-- Should a running raid end early? Only when nobody is left in it.
function Lobby.raidAbandoned(participants)
	return (participants or 0) == 0
end

-- Spectating. `targets` is a list of { userId, name } of goblins in the raid, in any order; the result is sorted by
-- name so pressing next and back walks a stable ring. `current` is the userId being watched (or nil).
function Lobby.sortTargets(targets)
	local list = table.clone(targets)
	table.sort(list, function(a, b)
		if a.name == b.name then
			return a.userId < b.userId
		end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return list
end

-- The next target from `current`, `step` places along (1 next, -1 back). nil when there is nobody to watch. A
-- current target who has gone (left, or is no longer in the raid) gives the first one.
function Lobby.cycle(targets, current, step)
	local list = Lobby.sortTargets(targets)
	if #list == 0 then
		return nil
	end
	local index = nil
	for i, entry in ipairs(list) do
		if entry.userId == current then
			index = i
			break
		end
	end
	if not index then
		return list[1].userId
	end
	return list[((index - 1 + (step or 1)) % #list) + 1].userId
end

-- What the Port's screen says about the raid, for a goblin standing in the Port. Returns a table:
--   { state = "countdown" | "raid" | "boarding", seconds, canJoin, reason }
function Lobby.status(phase, now, phaseEndsAt, alreadyIn)
	if phase == "raid" then
		local ok, reason = Lobby.canJoinLate(phase, now, phaseEndsAt, alreadyIn)
		return {
			state = "raid",
			seconds = Lobby.raidLeft(phase, now, phaseEndsAt) or 0,
			canJoin = ok,
			reason = reason,
		}
	end
	local left = math.max(0, (phaseEndsAt or now) - now)
	return { state = left <= 0.5 and "boarding" or "countdown", seconds = left, canJoin = false }
end

return Lobby

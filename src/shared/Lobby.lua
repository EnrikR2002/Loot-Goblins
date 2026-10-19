-- The rules of the round between raids (V13, the Goblin Port), as pure functions. Shared, so the server
-- (server/Raid.lua, server/Port.lua), the client's Port screen and the tests (tests/luau/Specs/LobbySpec.lua) agree.
--
--   PORT  ->  skyship launch window  ->  raid  ->  PORT ...
--
-- A goblin is in one of two places: the PORT (the harbour town between raids, and anyone who joined while a raid was
-- running) or the RAID (aboard the skyship, flying, or out on the archipelago). Only goblins in the raid score, earn a
-- raid's Shinies, can be hit by the world or rob each other.
--
-- V13.2: GOING IS A CHOICE. A goblin SIGNS UP for the next raid (the Port screen's JOIN button, or walking aboard the
-- Little Goblin) and can cancel until it leaves; only those signed up go. With nobody signed up the countdown waits
-- (nobody is sent on an empty raid); once someone is, it runs, and when every goblin signed up is aboard it is brought
-- forward. Anyone can stay to shop, watch or chat, join a running raid late, or leave a raid early (losing that raid's
-- gold and Shinies).
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

-- When the Port's countdown should end. `endsAt` is the countdown as it stands; `signed` is how many goblins in the
-- Port have signed up for the next raid and `aboard` how many of those stand aboard the Little Goblin. V13.2: with
-- nobody signed up (or nobody in the server: EMPTY_HOLD) the countdown is held at its full DURATION; with everyone who
-- signed up aboard it is brought forward to READY_SECONDS from now, never pushed back. (V13 counted everyone in the
-- Port, and sent them all.)
function Lobby.portEndsAt(now, endsAt, signed, aboard, inServer)
	if (P.EMPTY_HOLD and (inServer or 0) == 0) or (signed or 0) == 0 then
		return now + P.DURATION
	end
	if (aboard or 0) >= signed then
		return math.min(endsAt, now + P.READY_SECONDS)
	end
	return endsAt
end

-- V13.2: should the raid leave now? Only when the countdown is over and somebody signed up.
function Lobby.shouldDepart(now, endsAt, signed)
	return now >= endsAt and (signed or 0) > 0
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
--   { state = "countdown" | "raid" | "boarding" | "waiting" (V13.2: nobody signed up yet), seconds, canJoin, reason }
-- signed (V13.2, optional): how many have signed up for the next raid.
function Lobby.status(phase, now, phaseEndsAt, alreadyIn, signed)
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
	if signed ~= nil and signed == 0 then
		return { state = "waiting", seconds = left, canJoin = false }
	end
	return { state = left <= 0.5 and "boarding" or "countdown", seconds = left, canJoin = false }
end

return Lobby

-- Emotes and victory dances (V11, Goblin Life), as poses written over the avatar's animation each frame (the same way
-- V8 poses a dive: a joint's Transform, which both kinds of avatar joint have). No uploaded animation assets. Shared:
-- every client poses whoever is emoting near it (client/Looks.lua), and the shop's preview poses its goblin.
--
-- move.pose(t) returns { [jointName] = CFrame } for t seconds into the move. Joint names are the R15 ones; the older
-- six-part avatar's shoulders, hips, neck and root are mapped onto them (R6 below). Rotations, in the joint's frame:
-- X pitches (an arm forward and up, a leg forward, the head up), Z rolls (the right arm out with +, the left with -).
-- "Root" moves the whole body visually without moving the character: a bounce, a spin, a faceplant.
--
-- An emote never moves the character (no physics, no position): it cannot be used to travel, and it stops the moment
-- its goblin moves, jumps, sits or is hit (server/Emotes.lua).
local EmoteMoves = {}

local rad = math.rad
local sin = math.sin
local abs = math.abs

local function A(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

-- 0 -> 1 over `inTime`, then 1, then 1 -> 0 over the last `outTime` of `duration`: moves ease in and out of rest.
local function envelope(t, duration, inTime, outTime)
	inTime = inTime or 0.25
	outTime = outTime or 0.3
	local a = math.clamp(t / inTime, 0, 1)
	local b = math.clamp((duration - t) / outTime, 0, 1)
	local e = math.min(a, b)
	return e * e * (3 - 2 * e)
end

local function lerpPose(pose, e)
	if e >= 1 then
		return pose
	end
	local out = {}
	for joint, cf in pairs(pose) do
		out[joint] = CFrame.new():Lerp(cf, e)
	end
	return out
end

local MOVES = {}

MOVES.emote_wave = {
	duration = 2.4,
	pose = function(t)
		return {
			RightShoulder = A(0, 0, 150 + 18 * sin(t * 11)),
			RightElbow = A(0, 0, 25 + 20 * sin(t * 11 + 0.6)),
			Neck = A(4, 0, -8),
			Waist = A(0, 0, -4),
		}
	end,
}

MOVES.emote_cackle = {
	duration = 2.6,
	pose = function(t)
		local shake = sin(t * 26)
		return {
			Waist = A(18 + 3 * shake, 0, 0),
			Neck = A(26 + 5 * shake, 0, 0),
			LeftShoulder = A(40, 0, 18),
			RightShoulder = A(40, 0, -18),
			LeftElbow = A(75, 0, 0),
			RightElbow = A(75, 0, 0),
			Root = CFrame.new(0, 0.07 * abs(shake), 0),
		}
	end,
}

MOVES.emote_salute = {
	duration = 2.0,
	pose = function(t)
		local snap = math.clamp(t / 0.18, 0, 1)
		return {
			RightShoulder = A(95 * snap, 0, 52 * snap),
			RightElbow = A(0, 0, 125 * snap),
			Neck = A(6, 0, 0),
			Waist = A(-4, 0, 0),
		}
	end,
}

MOVES.emote_panic = {
	duration = 2.8,
	pose = function(t)
		return {
			LeftShoulder = A(10 * sin(t * 17), 0, -(150 + 25 * sin(t * 19))),
			RightShoulder = A(10 * sin(t * 17 + 1), 0, 150 + 25 * sin(t * 19 + 1.7)),
			LeftElbow = A(0, 0, -30 * sin(t * 23)),
			RightElbow = A(0, 0, 30 * sin(t * 23 + 1)),
			LeftHip = A(0, 0, -6 + 6 * sin(t * 21)),
			RightHip = A(0, 0, 6 - 6 * sin(t * 21)),
			Neck = A(10, 22 * sin(t * 15), 0),
			Root = CFrame.new(0.05 * sin(t * 31), 0, 0),
		}
	end,
}

MOVES.emote_jig = {
	duration = 3.2,
	pose = function(t)
		local beat = t * 8
		local left = math.max(0, sin(beat))
		local right = math.max(0, -sin(beat))
		return {
			LeftShoulder = A(0, 0, -35),
			RightShoulder = A(0, 0, 35),
			LeftElbow = A(0, 0, 95),
			RightElbow = A(0, 0, -95),
			LeftHip = A(40 * left, 0, -6 * left),
			RightHip = A(40 * right, 0, 6 * right),
			LeftKnee = A(-50 * left, 0, 0),
			RightKnee = A(-50 * right, 0, 0),
			Root = CFrame.new(0, 0.25 * abs(sin(beat)), 0) * A(0, 14 * sin(t * 4), 0),
			Neck = A(0, 0, 10 * sin(beat)),
		}
	end,
}

MOVES.emote_flex = {
	duration = 2.6,
	pose = function(t)
		local pump = 8 * sin(t * 9)
		return {
			LeftShoulder = A(0, 0, -90),
			RightShoulder = A(0, 0, 90),
			LeftElbow = A(0, 0, -(95 + pump)),
			RightElbow = A(0, 0, 95 + pump),
			Waist = A(-6, 12 * sin(t * 3), 0),
			Neck = A(10, -10 * sin(t * 3), 0),
		}
	end,
}

MOVES.emote_faceplant = {
	duration = 3.0,
	pose = function(t)
		local fall = math.clamp(t / 0.45, 0, 1)
		fall = fall * fall
		local twitch = t > 1.2 and 6 * math.max(0, sin(t * 22)) * (t < 2.2 and 1 or 0) or 0
		return {
			Root = CFrame.new(0, -1.9 * fall, -0.6 * fall) * A(-86 * fall, 0, 0),
			LeftShoulder = A(-25 * fall, 0, -10),
			RightShoulder = A(-25 * fall, 0, 10),
			LeftHip = A(-12 * fall + twitch, 0, 0),
			RightHip = A(-12 * fall - twitch, 0, 0),
			Neck = A(-10 * fall, 0, 0),
		}
	end,
	inTime = 0.05,
	outTime = 0.35,
}

-- Victory dances (played on the skyship's deck by the raid's winner, and in the shop's preview).
MOVES.victory_cheer = {
	duration = 3.6,
	victory = true,
	pose = function(t)
		local hop = abs(sin(t * 5))
		return {
			LeftShoulder = A(0, 0, -165 - 8 * sin(t * 10)),
			RightShoulder = A(0, 0, 165 + 8 * sin(t * 10)),
			Neck = A(18, 0, 0),
			Root = CFrame.new(0, 0.5 * hop, 0),
			LeftKnee = A(-25 * hop, 0, 0),
			RightKnee = A(-25 * hop, 0, 0),
		}
	end,
}

MOVES.victory_stomp = {
	duration = 4.0,
	victory = true,
	pose = function(t)
		local beat = t * 7
		local left = math.max(0, sin(beat))
		local right = math.max(0, -sin(beat))
		return {
			LeftHip = A(55 * left, 0, 0),
			RightHip = A(55 * right, 0, 0),
			LeftKnee = A(-70 * left, 0, 0),
			RightKnee = A(-70 * right, 0, 0),
			LeftShoulder = A(60 * right, 0, -40),
			RightShoulder = A(60 * left, 0, 40),
			LeftElbow = A(80, 0, 0),
			RightElbow = A(80, 0, 0),
			Root = CFrame.new(0, 0.15 * abs(sin(beat)), 0) * A(0, (t / 4) * 360, 0),
			Neck = A(-10 + 20 * abs(sin(beat)), 0, 0),
		}
	end,
}

MOVES.victory_shower = {
	duration = 4.0,
	victory = true,
	fx = "coins",
	pose = function(t)
		local throw = (t * 1.5) % 1
		local lift = throw < 0.5 and throw * 2 or 1
		return {
			LeftShoulder = A(30 + 140 * lift, 0, -20),
			RightShoulder = A(30 + 140 * lift, 0, 20),
			LeftElbow = A(60 * (1 - lift), 0, 0),
			RightElbow = A(60 * (1 - lift), 0, 0),
			Neck = A(30, 0, 0),
			Waist = A(10, 0, 0),
			Root = CFrame.new(0, 0.12 * lift, 0),
		}
	end,
}

MOVES.victory_crown = {
	duration = 4.0,
	victory = true,
	fx = "crown",
	pose = function(t)
		if t < 2.2 then
			local lower = math.clamp((t - 0.6) / 1.4, 0, 1)
			return {
				LeftShoulder = A(0, 0, -(170 - 40 * lower)),
				RightShoulder = A(0, 0, 170 - 40 * lower),
				LeftElbow = A(0, 0, -(20 + 70 * lower)),
				RightElbow = A(0, 0, 20 + 70 * lower),
				Neck = A(20 - 15 * lower, 0, 0),
			}
		end
		local bow = math.clamp((t - 2.4) / 0.4, 0, 1) * (t < 3.4 and 1 or math.clamp((4 - t) / 0.6, 0, 1))
		return {
			LeftShoulder = A(0, 0, -95),
			RightShoulder = A(0, 0, 95),
			Waist = A(-25 * bow, 0, 0),
			Neck = A(-10 * bow, 0, 0),
		}
	end,
}

EmoteMoves.MOVES = MOVES

-- The six-part avatar's joints, for the moves written for R15.
EmoteMoves.R6 = {
	LeftShoulder = "Left Shoulder",
	RightShoulder = "Right Shoulder",
	LeftHip = "Left Hip",
	RightHip = "Right Hip",
	Neck = "Neck",
	Root = "RootJoint",
}

function EmoteMoves.get(id)
	return MOVES[id]
end

-- The pose for move `id` at t seconds (eased in and out), or nil once it has finished.
function EmoteMoves.at(id, t)
	local move = MOVES[id]
	if not move or t < 0 or t > move.duration then
		return nil
	end
	return lerpPose(move.pose(t), envelope(t, move.duration, move.inTime, move.outTime))
end

function EmoteMoves.covers(item)
	return MOVES[item.id] ~= nil
end

return EmoteMoves

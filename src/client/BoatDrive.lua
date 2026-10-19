-- Driving a boat from the client.
--
-- When you sit in a driver's seat, the server hands your client the hull's physics (the
-- model's Pilot attribute becomes your UserId; Config.BOAT_CLIENT_PHYSICS). From then on this
-- module runs shared/BoatSim on it every physics step, reading the seat's throttle and steer
-- directly, so the boat answers the frame you press a key. The server still decides hull
-- health, crashes, sinking and boost cooldowns, and takes the hull back if it moves in a way
-- BoatSim could not have moved it.
--
-- With that setting off, the server simulates every boat and this module only passes the
-- boost and drift keys along.
--
-- It also draws every nearby boat's wake and spray, from how fast and how sideways it moves.
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local BoatSim = require(Shared:WaitForChild("BoatSim"))
local Sea = require(Shared:WaitForChild("Sea"))
local Twister = require(Shared:WaitForChild("Twister"))

local BoatDrive = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local boostRemote = remotes:WaitForChild("BoatBoostRequest")
local driftRemote = remotes:WaitForChild("BoatDriftRequest")
local fxRemote = remotes:WaitForChild("BoatFxRequest")
local jumpRemote = remotes:WaitForChild("BoatJumpRequest")
local abilityRemote = remotes:WaitForChild("BoatAbilityRequest")
local gunRemote = remotes:WaitForChild("BoatGunRequest") -- V13.2
local chainRemote = remotes:WaitForChild("BoatChainRequest") -- V13.2

local gates = {}
local sim, simHull = nil, nil
local driftHeld = false
local predictedReadyAt = 0 -- Our own guess at the boost cooldown until the server's arrives.
local seenRefund = 0 -- The boat's BoostRefund total when we last looked (coins hand cooldown back).
local input = { throttle = 0, steer = 0, drift = false, jump = false }
local jumpQueued = false
local info = { driving = false, speed = 0, charge = 0, level = 0, drifting = false }
local onEvent = function(_kind, _position, _a, _b) end
local spinSide = 1
local trickQueued = false -- R pressed during a trick: the next one starts when it ends
-- V13: the class ability (the stunt key on the water). Queued for the next physics step, sent to the server only once
-- it has actually played; our own guess at its cooldown until the server's attribute arrives.
local abilityQueued = false
local abilityTarget = nil -- V13.2: where the anchor or the hook goes ({ point } or { part }), chosen at the key press
local predictedAbilityAt = 0
local predictedGunAt = 0 -- V13.2: our own guess at the bow gun's reload
local aimProvider = function()
	return nil
end

local function now()
	return workspace:GetServerTimeNow()
end

-- The driver's seat you are sitting in and its boat model, or nil.
local function seatAndModel()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local model = seat.Parent
		if model and model:GetAttribute("BoatType") then
			return seat, model
		end
	end
	return nil, nil
end

-- V11: the boat model you are driving, or nil (client/Looks.lua draws its trick effects).
function BoatDrive.model()
	local _, model = seatAndModel()
	return model
end

-- Main sets this: function(kind, position, a, b) for "mini1", "mini2", "landing", "splash", "hoop",
-- "kick" (a: how many hoops in a row this one makes), and V9's "trickstart" (a: the trick), "trick" (a: the
-- trick, b: how many this flight), "trickland" (a: how many), "sketchy", "bail", "twister".
function BoatDrive.onEvent(callback)
	onEvent = callback
end

function BoatDrive.isDriving()
	return (seatAndModel()) ~= nil
end

-- Shift in the driver's seat. Starts the burst here at once; the server confirms it.
function BoatDrive.boost()
	local _, model = seatAndModel()
	if not model then
		return
	end
	boostRemote:FireServer()
	local t = now()
	local readyAt = math.max(model:GetAttribute("BoostReadyAt") or 0, predictedReadyAt)
	if sim and t >= readyAt and not model:GetAttribute("Moored") then
		sim.boostUntil = t + Config.BOAT_BOOST_TIME
		predictedReadyAt = t + (sim.spec.boostCooldown or Config.BOAT_BOOST_COOLDOWN)
	end
end

-- V13: where the driver is looking (Main sets it: the same aim the grapple and the kegs use). Sent with an ability
-- that fires something (the bow gun, the volley).
function BoatDrive.setAimProvider(fn)
	aimProvider = fn
end

-- V13.2: where a thrown anchor or boarding hook goes: a rival hull near the aim line (in range, ahead of the bow), or
-- for the anchor the first rock along the aim, or the sea bed at the end of the throw; for the hook a rock within its
-- zip range. The server makes the same choice (BoatAbilities) and corrects us if it disagrees. nil: nothing to hook.
local biteParams = RaycastParams.new()
biteParams.FilterType = Enum.RaycastFilterType.Exclude
biteParams.IgnoreWater = true
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function chooseTarget(kind)
	local A = Config.BOAT_ABILITIES[kind]
	local hull = simHull
	local here = flat(hull.Position)
	local look = flat(hull.CFrame.LookVector)
	look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
	local aim = aimProvider()
	local aimDir = aim and flat(aim - hull.Position) or look
	aimDir = aimDir.Magnitude > 1 and aimDir.Unit or look
	local range = A.range
	local cone = kind == "anchor" and A.arc or A.cone
	local assist = kind == "anchor" and A.assist or 30
	local best, bestScore = nil, math.huge
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local structures = generated and generated:FindFirstChild("Structures")
	if structures then
		for _, model in ipairs(structures:GetChildren()) do
			local other = model:GetAttribute("BoatType") and model:FindFirstChild("Hull")
			if other and other ~= hull and model:GetAttribute("BoatType") ~= "navy" then
				local offset = flat(other.Position) - here
				local distance = offset.Magnitude
				if distance > 4 and distance <= range + other.Size.Z * 0.5 then
					local along = offset:Dot(aimDir)
					local off = (offset - aimDir * along).Magnitude
					if offset.Unit:Dot(look) >= cone and along > 0 and off <= assist + other.Size.X then
						local score = off + distance * 0.15
						if score < bestScore then
							best, bestScore = other, score
						end
					end
				end
			end
		end
	end
	if best then
		return { part = best }
	end
	if aimDir:Dot(look) < -0.2 then
		aimDir = look
	end
	biteParams.FilterDescendantsInstances = { hull.Parent }
	local reach = kind == "anchor" and range or A.zip
	local from = hull.Position + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, aimDir * reach, biteParams)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:GetAttribute("BoatType")) then
			return { point = hit.Position }
		end
	end
	if kind == "anchor" then
		local toward = aim and flat(aim - hull.Position).Magnitude or range * 0.6
		return { point = here + aimDir * math.clamp(toward, 40, range) }
	end
	return nil
end

-- The class ability. Returns true if it was queued (it plays on the next physics step, on the water).
function BoatDrive.ability()
	if not sim then
		return false
	end
	local t = now()
	-- V13.2: R while your own anchor holds lets it go (BoatSim turns it into a sling).
	if sim.tether and (sim.tether.kind == "swing" or sim.tether.kind == "snag") then
		abilityQueued = true
		return true
	end
	if t < predictedAbilityAt then
		return false
	end
	sim.abilityReadyAt = math.max(simHull.Parent:GetAttribute("AbilityReadyAt") or 0, predictedAbilityAt)
	if not BoatSim.abilityReady(sim, t) then
		return false
	end
	local id = sim.spec.ability
	abilityTarget = nil
	if id == "anchor" or id == "hook" then
		abilityTarget = chooseTarget(id)
		if not abilityTarget then
			BoatDrive.toast("Nothing to hook: aim at a boat (or a rock) ahead.")
			return false
		end
	end
	abilityQueued = true
	return true
end

-- V13.2: the bow gun (a click, R2, the touch GUN button). Fires where the driver looks; the server judges it.
-- Returns true if a shot was asked for.
function BoatDrive.fireGun()
	local _, model = seatAndModel()
	if not model then
		return false
	end
	local t = now()
	local readyAt = math.max(model:GetAttribute("GunReadyAt") or 0, predictedGunAt)
	if t < readyAt then
		return false
	end
	predictedGunAt = t + Config.BOAT_GUN.cooldown
	gunRemote:FireServer(aimProvider())
	return true
end

-- For the HUD: { readyAt, cooldown } of the bow gun on the boat being driven, or nil.
function BoatDrive.gunInfo()
	local _, model = seatAndModel()
	if not model then
		return nil
	end
	return {
		readyAt = math.max(model:GetAttribute("GunReadyAt") or 0, predictedGunAt),
		cooldown = Config.BOAT_GUN.cooldown,
	}
end

-- Main sets this: a short note on the screen.
BoatDrive.toast = function(_text) end

-- V13: the stunt key (R, R1, the touch STUNT button). In the air: a trick. On the water: the boat's ability.
-- Returns "trick", "ability" or nil (nothing happened).
function BoatDrive.stunt()
	if not sim then
		return nil
	end
	local airborne = (sim.out.wet or 0) <= 0 and not sim.grounded
	if airborne or sim.trick then
		return BoatDrive.trick() and "trick" or nil
	end
	return BoatDrive.ability() and "ability" or nil
end

-- The server refused an ability (its cooldown, a rule like "no tornado near home"): forget our own guess, and any
-- chain our own physics started for it (V13.2).
function BoatDrive.abilityRefused()
	predictedAbilityAt = 0
	if sim then
		sim.tether = nil
	end
end

-- V13.2: the server put a chain on our hull, or took one off (a rival's anchor caught us; our own was corrected or
-- snapped). payload: { hull, tether = { kind, part, point, length, untilAt } | nil }.
function BoatDrive.tether(payload)
	if not sim or payload.hull ~= simHull then
		return
	end
	local tether = payload.tether
	if type(tether) ~= "table" then
		sim.tether = nil
		return
	end
	sim.tether = {
		kind = tether.kind,
		part = typeof(tether.part) == "Instance" and tether.part or nil,
		point = typeof(tether.point) == "Vector3" and tether.point or nil,
		length = tonumber(tether.length) or 40,
		untilAt = tonumber(tether.untilAt) or now(),
		startGap = 0,
	}
end

-- V13.2: which chain holds our hull now ("swing", "snag", "towed", "reel", "zip"), for the HUD.
function BoatDrive.tethered()
	return sim and sim.tether and sim.tether.kind or nil
end

-- For the HUD: { id, readyAt, cooldown } of the boat being driven, or nil.
function BoatDrive.abilityInfo()
	local _, model = seatAndModel()
	local spec = model and Config.BOAT_TYPES[model:GetAttribute("BoatType")]
	local id = spec and spec.ability
	local a = id and Config.BOAT_ABILITIES[id]
	if not a then
		return nil
	end
	return {
		id = id,
		def = a,
		readyAt = math.max(model:GetAttribute("AbilityReadyAt") or 0, predictedAbilityAt),
		cooldown = a.cooldown,
		airborne = sim ~= nil and (sim.out.wet or 0) <= 0 and not sim.grounded,
	}
end

-- Space in the driver's seat: a hop. Our own sim plays it this frame; if the server is the one
-- simulating (the setting is off, or it took the hull back), it is asked to.
function BoatDrive.jump()
	local _, model = seatAndModel()
	if not model then
		return
	end
	if sim then
		jumpQueued = true
	else
		jumpRemote:FireServer()
	end
end

-- V9: R (gamepad R1) in the air: a trick. One button, nothing to learn: the first press in a flight is a flat
-- spin and each further press the next in a combo (corkscrew, front flip, double spin, ...). Holding A or D
-- rolls that way instead; holding S, a backflip. (W is ignored: a driver is nearly always holding it.) A press
-- during a trick is kept and plays when it ends. Returns the trick's name, or nil if the boat is not in the air.
local COMBO = { "spin", "corkscrew", "frontflip", "spin2" }
local TRICK_NAMES = {
	spin = "SPIN CYCLE",
	spin2 = "DOUBLE SPIN",
	roll = "BARREL ROLL",
	backflip = "KEEL FLIP",
	frontflip = "BOW FLIP",
	corkscrew = "CORKSCREW",
}
BoatDrive.TRICK_NAMES = TRICK_NAMES

function BoatDrive.trick()
	local seat, model = seatAndModel()
	if not model or not sim then
		return nil
	end
	local t = now()
	if sim.trick then
		trickQueued = true
		return sim.trick.kind
	end
	local steer, throttle = seat.SteerFloat, seat.ThrottleFloat
	local kind, side
	if steer < -0.3 then
		kind, side = "roll", -1
	elseif steer > 0.3 then
		kind, side = "roll", 1
	elseif throttle < -0.3 then
		kind, side = "backflip", 1
	else
		kind = COMBO[(sim.tricksDone or 0) % #COMBO + 1]
		spinSide = -spinSide
		side = spinSide
	end
	if BoatSim.startTrick(sim, kind, side, t) then
		onEvent("trickstart", simHull.Position, kind, side)
		return kind
	end
	return nil
end

-- C held in the driver's seat.
function BoatDrive.setDrift(held)
	if held ~= driftHeld then
		driftHeld = held
		driftRemote:FireServer(held)
	end
end

-- The server pushed our hull (a blast, a waterspout). We simulate it, so we apply it.
function BoatDrive.push(payload)
	if sim and payload.hull == simHull and typeof(payload.velocity) == "Vector3" then
		simHull:ApplyImpulse(payload.velocity * simHull.AssemblyMass)
		if typeof(payload.spin) == "Vector3" then
			simHull:ApplyAngularImpulse(payload.spin * simHull.AssemblyMass * 20)
		end
		-- V13.1: the Guardian's launch throws the boat end over end (BoatSim.tumble).
		if type(payload.tumble) == "number" then
			BoatSim.tumble(sim, payload.tumble, math.random() < 0.5 and -1 or 1, now())
		end
	end
end

-- For the HUD: { driving, speed, charge, level, drifting, boosting, airborne, tricking, twister }.
function BoatDrive.info()
	return info
end

RunService.PreSimulation:Connect(function(dt)
	local seat, model = seatAndModel()
	local hull = model and model:FindFirstChild("Hull")
	info.driving = hull ~= nil
	if not hull then
		sim, simHull = nil, nil
		if driftHeld then
			BoatDrive.setDrift(false)
		end
		return
	end
	local velocity = hull.AssemblyLinearVelocity
	info.speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if model:GetAttribute("Pilot") ~= player.UserId then
		-- The server is simulating this boat (the setting is off, or it took the hull back).
		sim, simHull = nil, nil
		info.charge, info.level, info.drifting = 0, 0, false
		return
	end
	if simHull ~= hull then
		sim = BoatSim.new(hull, Config.BOAT_TYPES[model:GetAttribute("BoatType")])
		simHull = hull
		seenRefund = model:GetAttribute("BoostRefund") or 0
	end
	-- The server handed some boost cooldown back (a coin, salvage): our own guess follows.
	local refund = model:GetAttribute("BoostRefund") or 0
	if refund ~= seenRefund then
		predictedReadyAt -= math.max(refund - seenRefund, 0)
		seenRefund = refund
	end
	local t = now()
	sim.moored = model:GetAttribute("Moored") == true
	sim.payload = model:GetAttribute("Payload") or 0
	sim.boostUntil = math.max(sim.boostUntil, model:GetAttribute("BoostEndsAt") or 0)
	input.throttle, input.steer, input.drift = seat.ThrottleFloat, seat.SteerFloat, driftHeld
	-- V13.1: knocked out at the wheel: hands off, the boat coasts.
	if player:GetAttribute("KnockedOutUntil") then
		input.throttle, input.steer, input.drift = 0, 0, false
		jumpQueued, abilityQueued = false, false
	end
	input.jump = jumpQueued
	jumpQueued = false
	input.ability = abilityQueued
	abilityQueued = false
	input.target = input.ability and abilityTarget or nil
	if input.ability then
		abilityTarget = nil
	end
	if input.ability then
		sim.abilityReadyAt = math.max(model:GetAttribute("AbilityReadyAt") or 0, predictedAbilityAt)
	end
	-- The real frame time, down to 10 frames a second, so a slow client's boat still gets its
	-- full thrust and buoyancy (the forces are impulses scaled by dt).
	local out = BoatSim.step(sim, input, math.min(dt, Config.BOAT_MAX_STEP), t)
	if out.ability then
		-- It played: now tell the server (with where we are looking) and show it.
		local a = Config.BOAT_ABILITIES[out.ability]
		predictedAbilityAt = t + (a and a.cooldown or 1)
		local target = input.target
		abilityRemote:FireServer(aimProvider(), target and { target = target.part } or nil)
		onEvent("ability", hull.Position, out.ability, target)
	end
	if out.released then
		-- V13.2: our own anchor or hook let go (R again: a sling; it reached the boat; it ran out).
		chainRemote:FireServer(out.released)
		onEvent("released", hull.Position, out.released)
	end
	if out.airhop then
		onEvent("airhop", hull.Position)
	end
	info.charge, info.level, info.drifting = out.charge, out.level, out.drifting
	info.grounded = out.grounded == true
	info.airborne = out.wet == 0 and not out.grounded
	info.tricking = sim.trick ~= nil
	info.twister = out.twister
	if out.twister and not info.wasTwisted then
		onEvent("twister", hull.Position)
	end
	info.wasTwisted = out.twister ~= nil
	if out.jumped then
		local kind = out.super and "super" or "jump"
		onEvent(kind, hull.Position, out.super)
		fxRemote:FireServer(kind)
	end
	if out.punched then
		onEvent("punch", hull.Position)
	end
	if out.event then
		if out.event == "trick" then
			onEvent("trick", hull.Position, out.trick, out.tricks)
			fxRemote:FireServer("trick", out.trick)
			if trickQueued then
				trickQueued = false
				BoatDrive.trick()
			end
		elseif out.event == "trickland" then
			trickQueued = false
			onEvent("trickland", hull.Position, out.tricks)
			fxRemote:FireServer("trickland", out.tricks)
		else
			if out.event == "sketchy" then
				trickQueued = false
			end
			onEvent(out.event, hull.Position, out.airTime)
			if out.event ~= "splash" then
				fxRemote:FireServer(out.event)
			end
		end
	end
	local gate = BoatSim.gate(sim, gates, t, true)
	if gate then
		onEvent(gate == "boost" and "hoop" or "kick", hull.Position, sim.chain or 1)
	end
end)

-- Wakes -----------------------------------------------------------------------------------
-- Every boat near you trails foam by its speed and throws spray when it slides. Drawn here
-- from the hull's own motion, so it costs the server nothing.
local wakes = {} -- hull -> { foam, spray }
local nextScanAt = 0

local function makeEmitter(parent, color, size, lifetime, speed)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.3
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function wakeFor(hull)
	local wake = wakes[hull]
	if wake then
		return wake
	end
	local size = hull.Size
	local stern = Instance.new("Attachment")
	stern.Name = "WakeStern"
	stern.Position = Vector3.new(0, -size.Y / 2 + 0.6, size.Z / 2)
	stern.Parent = hull
	local bow = Instance.new("Attachment")
	bow.Name = "WakeBow"
	bow.Position = Vector3.new(0, -size.Y / 2 + 0.8, -size.Z / 2)
	bow.Parent = hull
	wake = {
		foam = makeEmitter(stern, Color3.fromRGB(240, 248, 255), size.X * 0.32, 1.1, 5),
		spray = makeEmitter(bow, Color3.fromRGB(255, 255, 255), size.X * 0.2, 0.55, 22),
		stern = stern,
		bow = bow,
	}
	wakes[hull] = wake
	return wake
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	if t >= nextScanAt then
		nextScanAt = t + 1
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		local structures = generated and generated:FindFirstChild("Structures")
		if structures then
			for _, model in ipairs(structures:GetChildren()) do
				if model:GetAttribute("BoatType") then
					local hull = model:FindFirstChild("Hull")
					if hull then
						wakeFor(hull)
					end
				end
			end
		end
		for hull, wake in pairs(wakes) do
			if not hull.Parent or not hull:IsDescendantOf(workspace) then
				wake.stern:Destroy()
				wake.bow:Destroy()
				wakes[hull] = nil
			end
		end
	end
	local clock = os.clock()
	local camera = workspace.CurrentCamera
	for hull, wake in pairs(wakes) do
		local velocity = hull.AssemblyLinearVelocity
		local level = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = level.Magnitude
		local afloat = hull.Position.Y < 6
		local look = hull.CFrame.LookVector
		local slip = speed > 8 and (1 - math.abs(level.Unit:Dot(Vector3.new(look.X, 0, look.Z)))) or 0
		wake.foam.Rate = (afloat and speed > 10) and math.min(90, speed * 0.7) or 0
		wake.spray.Rate = (afloat and speed > 45) and math.min(120, (speed - 45) * 1.1 + slip * 220) or 0
		-- V13: a Wraith at speed leaves fading afterimages of itself (only near the camera; one every 0.09 s).
		if
			speed > 70
			and clock >= (wake.ghostAt or 0)
			and hull.Parent
			and hull.Parent:GetAttribute("BoatType") == "wraith"
			and (hull.Position - camera.CFrame.Position).Magnitude < 350
		then
			wake.ghostAt = clock + 0.09
			local ghost = Instance.new("Part")
			ghost.Name = "WraithAfterimage"
			ghost.Size = hull.Size
			ghost.CFrame = hull.CFrame
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.CastShadow = false
			ghost.Material = Enum.Material.Neon
			ghost.Color = Color3.fromRGB(110, 255, 210)
			ghost.Transparency = 0.7
			ghost.Parent = workspace
			TweenService:Create(ghost, TweenInfo.new(0.45), { Transparency = 1, Size = hull.Size * 0.8 }):Play()
			Debris:AddItem(ghost, 0.5)
		end
	end
end)

-- The static half of the sea (currents, shelter map, gates) arrives once; the weather follows
-- live. Until it arrives a boat floats on open water with no currents, which is harmless.
task.spawn(function()
	-- The world takes several seconds to build; a timeout only keeps the engine from warning.
	local value = ReplicatedStorage:WaitForChild("LootGoblinsSea", 600)
	if not value then
		return
	end
	local data = HttpService:JSONDecode(value.Value)
	Sea.import(data)
	gates = data.gates or {}
	Sea.follow()
	Twister.follow()
end)

return BoatDrive

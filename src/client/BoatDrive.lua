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
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local BoatSim = require(Shared:WaitForChild("BoatSim"))
local Sea = require(Shared:WaitForChild("Sea"))

local BoatDrive = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local boostRemote = remotes:WaitForChild("BoatBoostRequest")
local driftRemote = remotes:WaitForChild("BoatDriftRequest")
local fxRemote = remotes:WaitForChild("BoatFxRequest")

local gates = {}
local sim, simHull = nil, nil
local driftHeld = false
local predictedReadyAt = 0 -- Our own guess at the boost cooldown until the server's arrives.
local seenRefund = 0 -- The boat's BoostRefund total when we last looked (coins hand cooldown back).
local input = { throttle = 0, steer = 0, drift = false }
local info = { driving = false, speed = 0, charge = 0, level = 0, drifting = false }
local onEvent = function(_kind, _position, _chain) end

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

-- Main sets this: function(kind, position, chain) for "mini1", "mini2", "landing", "splash", "hoop",
-- "kick". chain is how many hoops in a row this one makes (hoops only).
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
		predictedReadyAt = t + Config.BOAT_BOOST_COOLDOWN
	end
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
	end
end

-- For the HUD: { driving, speed, charge, level, drifting, boosting }.
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
	-- The real frame time, down to 10 frames a second, so a slow client's boat still gets its
	-- full thrust and buoyancy (the forces are impulses scaled by dt).
	local out = BoatSim.step(sim, input, math.min(dt, Config.BOAT_MAX_STEP), t)
	info.charge, info.level, info.drifting = out.charge, out.level, out.drifting
	if out.event then
		onEvent(out.event, hull.Position)
		if out.event ~= "splash" then
			fxRemote:FireServer(out.event)
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
	for hull, wake in pairs(wakes) do
		local velocity = hull.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		local afloat = hull.Position.Y < 6
		local look = hull.CFrame.LookVector
		local slip = speed > 8 and (1 - math.abs(flat.Unit:Dot(Vector3.new(look.X, 0, look.Z)))) or 0
		wake.foam.Rate = (afloat and speed > 10) and math.min(90, speed * 0.7) or 0
		wake.spray.Rate = (afloat and speed > 45) and math.min(120, (speed - 45) * 1.1 + slip * 220) or 0
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
end)

return BoatDrive

-- The moving parts of the islands, run from the data the builders left in `refs`:
--
--   spinners   the windmill's sails (they sweep the balcony the Golden Gear sits on) and the
--              Maelstrom's foam spirals
--   levers     pull one and its gate opens for a while (the Tide Vault's portcullis)
--   gates      slide up and down; Troubles can slam one shut as a trap
--   lava       the volcano's crater burns anyone standing in it
--
--   beacons    signal fires anyone can light; Mechanisms.BeaconLit tells whoever cares (the
--              Navy turns to look: Main wires it)
--
-- Boost gates and kickers live in Boats.lua (they act on hulls). Geysers are animated and
-- applied on the client from timestamps, so there is nothing to run for them here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Gear = require(script.Parent.Gear)
local Loot = require(script.Parent.Loot)
local Impact = require(script.Parent.Impact)

local Mechanisms = {}

Mechanisms.BeaconLit = Util.signal() -- (beacon, player)

local refs
local lastBladeHit = {} -- player -> time
local nextLava = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Gates -----------------------------------------------------------------------------
function Mechanisms.openGate(gate, holdSeconds)
	if gate.lockedUntil and now() < gate.lockedUntil then
		return false
	end
	gate.target = 1
	gate.closeAt = now() + holdSeconds
	gate.fast = false
	return true
end

-- Slams the gate shut and jams it for a while.
function Mechanisms.slamGate(gate, lockSeconds)
	gate.target = 0
	gate.closeAt = nil
	gate.fast = true
	gate.lockedUntil = now() + lockSeconds
end

function Mechanisms.pull(lever, player)
	local gate = lever.gate
	if not gate then
		return
	end
	if gate.lockedUntil and now() < gate.lockedUntil then
		Net.toast(player, "The lever won't budge - the gate is jammed")
		return
	end
	-- gate.hold: how long this one stays moved. gate.pulled: what the feed says (a harbor chain
	-- does not "grind open").
	local hold = gate.hold or Config.GATE_OPEN_TIME
	if Mechanisms.openGate(gate, hold) then
		lever.handle.CFrame = lever.restCFrame * CFrame.Angles(0, 0, math.rad(-70))
		lever.knob.Color = Color3.fromRGB(110, 255, 150)
		task.delay(hold, function()
			if lever.handle.Parent then
				lever.handle.CFrame = lever.restCFrame
				lever.knob.Color = Color3.fromRGB(255, 80, 60)
			end
		end)
		Net.feed(
			player.DisplayName
				.. " "
				.. (gate.pulled or ("pulled the lever: the " .. (gate.name or "gate") .. " grinds open!")),
			Color3.fromRGB(120, 255, 190)
		)
		Net.broadcast("GateMove", { position = gate.model.PrimaryPart.Position, open = true })
	end
end

local function tickGates(dt)
	local t = now()
	for _, gate in ipairs(refs.gates) do
		if gate.closeAt and t >= gate.closeAt then
			-- Don't close on someone standing in the doorway.
			local blocked = false
			local center = gate.closed.Position
			for _, player in ipairs(Players:GetPlayers()) do
				local root = Util.aliveRoot(player)
				if root and (root.Position - center).Magnitude < 7 then
					blocked = true
				end
			end
			if not blocked then
				gate.target = 0
				gate.closeAt = nil
				Net.broadcast("GateMove", { position = center, open = false })
			end
		end
		gate.progress = gate.progress or 0
		local goal = gate.target or 0
		if gate.progress ~= goal then
			local rate = gate.fast and 4 or 0.9
			gate.progress = goal > gate.progress and math.min(goal, gate.progress + rate * dt)
				or math.max(goal, gate.progress - rate * dt)
			gate.model:PivotTo(gate.closed:Lerp(gate.open, gate.progress))
		end
	end
end

-- Spinners --------------------------------------------------------------------------
local function nearestPlayerDistance(position)
	local best = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local root = Util.aliveRoot(player)
		if root then
			best = math.min(best, (root.Position - position).Magnitude)
		end
	end
	return best
end

local function tickSpinners(dt)
	local t = now()
	for _, spinner in ipairs(refs.spinners) do
		local hub = spinner.pivot.Position
		-- Only spin what someone could see or touch.
		if nearestPlayerDistance(hub) < 900 then
			spinner.angle += spinner.speed * dt
			local frame = spinner.pivot * CFrame.Angles(0, 0, spinner.angle)
			spinner.model:PivotTo(frame)
			if spinner.dangerous then
				for _, player in ipairs(Players:GetPlayers()) do
					local root, humanoid = Util.aliveRoot(player)
					if
						root
						and (root.Position - hub).Magnitude < spinner.radius + 4
						and t - (lastBladeHit[player] or 0) > 1.2
					then
						for i = 0, 3 do
							local blade = frame * CFrame.Angles(0, 0, i * math.pi / 2)
							local from = blade.Position
							local to = (blade * CFrame.new(0, spinner.radius, 0)).Position
							local along = to - from
							local alpha = math.clamp((root.Position - from):Dot(along) / along:Dot(along), 0, 1)
							local closest = from + along * alpha
							if (root.Position - closest).Magnitude < 3.2 and Impact.open(player) then
								lastBladeHit[player] = t
								Impact.damage(humanoid, Config.WINDMILL_DAMAGE)
								local away = root.Position - closest
								Util.knockback(
									root,
									(away.Magnitude > 0.1 and away.Unit or Vector3.yAxis) * 62 + Vector3.new(0, 30, 0),
									0.22
								)
								Loot.knockLoose(player, closest, "boulder", nil)
								Net.broadcast("Blast", { position = closest, radius = 5 })
								break
							end
						end
					end
				end
			end
		end
	end
end

-- Lava ------------------------------------------------------------------------------
local function tickLava()
	local t = now()
	if t < nextLava then
		return
	end
	nextLava = t + 0.3
	for _, zone in ipairs(refs.lavaZones) do
		for _, player in ipairs(Players:GetPlayers()) do
			local root, humanoid = Util.aliveRoot(player)
			if root and not Gear.fireproof(player) then
				local local_ = zone.part.CFrame:PointToObjectSpace(root.Position)
				local half = zone.part.Size / 2
				if
					math.abs(local_.X) < half.X
					and math.abs(local_.Y) < half.Y
					and math.abs(local_.Z) < half.Z
					and Impact.open(player)
				then
					Impact.damage(humanoid, zone.damage)
					Util.knockback(root, Vector3.new(0, 52, 0), 0.2)
					Loot.knockLoose(player, root.Position, "lava", nil)
					Net.send(player, "Burn", {})
				end
			end
		end
	end
end

-- Beacons --------------------------------------------------------------------------
function Mechanisms.light(beacon, player)
	local t = now()
	if t < (beacon.readyAt or 0) then
		Net.toast(player, "The beacon is still smouldering - give it a minute")
		return
	end
	beacon.readyAt = t + Config.BEACON_COOLDOWN
	beacon.fire.Enabled = true
	beacon.light.Brightness = 3
	beacon.prompt.Enabled = false
	Net.broadcast("Beacon", { position = beacon.position })
	Mechanisms.BeaconLit:Fire(beacon, player)
	task.delay(Config.BEACON_BURN, function()
		if beacon.fire.Parent then
			beacon.fire.Enabled = false
			beacon.light.Brightness = 0
		end
	end)
	task.delay(Config.BEACON_COOLDOWN, function()
		if beacon.prompt.Parent then
			beacon.prompt.Enabled = true
		end
	end)
end

function Mechanisms.build(worldRefs)
	refs = worldRefs
	for _, beacon in ipairs(refs.beacons or {}) do
		beacon.prompt.Triggered:Connect(function(player)
			Mechanisms.light(beacon, player)
		end)
	end
	for _, lever in ipairs(refs.levers) do
		lever.prompt.Triggered:Connect(function(player)
			Mechanisms.pull(lever, player)
		end)
	end
	for _, gate in ipairs(refs.gates) do
		gate.progress = 0
		gate.target = 0
	end
end

function Mechanisms.tick(dt)
	tickGates(dt)
	tickSpinners(dt)
	tickLava()
end

function Mechanisms.reset()
	for _, gate in ipairs(refs.gates) do
		gate.progress = gate.startOpen and 1 or 0
		gate.target = gate.progress
		gate.closeAt = nil
		gate.lockedUntil = nil
		gate.model:PivotTo(gate.closed:Lerp(gate.open, gate.progress))
	end
	for _, spinner in ipairs(refs.spinners) do
		spinner.speed = spinner.baseSpeed or spinner.speed
	end
	for _, beacon in ipairs(refs.beacons or {}) do
		beacon.readyAt = 0
		beacon.fire.Enabled = false
		beacon.light.Brightness = 0
		beacon.prompt.Enabled = true
	end
end

function Mechanisms.forget(player)
	lastBladeHit[player] = nil
end

return Mechanisms

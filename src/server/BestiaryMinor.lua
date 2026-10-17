-- The rest of the inhabitants (V5): the far islands' and the small islands'. Same rules as
-- Bestiary.lua: one idea each, learnable, and local to its island.
--
--   EMBER        Cinderlings     they run to where a carrier is GOING and set fire to it. They
--                                never touch you; they cut you off. Stand in the sea and one
--                                that follows goes out. A blast puts one out too.
--   FROST        the Chill       a drifting cold. Inside it stamina leaks away and barely comes
--                                back: it attacks the thing you climb with. A keg scatters it.
--   LEVIATHAN    the Sleeper     an eye under the water off the east dock that wakes to the
--                                noise of fast boats. Creep past, or go so fast it misses.
--   SKULL ROCK   the Captain     the skull's eyes are lit while his shade is awake and dark
--                                while it dozes. Take the Chalice while they are dark and the
--                                ghost fleet is late.
--   MAELSTROM    the Maw         a fin circling the whirlpool. It shoves boats along its path:
--                                a hazard, or a slingshot.
--   CORAL        the Clam        the pearl's shell opens and shuts. It pinches.
--   GOBLIN COVE  Gobbo           the dockhand. Hands out kegs and shouts when trouble is near home.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Gear = require(script.Parent.Gear)
local Impact = require(script.Parent.Impact)
local Leviathan = require(script.Parent.Leviathan)
local Loot = require(script.Parent.Loot)
local Boats = require(script.Parent.Boats)
local Movement = require(script.Parent.Movement)
local Kegs = require(script.Parent.Kegs)
local Blast = require(script.Parent.Blast)
local Threats = require(script.Parent.Threats)
local Navy = require(script.Parent.Navy)
local Storms = require(script.Parent.Storms)
local C = require(script.Parent.Creatures)

local K = Config.CREATURES
local M = Enum.Material
local rad = math.rad

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v, fallback)
	local f = flat(v)
	return f.Magnitude > 0.05 and f.Unit or (fallback or Vector3.zAxis)
end

-- CINDERLINGS (Ember Isle) -----------------------------------------------------------------
local patches = {} -- Fire on the ground: { part, position, diesAt }. Shared by all three.
local nextBurnAt = 0

local function tickPatches(t)
	for i = #patches, 1, -1 do
		if t >= patches[i].diesAt then
			patches[i].part:Destroy()
			table.remove(patches, i)
		end
	end
	if t < nextBurnAt or #patches == 0 then
		return
	end
	nextBurnAt = t + 0.5
	local k = K.Cinder
	local burned = {}
	for _, patch in ipairs(patches) do
		for _, entry in ipairs(C.players(patch.position, k.radius)) do
			if
				not burned[entry.player]
				and not Gear.fireproof(entry.player)
				and math.abs(entry.root.Position.Y - patch.position.Y) < 7
				and Impact.open(entry.player)
			then
				burned[entry.player] = true
				Impact.damage(entry.humanoid, k.burn)
				Net.send(entry.player, "Burn", {})
			end
		end
	end
end

local function cinderling(index, dx, dz)
	local k = K.Cinder
	local center = C.at("Ember")
	local HOT = Color3.fromRGB(255, 120, 40)
	return C.add({
		name = "Cinderling" .. index,
		home = C.at("Ember", dx, 0, dz),
		wake = k.island + 120,
		size = 3,
		lift = CFrame.new(0, 1.6, 0),

		build = function(self)
			self.home = v3(self.home.X, C.floor(self.home.X, self.home.Z), self.home.Z)
			self.model, self.root = C.body("Cinderling", {
				{ "Body", v3(3, 3, 3), nil, HOT, M.Neon, Enum.PartType.Ball },
				{ "Crown", v3(1.2, 2.2, 1.2), CFrame.new(0, 2, 0), Color3.fromRGB(255, 220, 90), M.Neon },
				{ "EyeL", v3(0.5, 0.7, 0.3), CFrame.new(-0.6, 0.3, -1.4), Color3.fromRGB(40, 20, 10), M.SmoothPlastic },
				{ "EyeR", v3(0.5, 0.7, 0.3), CFrame.new(0.6, 0.3, -1.4), Color3.fromRGB(40, 20, 10), M.SmoothPlastic },
				-- V10: a crust of cooled rock, flickering side flames, a wicked grin and two stubby feet.
				{
					"CrustA",
					v3(1.3, 1.3, 1.3),
					CFrame.new(1.1, -0.6, 0.9) * CFrame.Angles(0.4, 0.6, 0),
					Color3.fromRGB(56, 44, 44),
					M.Slate,
				},
				{
					"CrustB",
					v3(1.1, 1.1, 1.1),
					CFrame.new(-1.0, 0.8, 1.0) * CFrame.Angles(0.7, 0.2, 0.3),
					Color3.fromRGB(56, 44, 44),
					M.Slate,
				},
				{
					"CrustC",
					v3(1, 1, 1),
					CFrame.new(-0.7, -1.1, -0.9) * CFrame.Angles(0.2, 0.9, 0.5),
					Color3.fromRGB(56, 44, 44),
					M.Slate,
				},
				{
					"FlameL",
					v3(0.8, 1.7, 0.8),
					CFrame.new(-0.9, 1.6, 0.3) * CFrame.Angles(0, 0, rad(25)),
					Color3.fromRGB(255, 176, 60),
					M.Neon,
				},
				{
					"FlameR",
					v3(0.8, 1.5, 0.8),
					CFrame.new(0.9, 1.5, 0.3) * CFrame.Angles(0, 0, rad(-25)),
					Color3.fromRGB(255, 176, 60),
					M.Neon,
				},
				{ "Grin", v3(1.3, 0.3, 0.2), CFrame.new(0, -0.5, -1.42), Color3.fromRGB(40, 20, 10), M.SmoothPlastic },
				{
					"FootL",
					v3(0.9, 0.9, 0.9),
					CFrame.new(-0.7, -1.5, -0.2),
					Color3.fromRGB(56, 44, 44),
					M.Slate,
					Enum.PartType.Ball,
				},
				{
					"FootR",
					v3(0.9, 0.9, 0.9),
					CFrame.new(0.7, -1.5, -0.2),
					Color3.fromRGB(56, 44, 44),
					M.Slate,
					Enum.PartType.Ball,
				},
			})
			local light = Instance.new("PointLight")
			light.Color = HOT
			light.Range = 18
			light.Brightness = 1.5
			light.Parent = self.root
		end,

		reset = function(self)
			self.position, self.yaw = self.home, 0
			self.outUntil, self.nextPatchAt = 0, 0
			C.pose(self)
			if index == 1 then
				for _, patch in ipairs(patches) do
					patch.part:Destroy()
				end
				table.clear(patches)
			end
		end,

		quench = function(self, t)
			C.fx("steam", self.position)
			self.outUntil = t + k.respawn
			self.position = self.home
			self.root.CFrame = CFrame.new(0, -200, 0)
		end,

		onBlast = function(self)
			if C.now() >= self.outUntil then
				self:quench(C.now())
			end
		end,

		tick = function(self, dt, t)
			if index == 1 then
				tickPatches(t)
			end
			if t < self.outUntil then
				self.busy = #patches > 0
				return
			end
			local target = C.nearest(C.carriers(center, k.island), self.position)
			if not target then
				self.busy = #patches > 0 and index == 1
				if C.walk(self, self.home, k.speed * 0.5, dt, 2) then
					self.busy = true
				end
				C.pose(self)
				return
			end
			self.busy = true
			local to = target.root.Position
			-- A thief standing in the sea: it jumps in after them, and that is the end of it.
			local seabed = C.floor(to.X, to.Z, to.Y + 4)
			if seabed < C.WATER_Y and to.Y < 4 and Util.flatDistance(to, self.position) <= k.quench then
				self:quench(t)
				return
			end
			-- Run for where they are going, not where they are.
			local velocity = flat(target.root.AssemblyLinearVelocity)
			local ahead = to
				+ (velocity.Magnitude > 4 and velocity.Unit or Vector3.zero)
					* math.clamp(velocity.Magnitude * k.ahead, 22, 62)
			if Util.flatDistance(to, self.position) < 11 then
				ahead = self.position + flatUnit(self.position - to) * 14 -- Too close: it keeps its distance.
			end
			C.walk(self, ahead, k.speed, dt, 2, function(_, _, y)
				return y > 0.6 -- Not into the water by itself.
			end)
			C.pose(self, CFrame.new(0, math.abs(math.sin(t * 9)) * 1.2, 0))
			if t >= self.nextPatchAt and #patches < 40 then
				self.nextPatchAt = t + k.patch
				local at = v3(self.position.X, self.position.Y + 0.3, self.position.Z)
				local part = Util.part(
					"FirePatch",
					v3(0.5, k.radius * 2, k.radius * 2),
					CFrame.new(at) * CFrame.Angles(0, 0, rad(90)),
					HOT,
					M.Neon,
					C.refs().folders.fx
				)
				part.Shape = Enum.PartType.Cylinder
				part.Transparency = 0.3
				part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
				local fire = Instance.new("Fire")
				fire.Size = 9
				fire.Heat = 12
				fire.Parent = part
				table.insert(patches, { part = part, position = at, diesAt = t + k.life })
			end
		end,
	})
end

-- THE CHILL (Frost Spire) ------------------------------------------------------------------
local function chill()
	local k = K.Chill
	local center = C.at("Frost")
	local ICE = Color3.fromRGB(190, 235, 255)
	return C.add({
		name = "Chill",
		home = center,
		wake = k.leash + 80,
		size = 10,

		build = function(self)
			-- It rests above the Aurora Gem.
			local spot = C.refs().lootSpots.Aurora
			self.home = spot and (spot.Position + v3(0, 26, 0)) or (center + v3(0, 180, 0))
			self.model, self.root = C.body("Chill", {
				{ "Core", v3(9, 9, 9), nil, ICE, M.Neon, Enum.PartType.Ball, 0.55 },
				{ "Veil", v3(22, 22, 22), CFrame.new(), ICE, M.Glass, Enum.PartType.Ball, 0.86 },
				{ "Wisp1", v3(4, 4, 4), CFrame.new(7, 3, 2), ICE, M.Neon, Enum.PartType.Ball, 0.5 },
				{ "Wisp2", v3(3, 3, 3), CFrame.new(-6, -2, 5), ICE, M.Neon, Enum.PartType.Ball, 0.5 },
				{ "Wisp3", v3(3.5, 3.5, 3.5), CFrame.new(2, 5, -7), ICE, M.Neon, Enum.PartType.Ball, 0.5 },
				-- V10: a face in the frost (two dark eyes and a cold little mouth) and a crown of icicles.
				{
					"ChillEyeL",
					v3(1.6, 0.8, 0.3),
					CFrame.new(-1.7, 1, -4.35),
					Color3.fromRGB(24, 50, 96),
					M.SmoothPlastic,
				},
				{
					"ChillEyeR",
					v3(1.6, 0.8, 0.3),
					CFrame.new(1.7, 1, -4.35),
					Color3.fromRGB(24, 50, 96),
					M.SmoothPlastic,
				},
				{
					"ChillMouth",
					v3(1.4, 0.5, 0.3),
					CFrame.new(0, -1.6, -4.4),
					Color3.fromRGB(24, 50, 96),
					M.SmoothPlastic,
				},
				{ "Icicle1", v3(1, 4, 1), CFrame.new(0, 5.6, 0), ICE, M.Glass, nil, 0.2 },
				{
					"Icicle2",
					v3(0.9, 3.4, 0.9),
					CFrame.new(2.4, 4.8, 0) * CFrame.Angles(0, 0, rad(-25)),
					ICE,
					M.Glass,
					nil,
					0.2,
				},
				{
					"Icicle3",
					v3(0.9, 3.4, 0.9),
					CFrame.new(-2.4, 4.8, 0) * CFrame.Angles(0, 0, rad(25)),
					ICE,
					M.Glass,
					nil,
					0.2,
				},
				{
					"Icicle4",
					v3(0.8, 3, 0.8),
					CFrame.new(0, 4.6, 2.4) * CFrame.Angles(rad(25), 0, 0),
					ICE,
					M.Glass,
					nil,
					0.2,
				},
				{
					"Icicle5",
					v3(0.8, 3, 0.8),
					CFrame.new(0, 4.6, -2.4) * CFrame.Angles(rad(-25), 0, 0),
					ICE,
					M.Glass,
					nil,
					0.2,
				},
			}, nil, Config.GUARDIAN_SCALE.Chill) -- V9: bigger
		end,

		reset = function(self)
			self.position, self.yaw = self.home, 0
			self.goneUntil = 0
			self.told = {}
			C.pose(self)
		end,

		onBlast = function(self)
			local t = C.now()
			if t >= self.goneUntil then
				self.goneUntil = t + k.scatter
				C.fx("steam", self.position)
				self.position = self.home
				self.root.CFrame = CFrame.new(0, -200, 0)
			end
		end,

		tick = function(self, dt, t)
			if t < self.goneUntil then
				self.busy = true
				return
			end
			-- Whoever is on the mountain: a carrier first.
			local climbers = {}
			for _, entry in ipairs(C.players(center, k.leash)) do
				if entry.root.Position.Y > k.wakeHeight then
					table.insert(climbers, entry)
				end
			end
			local carriers = {}
			for _, entry in ipairs(climbers) do
				if entry.item then
					table.insert(carriers, entry)
				end
			end
			local target = C.nearest(#carriers > 0 and carriers or climbers, self.position)
			local goal = target and (target.root.Position + v3(0, 4, 0)) or self.home
			local to = goal - self.position
			if to.Magnitude > 1 then
				local speed = target and (target.item and k.carrierSpeed or k.speed) or k.speed
				self.position += to.Unit * math.min(speed * dt, to.Magnitude)
			end
			self.busy = target ~= nil or to.Magnitude > 2
			self.yaw = t * 0.6
			C.pose(self, CFrame.new(0, math.sin(t * 1.3) * 1.5, 0))
			for _, entry in ipairs(climbers) do
				if (entry.root.Position - self.position).Magnitude <= k.aura then
					Movement.chill(entry.player, 0.6)
					if t - (self.told[entry.player] or 0) > 10 then
						self.told[entry.player] = t
						Net.toast(
							entry.player,
							"THE CHILL HAS YOU - stamina is draining. Get clear of it, or blast it."
						)
						C.fx("chill", entry.root.Position)
					end
				end
			end
		end,
	})
end

-- THE SLEEPER (Leviathan's Rest) -----------------------------------------------------------
local function sleeper()
	local k = K.Sleeper
	local DEEP = Color3.fromRGB(150, 90, 220)
	local creature
	Blast.Hit:Connect(function(position, radius)
		local head = Leviathan.headPosition()
		if creature and head and (head - position).Magnitude < radius + 45 then
			Leviathan.recoil()
			creature.flinched = true
			creature.restUntil += k.rest -- twice the usual rest
		end
	end)
	creature = C.add({
		name = "Sleeper",
		home = C.at("Bone", 330, -2.4, 70),
		wake = k.range + 160,

		build = function(self)
			self.model, self.root = C.body("Sleeper", {
				{ "Eye", v3(26, 26, 26), nil, Color3.fromRGB(30, 22, 44), M.SmoothPlastic, Enum.PartType.Ball },
				{
					"Iris",
					v3(1.2, 12, 12),
					CFrame.new(0, 11.4, 0) * CFrame.Angles(0, 0, rad(90)),
					DEEP,
					M.Neon,
					Enum.PartType.Cylinder,
				},
			})
			self.iris = self.model.Iris
			Leviathan.build(C.refs().folders.threats, self.home)
		end,

		show = function(self)
			-- The eye opens as it wakes: the iris widens and brightens.
			local open = self.awareness
			self.iris.Transparency = 0.75 - open * 0.75
			self.root.CFrame = CFrame.new(self.home + v3(0, -11 + open * 3, 0))
		end,

		reset = function(self)
			self.awareness, self.restUntil, self.warnedAt = 0, 0, 0
			self.flinched = false
			Leviathan.reset()
			self:show()
		end,

		tick = function(self, dt, t)
			Leviathan.update(dt, self.awareness)
			-- The loudest boat with someone at the wheel. Empty boats and goblins on foot make no noise.
			local loudest, loudness, helmsman = nil, 0, nil
			for _, entry in ipairs(C.players(self.home, k.range)) do
				local boat = Boats.drivenBy(entry.player)
				if boat and boat.state == "float" then
					local speed = flat(boat.hull.AssemblyLinearVelocity).Magnitude
					local noise = math.clamp((speed - k.quiet) / 80, 0, 1)
					if noise > loudness then
						loudest, loudness, helmsman = boat, noise, entry.player
					end
				end
			end
			if t >= self.restUntil then
				self.awareness = math.clamp(self.awareness + (loudness * k.rise - k.fall) * dt, 0, 1)
			end
			self.busy = self.awareness > 0 or Leviathan.hunting()
			self:show()
			if loudest and self.awareness > 0.45 and t - self.warnedAt > 9 then
				self.warnedAt = t
				C.fx("eye", self.home, { open = self.awareness })
				Net.toast(helmsman, "SOMETHING BELOW IS LISTENING. Slow down... or go faster.")
			end
			if loudest and self.awareness >= 1 then
				-- V8: it does not strike from its circle any more. It comes after the boat (Leviathan.lua).
				self.awareness, self.restUntil = 0.3, t + k.rest
				self.flinched = false
				Leviathan.hunt(helmsman)
			end
		end,
	})
	return creature
end

-- THE CAPTAIN'S SHADE (Skull Rock) -----------------------------------------------------------
local function shade()
	local k = K.Shade
	local center = C.at("Skull")
	local LIT, DARK = Color3.fromRGB(110, 255, 170), Color3.fromRGB(46, 60, 54)
	return C.add({
		name = "CaptainsShade",
		home = center,
		wake = 900, -- The eyes are a signal to read from the sea, so they keep time from far off.

		build = function(self)
			self.eyes = {}
			for _, part in ipairs(C.refs().folders.decor:GetChildren()) do
				if part.Name == "SkullEye" and Util.flatDistance(part.Position, center) < 140 then
					table.insert(self.eyes, part)
				end
			end
			-- When the Chalice is taken while he dozes, the ghost fleet is late.
			local rise = Threats.handlers.GhostFleet
			Threats.handlers.GhostFleet = function(item, player)
				if not self.asleep then
					rise(item, player)
					return
				end
				Net.message(
					string.format("THE CAPTAIN WAS ASLEEP: %d SECONDS BEFORE THE FLEET RISES", k.headStart),
					4,
					LIT
				)
				local generation = C.generation
				task.delay(k.headStart, function()
					if generation == C.generation and player.Parent then
						rise(item, player)
					end
				end)
			end
		end,

		setAsleep = function(self, asleep)
			self.asleep = asleep
			for _, eye in ipairs(self.eyes) do
				eye.Color = asleep and DARK or LIT
				eye.Material = asleep and M.Slate or M.Neon
				local light = eye:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = not asleep
				end
			end
		end,

		reset = function(self)
			self:setAsleep(false)
		end,

		-- He keeps time by the clock, not by who is watching, so the rhythm is the same every visit.
		tick = function(self, _, t)
			local asleep = t % (k.awake + k.asleep) >= k.awake
			if asleep ~= self.asleep then
				self:setAsleep(asleep)
			end
		end,
	})
end

-- THE MAW (Maelstrom Rock) -------------------------------------------------------------------
local function maw()
	local k = K.Maw
	local center = C.at("Maelstrom")
	return C.add({
		name = "Maw",
		home = center,
		wake = 420,

		build = function(self)
			self.model, self.root = C.body("Maw", {
				{ "Back", v3(8, 5, 26), nil, Color3.fromRGB(52, 66, 84), M.SmoothPlastic },
				{
					"Fin",
					v3(1.4, 11, 9),
					CFrame.new(0, 6.5, 2) * CFrame.Angles(rad(-24), 0, 0),
					Color3.fromRGB(40, 52, 68),
					M.SmoothPlastic,
				},
				{
					"Tail",
					v3(1.2, 6, 5),
					CFrame.new(0, 3, 14) * CFrame.Angles(rad(-30), 0, 0),
					Color3.fromRGB(40, 52, 68),
					M.SmoothPlastic,
				},
				-- V10: a blunt snout with a row of teeth, yellow eyes, side fins and a pale belly line, so the thing
				-- circling the whirlpool reads as a huge fish, not a floating plank.
				{ "Snout", v3(7, 4, 6), CFrame.new(0, 0.8, -15), Color3.fromRGB(46, 60, 78), M.SmoothPlastic },
				{
					"Teeth",
					v3(6.4, 1.1, 0.8),
					CFrame.new(0, -0.3, -18) * CFrame.Angles(rad(180), 0, 0),
					Color3.fromRGB(244, 240, 226),
					M.SmoothPlastic,
					Enum.PartType.Wedge,
				},
				{
					"MawEyeL",
					v3(1, 1, 1),
					CFrame.new(-3.6, 2.2, -13),
					Color3.fromRGB(255, 214, 60),
					M.Neon,
					Enum.PartType.Ball,
				},
				{
					"MawEyeR",
					v3(1, 1, 1),
					CFrame.new(3.6, 2.2, -13),
					Color3.fromRGB(255, 214, 60),
					M.Neon,
					Enum.PartType.Ball,
				},
				{
					"SideFinL",
					v3(6, 0.6, 3.4),
					CFrame.new(-6, 0, -4) * CFrame.Angles(0, rad(-20), rad(-15)),
					Color3.fromRGB(40, 52, 68),
					M.SmoothPlastic,
				},
				{
					"SideFinR",
					v3(6, 0.6, 3.4),
					CFrame.new(6, 0, -4) * CFrame.Angles(0, rad(20), rad(15)),
					Color3.fromRGB(40, 52, 68),
					M.SmoothPlastic,
				},
				{ "Belly", v3(8.4, 1, 24), CFrame.new(0, -2.2, 0), Color3.fromRGB(196, 206, 214), M.SmoothPlastic },
			}, nil, Config.GUARDIAN_SCALE.Maw) -- V9: bigger
		end,

		reset = function(self)
			self.angle = 0
			self.shoved = {}
		end,

		tick = function(self, dt, t)
			self.angle += k.speed / k.radius * dt
			local out = v3(math.cos(self.angle), 0, math.sin(self.angle))
			local way = v3(-out.Z, 0, out.X) -- The way it swims: with the whirlpool.
			self.position = center + out * k.radius + v3(0, -2.6, 0)
			self.root.CFrame = CFrame.lookAt(self.position, self.position + way)
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and t - (self.shoved[boat] or 0) > 2.5 then
					if Util.flatDistance(boat.hull.Position, self.position) <= k.reach then
						self.shoved[boat] = t
						Boats.shove(boat, way * k.push + out * 8, 0)
						C.fx("splash", boat.hull.Position)
					end
				end
			end
			for _, entry in ipairs(C.players(self.position, 11)) do
				if
					not entry.humanoid.SeatPart
					and entry.root.Position.Y < 5
					and t - (self.shoved[entry.player] or 0) > 2.5
				then
					self.shoved[entry.player] = t
					C.strike(entry, self.position, { push = way * 34 + v3(0, 42, 0) })
					C.fx("splash", entry.root.Position)
				end
			end
		end,
	})
end

-- THE CLAM (Coral Atoll) ---------------------------------------------------------------------
local function clam()
	local k = K.Clam
	local center = C.at("Coral")
	return C.add({
		name = "Clam",
		home = center,
		wake = 320,

		build = function(self)
			for _, part in ipairs(C.refs().folders.decor:GetChildren()) do
				if part.Name == "ClamLid" and Util.flatDistance(part.Position, center) < 30 then
					self.lid = part
				end
			end
			if self.lid then
				self.open = self.lid.CFrame
				self.shut = CFrame.new(center.X, 6.4, center.Z)
			end
		end,

		reset = function(self)
			self.phase, self.flipAt, self.amount = "open", C.now() + k.open, 0
			if self.lid then
				self.lid.CFrame = self.open
			end
		end,

		tick = function(self, dt, t)
			if not self.lid then
				return
			end
			if t >= self.flipAt then
				if self.phase == "open" then
					self.phase, self.flipAt = "shut", t + k.shut
					-- SNAP. Whoever has a hand in it gets thrown.
					local middle = v3(center.X, 5, center.Z)
					for _, entry in ipairs(C.players(middle, k.reach)) do
						if math.abs(entry.root.Position.Y - 6) < 9 then
							C.strike(entry, middle, {
								damage = k.damage,
								push = flatUnit(entry.root.Position - middle) * 30 + v3(0, k.toss, 0),
								text = "PINCHED! The clam opens and shuts: time it.",
							})
						end
					end
					C.fx("thud", middle)
				else
					self.phase, self.flipAt = "open", t + k.open
				end
			end
			-- The lid swings; the pearl can only be taken while it is open.
			local goal = self.phase == "shut" and 1 or 0
			self.amount += math.clamp(goal - self.amount, -dt * 5, dt * 5)
			self.lid.CFrame = self.open:Lerp(self.shut, self.amount)
			local pearl = Loot.byId.Pearl
			if pearl and pearl.state == "spot" then
				pearl.prompt.Enabled = self.phase == "open"
			end
		end,
	})
end

-- GOBBO (Goblin Cove) ------------------------------------------------------------------------
local function gobbo()
	local k = K.Gobbo
	local GREEN = Color3.fromRGB(110, 190, 90)
	return C.add({
		name = "Gobbo",
		home = C.at("Home", -18, 0, -128),
		wake = 500,
		lift = CFrame.new(0, 2.2, 0),

		build = function(self)
			self.home = v3(self.home.X, C.floor(self.home.X, self.home.Z), self.home.Z)
			self.model, self.root = C.body("Gobbo", {
				{ "Body", v3(2.6, 2.8, 1.8), nil, Color3.fromRGB(120, 84, 50), M.Fabric },
				{ "Head", v3(2.4, 2.2, 2.2), CFrame.new(0, 2.5, 0), GREEN, M.SmoothPlastic },
				{
					"EarL",
					v3(1.8, 0.7, 0.4),
					CFrame.new(-2, 2.8, 0) * CFrame.Angles(0, 0, rad(20)),
					GREEN,
					M.SmoothPlastic,
				},
				{
					"EarR",
					v3(1.8, 0.7, 0.4),
					CFrame.new(2, 2.8, 0) * CFrame.Angles(0, 0, rad(-20)),
					GREEN,
					M.SmoothPlastic,
				},
				{ "Hat", v3(2.8, 0.6, 2.8), CFrame.new(0, 3.9, 0), Color3.fromRGB(190, 40, 46), M.Fabric },
				{ "Legs", v3(2, 1.6, 1.2), CFrame.new(0, -1.6, 0), Color3.fromRGB(60, 50, 44), M.Fabric },
				-- V10: Gobbo looks like the goblins he cheers on: a big nose, eyes, a belt and a gold buckle.
				{ "Nose", v3(0.9, 0.9, 0.9), CFrame.new(0, 2.3, -1.25), GREEN, M.SmoothPlastic, Enum.PartType.Ball },
				{
					"GobboEyeL",
					v3(0.5, 0.5, 0.5),
					CFrame.new(-0.55, 2.9, -1.05),
					Color3.fromRGB(250, 246, 220),
					M.SmoothPlastic,
					Enum.PartType.Ball,
				},
				{
					"GobboEyeR",
					v3(0.5, 0.5, 0.5),
					CFrame.new(0.55, 2.9, -1.05),
					Color3.fromRGB(250, 246, 220),
					M.SmoothPlastic,
					Enum.PartType.Ball,
				},
				{ "Belt", v3(2.7, 0.4, 1.9), CFrame.new(0, -0.6, 0), Color3.fromRGB(60, 40, 30), M.Fabric },
				{ "Buckle", v3(0.6, 0.5, 0.2), CFrame.new(0, -0.6, -0.98), Color3.fromRGB(255, 200, 60), M.Metal },
			})
			self.position, self.yaw = self.home, math.pi
			C.pose(self)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "GobboPrompt"
			prompt.ObjectText = "Gobbo the dockhand"
			prompt.ActionText = "Ask for a powder keg"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = self.root
			self.asked = {}
			prompt.Triggered:Connect(function(player)
				local t = C.now()
				if t - (self.asked[player] or -math.huge) < k.kegEvery then
					Net.toast(player, 'Gobbo: "One at a time! Come back in a bit."')
					return
				end
				self.asked[player] = t
				Kegs.give(player)
			end)
			local sign = Instance.new("BillboardGui")
			sign.Size = UDim2.fromOffset(150, 26)
			sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
			sign.MaxDistance = 120
			sign.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.Text = "GOBBO"
			label.TextColor3 = GREEN
			label.TextStrokeTransparency = 0.2
			label.Parent = sign
			sign.Parent = self.root
		end,

		reset = function(self)
			self.nextWarnAt = 0
			self.asked = {}
		end,

		-- He keeps watch on the water near home and shouts about what he sees.
		tick = function(self, _, t)
			if t < self.nextWarnAt then
				return
			end
			self.nextWarnAt = t + 3
			local hoard = C.refs().hoard.position
			for _, ship in ipairs(Navy.ships) do
				if not ship.ghost and Util.flatDistance(ship.boat.hull.Position, hoard) <= k.navyRange then
					local offset = ship.boat.hull.Position - hoard
					Net.feed(
						'Gobbo: "PATROL SHIP to the ' .. Storms.compassName(offset.X, offset.Z) .. ' of the cove!"',
						GREEN
					)
					self.nextWarnAt = t + k.warnEvery
					return
				end
			end
			for _, cell in ipairs(Storms.cells) do
				if
					cell.kind == "storm"
					and Util.flatDistance(Vector3.new(cell.x, 0, cell.z), hoard) <= k.stormRange
				then
					Net.feed(
						'Gobbo: "Weather coming in from the '
							.. Storms.compassName(cell.x - hoard.X, cell.z - hoard.Z)
							.. '. Mind the lightning!"',
						GREEN
					)
					self.nextWarnAt = t + k.warnEvery
					return
				end
			end
		end,
	})
end

-- The roster --------------------------------------------------------------------------------
cinderling(1, 0, 150)
cinderling(2, -62, 122)
cinderling(3, 62, 120)
chill()
sleeper()
shade()
maw()
clam()
gobbo()

return true

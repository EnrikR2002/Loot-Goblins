-- The inhabitants of the big islands (V5). Each is one idea a player can learn and then use.
-- Creatures.lua is the shared machinery; the numbers are in Config.CREATURES.
--
--   CROSSROADS   the Watchers    statues that only move while nobody is facing them. They knock
--                                treasure out of a thief's hands and carry it back to its place.
--   CRYSTAL      the Echo        a crystal double that retraces a carrier's exact path a few
--                                seconds behind. Never double back; a rival chasing you meets it.
--   SHOALS       Old Clacker     a crab under the sand. Sand and shallows are its ground: the
--                                wreck, the decks and deep water are not.
--   WINDMILL     Bramble         a ram that charges in a straight line and tosses what it hits.
--                                Sidestep it, bait it into a cliff, or let it throw you somewhere.
--   TIDE VAULT   the Warden      an eel circling the shallows. After the pearl is taken it hunts
--                                whoever is in the water: stay on the stones.
--   TANGLE       the Imps        they leap from the canopy, snatch the treasure and run to a nest.
--                                Get off the marked spot, or go and take it back.
--   FORT         the Garrison    marines with lanterns. Seen: a whistle, a charge, and over the
--                                wall you go (the treasure stays).
--
-- None of them chases anyone off its island. Most do no damage at all: what they threaten is
-- the treasure, the route, or your footing. A blast (a keg) stops every one of them for a while.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Boats = require(script.Parent.Boats)
local C = require(script.Parent.Creatures)

local K = Config.CREATURES
local M = Enum.Material
local rad = math.rad

local STONE = Color3.fromRGB(150, 150, 142)
local DARK = Color3.fromRGB(70, 66, 72)

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

-- THE WATCHERS (Crossroads Ruins) --------------------------------------------------------
local function watcher(index, dx, dz)
	local k = K.Watcher
	local S = Config.GUARDIAN_SCALE.Watcher -- V9: bigger
	local center = C.at("Cross")
	return C.add({
		name = "Watcher" .. index,
		home = C.at("Cross", dx, 0, dz),
		wake = 430,
		size = 5 * S,
		lift = CFrame.new(0, 0.7 * S, 0),

		build = function(self)
			self.home = v3(self.home.X, C.floor(self.home.X, self.home.Z), self.home.Z)
			self.homeYaw = math.atan2(self.home.X - center.X, self.home.Z - center.Z) -- facing outward
			self.model, self.root = C.body("Watcher", {
				{ "Base", v3(4.4, 1.4, 4.4), nil, DARK, M.Slate },
				{ "Body", v3(3, 7, 2.4), CFrame.new(0, 4.2, 0), STONE, M.Cobblestone },
				{ "Head", v3(2.6, 2.6, 2.6), CFrame.new(0, 9, 0), STONE, M.Slate },
				{ "EyeL", v3(0.6, 0.5, 0.3), CFrame.new(-0.6, 9.2, -1.36), Color3.fromRGB(60, 20, 20), M.Neon },
				{ "EyeR", v3(0.6, 0.5, 0.3), CFrame.new(0.6, 9.2, -1.36), Color3.fromRGB(60, 20, 20), M.Neon },
				{
					"ArmL",
					v3(1, 4.4, 1),
					CFrame.new(-2.1, 5.8, -1.4) * CFrame.Angles(rad(-72), 0, 0),
					STONE,
					M.Cobblestone,
				},
				{
					"ArmR",
					v3(1, 4.4, 1),
					CFrame.new(2.1, 5.8, -1.4) * CFrame.Angles(rad(-72), 0, 0),
					STONE,
					M.Cobblestone,
				},
			}, nil, S)
			self.eyes = { self.model.EyeL, self.model.EyeR }
		end,

		-- Lit eyes mean it is free to move. That is the whole tell.
		setEyes = function(self, lit)
			if self.lit ~= lit then
				self.lit = lit
				for _, eye in ipairs(self.eyes) do
					eye.Color = lit and Color3.fromRGB(255, 60, 50) or Color3.fromRGB(60, 20, 20)
				end
			end
		end,

		watched = function(self)
			for _, entry in ipairs(C.players(self.position, k.sight)) do
				local to = flatUnit(self.position - entry.root.Position)
				if flatUnit(entry.root.CFrame.LookVector):Dot(to) > k.gaze then
					return true
				end
			end
			return false
		end,

		drop = function(self)
			if self.holding then
				Loot.letGo(self.holding, v3(0, 18, 0))
				self.holding = nil
			end
		end,

		reset = function(self)
			self:drop()
			self.position, self.yaw = self.home, self.homeYaw
			self.toppledUntil, self.restAt, self.nextCatchAt = 0, 0, 0
			self:setEyes(false)
			C.pose(self)
		end,

		onBlast = function(self)
			self:drop()
			self.toppledUntil = C.now() + k.topple
			self.busy = true
			self:setEyes(false)
			C.pose(self, CFrame.new(0, 1.4, 0) * CFrame.Angles(rad(-82), 0, 0))
			C.fx("thud", self.position)
		end,

		tick = function(self, step, t)
			if t < self.toppledUntil then
				return
			end
			-- Carrying something back: slow, and it does not care who is looking.
			local held = self.holding
			if held then
				if held.state ~= "loose" or not held.held then
					self.holding = nil -- Someone took it out of its hands.
				else
					local walking = C.walk(self, held.spot.Position, k.carrySpeed, step, 7)
					self:setEyes(true)
					C.pose(self)
					Loot.hold(held, self.root.CFrame * CFrame.new(0, 6 * S, -2.8 * S))
					if not walking then
						Loot.sendHome(held, "taken:The Watchers")
						self.holding = nil
						C.fx("stone", self.position)
					end
					self.busy = true
					return
				end
			end
			local watched = self:watched()
			self:setEyes(not watched)
			if watched then
				self.busy = true
				return
			end
			-- Treasure on the ground nearby: fetch it.
			for _, item in ipairs(C.looseLoot(self.position, 80)) do
				if not item.held and Util.flatDistance(item.core.Position, center) <= k.island then
					if not C.walk(self, item.core.Position, k.speed, step, 5) then
						if Loot.hold(item, self.root.CFrame * CFrame.new(0, 6 * S, -2.8 * S)) then
							self.holding = item
							C.fx("stone", self.position)
						end
					end
					C.pose(self)
					self.busy = true
					return
				end
			end
			local target = C.nearest(C.carriers(center, k.island), self.position)
			if target then
				self.restAt = t + k.restAfter
				self.busy = true
				local to = target.root.Position
				if Util.flatDistance(to, self.position) <= k.reach and math.abs(to.Y - self.position.Y) < 12 then
					if t >= self.nextCatchAt then
						self.nextCatchAt = t + 2
						C.strike(target, self.position, {
							push = flatUnit(to - self.position) * 22 + v3(0, 14, 0),
							reason = "watcher",
							text = "A WATCHER HAS YOU! It only moves when nobody is facing it.",
						})
						C.fx("stone", self.position)
					end
				else
					C.walk(self, to, k.speed, step, k.reach - 1.5)
				end
				C.pose(self)
			elseif t > self.restAt then
				-- Back to the plinth, still only while unwatched.
				if C.walk(self, self.home, k.speed * 0.6, step, 1) then
					self.busy = true
				else
					self.busy = false
					self.yaw = self.homeYaw
				end
				C.pose(self)
			end
		end,
	})
end

-- THE ECHO (Crystal Isle) -----------------------------------------------------------------
local function echo()
	local k = K.Echo
	local center = C.at("Crystal")
	local CRYSTAL = Color3.fromRGB(205, 120, 255)
	return C.add({
		name = "Echo",
		home = center,
		wake = k.island + 80,

		build = function(self)
			self.bodies = {}
			for i = 1, k.max do
				local model, root = C.body("Echo", {
					{ "Torso", v3(2.2, 2.4, 1.2), nil, CRYSTAL, M.Glass, nil, 0.25 },
					{ "Head", v3(1.5, 1.5, 1.5), CFrame.new(0, 2, 0), CRYSTAL, M.Neon, nil, 0.1 },
					{ "Legs", v3(2, 2.2, 1), CFrame.new(0, -2.3, 0), CRYSTAL, M.Glass, nil, 0.25 },
					{
						"Shard",
						v3(0.8, 3, 0.8),
						CFrame.new(0, 0.6, 1) * CFrame.Angles(rad(30), 0, rad(20)),
						CRYSTAL,
						M.Neon,
						nil,
						0.2,
					},
				})
				self.bodies[i] = { model = model, root = root, used = false }
			end
			self.echoes = {} -- player -> echo
		end,

		hide = function(_, body)
			body.root.CFrame = CFrame.new(0, -200, 0)
		end,

		release = function(self, player)
			local e = self.echoes[player]
			if e then
				e.body.used = false
				self:hide(e.body)
				self.echoes[player] = nil
			end
		end,

		reset = function(self)
			for player in pairs(self.echoes) do
				self:release(player)
			end
			for _, body in ipairs(self.bodies) do
				body.used = false
				self:hide(body)
			end
		end,

		shatter = function(self, e, t)
			C.fx("shatter", e.body.root.Position)
			self:hide(e.body)
			e.reformAt = t + k.reform
			e.path, e.cursor = {}, 1
		end,

		onBlast = function(self, position, radius)
			local t = C.now()
			for _, e in pairs(self.echoes) do
				if e.visible and (e.body.root.Position - position).Magnitude <= radius + 3 then
					self:shatter(e, t)
				end
			end
		end,

		tick = function(self, _, t)
			local present = {}
			for _, entry in ipairs(C.carriers(center, k.island)) do
				present[entry.player] = entry
				if not self.echoes[entry.player] then
					for _, body in ipairs(self.bodies) do
						if not body.used then
							body.used = true
							self.echoes[entry.player] =
								{ body = body, path = {}, cursor = 1, lastSample = 0, reformAt = 0, visible = false }
							Net.toast(
								entry.player,
								"YOUR ECHO IS BEHIND YOU. It follows your exact steps: never double back."
							)
							C.fx("chime", entry.root.Position)
							break
						end
					end
				end
			end
			self.busy = false
			for player, e in pairs(self.echoes) do
				local entry = present[player]
				if not entry then
					self:release(player)
				else
					self.busy = true
					if t - e.lastSample >= 0.1 then
						e.lastSample = t
						table.insert(e.path, { t = t, cf = entry.root.CFrame })
					end
					e.visible = false
					local playAt = t - k.delay
					if t >= e.reformAt and #e.path >= 2 and e.path[1].t <= playAt then
						while e.path[e.cursor + 1] and e.path[e.cursor + 1].t <= playAt do
							e.cursor += 1
						end
						local a, b = e.path[e.cursor], e.path[e.cursor + 1]
						local cf = a.cf
						if b then
							cf = a.cf:Lerp(b.cf, math.clamp((playAt - a.t) / math.max(b.t - a.t, 0.01), 0, 1))
						end
						e.body.root.CFrame = cf
						e.visible = true
						-- Old steps are forgotten once the echo has walked them.
						if e.cursor > 60 then
							local kept = {}
							for i = e.cursor, #e.path do
								table.insert(kept, e.path[i])
							end
							e.path, e.cursor = kept, 1
						end
						-- It hurts whoever it walks into: its own thief, or a rival on their heels.
						for _, other in ipairs(C.players(cf.Position, k.reach + 2)) do
							if (other.root.Position - cf.Position).Magnitude <= k.reach then
								C.strike(other, cf.Position, {
									damage = k.damage,
									push = flatUnit(other.root.Position - cf.Position, -cf.LookVector) * k.push
										+ v3(0, 20, 0),
									reason = "echo",
									text = other.player == player and "YOU WALKED INTO YOUR OWN ECHO!"
										or "AN ECHO! It was following someone else.",
								})
								self:shatter(e, t)
								break
							end
						end
					else
						self:hide(e.body)
					end
				end
			end
		end,
	})
end

-- OLD CLACKER (Shipwreck Shoals) -----------------------------------------------------------
local function crab()
	local k = K.Crab
	local center = C.at("Shoals")
	local SHELL = Color3.fromRGB(196, 92, 60)
	-- Its ground: sand, dry or in the shallows. Decks, rock and deep water are not.
	local function sand(_, _, y, material, instance)
		return instance == workspace.Terrain and material == M.Sand and y > -6
	end
	return C.add({
		name = "OldClacker",
		home = C.at("Shoals", 110, 0, 70),
		wake = k.island + 80,
		size = 7,

		build = function(self)
			self.scale = Config.GUARDIAN_SCALE.Crab -- V9: bigger
			-- Find real sand near the intended spot (the atoll's shape is not known to this file).
			local found
			for ring = 0, 8 do
				for step = 0, 7 do
					local a = step / 8 * math.pi * 2
					local x, z = self.home.X + math.cos(a) * ring * 12, self.home.Z + math.sin(a) * ring * 12
					local y, material, instance = C.floor(x, z)
					if not found and instance == workspace.Terrain and material == M.Sand and y > 0.5 then
						found = v3(x, y, z)
					end
				end
			end
			self.home = found or v3(self.home.X, 2, self.home.Z)
			self.model, self.root = C.body("OldClacker", {
				{ "Shell", v3(11, 6, 11), nil, SHELL, M.Slate, Enum.PartType.Ball },
				{
					"Hull",
					v3(8, 3, 13),
					CFrame.new(0, 3.4, 0) * CFrame.Angles(rad(8), 0, rad(6)),
					Color3.fromRGB(110, 78, 52),
					M.WoodPlanks,
				},
				{ "ClawL", v3(3, 2.4, 5), CFrame.new(-6.5, -0.6, -4), SHELL, M.Slate },
				{ "ClawR", v3(3, 2.4, 5), CFrame.new(6.5, -0.6, -4), SHELL, M.Slate },
				{ "EyeL", v3(0.9, 2.2, 0.9), CFrame.new(-1.6, 2.2, -4.6), Color3.fromRGB(250, 240, 200), M.Neon },
				{ "EyeR", v3(0.9, 2.2, 0.9), CFrame.new(1.6, 2.2, -4.6), Color3.fromRGB(250, 240, 200), M.Neon },
			}, nil, self.scale)
		end,

		-- depth: how far the shell is sunk into the sand (0 = fully up).
		show = function(self, depth)
			self.lift = CFrame.new(0, (3 - depth) * (self.scale or 1), 0)
			C.pose(self)
		end,

		reset = function(self)
			self.position, self.yaw = self.home, 0
			self.state, self.until_, self.awayUntil = "sleep", 0, 0
			self.grabbing = nil
			self:show(3.6) -- Asleep it is a mound with a wreck on its back.
		end,

		onBlast = function(self)
			if self.state == "up" or self.state == "grab" then
				self.state, self.awayUntil = "sleep", C.now() + k.retreat
				self.grabbing = nil
				self.position = self.home
				self:show(3.6)
				C.fx("thud", self.position)
				Net.feed("Old Clacker has had enough and gone under.", SHELL)
			end
		end,

		tick = function(self, dt, t)
			if t < self.awayUntil then
				self.busy = false
				return
			end
			if self.state == "warn" then
				if t >= self.until_ then
					-- Up it comes.
					self.state, self.until_ = "up", t + k.exposed
					self:show(0)
					C.fx("erupt", self.position)
					for _, entry in ipairs(C.players(self.position, k.radius)) do
						if math.abs(entry.root.Position.Y - self.position.Y) < 14 then
							C.strike(entry, self.position, {
								damage = k.damage,
								push = flatUnit(entry.root.Position - self.position) * 30 + v3(0, k.toss, 0),
								reason = "crab",
								text = "OLD CLACKER! It travels under the sand: get off it.",
							})
						end
					end
				end
				return
			elseif self.state == "up" then
				if t >= self.until_ then
					self.state = "under"
					self:show(4.6)
				end
				return
			elseif self.state == "grab" then
				local item = self.grabbing
				if not item or item.state ~= "loose" then
					self.state, self.grabbing = "under", nil
					self:show(4.6)
				elseif t >= self.until_ then
					Loot.sendHome(item, "taken:Old Clacker")
					self.state, self.grabbing = "under", nil
					self:show(4.6)
					C.fx("erupt", self.position)
				end
				return
			end
			-- Under the sand: after loose treasure first, then after whoever is carrying.
			local goal, isLoot
			for _, item in ipairs(C.looseLoot(center, k.island)) do
				local y, material, instance = C.floor(item.core.Position.X, item.core.Position.Z)
				if not item.held and sand(nil, nil, y, material, instance) and item.core.Position.Y - y < 8 then
					goal, isLoot = item, true
					break
				end
			end
			local target = not goal and C.nearest(C.carriers(center, k.island), self.position) or nil
			if not goal and not target then
				-- Nothing to do: go home and sleep.
				if self.state ~= "sleep" then
					if not C.walk(self, self.home, k.speed, dt, 2, sand) then
						self.state = "sleep"
						self.position = self.home
					end
					self:show(self.state == "sleep" and 3.6 or 4.6)
					self.busy = self.state ~= "sleep"
				end
				return
			end
			self.busy = true
			self.state = "under"
			local to = isLoot and goal.core.Position or target.root.Position
			local walking = C.walk(self, to, k.speed, dt, isLoot and 3 or 6, sand)
			self:show(4.6) -- Only the wreck on its back shows, sliding through the sand.
			if isLoot then
				if not walking and Util.flatDistance(to, self.position) < 6 then
					self.state, self.until_, self.grabbing = "grab", t + k.grab, goal
					self:show(0)
					C.fx("erupt", self.position)
				end
			elseif Util.flatDistance(to, self.position) <= k.radius - 2 then
				-- Only if they are standing on its ground.
				local y, material, instance = C.floor(to.X, to.Z, to.Y + 4)
				if sand(nil, nil, y, material, instance) and to.Y - y < 7 then
					self.state, self.until_ = "warn", t + k.erupt
					C.mark(v3(self.position.X, math.max(y, 0) + 0.3, self.position.Z), k.radius, k.erupt, SHELL)
					C.fx("rumble", self.position)
				end
			end
		end,
	})
end

-- BRAMBLE (Windmill Hills) -----------------------------------------------------------------
local function ram()
	local k = K.Ram
	local WOOL = Color3.fromRGB(235, 228, 210)
	local HORN = Color3.fromRGB(120, 96, 70)
	return C.add({
		name = "Bramble",
		home = C.at("Windmill", -250, 0, 20),
		wake = 330,
		size = 5 * Config.GUARDIAN_SCALE.Ram,
		lift = CFrame.new(0, 3.3 * Config.GUARDIAN_SCALE.Ram, 0), -- V9: bigger

		build = function(self)
			self.home = v3(self.home.X, C.floor(self.home.X, self.home.Z), self.home.Z)
			self.model, self.root = C.body("Bramble", {
				{ "Body", v3(4, 3.6, 6.4), nil, WOOL, M.Fabric },
				{ "Head", v3(2.4, 2.4, 2.6), CFrame.new(0, 1, -4), Color3.fromRGB(70, 60, 58), M.SmoothPlastic },
				{
					"HornL",
					v3(0.9, 0.9, 3),
					CFrame.new(-1.5, 2, -4.2) * CFrame.Angles(rad(35), rad(-25), 0),
					HORN,
					M.Slate,
				},
				{
					"HornR",
					v3(0.9, 0.9, 3),
					CFrame.new(1.5, 2, -4.2) * CFrame.Angles(rad(35), rad(25), 0),
					HORN,
					M.Slate,
				},
				{ "LegsF", v3(3, 2.2, 0.9), CFrame.new(0, -2.7, -2.2), Color3.fromRGB(70, 60, 58), M.SmoothPlastic },
				{ "LegsB", v3(3, 2.2, 0.9), CFrame.new(0, -2.7, 2.2), Color3.fromRGB(70, 60, 58), M.SmoothPlastic },
			}, nil, Config.GUARDIAN_SCALE.Ram)
		end,

		reset = function(self)
			self.position, self.yaw = self.home, 0
			self.state, self.until_, self.nextChargeAt, self.rageUntil = "graze", 0, 0, 0
			self.wander, self.nextWanderAt = self.home, 0
			C.pose(self)
		end,

		onTaken = function(self, item, _, fromSpot)
			if fromSpot and item.def.island == "Windmill" then
				self.rageUntil = C.now() + k.rage
				self.nextChargeAt = 0
			end
		end,

		onBlast = function(self)
			self.state, self.until_ = "dazed", C.now() + k.stun
			C.fx("thud", self.position)
		end,

		tick = function(self, dt, t)
			local raging = t < self.rageUntil
			if self.state == "dazed" then
				C.pose(self, CFrame.Angles(0, 0, rad(18) * math.sin(t * 9)))
				if t >= self.until_ then
					self.state = "graze"
				end
				return
			elseif self.state == "windup" then
				C.pose(self, CFrame.Angles(rad(14), 0, 0)) -- Head down.
				if t >= self.until_ then
					self.state, self.charged = "charge", 0
					self.hit = {}
				end
				return
			elseif self.state == "charge" then
				local way = self.way
				local step = k.speed * dt
				local nextPos = self.position + way * step
				local y = C.floor(nextPos.X, nextPos.Z, self.position.Y + 30)
				if y - self.position.Y > 7 then
					-- A cliff. That hurt.
					self.state, self.until_ = "dazed", t + k.stun
					C.fx("thud", self.position)
					return
				elseif y < 0.4 then
					self.state, self.until_ = "dazed", t + 1.4 -- Into the sea: it stops at the edge.
					return
				end
				self.position = v3(nextPos.X, y, nextPos.Z)
				self.charged += step
				C.pose(self, CFrame.Angles(rad(10), 0, 0))
				for _, entry in ipairs(C.players(self.position, 6 * Config.GUARDIAN_SCALE.Ram)) do
					if not self.hit[entry.player] and math.abs(entry.root.Position.Y - self.position.Y) < 12 then
						self.hit[entry.player] = true
						C.strike(entry, self.position, {
							damage = k.damage,
							push = way * k.toss + v3(0, k.lift, 0),
							pushTime = 0.3,
							reason = "ram",
							text = "BRAMBLE! It only charges in a straight line.",
						})
						C.fx("thud", self.position)
					end
				end
				if self.charged >= k.range then
					self.state, self.until_ = "dazed", t + 1.2
					self.nextChargeAt = t + (raging and 0.8 or k.rest)
				end
				return
			end
			-- Grazing: notice, then choose a line.
			-- Whoever is closest on dry land (it will not charge at someone in the sea).
			local ashore = {}
			for _, entry in ipairs(C.players(self.position, raging and k.notice * 1.6 or k.notice)) do
				local at = entry.root.Position
				if C.floor(at.X, at.Z, at.Y + 4) > 0.6 then
					table.insert(ashore, entry)
				end
			end
			local visitor = C.nearest(ashore, self.position)
			self.busy = visitor ~= nil or raging
			if visitor and t >= self.nextChargeAt and math.abs(visitor.root.Position.Y - self.position.Y) < 14 then
				self.way = flatUnit(visitor.root.Position - self.position)
				C.face(self, visitor.root.Position)
				self.state, self.until_ = "windup", t + k.windup
				self.nextChargeAt = t + k.rest
				-- The line it will run, drawn on the ground at both ends.
				C.mark(visitor.root.Position, 5, k.windup, WOOL)
				C.fx("bleat", self.position)
				return
			end
			if t >= self.nextWanderAt then
				self.nextWanderAt = t + 6
				local a = (t * 0.37 + self.home.X) % (math.pi * 2)
				self.wander = self.home + v3(math.cos(a), 0, math.sin(a)) * k.roam * 0.6
			end
			C.walk(self, self.wander, 7, dt, 2, function(_, _, y)
				return y > 1
			end)
			C.pose(self)
		end,
	})
end

-- THE WARDEN (Tide Vault) ------------------------------------------------------------------
local function eel()
	local k = K.Eel
	local center = C.at("Tide")
	local GLOW = Color3.fromRGB(120, 235, 255)
	local SEGMENTS = 7
	return C.add({
		name = "Warden",
		home = center,
		wake = 330,
		size = 10 * Config.GUARDIAN_SCALE.Eel,

		build = function(self)
			self.parts = {}
			local model = Instance.new("Model")
			model.Name = "Warden"
			for i = 1, SEGMENTS do
				local size = (i == 1 and 5 or (4.4 - i * 0.4)) * Config.GUARDIAN_SCALE.Eel -- V9: bigger
				local part = Util.part("Segment", v3(size, size, size), CFrame.new(0, -200, 0), GLOW, M.Neon, model)
				part.Shape = Enum.PartType.Ball
				part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
				part.Transparency = i == 1 and 0 or 0.25
				self.parts[i] = part
			end
			model.Parent = C.refs().folders.threats
			self.trail = {}
		end,

		reset = function(self)
			self.angle = 0
			self.position = center + v3(k.radius, 0, 0)
			self.huntUntil, self.stunnedUntil = 0, 0
			self.shocked = {}
			self.trail = {}
			self:draw()
		end,

		draw = function(self)
			-- The body follows where the head has been.
			table.insert(self.trail, 1, self.position)
			while #self.trail > SEGMENTS * 4 do
				table.remove(self.trail)
			end
			for i, part in ipairs(self.parts) do
				local at = self.trail[math.min((i - 1) * 4 + 1, #self.trail)]
				part.CFrame = CFrame.new(at.X, 0.4, at.Z)
			end
		end,

		onTaken = function(self, item, _, fromSpot)
			if fromSpot and item.def.island == "Tide" then
				self.huntUntil = C.now() + k.hunt
				Net.message("THE WARDEN IS LOOSE IN THE SHALLOWS - STAY OUT OF THE WATER!", 3, GLOW)
			end
		end,

		onBlast = function(self)
			self.stunnedUntil = C.now() + k.stun
			C.fx("zap", self.position)
		end,

		tick = function(self, dt, t)
			if t < self.stunnedUntil then
				return
			end
			-- Who is in the water?
			local wet = {}
			for _, entry in ipairs(C.players(center, k.leash)) do
				if entry.root.Position.Y < k.waterY and entry.distance > 46 and not entry.humanoid.SeatPart then
					table.insert(wet, entry)
				end
			end
			local hunting = t < self.huntUntil
			local prey
			if hunting then
				local carrying = {}
				for _, entry in ipairs(wet) do
					if entry.item then
						table.insert(carrying, entry)
					end
				end
				prey = C.nearest(#carrying > 0 and carrying or wet, self.position)
			end
			self.busy = hunting
			if prey then
				local to = flat(prey.root.Position - self.position)
				if to.Magnitude > 1 then
					self.position += to.Unit * math.min(k.huntSpeed * dt, to.Magnitude)
				end
			else
				-- The circuit: round the shallows between the stones and the vault.
				local onRing = flat(self.position - center)
				local wanted = center + v3(math.cos(self.angle), 0, math.sin(self.angle)) * k.radius
				if onRing.Magnitude > 1 and math.abs(onRing.Magnitude - k.radius) > 6 then
					-- Coming back from a hunt: rejoin the ring where it is nearest.
					self.angle = math.atan2(onRing.Z, onRing.X)
					wanted = center + onRing.Unit * k.radius
					local back = flat(wanted - self.position)
					self.position += back.Unit * math.min(k.speed * 1.4 * dt, back.Magnitude)
				else
					self.angle += k.speed / k.radius * dt
					self.position = center + v3(math.cos(self.angle), 0, math.sin(self.angle)) * k.radius
				end
			end
			self:draw()
			-- The shock: anyone in the water beside any part of it.
			for _, entry in ipairs(wet) do
				if t - (self.shocked[entry.player] or 0) > 1.5 then
					for i = 1, SEGMENTS, 2 do
						if Util.flatDistance(self.parts[i].Position, entry.root.Position) <= k.reach then
							self.shocked[entry.player] = t
							C.strike(entry, self.position, {
								damage = k.damage,
								push = flatUnit(entry.root.Position - self.parts[i].Position) * 24 + v3(0, k.lift, 0),
								reason = "eel",
								text = "THE WARDEN! It only reaches you in the water.",
							})
							C.fx("zap", entry.root.Position)
							break
						end
					end
				end
			end
			-- Boats it bumps into are shoved off, unharmed.
			if hunting then
				for _, boat in ipairs(Boats.list) do
					if boat.state == "float" and t - (boat.eelAt or 0) > 2 then
						local off = flat(boat.hull.Position - self.position)
						if off.Magnitude < 14 then
							boat.eelAt = t
							Boats.shove(boat, off.Unit * 26, 0)
							C.fx("zap", boat.hull.Position)
						end
					end
				end
			end
		end,
	})
end

-- THE IMPS (Tangle Isle) -------------------------------------------------------------------
-- Pillar tops they use, as offsets from the island and a height (IslandsFar's pillars and
-- Outlands' new ones). The last is the nest.
local PERCHES = {
	{ -70, 52, 40 },
	{ -10, 62, -10 },
	{ 55, 58, -35 },
	{ 95, 46, 10 },
	{ 120, 84, -75 },
	{ -180, 58, -130 },
	{ 70, 62, -220 },
	{ -90, 50, -190 },
	{ -250, 66, -10 },
}
local NEST = #PERCHES

local function imp(index, perchIndex)
	local k = K.Imp
	local center = C.at("Tangle")
	local FUR = Color3.fromRGB(96, 150, 84)
	local function perch(i)
		local p = PERCHES[i]
		return C.at("Tangle", p[1], p[2] + 1.6, p[3])
	end
	return C.add({
		name = "Imp" .. index,
		home = perch(perchIndex),
		wake = 420,
		size = 4,

		build = function(self)
			self.model, self.root = C.body("Imp", {
				{ "Body", v3(2.2, 2.6, 1.8), nil, FUR, M.Fabric },
				{ "Head", v3(2, 1.8, 1.8), CFrame.new(0, 2, -0.2), FUR, M.Fabric },
				{ "EarL", v3(0.5, 1.6, 0.9), CFrame.new(-1.2, 2.6, 0) * CFrame.Angles(0, 0, rad(30)), FUR, M.Fabric },
				{ "EarR", v3(0.5, 1.6, 0.9), CFrame.new(1.2, 2.6, 0) * CFrame.Angles(0, 0, rad(-30)), FUR, M.Fabric },
				{ "EyeL", v3(0.4, 0.4, 0.2), CFrame.new(-0.45, 2.2, -1.1), Color3.fromRGB(255, 220, 90), M.Neon },
				{ "EyeR", v3(0.4, 0.4, 0.2), CFrame.new(0.45, 2.2, -1.1), Color3.fromRGB(255, 220, 90), M.Neon },
				{ "Tail", v3(0.5, 0.5, 3), CFrame.new(0, -0.6, 2.2) * CFrame.Angles(rad(35), 0, 0), FUR, M.Fabric },
			})
		end,

		drop = function(self, velocity)
			if self.holding then
				Loot.letGo(self.holding, velocity or v3(0, 16, 0))
				self.holding = nil
			end
		end,

		reset = function(self)
			self:drop()
			self.position, self.yaw = self.home, 0
			self.state, self.hop, self.nextTryAt, self.until_ = "idle", nil, 0, 0
			self.goal = nil
			C.pose(self)
		end,

		-- One jump from where it is to `to`, taking as long as the distance needs.
		jump = function(self, to, seconds)
			local from = self.position
			local duration = seconds or math.max(0.45, (to - from).Magnitude / k.hop)
			self.hop = { from = from, to = to, t0 = C.now(), t1 = C.now() + duration }
			C.face(self, to)
		end,

		-- Hops toward a far perch by way of the perches between. Returns true when it has arrived.
		travel = function(self, goalIndex)
			local goal = perch(goalIndex)
			if (self.position - goal).Magnitude < 3 then
				return true
			end
			local best, bestDistance = goal, (self.position - goal).Magnitude
			for i = 1, #PERCHES do
				local p = perch(i)
				local hop, left = (p - self.position).Magnitude, (p - goal).Magnitude
				if hop > 4 and hop < 170 and left < bestDistance - 20 then
					best, bestDistance = p, left
				end
			end
			self:jump(best)
			return false
		end,

		onBlast = function(self)
			self:drop(v3(0, 20, 0))
			self.state, self.nextTryAt = "home", C.now() + k.rest * 2
			C.fx("shriek", self.position)
		end,

		-- The Jade Frog has just been taken: they go for it at once, one after the other.
		onTaken = function(self, item, _, fromSpot)
			if fromSpot and item.def.island == "Tangle" then
				self.nextTryAt = C.now() + (index - 1) * 2.5
			end
		end,

		tick = function(self, _, t)
			-- In the air.
			local hop = self.hop
			if hop then
				local a = math.clamp((t - hop.t0) / (hop.t1 - hop.t0), 0, 1)
				local arc = math.sin(a * math.pi) * math.max(8, (hop.to - hop.from).Magnitude * 0.18)
				self.position = hop.from:Lerp(hop.to, a) + v3(0, arc, 0)
				C.pose(self)
				if self.holding then
					if self.holding.state ~= "loose" or not self.holding.held then
						self.holding = nil
					else
						Loot.hold(self.holding, self.root.CFrame * CFrame.new(0, 3.4, 0))
					end
				end
				if a < 1 then
					self.busy = true
					return
				end
				self.hop = nil
				self.position = hop.to
			end
			local state = self.state
			if state == "leap" then
				-- Landed on the mark. Is the thief still on it?
				local victim
				for _, entry in ipairs(C.carriers(self.position, k.reach)) do
					if math.abs(entry.root.Position.Y - self.position.Y) < 10 then
						victim = entry
					end
				end
				if victim then
					local item = victim.item
					Loot.worldTake(victim.player, "imp")
					if item.state == "loose" and Loot.hold(item, self.root.CFrame * CFrame.new(0, 3.4, 0)) then
						self.holding = item
						self.state = "flee"
						Net.toast(victim.player, "AN IMP HAS IT! It is running for its nest in the west of the canopy.")
						C.fx("shriek", self.position)
						return
					end
				end
				self.state, self.until_ = "miss", t + 1.2
				self.nextTryAt = t + k.rest
				return
			elseif state == "miss" then
				if t >= self.until_ then
					self.state = "home"
				end
				return
			elseif state == "flee" then
				if not self.holding then
					self.state = "home"
				elseif self:travel(NEST) then
					self.state, self.until_ = "nest", t + k.hold
				end
				self.busy = true
				return
			elseif state == "nest" then
				self.busy = true
				local item = self.holding
				if not item or item.state ~= "loose" or not item.held then
					self.holding = nil
					self.state = "home"
				elseif #C.players(self.position, k.scare) > 0 then
					-- Cornered: it drops the treasure and bolts.
					self:drop(v3(0, 14, 0))
					self.state, self.nextTryAt = "home", t + k.rest
					C.fx("shriek", self.position)
				elseif t >= self.until_ then
					Loot.sendHome(item, "taken:The imps")
					self.holding = nil
					self.state = "home"
				else
					Loot.hold(item, self.root.CFrame * CFrame.new(0, 3.4, 0))
				end
				return
			elseif state == "home" then
				self.busy = not self:travel(perchIndex)
				if not self.busy then
					self.state = "idle"
				end
				return
			end
			-- Idle on a perch: watching for someone carrying treasure through the canopy.
			self.busy = false
			if t < self.nextTryAt then
				return
			end
			for _, entry in ipairs(C.carriers(center, 330)) do
				local to = entry.root.Position
				if (to - self.position).Magnitude <= k.notice and to.Y > 18 then
					-- Shriek, mark the spot, and jump for it.
					self.state = "leap"
					self.nextTryAt = t + k.rest
					local y = C.floor(to.X, to.Z, to.Y + 4)
					local mark = v3(to.X, y + 0.3, to.Z)
					C.mark(mark, k.reach, k.leap, FUR)
					C.fx("shriek", self.position)
					Net.toast(entry.player, "AN IMP IS JUMPING FOR IT - get off the marked spot!")
					self:jump(mark + v3(0, 1.6, 0), k.leap)
					self.busy = true
					return
				end
			end
		end,
	})
end

-- THE GARRISON (Fort Barnacle) -------------------------------------------------------------
local function marine(index, route)
	local k = K.Marine
	local center = C.at("Fort", 0, 0, -10)
	local COAT = Color3.fromRGB(170, 40, 46)
	local points = {}
	for i, p in ipairs(route) do
		points[i] = C.at("Fort", p[1], 0, p[2])
	end
	-- The yard: inside the walls and on the plateau.
	local function inYard(position)
		local off = position - center
		return math.abs(off.X) < 50 and math.abs(off.Z) < 50
	end
	return C.add({
		name = "Marine" .. index,
		home = points[1],
		wake = 320,
		size = 4,
		lift = CFrame.new(0, 4.4, 0),

		build = function(self)
			self.home = v3(self.home.X, C.floor(self.home.X, self.home.Z), self.home.Z)
			self.model, self.root = C.body("Marine", {
				{ "Coat", v3(2.6, 3.2, 1.6), nil, COAT, M.Fabric },
				{ "Head", v3(1.6, 1.6, 1.6), CFrame.new(0, 2.4, 0), Color3.fromRGB(236, 196, 160), M.SmoothPlastic },
				{ "Hat", v3(2.6, 0.6, 2.6), CFrame.new(0, 3.4, 0), Color3.fromRGB(30, 30, 40), M.Fabric },
				{ "Legs", v3(2.2, 2.8, 1.2), CFrame.new(0, -3, 0), Color3.fromRGB(240, 240, 235), M.Fabric },
				{ "Lantern", v3(0.9, 1.2, 0.9), CFrame.new(1.6, 0.4, -1.4), Color3.fromRGB(255, 220, 120), M.Neon },
				-- The edges of what it can see, drawn on the ground in front of it.
				{
					"SightL",
					v3(0.5, 0.2, k.sight),
					CFrame.new(0, -4.2, 0) * CFrame.Angles(0, rad(k.cone), 0) * CFrame.new(0, 0, -k.sight / 2),
					Color3.fromRGB(255, 230, 120),
					M.Neon,
					nil,
					0.55,
				},
				{
					"SightR",
					v3(0.5, 0.2, k.sight),
					CFrame.new(0, -4.2, 0) * CFrame.Angles(0, rad(-k.cone), 0) * CFrame.new(0, 0, -k.sight / 2),
					Color3.fromRGB(255, 230, 120),
					M.Neon,
					nil,
					0.55,
				},
			})
			local light = Instance.new("SpotLight")
			light.Angle = k.cone * 2
			light.Range = k.sight
			light.Brightness = 3
			light.Color = Color3.fromRGB(255, 225, 150)
			light.Face = Enum.NormalId.Front
			light.Parent = self.root
		end,

		reset = function(self)
			self.position, self.yaw = self.home, 0
			self.leg, self.state, self.until_, self.target = 2, "patrol", 0, nil
			self.nextSpotAt, self.stunnedUntil = 0, 0
			C.pose(self)
		end,

		onBlast = function(self)
			self.stunnedUntil = C.now() + k.stun
			self.state, self.target = "patrol", nil
			C.pose(self, CFrame.new(0, -1.6, 0) * CFrame.Angles(rad(-80), 0, 0))
			C.fx("thud", self.position)
		end,

		-- The first goblin in its cone, with a clear line.
		spot = function(self)
			local eye = self.position + v3(0, 5, 0)
			local way = C.heading(self)
			for _, entry in ipairs(C.players(self.position, k.sight)) do
				local to = entry.root.Position - self.position
				if
					math.abs(to.Y) < 12
					and inYard(entry.root.Position)
					and flatUnit(to):Dot(way) >= math.cos(rad(k.cone))
					and C.canSee(eye, entry.root.Position + v3(0, 1, 0))
				then
					return entry
				end
			end
			return nil
		end,

		tick = function(self, dt, t)
			if t < self.stunnedUntil then
				return
			end
			if self.state == "whistle" then
				if t >= self.until_ then
					self.state, self.until_ = "chase", t + k.chaseTime
				end
				C.pose(self)
				return
			elseif self.state == "chase" then
				self.busy = true
				local entry
				for _, e in ipairs(C.players(self.position, 140)) do
					if e.player == self.target then
						entry = e
					end
				end
				if not entry or t >= self.until_ or not inYard(entry.root.Position) then
					self.state, self.target = "patrol", nil
					self.nextSpotAt = t + k.rest
					return
				end
				local to = entry.root.Position
				if Util.flatDistance(to, self.position) <= k.reach and math.abs(to.Y - self.position.Y) < 10 then
					-- Heave-ho: over the nearest wall.
					local out = flatUnit(to - center, C.heading(self))
					C.strike(entry, self.position, {
						push = out * k.throw + v3(0, k.lift, 0),
						pushTime = 0.32,
						reason = "marine",
						text = "THROWN OUT! Stay out of the lantern light.",
					})
					C.fx("thud", self.position)
					self.state, self.target = "patrol", nil
					self.nextSpotAt = t + k.rest
				else
					C.walk(self, to, k.chase, dt, k.reach - 1.5, function(x, z)
						return inYard(v3(x, 0, z))
					end)
				end
				C.pose(self)
				return
			end
			-- Patrol.
			self.busy = false
			if not C.walk(self, points[self.leg], k.patrol, dt, 2) then
				self.leg = self.leg % #points + 1
			end
			C.pose(self)
			if t >= self.nextSpotAt then
				local seen = self:spot()
				if seen then
					self.state, self.until_, self.target = "whistle", t + k.whistle, seen.player
					self.busy = true
					C.face(self, seen.root.Position)
					C.fx("whistle", self.position)
					Net.toast(seen.player, "A MARINE HAS SEEN YOU!")
				end
			end
		end,
	})
end

-- The roster --------------------------------------------------------------------------------
watcher(1, -50, -10)
watcher(2, 0, 30)
watcher(3, 95, 95)
watcher(4, -115, 65)
echo()
crab()
ram()
eel()
-- They live on the two pillars nearest the shrine, where the treasure is taken from.
imp(1, 3)
imp(2, 4)
-- Routes are offsets from the fort's center: one loop between the barracks, one beat along the south wall.
marine(1, { { -12, -14 }, { 12, -14 }, { 12, 34 }, { -12, 34 } })
marine(2, { { -46, 34 }, { 46, 34 } })

return true

-- Boat abilities (V13): one per class, on the stunt key while the hull is on the water (Config.BOAT_ABILITIES).
--
-- The physical part (Nitro's burst, the Reefhopper's spring, the Wraith's sideways slip, the Ironbelly's charge) is
-- played by shared/BoatSim.lua on whichever machine simulates the hull, so it answers the frame the key is pressed;
-- the driver's client tells the server it played (BoatAbilityRequest, with where the driver is looking). This module:
--   * owns the cooldown (the boat's AbilityReadyAt attribute) and refuses a request that comes too soon;
--   * tells the anti-cheat (Boats.police) how much extra speed the ability is allowed;
--   * does everything the server owns:
--       Skiff        NITRO      (V13.2) breaks any chain or hook on it, and shrugs off shoves while it burns
--       Cutter       RALLY HORN (V13.2) every boat near it surges (a boost), chasing monsters flinch back, a hull patch
--       Broadside    BROADSIDE  three shots from the gun on the side the driver looks to
--       Stormrunner  TWISTER    a real, short tornado spins up in its wake (Tornadoes.summon)
--       Wraith       PHANTOM    a ghost of the boat runs on along the old course; pursuers chase it (Pursuit.decoy)
--       Ironbelly    RAM PLOW   for its length, boats it runs into are shoved aside and pursuers thrown off
--       Anchorjack   ANCHOR     (V13.2) the anchor snags a rival's hull (it is chained to you: Boats.tether) or bites a
--                               rock or the sea bed (the Anchorjack swings round it, its own client's BoatSim)
--       Wavebreaker  BREAKER    (V13.2) a ring of water: boats thrown outward, swimmers washed away, pursuers knocked back
--       Corsair      BOARDING HOOK (V13.2) the hook bites the rival hull ahead and its client reels it in; reaching it
--                               is BOARDING: the target is shoved aside and slowed, and a carrier aboard drops their loot
-- Chains (anchor and hook) are listed here so they can be drawn (BoatChain), snapped (Nitro, Phantom, too far, a sunk
-- hull) and judged (a boarding), whoever simulates each hull.
-- Fair play: shots from a goblin's boat never reach someone at home (the Hoard's ward) or in the Port, and no ability
-- acts on a boat there; nothing here does lasting damage beyond a cannon's ordinary hull damage; every ability has a
-- cooldown and a tell.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Cannons = require(script.Parent.Cannons)
local SeaNav = require(script.Parent.SeaNav)
local Tornadoes = require(script.Parent.Tornadoes)
local Pursuit = require(script.Parent.Pursuit)
local Loot = require(script.Parent.Loot)
local Leviathan = require(script.Parent.Leviathan)

local BoatAbilities = {}
BoatAbilities.Used = Util.signal() -- (player, abilityId, boat): for progress (server/Progress.lua counts some)

local A = Config.BOAT_ABILITIES
local refs
local lastRequest = {} -- player -> time
local ghosts = {} -- player -> { model, root, at, velocity, untilAt, born }
local plows = {} -- boat -> { player, untilAt, hit = { [boat] = true } }
local chains = {} -- id -> { id, kind ("snag" | "swing" | "reel" | "zip"), boat, player, target (boat), point, untilAt, startGap }
local nextChain = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function finite(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5
end

local function refuse(player, text)
	Net.send(player, "AbilityRefused", { text = text })
end

local function lookOf(boat)
	local look = flat(boat.hull.CFrame.LookVector)
	return look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
end

-- V13.2: where no ability may act (the Port, and the water round home): Main sets it.
BoatAbilities.safe = function(_position)
	return false
end

-- Chains ---------------------------------------------------------------------------------------------------------------
local function endChain(chain, why)
	if not chains[chain.id] then
		return
	end
	chains[chain.id] = nil
	-- Tell whoever simulates each hull to let go. (When the driver's own client let go, it already has.)
	if why == "released" or why == "arrived" then
		chain.boat.serverTether = nil
		chain.boat.model:SetAttribute("Chained", nil)
	else
		Boats.tether(chain.boat, nil)
	end
	if chain.target then
		Boats.tether(chain.target, nil)
	end
	Net.broadcast("BoatChainEnd", { id = chain.id, why = why })
end

local function chainsOn(boat)
	local list = {}
	for _, chain in pairs(chains) do
		if chain.boat == boat or chain.target == boat then
			table.insert(list, chain)
		end
	end
	return list
end

-- Everything chained to this boat lets go (a Nitro, a Phantom slip, a wreck).
function BoatAbilities.breakFree(boat, why)
	for _, chain in ipairs(chainsOn(boat)) do
		endChain(chain, why or "broken")
	end
end

local function startChain(kind, boat, player, target, point, untilAt)
	nextChain += 1
	local chain = {
		id = nextChain,
		kind = kind,
		boat = boat,
		player = player,
		target = target,
		point = point,
		untilAt = untilAt,
		startGap = flat((target and target.hull.Position or point) - boat.hull.Position).Magnitude,
	}
	chains[chain.id] = chain
	Net.broadcast("BoatChain", {
		id = chain.id,
		kind = kind,
		a = boat.hull,
		b = target and target.hull or nil,
		point = point,
		untilAt = untilAt,
	})
	return chain
end

-- A rival hull near where the driver aimed: in range, ahead of the bow, not the driver's own, not in a safe place.
-- `hint` is the hull the client chose (it is only believed if it passes the same tests).
local function rivalAhead(boat, aim, range, cone, assist, hint)
	local from = flat(boat.hull.Position)
	local look = lookOf(boat)
	local aimDir = aim and flat(aim - boat.hull.Position) or look
	aimDir = aimDir.Magnitude > 1 and aimDir.Unit or look
	local best, bestScore = nil, math.huge
	for _, other in ipairs(Boats.list) do
		if other ~= boat and other.state == "float" and not BoatAbilities.safe(other.hull.Position) then
			local offset = flat(other.hull.Position) - from
			local distance = offset.Magnitude
			if distance > 4 and distance <= range + other.spec.size.Z * 0.5 then
				local dir = offset.Unit
				local along = offset:Dot(aimDir)
				local off = (offset - aimDir * along).Magnitude
				if dir:Dot(look) >= cone and along > 0 and off <= assist + other.spec.size.X then
					local score = off + distance * 0.15 - (other.hull == hint and 40 or 0)
					if score < bestScore then
						best, bestScore = other, score
					end
				end
			end
		end
	end
	return best
end

-- Where a thrown anchor or hook bites if no boat is in reach: the first solid thing along the aim, or (the anchor
-- only) the sea bed at the end of the throw.
local biteParams = RaycastParams.new()
biteParams.FilterType = Enum.RaycastFilterType.Exclude
biteParams.IgnoreWater = true
local function biteAlong(boat, aim, range, seabed)
	local from = boat.hull.Position + Vector3.new(0, 3, 0)
	local look = lookOf(boat)
	local dir = aim and flat(aim - from) or look
	dir = dir.Magnitude > 1 and dir.Unit or look
	if dir:Dot(look) < -0.2 then
		dir = look
	end
	biteParams.FilterDescendantsInstances = { boat.model, refs and refs.folders.fx or nil }
	local hit = workspace:Raycast(from, dir * range, biteParams)
	if hit and not Boats.boatOf(hit.Instance) then
		return hit.Position
	end
	if seabed then
		local reach = aim and math.clamp(flat(aim - from).Magnitude, 40, range) or range * 0.6
		return flat(from) + dir * reach
	end
	return nil
end

-- The Skiff's Nitro: it breaks free of everything holding it.
local function nitro(boat, _player)
	boat.nitroUntil = now() + A.nitro.time -- Boats.shove reads it: shoves are shrugged off while it burns
	BoatAbilities.breakFree(boat, "nitro")
	return true
end

-- The Cutter's Rally Horn: a convoy surge.
local function rally(boat, player)
	local spec = A.rally
	local t = now()
	local here = boat.hull.Position
	if BoatAbilities.safe(here) then
		return false, "Save the horn for the open sea."
	end
	local surged = 0
	for _, other in ipairs(Boats.list) do
		if other.state == "float" and not other.ai and flat(other.hull.Position - here).Magnitude <= spec.radius then
			other.boostUntil = math.max(other.boostUntil, t + spec.boost)
			other.model:SetAttribute("BoostEndsAt", other.boostUntil)
			other.impactGraceUntil = math.max(other.impactGraceUntil, t + 0.4)
			if other ~= boat then
				surged += 1
			end
		end
	end
	Boats.patch(boat, spec.patch)
	local flinched = Pursuit.shoveAt(here, spec.flinch, spec.push)
	local head = Leviathan.headPosition()
	if head and flat(head - here).Magnitude < spec.flinch then
		Leviathan.recoil()
		flinched += 1
	end
	if surged > 0 or flinched > 0 then
		Net.feed(
			string.format(
				"%s's Rally Horn!%s%s",
				player.DisplayName,
				surged > 0 and string.format(" %d boat%s surged.", surged, surged > 1 and "s" or "") or "",
				flinched > 0 and " The monsters flinched." or ""
			),
			Color3.fromRGB(255, 220, 140)
		)
	end
	return true
end

-- The Wavebreaker's Breaker: a ring of water out from the hull.
local function breaker(boat, player)
	local spec = A.breaker
	local here = boat.hull.Position
	if BoatAbilities.safe(here) then
		return false, "Too close to home to make waves."
	end
	local thrown = 0
	for _, other in ipairs(Boats.list) do
		if other ~= boat and other.state == "float" and not BoatAbilities.safe(other.hull.Position) then
			local offset = flat(other.hull.Position - here)
			local distance = offset.Magnitude
			if distance < spec.radius + other.spec.size.Z * 0.4 then
				local k = math.clamp(1 - distance / (spec.radius + other.spec.size.Z * 0.4), 0, 1)
				local push = spec.edgePush + (spec.push - spec.edgePush) * k
				local away = distance > 0.5 and offset.Unit or lookOf(boat)
				local spinSide = away:Cross(lookOf(boat)).Y > 0 and 1 or -1
				Boats.shove(
					other,
					away * push + Vector3.new(0, spec.lift * (0.5 + k * 0.5), 0),
					Vector3.new(0, spinSide * 1.2, 0)
				)
				thrown += 1
			end
		end
	end
	-- Swimmers (not anyone in a boat: the hull takes the wave).
	for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
		if other ~= player then
			local root, humanoid = Util.aliveRoot(other)
			if root and not humanoid.SeatPart and root.Position.Y < Config.WATER_ROOT_Y + 2 then
				local offset = flat(root.Position - here)
				if offset.Magnitude < spec.swimRadius and not BoatAbilities.safe(root.Position) then
					local away = offset.Magnitude > 0.5 and offset.Unit or lookOf(boat)
					Util.knockback(root, away * spec.swimPush + Vector3.new(0, spec.swimPush * 0.5, 0), 0.25)
				end
			end
		end
	end
	Pursuit.shoveAt(here, spec.flinch, 110)
	-- Loose treasure on the water is washed outward too.
	for _, item in ipairs(Loot.items) do
		if item.state == "loose" and not item.held then
			local offset = flat(item.core.Position - here)
			if offset.Magnitude < spec.radius and offset.Magnitude > 0.5 and not item.core.Anchored then
				item.core:ApplyImpulse((offset.Unit * 40 + Vector3.new(0, 30, 0)) * item.core.AssemblyMass)
			end
		end
	end
	Net.broadcastNear(here, 1600, "BoatWave", { position = here, radius = spec.radius, userId = player.UserId })
	if thrown > 0 then
		Net.feed(
			string.format("%s's Wavebreaker threw %d boat%s!", player.DisplayName, thrown, thrown > 1 and "s" or ""),
			Color3.fromRGB(140, 220, 255)
		)
	end
	return true
end

-- The Anchorjack's anchor.
local function anchor(boat, player, aim, info)
	local spec = A.anchor
	if BoatAbilities.safe(boat.hull.Position) then
		return false, "Not in the harbour!"
	end
	local hint = info and typeof(info.target) == "Instance" and info.target or nil
	local target = rivalAhead(boat, aim, spec.range, spec.arc, spec.assist, hint)
	local t = now()
	BoatAbilities.breakFree(boat, "replaced")
	if target then
		local chain = startChain("snag", boat, player, target, nil, t + spec.snag)
		local length = math.max(spec.snagMin, chain.startGap * spec.snagSlack)
		-- The rival is chained to the Anchorjack (its own client drags it)...
		Boats.tether(
			target,
			{ kind = "towed", part = boat.hull, length = length, untilAt = t + spec.snag, chain = chain.id },
			80
		)
		-- ...and the Anchorjack to the rival (its client already did this if it chose the same hull).
		local mine = { kind = "snag", part = target.hull, length = length, untilAt = t + spec.snag, chain = chain.id }
		if not boat.pilot then
			boat.abilityTarget = { part = target.hull }
		elseif hint ~= target.hull then
			Boats.tether(boat, mine, 80)
		end
		boat.serverTether = mine
		local victim = target.driver and target.driver.Occupant
		local victimPlayer = victim and game:GetService("Players"):GetPlayerFromCharacter(victim.Parent)
		if victimPlayer then
			Net.toast(
				victimPlayer,
				player.DisplayName .. "'s anchor caught your boat! (Nitro, a Phantom slip or distance breaks it)"
			)
		end
		Net.feed(player.DisplayName .. " anchored a rival boat!", Color3.fromRGB(150, 220, 200))
		return true
	end
	local point = biteAlong(boat, aim, spec.range, true)
	startChain("swing", boat, player, nil, point, t + spec.swing)
	if not boat.pilot then
		boat.abilityTarget = { point = point }
	elseif hint then
		-- The client guessed a boat the server would not give it: swing on the bite instead.
		Boats.tether(boat, {
			kind = "swing",
			point = point,
			length = math.max(spec.swingMin, flat(point - boat.hull.Position).Magnitude),
			untilAt = t + spec.swing,
		}, 60)
	end
	return true
end

-- The Corsair's boarding hook.
local function hook(boat, player, aim, info)
	local spec = A.hook
	if BoatAbilities.safe(boat.hull.Position) then
		return false, "Not in the harbour!"
	end
	local hint = info and typeof(info.target) == "Instance" and info.target or nil
	local target = rivalAhead(boat, aim, spec.range, spec.cone, 30, hint)
	local t = now()
	BoatAbilities.breakFree(boat, "replaced")
	if target then
		startChain("reel", boat, player, target, nil, t + spec.reelTime)
		if not boat.pilot then
			boat.abilityTarget = { part = target.hull }
		elseif hint ~= target.hull then
			Boats.tether(boat, { kind = "reel", part = target.hull, untilAt = t + spec.reelTime, startGap = 0 }, 90)
		end
		local victim = target.driver and target.driver.Occupant
		local victimPlayer = victim and game:GetService("Players"):GetPlayerFromCharacter(victim.Parent)
		if victimPlayer then
			Net.toast(victimPlayer, "BOARDING HOOK! " .. player.DisplayName .. " is reeling in on you!")
		end
		return true
	end
	local point = biteAlong(boat, aim, spec.zip, false)
	if not point then
		return false, "Nothing to hook: aim at a boat (or a rock) ahead."
	end
	startChain("zip", boat, player, nil, point, t + spec.reelTime)
	if not boat.pilot then
		boat.abilityTarget = { point = point }
	elseif hint then
		Boats.tether(boat, { kind = "zip", point = point, untilAt = t + spec.reelTime, startGap = 0 }, 90)
	end
	return true
end

-- A boarding: the Corsair reached the boat it hooked.
local function board(chain)
	local spec = A.hook
	local boat, target = chain.boat, chain.target
	local here, there = boat.hull.Position, target.hull.Position
	local side = flat(there - here)
	side = side.Magnitude > 0.5 and side.Unit or lookOf(boat)
	local v = flat(target.hull.AssemblyLinearVelocity)
	-- Shoved aside, and most of its way lost.
	Boats.shove(target, side * spec.hitShove - v * (1 - spec.slow) + Vector3.new(0, 18, 0), Vector3.new(0, 1.4, 0))
	Boats.damage(target, spec.hullDamage, chain.player.DisplayName .. "'s boarding party")
	Boats.damage(boat, spec.selfDamage, "a boarding")
	local dropped = 0
	for _, seat in ipairs(target.seats or {}) do
		local humanoid = seat.Occupant
		local victim = humanoid and game:GetService("Players"):GetPlayerFromCharacter(humanoid.Parent)
		if victim and Loot.knockLoose(victim, here, "boarded", chain.player) then
			dropped += 1
		end
	end
	Net.broadcastNear(there, 1400, "BoatImpact", { position = there, power = 1 })
	Net.broadcastNear(there, 1400, "Boarded", { position = there, userId = chain.player.UserId })
	Net.feed(
		chain.player.DisplayName
			.. " BOARDED a "
			.. target.spec.name
			.. (dropped > 0 and ": the treasure went over the side!" or "!"),
		Color3.fromRGB(255, 120, 110)
	)
	endChain(chain, "boarded")
end

local function tickChains(t)
	for _, chain in pairs(chains) do
		local boat, target = chain.boat, chain.target
		if
			boat.state ~= "float"
			or not boat.model.Parent
			or (target and (target.state ~= "float" or not target.model.Parent))
		then
			endChain(chain, "sunk")
		elseif t >= chain.untilAt then
			endChain(chain, "slipped")
		elseif chain.kind == "reel" then
			local gap = flat(target.hull.Position - boat.hull.Position).Magnitude
			local reach = A.hook.board + (boat.spec.size.X + target.spec.size.X) * 0.5
			if gap <= reach then
				board(chain)
			elseif gap > math.max(chain.startGap, 40) * A.hook.snap then
				endChain(chain, "snapped")
			elseif BoatAbilities.safe(target.hull.Position) then
				endChain(chain, "safe")
			end
		elseif chain.kind == "snag" then
			if BoatAbilities.safe(target.hull.Position) then
				endChain(chain, "safe")
			end
		end
	end
end

-- The Broadside's volley: the gun on the side the driver looks to fires three shots, spread along the boat's line.
local function volley(boat, player, aim)
	local look = lookOf(boat)
	local right = Vector3.new(-look.Z, 0, look.X)
	local from = boat.hull.Position
	local toward = aim and flat(aim - from) or right
	local side = toward:Dot(right) >= 0 and 1 or -1
	local entry = Cannons.boatGun(boat, side)
	if not entry then
		return false, "This boat has no side guns."
	end
	local out = right * side
	local spec = A.volley
	if toward.Magnitude < 20 or (toward.Magnitude > 0 and toward.Unit:Dot(out) < 0.25) then
		aim = from + out * 170
	elseif toward.Magnitude > spec.range then
		aim = from + toward.Unit * spec.range
	end
	aim = Vector3.new(aim.X, math.max(aim.Y, 0), aim.Z)
	for i = 1, spec.shots do
		local along = (i - (spec.shots + 1) / 2) * spec.spread
		task.delay((i - 1) * 0.12, function()
			if boat.state == "float" and boat.model.Parent then
				Cannons.launch(entry, aim + look * along, player, Config.BOAT_SHOT)
			end
		end)
	end
	return true
end

-- The Stormrunner's twister: over open water, away from home and the Port, behind the stern.
local function twister(boat, player)
	local spec = A.twister
	local hull = boat.hull
	if Lobby.inPort(hull.Position) then
		return false, "No tornadoes in the Port!"
	end
	if refs and Util.flatDistance(hull.Position, refs.hoard.position) < spec.homeClear then
		return false, "Too close to home for a tornado."
	end
	local look = lookOf(boat)
	local at = flat(hull.Position) - look * spec.behind
	if SeaNav.depthAt(at.X, at.Z) < 5 or SeaNav.depthAt(hull.Position.X, hull.Position.Z) < 4 then
		return false, "A tornado needs open water."
	end
	local tw = Tornadoes.summon(at, look, player.UserId, spec.life, spec.drift, spec.max)
	if not tw then
		return false, "The sky has all the tornadoes it can hold."
	end
	Net.feed(player.DisplayName .. "'s Stormrunner whipped up a tornado!", Color3.fromRGB(170, 200, 255))
	return true
end

-- The Wraith's ghost: a see-through copy of the hull running straight on along the course it had.
local function ghostModel(boat)
	local model = Instance.new("Model")
	model.Name = "PhantomGhost"
	local size = boat.spec.size
	local function piece(name, partSize, offset, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = partSize
		p.CFrame = boat.hull.CFrame * offset
		p.Color = Color3.fromRGB(150, 255, 225)
		p.Material = Enum.Material.Neon
		p.Transparency = transparency
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Anchored = false
		p.Massless = true
		p.Parent = model
		return p
	end
	local root = piece("Hull", size, CFrame.new(), 0.55)
	root.Anchored = true
	local sail = piece("Sail", Vector3.new(0.3, 9, 7), CFrame.new(0, size.Y / 2 + 5, 1), 0.6)
	local bow = piece("Bow", Vector3.new(size.X * 0.6, size.Y * 0.8, size.Z * 0.3), CFrame.new(0, 0, -size.Z / 2), 0.6)
	for _, p in ipairs({ sail, bow }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, p
		weld.Parent = p
	end
	model.PrimaryPart = root
	model:SetAttribute("Phantom", true)
	model.Parent = refs and refs.folders.fx or workspace
	return model, root
end

local function phantom(boat, player)
	local spec = A.slip
	local t = now()
	local old = ghosts[player]
	if old and old.model then
		old.model:Destroy()
	end
	local velocity = flat(boat.hull.AssemblyLinearVelocity)
	if velocity.Magnitude < 40 then
		velocity = lookOf(boat) * 110 -- standing still, the ghost still runs
	end
	local model, root = ghostModel(boat)
	ghosts[player] = {
		model = model,
		root = root,
		at = boat.hull.Position,
		velocity = velocity,
		born = t,
		untilAt = t + spec.decoy,
	}
	Pursuit.decoy(player, boat.hull.Position, velocity, t + spec.decoy, spec.fool)
	return true
end

local function plow(boat, player)
	local spec = A.plow
	local t = now()
	boat.plowUntil = t + spec.time -- the server's own copy: Boats.shove reads it (the hull hardly moves)
	plows[boat] = { player = player, untilAt = t + spec.time, hit = {} }
	return true
end

local SERVER_PART = {
	nitro = nitro,
	rally = rally,
	volley = volley,
	twister = twister,
	slip = function(boat, player)
		BoatAbilities.breakFree(boat, "phantom") -- (V13.2) a Phantom slip shakes off a chain too
		return phantom(boat, player)
	end,
	plow = plow,
	anchor = anchor,
	breaker = breaker,
	hook = hook,
}

-- How much faster than its class the anti-cheat lets the hull go, and for how long.
local function allowance(boat, id)
	local spec = boat.spec
	local a = A[id]
	if id == "nitro" then
		return spec.maxSpeed * (a.mult - Config.BOAT_BOOST_MULT) + a.kick + 25, a.time + 2.5
	elseif id == "slip" then
		return a.side + 20, 1.6
	elseif id == "plow" then
		return spec.maxSpeed * (a.top - 1) + 35, a.time + 2
	elseif id == "spring" then
		return 45, 3
	elseif id == "rally" then
		return 30, A.rally.boost + 2.5
	elseif id == "breaker" then
		return a.surge + 25, a.boost + 2.5
	elseif id == "anchor" then
		return a.sling + 60, a.swing + 2.5 -- a swing whips round faster than the boat drives, then the sling
	elseif id == "hook" then
		return a.reel + 70, a.reelTime + 1.5
	end
	return 0, 0
end

-- The driver says their ability played (BoatAbilityRequest). aimPoint: where they were looking. info (V13.2, the anchor
-- and the hook): { target = the rival hull the client chose } (only believed if it passes the server's own tests).
function BoatAbilities.request(player, aimPoint, info)
	local t = now()
	if t - (lastRequest[player] or -math.huge) < 0.2 then
		return
	end
	lastRequest[player] = t
	if not finite(aimPoint) then
		aimPoint = nil
	end
	local boat = Boats.drivenBy(player)
	if not boat or boat.ai or boat.state ~= "float" then
		return
	end
	local id = boat.spec.ability
	local a = id and A[id]
	if not a then
		return
	end
	-- A little slack for the network: the client and server clocks agree only to a frame or two.
	if t < (boat.abilityServerReadyAt or 0) - 0.25 then
		refuse(player, nil)
		return
	end
	if type(info) ~= "table" then
		info = nil
	end
	local fn = SERVER_PART[id]
	if fn then
		local ok, reason = fn(boat, player, aimPoint, info)
		if not ok then
			refuse(player, reason)
			return
		end
	end
	boat.abilityServerReadyAt = t + a.cooldown
	boat.model:SetAttribute("AbilityReadyAt", boat.abilityServerReadyAt)
	local extra, seconds = allowance(boat, id)
	if extra > 0 then
		boat.abilityAllow = extra
		boat.abilityAllowUntil = t + seconds
	end
	-- A burst of speed is not a crash.
	boat.impactGraceUntil = math.max(boat.impactGraceUntil or 0, t + 0.5)
	if boat.pilot == nil then
		boat.abilityQueued = true -- the server simulates this hull: it plays the physical part itself
	end
	Net.broadcast("BoatFx", { kind = "ability", ability = id, position = boat.hull.Position, userId = player.UserId })
	BoatAbilities.Used:Fire(player, id, boat)
end

-- V13.2: the driver's own chain let go (R again: the sling; it arrived; it timed out on their client).
function BoatAbilities.released(player, kind)
	local boat = Boats.drivenBy(player)
	if not boat then
		return
	end
	for _, chain in ipairs(chainsOn(boat)) do
		if chain.boat == boat then
			endChain(chain, kind == "arrived" and "arrived" or "released")
		end
	end
	if kind == "sling" then
		boat.abilityAllow = A.anchor.sling + 60
		boat.abilityAllowUntil = now() + 2.5
	end
end

-- Each frame: the ghosts run on, the plows hit what is in front of them, the chains hold or break.
local function tick(dt)
	local t = now()
	tickChains(t)
	for player, g in pairs(ghosts) do
		if t >= g.untilAt or not g.model.Parent then
			g.model:Destroy()
			ghosts[player] = nil
		else
			g.at = g.at + g.velocity * dt
			local k = (t - g.born) / (g.untilAt - g.born)
			g.root.CFrame = CFrame.lookAt(g.at, g.at + g.velocity)
			for _, p in ipairs(g.model:GetChildren()) do
				if p:IsA("BasePart") then
					p.Transparency = 0.5 + 0.45 * k
				end
			end
			Pursuit.moveDecoy(player, g.at, g.velocity)
		end
	end
	local spec = A.plow
	for boat, p in pairs(plows) do
		if t >= p.untilAt or boat.state ~= "float" or not boat.model.Parent then
			plows[boat] = nil
		else
			local hull = boat.hull
			local look = lookOf(boat)
			local bow = hull.Position + look * (boat.spec.size.Z / 2 + spec.reach * 0.5)
			for _, other in ipairs(Boats.list) do
				if other ~= boat and other.state == "float" and not p.hit[other] then
					local reach = other.spec.size.Z * 0.45 + spec.reach + 4
					if flat(other.hull.Position - bow).Magnitude < reach then
						p.hit[other] = true
						local away = flat(other.hull.Position - hull.Position)
						away = away.Magnitude > 0.1 and away.Unit or look
						local shove = (away * 0.6 + look * 0.4).Unit * spec.shove + Vector3.new(0, 32, 0)
						Boats.shove(other, shove, Vector3.new(0, (away:Cross(look).Y > 0 and 1 or -1) * 1.6, 0))
						Net.broadcastNear(
							other.hull.Position,
							900,
							"BoatImpact",
							{ position = other.hull.Position, power = 1 }
						)
					end
				end
			end
			local moved = Pursuit.shoveAt(bow, spec.reach + 10, 110, look)
			if moved > 0 then
				p.hit.pursuers = (p.hit.pursuers or 0) + moved
			end
		end
	end
end

function BoatAbilities.init(worldRefs)
	refs = worldRefs
	RunService.Heartbeat:Connect(tick)
end

function BoatAbilities.forget(player)
	lastRequest[player] = nil
	local g = ghosts[player]
	if g then
		g.model:Destroy()
		ghosts[player] = nil
	end
	for boat, p in pairs(plows) do
		if p.player == player then
			plows[boat] = nil
		end
	end
	for _, chain in pairs(chains) do
		if chain.player == player then
			endChain(chain, "left")
		end
	end
end

function BoatAbilities.reset()
	for player in pairs(ghosts) do
		BoatAbilities.forget(player)
	end
	table.clear(plows)
	for _, chain in pairs(chains) do
		endChain(chain, "reset")
	end
end

-- For tests and the playtest hook: the chains holding now.
function BoatAbilities.chains()
	local list = {}
	for _, chain in pairs(chains) do
		table.insert(
			list,
			{ id = chain.id, kind = chain.kind, boat = chain.boat, target = chain.target, untilAt = chain.untilAt }
		)
	end
	return list
end

-- For the Port's screen and tests: is anyone's ghost running.
function BoatAbilities.ghostOf(player)
	return ghosts[player]
end

return BoatAbilities

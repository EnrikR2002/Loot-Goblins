-- Boat abilities (V13): one per class, on the stunt key while the hull is on the water (Config.BOAT_ABILITIES).
--
-- The physical part (Nitro's burst, the Reefhopper's spring, the Wraith's sideways slip, the Ironbelly's charge) is
-- played by shared/BoatSim.lua on whichever machine simulates the hull, so it answers the frame the key is pressed;
-- the driver's client tells the server it played (BoatAbilityRequest, with where the driver is looking). This module:
--   * owns the cooldown (the boat's AbilityReadyAt attribute) and refuses a request that comes too soon;
--   * tells the anti-cheat (Boats.police) how much extra speed the ability is allowed;
--   * does everything the server owns:
--       Cutter       BOW GUN    the bow cannon fires the light boat shot (Config.BOAT_SHOT) where the driver looks
--       Broadside    BROADSIDE  three shots from the gun on the side the driver looks to
--       Stormrunner  TWISTER    a real, short tornado spins up in its wake (Tornadoes.summon)
--       Wraith       PHANTOM    a ghost of the boat runs on along the old course; pursuers chase it (Pursuit.decoy)
--       Ironbelly    RAM PLOW   for its length, boats it runs into are shoved aside and pursuers thrown off
-- Fair play: shots from a goblin's boat never reach someone at home (the Hoard's ward) or in the Port; nothing here
-- does lasting damage to a rival beyond a cannon's ordinary hull damage; every ability has a cooldown and a tell.
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

local BoatAbilities = {}
BoatAbilities.Used = Util.signal() -- (player, abilityId, boat): for progress (server/Progress.lua counts some)

local A = Config.BOAT_ABILITIES
local refs
local lastRequest = {} -- player -> time
local ghosts = {} -- player -> { model, root, at, velocity, untilAt, born }
local plows = {} -- boat -> { player, untilAt, hit = { [boat] = true } }

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

-- The Cutter's bow gun: anywhere ahead of the bow (within 70 degrees), up to 420 studs.
local function bowGun(boat, player, aim)
	local entry = Cannons.boatGun(boat, nil)
	if not entry then
		return false, "This boat has no bow gun."
	end
	local look = lookOf(boat)
	local from = boat.hull.Position
	local toward = aim and flat(aim - from) or Vector3.zero
	if toward.Magnitude < 20 or toward.Unit:Dot(look) < 0.34 then
		aim = from + look * 220
	elseif toward.Magnitude > 420 then
		aim = from + toward.Unit * 420
	end
	Cannons.launch(entry, Vector3.new(aim.X, math.max(aim.Y, 0), aim.Z), player, Config.BOAT_SHOT)
	return true
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
	chaser = bowGun,
	volley = volley,
	twister = twister,
	slip = phantom,
	plow = plow,
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
	end
	return 0, 0
end

-- The driver says their ability played (BoatAbilityRequest). aimPoint: where they were looking.
function BoatAbilities.request(player, aimPoint)
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
	local fn = SERVER_PART[id]
	if fn then
		local ok, reason = fn(boat, player, aimPoint)
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

-- Each frame: the ghosts run on, the plows hit what is in front of them.
local function tick(dt)
	local t = now()
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
end

function BoatAbilities.reset()
	for player in pairs(ghosts) do
		BoatAbilities.forget(player)
	end
	table.clear(plows)
end

-- For the Port's screen and tests: is anyone's ghost running.
function BoatAbilities.ghostOf(player)
	return ghosts[player]
end

return BoatAbilities

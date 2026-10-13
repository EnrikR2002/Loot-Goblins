-- Sword and grapple: how players interfere with each other.
--
-- Sword (everyone spawns with one): click to swing. A hit on a carrier knocks
-- their loot loose. A carrier's own swing is a slow, short, tiring bash.
-- Grapple (F): one hook, three jobs.
--   * Aimed at LOOSE loot (aim is forgiving): grab it, if nothing solid is in the way.
--   * Aimed at a CARRIER within GRAPPLE_PVP_RANGE (V7): catch them. They are yanked toward you and
--     fall for CATCH_DOWN_TIME. Nothing is stolen: you run up and press E (Combat.stealFrom, within
--     STEAL_RANGE, on a goblin who is down). Cover and tunnels still protect carriers.
--   * Aimed anywhere else: hook the first solid thing along your aim and the
--     client reels you in. Cliffs, masts, the beach, or a boat: a hook on something
--     that moves follows it, and from a boat seat it yanks you out of the seat.
-- Carriers can't steal with it (hands full) but can still pull themselves about,
-- on a longer cooldown: an escape tool, not a free ride home.
-- A miss (nothing in range) costs no cooldown.
--
-- The server picks every target and anchor. The client only sends its aim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Movement = require(script.Parent.Movement)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Boats = require(script.Parent.Boats)

local Combat = {}
local refs
local lastSwing = {}
local lastGrapple = {}
local stealReadyAt = {} -- thief -> time
local downToken = {} -- victim -> counter: a stale stand-up timer must not stand someone up twice
local boatHook = {} -- player -> { boat, at }: the boat their hook just caught.
local GUARD_OFFSET = CFrame.new(0, 0, -1)
local GRAPPLE_SPAM_GAP = 0.25 -- Misses are free, so ignore requests faster than this.

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true
losParams.IgnoreWater = true

local HOOK_MIN_Y = -1 -- Hooks below this hit the sea floor, which is no use to anyone.

-- Sword -----------------------------------------------------------------------
local function swing(player, tool)
	local _, humanoid, root = Util.getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return
	end
	local t = os.clock()
	-- Loot-carrying hands swing too, but heavy: slower, shorter, weaker, and it costs stamina.
	local carrying = Loot.itemOf(player) ~= nil
	local cooldown = carrying and Config.CARRY_SWORD_COOLDOWN or Config.SWORD_COOLDOWN
	if t - (lastSwing[player] or 0) < cooldown then
		return
	end
	if carrying and not Movement.spend(player, Config.CARRY_SWING_STAMINA) then
		Net.toast(player, "Too winded to swing - heavy loot takes stamina")
		return
	end
	lastSwing[player] = t
	local range = carrying and Config.CARRY_SWORD_RANGE or Config.SWORD_RANGE
	local damage = carrying and Config.CARRY_SWORD_DAMAGE or Config.SWORD_DAMAGE
	local knockback = carrying and Config.CARRY_SWORD_KNOCKBACK or Config.SWORD_KNOCKBACK

	-- Roblox's default animate script plays a slash when it sees this value.
	local slash = Instance.new("StringValue")
	slash.Name = "toolanim"
	slash.Value = "Slash"
	slash.Parent = tool
	Debris:AddItem(slash, 1)

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local hits = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot, otherHumanoid = Util.aliveRoot(other)
		if other ~= player and otherRoot then
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if offset.Magnitude <= range and flat.Magnitude > 0.01 and flat.Unit:Dot(look) >= Config.SWORD_MIN_DOT then
				local dealt = Util.damage(otherHumanoid, damage)
				Poltergoblin.markDamage(player, otherHumanoid, dealt)
				Loot.knockLoose(other, root.Position, "sword", player)
				Util.knockback(otherRoot, flat.Unit * knockback + Vector3.new(0, 15, 0))
				table.insert(hits, otherRoot.Position)
			end
		end
	end
	Poltergoblin.strikeBodies(player, root.Position, look, damage)
	if #hits > 0 then
		Net.broadcast("SwordHit", { hits = hits })
	end
end

-- Metal is dense: a real-weight sword outweighs a goblin's buoyancy and drags an idle swimmer
-- to the sea floor. The blade only looks like metal.
local LIGHT = PhysicalProperties.new(0.3, 0.3, 0.5)

local function makeSwordParts(parent)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 4.5)
	handle.Color = Color3.fromRGB(205, 210, 220)
	handle.Material = Enum.Material.Metal
	handle.CustomPhysicalProperties = LIGHT
	handle.Parent = parent

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(2, 0.5, 0.5)
	guard.Color = Color3.fromRGB(255, 200, 35)
	guard.Material = Enum.Material.Metal
	guard.CustomPhysicalProperties = LIGHT
	guard.Parent = parent
	return handle, guard
end

local function newSwordTool()
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.ToolTip = "Click to swing. Knocks loot loose. Carrying loot makes it a slow, tiring bash."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- Same grip as Roblox's classic sword: the blade points forward from the fist.
	tool.GripPos = Vector3.new(0, 0, -1.5)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	local handle, guard = makeSwordParts(tool)
	handle.CanCollide = false
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = handle.CFrame * GUARD_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = guard
	weld.Parent = guard

	tool.Activated:Connect(function()
		local owner = Players:GetPlayerFromCharacter(tool.Parent)
		if owner then
			swing(owner, tool)
		end
	end)
	return tool
end

-- Everyone gets a sword on spawn, already in hand.
function Combat.giveSword(player, character)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Sword") or character:FindFirstChild("Sword") then
		return
	end
	local tool = newSwordTool()
	tool.Parent = backpack
	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and character.Parent and tool.Parent == backpack then
			humanoid:EquipTool(tool)
		end
	end)
end

-- Grapple ---------------------------------------------------------------------
local function itemFromPart(part)
	for _, item in ipairs(Loot.items) do
		if part:IsDescendantOf(item.model) then
			return item
		end
	end
	return nil
end

-- Everything a hook or a line of sight passes through: people, loot, effects.
local function ignoreList()
	local ignore = { refs.folders.loot, refs.folders.bodies, refs.folders.fx, refs.folders.threats, refs.folders.decor }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	return ignore
end

-- Nothing solid between the two points.
local function clearLine(from, to, ignore)
	losParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, losParams)
	return hit == nil or (hit.Position - to).Magnitude < 2
end

local function stealable(item, player)
	return (item.state == "loose" or item.state == "carried") and item.carrier ~= player
end

-- The loot the hook goes for: what you clicked, else the loose or carried loot
-- closest to your aim line (its carrier's body counts too).
local function stealTarget(player, origin, aim, target)
	if target and target:IsA("BasePart") then
		local item = itemFromPart(target)
		if not item then
			local targetPlayer = Util.playerFromPart(target)
			if targetPlayer and targetPlayer ~= player then
				item = Loot.itemOf(targetPlayer)
			end
		end
		if item and stealable(item, player) then
			return item
		end
	end
	local best, bestOff = nil, Config.GRAPPLE_AIM_ASSIST
	for _, item in ipairs(Loot.items) do
		if stealable(item, player) then
			local points = { item.core.Position }
			local carrierRoot = item.carrier and Util.aliveRoot(item.carrier)
			if carrierRoot then
				table.insert(points, carrierRoot.Position)
			end
			for _, point in ipairs(points) do
				local offset = point - origin
				local along = offset:Dot(aim)
				if along > 0 and offset.Magnitude <= Config.GRAPPLE_RANGE then
					local off = (offset - aim * along).Magnitude
					if off < bestOff then
						best, bestOff = item, off
					end
				end
			end
		end
	end
	return best
end

local function setCooldown(player, seconds)
	player:SetAttribute("GrappleReadyAt", workspace:GetServerTimeNow() + seconds)
	player:SetAttribute("GrappleCooldown", seconds)
end

-- Caught and stealing (V7) ------------------------------------------------------------------
local function inWard(position)
	return Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS
end

-- Gets a goblin back on their feet and (for a while) uncatchable. Safe to call twice.
function Combat.standUp(victim, immunity)
	downToken[victim] = (downToken[victim] or 0) + 1
	local _, humanoid = Util.getCharacterParts(victim)
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	victim:SetAttribute("DownedUntil", nil)
	victim:SetAttribute("DownedBy", nil)
	if immunity and immunity > 0 then
		victim:SetAttribute("CatchImmuneUntil", workspace:GetServerTimeNow() + immunity)
	end
end

local function knockDown(victim, humanoid, root, attacker, attackerRoot)
	local t = workspace:GetServerTimeNow()
	local token = (downToken[victim] or 0) + 1
	downToken[victim] = token
	victim:SetAttribute("DownedUntil", t + Config.CATCH_DOWN_TIME)
	victim:SetAttribute("DownedAt", t)
	victim:SetAttribute("DownedBy", attacker.UserId)
	humanoid.PlatformStand = true
	Movement.setSprintHeld(victim, false)
	local toward = attackerRoot.Position - root.Position
	toward = Vector3.new(toward.X, 0, toward.Z)
	toward = toward.Magnitude > 1 and toward.Unit or Vector3.zero
	-- A yank, but never past the thrower: stop a stride short.
	local gap = math.max(0, (attackerRoot.Position - root.Position).Magnitude - 4)
	local speed = math.min(Config.CATCH_PULL_SPEED, gap / 0.25)
	Util.knockback(root, toward * speed + Vector3.new(0, 16, 0), 0.25)
	Net.toast(victim, "CAUGHT by " .. attacker.DisplayName .. "! Space to get up.")
	task.delay(Config.CATCH_DOWN_TIME, function()
		if downToken[victim] == token and victim.Parent then
			Combat.standUp(victim, Config.CATCH_IMMUNITY)
		end
	end)
end

-- The hook found a carrier. Returns true when the throw is spent (caught, or refused with a reason).
function Combat.catch(attacker, victim, origin)
	local t = workspace:GetServerTimeNow()
	local attackerRoot = Util.aliveRoot(attacker)
	local root, humanoid = Util.aliveRoot(victim)
	if not attackerRoot or not root or humanoid.SeatPart then
		return false -- a goblin in a boat is hooked as the boat
	end
	if inWard(root.Position) then
		Net.toast(attacker, "The Hoard's ward protects them.")
		setCooldown(attacker, Config.GRAPPLE_FAIL_COOLDOWN)
		return true
	end
	if t < (victim:GetAttribute("DownedUntil") or 0) then
		Net.toast(attacker, "They are already down: run up and press E.")
		return true
	end
	if t < (victim:GetAttribute("CatchImmuneUntil") or 0) then
		Net.toast(attacker, "They only just got up: the hook slips off.")
		setCooldown(attacker, Config.GRAPPLE_FAIL_COOLDOWN)
		return true
	end
	knockDown(victim, humanoid, root, attacker, attackerRoot)
	setCooldown(attacker, Config.CATCH_COOLDOWN)
	Net.broadcast("GrappleFX", {
		kind = "catch",
		from = origin,
		to = root.Position,
		userId = attacker.UserId,
		victim = victim.UserId,
	})
	return true
end

-- E on a goblin who is down, from close by. Everything is checked here: who, how far, what is in
-- the way, what they hold. The client only says who it is looking at.
function Combat.stealFrom(thief, victim)
	if typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim == thief then
		return
	end
	local t = workspace:GetServerTimeNow()
	if t < (stealReadyAt[thief] or 0) then
		return
	end
	stealReadyAt[thief] = t + Config.STEAL_COOLDOWN
	local thiefRoot, thiefHumanoid = Util.aliveRoot(thief)
	local victimRoot = Util.aliveRoot(victim)
	if not thiefRoot or not victimRoot or thiefHumanoid.SeatPart or Poltergoblin.isSpirit(thief) then
		return
	end
	local item = Loot.itemOf(victim)
	if not item or Loot.itemOf(thief) then
		return
	end
	if t >= (victim:GetAttribute("DownedUntil") or 0) then
		Net.toast(thief, "They are on their feet. Catch them with F first.")
		return
	end
	if (victimRoot.Position - thiefRoot.Position).Magnitude > Config.STEAL_RANGE then
		Net.toast(thief, "Too far. Get right up to them.")
		return
	end
	if not clearLine(thiefRoot.Position + Vector3.new(0, 1.5, 0), victimRoot.Position, ignoreList()) then
		return -- a wall between you
	end
	if not Loot.steal(item, thief) then
		Net.toast(thief, "It slipped off: loot cannot be taken right after it changes hands.")
		return
	end
	Combat.standUp(victim, Config.CATCH_IMMUNITY * 0.6)
	Net.broadcast("GrappleFX", {
		kind = "steal",
		from = thiefRoot.Position,
		to = victimRoot.Position,
		success = true,
		userId = thief.UserId,
	})
end

-- Space while down, once CATCH_MIN_DOWN has passed.
function Combat.getUp(player)
	local t = workspace:GetServerTimeNow()
	local until_ = player:GetAttribute("DownedUntil")
	if until_ and t >= until_ - Config.CATCH_DOWN_TIME + Config.CATCH_MIN_DOWN then
		Combat.standUp(player, Config.CATCH_IMMUNITY * 0.6)
	end
end

function Combat.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		Combat.standUp(player, 0)
		player:SetAttribute("CatchImmuneUntil", nil)
	end
	table.clear(stealReadyAt)
end

local function grapple(player, hitPosition, target)
	if typeof(hitPosition) ~= "Vector3" or (target ~= nil and typeof(target) ~= "Instance") then
		return
	end
	local _, humanoid, root = Util.getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return
	end
	local t = workspace:GetServerTimeNow()
	if t - (lastGrapple[player] or -math.huge) < GRAPPLE_SPAM_GAP then
		return
	end
	lastGrapple[player] = t
	if t < (player:GetAttribute("GrappleReadyAt") or 0) then
		return
	end
	local carrying = Loot.itemOf(player) ~= nil
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = hitPosition - origin
	aim = aim.Magnitude > 0.01 and aim.Unit or root.CFrame.LookVector
	local ignore = ignoreList()

	-- 1. Loose loot near the aim, in range, with nothing solid in between, is grabbed. A carrier is
	-- caught (and only when close). Full hands can do neither.
	local item = not carrying and stealTarget(player, origin, aim, target) or nil
	if item and item.state == "carried" and item.carrier then
		local victimRoot = Util.aliveRoot(item.carrier)
		if
			victimRoot
			and (victimRoot.Position - origin).Magnitude <= Config.GRAPPLE_PVP_RANGE
			and clearLine(origin, victimRoot.Position, ignore)
			and Combat.catch(player, item.carrier, origin)
		then
			return
		end
		item = nil -- too far, or behind cover: the hook flies on to whatever is in the way
	end
	if item then
		local targetPos = item.core.Position
		if (targetPos - origin).Magnitude <= Config.GRAPPLE_RANGE and clearLine(origin, targetPos, ignore) then
			local success = Loot.steal(item, player)
			setCooldown(player, success and Config.GRAPPLE_COOLDOWN or Config.GRAPPLE_FAIL_COOLDOWN)
			if not success then
				Net.toast(player, "It slipped off - loot can't be grabbed right after it changes hands")
			end
			Net.broadcast("GrappleFX", {
				kind = "steal",
				from = origin,
				to = targetPos,
				success = success,
				userId = player.UserId,
			})
			return
		end
		-- Blocked: the hook flies on and catches whatever is in the way.
	end

	-- 2. Pull: hook the first solid thing along the aim and reel in. From a boat seat the hook
	-- yanks you out of it, so never hook the boat you are sitting in.
	local seat = humanoid.SeatPart
	if seat then
		table.insert(ignore, seat:FindFirstAncestorOfClass("Model") or seat)
	end
	losParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, aim * Config.GRAPPLE_PULL_RANGE, losParams)
	-- A fast boat is not where the player sees it (what they aim at is a moment old), so a
	-- hook thrown at a passing boat would fly behind its stern. Aim that passes close to a
	-- MOVING boat catches the boat, unless something solid is nearer. (A parked boat needs no
	-- help, and must not steal a hook meant for the cliff behind it.)
	local own = seat and Boats.boatOf(seat) or nil
	local nearBoat, nearOff = nil, Config.GRAPPLE_BOAT_ASSIST
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" and boat ~= own and boat.hull.AssemblyLinearVelocity.Magnitude > 12 then
			local offset = boat.hull.Position - origin
			local along = offset:Dot(aim)
			if along > 0 and offset.Magnitude <= Config.GRAPPLE_PULL_RANGE then
				local off = (offset - aim * along).Magnitude
				if off < nearOff then
					nearBoat, nearOff = boat, off
				end
			end
		end
	end
	if nearBoat then
		local toBoat = nearBoat.hull.Position - origin
		local direct = workspace:Raycast(origin, toBoat, losParams)
		local reached = direct and direct.Instance:IsDescendantOf(nearBoat.model)
		local nothingNearer = not hit
			or hit.Position.Y < HOOK_MIN_Y
			or (hit.Position - origin).Magnitude > toBoat.Magnitude
		if reached and (nothingNearer or hit.Instance:IsDescendantOf(nearBoat.model)) then
			hit = direct
		end
	end
	if not hit or hit.Position.Y < HOOK_MIN_Y then
		local reach = hit and (hit.Position - origin).Magnitude or Config.GRAPPLE_PULL_RANGE
		Net.send(
			player,
			"GrappleFX",
			{ kind = "miss", from = origin, to = origin + aim * reach, userId = player.UserId }
		)
		Net.toast(
			player,
			string.format("Nothing to hook - aim at ground, walls or loot within %d studs", Config.GRAPPLE_PULL_RANGE)
		)
		return
	end
	setCooldown(player, carrying and Config.GRAPPLE_CARRY_COOLDOWN or Config.GRAPPLE_PULL_COOLDOWN)
	if seat then
		local seatWeld = seat:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
		humanoid.Sit = false
	end
	local distance = (hit.Position - origin).Magnitude
	-- Something that moves (a boat): the client keeps the rope on the part, not on the spot.
	local moving = not hit.Instance.Anchored and hit.Instance ~= workspace.Terrain
	-- Remember a hook on a boat for a moment: the client asks for a seat when the pull arrives
	-- (Combat.hookedBoat), and by then a fast boat is too far from where the server last saw
	-- the player for an ordinary "are you beside it" check.
	local hooked = Boats.boatOf(hit.Instance)
	boatHook[player] = hooked and not hooked.ai and { boat = hooked, at = t } or nil
	Net.broadcast("GrappleFX", {
		kind = "pull",
		from = origin,
		to = hit.Position,
		normal = hit.Normal,
		part = moving and hit.Instance or nil,
		offset = moving and hit.Instance.CFrame:PointToObjectSpace(hit.Position) or nil,
		userId = player.UserId,
		duration = distance / Config.GRAPPLE_PULL_SPEED + 0.6,
	})
end

function Combat.init(worldRefs)
	refs = worldRefs
	Net.Grapple.OnServerEvent:Connect(grapple)
end

-- The boat this player's hook caught in the last few seconds, if any (asked once).
function Combat.hookedBoat(player)
	local hook = boatHook[player]
	boatHook[player] = nil
	if hook and workspace:GetServerTimeNow() - hook.at < 4 then
		return hook.boat
	end
	return nil
end

function Combat.forget(player)
	boatHook[player] = nil
	lastSwing[player] = nil
	lastGrapple[player] = nil
	stealReadyAt[player] = nil
	downToken[player] = nil
end

return Combat

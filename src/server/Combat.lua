-- Sword and grapple: how players interfere with each other.
--
-- Sword (everyone spawns with one): click to swing. A hit on a carrier knocks
-- their loot loose. Carriers can't swing; their hands are full.
-- Grapple (F): one hook, two jobs.
--   * Aimed at loot or near a carrier (aim is forgiving): steal it, if nothing
--     solid is in the way. Cover and tunnels still protect carriers.
--   * Aimed anywhere else: hook the first solid thing along your aim and the
--     client reels you in. Great for cliffs, masts and getting off the beach.
-- Carriers can't grapple at all (hands full), so it never carries loot home.
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

local Combat = {}
local refs
local lastSwing = {}
local lastGrapple = {}
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

local function makeSwordParts(parent)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 4.5)
	handle.Color = Color3.fromRGB(205, 210, 220)
	handle.Material = Enum.Material.Metal
	handle.Parent = parent

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(2, 0.5, 0.5)
	guard.Color = Color3.fromRGB(255, 200, 35)
	guard.Material = Enum.Material.Metal
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
	if Loot.itemOf(player) then
		Net.toast(player, "HANDS FULL - Q to throw your loot, then grapple")
		return
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = hitPosition - origin
	aim = aim.Magnitude > 0.01 and aim.Unit or root.CFrame.LookVector
	local ignore = ignoreList()

	-- 1. Steal: loot near the aim, in range, with nothing solid in between.
	local item = stealTarget(player, origin, aim, target)
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

	-- 2. Pull: hook the first solid thing along the aim and reel in.
	if humanoid.SeatPart then
		Net.toast(player, "Stand up first - you can only grapple-pull on foot")
		return
	end
	losParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, aim * Config.GRAPPLE_PULL_RANGE, losParams)
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
	setCooldown(player, Config.GRAPPLE_PULL_COOLDOWN)
	local distance = (hit.Position - origin).Magnitude
	Net.broadcast("GrappleFX", {
		kind = "pull",
		from = origin,
		to = hit.Position,
		normal = hit.Normal,
		userId = player.UserId,
		duration = distance / Config.GRAPPLE_PULL_SPEED + 0.6,
	})
end

function Combat.init(worldRefs)
	refs = worldRefs
	Net.Grapple.OnServerEvent:Connect(grapple)
end

function Combat.forget(player)
	lastSwing[player] = nil
	lastGrapple[player] = nil
end

return Combat

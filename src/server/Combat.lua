-- Sword and grapple: how players interfere with each other.
--
-- Sword (everyone spawns with one): click to swing. A hit on a carrier knocks
-- their loot loose. Carriers can't swing; their hands are full.
-- Grapple (F): from range, steal loot from a carrier or yank loose loot to you.
-- It needs a clear line of sight, so cover and tunnels protect carriers.
--
-- The server picks every target. The client never says who it hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Poltergoblin = require(script.Parent.Poltergoblin)

local Combat = {}
local refs
local lastSwing = {}
local GUARD_OFFSET = CFrame.new(0, 0, -1)

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true
losParams.IgnoreWater = true

-- Sword -----------------------------------------------------------------------
local function swing(player, tool)
	local _, humanoid, root = Util.getCharacterParts(player)
	if not root or humanoid.Health <= 0 then
		return
	end
	local t = os.clock()
	if t - (lastSwing[player] or 0) < Config.SWORD_COOLDOWN then
		return
	end
	if Loot.itemOf(player) then
		Net.toast(player, "HANDS FULL - Q to throw the loot, then fight")
		return
	end
	lastSwing[player] = t

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
			if
				offset.Magnitude <= Config.SWORD_RANGE
				and flat.Magnitude > 0.01
				and flat.Unit:Dot(look) >= Config.SWORD_MIN_DOT
			then
				local dealt = Util.damage(otherHumanoid, Config.SWORD_DAMAGE)
				Poltergoblin.markDamage(player, otherHumanoid, dealt)
				Loot.knockLoose(other, root.Position, "sword", player)
				Util.knockback(otherRoot, flat.Unit * Config.SWORD_KNOCKBACK + Vector3.new(0, 15, 0))
				table.insert(hits, otherRoot.Position)
			end
		end
	end
	Poltergoblin.strikeBodies(player, root.Position, look, Config.SWORD_DAMAGE)
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
	tool.ToolTip = "Click to swing. Knocks loot loose."
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

-- Nothing solid between the two points (characters and loot don't count).
local function clearLine(from, to, ignore)
	losParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, losParams)
	return hit == nil or (hit.Position - to).Magnitude < 2
end

local function grapple(player, hitPosition, target)
	if typeof(hitPosition) ~= "Vector3" or (target ~= nil and typeof(target) ~= "Instance") then
		return
	end
	local character, _, root = Util.getCharacterParts(player)
	if not root or not Util.aliveRoot(player) then
		return
	end
	local t = workspace:GetServerTimeNow()
	if t < (player:GetAttribute("GrappleReadyAt") or 0) then
		return
	end
	player:SetAttribute("GrappleReadyAt", t + Config.GRAPPLE_COOLDOWN)

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = hitPosition - origin
	local missEnd = origin
		+ (aim.Magnitude > 0.01 and aim.Unit or root.CFrame.LookVector)
			* math.min(aim.Magnitude, Config.GRAPPLE_RANGE)

	-- Aiming at loot (carried or loose) or at a carrier.
	local item, holder = nil, nil
	if target and target:IsA("BasePart") then
		item = itemFromPart(target)
		if not item then
			local targetPlayer = Util.playerFromPart(target)
			if targetPlayer and targetPlayer ~= player then
				item = Loot.itemOf(targetPlayer)
			end
		end
		holder = item and item.carrier
	end

	local success = false
	local to = missEnd
	if item and holder ~= player and (item.state == "loose" or item.state == "carried") then
		local targetPos = item.core.Position
		local ignore = { character, refs.folders.loot, refs.folders.bodies, refs.folders.fx, refs.folders.threats }
		if holder and holder.Character then
			table.insert(ignore, holder.Character)
		end
		if (targetPos - origin).Magnitude <= Config.GRAPPLE_RANGE then
			to = targetPos
			if clearLine(origin, targetPos, ignore) then
				success = Loot.steal(item, player)
			else
				Net.toast(player, "No clear line - grapple blocked")
			end
		end
	end
	Net.broadcast("GrappleFX", { from = origin, to = to, success = success })
end

function Combat.init(worldRefs)
	refs = worldRefs
	Net.Grapple.OnServerEvent:Connect(grapple)
end

function Combat.forget(player)
	lastSwing[player] = nil
end

return Combat

-- Powder kegs: the pocket interference tool. Take up to KEG_MAX from a keg crate (hold E),
-- press G to lob one where you aim. It lands, sizzles for KEG_FUSE seconds and blasts:
-- people are thrown, loot is knocked loose, cracked walls and gates open, boats are shoved and
-- holed, and powder barrels nearby go up with it. Kegs float, so a keg rolled onto a boat's deck
-- or left in the water is a trap, and a keg at your own feet is a launcher (you take the shove,
-- never the damage).
--
-- The client sends only the aim point. The server owns the count, the throw, the fuse and the blast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Blast = require(script.Parent.Blast)

local Kegs = {}

local live = {} -- { part, explodeAt, owner, nextFlash }
local lastThrow = {}
local refs

local function now()
	return workspace:GetServerTimeNow()
end

local function count(player)
	return player:GetAttribute("Kegs") or 0
end

function Kegs.give(player)
	local have = count(player)
	if have >= Config.KEG_MAX then
		Net.toast(player, "You're carrying all the kegs you can")
		return
	end
	player:SetAttribute("Kegs", have + 1)
	Net.toast(player, string.format("Powder keg! %d/%d - G to throw", have + 1, Config.KEG_MAX))
end

function Kegs.throw(player, aimPoint)
	if
		typeof(aimPoint) ~= "Vector3"
		or aimPoint.X ~= aimPoint.X
		or aimPoint.Y ~= aimPoint.Y
		or aimPoint.Z ~= aimPoint.Z
	then
		return
	end
	local root = Util.aliveRoot(player)
	if not root or count(player) <= 0 then
		return
	end
	local t = now()
	if t - (lastThrow[player] or -math.huge) < Config.KEG_THROW_GAP then
		return
	end
	lastThrow[player] = t
	player:SetAttribute("Kegs", count(player) - 1)

	local origin = root.Position + Vector3.new(0, 2.5, 0) + root.CFrame.LookVector * 2
	local delta = aimPoint - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = math.clamp(flat.Magnitude, 6, Config.KEG_RANGE)
	local direction = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
	-- A 45 degree lob: speed that carries `distance` under normal gravity.
	local speed = math.sqrt(workspace.Gravity * distance)
	local velocity = direction * speed * 0.7071 + Vector3.new(0, speed * 0.7071, 0)

	local keg = Instance.new("Part")
	keg.Name = "LitKeg"
	keg.Size = Vector3.new(2.6, 3, 2.6)
	keg.Shape = Enum.PartType.Cylinder
	keg.Color = Color3.fromRGB(110, 70, 40)
	keg.Material = Enum.Material.Wood
	keg.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.6, 0.3)
	keg.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.9, 0.9, 0.9)
	fuse.Shape = Enum.PartType.Ball
	fuse.Color = Color3.fromRGB(255, 80, 40)
	fuse.Material = Enum.Material.Neon
	fuse.CanCollide = false
	fuse.Massless = true
	fuse.CFrame = keg.CFrame * CFrame.new(1.7, 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = keg, fuse
	weld.Parent = fuse
	fuse.Parent = keg
	local spark = Instance.new("ParticleEmitter")
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
	spark.LightEmission = 1
	spark.Rate = 40
	spark.Lifetime = NumberRange.new(0.3, 0.5)
	spark.Speed = NumberRange.new(4, 9)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new(0.5, 0)
	spark.Parent = fuse
	keg.Parent = refs.folders.fx
	pcall(function()
		keg:SetNetworkOwner(nil)
	end)
	keg.AssemblyLinearVelocity = velocity
		+ Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) * 0.6
	keg.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
	table.insert(live, { part = keg, explodeAt = t + Config.KEG_FUSE, owner = player, nextFlash = 0, fuse = fuse })
	Net.broadcast("KegLit", { position = origin, userId = player.UserId })
end

function Kegs.tick()
	local t = now()
	for i = #live, 1, -1 do
		local keg = live[i]
		if not keg.part.Parent then
			table.remove(live, i)
		elseif t >= keg.explodeAt then
			local position = keg.part.Position
			keg.part:Destroy()
			table.remove(live, i)
			Blast.at(position, {
				radius = Config.KEG_RADIUS,
				damage = Config.KEG_DAMAGE,
				knockback = Config.KEG_KNOCKBACK,
				hullDamage = Config.KEG_HULL_DAMAGE,
				boatPush = Config.KEG_BOAT_PUSH,
				breakPower = 1,
				lootReason = "keg",
				owner = keg.owner,
				cause = keg.owner and (keg.owner.DisplayName .. "'s keg") or "a keg",
			})
		elseif t >= keg.nextFlash then
			-- Flashes faster as the fuse burns down.
			local left = keg.explodeAt - t
			keg.nextFlash = t + math.clamp(left * 0.18, 0.06, 0.3)
			keg.fuse.Color = keg.fuse.Color == Color3.fromRGB(255, 80, 40) and Color3.fromRGB(255, 240, 160)
				or Color3.fromRGB(255, 80, 40)
		end
	end
end

function Kegs.build(worldRefs)
	refs = worldRefs
	for _, crate in ipairs(refs.kegCrates) do
		local prompt = crate:FindFirstChild("KegPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				Kegs.give(player)
			end)
		end
	end
	Net.Keg.OnServerEvent:Connect(Kegs.throw)
end

function Kegs.refill(player)
	player:SetAttribute("Kegs", 0)
end

function Kegs.forget(player)
	lastThrow[player] = nil
end

function Kegs.reset()
	for _, keg in ipairs(live) do
		keg.part:Destroy()
	end
	table.clear(live)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Kegs", 0)
	end
end

return Kegs

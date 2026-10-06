-- Small helpers every server module uses.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Util = {}

function Util.getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	return character, humanoid, root
end

-- Returns the live root of a player who is alive, or nil.
function Util.aliveRoot(player)
	local _, humanoid, root = Util.getCharacterParts(player)
	if root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

function Util.playerFromPart(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

-- Anchored, smooth part. Most of the world is built with this.
function Util.part(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Horizontal distance, ignoring height.
function Util.flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Pushes a character. The client owns its own physics, so a short-lived
-- LinearVelocity (which replicates) is more reliable than writing velocity once.
function Util.knockback(root, velocity, duration)
	root.AssemblyLinearVelocity = velocity
	local attachment = Instance.new("Attachment")
	attachment.Name = "Knockback"
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = 1e6
	push.VectorVelocity = velocity
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Parent = attachment
	attachment.Parent = root
	Debris:AddItem(attachment, duration or 0.18)
end

-- Damage that goes through ForceFields like Humanoid:TakeDamage. Returns the
-- health actually removed, so Poltergoblin marks store real damage.
function Util.damage(humanoid, amount)
	local before = humanoid.Health
	humanoid:TakeDamage(amount)
	return before - humanoid.Health
end

-- A tiny signal: modules announce events without requiring each other.
function Util.signal()
	local listeners = {}
	local signal = {}
	function signal:Connect(fn)
		table.insert(listeners, fn)
	end
	function signal:Fire(...)
		for _, fn in ipairs(listeners) do
			fn(...)
		end
	end
	return signal
end

return Util

-- Things that break. A handful of structures on purpose, each one changing the route:
--
--   weak    cracked walls: any blast opens a shortcut (Smuggler's shed, Fort Barnacle's east wall)
--   gate    heavy gates: need a cannonball or two kegs (the Fort's south gate)
--   bridge  rope bridges that snap in one piece (Tangle Isle's canopy)
--   barrel  powder barrels: a blast sets them off, and they blast in turn (chain reactions)
--
-- The builders in World/Islands only describe breakables (refs.breakables, refs.barrels). A
-- broken structure becomes physics debris and is rebuilt from a stored copy when the raid resets.
local Debris = game:GetService("Debris")

local Net = require(script.Parent.Net)

local Destructibles = {}
Destructibles.explode = nil -- Blast.at, injected by Blast to avoid a require cycle.

local entries = {}
local refs

local function register(entry)
	entry.template = entry.model:Clone()
	entry.parent = entry.model.Parent
	entry.maxHealth = entry.health
	entry.broken = false
	table.insert(entries, entry)
end

function Destructibles.build(worldRefs)
	refs = worldRefs
	for _, entry in ipairs(refs.breakables) do
		register(entry)
	end
	for _, barrel in ipairs(refs.barrels) do
		register({ model = barrel, health = 1, kind = "barrel", label = "Powder barrel" })
	end
end

-- Distance from a point to the closest point of a model's bounding box.
local function distanceTo(model, position)
	local cframe, size = model:GetBoundingBox()
	local rel = cframe:PointToObjectSpace(position)
	local clamped = Vector3.new(
		math.clamp(rel.X, -size.X / 2, size.X / 2),
		math.clamp(rel.Y, -size.Y / 2, size.Y / 2),
		math.clamp(rel.Z, -size.Z / 2, size.Z / 2)
	)
	return (rel - clamped).Magnitude
end

local function shatter(entry)
	entry.broken = true
	local model = entry.model
	local center = model:GetBoundingBox().Position
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
			part.CanQuery = false
			local away = part.Position - center
			away = away.Magnitude > 0.1 and away.Unit or Vector3.yAxis
			part.AssemblyLinearVelocity = away * math.random(10, 26) + Vector3.new(0, math.random(8, 22), 0)
			part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				* 8
		elseif part:IsA("ProximityPrompt") then
			part.Enabled = false
		end
	end
	-- Out of the Ground/Structures folders at once, so rays and the Guardian stop treating it as solid.
	model.Parent = refs.folders.fx
	Debris:AddItem(model, 6)
	Net.broadcast("Broke", { position = center, label = entry.label, kind = entry.kind })
end

local function ignite(entry)
	entry.broken = true -- Claimed now, so a chain reaction can't light it twice.
	local position = entry.model.PrimaryPart and entry.model.PrimaryPart.Position
		or entry.model:GetBoundingBox().Position
	task.delay(0.22, function()
		entry.broken = false
		shatter(entry)
		if Destructibles.explode then
			Destructibles.explode(position, {
				radius = 15,
				damage = 34,
				knockback = 72,
				hullDamage = 60,
				boatPush = 55,
				breakPower = 1,
				lootReason = "boulder",
				cause = "a powder barrel",
			})
		end
	end)
end

-- A blast of this power went off here. power 1 = a keg or barrel, 2 = a cannonball.
function Destructibles.blastAt(position, radius, power)
	for _, entry in ipairs(entries) do
		if not entry.broken and entry.model.Parent then
			if distanceTo(entry.model, position) <= radius then
				if entry.kind == "barrel" then
					ignite(entry)
				elseif entry.kind == "gate" then
					entry.health -= power
					if entry.health <= 0 then
						shatter(entry)
					end
				elseif power >= 1 then
					shatter(entry)
				end
			end
		end
	end
end

-- Break every breakable of these kinds within radius (a quake, an eruption).
function Destructibles.breakNear(position, radius, kinds)
	for _, entry in ipairs(entries) do
		if not entry.broken and entry.model.Parent and kinds[entry.kind] then
			if distanceTo(entry.model, position) <= radius then
				shatter(entry)
			end
		end
	end
end

-- Everything comes back for the next raid.
function Destructibles.reset()
	for _, entry in ipairs(entries) do
		if entry.broken or not entry.model.Parent or entry.health ~= entry.maxHealth then
			entry.model:Destroy()
			entry.model = entry.template:Clone()
			entry.model.Parent = entry.parent
			entry.broken = false
			entry.health = entry.maxHealth
		end
	end
end

return Destructibles

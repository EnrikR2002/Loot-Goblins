-- A crowd of pets drawn by this client (V13.3): the Pet Derby's racers, Crab Chaos's crabs and the sanctuaries' pets
-- all use it. Each pet is a rig from the shared builder and animator (shared/PetLook.lua: the same code that draws the
-- pets that follow goblins), placed where its owner says each frame, and every moved part goes out in one BulkMoveTo.
-- Nothing here is physical or replicated: anchored, non-colliding parts, local to this client.
--
--   local crowd = PetCrowd.new("Name")       a folder in the workspace
--   crowd:add(key, petId, skin, hat)          -> pet (rig + animation state); the same key twice returns the first
--   crowd:remove(key) / crowd:clear()
--   crowd:place(pet, position, yaw, speed, opts)   opts: { extra = CFrame (a roll or flip), lift = studs,
--                                                   chased, idle (it may do its quirk) }
--   crowd:flush()                              after placing: moves everything at once
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local PetLook = require(Shared:WaitForChild("PetLook"))

local PetCrowd = {}
PetCrowd.__index = PetCrowd

local A = CFrame.Angles

function PetCrowd.new(name)
	local folder = Instance.new("Folder")
	folder.Name = name or "LootGoblinsPetCrowd"
	folder.Parent = workspace
	return setmetatable({ folder = folder, pets = {}, parts = {}, cframes = {} }, PetCrowd)
end

function PetCrowd:add(key, petId, skin, hat)
	local pet = self.pets[key]
	if pet and pet.id == petId and pet.skin == skin and pet.hat == hat then
		return pet
	end
	if pet then
		self:remove(key)
	end
	local ok, rig = pcall(PetLook.build, petId, skin, hat)
	if not ok or not rig then
		ok, rig = pcall(PetLook.build, "Crab")
		if not ok or not rig then
			return nil
		end
	end
	if rig.glow then
		rig.glow.Transparency = 1
	end
	rig.model.Parent = self.folder
	pet = {
		key = key,
		id = petId,
		skin = skin,
		hat = hat,
		rig = rig,
		phase = math.random() * 10,
		idleAt = time() + math.random() * 6,
		flying = PetLook.FLYING[rig.kind] == true,
	}
	self.pets[key] = pet
	return pet
end

function PetCrowd:get(key)
	return self.pets[key]
end

function PetCrowd:remove(key)
	local pet = self.pets[key]
	if pet then
		pet.rig.model:Destroy()
		self.pets[key] = nil
	end
end

function PetCrowd:clear()
	for key in pairs(self.pets) do
		self:remove(key)
	end
end

function PetCrowd:keys()
	local list = {}
	for key in pairs(self.pets) do
		table.insert(list, key)
	end
	return list
end

-- Hide or show a pet without destroying it (out of range).
function PetCrowd:show(pet, visible)
	if pet.visible == visible then
		return
	end
	pet.visible = visible
	pet.rig.model.Parent = visible and self.folder or nil
end

local SITUATION = { speed = 0, chased = false, diving = false }

function PetCrowd:place(pet, position, yaw, speed, opts)
	opts = opts or {}
	local t = time()
	local dt = math.clamp(t - (pet.lastAt or t), 0, 0.1)
	pet.lastAt = t
	pet.phase += dt * (speed or 0) * 0.12 + (pet.flying and dt * 1.2 or 0)
	PetLook.updateQuirk(pet, t, opts.idle == true and (speed or 0) < 0.5)
	SITUATION.speed = speed or 0
	SITUATION.chased = opts.chased == true
	local poses, bounce, extra = PetLook.pose(pet, t, speed or 0, SITUATION)
	local lift = (opts.lift or 0) + (bounce or 0)
	if pet.flying and not opts.grounded then
		lift += 2 + 0.3 * math.sin(t * 1.7 + pet.phase)
	end
	local origin = CFrame.new(position + Vector3.new(0, lift, 0)) * A(0, yaw or 0, 0)
	if opts.extra then
		origin = origin * opts.extra
	end
	pet.origin = PetLook.apply(pet.rig, origin, poses, extra, self.parts, self.cframes)
	return pet.origin
end

function PetCrowd:flush()
	if #self.parts > 0 then
		workspace:BulkMoveTo(self.parts, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(self.parts)
		table.clear(self.cframes)
	end
end

-- The yaw that faces along a flat direction (a pet's front is -Z).
function PetCrowd.yawOf(direction)
	return math.atan2(-direction.X, -direction.Z)
end

return PetCrowd

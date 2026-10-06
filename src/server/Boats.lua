-- The ugly kinematic boats from Test 001, now two of them at the home docks.
-- Sit in Driver; WASD steers. The server moves the boat and stops it at land.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local Boats = {}
local boats = {}
local refs

local WOOD = Color3.fromRGB(102, 67, 42)
local HULL_SIZE = Vector3.new(14, 3, 26)

local landParams = RaycastParams.new()
landParams.FilterType = Enum.RaycastFilterType.Include
landParams.IgnoreWater = false

local function buildBoat(index, spawnCFrame)
	local model = Instance.new("Model")
	model.Name = "Boat" .. index
	local hull = Util.part("Hull", HULL_SIZE, spawnCFrame, WOOD, Enum.Material.WoodPlanks, model)
	model.PrimaryPart = hull
	Util.part(
		"Bow",
		Vector3.new(10, 3, 4),
		spawnCFrame * CFrame.new(0, 0, -14.5),
		WOOD,
		Enum.Material.WoodPlanks,
		model
	)

	local driver = Instance.new("VehicleSeat")
	driver.Name = "Driver"
	driver.Size = Vector3.new(4, 1, 4)
	driver.CFrame = spawnCFrame * CFrame.new(0, 2, 8)
	driver.Anchored = true
	driver.MaxSpeed = Config.BOAT_SPEED
	driver.Color = Color3.fromRGB(60, 60, 70)
	driver.Parent = model

	for i, x in ipairs({ -4, 4 }) do
		local seat = Instance.new("Seat")
		seat.Name = "Passenger" .. i
		seat.Size = Vector3.new(4, 1, 4)
		seat.CFrame = spawnCFrame * CFrame.new(x, 2, -2)
		seat.Anchored = true
		seat.Parent = model
	end

	Util.part(
		"Mast",
		Vector3.new(1, 12, 1),
		spawnCFrame * CFrame.new(0, 7.5, 1),
		Color3.fromRGB(90, 58, 35),
		Enum.Material.Wood,
		model
	)
	local flagColor = index == 1 and Color3.fromRGB(255, 210, 75) or Color3.fromRGB(110, 220, 255)
	Util.part(
		"Flag",
		Vector3.new(0.4, 4, 7),
		spawnCFrame * CFrame.new(0, 11, 4.5),
		flagColor,
		Enum.Material.Fabric,
		model
	)
	model.Parent = refs.folders.structures
	return { model = model, driver = driver, home = spawnCFrame, cframe = spawnCFrame }
end

-- True when the boat's front (or back, when reversing) would hit land, a dock
-- or a post. Rays start just above the sea, so bridges overhead don't count.
local function blocked(cframe, direction)
	local ends = direction >= 0 and -HULL_SIZE.Z / 2 - 4 or HULL_SIZE.Z / 2 + 1
	for _, x in ipairs({ -HULL_SIZE.X / 2, 0, HULL_SIZE.X / 2 }) do
		local probe = (cframe * CFrame.new(x, 0, ends)).Position
		local hit = workspace:Raycast(Vector3.new(probe.X, 4, probe.Z), Vector3.new(0, -12, 0), landParams)
		if hit and hit.Material ~= Enum.Material.Water then
			return true
		end
	end
	return false
end

function Boats.build(worldRefs)
	refs = worldRefs
	-- Terrain and walkable parts (docks, bridges' feet) stop boats; boats don't stop each other.
	landParams.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	for i, spawnCFrame in ipairs(refs.boatSpawns) do
		table.insert(boats, buildBoat(i, spawnCFrame))
	end
end

function Boats.tick(dt)
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	for _, boat in ipairs(boats) do
		local driver = boat.driver
		if driver.Occupant then
			local throttle = driver.ThrottleFloat
			local steer = driver.SteerFloat
			local turned = boat.cframe * CFrame.Angles(0, -steer * Config.BOAT_TURN_RATE * dt, 0)
			local step = turned.LookVector * throttle * Config.BOAT_SPEED * dt
			local moved = CFrame.new(turned.Position + Vector3.new(step.X, 0, step.Z)) * turned.Rotation
			local p = moved.Position
			local inside = p.X > min.X + 15 and p.X < max.X - 15 and p.Z > min.Z + 15 and p.Z < max.Z - 15
			if throttle ~= 0 and (blocked(turned, throttle) or not inside) then
				moved = turned
			end
			boat.cframe = moved
			boat.model:PivotTo(moved)
		end
	end
end

function Boats.reset()
	for _, boat in ipairs(boats) do
		boat.cframe = boat.home
		boat.model:PivotTo(boat.home)
	end
end

return Boats

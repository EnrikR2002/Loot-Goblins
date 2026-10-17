-- The default goblin (V10, docs/ART_DIRECTION.md "Goblins"). Every player is a goblin: green skin, long pointed
-- ears and a big nose, over whatever their avatar wears. Not a customization system (that is V11); one look for
-- everyone, so a goblin always reads as a goblin from across the water.
--
-- Purely cosmetic: the ears and nose are welded to the head and are massless, non-colliding, never hit by rays
-- or touches, so movement, hitboxes, grapples and the Poltergoblin's body copy are exactly what they were.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Palette"))

local GoblinLook = {}

local SKIN = Palette.GOBLIN
local INNER = Color3.fromRGB(214, 132, 120)

local function bit(head, name, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = p
	weld.Parent = p
	p.Parent = head.Parent
	return p
end

-- Safe to call any number of times: it (re)builds the ears and nose on the current head and sets the colours.
-- Avatar loading replaces the head and the body colours just after the character spawns, so it is called when
-- the appearance has loaded (watch) and once more a moment after spawning (Main), whichever comes last wins.
function GoblinLook.apply(player, character)
	if not character or not character.Parent or player.Character ~= character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.HeadColor3 = SKIN
	colors.LeftArmColor3 = SKIN
	colors.RightArmColor3 = SKIN
	colors.LeftLegColor3 = SKIN
	colors.RightLegColor3 = SKIN
	colors.TorsoColor3 = SKIN

	local ear = character:FindFirstChild("GoblinEarL")
	local weld = ear and ear:FindFirstChildOfClass("WeldConstraint")
	if weld and weld.Part0 == head then
		return -- already on this head
	end
	for _, name in ipairs({ "GoblinEarL", "GoblinEarR", "GoblinEarInnerL", "GoblinEarInnerR", "GoblinNose" }) do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local half = head.Size / 2
	for _, side in ipairs({ -1, 1 }) do
		local suffix = side < 0 and "L" or "R"
		-- Long ears swept out and back, pink inside.
		local tilt = CFrame.new(side * (half.X + 0.35), half.Y * 0.2, 0.1)
			* CFrame.Angles(0, side * math.rad(-20), side * math.rad(-62))
		bit(
			head,
			"GoblinEar" .. suffix,
			Vector3.new(0.28, 0.75, 1.5),
			tilt * CFrame.Angles(0, math.rad(180), 0),
			SKIN,
			Enum.PartType.Wedge
		)
		bit(
			head,
			"GoblinEarInner" .. suffix,
			Vector3.new(0.12, 0.45, 0.95),
			tilt * CFrame.new(side * 0.12, -0.08, 0.1) * CFrame.Angles(0, math.rad(180), 0),
			INNER,
			Enum.PartType.Wedge
		)
	end
	-- A big nose.
	local nose = bit(head, "GoblinNose", Vector3.new(0.42, 0.42, 0.7), CFrame.new(0, -0.05, -half.Z - 0.12), SKIN)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = nose
end

function GoblinLook.watch(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		GoblinLook.apply(player, character)
	end)
end

return GoblinLook

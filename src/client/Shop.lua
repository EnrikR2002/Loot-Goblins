-- The Goblin Wardrobe (V11, Goblin Life): the shop and the locker in one window (P, the wardrobe button, or the
-- tailor's stall on the skyship).
--   SHOP    every item, what it costs, how to earn it; buy with Shinies (two presses: no accidental purchases)
--   LOCKER  what you own; wear and take off; three saved outfits; your trophies and how close the next ones are
-- Picking any item tries it on in the preview: YOUR goblin (a copy of your real character, dressed by the same code
-- that dresses it in the game), a real boat, or the real pet, turning slowly; drag (or the right stick) to turn it.
-- A preview is only a preview: nothing is bought or worn until the server says so. Every price, balance, owned flag
-- and result comes from the server (attributes and ShopResult); the buttons only send intent.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))
local BoatLook = require(Shared:WaitForChild("BoatLook"))
local PetLook = require(Shared:WaitForChild("PetLook"))
local StyleFx = require(Shared:WaitForChild("StyleFx"))
local EmoteMoves = require(Shared:WaitForChild("EmoteMoves"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local Shop = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local shopRemote = remotes:WaitForChild("ShopRequest")
local emoteRemote = remotes:WaitForChild("EmoteRequest")

local C = Ui.C
local welcomeWaiting = nil -- V12: the welcome card's payload, until a calm moment shows it (see Shop.welcome)
local W, H = 1000, 600 -- the window's design size (scaled to fit the screen)
-- Short screens (a phone held sideways is about 390 points tall) get a shorter window and stage, so the window
-- scales to about 0.8 instead of 0.6 and its text stays readable. Chosen once, when the window is built.
local VIEW_H = 292 -- the stage's 3D view
local INFO = { name = 0, chips = 34, blurb = 60, blurbH = 40, detail = 100, detailH = 44, message = 142, messageH = 34 }
local function chooseSize()
	local size = workspace.CurrentCamera.ViewportSize
	if size.Y < 560 then
		H = 500
		VIEW_H = 192
		INFO =
			{ name = 0, chips = 32, blurb = 56, blurbH = 36, detail = 94, detailH = 38, message = 134, messageH = 24 }
	end
end

-- State ---------------------------------------------------------------------------------------------------------------
local gui, backdrop, window, uiScale, dock, dockWardrobe
local tabButtons = {}
local rail, grid, footer, gridLayout, rowsLayout
local info = {}
local stageView, overlay, previewChip
local tab = "shop" -- "shop" | "locker"
local section = "slot" -- "slot" | "presets" | "trophies"
local slotId = "hat"
local petTheme = nil -- V13: the pet grid's theme filter (nil: all)
local selected = nil -- item id
local preview = {} -- slot -> item id tried on (local only)
local previewPreset = nil
local pending = {} -- id -> time a request was sent
local armed = nil -- { id, untilTime }: the first press of a purchase
local visible = false
local cards = {}
local railButtons = {}
local openedOnce = false

-- What the server says --------------------------------------------------------------------------------------------------
local function ownedSet()
	local set = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function owns(item, set)
	return Catalog.isFree(item) or (set or ownedSet())[item.id] == true
end

local function equippedLook()
	return Catalog.decodeLook(player:GetAttribute("Look"))
end

local function wearing(item, look)
	look = look or equippedLook()
	if item.slot == "kit" then
		return player:GetAttribute("Kit") == item.gear
	elseif item.slot == "emote" then
		return false
	end
	return look[item.slot] == item.id
end

local function shinies()
	return player:GetAttribute("Shinies") or 0
end

-- Robux items: on sale (with the price Roblox gave the server), shown as "not on sale yet" (Studio only), or hidden.
local function premiumInfo(item)
	if not item.premium then
		return nil
	end
	for key, price in string.gmatch(workspace:GetAttribute("PremiumPrices") or "", "([%w_]+)=(%d+)") do
		if key == item.premium then
			return { onSale = true, price = tonumber(price) }
		end
	end
	if workspace:GetAttribute("PremiumPreview") then
		return { onSale = false }
	end
	return nil
end

local function listed(item, set)
	if item.retired then
		return false
	end
	if tab == "locker" then
		return owns(item, set)
	end
	if item.rarity == "premium" then
		return premiumInfo(item) ~= nil
	end
	return true
end

local function achievementProgress()
	local ok, data = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("AchievementProgress") or "{}")
	end)
	return ok and data or {}
end

local function presets()
	local ok, data = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Presets") or "[]")
	end)
	return ok and type(data) == "table" and data or {}
end

-- The look being shown: what is worn, with whatever is being tried on.
local function previewLook()
	local look = equippedLook()
	if previewPreset then
		for _, slot in ipairs({
			"hat",
			"eyes",
			"face",
			"outfit",
			"back",
			"skin",
			"ears",
			"nose",
			"livery",
			"flag",
			"figurehead",
			"trail",
			"wake",
			"trickfx",
			"callout",
			"victory",
			"title", -- V13.3
		}) do
			look[slot] = previewPreset[slot]
		end
	end
	for slot, id in pairs(preview) do
		look[slot] = id or nil
	end
	if preview.pet and look.petskin then
		local skin = Catalog.get(look.petskin)
		if skin and skin.pet ~= look.pet then
			look.petskin = nil
		end
	end
	return Catalog.withDefaults(look)
end

local function previewing()
	if previewPreset then
		return true
	end
	local look = equippedLook()
	for slot, id in pairs(preview) do
		if look[slot] ~= id then
			return true
		end
	end
	return false
end

-- What the stage shows for a slot.
local STAGE_FOR = {
	boat = "boat", -- V13: the showroom
	hat = "goblin",
	eyes = "goblin",
	face = "goblin",
	outfit = "goblin",
	back = "goblin",
	skin = "goblin",
	ears = "goblin",
	nose = "goblin",
	livery = "boat",
	flag = "boat",
	figurehead = "boat",
	trail = "boat",
	wake = "boat",
	trickfx = "boat",
	callout = "callout",
	title = "callout", -- V13.3: a title previews flat, as the words over your head
	emote = "goblin",
	victory = "goblin",
	pet = "pet",
	petskin = "pet",
	pethat = "pet",
	kit = "kit",
}
local HEAD_SLOTS = { hat = true, eyes = true, face = true, ears = true, nose = true, skin = true }

-- The stage: the 3D preview --------------------------------------------------------------------------------------------
local stage = {
	kind = nil,
	subject = nil,
	skeleton = nil,
	attached = nil,
	yaw = 200,
	pitch = 8,
	focus = nil,
	dragging = false,
	lastTouch = 0,
	emote = nil,
	emoteAt = 0,
	pet = nil,
}

local function clearStage()
	if stage.subject then
		stage.subject:Destroy()
	end
	stage.subject, stage.skeleton, stage.attached, stage.pet, stage.emote = nil, nil, nil, nil, nil
	stage.boatClass = nil
	if overlay then
		for _, child in ipairs(overlay:GetChildren()) do
			child:Destroy()
		end
	end
end

-- A posable copy of a character: anchored, every joint known, everything attached to a body part remembered.
local function skeletonOf(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("Motor6D") and j.Part0 and j.Part1 then
			table.insert(joints, { name = j.Name, p0 = j.Part0, p1 = j.Part1, c0 = j.C0, c1 = j.C1 })
		elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
			local a0, a1 = j.Attachment0, j.Attachment1
			table.insert(joints, { name = j.Name, p0 = a0.Parent, p1 = a1.Parent, c0 = a0.CFrame, c1 = a1.CFrame })
		end
	end
	local placed = {}
	if not root then
		return nil
	end
	placed[root] = true
	local order = {}
	local progress = true
	while progress do
		progress = false
		for _, j in ipairs(joints) do
			if not j.done and placed[j.p0] and j.p1:IsA("BasePart") then
				j.done = true
				placed[j.p1] = true
				table.insert(order, j)
				progress = true
			end
		end
	end
	return { root = root, order = order, placed = placed }
end

local function attachedOf(model, placed)
	local links = {}
	local function link(a, b)
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") or (d:IsA("JointInstance") and not d:IsA("Motor6D")) then
			link(d.Part0, d.Part1)
		elseif d:IsA("RigidConstraint") and d.Attachment0 and d.Attachment1 then
			link(d.Attachment0.Parent, d.Attachment1.Parent)
		end
	end
	local order, seen, queue = {}, {}, {}
	for part in pairs(placed) do
		seen[part] = true
		table.insert(queue, part)
	end
	local head = 1
	while head <= #queue do
		local base = queue[head]
		head += 1
		for _, other in ipairs(links[base] or {}) do
			if not seen[other] and other:IsDescendantOf(model) then
				seen[other] = true
				table.insert(order, { part = other, base = base, offset = base.CFrame:ToObjectSpace(other.CFrame) })
				table.insert(queue, other)
			end
		end
	end
	return order
end

local REST = CFrame.new(0, 3, 0)
local function pose(transforms)
	local skeleton = stage.skeleton
	if not skeleton then
		return
	end
	skeleton.root.CFrame = REST
	for _, j in ipairs(skeleton.order) do
		local t = transforms and (transforms[j.name] or transforms[(EmoteMoves.R6[j.name] or "")]) or nil
		j.p1.CFrame = j.p0.CFrame * j.c0 * (t or CFrame.new()) * j.c1:Inverse()
	end
	for _, a in ipairs(stage.attached or {}) do
		a.part.CFrame = a.base.CFrame * a.offset
	end
end

local function copyCharacter()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Head") then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if
			d:IsA("BaseScript")
			or d:IsA("Tool")
			or d:IsA("ForceField")
			or d:IsA("BillboardGui")
			or d:IsA("Highlight")
			or d:IsA("Sound")
			or d:IsA("ParticleEmitter")
			or d:IsA("ProximityPrompt")
			or (d:IsA("Constraint") and not d:IsA("AnimationConstraint") and not d:IsA("RigidConstraint"))
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	return copy
end

-- Puts the goblin (or a stand-in) on the stage, dressed in `look`.
local function stageGoblin(look)
	if stage.kind ~= "goblin" or not stage.subject or not stage.subject.Parent then
		clearStage()
		stage.kind = "goblin"
		local copy = copyCharacter()
		if copy then
			local skeleton = skeletonOf(copy)
			if skeleton and #skeleton.order > 3 then
				stage.skeleton = skeleton
				stage.attached = attachedOf(copy, skeleton.placed)
				copy.Parent = stageView.world
				stage.subject = copy
				pose(nil)
			else
				copy:Destroy()
			end
		end
		if not stage.subject then
			local stand = Wardrobe.mannequin()
			stand:PivotTo(CFrame.new(0, 3, 0))
			stand.Parent = stageView.world
			stage.subject = stand
		end
	end
	Wardrobe.dress(stage.subject, look)
	if stage.skeleton then
		stage.attached = attachedOf(stage.subject, stage.skeleton.placed)
	end
end

-- V13: the boat class a look sails (its "boat" slot), and the still copy of it the server made for previews.
local function boatClassOf(look)
	local item = Catalog.get(look and look.boat)
	return item and item.class or "skiff"
end

local function boatTemplate(class)
	local folder = ReplicatedStorage:FindFirstChild("LootGoblinsPreview")
	return folder and (folder:FindFirstChild(class) or folder:FindFirstChild("skiff"))
end

local function stageBoat(look)
	local class = boatClassOf(look)
	if stage.kind ~= "boat" or not stage.subject or stage.boatClass ~= class then
		clearStage()
		stage.kind = "boat"
		stage.boatClass = class
		local template = boatTemplate(class)
		if template then
			stage.subject = template:Clone()
			stage.subject.Parent = stageView.world
		end
	end
	if stage.subject then
		BoatLook.apply(stage.subject, look)
	end
end

local function stagePet(look)
	local petId = look.pet or "Crab"
	local sig = petId .. tostring(look.petskin) .. tostring(look.pethat)
	if stage.kind == "pet" and stage.pet and stage.pet.sig == sig then
		return
	end
	clearStage()
	stage.kind = "pet"
	local rig = PetLook.build(petId, look.petskin, look.pethat)
	if rig then
		rig.model.Parent = stageView.world
		stage.subject = rig.model
		if rig.glow then
			rig.glow.Transparency = 1 -- the shell's "ready" glow is a game state, not part of the look
		end
		local cf, size = rig.model:GetBoundingBox()
		stage.pet = {
			rig = rig,
			sig = sig,
			box = size,
			center = cf.Position.Y,
			entry = { rig = rig, phase = 0, quirk = nil, quirkAt = 0, idleAt = time() + 1.5, owner = player },
		}
	end
end

-- V13: the showroom's rows (Config.BOAT_CLASSES) and abilities (Config.BOAT_ABILITIES) by class.
local function classRow(class)
	for _, row in ipairs(Config.BOAT_CLASSES) do
		if row.id == class then
			return row
		end
	end
	return nil
end

local function boatAbility(class)
	local spec = Config.BOAT_TYPES[class]
	return spec and spec.ability and Config.BOAT_ABILITIES[spec.ability]
end

local BOAT_STATS = {
	{ "speed", "SPEED", Color3.fromRGB(255, 196, 70) },
	{ "handling", "HANDLING", Color3.fromRGB(120, 210, 255) },
	{ "toughness", "TOUGHNESS", Color3.fromRGB(150, 230, 120) },
	{ "air", "AIR", Color3.fromRGB(220, 160, 255) },
	{ "firepower", "FIREPOWER", Color3.fromRGB(255, 120, 96) },
}
local ABILITY_KEYS = "At the wheel: R on the water (R1 on a controller, the stunt button on touch)."

-- Flat effects drawn over the stage (a trail's colours, a callout's style, a kit's icon).
local function overlayLabel(props)
	return Ui.label(overlay, props)
end

local function stageOverlay(item)
	for _, child in ipairs(overlay:GetChildren()) do
		child:Destroy()
	end
	if not item then
		return
	end
	if item.slot == "boat" then
		-- V13, the showroom card: what this class is for, five stats as pips, and its ability.
		local class = classRow(item.class)
		local ability = boatAbility(item.class)
		if not class then
			return
		end
		local panel = Ui.make("Frame", {
			Name = "BoatStats",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(1, -16, 0, 92),
			BackgroundColor3 = C.night,
			BackgroundTransparency = 0.25,
		}, overlay)
		Ui.corner(panel, 10)
		Ui.label(panel, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.5, -10, 0, 16),
			Text = class.role,
			Font = Ui.TITLE,
			TextSize = 13,
			TextColor3 = C.goldPale,
		})
		for i, stat in ipairs(BOAT_STATS) do
			local value = class.pips[stat[1]] or 0
			Ui.label(panel, {
				Position = UDim2.fromOffset(10, 6 + i * 14),
				Size = UDim2.fromOffset(74, 14),
				Text = stat[2],
				Font = Ui.BOLD,
				TextSize = 11,
				TextColor3 = C.parchmentDark,
			})
			Ui.label(panel, {
				Position = UDim2.fromOffset(80, 6 + i * 14),
				Size = UDim2.fromOffset(80, 14),
				Text = string.rep("●", value) .. string.rep("○", 5 - value),
				Font = Ui.BOLD,
				TextSize = 12,
				TextColor3 = stat[3],
			})
		end
		if ability then
			Ui.label(panel, {
				Position = UDim2.new(0.5, 4, 0, 4),
				Size = UDim2.new(0.5, -12, 0, 30),
				Text = ability.glyph .. " " .. ability.name,
				Font = Ui.TITLE,
				TextSize = 16,
				TextColor3 = C.white,
			})
			Ui.label(panel, {
				Position = UDim2.new(0.5, 4, 0, 32),
				Size = UDim2.new(0.5, -12, 0, 56),
				Text = ability.verb .. string.format(" (every %d s). %s", ability.cooldown, ABILITY_KEYS),
				Font = Ui.BODY,
				TextSize = 11,
				TextColor3 = C.parchment,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
		end
		return
	end
	if item.slot == "trail" or item.slot == "wake" then
		local spec = item.slot == "trail" and StyleFx.TRAILS[item.id] or StyleFx.WAKES[item.id]
		if spec then
			local ribbon = Ui.make("Frame", {
				Name = "Ribbon",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(0.62, 0.66),
				Size = UDim2.fromScale(0.62, item.slot == "trail" and 0.07 or 0.12),
				BackgroundColor3 = C.white,
				BorderSizePixel = 0,
				Rotation = -8,
			}, overlay)
			Ui.corner(ribbon, 30)
			Ui.make("UIGradient", {
				Color = spec.colors or ColorSequence.new(spec.color),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.7, 0.15),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}, ribbon)
			stage.ribbon = ribbon
		end
		overlayLabel({
			Position = UDim2.new(0, 10, 1, -54),
			Size = UDim2.new(1, -20, 0, 20),
			Text = item.slot == "trail" and "Shown behind your boat while it boosts." or "Shown in your wake at speed.",
			TextSize = 13,
			Font = Ui.BODY,
			TextColor3 = C.inkSoft,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif item.slot == "trickfx" then
		overlayLabel({
			Position = UDim2.new(0, 10, 1, -54),
			Size = UDim2.new(1, -20, 0, 20),
			Text = "Streams off your boat through every trick; bursts when you land clean.",
			TextSize = 13,
			Font = Ui.BODY,
			TextColor3 = C.inkSoft,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif item.slot == "title" then
		-- V13.3: the words as they float over a goblin's head.
		local style = StyleFx.TITLES[item.id]
		if style then
			local label = overlayLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromScale(0.92, 0.2),
				Text = (style.glyph and (style.glyph .. " ") or "") .. style.text,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = style.color,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			Ui.make(
				"UIStroke",
				{ Color = style.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
				label
			)
			if style.gradient then
				Ui.make("UIGradient", { Color = style.gradient, Rotation = 90 }, label)
			end
			overlayLabel({
				Position = UDim2.new(0, 10, 1, -54),
				Size = UDim2.new(1, -20, 0, 20),
				Text = "Floats over your goblin's head, for everyone to see.",
				TextSize = 13,
				Font = Ui.BODY,
				TextColor3 = C.inkSoft,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	elseif item.slot == "callout" then
		local style = StyleFx.CALLOUTS[item.id] or StyleFx.CALLOUTS.callout_classic
		local words = { "CORKSCREW!", "x3 COMBO!", "OUTRAGEOUS!" }
		for i, word in ipairs(words) do
			local back = style.back and style.back[(i - 1) % #style.back + 1]
			local label = overlayLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.2 + i * 0.2),
				Size = UDim2.fromScale(0.9, 0.17),
				Text = word,
				Font = style.font,
				TextScaled = true,
				TextColor3 = style.palette[(i - 1) % #style.palette + 1],
				TextXAlignment = Enum.TextXAlignment.Center,
				Rotation = (i % 2 == 0) and 6 or -6,
				BackgroundTransparency = back and 0 or 1,
				BackgroundColor3 = back or C.white,
			})
			if back then
				Ui.corner(label, 8)
			end
			Ui.make(
				"UIStroke",
				{ Color = style.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
				label
			)
			if style.gradient then
				Ui.make("UIGradient", { Color = style.gradient, Rotation = 90 }, label)
			end
		end
	elseif item.slot == "kit" then
		local gear = Config.GEAR[item.gear]
		local badge = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(150, 150),
			BackgroundColor3 = gear and gear.color or C.gold,
		}, overlay)
		Ui.corner(badge, 75)
		Ui.stroke(badge, C.wood, 4)
		Ui.label(badge, {
			Size = UDim2.fromScale(1, 1),
			Text = ({ Rebreather = "🤿", CinderBoots = "🔥", FrostClaws = "❄" })[item.gear] or "★",
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
end

-- Shows a look on the stage for a slot (and an item, for its flat effect).
local function showStage(forSlot, item)
	if not stageView then
		return
	end
	local look = previewLook()
	local kind = STAGE_FOR[forSlot] or "goblin"
	stage.ribbon = nil
	-- V13: the chosen pet or boat stays on the stage after it is bought (buying clears the try-on, and the stage used
	-- to fall back to what is worn: a Crab, or the Skiff).
	if item and item.slot == "pet" then
		if look.pet ~= item.id then
			look.pet, look.petskin = item.id, nil
		end
	elseif item and item.slot == "boat" then
		look.boat = item.id
	end
	if kind == "goblin" then
		stageGoblin(look)
		stage.focus = HEAD_SLOTS[forSlot] and "head" or "body"
		if forSlot == "back" then
			stage.yaw = 20
		end
		if (forSlot == "emote" or forSlot == "victory") and item then
			stage.emote = item.id
			stage.emoteAt = time()
		else
			stage.emote = nil
			pose(nil)
		end
	elseif kind == "boat" then
		if stage.kind ~= "boat" then
			stage.yaw = 235 -- a three-quarter view from the bow, like the thumbnails
		end
		stageBoat(look)
		stage.focus = forSlot == "flag" and "flag" or (forSlot == "figurehead" and "bow" or "boat")
	elseif kind == "pet" then
		stagePet(look)
		stage.focus = "pet"
	else
		clearStage()
		stage.kind = kind
	end
	stageOverlay(item)
	previewChip.Visible = previewing()
end

local function stageCamera()
	local camera = stageView.camera
	local subject = stage.subject
	if not subject or not subject.Parent then
		camera.CFrame = CFrame.new(0, 0, 10)
		return
	end
	if stage.kind == "goblin" then
		local head = subject:FindFirstChild("Head")
		if stage.focus == "head" and head then
			Ui.frameBox(
				camera,
				head.Position + Vector3.new(0, 0.45, 0),
				Vector3.new(4.4, 4.4, 4.4),
				stage.yaw,
				stage.pitch,
				1.0
			)
		else
			local cf, size = subject:GetBoundingBox()
			Ui.frameBox(
				camera,
				cf.Position,
				Vector3.new(size.X * 0.6, size.Y, size.Z * 0.6),
				stage.yaw,
				stage.pitch,
				1.0
			)
		end
	elseif stage.kind == "boat" then
		local hull = subject:FindFirstChild("Hull")
		if hull and stage.focus == "flag" then
			local flag = subject:FindFirstChild("Flag")
			local at = flag and flag.Position or hull.Position + Vector3.new(0, 12, 0)
			Ui.frameBox(camera, at, Vector3.new(7, 7, 7), stage.yaw, 4, 1.2)
		elseif hull and stage.focus == "bow" then
			Ui.frameBox(
				camera,
				(hull.CFrame * CFrame.new(0, 2.5, -hull.Size.Z * 0.42)).Position,
				Vector3.new(9, 9, 9),
				stage.yaw,
				8,
				1.2
			)
		else
			local cf, size = subject:GetBoundingBox()
			Ui.frameBox(camera, cf.Position, size, stage.yaw, 14, 0.95)
		end
	elseif stage.kind == "pet" then
		local pet = stage.pet
		local lift = pet and PetLook.FLYING[pet.rig.kind] and 1.2 or 0
		local box = pet and pet.box or Vector3.new(3, 3, 3)
		local span = math.max(3.4, box.X, box.Y, box.Z) * 1.2
		Ui.frameBox(
			camera,
			Vector3.new(0, lift + (pet and pet.center or 0.8), 0),
			Vector3.new(span, span, span),
			stage.yaw,
			12,
			1.05
		)
	end
end

local function animateStage(dt)
	if not visible or not stageView then
		return
	end
	if not stage.dragging and time() - stage.lastTouch > 2.5 then
		stage.yaw = (stage.yaw + dt * 14) % 360
	end
	local t = time()
	if stage.kind == "goblin" and stage.emote then
		local move = EmoteMoves.get(stage.emote)
		if move then
			local cycle = move.duration + 0.6
			local elapsed = (t - stage.emoteAt) % cycle
			pose(EmoteMoves.at(stage.emote, elapsed))
		end
	elseif stage.kind == "pet" and stage.pet then
		local rig, entry = stage.pet.rig, stage.pet.entry
		entry.phase += dt
		-- Its idle quirk every few seconds, so the shop shows what it does (shared/PetLook.lua).
		entry.idleAt = math.min(entry.idleAt or 0, (entry.quirkAt or 0) + 4.5)
		PetLook.updateQuirk(entry, t, true)
		local poses, bounce, extra = PetLook.pose(entry, t, 0, { speed = 0, chased = false, diving = false })
		local lift = PetLook.FLYING[rig.kind] and 1.2 or 0
		PetLook.apply(rig, CFrame.new(0, lift + (bounce or 0), 0), poses, extra)
	elseif stage.kind == "boat" and stage.subject and selected then
		local item = Catalog.get(selected)
		if item and item.slot == "trickfx" then
			local p = (t % 2.2) / 0.9
			local spin = p < 1 and p * math.pi * 2 or 0
			local lift = p < 1 and math.sin(p * math.pi) * 4 or 0
			stage.subject:PivotTo(CFrame.new(0, lift, 0) * CFrame.Angles(0, spin, 0))
			if p < 1 and math.random() < 0.6 then
				local spec = StyleFx.TRICKFX[item.id]
				local color = spec and (spec.during.color or spec.during.colors.Keypoints[1].Value) or C.gold
				local dot = Ui.make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.5, 0.5 + (math.random() - 0.5) * 0.4),
					Size = UDim2.fromOffset(10, 10),
					Rotation = 45,
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				}, overlay)
				TweenService
					:Create(dot, TweenInfo.new(0.6), { BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) })
					:Play()
				task.delay(0.65, function()
					dot:Destroy()
				end)
			end
		end
	end
	if stage.ribbon then
		local gradient = stage.ribbon:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Offset = Vector2.new(math.sin(t * 3) * 0.05, 0)
		end
	end
	stageCamera()
end

-- Thumbnails -------------------------------------------------------------------------------------------------------------
local GLYPHS = {
	emote_wave = "👋",
	emote_cackle = "😆",
	emote_salute = "🎖",
	emote_panic = "😱",
	emote_jig = "🕺",
	emote_flex = "💪",
	emote_faceplant = "😵",
	victory_cheer = "🙌",
	victory_stomp = "🥁",
	victory_shower = "💰",
	victory_crown = "👑",
	kit_Rebreather = "🤿",
	kit_CinderBoots = "🔥",
	kit_FrostClaws = "❄",
}

local mannequinTemplate, skiffTemplate
local function mannequin()
	if not mannequinTemplate then
		mannequinTemplate = Wardrobe.mannequin()
	end
	return mannequinTemplate:Clone()
end

local function thumbnail(item, holder)
	local slot = item.slot
	local kind = STAGE_FOR[slot]
	if kind == "goblin" and slot ~= "emote" and slot ~= "victory" then
		local view = Ui.viewport(holder, { fov = 26 })
		local model = mannequin()
		Wardrobe.dress(model, Catalog.withDefaults({ [slot] = item.id }))
		model.Parent = view.world
		local head = model:FindFirstChild("Head")
		if slot == "hat" or slot == "ears" then
			-- Frame the head and whatever is on it (a bicorne is three heads wide).
			local low, high = head.Position - head.Size / 2, head.Position + head.Size / 2
			for _, p in ipairs(model[Wardrobe.FOLDER]:GetDescendants()) do
				if p:IsA("BasePart") then
					local half = p.Size / 2
					low = low:Min(p.Position - Vector3.new(half.Magnitude, half.Magnitude, half.Magnitude) * 0.6)
					high = high:Max(p.Position + Vector3.new(half.Magnitude, half.Magnitude, half.Magnitude) * 0.6)
				end
			end
			Ui.frameBox(view.camera, (low + high) / 2, high - low, slot == "ears" and 225 or 200, 8, 1.0)
		elseif HEAD_SLOTS[slot] then
			Ui.frameBox(view.camera, head.Position + Vector3.new(0, 0, -0.25), Vector3.new(2.1, 2.1, 2.1), 192, 4, 1.0)
		elseif slot == "back" then
			Ui.frameBox(view.camera, Vector3.new(0, 2.6, 0), Vector3.new(3.4, 3.4, 3.4), 30, 10, 1.1)
		else
			Ui.frameBox(view.camera, Vector3.new(0, 1.9, 0), Vector3.new(2.6, 6.2, 2.6), 200, 6, 1)
		end
		return
	end
	if slot == "boat" then
		-- V13: the class itself, a three-quarter view from the bow.
		local template = boatTemplate(item.class)
		if template then
			local view = Ui.viewport(holder, { fov = 30 })
			local copy = template:Clone()
			copy.Parent = view.world
			local cf, size = copy:GetBoundingBox()
			Ui.frameBox(view.camera, cf.Position, size, 235, 16, 0.8)
		end
		return
	end
	if kind == "boat" and (slot == "livery" or slot == "flag" or slot == "figurehead") then
		skiffTemplate = skiffTemplate or boatTemplate("skiff")
		if skiffTemplate then
			local view = Ui.viewport(holder, { fov = 30 })
			local copy = skiffTemplate:Clone()
			BoatLook.apply(copy, { [slot] = item.id })
			copy.Parent = view.world
			local hull = copy:FindFirstChild("Hull")
			if slot == "flag" then
				local flag = copy:FindFirstChild("Flag")
				Ui.frameBox(view.camera, flag and flag.Position or hull.Position, Vector3.new(6, 6, 6), 250, 4, 1.15)
			elseif slot == "figurehead" then
				Ui.frameBox(
					view.camera,
					(hull.CFrame * CFrame.new(0, 2.5, -12)).Position,
					Vector3.new(8, 8, 8),
					230,
					8,
					1.15
				)
			else
				local cf, size = copy:GetBoundingBox()
				Ui.frameBox(view.camera, cf.Position, size, 235, 16, 0.85)
			end
			return
		end
	end
	if kind == "pet" then
		local petId = slot == "pet" and item.id or (item.pet or player:GetAttribute("Pet") or "Crab")
		local rig = PetLook.build(petId, slot == "petskin" and item.id or nil, slot == "pethat" and item.id or nil)
		if rig then
			local view = Ui.viewport(holder, { fov = 30 })
			if rig.glow then
				rig.glow.Transparency = 1 -- the shell's "ready" glow is a game state, not part of the look
			end
			rig.model.Parent = view.world
			local cf, size = rig.model:GetBoundingBox()
			local span = math.max(2.6, size.X, size.Y, size.Z)
			Ui.frameBox(view.camera, cf.Position, Vector3.new(span, span, span), 215, 14, 1)
		end
		return
	end
	-- Flat thumbnails.
	if slot == "trail" or slot == "wake" or slot == "trickfx" then
		local spec = slot == "trail" and StyleFx.TRAILS[item.id]
			or (
				slot == "wake" and StyleFx.WAKES[item.id]
				or (StyleFx.TRICKFX[item.id] and StyleFx.TRICKFX[item.id].land)
			)
		local swatch = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.84, slot == "trail" and 0.28 or 0.5),
			BackgroundColor3 = C.white,
			Rotation = -10,
		}, holder)
		Ui.corner(swatch, 20)
		if spec then
			Ui.make("UIGradient", { Color = spec.colors or ColorSequence.new(spec.color) }, swatch)
		end
		Ui.label(holder, {
			Size = UDim2.fromScale(1, 1),
			Text = slot == "trail" and "✦  ✦" or (slot == "wake" and "≈ ≈ ≈" or "★"),
			TextColor3 = C.white,
			TextStrokeTransparency = 0.4,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif slot == "title" then
		local style = StyleFx.TITLES[item.id]
		local label = Ui.label(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.42),
			Text = style and style.text or item.name,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = style and style.color or C.white,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.make("UIStroke", {
			Color = style and style.stroke or C.night,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, label)
	elseif slot == "callout" then
		local style = StyleFx.CALLOUTS[item.id] or StyleFx.CALLOUTS.callout_classic
		local label = Ui.label(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.92, 0.5),
			Text = "WOW!",
			Font = style.font,
			TextScaled = true,
			TextColor3 = style.palette[1],
			TextXAlignment = Enum.TextXAlignment.Center,
			Rotation = -6,
			BackgroundTransparency = style.back and 0 or 1,
			BackgroundColor3 = style.back and style.back[1] or C.white,
		})
		Ui.make(
			"UIStroke",
			{ Color = style.stroke, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
			label
		)
		if style.gradient then
			Ui.make("UIGradient", { Color = style.gradient, Rotation = 90 }, label)
		end
	else
		local gear = item.gear and Config.GEAR[item.gear]
		if gear then
			holder.BackgroundColor3 = gear.color:Lerp(C.parchment, 0.4)
		end
		Ui.label(holder, {
			Size = UDim2.fromScale(1, 1),
			Text = GLYPHS[item.id] or "★",
			TextSize = 46,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
end

-- Cards ----------------------------------------------------------------------------------------------------------------------
local function stateText(item, set, look)
	if wearing(item, look) then
		return item.slot == "kit" and "STARTING WITH" or "WEARING", C.good
	end
	if owns(item, set) then
		return "OWNED", C.sea
	end
	if item.unlock then
		return "🔒 TROPHY", Catalog.RARITIES.trophy.color:Lerp(C.ink, 0.35)
	end
	if item.award then
		return "🏆 SEASON", Catalog.RARITIES.season.color:Lerp(C.ink, 0.3) -- V13.3
	end
	local premium = premiumInfo(item)
	if Catalog.forSale(item) then
		local affordable = shinies() >= item.price
		return "◆ " .. item.price, affordable and C.ink or C.danger
	end
	if premium then
		return premium.onSale and ("R$ " .. premium.price) or "NOT ON SALE", C.inkSoft
	end
	return "", C.ink
end

local function refreshCards()
	local set, look = ownedSet(), equippedLook()
	for id, card in pairs(cards) do
		local item = Catalog.get(id)
		local text, color = stateText(item, set, look)
		card.state.Text = text
		card.state.TextColor3 = color
		card.check.Visible = wearing(item, look)
		card.stroke.Color = (id == selected) and C.gold or Catalog.RARITIES[item.rarity].color
		card.stroke.Thickness = (id == selected) and 4 or 2
	end
end

-- The info panel -------------------------------------------------------------------------------------------------------------
local function setMessage(text, color)
	info.message.Text = text or ""
	info.message.TextColor3 = color or C.inkSoft
end

local function describe(item)
	if item.slot == "boat" then
		local class = classRow(item.class)
		return class
				and string.format(
					"Best: %s. Worst: %s. Change boats at the Port or at the Hoard.",
					class.best,
					string.lower(string.sub(class.worst, 1, 1)) .. string.sub(class.worst, 2)
				)
			or ""
	elseif item.slot == "pet" then
		local def = Config.PETS[item.id]
		local ability = def and def.ability and Config.PET_ABILITIES[def.ability]
		if not ability then
			return "A show pet: no ability, pure glamour. Pets change at the Port or at the Hoard."
		end
		return string.format(
			"%s %s: %s Pets change at the Port or at the Hoard.",
			ability.glyph,
			ability.name,
			ability.effect
		)
	elseif item.slot == "kit" then
		local gear = Config.GEAR[item.gear]
		return "Start every raid carrying it: "
			.. (gear and gear.effect or "")
			.. " A convenience: it is free in the world too."
	elseif item.slot == "emote" then
		return "Cosmetic. Press V (or the emote button) for the emote wheel. Moving stops it."
	elseif item.slot == "victory" then
		return "Cosmetic. Played on the skyship's deck when you win a raid."
	end
	return "Cosmetic only: it changes how you look, never how you play. Yours for good."
end

local function refreshInfo()
	local item = selected and Catalog.get(selected)
	local set, look = ownedSet(), equippedLook()
	info.primary.Visible = false
	info.secondary.Visible = false
	info.robux.Visible = false
	if not item and section ~= "slot" then
		info.rarity.Visible = false
		info.vibe.Visible = false
		if section == "presets" then
			info.name.Text = "Outfits"
			info.blurb.Text = "Save what you are wearing (goblin, boat and style) and put it back on in one press."
			info.detail.Text = "An outfit only ever puts on things you still own."
		else
			info.name.Text = "Trophies"
			info.blurb.Text = "Deeds that pay Shinies once, and some unlock a cosmetic you cannot buy."
			info.detail.Text = "Point at (or press) a trophy to see its reward on your goblin, boat or pet."
		end
		info.secondary.Visible = previewing()
		info.secondary.Text = "RESET"
		return
	end
	if not item then
		info.name.Text = (Catalog.slot(slotId) or { name = "" }).name
		info.rarity.Visible = false
		info.vibe.Visible = false
		info.blurb.Text = "Pick something to try it on."
		info.detail.Text =
			"Shinies are kept forever and earned by playing raids. Raid gold only decides who wins the raid."
		info.secondary.Visible = previewing()
		info.secondary.Text = "RESET"
		return
	end
	info.name.Text = item.name
	local rarity = Catalog.RARITIES[item.rarity]
	info.rarity.Visible = true
	info.rarity.Text = string.upper(rarity.name)
	info.rarity.BackgroundColor3 = rarity.color
	info.vibe.Visible = item.vibe ~= nil
	info.vibe.Text = item.vibe and string.upper(item.vibe) or ""
	info.blurb.Text = item.blurb
	local detail = describe(item)
	if item.award and not owns(item, set) then
		detail = item.award == "weekly_bundle"
				and "Earned, not bought: claim all three of a week's quests at the Captain's Quest Board (it changes each week)."
			or "Earned, not bought: a season prize from the Hall of Records (see the Quest Board's SEASON page)."
	end
	if item.unlock and not owns(item, set) then
		local achievement = Catalog.achievementById[item.unlock]
		local progress = achievementProgress()[item.unlock]
		detail = string.format(
			"Earned, not bought: %s %s",
			achievement and achievement.how or "",
			progress and string.format("(%d / %d)", progress[1], progress[2]) or ""
		)
	end
	info.detail.Text = detail
	local primary = info.primary
	local owned = owns(item, set)
	local premium = premiumInfo(item)
	if owned then
		primary.Visible = true
		if item.slot == "emote" then
			primary.Text = "PLAY IT"
			Ui.setStyle(primary, "good")
		elseif wearing(item, look) then
			local slotDef = Catalog.slot(item.slot)
			if slotDef and slotDef.default == item.id then
				primary.Text = item.slot == "boat" and "SAILING IT" or "WEARING"
				Ui.setStyle(primary, "ghost")
			else
				primary.Text = item.slot == "pet" and "PUT AWAY" or (item.slot == "kit" and "STOP" or "TAKE OFF")
				if item.slot == "boat" then
					primary.Text = "SAILING IT"
					Ui.setStyle(primary, "ghost")
				end
				Ui.setStyle(primary, "wood")
			end
		else
			primary.Text = item.slot == "pet" and "BRING OUT"
				or (item.slot == "kit" and "START WITH IT" or (item.slot == "boat" and "SAIL IT" or "WEAR IT"))
			Ui.setStyle(primary, "good")
		end
	elseif Catalog.forSale(item) then
		primary.Visible = true
		if armed and armed.id == item.id and time() < armed.untilTime then
			primary.Text = "CONFIRM ◆ " .. item.price .. "?"
			Ui.setStyle(primary, "gold")
		elseif shinies() >= item.price then
			primary.Text = "BUY ◆ " .. item.price
			Ui.setStyle(primary, "gold")
		else
			primary.Text = string.format("NEED ◆ %d MORE", item.price - shinies())
			Ui.setStyle(primary, "ghost")
		end
	elseif item.unlock or item.award then
		primary.Visible = true
		primary.Text = item.award and "SEASON PRIZE" or "LOCKED"
		Ui.setStyle(primary, "ghost")
	end
	if premium and not owned then
		info.robux.Visible = true
		info.robux.Text = premium.onSale and ("R$ " .. premium.price) or "ROBUX: NOT ON SALE"
		Ui.setStyle(info.robux, premium.onSale and "premium" or "ghost")
	end
	info.secondary.Visible = previewing()
	info.secondary.Text = "RESET"
end

-- Selecting ---------------------------------------------------------------------------------------------------------------------
local function choose(id)
	selected = id
	previewPreset = nil
	local item = Catalog.get(id)
	if item then
		if item.slot == "emote" or item.slot == "kit" then
			preview = {}
		else
			preview[item.slot] = item.id
			if item.slot == "petskin" then
				preview.pet = item.pet
			end
		end
		showStage(item.slot, item)
	end
	setMessage("")
	refreshCards()
	refreshInfo()
end

local function send(action, a, b)
	shopRemote:FireServer(action, a, b)
end

local function resetPreview()
	preview = {}
	previewPreset = nil
	showStage(slotId, selected and Catalog.get(selected))
	refreshInfo()
end

local function primaryPressed()
	local item = selected and Catalog.get(selected)
	if not item then
		return
	end
	local set, look = ownedSet(), equippedLook()
	if pending[item.id] and time() - pending[item.id] < 3 then
		return
	end
	if owns(item, set) then
		if item.slot == "emote" then
			emoteRemote:FireServer(item.id)
			Shop.close()
			return
		end
		pending[item.id] = time()
		if wearing(item, look) then
			local slotDef = Catalog.slot(item.slot)
			if (slotDef and slotDef.default == item.id) or item.slot == "boat" then
				pending[item.id] = nil
				return
			end
			send("unequip", item.slot)
		else
			send("equip", item.slot, item.id)
		end
		Effects.sound("blip", { speed = 1.3, volume = 0.5 })
		return
	end
	if Catalog.forSale(item) then
		if shinies() < item.price then
			setMessage(
				string.format(
					"You need %d more Shinies. Play raids: every raid pays, banking treasure and winning pay more.",
					item.price - shinies()
				),
				C.danger
			)
			Effects.sound("blip", { speed = 0.7, volume = 0.5 })
			return
		end
		if armed and armed.id == item.id and time() < armed.untilTime then
			armed = nil
			pending[item.id] = time()
			send("buy", item.id)
			setMessage("Buying...", C.inkSoft)
		else
			-- Five seconds to press again (three was too short in a test; a touch player needs time to read).
			armed = { id = item.id, untilTime = time() + 5 }
			setMessage("Press again to buy it for " .. item.price .. " Shinies.", C.ink)
			Effects.sound("blip", { speed = 1.1, volume = 0.5 })
			task.delay(5.05, function()
				if armed and armed.id == item.id and time() >= armed.untilTime then
					armed = nil
					refreshInfo()
				end
			end)
		end
		refreshInfo()
	elseif item.unlock then
		setMessage("This one is a trophy: see how to earn it above.", C.inkSoft)
	elseif item.award then
		setMessage("This one is a season prize: see how to earn it above.", C.inkSoft)
	end
end

local function robuxPressed()
	local item = selected and Catalog.get(selected)
	local premium = item and premiumInfo(item)
	if not premium or not premium.onSale then
		setMessage("Robux purchases are not set up yet. Most things are earned with Shinies.", C.inkSoft)
		return
	end
	send("robux", item.id)
end

-- The rail: slots, outfits, trophies ------------------------------------------------------------------------------------------------
local rebuildGrid
local showFilters

local function railButton(text, order, onClick)
	local b = Ui.button(rail, {
		text = text,
		size = UDim2.new(1, -8, 0, 38),
		textSize = 16,
		style = "parchment",
		order = order,
		font = Ui.BOLD,
	}, onClick)
	b.TextXAlignment = Enum.TextXAlignment.Left
	Ui.pad(b, 12, 0, 6, 0)
	return b
end

local GROUP_ICONS = { fleet = "⛵", goblin = "👺", boat = "🎨", style = "✨", pets = "🐾" }

local function rebuildRail()
	for _, child in ipairs(rail:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(railButtons)
	local set = ownedSet()
	local group = (Catalog.slot(slotId) or Catalog.SLOTS[1]).group
	-- The groups, always in view: Boats, Goblin, Paint, Style, Pets (V13: two to a row).
	local groups = Ui.make("Frame", {
		Name = "Groups",
		Size = UDim2.new(1, -8, 0, math.ceil(#Catalog.GROUPS / 2) * 45 - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
	}, rail)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -3, 0, 39),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, groups)
	for index, g in ipairs(Catalog.GROUPS) do
		Ui.button(groups, {
			text = (GROUP_ICONS[g.id] or "") .. " " .. string.upper(g.id == "pets" and "Pets" or g.name),
			style = g.id == group and section == "slot" and "gold" or "wood",
			order = index,
			textSize = 14,
			name = "group_" .. g.id,
		}, function()
			for _, slot in ipairs(Catalog.SLOTS) do
				if slot.group == g.id then
					section = "slot"
					slotId = slot.id
					break
				end
			end
			petTheme = nil
			selected = nil
			preview = {}
			previewPreset = nil
			rebuildRail()
			rebuildGrid()
			showStage(slotId, nil)
			refreshInfo()
		end)
	end
	local order = 1
	if tab == "locker" then
		for _, entry in ipairs({ { "presets", "★ Outfits" }, { "trophies", "🏆 Trophies" } }) do
			order += 1
			local b = railButton(entry[2], order, function()
				section = entry[1]
				selected = nil
				rebuildRail()
				rebuildGrid()
				refreshInfo()
			end)
			b.Name = entry[1]
			railButtons[entry[1]] = b
		end
	end
	order += 1
	Ui.label(rail, {
		Size = UDim2.new(1, -8, 0, 22),
		Text = string.upper((function()
			for _, g in ipairs(Catalog.GROUPS) do
				if g.id == group then
					return g.name
				end
			end
			return ""
		end)()),
		Font = Ui.TITLE,
		TextSize = 14,
		TextColor3 = C.goldPale,
		LayoutOrder = order,
	})
	for _, slot in ipairs(Catalog.SLOTS) do
		if slot.group == group then
			local have = 0
			for _, item in ipairs(Catalog.bySlot[slot.id]) do
				if owns(item, set) then
					have += 1
				end
			end
			order += 1
			local label = tab == "locker" and string.format("%s  %d", slot.name, have) or slot.name
			local b = railButton(label, order, function()
				section = "slot"
				slotId = slot.id
				selected = nil
				preview = {}
				previewPreset = nil
				rebuildRail()
				rebuildGrid()
				showStage(slotId, nil)
				refreshInfo()
			end)
			b.Name = slot.id
			railButtons[slot.id] = b
		end
	end
	for key, b in pairs(railButtons) do
		local active = (section == "slot" and key == slotId) or (section ~= "slot" and key == section)
		Ui.setStyle(b, active and "gold" or "parchment")
	end
end

-- The grid --------------------------------------------------------------------------------------------------------------------------
local function clearGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(cards)
end

local function makeCard(item, order)
	local rarity = Catalog.RARITIES[item.rarity]
	local card = Ui.make("TextButton", {
		Name = item.id,
		AutoButtonColor = false,
		BackgroundColor3 = C.parchment,
		Text = "",
		LayoutOrder = order,
	}, grid)
	Ui.corner(card, 12)
	local stroke = Ui.stroke(card, rarity.color, 2)
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	Ui.corner(ring, 12)
	Ui.make("UIStroke", { Color = C.gold, Thickness = 4 }, ring)
	card.SelectionImageObject = ring
	local strip =
		Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarity.color, BorderSizePixel = 0 }, card)
	Ui.corner(strip, 4)
	local holder = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 12),
		Size = UDim2.new(1, -16, 0, 84),
		BackgroundColor3 = C.parchmentDark,
		ClipsDescendants = true,
	}, card)
	Ui.corner(holder, 8)
	local ok, err = pcall(thumbnail, item, holder)
	if not ok then
		warn("[Shop] thumbnail " .. item.id .. ": " .. tostring(err))
	end
	Ui.label(card, {
		Position = UDim2.fromOffset(6, 98),
		Size = UDim2.new(1, -12, 0, 30),
		Text = item.name,
		TextSize = 13,
		Font = Ui.BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local state = Ui.label(card, {
		Position = UDim2.new(0, 6, 1, -24),
		Size = UDim2.new(1, -12, 0, 20),
		Text = "",
		TextSize = 15,
		Font = Ui.TITLE,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local check = Ui.label(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✔",
		TextSize = 18,
		TextColor3 = C.white,
		BackgroundColor3 = C.good,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Visible = false,
	})
	Ui.corner(check, 13)
	card.Activated:Connect(function()
		choose(item.id)
		Effects.sound("blip", { speed = 1.6, volume = 0.35 })
	end)
	cards[item.id] = { button = card, state = state, stroke = stroke, check = check }
	return card
end

local function presetSummary(look)
	local names = {}
	for _, slot in ipairs({ "hat", "eyes", "face", "outfit", "back", "livery" }) do
		local item = look[slot] and Catalog.get(look[slot])
		if item then
			table.insert(names, item.name)
		end
	end
	return #names > 0 and table.concat(names, ", ") or "Nothing saved here yet."
end

local function buildPresets()
	local list = presets()
	for index = 1, Config.PROGRESS.PRESETS do
		local preset = list[index]
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 118),
			BackgroundColor3 = C.parchment,
			LayoutOrder = index,
		}, grid)
		Ui.corner(row, 12)
		Ui.stroke(row, C.woodLight, 2)
		local name = Ui.make("TextBox", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 32),
			BackgroundColor3 = C.parchmentDark,
			Font = Ui.TITLE,
			TextSize = 20,
			TextColor3 = C.ink,
			Text = preset and preset.name or ("Outfit " .. index),
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		Ui.corner(name, 8)
		Ui.pad(name, 8, 0, 8, 0)
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(1, -24, 0, 26),
			Text = preset and presetSummary(preset.look or {}) or "Empty: dress up, then save here.",
			TextSize = 13,
			Font = Ui.BODY,
			TextColor3 = C.inkSoft,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Ui.button(row, {
			text = "SAVE CURRENT",
			style = "wood",
			size = UDim2.new(0.5, -18, 0, 38),
			position = UDim2.new(0, 12, 1, -46),
			textSize = 16,
		}, function()
			send("presetsave", index, name.Text)
		end)
		local wear = Ui.button(row, {
			text = "WEAR",
			style = "good",
			size = UDim2.new(0.5, -18, 0, 38),
			position = UDim2.new(0.5, 6, 1, -46),
			textSize = 16,
		}, function()
			send("presetload", index)
			previewPreset = nil
		end)
		wear.Visible = preset ~= nil
		row.MouseEnter:Connect(function()
			if preset then
				previewPreset = preset.look
				showStage("outfit", nil)
				previewChip.Visible = true
			end
		end)
	end
	info.name.Text = "Outfits"
	info.blurb.Text = "Save what you are wearing (goblin, boat and style) and put it back on in one press."
	info.detail.Text = "An outfit only ever puts on things you still own."
end

local function buildTrophies()
	local progress = achievementProgress()
	local done = {}
	for id in string.gmatch(player:GetAttribute("Achievements") or "", "[^,]+") do
		done[id] = true
	end
	for index, achievement in ipairs(Catalog.ACHIEVEMENTS) do
		local p = progress[achievement.id] or { 0, achievement.goal }
		local finished = done[achievement.id]
		local row = Ui.make("TextButton", {
			Size = UDim2.new(1, -10, 0, 100),
			BackgroundColor3 = finished and C.goldPale or C.parchment,
			LayoutOrder = index,
			Text = "",
			AutoButtonColor = false,
			Name = achievement.id,
		}, grid)
		Ui.corner(row, 12)
		Ui.stroke(row, finished and C.goldDeep or C.woodLight, 2)
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 26),
			Text = (finished and "🏆 " or "") .. achievement.name,
			Font = Ui.TITLE,
			TextSize = 19,
		})
		local reward = achievement.reward and Catalog.get(achievement.reward)
		Ui.label(row, {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 36),
			Text = achievement.how
				.. "  Reward: ◆"
				.. achievement.shinies
				.. (reward and (" and the " .. reward.name) or ""),
			Font = Ui.BODY,
			TextSize = 13,
			TextColor3 = C.inkSoft,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local bar = Ui.make("Frame", {
			Position = UDim2.fromOffset(12, 74),
			Size = UDim2.new(1, -110, 0, 14),
			BackgroundColor3 = C.parchmentDark,
		}, row)
		Ui.corner(bar, 7)
		local fill = Ui.make("Frame", {
			Size = UDim2.fromScale(math.clamp(p[1] / math.max(1, p[2]), 0, 1), 1),
			BackgroundColor3 = finished and C.goldDeep or C.good,
		}, bar)
		Ui.corner(fill, 7)
		Ui.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 68),
			Size = UDim2.fromOffset(90, 24),
			Text = finished and "DONE" or string.format("%d / %d", p[1], p[2]),
			Font = Ui.TITLE,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		if reward then
			-- Pointing at (or pressing, on touch and gamepad) a trophy shows its reward on the stage.
			local function show()
				preview = { [reward.slot] = reward.id }
				showStage(reward.slot, reward)
			end
			row.MouseEnter:Connect(show)
			row.Activated:Connect(show)
		end
	end
	info.name.Text = "Trophies"
	info.blurb.Text = "Deeds that pay Shinies once, and some unlock a cosmetic you cannot buy."
	info.detail.Text = "Point at a trophy to see its reward on your goblin, boat or pet."
end

-- V13: the pet grid's theme chips (All, Ocean, Pirate, Magic, Island), over the grid while Pets is open.
local filterBar, filterButtons = nil, {}
local THEME_LABELS = {
	{ nil, "ALL" },
	{ "ocean", "🌊 OCEAN" },
	{ "pirate", "🏴 PIRATE" },
	{ "magic", "✨ MAGIC" },
	{ "island", "🏝 ISLAND" },
}
showFilters = function(on)
	if not filterBar then
		return
	end
	filterBar.Visible = on
	grid.Position = UDim2.fromOffset(548, on and 108 or 70)
	grid.Size = UDim2.fromOffset(W - 560, H - (on and 154 or 116))
	for key, b in pairs(filterButtons) do
		Ui.setStyle(b, key == (petTheme or "all") and "gold" or "wood")
	end
end

local function buildFilters()
	filterBar = Ui.make("Frame", {
		Name = "PetFilters",
		Position = UDim2.fromOffset(548, 70),
		Size = UDim2.fromOffset(W - 560, 32),
		BackgroundTransparency = 1,
		Visible = false,
	}, window)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, filterBar)
	for index, entry in ipairs(THEME_LABELS) do
		local theme, text = entry[1], entry[2]
		filterButtons[theme or "all"] = Ui.button(filterBar, {
			text = text,
			style = "wood",
			size = UDim2.fromOffset(index == 1 and 58 or 84, 30),
			order = index,
			textSize = 12,
			name = "theme_" .. (theme or "all"),
		}, function()
			petTheme = theme
			selected = nil
			rebuildGrid()
		end)
	end
end

rebuildGrid = function()
	clearGrid()
	if section ~= "slot" then
		showFilters(false)
		gridLayout.Parent = nil
		rowsLayout.Parent = grid
		if section == "presets" then
			buildPresets()
		else
			buildTrophies()
		end
		info.rarity.Visible, info.vibe.Visible = false, false
		info.primary.Visible, info.robux.Visible = false, false
		showStage("outfit", nil)
		return
	end
	rowsLayout.Parent = nil
	gridLayout.Parent = grid
	showFilters(slotId == "pet")
	local set = ownedSet()
	local order = 0
	for _, item in ipairs(Catalog.sorted(slotId)) do
		if listed(item, set) and (slotId ~= "pet" or not petTheme or item.theme == petTheme) then
			order += 1
			makeCard(item, order)
		end
	end
	if order == 0 then
		Ui.label(grid, {
			Size = UDim2.fromOffset(400, 60),
			Text = tab == "locker" and "Nothing here yet. Have a look in the SHOP tab." or "Nothing here.",
			TextSize = 16,
			Font = Ui.BODY,
			TextColor3 = C.parchment,
		})
	end
	refreshCards()
	grid.CanvasPosition = Vector2.zero
end

-- Balance and save state ---------------------------------------------------------------------------------------------------------------
local balanceLabel, balanceShown = nil, 0
local SAVE_TEXT = {
	saved = "✔ Saved",
	saving = "Saving...",
	studio = "Studio test: progress resets when Play stops",
	loading = "Opening your saved progress...",
	standin = "Saved progress not open yet: earnings will be added, buying waits",
	newer = "Not saving here (an older server)",
	lost = "Not saving here (opened in another server)",
	off = "Saving is off here",
}

local function refreshBalance(animate)
	local target = shinies()
	if animate and balanceShown ~= target then
		local from = balanceShown
		local started = time()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local p = math.clamp((time() - started) / 0.5, 0, 1)
			balanceLabel.Text = tostring(math.floor(from + (target - from) * p + 0.5))
			if p >= 1 then
				connection:Disconnect()
			end
		end)
	else
		balanceLabel.Text = tostring(target)
	end
	balanceShown = target
	footer.Text = (SAVE_TEXT[player:GetAttribute("SaveState") or ""] or "")
		.. "   |   Earn Shinies by playing raids: banking treasure and winning pay more."
end

-- Building the window -----------------------------------------------------------------------------------------------------------------------
local function layout()
	if not window then
		return
	end
	local size = workspace.CurrentCamera.ViewportSize
	local scale = math.min(size.X / (W + 30), size.Y / (H + 24))
	uiScale.Scale = math.clamp(scale, 0.5, 1.35)
end

local function setTab(name)
	tab = name
	section = "slot"
	selected = nil
	preview = {}
	previewPreset = nil
	for key, b in pairs(tabButtons) do
		Ui.setStyle(b, key == tab and "gold" or "wood")
	end
	rebuildRail()
	rebuildGrid()
	showStage(slotId, nil)
	refreshInfo()
end

local function build()
	gui = Ui.make("ScreenGui", {
		Name = "LootGoblinsWardrobe",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	backdrop = Ui.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
	}, gui)
	backdrop.Activated:Connect(function()
		Shop.close()
	end)
	window = Ui.make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C.wood,
		Active = true,
	}, gui)
	Ui.corner(window, 20)
	Ui.stroke(window, C.goldDeep, 3)
	Ui.make("UIGradient", { Color = ColorSequence.new(C.woodMid, C.wood), Rotation = 90 }, window)
	uiScale = Ui.make("UIScale", {}, window)

	-- Header: tabs, title, balance, close.
	tabButtons.shop = Ui.button(window, {
		text = "SHOP",
		size = UDim2.fromOffset(120, 46),
		position = UDim2.fromOffset(14, 10),
		textSize = 22,
		name = "TabShop",
	}, function()
		setTab("shop")
	end)
	tabButtons.locker = Ui.button(window, {
		text = "LOCKER",
		name = "TabLocker",
		style = "wood",
		size = UDim2.fromOffset(130, 46),
		position = UDim2.fromOffset(142, 10),
		textSize = 22,
	}, function()
		setTab("locker")
	end)
	Ui.label(window, {
		Position = UDim2.fromOffset(290, 8),
		Size = UDim2.fromOffset(380, 50),
		Text = "THE GOBLIN WARDROBE",
		Font = Ui.TITLE,
		TextSize = 30,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local pill = Ui.make("Frame", {
		Position = UDim2.fromOffset(700, 12),
		Size = UDim2.fromOffset(212, 42),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.25,
	}, window)
	Ui.corner(pill, 21)
	Ui.stroke(pill, C.gold, 2)
	Ui.gem(pill, 16, UDim2.new(0, 22, 0.5, 0))
	balanceLabel = Ui.label(pill, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -96, 1, 0),
		Text = "0",
		Font = Ui.TITLE,
		TextSize = 24,
		TextColor3 = C.goldPale,
	})
	local help = Ui.button(pill, {
		text = "?",
		style = "wood",
		size = UDim2.fromOffset(34, 34),
		position = UDim2.new(1, -40, 0.5, -17),
		textSize = 20,
		radius = 17,
	}, function()
		setMessage(
			string.format(
				"A raid pays %d Shinies, +1 per gold banked (up to %d), +%d for winning, and a little for deeds (a steal, an escape, a snatch, clean tricks). Trophies pay once. Max %d a raid.",
				Config.PROGRESS.PARTICIPATION,
				Config.PROGRESS.GOLD_CAP,
				Config.PROGRESS.WIN,
				Config.PROGRESS.RAID_CAP
			),
			C.ink
		)
	end)
	help.Name = "Help"
	local close = Ui.button(window, {
		text = "X",
		font = Ui.BLACK,
		style = "danger",
		size = UDim2.fromOffset(46, 46),
		position = UDim2.fromOffset(W - 60, 10),
		textSize = 24,
		radius = 23,
	}, function()
		Shop.close()
	end)
	close.Name = "Close"

	-- The rail.
	rail = Ui.make("ScrollingFrame", {
		Name = "Rail",
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.fromOffset(176, H - 82),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, window)
	Ui.corner(rail, 12)
	Ui.pad(rail, 6, 8, 6, 8)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, rail)

	-- The stage and the info panel.
	local stagePanel = Ui.make("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(198, 70),
		Size = UDim2.fromOffset(340, H - 82),
		BackgroundColor3 = C.parchment,
	}, window)
	Ui.corner(stagePanel, 14)
	Ui.stroke(stagePanel, C.goldDeep, 2)
	local stageBack = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, VIEW_H),
		BackgroundColor3 = Color3.fromRGB(170, 214, 228),
		ClipsDescendants = true,
		Active = true,
	}, stagePanel)
	Ui.corner(stageBack, 10)
	Ui.make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(196, 232, 244), Color3.fromRGB(240, 220, 170)),
		Rotation = 90,
	}, stageBack)
	stageView = Ui.viewport(stageBack, { fov = 32 })
	overlay = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, stageBack)
	previewChip = Ui.label(stageBack, {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(170, 26),
		Text = "PREVIEW: not worn yet",
		Font = Ui.TITLE,
		TextSize = 14,
		TextColor3 = C.ink,
		BackgroundColor3 = C.goldPale,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(previewChip, 13)
	Ui.label(stageBack, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(240, 18),
		Text = "drag to turn",
		Font = Ui.BODY,
		TextSize = 12,
		TextColor3 = C.inkSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	stageBack.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stage.dragging = true
			stage.dragFrom = input.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not visible then
			return
		end
		if
			stage.dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local from = stage.dragFrom or input.Position
			stage.yaw = (stage.yaw - (input.Position.X - from.X) * 0.6) % 360
			stage.pitch = math.clamp(stage.pitch + (input.Position.Y - from.Y) * 0.2, -10, 35)
			stage.dragFrom = input.Position
			stage.lastTouch = time()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(input.Position.X) > 0.2 then
			stage.yaw = (stage.yaw - input.Position.X * 4) % 360
			stage.lastTouch = time()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stage.dragging = false
		end
	end)

	local infoTop = VIEW_H + 14
	info.name = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(14, infoTop),
		Size = UDim2.new(1, -28, 0, 30),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 24,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	info.rarity = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(14, infoTop + INFO.chips),
		Size = UDim2.fromOffset(104, 22),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 13,
		TextColor3 = C.ink,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.corner(info.rarity, 11)
	info.vibe = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(124, infoTop + INFO.chips),
		Size = UDim2.fromOffset(110, 22),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 13,
		TextColor3 = C.parchment,
		BackgroundColor3 = C.woodMid,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.corner(info.vibe, 11)
	info.blurb = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(14, infoTop + INFO.blurb),
		Size = UDim2.new(1, -28, 0, INFO.blurbH),
		Text = "",
		Font = Ui.BODY,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	info.detail = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(14, infoTop + INFO.detail),
		Size = UDim2.new(1, -28, 0, INFO.detailH),
		Text = "",
		Font = Ui.BODY,
		TextSize = 12,
		TextColor3 = C.inkSoft,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	info.message = Ui.label(stagePanel, {
		Position = UDim2.fromOffset(14, infoTop + INFO.message),
		Size = UDim2.new(1, -28, 0, INFO.messageH),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	info.primary = Ui.button(stagePanel, {
		text = "",
		size = UDim2.fromOffset(196, 46),
		position = UDim2.new(0, 12, 1, -56),
		textSize = 19,
	}, primaryPressed)
	info.primary.Name = "Primary"
	-- Reset sits on the stage it resets; the Robux button (premium items only) shares the row with the main one.
	info.secondary = Ui.button(stageBack, {
		text = "RESET",
		style = "wood",
		size = UDim2.fromOffset(84, 30),
		position = UDim2.new(1, -92, 0, 8),
		textSize = 14,
		name = "Reset",
	}, resetPreview)
	info.robux = Ui.button(stagePanel, {
		text = "",
		style = "premium",
		size = UDim2.fromOffset(112, 46),
		position = UDim2.new(1, -124, 1, -56),
		textSize = 13,
		name = "Robux",
	}, robuxPressed)

	-- The grid.
	grid = Ui.make("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(548, 70),
		Size = UDim2.fromOffset(W - 560, H - 116),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, window)
	Ui.corner(grid, 12)
	Ui.pad(grid, 8, 8, 8, 8)
	-- A grid of cards for items; a list of rows for outfits and trophies (a frame can only hold one layout).
	gridLayout = Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(130, 156),
		CellPadding = UDim2.fromOffset(9, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	rowsLayout = Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	footer = Ui.label(window, {
		Position = UDim2.fromOffset(552, H - 42),
		Size = UDim2.fromOffset(W - 566, 34),
		Text = "",
		Font = Ui.BODY,
		TextSize = 12,
		TextColor3 = C.parchmentDark,
	})

	buildFilters()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	layout()
end

-- The dock: always-on buttons for the wardrobe (and the emote wheel, added by client/Emotes.lua) --------------------------------
local function buildDock()
	local dockGui = Ui.make("ScreenGui", {
		Name = "LootGoblinsDock",
		ResetOnSpawn = false,
		DisplayOrder = 6,
	}, player:WaitForChild("PlayerGui"))
	pcall(function()
		dockGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	dock = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.46, 0),
		Size = UDim2.fromOffset(64, 140),
		BackgroundTransparency = 1,
	}, dockGui)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, dock)
	dockWardrobe = Ui.button(
		dock,
		{ text = "🧥", size = UDim2.fromOffset(60, 60), textSize = 30, radius = 30, order = 1, font = Ui.BOLD },
		function()
			Shop.toggle()
		end
	)
	dockWardrobe.Name = "Wardrobe"
	Ui.label(dockWardrobe, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(58, 16),
		Text = "P",
		TextSize = 12,
		Font = Ui.TITLE,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Name = "Key",
	})
	Shop.dock = dock
	return dockGui
end

-- Opening and closing ---------------------------------------------------------------------------------------------------------------------------
local function bindWhileOpen()
	ContextActionService:BindActionAtPriority("LootGoblinsWardrobeClose", function(_, state)
		if state == Enum.UserInputState.Begin then
			Shop.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("LootGoblinsWardrobeTabs", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			setTab(input.KeyCode == Enum.KeyCode.ButtonL1 and "shop" or "locker")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
end

-- V13: `focus` opens it at one counter of the Port: "goblin" (Madame Ragwort's wardrobe), "pet" (the menagerie),
-- "boat:<class>" (a slipway in the shipyard: that boat chosen, on the stage, its stats showing).
function Shop.open(which, focus)
	if not gui then
		return
	end
	welcomeWaiting = nil -- found it on their own: no card needed
	if which and which ~= tab then
		tab = which
	end
	local focusItem
	if type(focus) == "string" then
		section, selected, preview, previewPreset, petTheme = "slot", nil, {}, nil, nil
		if focus == "pet" then
			slotId = "pet"
		elseif string.sub(focus, 1, 5) == "boat:" then
			slotId = "boat"
			focusItem = "boat_" .. string.sub(focus, 6)
		else
			slotId = "hat"
		end
	end
	visible = true
	gui.Enabled = true
	openedOnce = true
	for key, b in pairs(tabButtons) do
		Ui.setStyle(b, key == tab and "gold" or "wood")
	end
	rebuildRail()
	rebuildGrid()
	-- The stage needs a fresh copy of the goblin each time (they may have respawned or changed avatar).
	clearStage()
	stage.kind = nil
	showStage(slotId, selected and Catalog.get(selected))
	refreshBalance(false)
	setMessage("")
	refreshInfo()
	if focusItem and Catalog.get(focusItem) then
		choose(focusItem)
	end
	window.Position = UDim2.fromScale(0.5, 0.54)
	TweenService:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
		:Play()
	bindWhileOpen()
	local first = grid:FindFirstChildWhichIsA("GuiButton", true)
	Ui.focus(first)
	send("opened")
	Effects.sound("blip", { speed = 1.2, volume = 0.4 })
end

function Shop.close()
	if not visible then
		return
	end
	visible = false
	gui.Enabled = false
	armed = nil
	preview = {}
	previewPreset = nil
	clearStage()
	stage.kind = nil
	ContextActionService:UnbindAction("LootGoblinsWardrobeClose")
	ContextActionService:UnbindAction("LootGoblinsWardrobeTabs")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

function Shop.toggle()
	if visible then
		Shop.close()
	else
		Shop.open()
	end
end

function Shop.isOpen()
	return visible
end

-- The server answered a request (Main routes the ShopResult event here).
function Shop.result(p)
	if p.id then
		pending[p.id] = nil
	end
	if p.ok then
		if p.action == "buy" then
			Effects.chime(Effects.CHIME_GOOD, 0.7)
			local card = cards[p.id]
			if card then
				local scale = Ui.make("UIScale", { Scale = 1.12 }, card.button)
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				task.delay(0.4, function()
					scale:Destroy()
				end)
			end
			if p.equipped then
				local item = Catalog.get(p.id)
				if item then
					preview[item.slot] = nil
				end
			end
			if visible then
				setMessage(p.message or "Bought!", C.good)
			end
		elseif p.action == "equip" or p.action == "unequip" then
			if p.slot then
				preview[p.slot] = nil
			end
			if visible then
				setMessage("")
			end
		elseif p.action == "presetsave" or p.action == "presetload" then
			if visible then
				setMessage(p.message or "", C.good)
				if section == "presets" then
					rebuildGrid()
				end
			end
			Effects.chime({ 1, 1.5 }, 0.5)
		end
	else
		if visible then
			setMessage(p.message or "That did not work.", C.danger)
		end
		Effects.sound("blip", { speed = 0.7, volume = 0.5 })
	end
	if visible then
		refreshCards()
		refreshInfo()
		refreshBalance(true)
		if p.ok and (p.action == "equip" or p.action == "unequip" or p.action == "buy" or p.action == "presetload") then
			showStage(slotId, selected and Catalog.get(selected))
		end
	end
end

-- First visit: a short, skippable welcome (the server sends it once per goblin, ever).
-- V12: the welcome card waits for a calm moment: the goblin standing at home (in the Hoard's ward, nothing in
-- hand) or between raids. V11 showed it the moment a new goblin joined, on top of the launch window, the map and
-- the help card: the first twenty seconds became four things to close. Until then the wardrobe button glows.
-- V13: or standing about in the Port (not watching a raid).
local function atHoard()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or player:GetAttribute("Zone") ~= "raid" or player:GetAttribute("DeployState") ~= "landed" then
		return false
	end
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local marker = generated and generated:FindFirstChild("Landmarks")
	marker = marker and marker:FindFirstChild("HoardMarker")
	local hoard = marker and marker:FindFirstChild("Hoard")
	return hoard ~= nil
		and Vector3.new(root.Position.X - hoard.Position.X, 0, root.Position.Z - hoard.Position.Z).Magnitude
			<= Config.WARD_RADIUS
end

local function calmMoment()
	if player:GetAttribute("Zone") ~= "raid" then
		return not player:GetAttribute("Spectating") and workspace:GetAttribute("RaidPhase") == "port"
	end
	return not player:GetAttribute("CarryingLoot") and atHoard()
end

local showWelcome
function Shop.welcome(p)
	if welcomeWaiting then
		return
	end
	welcomeWaiting = p
	local glow = dockWardrobe and Ui.stroke(dockWardrobe, C.gold, 3)
	task.spawn(function()
		while welcomeWaiting and not calmMoment() do
			if glow then
				glow.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 5)
			end
			task.wait(0.1)
		end
		if glow then
			glow:Destroy()
		end
		if welcomeWaiting then
			local waiting = welcomeWaiting
			welcomeWaiting = nil
			showWelcome(waiting)
		end
	end)
end

showWelcome = function(p)
	local dockGui = dock and dock.Parent
	if not dockGui then
		return
	end
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 84, 0.46, 0),
		Size = UDim2.fromOffset(330, 150),
		BackgroundColor3 = C.parchment,
	}, dockGui)
	Ui.corner(card, 14)
	Ui.stroke(card, C.goldDeep, 3)
	Ui.label(card, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 30),
		Text = p.migrated and "GOBLIN LIFE IS HERE!" or "WELCOME, GOBLIN!",
		Font = Ui.TITLE,
		TextSize = 22,
	})
	Ui.label(card, {
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 56),
		Text = string.format(
			"Here are %d Shinies to spend. Shinies are yours for good: every raid pays more. Dress your goblin, paint your boat, adopt a pet.",
			p.shinies or 0
		),
		Font = Ui.BODY,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	Ui.button(
		card,
		{ text = "OPEN WARDROBE", size = UDim2.fromOffset(180, 40), position = UDim2.new(0, 14, 1, -50), textSize = 17 },
		function()
			card:Destroy()
			Shop.open("shop")
		end
	)
	Ui.button(card, {
		text = "LATER",
		style = "ghost",
		size = UDim2.fromOffset(110, 40),
		position = UDim2.new(1, -124, 1, -50),
		textSize = 17,
	}, function()
		card:Destroy()
	end)
	task.delay(14, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Shop.start()
	chooseSize()
	build()
	buildDock()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.DPadRight then
			Shop.toggle()
		end
	end)
	for _, attribute in ipairs({ "Shinies", "Owned", "Look", "Kit", "SaveState", "Presets", "Achievements" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if visible then
				if attribute == "Shinies" or attribute == "SaveState" then
					refreshBalance(true)
				end
				if
					(attribute == "Presets" and section == "presets")
					or (attribute == "Achievements" and section == "trophies")
				then
					rebuildGrid()
				end
				refreshCards()
				refreshInfo()
			end
		end)
	end
	-- It gets out of the way when the game needs the screen: climbing into a cannon, flying, picking up treasure.
	for _, attribute in ipairs({ "DeployState", "CarryingLoot", "Diving" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			local state = player:GetAttribute("DeployState")
			if
				visible
				and (
					player:GetAttribute("CarryingLoot")
					or player:GetAttribute("Diving")
					or state == "loaded"
					or state == "fuse"
					or state == "diving"
				)
			then
				Shop.close()
			end
		end)
	end
	-- V13: the Port's counters (the wardrobe, the menagerie, each slipway in the shipyard) open it at their page.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local focus = who == player and prompt:GetAttribute("OpensWardrobe")
		if focus then
			Shop.open("shop", focus)
		end
	end)
	RunService.RenderStepped:Connect(animateStage)
	-- V13: the dock (wardrobe and emotes) is a Port thing. In a raid it shows only at the Hoard, where pets and boats can
	-- change; P opens the wardrobe anywhere. Until it has been opened once, its button glows gently in the Port.
	task.spawn(function()
		while true do
			task.wait(0.4)
			if dock then
				local inPort = player:GetAttribute("Zone") ~= "raid"
				dock.Visible = (inPort and not player:GetAttribute("Spectating")) or atHoard()
				if dockWardrobe and not openedOnce then
					dockWardrobe.BackgroundColor3 = (inPort and math.floor(time() / 0.8) % 2 == 0) and C.goldPale
						or C.gold
				end
			end
		end
	end)
end

return Shop

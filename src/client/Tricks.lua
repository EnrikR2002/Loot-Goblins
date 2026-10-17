-- The trick callouts (V9): what you see when your boat does something stylish in the air.
--
-- The inspiration is Jet Set Radio's attitude: tricks are part of ordinary travel, and the game shouts them
-- at you in chunky, tilted, loud colour. Nothing here is copied from it (no names, no art, no music): the
-- callouts are this game's own trick names in big tilted letters that pop in, wobble and fly off, a combo
-- count that climbs while you stay in the air, and a landing call (clean or sketchy) at the end.
--
-- Other players' tricks are shown over their boat (a short-range label), so a spectator can tell a boat
-- spinning in the air on purpose from one that was hit.
--
-- V11: callouts wear the goblin's chosen callout style (shared/StyleFx.lua CALLOUTS): your own style on your
-- screen, each other goblin's style over their boat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local StyleFx = require(Shared:WaitForChild("StyleFx"))

local Tricks = {}

local player = Players.LocalPlayer
local gui, holder
local combo = 0
local paletteIndex = 0

local function styleOf(who)
	local look = Catalog.decodeLook(who and who:GetAttribute("Look"))
	return StyleFx.CALLOUTS[look.callout] or StyleFx.CALLOUTS.callout_classic
end

local function nextColor(style)
	local palette = (style or styleOf(player)).palette
	paletteIndex = paletteIndex % #palette + 1
	return palette[paletteIndex]
end

-- Dresses a label in a callout style (font, outline, a gradient or a comic-book backing).
local function dress(label, style, stroke)
	label.Font = style.font
	label.TextStrokeColor3 = style.stroke
	if stroke then
		stroke.Color = style.stroke
	end
	if style.gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = style.gradient
		gradient.Rotation = 90
		gradient.Parent = label
	end
	if style.back then
		-- A comic-book backing that hugs the words (a full-width panel hid the middle of the screen).
		-- (Only for on-screen callouts sized in pixels; a label filling a billboard keeps its size.)
		local height = label.Size.Y.Offset
		if height > 0 then
			local size = math.floor(height * 0.78)
			label.TextScaled = false
			label.TextSize = size
			local bounds = TextService:GetTextSize(label.Text, size, label.Font, Vector2.new(2000, size * 2))
			label.Size = UDim2.fromOffset(bounds.X + 28, height)
		end
		label.BackgroundTransparency = 0.2
		label.BackgroundColor3 = style.back[math.random(1, #style.back)]
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = label
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "LootGoblinsTricks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	holder = Instance.new("Frame")
	holder.Name = "Callouts"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromOffset(700, 220)
	holder.Parent = gui
end

-- One callout: pops in big and tilted, holds, then flies up and fades.
local function callout(text, color, size, tilt, yOffset, hold)
	if not gui then
		build()
	end
	local style = styleOf(player)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, math.random(-40, 40), 0.5, yOffset or 0)
	label.Size = UDim2.fromOffset(640, size)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(20, 10, 30)
	label.TextStrokeTransparency = 0
	label.Rotation = tilt
	label.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 10, 30)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	dress(label, style, stroke)
	if style.wobble then
		TweenService:Create(
			label,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = -tilt }
		):Play()
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 })
		:Play()
	task.delay(0.16, function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Rotation = -tilt * 0.4 }):Play()
	end)
	task.delay(hold or 0.8, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = label.Position - UDim2.fromOffset(0, 70),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			task.delay(0.4, function()
				label:Destroy()
			end)
		end
	end)
end

-- A trick started (shown as it begins, so the name and the motion arrive together).
function Tricks.started(name)
	combo += 1
	local tilt = (combo % 2 == 0) and 7 or -7
	callout(name, nextColor(), 70, tilt, 0, 0.7)
	if combo >= 2 then
		callout(string.format("x%d COMBO!", combo), nextColor(), 46, -tilt * 1.4, 64, 0.9)
	end
end

-- Down again.
function Tricks.landed(count)
	if count and count > 0 then
		local words = count >= 4 and "OUTRAGEOUS!"
			or (count == 3 and "FRESH!" or (count == 2 and "SMOOTH!" or "CLEAN!"))
		callout(words, nextColor(), 64, -4, 10, 1)
		callout(string.format("+ SPEED   + BOOST  (x%d)", count), Color3.fromRGB(255, 255, 255), 30, 3, 70, 1)
	end
	combo = 0
end

function Tricks.sketchy()
	callout("SKETCHY!", Color3.fromRGB(255, 120, 90), 58, 9, 10, 0.9)
	combo = 0
end

function Tricks.reset()
	combo = 0
end

-- Someone else's trick: a short-range label over their boat for a moment, in their callout style.
function Tricks.other(position, name, userId)
	local style = styleOf(userId and Players:GetPlayerByUserId(userId))
	local anchor = Instance.new("Part")
	anchor.Name = "TrickLabel"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 14, 0))
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 46)
	board.MaxDistance = 320
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = name
	label.TextColor3 = nextColor(style)
	label.TextStrokeTransparency = 0
	label.Rotation = math.random(-8, 8)
	dress(label, style, nil)
	label.Parent = board
	TweenService:Create(anchor, TweenInfo.new(1.1), { CFrame = anchor.CFrame + Vector3.new(0, 10, 0) }):Play()
	TweenService
		:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		:Play()
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

return Tricks

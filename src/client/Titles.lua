-- Titles over goblins' heads (V13.3): "Old Sea Dog", "Regatta Ace", "Pirate Champion". A title is a catalogue item in
-- the `title` slot (bought, a trophy, or a season reward); the server puts it in the goblin's Look attribute like
-- everything else they wear, and every client draws it from there: a small line of letters over the head, in the
-- title's own colours (shared/StyleFx.lua: StyleFx.TITLES), within TITLE_RANGE studs of the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local StyleFx = require(Shared:WaitForChild("StyleFx"))

local Titles = {}

local TITLE_RANGE = 90
local shown = {} -- player -> { gui, id }

local function clear(player)
	local entry = shown[player]
	if entry then
		entry.gui:Destroy()
		shown[player] = nil
	end
end

local function refresh(player)
	local look = Catalog.decodeLook(player:GetAttribute("Look"))
	local id = look.title
	local style = id and StyleFx.TITLES[id]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local entry = shown[player]
	if not style or not head then
		clear(player)
		return
	end
	if entry and entry.id == id and entry.gui.Adornee == head and entry.gui.Parent then
		return
	end
	clear(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GoblinTitle"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.9, 0)
	gui.MaxDistance = TITLE_RANGE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = (style.glyph and (style.glyph .. " ") or "") .. style.text
	label.TextColor3 = style.color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = style.stroke
	stroke.Thickness = 1.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	if style.gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = style.gradient
		gradient.Rotation = 90
		gradient.Parent = label
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	shown[player] = { gui = gui, id = id }
end

local function watch(player)
	player:GetAttributeChangedSignal("Look"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refresh(player)
	end)
	if player.Character then
		task.spawn(refresh, player)
	end
end

function Titles.start()
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	-- A head replaced by the avatar loading (V10's lesson) is picked up here.
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in ipairs(Players:GetPlayers()) do
				refresh(player)
			end
		end
	end)
end

return Titles

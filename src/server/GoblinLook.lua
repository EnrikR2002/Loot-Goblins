-- Every player is a goblin (V10, docs/ART_DIRECTION.md "Goblins"), dressed in what they chose (V11, Goblin Life).
-- The look comes from the player's Look attribute, which only server/Progress.lua writes (from what they own); the
-- dressing itself is shared/Wardrobe.lua, the same code the shop's preview uses.
--
-- Purely cosmetic: every piece is welded to the body and is massless, non-colliding, never hit by rays or touches, so
-- movement, hitboxes, grapples and the Poltergoblin's body copy are exactly what they were.
--
-- When it runs: avatar loading replaces the head and the body colours just after a character spawns (the V10
-- lesson), so the look is applied when the appearance has loaded, again a moment after spawning (Main), and whenever
-- the Look attribute changes. Wardrobe.dress is safe to call any number of times: it rebuilds only when something
-- changed and otherwise just re-applies colours and hiding.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))

local GoblinLook = {}

function GoblinLook.apply(player, character)
	character = character or player.Character
	if not character or not character.Parent or player.Character ~= character then
		return
	end
	local ok, err = pcall(Wardrobe.dress, character, Catalog.decodeLook(player:GetAttribute("Look")))
	if not ok then
		warn("[GoblinLook] " .. player.Name .. ": " .. tostring(err))
	end
end

function GoblinLook.watch(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		GoblinLook.apply(player, character)
	end)
	player:GetAttributeChangedSignal("Look"):Connect(function()
		GoblinLook.apply(player)
	end)
end

return GoblinLook

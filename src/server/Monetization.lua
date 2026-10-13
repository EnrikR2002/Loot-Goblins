-- Robux (V7): the legitimate plumbing, switched OFF until real products exist.
--
-- No product id is invented here. Config.MONETIZATION.PRODUCTS maps a Developer Product id (a
-- number from the Creator Dashboard) to a grant. It is EMPTY on purpose: until a human creates the
-- products and pastes their ids, every function below does nothing and the shop shows no Robux
-- buttons. Setup is written down in docs/reports/2026-10-13-v7-skyfall.md ("Monetization setup").
--
-- What is built, and how it behaves once an id is filled in:
--   * the only way a purchase is granted is MarketplaceService.ProcessReceipt, on the server;
--   * the receipt is looked up by PurchaseId in the saved profile, so a receipt that arrives twice (a
--     crash, a retry, two servers) grants once and answers PurchaseGranted both times;
--   * the grant is only confirmed (PurchaseGranted) after the profile has been SAVED; if the save
--     fails the answer is NotProcessedYet and Roblox sends the receipt again;
--   * an unknown product, or a goblin who has left, is NotProcessedYet (never granted blind).
-- Nothing sold is essential: every pet is also bought with Shinies, and gear is free in the world.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)

local Monetization = {}

-- The product (if any) that sells this pet.
function Monetization.productFor(petId)
	for productId, grant in pairs(Config.MONETIZATION.PRODUCTS) do
		if grant.pet == petId then
			return productId
		end
	end
	return nil
end

local function process(receipt)
	local grant = Config.MONETIZATION.PRODUCTS[receipt.ProductId]
	if not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not Progress.profileOf(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local fresh = Progress.noteReceipt(player, receipt.PurchaseId)
	if fresh == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if fresh and grant.pet then
		Progress.grantPet(player, grant.pet)
	end
	-- Confirm only once it is on disk.
	if not Progress.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if fresh then
		Net.toast(
			player,
			"Thank you! " .. (Config.PETS[grant.pet] and Config.PETS[grant.pet].name or "Your purchase") .. " is yours."
		)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- The shop's Robux button: only prompts if a product is configured for it.
function Monetization.prompt(player, petId)
	local productId = Monetization.productFor(petId)
	if not productId then
		Net.toast(player, "Robux purchases are not set up yet. Earn Shinies and buy it that way.")
		return false
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end

function Monetization.init()
	if next(Config.MONETIZATION.PRODUCTS) == nil then
		return -- nothing to process; do not take over ProcessReceipt for nothing
	end
	MarketplaceService.ProcessReceipt = process
end

-- For tests (no real purchase): run a fake receipt through the same path.
Monetization.process = process

return Monetization

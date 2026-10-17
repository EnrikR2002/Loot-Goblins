-- Lightweight, privacy-conscious signals for tuning the economy later (V11). Roblox's own AnalyticsService only: no
-- external service, no personal data, nothing the game needs to work. Every call is wrapped, so analytics being
-- unavailable (Studio, an outage) never breaks a purchase or a raid.
--
-- What is sent:
--   economy (Shinies): sources (raid, achievement, welcome, refund) and sinks (shop), with the balance after;
--   custom events: ShopOpened, FirstShiniesPurchase, CosmeticEquipped, PetEquipped, AchievementUnlocked,
--   PremiumPurchase, PurchaseFailed, SaveFailed;
--   onboarding steps: 1 joined, 2 first raid finished, 3 first Shinies purchase, 4 first item equipped.
-- Event names are a fixed list (no ids glued into names), so the dashboard stays readable.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local CURRENCY = "Shinies"

local function safe(fn)
	local ok = pcall(fn)
	return ok
end

-- Shinies in (source) or out (sink). transaction: "Gameplay" | "Shop" | "Onboarding" | "IAP" | "ContextualPurchase".
function Analytics.shinies(player, isSink, amount, balance, transaction, sku)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			isSink and Enum.AnalyticsEconomyFlowType.Sink or Enum.AnalyticsEconomyFlowType.Source,
			CURRENCY,
			amount,
			balance,
			transaction,
			sku or ""
		)
	end)
end

function Analytics.event(player, name, value, fields)
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end)
end

local ONBOARDING = { "Joined", "FirstRaidFinished", "FirstShiniesPurchase", "FirstItemEquipped" }
function Analytics.onboarding(player, step)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, ONBOARDING[step] or ("Step" .. step))
	end)
end

return Analytics

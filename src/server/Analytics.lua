-- Lightweight, privacy-conscious signals for tuning the economy later (V11). Roblox's own AnalyticsService only: no
-- external service, no personal data, nothing the game needs to work. Every call is wrapped, so analytics being
-- unavailable (Studio, an outage) never breaks a purchase or a raid.
--
-- What is sent:
--   economy (Shinies): sources (raid, achievement, welcome, refund, V13.3 game, quest, season, expedition, challenge)
--   and sinks (shop, V13.3 sanctuary), with the balance after;
--   custom events: ShopOpened, FirstShiniesPurchase, CosmeticEquipped, PetEquipped, AchievementUnlocked,
--   PremiumPurchase, PurchaseFailed, SaveFailed; V13.3: PortGamePlayed, QuestClaimed, ChallengePlayed, RaidJoined,
--   SessionSummary, ReturnSession, and the MILESTONES below;
--   onboarding steps: 1 joined, 2 first raid finished, 3 first Shinies purchase, 4 first item equipped;
--   V13.3, the RaidContinuation funnel, once per play session: 1 a raid finished, 2 another raid joined, 3 that one
--   finished. Its question is the one that matters most: does a goblin who finishes a raid choose to play another?
-- Event names are a fixed list (no ids glued into names), so the dashboard stays readable. Custom fields go under
-- Roblox's own keys (CustomField01 to 03), as "name=value" (V11 passed its own field names, which Roblox does not
-- define: those breakdowns may never have arrived).
--
-- MILESTONES (V13.3) are reported once per goblin, ever (the profile remembers: profile.milestones): FirstRaidCompleted,
-- SecondRaidStarted, SecondRaidCompleted, FirstMinigamePlayed, FirstQuestCompleted, FirstExpeditionCollected,
-- FirstSpecialtyBoat. How to read them: docs/GAME_DESIGN.md, "Retention instrumentation".
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local CURRENCY = "Shinies"
local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local function safe(fn)
	local ok = pcall(fn)
	return ok
end

-- { reason = "store" } -> { CustomField01 = "reason=store" } (sorted by name; at most three).
local function fieldsOf(fields)
	if type(fields) ~= "table" then
		return nil
	end
	local names = {}
	for name in pairs(fields) do
		table.insert(names, tostring(name))
	end
	table.sort(names)
	local out = {}
	for i, name in ipairs(names) do
		if i > #FIELD_KEYS then
			break
		end
		local ok, key = pcall(function()
			return Enum.AnalyticsCustomFieldKeys[FIELD_KEYS[i]].Name
		end)
		out[ok and key or FIELD_KEYS[i]] = name .. "=" .. string.sub(tostring(fields[name]), 1, 40)
	end
	return out
end
Analytics.fieldsOf = fieldsOf

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
		local custom = fieldsOf(fields)
		if custom then
			AnalyticsService:LogCustomEvent(player, name, value or 1, custom)
		else
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end
	end)
end

local ONBOARDING = { "Joined", "FirstRaidFinished", "FirstShiniesPurchase", "FirstItemEquipped" }
function Analytics.onboarding(player, step)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, ONBOARDING[step] or ("Step" .. step))
	end)
end

-- V13.3: a first that matters for retention, reported once per goblin (profile.milestones remembers). Returns true if
-- it was new (the caller saves the profile).
Analytics.MILESTONES = {
	FirstRaidCompleted = true,
	SecondRaidStarted = true,
	SecondRaidCompleted = true,
	FirstMinigamePlayed = true,
	FirstQuestCompleted = true,
	FirstExpeditionCollected = true,
	FirstSpecialtyBoat = true,
}
function Analytics.milestone(player, profile, name, unix)
	if not Analytics.MILESTONES[name] or type(profile) ~= "table" or type(profile.milestones) ~= "table" then
		return false
	end
	if profile.milestones[name] then
		return false
	end
	profile.milestones[name] = math.floor(unix or os.time())
	Analytics.event(player, name, 1)
	return true
end

-- V13.3: the RaidContinuation funnel, one per play session (a session id from the server). step 1: a raid finished;
-- 2: another raid joined after it; 3: that raid finished.
local CONTINUATION = { "RaidFinished", "NextRaidJoined", "NextRaidFinished" }
function Analytics.continuation(player, sessionId, step)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, "RaidContinuation", sessionId, step, CONTINUATION[step])
	end)
end

return Analytics

-- Robux receipts for Developer Products (V11). Pure logic with its dependencies passed in, so every failure case can
-- be tested without a real purchase. server/Monetization.lua plugs it into MarketplaceService.ProcessReceipt.
--
-- The rules:
--   1. An unknown product id is never granted: "retry" (Roblox keeps the receipt; a human may map the id later).
--   2. A goblin who is not in this server, or whose saved profile is not open here (still loading, opened
--      elsewhere, the store down), is not granted here: "retry". Roblox calls ProcessReceipt again when they join.
--   3. The receipt's PurchaseId is recorded in the profile TOGETHER with the grant, in memory, and the profile is
--      saved. Only a successful save answers "granted" (PurchaseGranted). If the save fails the answer is "retry",
--      and the grant stays in memory to go out with the next save.
--   4. A receipt already recorded grants nothing again. It still needs its record on disk before "granted", so a
--      repeat of a receipt whose first save failed saves again and only then confirms.
--   5. A permanent item paid for twice (two purchase windows racing) is not lost money: the second payment becomes
--      Shinies (Config.MONETIZATION.DUPLICATE_SHINIES) and the goblin is told.
local Receipts = {}

function Receipts.has(profile, purchaseId)
	purchaseId = tostring(purchaseId)
	for _, id in ipairs(profile.receipts) do
		if id == purchaseId then
			return true
		end
	end
	return false
end

-- Remembers a receipt, dropping the oldest beyond `keep` (Roblox stops re-sending a receipt long before 500 newer
-- purchases have been made by the same goblin).
function Receipts.add(profile, purchaseId, keep)
	table.insert(profile.receipts, tostring(purchaseId))
	while #profile.receipts > (keep or 500) do
		table.remove(profile.receipts, 1)
	end
end

-- deps:
--   product(productId)   -> the Config.MONETIZATION entry for a configured Developer Product id, or nil
--   session(userId)      -> { profile = table, ready = bool } for a goblin in this server, or nil
--   grant(session, entry, receipt) -> a description of what was given (applied to session.profile, no yielding)
--   save(session)        -> true once the profile is on disk (may yield)
--   keep                 receipts to remember
-- Returns "granted" | "retry", and a reason for the logs.
function Receipts.process(receipt, deps)
	if type(receipt) ~= "table" or receipt.PurchaseId == nil then
		return "retry", "malformed"
	end
	local entry = deps.product(receipt.ProductId)
	if not entry then
		return "retry", "unknown product"
	end
	local session = deps.session(receipt.PlayerId)
	if not session or not session.profile then
		return "retry", "player not here"
	end
	if not session.ready then
		return "retry", "profile not open"
	end
	local profile = session.profile
	local fresh = not Receipts.has(profile, receipt.PurchaseId)
	local given
	if fresh then
		Receipts.add(profile, receipt.PurchaseId, deps.keep)
		given = deps.grant(session, entry, receipt)
	end
	if not deps.save(session) then
		return "retry", fresh and "granted in memory, save failed" or "repeat, save failed"
	end
	return "granted", fresh and (given or "granted") or "repeat"
end

return Receipts

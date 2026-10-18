-- Robux (V7 plumbing, rebuilt for V11). Switched OFF until real products exist: no id or price is invented here.
--
-- Config.MONETIZATION.PRODUCTS lists what COULD be sold: a key, the kind of Roblox product ("pass" for a Game Pass,
-- "product" for a Developer Product), its id from the Creator Dashboard (nil until a human creates it) and the
-- catalogue items it grants. Nothing is offered unless SALES_ENABLED is true AND the entry has an id. Setup and
-- testing: docs/MONETIZATION.md.
--
-- Game Passes (recommended for permanent items): Roblox itself remembers who owns them. On joining (once the saved
-- profile is open) every configured pass is checked with UserOwnsGamePassAsync and what it grants is added to the
-- profile; a purchase made in this server is granted from PromptGamePassPurchaseFinished (a server event).
-- Developer Products: granted only through ProcessReceipt and server/Receipts.lua: idempotent by PurchaseId, recorded
-- in the profile with the grant, confirmed (PurchaseGranted) only after that profile is saved.
-- The client never says what was bought; it only asks to see a purchase window for a key.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Economy = require(script.Parent.Economy)
local Receipts = require(script.Parent.Receipts)
local Analytics = require(script.Parent.Analytics)

local Monetization = {}

local M = Config.MONETIZATION
local byProductId = {} -- Developer Product id -> key
local byPassId = {} -- Game Pass id -> key
local prompting = {} -- player -> { key, until }: one purchase window at a time, per goblin

-- What a configured entry is (or nil if it is not configured: no id, unknown kind, no known item).
local function entryFor(key)
	local entry = M.PRODUCTS[key]
	if type(entry) ~= "table" or type(entry.id) ~= "number" then
		return nil
	end
	if entry.kind ~= "pass" and entry.kind ~= "product" then
		return nil
	end
	return entry
end

-- Checks the table once at start-up and says what is wrong in the output (a typo should never sell nothing).
function Monetization.validate()
	local problems = {}
	local seenIds = {}
	for key, entry in pairs(M.PRODUCTS) do
		if type(entry) ~= "table" then
			table.insert(problems, key .. ": not a table")
		else
			if entry.kind ~= "pass" and entry.kind ~= "product" then
				table.insert(problems, key .. ': kind must be "pass" or "product"')
			end
			if
				entry.id ~= nil and (type(entry.id) ~= "number" or entry.id <= 0 or entry.id ~= math.floor(entry.id))
			then
				table.insert(problems, key .. ": id must be a whole number from the Creator Dashboard")
			end
			if entry.id and seenIds[entry.id] then
				table.insert(problems, key .. ": the same id as " .. seenIds[entry.id])
			end
			if entry.id then
				seenIds[entry.id] = key
			end
			if type(entry.grants) ~= "table" or #entry.grants == 0 then
				table.insert(problems, key .. ": grants nothing")
			else
				for _, id in ipairs(entry.grants) do
					if not Catalog.get(id) then
						table.insert(problems, key .. ": grants an unknown item " .. tostring(id))
					end
				end
			end
		end
	end
	for _, item in ipairs(Catalog.items) do
		if item.premium and not M.PRODUCTS[item.premium] then
			table.insert(problems, item.id .. ": its premium key " .. item.premium .. " is not in Config.MONETIZATION")
		end
	end
	return problems
end

-- The key that sells this catalogue item, if it is on sale right now.
function Monetization.keyFor(itemId)
	local item = Catalog.get(itemId)
	if not item or not item.premium then
		return nil
	end
	return M.SALES_ENABLED and entryFor(item.premium) and item.premium or nil
end

-- Grants -------------------------------------------------------------------------------------------------------------
local function grantEntry(session, key, entry, source)
	local profile = session.profile
	local fresh = Economy.grant(profile, entry.grants, source, os.time(), Config.PROGRESS.HISTORY)
	if #fresh == 0 and source == "robux" then
		-- Everything it grants was already owned (two purchase windows raced). The payment is not lost.
		Economy.addShinies(profile, M.DUPLICATE_SHINIES)
		Net.toast(
			session.player,
			string.format("You already owned that, so it became %d Shinies instead.", M.DUPLICATE_SHINIES)
		)
		Analytics.shinies(session.player, false, M.DUPLICATE_SHINIES, profile.shinies, "IAP", "duplicate:" .. key)
		return "duplicate"
	end
	local names = {}
	for _, id in ipairs(fresh) do
		table.insert(names, Catalog.get(id).name)
	end
	if #names > 0 then
		Net.send(session.player, "Premium", { items = fresh, names = names })
	end
	Analytics.event(session.player, "PremiumPurchase", 1, { key = key, source = source })
	return table.concat(fresh, ",")
end

-- Developer Product receipts --------------------------------------------------------------------------------------------
local function receiptDeps()
	return {
		keep = Config.PROGRESS.RECEIPTS_KEEP,
		product = function(productId)
			local key = byProductId[productId]
			local entry = key and entryFor(key)
			return entry and { key = key, entry = entry } or nil
		end,
		session = function(userId)
			local s = Progress.sessionByUserId(userId)
			if not s then
				return nil
			end
			return { profile = s.profile, ready = s.status == "ready", player = s.player }
		end,
		grant = function(session, product)
			local given = grantEntry(session, product.key, product.entry, "robux")
			Progress.granted(session.player, true)
			return given
		end,
		save = function(session)
			return Progress.saveNow(session.player)
		end,
	}
end

local function processReceipt(receipt)
	local decision, why = Receipts.process(receipt, receiptDeps())
	if decision == "granted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	warn(
		"[Monetization] receipt " .. tostring(receipt and receipt.PurchaseId) .. " not processed yet: " .. tostring(why)
	)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
Monetization.processReceipt = processReceipt -- for tests with simulated receipts

-- Game passes ----------------------------------------------------------------------------------------------------------
local function owns(player, passId)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return result
		end
		task.wait(attempt)
	end
	return false -- unknown: what the profile already holds stays held
end

-- Once a goblin's profile is open: add anything their game passes grant that the profile does not hold yet.
function Monetization.checkPasses(player)
	local s = Progress.session(player)
	if not s or s.status ~= "ready" then
		return
	end
	for passId, key in pairs(byPassId) do
		local entry = entryFor(key)
		if entry and owns(player, passId) and player.Parent then
			local fresh = Economy.grant(s.profile, entry.grants, "pass", os.time(), Config.PROGRESS.HISTORY)
			if #fresh > 0 then
				Progress.granted(player, false)
			end
		end
	end
end

-- Prompts ------------------------------------------------------------------------------------------------------------
-- The shop's Robux button sends the item id. Refused (with a reason) unless it is really on sale, not owned, and the
-- goblin's profile is open (so the grant has somewhere durable to go).
function Monetization.prompt(player, itemId)
	local item = Catalog.get(itemId)
	local key = item and item.premium
	local entry = key and entryFor(key)
	if not item or not M.SALES_ENABLED or not entry then
		Net.send(player, "ShopResult", {
			action = "robux",
			ok = false,
			code = "notonsale",
			id = itemId,
			message = "That is not on sale for Robux yet.",
		})
		return false
	end
	local s = Progress.session(player)
	if not s or s.status ~= "ready" then
		Net.send(player, "ShopResult", {
			action = "robux",
			ok = false,
			code = "unsaved",
			id = itemId,
			message = "Purchases wait until your saved progress is open.",
		})
		return false
	end
	local allOwned = true
	for _, id in ipairs(entry.grants) do
		if not Economy.owns(s.profile, id) then
			allOwned = false
		end
	end
	if allOwned then
		Net.send(
			player,
			"ShopResult",
			{ action = "robux", ok = false, code = "owned", id = itemId, message = "You already own that." }
		)
		return false
	end
	local pending = prompting[player]
	if pending and time() < pending.untilTime then
		return false
	end
	prompting[player] = { key = key, untilTime = time() + 10 }
	if entry.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, entry.id)
	else
		MarketplaceService:PromptProductPurchase(player, entry.id)
	end
	return true
end

-- Prices for the shop: fetched from Roblox for configured products only, published for clients as one attribute
-- (key -> price in Robux). A product whose price cannot be read is not shown as buyable.
local function publishPrices()
	local prices = {}
	for key in pairs(M.PRODUCTS) do
		local entry = entryFor(key)
		if entry and M.SALES_ENABLED then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(
					entry.id,
					entry.kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
				)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
	end
	local parts = {}
	for key, price in pairs(prices) do
		table.insert(parts, key .. "=" .. price)
	end
	workspace:SetAttribute("PremiumPrices", table.concat(parts, ";"))
	-- In Studio, unconfigured premium items are shown (marked not on sale) so the team can see them.
	workspace:SetAttribute("PremiumPreview", RunService:IsStudio() and M.SHOW_UNCONFIGURED_IN_STUDIO or false)
end

function Monetization.init()
	for _, problem in ipairs(Monetization.validate()) do
		warn("[Monetization] " .. problem)
	end
	local hasProducts = false
	for key in pairs(M.PRODUCTS) do
		local entry = entryFor(key)
		if entry and entry.kind == "product" then
			byProductId[entry.id] = key
			hasProducts = true
		elseif entry and entry.kind == "pass" then
			byPassId[entry.id] = key
		end
	end
	-- Only take ProcessReceipt over when there is a Developer Product to process.
	if hasProducts then
		MarketplaceService.ProcessReceipt = processReceipt
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		prompting[player] = nil
		local key = byPassId[passId]
		local entry = key and entryFor(key)
		local s = Progress.session(player)
		if purchased and entry and s then
			grantEntry(s, key, entry, "pass")
			Progress.granted(player, true)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
		for player in pairs(prompting) do
			if player.UserId == userId then
				prompting[player] = nil
			end
		end
	end)
	Progress.Opened:Connect(function(player)
		task.spawn(Monetization.checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		prompting[player] = nil
	end)
	task.spawn(publishPrices)
end

-- For tests: the configured-entry lookup tables, so a test can map a fake product id to a key.
function Monetization.mapProductForTest(productId, key)
	byProductId[productId] = key
end

return Monetization

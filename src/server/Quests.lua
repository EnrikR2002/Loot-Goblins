-- THE CAPTAIN'S QUEST BOARD (V13.3): three daily and three weekly quests, the same for everyone on the day
-- (shared/Seasons.lua chooses them and holds every rule). This module is the server's side of it:
--
--   PROGRESS   from the server's own events only: Progress.Deed (a steal, a bank, an escape, a trick, a Port game...),
--              and each raid's end (Progress.RaidRewarded: played, banked, top three). A finished quest says so at
--              once ("QuestDone": a short line on the screen) and waits at the board.
--   CLAIMING   at the Quest Board (a prompt opens the panel; client/PortBoard.lua) or the Port screen's 📜 chip:
--              ShopRequest("questclaim", "day" | "week", index). The real profile must be open (like buying).
--   RESETS     a goblin's quests roll over the moment anything happens after midnight UTC (or Monday, for the weekly
--              ones), and every half minute anyway while they are in a server; whatever was finished and not claimed
--              is paid then, and the week's cosmetic too when all three weekly quests were claimed (never lost).
--   THE BOARD  a big board by the boarding pier; every client writes today's quests and its own progress on it.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Palette = require(Shared:WaitForChild("Palette"))
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Economy = require(script.Parent.Economy)
local Analytics = require(script.Parent.Analytics)

local Quests = {}

local rgb = Color3.fromRGB

local function unix()
	return os.time()
end

-- What a rollover paid (finished quests nobody claimed; the week's cosmetic): granted and told.
local function settleRollover(s, rolled)
	if not rolled or (rolled.shinies or 0) <= 0 and not rolled.bundle then
		return
	end
	local player = s.player
	if rolled.bundle and rolled.bundle.item then
		Economy.grant(s.profile, { rolled.bundle.item }, "quest", unix(), Config.PROGRESS.HISTORY)
	end
	if (rolled.shinies or 0) > 0 then
		Analytics.shinies(player, false, rolled.shinies, s.profile.shinies, "Gameplay", "quest:rollover")
	end
	local item = rolled.bundle and rolled.bundle.item and Catalog.get(rolled.bundle.item)
	Net.send(player, "QuestRollover", {
		shinies = rolled.shinies or 0,
		count = rolled.count or 0,
		item = item and item.id or nil,
		itemName = item and item.name or nil,
	})
	Progress.markChanged(player, true)
	Progress.checkAchievements(player)
end

local function ensure(s)
	local rolled = Seasons.ensureQuests(s.profile, unix(), Progress.ownsFn(s))
	settleRollover(s, rolled)
end

-- The player's quests as an attribute (no clocks in it: the client counts down to the resets itself).
local function publish(s)
	local player = s.player
	if not player.Parent then
		return
	end
	if not s.profile.quests.day then
		Seasons.ensureQuests(s.profile, unix(), Progress.ownsFn(s))
	end
	local view = Seasons.questView(s.profile, unix())
	view.dayLeft, view.weekLeft = nil, nil
	local ok, text = pcall(HttpService.JSONEncode, HttpService, view)
	if ok and text ~= s.questsSent then
		s.questsSent = text
		player:SetAttribute("Quests", text)
	end
end

local function record(player, s, event, amount, detail)
	local done, rolled = Seasons.recordQuest(s.profile, event, amount, detail, unix(), Progress.ownsFn(s))
	settleRollover(s, rolled)
	for _, finished in ipairs(done) do
		Net.send(player, "QuestDone", {
			kind = finished.kind,
			index = finished.index,
			text = finished.def.text,
			shinies = Seasons.questReward(finished.def),
		})
		Progress.milestone(player, "FirstQuestCompleted")
	end
	-- Worth saving, but not urgently (a crash loses a little progress, never a claim).
	Progress.markChanged(player, false)
end

-- ShopRequest("questclaim", kind, index).
local function claim(s, kind, index)
	local player = s.player
	if kind ~= "day" and kind ~= "week" then
		return
	end
	if not Progress.isReady(s) then
		Net.send(player, "ShopResult", {
			action = "questclaim",
			ok = false,
			code = "unsaved",
			message = "Claiming waits until your saved progress is open (a few seconds after joining).",
			balance = s.profile.shinies,
		})
		return
	end
	local result = Seasons.claimQuest(s.profile, kind, tonumber(index), unix(), Progress.ownsFn(s))
	settleRollover(s, result.rolled)
	local message
	if result.ok then
		message = string.format("Quest done: +%d Shinies!", result.shinies)
		Analytics.shinies(player, false, result.shinies, s.profile.shinies, "Gameplay", "quest:" .. result.def.id)
		Analytics.event(player, "QuestClaimed", 1, { quest = result.def.id, kind = kind })
		if result.bundle then
			if result.bundle.item then
				Economy.grant(s.profile, { result.bundle.item }, "quest", unix(), Config.PROGRESS.HISTORY)
				local item = Catalog.get(result.bundle.item)
				message = string.format(
					"Every quest this week done: +%d Shinies and the %s!",
					result.shinies,
					item and item.name or "week's prize"
				)
			elseif result.bundle.shinies then
				message =
					string.format("Every quest this week done: +%d Shinies!", result.shinies + result.bundle.shinies)
			end
		end
		Progress.markChanged(player, true)
		Progress.checkAchievements(player)
	elseif result.code == "notdone" then
		message = "Not finished yet."
	elseif result.code == "already" then
		message = "Already claimed."
	end
	Net.send(player, "ShopResult", {
		action = "questclaim",
		ok = result.ok,
		code = result.code,
		message = message,
		balance = s.profile.shinies,
		bundle = result.bundle and (result.bundle.item or true) or nil,
	})
	Net.send(player, "QuestClaimed", {
		ok = result.ok,
		kind = kind,
		index = index,
		shinies = result.ok and result.shinies or nil,
		bundle = result.ok and result.bundle ~= nil or nil,
	})
end

-- The board in the Port ----------------------------------------------------------------------------------------------------
local function build(kit)
	local at = PortGames.world(-34, 6, -70)
	local toward = PortGames.world(0, 6, 0)
	local base = CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
	for _, x in ipairs({ -8, 8 }) do
		kit.part(
			"QuestBoardPost",
			Vector3.new(1.2, 14, 1.2),
			base * CFrame.new(x, 7, 0),
			Palette.WOOD_DARK,
			Enum.Material.Wood
		)
	end
	local board = kit.board(
		"QuestBoard",
		Vector3.new(15, 10, 0.6),
		base * CFrame.new(0, 9.4, 0),
		"",
		Palette.GOLD,
		rgb(60, 40, 26),
		kit.core
	)
	board.Name = "QuestBoard"
	kit.board(
		"QuestBoardTitle",
		Vector3.new(16, 2.4, 0.5),
		base * CFrame.new(0, 15.6, 0),
		"THE CAPTAIN'S QUESTS",
		Palette.GOLD,
		rgb(110, 44, 150),
		kit.core
	)
	kit.deco(
		"QuestRoof",
		Vector3.new(19, 0.6, 4),
		base * CFrame.new(0, 17.4, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
		rgb(196, 70, 54),
		Enum.Material.Slate
	)
	for i = 0, 2 do
		kit.deco(
			"QuestScroll",
			Vector3.new(1.2, 0.5, 0.5),
			base * CFrame.new(-5 + i * 5, 4.2, -0.6) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(244, 232, 204),
			Enum.Material.SmoothPlastic,
			{ cyl = true }
		)
	end
	kit.shopkeeper(
		"Captain",
		base * CFrame.new(10.5, 0.2, -1.8) * CFrame.Angles(0, math.rad(-25), 0),
		rgb(40, 60, 120),
		"tricorn"
	)
	local _, pad = kit.prompt(
		"QuestBoardPrompt",
		base * CFrame.new(0, 3, -3.5),
		"The Captain's Quests",
		"Read the board",
		{ OpensPanel = "quests" },
		14
	)
	local _ = pad
end

function Quests.init(kit)
	local built, err = pcall(build, kit)
	if not built then
		warn("[Quests] board: " .. tostring(err))
	end
	Progress.actions.questclaim = claim
	table.insert(Progress.publishers, publish)
	Progress.Deed:Connect(function(player, s, event, amount, detail)
		record(player, s, event, amount, detail)
	end)
	Progress.RaidRewarded:Connect(function(player, s, result)
		record(player, s, "raid", 1)
		if result.banked then
			record(player, s, "bankraid", 1)
		end
		if result.place and result.place <= 3 and (result.gold or 0) > 0 then
			record(player, s, "podium", 1)
		end
	end)
	Progress.Opened:Connect(function(player)
		local s = Progress.session(player)
		if s then
			ensure(s)
			publish(s)
		end
	end)
	-- The day can turn while a goblin plays.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Progress.session(player)
				if s then
					local before = s.profile.quests.day
					ensure(s)
					if s.profile.quests.day ~= before then
						publish(s)
					end
				end
			end
		end
	end)
end

return Quests

-- The small rewards of sailing (V5): coins, timed runs and salvage. Searuns.lua lays them out;
-- this module decides who picked what up and what it was worth.
--
--   COINS    Drive (or walk, or swim) through one and it is yours: no button, no stopping, and
--            a boat's reach is wide enough that it works at full boost. A coin goes into your
--            PURSE. Each one also shaves the boat's boost cooldown and patches its hull a
--            little, so a trail of them is worth taking for its own sake. Coins come back after
--            COIN_RESPAWN seconds, for the next goblin along.
--   PURSE    Ten coins are worth 1 gold, paid when you are next at the Hoard, up to
--            COIN_GOLD_CAP gold a raid. Treasure stays the real score: the cap is about one
--            near-island treasure, and nobody wins a raid on coins.
--   RUNS     A timed run starts when a boat passes the hoop at either end and ends at the
--            other, hoops in order. It pays coins once a raid (more under par) and keeps the
--            best time on its signs, with a name, for the others to beat.
--   SALVAGE  A floating crate where a patrol ship went down, where a storm blew itself out,
--            and a few adrift each raid. Coins, a keg, and a hull patch.
--
-- The server decides all of it from where hulls and goblins actually are. The client only
-- hides a coin a moment early so it feels instant (Main.client.lua); it never claims one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Kegs = require(script.Parent.Kegs)

local Coins = {}

local CELL = 64
local STEP = 0.05 -- Seconds between checks: a boat at full boost moves 8 studs in that time.

local refs
local coins = {} -- { part, value, position, takenAt }
local grid = {} -- cell key -> { coin, ... }
local taken = {} -- coins waiting to come back
local salvage = {} -- { part, position, diesAt }
local state = {} -- player -> { purse, gold, last, run, runDone = {}, runWait }
local best = {} -- run name -> { time, name }  (kept across raids: a record is for the session)
local accumulator = 0
local random = Random.new()

local GOLD = Color3.fromRGB(255, 215, 60)

local function now()
	return workspace:GetServerTimeNow()
end

local function key(cx, cz)
	return cx * 4096 + cz
end

local function stateOf(player)
	local s = state[player]
	if not s then
		s = { purse = 0, gold = 0, runDone = {} }
		state[player] = s
	end
	return s
end

local function publish(player, s)
	player:SetAttribute("Coins", s.purse)
	player:SetAttribute("CoinGold", s.gold)
end

-- Where a player is for collecting purposes: their boat's hull if they are aboard one (a wide
-- reach, so coins come easily at speed), otherwise themselves.
local function collector(player)
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return nil
	end
	local seat = humanoid.SeatPart
	local boat = seat and Boats.boatOf(seat)
	if boat and boat.state == "float" then
		return boat.hull.Position, Config.COIN_BOAT_REACH, boat, root
	end
	return root.Position, Config.COIN_FOOT_REACH, nil, root
end

-- Coins -----------------------------------------------------------------------------
local function take(coin, player, boat)
	local t = now()
	coin.takenAt = t
	coin.part.Transparency = 1
	table.insert(taken, coin)
	local s = stateOf(player)
	s.purse += coin.value
	publish(player, s)
	if boat then
		-- A trail of coins keeps a boat boosting and afloat.
		Boats.refund(boat, Config.COIN_BOOST_REFUND * coin.value)
		Boats.patch(boat, Config.COIN_REPAIR * coin.value)
	end
	Net.send(player, "Coin", { position = coin.position, value = coin.value, purse = s.purse })
end

local function collectAt(player, position, reach, boat)
	local cx, cz = math.floor(position.X / CELL), math.floor(position.Z / CELL)
	for ox = -1, 1 do
		for oz = -1, 1 do
			local cell = grid[key(cx + ox, cz + oz)]
			if cell then
				for _, coin in ipairs(cell) do
					if not coin.takenAt then
						local offset = coin.position - position
						if
							offset.X * offset.X + offset.Z * offset.Z <= reach * reach
							and math.abs(offset.Y) <= Config.COIN_HEIGHT
						then
							take(coin, player, boat)
						end
					end
				end
			end
		end
	end
end

-- Salvage -----------------------------------------------------------------------------
-- A crate floating at `position` for SALVAGE_LIFETIME seconds.
function Coins.dropSalvage(position, why)
	if #salvage >= Config.SALVAGE_MAX then
		return
	end
	local at = Vector3.new(position.X, 1.2, position.Z)
	local part = Util.part(
		"Salvage",
		Vector3.new(5, 5, 5),
		CFrame.new(at) * CFrame.Angles(0.2, random:NextNumber(0, 6), 0.15),
		Color3.fromRGB(150, 105, 60),
		Enum.Material.WoodPlanks,
		refs.folders.coins
	)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 26
	glow.Brightness = 1.6
	glow.Parent = part
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.MaxDistance = 380
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "SALVAGE"
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = part
	table.insert(salvage, { part = part, position = at, diesAt = now() + Config.SALVAGE_LIFETIME })
	if why then
		Net.feed("Salvage is floating where " .. why .. ".", GOLD)
	end
end

local function claimSalvage(crate, player, boat)
	crate.part:Destroy()
	local s = stateOf(player)
	s.purse += Config.SALVAGE_COINS
	publish(player, s)
	if boat then
		Boats.patch(boat, Config.SALVAGE_REPAIR)
		Boats.refund(boat, Config.BOAT_BOOST_COOLDOWN)
	end
	if (player:GetAttribute("Kegs") or 0) < Config.KEG_MAX then
		Kegs.give(player)
	end
	Net.send(
		player,
		"Coin",
		{ position = crate.position, value = Config.SALVAGE_COINS, purse = s.purse, salvage = true }
	)
	Net.toast(player, string.format("SALVAGE! +%d coins, a keg, and the hull patched", Config.SALVAGE_COINS))
end

local function tickSalvage(t)
	for i = #salvage, 1, -1 do
		local crate = salvage[i]
		local gone = t >= crate.diesAt
		if not gone then
			for _, player in ipairs(Players:GetPlayers()) do
				local position, reach, boat = collector(player)
				if
					position
					and Util.flatDistance(position, crate.position) <= reach + 4
					and math.abs(position.Y - 1) < 14
				then
					claimSalvage(crate, player, boat)
					gone = true
					break
				end
			end
		elseif crate.part.Parent then
			crate.part:Destroy()
		end
		if gone then
			table.remove(salvage, i)
		end
	end
end

-- Timed runs ----------------------------------------------------------------------------
local function setLabels(run)
	local record = best[run.name]
	local text = string.format("%s - par %.1f s", run.name, run.par)
	if record then
		text ..= string.format(" - best %.1f %s", record.time, record.name)
	end
	for _, label in ipairs(run.labels) do
		label.Text = text
	end
end

local function finishRun(player, s, t)
	local active = s.run
	local run = active.def
	local time = t - active.startedAt
	s.run = nil
	s.runWait = t + 4
	local underPar = time <= run.par
	local record = best[run.name]
	local isBest = not record or time < record.time
	if isBest then
		best[run.name] = { time = time, name = player.DisplayName }
		setLabels(run)
	end
	local reward = 0
	if not s.runDone[run.name] then
		reward = Config.RUN_COINS
		s.runDone[run.name] = "done"
	end
	if underPar and s.runDone[run.name] ~= "par" then
		reward += Config.RUN_PAR_COINS
		s.runDone[run.name] = "par"
	end
	if reward > 0 then
		s.purse += reward
		publish(player, s)
	end
	Net.send(
		player,
		"Run",
		{ name = run.name, time = time, par = run.par, underPar = underPar, best = isBest, coins = reward }
	)
	if isBest then
		Net.feed(
			string.format("%s ran %s in %.1f s: the time to beat!", player.DisplayName, run.name, time),
			Color3.fromRGB(255, 185, 80)
		)
	end
end

local function tickRuns(player, s, position, t)
	local active = s.run
	if active then
		local run = active.def
		if t > active.startedAt + run.par * Config.RUN_GIVE_UP then
			s.run = nil -- Wandered off: no fuss.
			return
		end
		local index = active.index + active.way
		local target = run.checkpoints[index]
		if target and Util.flatDistance(position, target) <= Config.RUN_REACH then
			active.index = index
			if run.checkpoints[index + active.way] == nil then
				finishRun(player, s, t)
			end
		end
		return
	end
	if t < (s.runWait or 0) then
		return
	end
	for _, run in ipairs(refs.runs) do
		local count = #run.checkpoints
		local atFirst = Util.flatDistance(position, run.checkpoints[1]) <= Config.RUN_REACH
		local atLast = not atFirst and Util.flatDistance(position, run.checkpoints[count]) <= Config.RUN_REACH
		if atFirst or atLast then
			s.run = { def = run, index = atFirst and 1 or count, way = atFirst and 1 or -1, startedAt = t }
			Net.send(player, "Run", { name = run.name, par = run.par, started = true })
			return
		end
	end
end

-- The purse ---------------------------------------------------------------------------
local function cashIn(player, s, root)
	if s.purse < Config.COINS_PER_GOLD or s.gold >= Config.COIN_GOLD_CAP then
		return
	end
	local hoard = refs.hoard.position
	if Util.flatDistance(root.Position, hoard) > Config.BANK_RADIUS + 4 or math.abs(root.Position.Y - hoard.Y) > 14 then
		return
	end
	local gold = math.min(math.floor(s.purse / Config.COINS_PER_GOLD), Config.COIN_GOLD_CAP - s.gold)
	s.purse -= gold * Config.COINS_PER_GOLD
	s.gold += gold
	publish(player, s)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Gold")
	if stat then
		stat.Value += gold
	end
	Net.send(player, "CoinsBanked", { gold = gold, total = s.gold, cap = Config.COIN_GOLD_CAP })
	Net.feed(string.format("%s cashed in a purse of coins (+%d gold)", player.DisplayName, gold), GOLD)
end

-- Public API ----------------------------------------------------------------------------
function Coins.build(worldRefs)
	refs = worldRefs
	for _, entry in ipairs(refs.coins or {}) do
		local coin = { part = entry.part, value = entry.value, position = entry.position, takenAt = nil }
		table.insert(coins, coin)
		local k = key(math.floor(coin.position.X / CELL), math.floor(coin.position.Z / CELL))
		grid[k] = grid[k] or {}
		table.insert(grid[k], coin)
	end
	for _, run in ipairs(refs.runs or {}) do
		setLabels(run)
	end
end

function Coins.count()
	return #coins
end

-- raidActive: gold is only paid during a raid (coins can be picked up any time).
function Coins.tick(dt, raidActive)
	accumulator += dt
	if accumulator < STEP then
		return
	end
	accumulator = 0
	local t = now()
	for i = #taken, 1, -1 do
		local coin = taken[i]
		if t - coin.takenAt >= Config.COIN_RESPAWN then
			coin.takenAt = nil
			coin.part.Transparency = 0
			table.remove(taken, i)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local position, reach, boat, root = collector(player)
		if position then
			local s = stateOf(player)
			-- Check where they are and half way back to where they were, so nothing is skipped
			-- between two checks at speed.
			collectAt(player, position, reach, boat)
			if s.last and (s.last - position).Magnitude > reach and (s.last - position).Magnitude < 60 then
				collectAt(player, s.last:Lerp(position, 0.5), reach, boat)
			end
			s.last = position
			if boat then
				tickRuns(player, s, position, t)
			else
				s.run = nil
			end
			if raidActive then
				cashIn(player, s, root)
			end
		end
	end
	if #salvage > 0 then
		tickSalvage(t)
	end
end

-- A new raid: every coin back, every purse empty, a few crates adrift on the runs.
function Coins.reset()
	for _, coin in ipairs(taken) do
		coin.takenAt = nil
		coin.part.Transparency = 0
	end
	table.clear(taken)
	for _, crate in ipairs(salvage) do
		crate.part:Destroy()
	end
	table.clear(salvage)
	for player, s in pairs(state) do
		s.purse, s.gold, s.run, s.runDone, s.last = 0, 0, nil, {}, nil
		if player.Parent then
			publish(player, s)
		end
	end
	if #coins > 0 then
		for _ = 1, Config.SALVAGE_ADRIFT do
			local near = coins[random:NextInteger(1, #coins)].position
			Coins.dropSalvage(near + Vector3.new(random:NextNumber(-14, 14), 0, random:NextNumber(-14, 14)))
		end
	end
end

function Coins.forget(player)
	state[player] = nil
end

return Coins

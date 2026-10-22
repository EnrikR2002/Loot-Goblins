-- Touch buttons for the essential loop (V12). Only on a touch screen; a keyboard or a controller never sees them.
--
-- Through V11 a phone could steal (prompts are tappable) and swing a sword, but could not fire a cannon (only CLICK,
-- SPACE or A did), call a boat (B), boost, hop or trick at the wheel, grapple or throw: the six-minute raid had no
-- way home but swimming. These are Roblox's own context-action touch buttons, bound only while they mean something
-- (FIRE while aiming a cannon, BOOST / HOP / TRICK at the wheel, BOAT / HOOK / THROW on foot) and calling the same
-- functions the keys call, so nothing a button does differs from its key. Not yet tried on a real phone (V13).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TouchControls = {}

local player = Players.LocalPlayer
local bound = {}

-- actions: { name = { title, mode(s), fn } }. Main passes the functions (the same ones its keys call).
local ACTIONS
local function bind(name, title, fn, slot)
	if bound[name] then
		return
	end
	bound[name] = true
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle(name, title)
	-- Stacked above Roblox's jump button, from the right edge inward.
	pcall(function()
		ContextActionService:SetPosition(name, UDim2.new(1, -95 - (slot % 2) * 70, 1, -170 - math.floor(slot / 2) * 70))
	end)
end

local function unbind(name)
	if bound[name] then
		bound[name] = nil
		ContextActionService:UnbindAction(name)
	end
end

local function wanted(mode)
	local want = {}
	for name, action in pairs(ACTIONS) do
		if action.when(mode) then
			want[name] = action
		end
	end
	return want
end

local lastKey = nil
local function refresh(modeOf)
	local mode = modeOf()
	local carrying = player:GetAttribute("CarryingLoot") ~= nil
	local key = mode .. (carrying and "+" or "")
	if key == lastKey then
		return
	end
	lastKey = key
	local want = wanted({ mode = mode, carrying = carrying })
	for name in pairs(bound) do
		if not want[name] then
			unbind(name)
		end
	end
	for name, action in pairs(want) do
		bind(name, action.title, action.fn, action.slot)
	end
end

-- fns = { fire, call, grapple, throw, boost, hop, trick, gun (V13.2) }; modeOf() returns "ship", "aim", "flight", "boat", "foot" or
-- (V13) "port", where nothing is bound: the Port's own buttons are on its screen.
-- force: bind them on a computer too (a Studio check of which actions each mode binds; Roblox draws the buttons
-- only on a touch screen, so how they look and feel needs a phone or Studio's device emulator). The game never
-- passes it.
function TouchControls.start(fns, modeOf, force)
	if not UserInputService.TouchEnabled and not force then
		return
	end
	ACTIONS = {
		LootGoblinsTouchFire = {
			title = "FIRE",
			slot = 0,
			fn = fns.fire,
			when = function(s)
				return s.mode == "aim"
			end,
		},
		LootGoblinsTouchBoat = {
			title = "BOAT",
			slot = 0,
			fn = fns.call,
			when = function(s)
				return s.mode == "foot"
			end,
		},
		LootGoblinsTouchHook = {
			title = "HOOK",
			slot = 1,
			fn = fns.grapple,
			when = function(s)
				return s.mode == "foot"
			end,
		},
		LootGoblinsTouchThrow = {
			title = "THROW",
			slot = 2,
			fn = fns.throw,
			when = function(s)
				return s.mode == "foot" and s.carrying
			end,
		},
		LootGoblinsTouchBoost = {
			title = "BOOST",
			slot = 0,
			fn = fns.boost,
			when = function(s)
				return s.mode == "boat"
			end,
		},
		LootGoblinsTouchHop = {
			title = "HOP",
			slot = 1,
			fn = fns.hop,
			when = function(s)
				return s.mode == "boat"
			end,
		},
		LootGoblinsTouchTrick = {
			title = "STUNT", -- V13: a trick in the air, the boat's ability on the water
			slot = 2,
			fn = fns.trick,
			when = function(s)
				return s.mode == "boat"
			end,
		},
		LootGoblinsTouchGun = {
			title = "GUN", -- V13.2: the bow gun, fired where the middle of the screen looks
			slot = 3,
			fn = fns.gun,
			when = function(s)
				return s.mode == "boat" and fns.gun ~= nil
			end,
		},
	}
	RunService.Heartbeat:Connect(function()
		refresh(modeOf)
	end)
end

return TouchControls

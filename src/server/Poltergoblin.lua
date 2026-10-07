-- Poltergoblin (was Soul Unbound, inspired by Yone's E from League of Legends).
--
-- E: your goblin's spirit dashes out and your body stays behind, frozen and
-- tethered. For a few seconds the spirit is faster and can do anything: fight,
-- grapple, grab loot. Then it snaps back to the body (or press E again), and
-- every player it hurt takes part of that damage again (the echo).
--
-- Rules that keep it from being a free escape button:
--   * Loot rides the tether: whatever the spirit holds comes back to the body.
--     It never carries loot forward, only lets you grab and rewind.
--   * The tether has a length. Stray too far and you snap back early.
--   * Your body is vulnerable. A sword hit on it shatters the spirit: you snap
--     back hurt, with no echo, and any loot the spirit held drops where it was.
--   * The Hoard's ward repels spirits: no casting inside it, and a spirit that
--     enters it is pulled back. Spirits can't bank.
--
-- The server owns the timer, the body, the marks and the return. The client
-- only predicts its own dash so the key feels instant.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Movement = require(script.Parent.Movement)
local Loot = require(script.Parent.Loot)

local Poltergoblin = {}

local SPIRIT_COLOR = Color3.fromRGB(120, 255, 170)
local STRETCHED_COLOR = Color3.fromRGB(255, 90, 70)
local MARK_COLOR = Color3.fromRGB(190, 90, 255)
local LETHAL_MARK_COLOR = Color3.fromRGB(255, 255, 255)

local spirits = {}
local readyAt = {}
local refs

local function now()
	return workspace:GetServerTimeNow()
end

local function inWard(position)
	return Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS
end

function Poltergoblin.init(worldRefs)
	refs = worldRefs
end

function Poltergoblin.isSpirit(player)
	return spirits[player] ~= nil
end

-- The body left behind is a frozen, darkened copy of the character, labeled so
-- everyone knows they can hit it.
local function makeBody(character, player)
	local archivable = character.Archivable
	character.Archivable = true
	local body = character:Clone()
	character.Archivable = archivable
	if not body then
		return nil
	end

	body.Name = character.Name .. "Body"
	for _, item in ipairs(body:GetDescendants()) do
		-- Billboards and highlights catch marks and carrier reveals on this player.
		if
			item:IsA("BaseScript")
			or item:IsA("Tool")
			or item:IsA("ForceField")
			or item:IsA("BillboardGui")
			or item:IsA("Highlight")
			or item:IsA("Constraint")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			item.EvaluateStateMachine = false
		end
	end

	local shell = Instance.new("Highlight")
	shell.FillColor = Color3.fromRGB(20, 50, 35)
	shell.FillTransparency = 0.45
	shell.OutlineColor = SPIRIT_COLOR
	shell.OutlineTransparency = 0.2
	shell.DepthMode = Enum.HighlightDepthMode.Occluded
	shell.Parent = body

	local head = body:FindFirstChild("Head") or body:FindFirstChild("HumanoidRootPart")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Name = "BodyTag"
		gui.Size = UDim2.fromOffset(170, 36)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		gui.MaxDistance = 160
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = SPIRIT_COLOR
		label.TextStrokeTransparency = 0.2
		label.Text = string.upper(player.DisplayName) .. "'S BODY - HIT IT!"
		label.Parent = gui
		gui.Parent = head
	end
	body.Parent = refs.folders.bodies
	return body
end

local function start(player)
	local character, humanoid, root = Util.getCharacterParts(player)
	if not root or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	local t = now()
	if t < (readyAt[player] or 0) then
		return
	end
	if inWard(root.Position) then
		Net.toast(player, "The Hoard's ward blocks Poltergoblin")
		return
	end
	readyAt[player] = t + Config.POLTER_COOLDOWN

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local bodyCFrame = CFrame.lookAt(root.Position, root.Position + look)
	local body = makeBody(character, player)

	-- A beam ties the spirit to the spot where the body stands.
	local anchor = Instance.new("Attachment")
	anchor.Name = "PolterBodyAnchor"
	anchor.Position = bodyCFrame.Position
	anchor.Parent = workspace.Terrain

	local tetherEnd = Instance.new("Attachment")
	tetherEnd.Name = "PolterTether"
	tetherEnd.Parent = root

	local tether = Instance.new("Beam")
	tether.Attachment0 = anchor
	tether.Attachment1 = tetherEnd
	tether.Color = ColorSequence.new(SPIRIT_COLOR)
	tether.LightEmission = 1
	tether.FaceCamera = true
	tether.Width0 = 0.6
	tether.Width1 = 0.2
	tether.Transparency = NumberSequence.new(0.1, 0.5)
	tether.Parent = anchor

	local trailTop = Instance.new("Attachment")
	trailTop.Name = "PolterTrailTop"
	trailTop.Position = Vector3.new(0, 1.2, 0)
	trailTop.Parent = root
	local trailBottom = Instance.new("Attachment")
	trailBottom.Name = "PolterTrailBottom"
	trailBottom.Position = Vector3.new(0, -1.2, 0)
	trailBottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = trailTop
	trail.Attachment1 = trailBottom
	trail.Color = ColorSequence.new(SPIRIT_COLOR)
	trail.LightEmission = 1
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Parent = trailTop

	local glow = Instance.new("Highlight")
	glow.Name = "PolterGlow"
	glow.FillColor = SPIRIT_COLOR
	glow.FillTransparency = 0.65
	glow.OutlineColor = SPIRIT_COLOR
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = character

	local visuals = { anchor, tetherEnd, trailTop, trailBottom, glow }
	if body then
		table.insert(visuals, body)
	end
	spirits[player] = {
		character = character,
		body = body,
		bodyCFrame = bodyCFrame,
		startedAt = t,
		endsAt = t + Config.POLTER_DURATION,
		marks = {},
		visuals = visuals,
		tether = tether,
		stretched = false,
	}
	-- The client reads these for its HUD and to predict its own dash.
	player:SetAttribute("PolterReadyAt", readyAt[player])
	player:SetAttribute("PolterEndsAt", t + Config.POLTER_DURATION)
	player:SetAttribute("PolterBody", bodyCFrame.Position)
	Net.broadcast("Polter", { phase = "cast", from = bodyCFrame.Position, userId = player.UserId })
end

-- Every attack that hurts a player calls this. Only a spirit's hits leave a mark.
function Poltergoblin.markDamage(attacker, victimHumanoid, amount)
	local spirit = spirits[attacker]
	if not spirit or amount <= 0 then
		return
	end
	local mark = spirit.marks[victimHumanoid]
	if not mark then
		local victimRoot = victimHumanoid.Parent and victimHumanoid.Parent:FindFirstChild("HumanoidRootPart")
		if not victimRoot then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "PolterMark"
		gui.Size = UDim2.fromOffset(44, 44)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 200

		local diamond = Instance.new("Frame")
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Position = UDim2.fromScale(0.5, 0.5)
		diamond.Size = UDim2.fromOffset(26, 26)
		diamond.Rotation = 45
		diamond.BackgroundColor3 = MARK_COLOR
		diamond.BackgroundTransparency = 0.15
		diamond.Parent = gui
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.new(1, 1, 1)
		outline.Thickness = 2
		outline.Parent = diamond

		-- The number is the damage the echo will repeat.
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui

		gui.Parent = victimRoot
		mark = { damage = 0, gui = gui, diamond = diamond, label = label }
		spirit.marks[victimHumanoid] = mark
	end
	mark.damage += amount
	mark.label.Text = tostring(math.floor(mark.damage * Config.POLTER_ECHO_FRACTION + 0.5))
end

-- outcome:
--   "return"  snap back to the body, then the marks echo
--   "death"   only the echo (the spirit died where it stood)
--   "shatter" someone struck the body: drop the spirit's loot, snap back, no echo
--   "cancel"  clean up only (respawn, raid reset, leaving)
function Poltergoblin.finish(player, outcome, byPlayer)
	local spirit = spirits[player]
	if not spirit then
		return
	end
	spirits[player] = nil
	player:SetAttribute("PolterEndsAt", nil)
	player:SetAttribute("PolterBody", nil)
	Movement.setBoost(player, nil)
	for _, item in ipairs(spirit.visuals) do
		item:Destroy()
	end

	local character, humanoid, root = Util.getCharacterParts(player)
	local alive = character ~= nil and character == spirit.character and humanoid.Health > 0
	if outcome == "shatter" then
		Loot.dropFor(player, "shatter", byPlayer)
	end
	if (outcome == "return" or outcome == "shatter") and alive then
		local seat = humanoid.SeatPart
		if seat then
			local seatWeld = seat:FindFirstChild("SeatWeld")
			if seatWeld then
				seatWeld:Destroy()
			end
			humanoid.Sit = false
		end
		-- Carried loot is welded to the root, so it rides the tether back too.
		local from = root.Position
		root.CFrame = spirit.bodyCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		Net.broadcast("Polter", {
			phase = outcome,
			from = from,
			to = spirit.bodyCFrame.Position,
			userId = player.UserId,
		})
	end

	local hits = {}
	for victimHumanoid, mark in pairs(spirit.marks) do
		mark.gui:Destroy()
		local victimRoot = victimHumanoid.Parent and victimHumanoid.Parent:FindFirstChild("HumanoidRootPart")
		local echoes = outcome == "return" or outcome == "death"
		if echoes and victimRoot and victimHumanoid.Health > 0 then
			victimHumanoid:TakeDamage(mark.damage * Config.POLTER_ECHO_FRACTION)
			table.insert(hits, victimRoot.Position)
		end
	end
	if #hits > 0 then
		Net.broadcast("Polter", { phase = "echo", hits = hits })
	end
end

-- A sword swing also checks the bodies left behind. Returns true if it hit one.
function Poltergoblin.strikeBodies(attacker, origin, look, damage)
	local struck = false
	for owner, spirit in pairs(spirits) do
		if owner ~= attacker then
			local offset = spirit.bodyCFrame.Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if
				offset.Magnitude <= Config.SWORD_RANGE
				and (flat.Magnitude < 0.5 or flat.Unit:Dot(look) >= Config.SWORD_MIN_DOT)
			then
				local _, humanoid = Util.getCharacterParts(owner)
				if humanoid then
					Util.damage(humanoid, damage)
				end
				Net.feed(attacker.DisplayName .. " struck " .. owner.DisplayName .. "'s body!", SPIRIT_COLOR)
				Net.toast(owner, "Your body was struck! Snapped back.")
				Poltergoblin.finish(owner, "shatter", attacker)
				struck = true
			end
		end
	end
	return struck
end

function Poltergoblin.request(player)
	local spirit = spirits[player]
	if not spirit then
		start(player)
	elseif now() - spirit.startedAt >= Config.POLTER_RECAST_DELAY then
		Poltergoblin.finish(player, "return")
	end
end

function Poltergoblin.tick()
	local t = now()
	for player, spirit in pairs(spirits) do
		local root, humanoid = Util.aliveRoot(player)
		if t >= spirit.endsAt then
			Poltergoblin.finish(player, "return")
		elseif root and humanoid then
			local stretch = (root.Position - spirit.bodyCFrame.Position).Magnitude / Config.POLTER_TETHER
			if stretch >= 1 then
				Net.toast(player, "Tether snapped - pulled back!")
				Poltergoblin.finish(player, "return")
			elseif inWard(root.Position) then
				Net.toast(player, "The Hoard's ward pulls your spirit back!")
				Poltergoblin.finish(player, "return")
			else
				-- The bonus grows the longer the spirit is out, like League.
				local progress = math.clamp((t - spirit.startedAt) / Config.POLTER_DURATION, 0, 1)
				local bonus = Config.POLTER_SPEED_BONUS_START
					+ (Config.POLTER_SPEED_BONUS_END - Config.POLTER_SPEED_BONUS_START) * progress
				Movement.setBoost(player, 1 + bonus)
				-- The tether turns red when it's close to snapping.
				local stretched = stretch > 0.75
				if stretched ~= spirit.stretched then
					spirit.stretched = stretched
					spirit.tether.Color = ColorSequence.new(stretched and STRETCHED_COLOR or SPIRIT_COLOR)
				end
				-- Like League, a mark turns white once its echo would finish the target.
				for victimHumanoid, mark in pairs(spirit.marks) do
					local lethal = mark.damage * Config.POLTER_ECHO_FRACTION >= victimHumanoid.Health
					mark.diamond.BackgroundColor3 = lethal and LETHAL_MARK_COLOR or MARK_COLOR
					mark.label.TextColor3 = lethal and MARK_COLOR or Color3.new(1, 1, 1)
				end
			end
		end
	end
end

function Poltergoblin.cancelAll()
	for player in pairs(spirits) do
		Poltergoblin.finish(player, "cancel")
	end
end

function Poltergoblin.forget(player)
	Poltergoblin.finish(player, "cancel")
	readyAt[player] = nil
end

return Poltergoblin

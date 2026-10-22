-- Remotes and the one server -> client broadcast channel.
-- Clients only ever send intent ("throw", "grapple here", "Poltergoblin",
-- "Shift is held").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local oldRemotes = ReplicatedStorage:FindFirstChild("LootGoblinsRemotes")
if oldRemotes then
	oldRemotes:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "LootGoblinsRemotes"

local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

Net.Throw = remote("ThrowRequest")
Net.Grapple = remote("GrappleRequest")
Net.Poltergoblin = remote("PoltergoblinRequest")
Net.Move = remote("MoveRequest") -- "dash" | "airjump": pay stamina for a move the client played.
Net.BoatBoost = remote("BoatBoostRequest")
Net.BoatDrift = remote("BoatDriftRequest") -- (held): the driver's drift key.
Net.BoatFx = remote("BoatFxRequest") -- (kind): the driver's boat did something worth showing.
Net.BoatBoard = remote("BoatBoardRequest") -- A grapple reeled the player onto a boat: seat them.
Net.Cannon = remote("CannonRequest")
Net.Keg = remote("KegRequest")
-- V7:
Net.BoatJump = remote("BoatJumpRequest") -- The hop, for a boat the server is simulating (a driven one hops on its own client).
Net.BoatRecall = remote("BoatRecallRequest") -- B: call a boat to the nearest shore.
Net.Steal = remote("StealRequest") -- (target Player): E at close range on a carrier you have knocked down.
Net.Deploy = remote("DeployRequest") -- (islandId | nil): choose where to land, and (second argument true) go.
Net.Shop = remote("ShopRequest") -- (action, a, b): buy, equip, unequip, outfit presets (V11: server/Progress.lua).
-- V11:
Net.Emote = remote("EmoteRequest") -- (emoteId | "stop"): strike a pose you own (server/Emotes.lua).
-- V13:
Net.Port = remote("PortRequest") -- (action, a): "join" the running raid; "spectate" start|next|back|stop (server/Port.lua).
Net.BoatAbility = remote("BoatAbilityRequest") -- (aimPoint): the driver used their boat's ability (server/BoatAbilities.lua).
Net.Reset = remote("ResetRequest") -- V13.1: the Reset button (a real respawn, for a goblin who is stuck).
-- V13.2:
Net.BoatGun = remote("BoatGunRequest") -- (aimPoint): the driver clicked: their boat's bow gun (Cannons.driverFire).
Net.BoatChain = remote("BoatChainRequest") -- (kind): the driver's own anchor or hook let go ("sling", "arrived", ...).
Net.Raid = remote("RaidRequest") -- (action): "in" / "out" of the next raid, "leave" the running one (Raid.lua).
-- V13.3 (the Living Port):
Net.Play = remote("PlayRequest") -- (action, a, b): a Port game: "leave", "again" (gameId), or a game's own input (Minigames.lua).
Net.Challenge = remote("ChallengeRequest") -- ("ask", userId, game) | ("answer", inviteId, yes) | ("cancel") | ("rematch", id) (Challenges.lua).
Net.Sanctuary = remote("SanctuaryRequest") -- ("home" | "visit", userId | "port" | "feed" | "toy", point | "bell").
Net.GameEvent = remote("GameEvent")
folder.Parent = ReplicatedStorage

-- kind is a short string the client switches on; payload is a plain table.
function Net.broadcast(kind, payload)
	Net.GameEvent:FireAllClients(kind, payload or {})
end

function Net.send(player, kind, payload)
	Net.GameEvent:FireClient(player, kind, payload or {})
end

-- Something that happened at a place, sent only to the goblins within `range` of it (and to
-- anyone with no body just now: their client decides). A storm on the far side of the sea is
-- nobody's business at home. The client still decides what to draw and play from where its own
-- camera is, so `range` only has to be generous.
function Net.broadcastNear(position, range, kind, payload)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - position).Magnitude <= range then
			Net.GameEvent:FireClient(player, kind, payload or {})
		end
	end
end

-- The big banner at the top of everyone's screen.
function Net.message(text, duration, color)
	Net.broadcast("Message", { text = text, duration = duration or 2.5, color = color })
end

-- One line in everyone's event feed.
function Net.feed(text, color)
	Net.broadcast("Feed", { text = text, color = color })
end

-- A short note for one player only ("Hands full").
function Net.toast(player, text)
	Net.send(player, "Toast", { text = text })
end

return Net

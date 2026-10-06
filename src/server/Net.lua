-- Remotes and the one server -> client broadcast channel.
-- Clients only ever send intent ("throw", "grapple here", "Poltergoblin").
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
Net.GameEvent = remote("GameEvent")
folder.Parent = ReplicatedStorage

-- kind is a short string the client switches on; payload is a plain table.
function Net.broadcast(kind, payload)
	Net.GameEvent:FireAllClients(kind, payload or {})
end

function Net.send(player, kind, payload)
	Net.GameEvent:FireClient(player, kind, payload or {})
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

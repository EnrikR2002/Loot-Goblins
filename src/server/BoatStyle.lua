-- Who a boat looks like (V11). The policy:
--   * a player boat wears the look of whoever is DRIVING it (paint, flag, figurehead, and the driver's boost trail,
--     wake, trick effect and callout style, which every client draws from the boat's attributes);
--   * passengers change nothing; a boat keeps its last driver's look while it sits, so hopping out to grab treasure
--     and back in does not flicker; the next driver repaints it;
--   * a boat called with B wears the caller's look as it arrives;
--   * a boat that sinks and comes back, or is reset at the end of a raid, goes back to its class colours;
--   * the Navy, the Guardian's speedboat and every other AI ship are never painted (they are not player boats).
-- Nothing here touches physics: see shared/BoatLook.lua's contract.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Catalog = require(Shared:WaitForChild("Catalog"))
local BoatLook = require(Shared:WaitForChild("BoatLook"))

local BoatStyle = {}

local EFFECTS = { trail = "Trail", wake = "Wake", trickfx = "TrickFx", callout = "Callout" }

function BoatStyle.paintable(boat)
	-- V13: every player class (Config.BOAT_TYPES[...].class); never the Navy or any other AI ship.
	return not boat.ai and boat.spec ~= nil and boat.spec.class == true
end

-- Dresses a boat for a player (nil: back to class colours and no effects).
function BoatStyle.dress(boat, player)
	if not BoatStyle.paintable(boat) or not boat.model.Parent then
		return
	end
	local look = player and Catalog.decodeLook(player:GetAttribute("Look")) or {}
	BoatLook.apply(boat.model, look)
	boat.model:SetAttribute("StyleOwner", player and player.UserId or nil)
	for slot, attribute in pairs(EFFECTS) do
		boat.model:SetAttribute(attribute, look[slot])
	end
end

return BoatStyle

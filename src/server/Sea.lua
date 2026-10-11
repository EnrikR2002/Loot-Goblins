-- The sea's math lives in ReplicatedStorage (shared/Sea.lua): the driver's client floats its
-- own boat on the same waves and currents the server uses. Server modules keep requiring it
-- from here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))

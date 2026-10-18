-- Which centre-screen banner shows (V12). Pure, so it is tested (tests/luau/Specs/CohesionSpec.lua).
--
-- Through V11 every banner replaced the one before, so the trouble line that follows a steal 1.1 s later wiped
-- "YOU STOLE THE ..." before it could be read, and a storm on the horizon could wipe "BANKED". Now each banner has
-- a priority: 4 act now (a stomp ring, a ram), 3 your own big moment (steal, bank, raid start and end, last call),
-- 2 the world reacting (trouble, a trophy, the default), 1 news (someone else's steal, a storm far off). A banner
-- of lower priority than the one showing waits for it to end, and then shows only if it is still fresh; only
-- the most important waiting banner is kept. Equal or higher priority shows at once.
local BannerQueue = {}

BannerQueue.FRESH = 5 -- seconds a waiting banner stays worth showing
BannerQueue.DEFAULT = 2

function BannerQueue.new()
	return { untilAt = 0, priority = 0, pending = nil }
end

-- Offer a banner { message, color, duration, priority }. Returns it if it should show now, otherwise nil.
function BannerQueue.offer(queue, now, banner)
	banner.priority = banner.priority or BannerQueue.DEFAULT
	if now < queue.untilAt and banner.priority < queue.priority then
		if not queue.pending or banner.priority >= queue.pending.priority then
			banner.at = now
			queue.pending = banner
		end
		return nil
	end
	queue.pending = nil
	queue.untilAt = now + (banner.duration or 2.5)
	queue.priority = banner.priority
	return banner
end

-- Each frame: the waiting banner, if the one showing has ended and it is still fresh.
function BannerQueue.flush(queue, now)
	local waiting = queue.pending
	if not waiting or now < queue.untilAt then
		return nil
	end
	queue.pending = nil
	if now - (waiting.at or now) > BannerQueue.FRESH then
		return nil
	end
	return BannerQueue.offer(queue, now, waiting)
end

return BannerQueue

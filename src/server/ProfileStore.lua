-- Reading and writing profiles safely (V11). Every read and write is one UpdateAsync on the player's key, so the
-- check and the write happen together.
--
-- SESSION LOCK. A profile records which server session has it open (`lock = { job, session, at }`):
--   * opening takes the lock, unless another session holds a FRESH one (refreshed within LOCK_STALE seconds by
--     that server's saves); then the answer is "locked" and the caller tries again later;
--   * a STALE lock (its server crashed or lost the store for minutes) is taken over;
--   * every save checks the lock is still ours. If it is not (another server took over, or the key was deleted),
--     the save is refused: "lost". A server never writes over a profile it no longer holds, so a goblin who
--     rejoins elsewhere cannot have their newer progress overwritten by the old server's late save;
--   * the save made when a goblin leaves releases the lock, so their next server opens it at once.
--
-- RETRIES. A failed call is retried with growing waits; if the request budget is exhausted it waits for budget
-- first. The store is passed in (a real DataStore, or tests' MockStore), and so are the clock and the wait, so the
-- tests can run every failure on a stand-in.
local ProfileSchema = require(script.Parent.ProfileSchema)

local ProfileStore = {}
ProfileStore.__index = ProfileStore

-- opts:
--   store       an object with UpdateAsync(key, transform) (a DataStore)
--   job         this server's id (game.JobId; Studio's is empty, so a random one is used)
--   now         () -> unix seconds
--   wait        (seconds) -> ()
--   budget      () -> number | nil   UpdateAsync requests available now (nil: unknown)
--   limits      ProfileSchema limits ({ presets, receipts, history })
--   lockStale   seconds after which another session's lock is treated as abandoned
--   tries       attempts per call
function ProfileStore.new(opts)
	local self = setmetatable({}, ProfileStore)
	self.store = opts.store
	self.job = opts.job or "server"
	self.now = opts.now or os.time
	self.wait = opts.wait or task.wait
	self.budget = opts.budget
	self.limits = opts.limits or {}
	self.lockStale = opts.lockStale or 180
	self.tries = opts.tries or 4
	return self
end

-- One UpdateAsync, retried. Returns ok, errorMessage.
function ProfileStore:_update(key, transform)
	local lastError
	for attempt = 1, self.tries do
		if self.budget then
			for _ = 1, 6 do
				local available = self.budget()
				if available == nil or available >= 1 then
					break
				end
				self.wait(1)
			end
		end
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, transform)
		end)
		if ok then
			return true
		end
		lastError = tostring(err)
		if attempt < self.tries then
			self.wait(math.min(8, 2 ^ (attempt - 1)))
		end
	end
	return false, lastError
end

local function foreignLock(data, session)
	return type(data) == "table" and type(data.lock) == "table" and data.lock.session ~= session
end

-- Opens a profile for `session`. Returns status, profile, how:
--   "ok", profile, how ("new" | "migrated" | "loaded" | "repaired")   the lock is ours now
--   "locked", nil       another session holds a fresh lock
--   "newer", nil        written by a newer version of the game: play unsaved, never write
--   "error", nil, msg   the store failed every attempt
function ProfileStore:open(key, session)
	local status, profile, how
	local ok, err = self:_update(key, function(old)
		-- UpdateAsync may run this more than once: start clean each time.
		status, profile, how = nil, nil, nil
		local t = self.now()
		if foreignLock(old, session) then
			local age = t - (tonumber(old.lock.at) or 0)
			if age < self.lockStale then
				status = "locked"
				return nil
			end
		end
		local loaded, reason = ProfileSchema.load(old, self.limits, t)
		if not loaded then
			status = reason
			return nil
		end
		loaded.lock = { job = self.job, session = session, at = t }
		loaded.seen = t
		status, profile, how = "ok", loaded, reason
		return loaded
	end)
	if not ok then
		return "error", nil, err
	end
	return status or "error", profile, how
end

-- Writes `profile` for `session`. release = true also gives the lock up (the goblin is leaving). Returns status:
--   "ok"      written
--   "lost"    the lock is not ours any more (or the key is gone): nothing was written, stop saving this profile
--   "newer"   a newer game version has written it since: nothing was written
--   "error"   the store failed every attempt (try again later; the lock is still ours)
function ProfileStore:save(key, session, profile, release)
	local snapshot = ProfileSchema.copy(profile)
	local status
	local ok = self:_update(key, function(old)
		status = nil
		if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.session ~= session then
			status = "lost"
			return nil
		end
		if type(old.v) == "number" and old.v > ProfileSchema.VERSION then
			status = "newer"
			return nil
		end
		local t = self.now()
		snapshot.lock = (not release) and { job = self.job, session = session, at = t } or nil
		snapshot.seen = t
		status = "ok"
		return snapshot
	end)
	if not ok then
		return "error"
	end
	return status or "error"
end

-- An in-memory stand-in for a DataStore, for the tests and for Studio when the real store is unavailable. It copies
-- values in and out like the real one (a stored table is never the same table the game holds) and can be told to
-- fail the next n calls.
local MockStore = {}
MockStore.__index = MockStore

function ProfileStore.mock()
	return setmetatable({ data = {}, failNext = 0, calls = 0, writes = 0 }, MockStore)
end

function MockStore:UpdateAsync(key, transform)
	self.calls += 1
	if self.failNext > 0 then
		self.failNext -= 1
		error("MockStore: simulated failure")
	end
	local value = transform(ProfileSchema.copy(self.data[key]))
	if value ~= nil then
		self.data[key] = ProfileSchema.copy(value)
		self.writes += 1
	end
	return value
end

function MockStore:GetAsync(key)
	return ProfileSchema.copy(self.data[key])
end

return ProfileStore

local Result = require(script.Result)
local Session = require(script.Session)
local SessionData = require(script.SessionData)
local constants = require(script.constants)
local Future = require(script.packages.Future)
local types = require(script.types)
local utils = require(script.utils)

local Store = {}
Store.__index = Store

function Store.new<K, T, M>(options: types.StoreOptions<K, T>): types.Store<K, T, M>
	return setmetatable({
		dataStore = options.datastore,
		options = options,
		sessions = {},
		closed = false,
	}, Store) :: any
end

type LoadOptions = {
	force: boolean?,
	userIds: { number }?,
}

function Store.load<K, T, M>(
	self: types.Store<K, T, M>,
	key: K,
	options: LoadOptions?
): Result.Result<types.Session<K, T, M>, types.StoreResult>
	if self.closed then
		return Result.Err(utils.createStoreResult("StoreClosed"))
	end

	local options: LoadOptions = options or {}
	local normalizedKey = self.options.key(key)

	if self.sessions[normalizedKey] then
		return Result.Ok(self.sessions[normalizedKey])
	end

	local function attemptLoad(force: boolean?): Result.Result<types.Session<K, T, M>, types.StoreResult>
		if self.closed then
			return Result.Err(utils.createStoreResult("StoreClosed"))
		end

		local session: Result.Result<types.Session<K, T, M>, types.StoreResult>

		local result = utils.updateAsync(self.dataStore, normalizedKey, function(rawData, dataStoreKeyInfo)
			local sessionData

			if not dataStoreKeyInfo then
				sessionData = SessionData.new(rawData, self.options.defaultMetadata(), {}, 0)
			else
				sessionData = SessionData.from(rawData, self.options.defaultMetadata(), dataStoreKeyInfo)

				if not SessionData.doesOwn(sessionData, self.options.lockId) and not force then
					session = Result.Err(utils.createStoreResult("SessionLocked"))
					return
				end
			end

			SessionData.own(sessionData, self.options.lockId)

			session = Result.Ok(Session.new(self, key, sessionData))

			return sessionData.inner,
				options.userIds or sessionData.userIds,
				SessionData.dataStoreKeyInfoMetadata(sessionData)
		end)

		if result:isErr() then
			return Result.Err(utils.createStoreResult("DataStoreAPIError", result:unwrapErr()))
		end

		return session:match({
			Ok = function(session)
				local migrationResult = SessionData.migrate(session.data, self.options.migrations)

				if migrationResult:isErr() then
					return Result.Err(utils.createStoreResult("MigrationError", migrationResult:unwrapErr()))
				end

				return Result.Ok(session)
			end,
			Err = function(err)
				return Result.Err(err)
			end,
		})
	end

	local function retry(attempt: number, force: boolean?): Result.Result<types.Session<K, T, M>, types.StoreResult>
		return Result.match(attemptLoad(force), {
			Ok = function(session)
				return Result.Ok(session)
			end,
			Err = function(storeResult)
				if storeResult.type == "DataStoreAPIError" or storeResult.type == "MigrationError" then
					return Result.Err(utils.createStoreResult(storeResult.type, storeResult.message))
				end

				local maxLoadRetries = self.options.maxLoadRetries or constants.DEFAULT_MAX_LOAD_RETRIES
				local loadDelays = self.options.loadDelays or constants.DEFAULT_LOAD_RETRY_DELAYS

				if attempt > maxLoadRetries then
					warn(`forcing ownership of {normalizedKey} as the previous lockId will not release it`)
					return retry(attempt + 1, true)
				end

				warn(
					`failed to load session for {normalizedKey} for {storeResult.type}{if storeResult.message
						then `, {storeResult.message}`
						else ""}. attempt {attempt} / {maxLoadRetries}`
				)
				task.wait(loadDelays[math.min(attempt, #loadDelays)])

				return retry(attempt + 1)
			end,
		})
	end

	return Result.match(retry(1, options.force), {
		Ok = function(session)
			local autosaveThread = task.spawn(function()
				if not self.options.autosaveInterval then
					return
				end

				while task.wait(self.options.autosaveInterval) do
					session:save():match({
						Ok = function()
							print(`successfully saved {normalizedKey}`)
							return nil
						end,
						Err = function(message)
							warn(`failed to save {normalizedKey} due to {message}`)
							return nil
						end,
					})
				end
			end)

			session.released:connect(function()
				task.cancel(autosaveThread)
				self.sessions[normalizedKey] = nil
			end)

			self.sessions[normalizedKey] = session

			return Result.Ok(session)
		end,
		Err = function(err)
			return Result.Err(err)
		end,
	})
end

function Store.get<K, T, M>(self: types.Store<K, T, M>, key: K): types.Session<K, T, M>?
	assert(not self.closed, "store is closed")
	return self.sessions[self.options.key(key)]
end

type CloseResult<K> = {
	key: K,
	result: Result.Result<nil, types.StoreResult>,
}

function Store.close<K, T, M>(self: types.Store<K, T, M>): { CloseResult<K> }
	assert(not self.closed, "store is already closed")

	self.closed = true

	local futures: { Future.Future<CloseResult<K>> } = {}

	for _, session in self.sessions do
		-- todo: probably implement my own signal so that i dont need to assert a session
		-- with a types.Session<K, T, M> just becuase the freaking signal are causing
		-- the typechecker to me ANGRY at me (when in --!strict mode smh)
		local session = session :: types.Session<K, T, M>

		table.insert(
			futures,
			Future.spawn(function()
				return {
					key = session.key,
					result = session:release(),
				}
			end)
		)
	end

	return Future.all(futures):await()
end

export type Store<K, T, M = {}> = types.Store<K, T, M>
export type Session<K, T, M = {}> = types.Session<K, T, M>

return Store

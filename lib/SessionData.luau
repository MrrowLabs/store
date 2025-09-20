local Result = require(script.Parent.Result)
local constants = require(script.Parent.constants)
local types = require(script.Parent.types)

local SessionData = {}

function SessionData.from<T, M>(data: T, defaultMetadata: M, dataStoreKeyInfo: DataStoreKeyInfo): types.SessionData<T, M>
	local metadata: {
		inner: M?,
		version: number?,
	} & types.DataStoreKeyInfoMetadata<M> =
		dataStoreKeyInfo:GetMetadata()
	local userIds = dataStoreKeyInfo:GetUserIds()
	local newData = not metadata.version

	if newData then
		return SessionData.new(data, defaultMetadata, {}, 0)
	end

	return {
		inner = data,
		metadata = metadata.inner :: M,
		version = metadata.version :: number,
		lastUpdate = metadata.lastUpdate,
		lockId = metadata.lockId,
		userIds = userIds,
	}
end

function SessionData.new<T, M>(data: T, metadata: M, userIds: { number }, version: number): types.SessionData<T, M>
	return {
		inner = data,
		metadata = metadata,
		version = version,
		userIds = userIds,
	}
end

function SessionData.migrate<T, M>(
	sessionData: types.SessionData<T, M>,
	migrations: types.Migrations
): Result.Result<nil, string>
	-- older servers thingies, dont wana mess up the game due to breaking data changes per migration
	if sessionData.version > #migrations then
		return Result.Err(
			"version mismatch: the session data version is higher than the version that the server can handle"
		)
	end

	for migrationVersion = sessionData.version + 1, #migrations do
		-- luau decides that pcall does not return a second argument which can be the
		-- error message of the function, soo errm just casting it as the type
		-- below works lol
		local ok, errOrMigrationResult = pcall(migrations[migrationVersion], sessionData.inner)

		if not ok then
			return Result.Err(errOrMigrationResult :: string)
		end

		-- pretty much replace le data
		if errOrMigrationResult then
			sessionData.inner = errOrMigrationResult
		end

		sessionData.version = migrationVersion
	end

	return Result.Ok(nil)
end

function SessionData.dataStoreKeyInfoMetadata<T, M>(sessionData: types.SessionData<T, M>): types.DataStoreKeyInfoMetadata<M>
	return {
		inner = sessionData.metadata,
		version = sessionData.version,
		lastUpdate = sessionData.lastUpdate,
		lockId = sessionData.lockId,
	}
end

function SessionData.export<T, M>(sessionData: types.SessionData<T, M>): (T, { number }, types.DataStoreKeyInfoMetadata<M>)
	return sessionData.inner, sessionData.userIds, SessionData.dataStoreKeyInfoMetadata(sessionData)
end

function SessionData.update<T, M>(sessionData: types.SessionData<T, M>)
	sessionData.lastUpdate = os.time()
end

function SessionData.own<T, M>(sessionData: types.SessionData<T, M>, lockId: string)
	sessionData.lockId = lockId
	SessionData.update(sessionData)
end

function SessionData.release<T, M>(sessionData: types.SessionData<T, M>)
	sessionData.lockId = nil
	SessionData.update(sessionData)
end

function SessionData.isDead<T, M>(sessionData: types.SessionData<T, M>): boolean
	return os.time() - (sessionData.lastUpdate or 0) >= constants.DEAD_LOCK_LENGTH
end

function SessionData.doesOwn<T, M>(sessionData: types.SessionData<T, M>, lockId: string): boolean
	return not sessionData.lockId or sessionData.lockId == lockId or SessionData.isDead(sessionData)
end

return SessionData

local Result = require(script.Parent.Result)
local types = require(script.Parent.types)

local utils = {}

function utils.updateAsync(
	dataStore: DataStore,
	key: string,
	fn: (
		rawData: any,
		dataStoreKeyInfo: DataStoreKeyInfo?
	) -> (any?, { number }?, { [any]: any }?)
): Result.Result<nil, string>
	local ok, err = pcall(dataStore.UpdateAsync, dataStore, key, fn)

	if not ok then
		return Result.Err(`{err}`)
	end

	return Result.Ok(nil)
end

function utils.createStoreResult(type: string, message: string?): types.StoreResult
	return {
		type = type,
		message = message,
	} :: any
end

return utils

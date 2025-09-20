local Result = require(script.Parent.Result)

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

return utils

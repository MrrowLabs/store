local Result = require(script.Parent.Result)
local SessionData = require(script.Parent.SessionData)
local Signal = require(script.Parent.packages.Signal)
local types = require(script.Parent.types)
local utils = require(script.Parent.utils)
local Session = {}
Session.__index = Session

function Session.new<K, T, M>(store: types.Store<K, T, M>, key: K, sessionData: types.SessionData<T, M>): types.Session<K, T, M>
	return setmetatable({
		store = store,
		key = key,
		data = sessionData,
		releasing = false,
		isReleased = false,
		updated = Signal.new(),
		released = Signal.new(),
	}, Session) :: any
end

function Session.peek<K, T, M>(self: types.Session<K, T, M>): T
	assert(not self.releasing and not self.isReleased, `cannot update releasing/released data`)

	return self.data.inner
end

function Session.update<K, T, M>(self: types.Session<K, T, M>, fn: (T) -> ())
	assert(not self.releasing and not self.isReleased, `cannot update releasing/released data`)

	local changes: { types.DataChange } = {}

	local function track<T>(root: T, path: { string }?): typeof(setmetatable({} :: any, {} :: any))
		assert(typeof(root) == "table", "root must a table type")

		local path: { string } = path or {}

		return setmetatable({}, {
			__index = function(_, key)
				local value = root[key]

				local newPath = table.clone(path)
				table.insert(newPath, key)

				if typeof(value) == "table" then
					return track(value, newPath)
				else
					return value
				end
			end,
			__newindex = function(_, key, value)
				local newPath = table.clone(path)
				table.insert(newPath, key)
				table.insert(changes, {
					path = newPath,
					newValue = value,
				})
				root[key] = value
			end,
			__iter = function()
				return function(t, lastKey)
					local nextKey, nextValue = next(t, lastKey)

					if not nextKey then
						return nil :: any
					end

					if typeof(nextValue) == "table" then
						local newPath = table.clone(path)
						table.insert(newPath, nextKey)
						return nextKey, track(nextValue, newPath)
					else
						return nextKey, nextValue
					end
				end,
					root
			end,
			__len = function()
				return #root
			end,
		})
	end

	fn(track(self.data.inner))

	if #changes > 0 then
		SessionData.update(self.data)
	end

	self.updated:fire(changes)
end

function Session.save<K, T, M>(self: types.Session<K, T, M>): Result.Result<nil, string>
	assert(not self.releasing and not self.isReleased, `cannot save releasing/released data`)

	local normalizedKey = self.store.options.key(self.key)

	local result = utils.updateAsync(self.store.dataStore, normalizedKey, function()
		return SessionData.export(self.data)
	end)

	if result:isErr() then
		return Result.Err(result:unwrapErr())
	end

	return Result.Ok(nil)
end

function Session.release<K, T, M>(self: types.Session<K, T, M>): Result.Result<nil, string>
	assert(not self.releasing and not self.isReleased, `session is already being released or is released`)

	self.releasing = true

	SessionData.release(self.data)

	local normalizedKey = self.store.options.key(self.key)

	local result = utils.updateAsync(self.store.dataStore, normalizedKey, function()
		return SessionData.export(self.data)
	end)

	self.isReleased = true
	self.released:fire()

	return result
end

return Session

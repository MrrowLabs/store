-- a more cutdown version of lukadev_0's result library

local Result = {}
Result.__index = Result

function Result.new<T, E>(v: T?, e: E?, ok: boolean): Result<T, E>
	return table.freeze(setmetatable({
		v = v,
		e = e,
		ok = ok,
	}, Result)) :: Result<T, E>
end

function Result.Ok<T, E>(v: T): Result<T, E>
	return Result.new(v, nil, true)
end

function Result.Err<T, E>(e: E): Result<T, E>
	return Result.new(nil, e, false)
end

function Result.isOk<T, E>(self: Result<T, E>): boolean
	return self.ok
end

function Result.isErr<T, E>(self: Result<T, E>): boolean
	return not self.ok
end

function Result.unwrap<T, E>(self: Result<T, E>): T
	assert(self.ok, "cannot unwrap on an err")
	return self.v
end

function Result.unwrapErr<T, E>(self: Result<T, E>): E
	assert(not self.ok, "cannot unwrap on an ok")
	return self.e
end

function Result.match<T, E, R>(self: Result<T, E>, fns: { Ok: (T) -> R, Err: (E) -> R }): R
	if self:isOk() then
		return fns.Ok(self.v)
	else
		return fns.Err(self.e)
	end
end

export type Result<T, E> = typeof(setmetatable(
	{} :: {
		v: T,
		e: E,
		ok: boolean,
		isOk: (self: Result<T, E>) -> boolean,
		isErr: (self: Result<T, E>) -> boolean,
		unwrap: (self: Result<T, E>) -> T,
		unwrapErr: (self: Result<T, E>) -> E,
		match: <R>(self: Result<T, E>, fns: { Ok: (T) -> R, Err: (E) -> R }) -> R,
	},
	Result
))

return Result

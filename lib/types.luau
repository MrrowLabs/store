local Result = require(script.Parent.Result)
local Signal = require(script.Parent.packages.Signal)

export type Migrations = { [number]: (inner: any) -> any? }

export type BaseStoreResult<T, M = nil> = {
	type: T,
	message: M,
}

export type StoreResult =
	BaseStoreResult<"DataStoreAPIError", string>
	| BaseStoreResult<"MigrationError", string>
	| BaseStoreResult<"SessionLocked">
	| BaseStoreResult<"StoreClosed">
	| BaseStoreResult<"SessionReleased">

export type DataStoreKeyInfoMetadata<T> = {
	inner: T,
	version: number,
	lastUpdate: number?,
	lockId: string?,
}

export type StoreOptions<K, T, M = {}> = {
	datastore: DataStore,
	maxLoadRetries: number?,
	loadDelays: { number }?,
	autosaveInterval: number?,
	key: (input: K) -> string,
	lockId: string,
	defaultMetadata: () -> M,
	migrations: Migrations,
}

export type SessionData<T, M = {}> = {
	inner: T,
	metadata: M,
	version: number,
	lastUpdate: number?,
	lockId: string?,
	userIds: { number },
}

export type Store<K, T, M = {}> = typeof(setmetatable(
	{} :: {
		dataStore: DataStore,
		options: StoreOptions<K, T, M>,
		sessions: { [string]: Session<K, T, M> },
		closed: boolean,
	},
	{} :: {
		__index: {
			load: (self: Store<K, T, M>, key: K) -> Result.Result<Session<K, T, M>, StoreResult>,
			get: (self: Store<K, T, M>, key: K) -> Session<K, T, M>?,
			close: (self: Store<K, T, M>) -> { Result.Result<nil, StoreResult> },
		},
	}
))

export type DataChange = {
	path: { string },
	newValue: any,
}

export type Session<K, T, M = {}> = typeof(setmetatable(
	{} :: {
		store: Store<K, T, M>,
		key: K,
		data: SessionData<T, M>,
		isReleased: boolean,
		updated: Signal.Signal<{ DataChange }>,
		released: Signal.Signal<>,
	},
	{} :: {
		__index: {
			peek: (self: Session<K, T, M>) -> T,
			update: (self: Session<K, T, M>, fn: (T) -> ()) -> (),
			save: (self: Session<K, T, M>) -> Result.Result<nil, StoreResult>,
			release: (self: Session<K, T, M>) -> Result.Result<nil, StoreResult>,
		},
	}
))

return nil

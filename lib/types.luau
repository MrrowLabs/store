local Result = require(script.Parent.Result)
local Signal = require(script.Parent.packages.Signal)

export type Migrations = { [number]: (inner: any) -> any? }

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
		closing: boolean,
		isClosed: boolean,
	},
	{} :: {
		__index: {
			load: (self: Store<K, T, M>, key: K) -> Result.Result<Session<K, T, M>, string>,
			get: (self: Store<K, T, M>, key: K) -> Session<K, T, M>?,
			close: (self: Store<K, T, M>) -> { Result.Result<nil, string> },
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
		releasing: boolean,
		isReleased: boolean,
		updated: Signal.Signal<{ DataChange }>,
		released: Signal.Signal<>,
	},
	{} :: {
		__index: {
			peek: (self: Session<K, T, M>) -> T,
			update: (self: Session<K, T, M>, fn: (T) -> ()) -> (),
			save: (self: Session<K, T, M>) -> Result.Result<nil, string>,
			release: (self: Session<K, T, M>) -> Result.Result<nil, string>,
		},
	}
))

return nil

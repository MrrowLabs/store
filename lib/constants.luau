local constants = {
	DEFAULT_MAX_LOAD_RETRIES = 6,
	DEFAULT_LOAD_RETRY_DELAYS = { 5, 10, 15, 20, 30, 60 },

	DEAD_LOCK_LENGTH = 30 * 60,
}

return constants

.PHONY: test

test:
	mix test
	MEMCACHE_PORT=11211 mix test

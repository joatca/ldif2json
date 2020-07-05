bin/ldif2json: src/*.cr
	shards build --release
	strip $@

all: bin/ldif2json doc/ldif2json.1

bin/ldif2json: src/*.cr
	shards build --release
	strip $@

doc/ldif2json.1: doc/ldif2json.md
	pandoc --standalone --to man $< -o $@

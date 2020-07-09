all: bin/ldif2json doc/ldif2json.1.gz

install: all
	install -o root -g root bin/ldif2json /usr/bin
	install -o root -g root doc/ldif2json.1.gz /usr/share/man/man1

bin/ldif2json: src/*.cr
	shards -v build --release
	strip $@

doc/ldif2json.1.gz: doc/ldif2json.md
	pandoc --standalone --to man $< | gzip > $@

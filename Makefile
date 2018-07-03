CRYSTAL_BIN ?= $(shell which crystal)
SHARDS_BIN ?= $(shell which shards)
PREFIX ?= /usr/local
SHARD_BIN ?= ../../bin

build: bin/ameba
bin/ameba:
	$(SHARDS_BIN) build $(CRFLAGS)
clean:
	rm -f ./bin/ameba ./bin/ameba.dwarf
install: build
	mkdir -p $(PREFIX)/bin
	cp ./bin/ameba $(PREFIX)/bin
bin: build
	mkdir -p $(SHARD_BIN)
	cp ./bin/ameba $(SHARD_BIN)
test: build
	$(CRYSTAL_BIN) spec
	./bin/ameba

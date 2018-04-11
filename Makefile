CRYSTAL_BIN ?= $(shell which crystal)
SHARDS_BIN ?= $(shell which shards)
PREFIX ?= /usr/local
SHARD_BIN ?= ../../bin

build:
	$(SHARDS_BIN) build --no-debug $(CRFLAGS)
clean:
	rm -f ./bin/ameba
install: build
	mkdir -p $(PREFIX)/bin
	cp ./bin/ameba $(PREFIX)/bin
bin: build
	mkdir -p $(SHARD_BIN)
	cp ./bin/ameba $(SHARD_BIN)
test: build
	$(CRYSTAL_BIN) spec
	./bin/ameba

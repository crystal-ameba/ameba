CRYSTAL_BIN ?= $(shell which crystal)
PREFIX ?= /usr/local

build:
	$(CRYSTAL_BIN) build --release --no-debug -o bin/ameba src/cli.cr $(CRFLAGS)
clean:
	rm -f ./bin/ameba
install: build
	mkdir -p $(PREFIX)/bin
	cp ./bin/ameba $(PREFIX)/bin

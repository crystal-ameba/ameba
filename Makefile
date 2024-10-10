.POSIX:
all:

# Recipes

## Build ameba
##   $ make
## Run tests
##   $ make test
## Install ameba
##   $ sudo make install

-include Makefile.local # for optional local options

BUILD_TARGET := bin/ameba

DESTDIR ?=          ## Install destination dir
PREFIX ?= /usr/local## Install path prefix
BINDIR ?= $(DESTDIR)$(PREFIX)/bin

# The crystal command to use
CRYSTAL_BIN ?= crystal
# The shards command to use
SHARDS_BIN ?= shards
# The install command to use
INSTALL_BIN ?= /usr/bin/install

SHARD_BIN ?= ../../bin
CRFLAGS ?= -Dpreview_mt

SRC_SOURCES := $(shell find src -name '*.cr' 2>/dev/null)
DOC_SOURCE   := src/**

.PHONY: all
all: build

.PHONY: build
build: ## Build the application binary
build: $(BUILD_TARGET)

$(BUILD_TARGET): $(SRC_SOURCES)
	$(SHARDS_BIN) build $(CRFLAGS)

docs: ## Generate API docs
docs: $(SRC_SOURCES)
	$(CRYSTAL_BIN) docs -o docs $(DOC_SOURCE)

.PHONY: lint
lint: ## Run ameba on ameba's code base
lint: $(BUILD_TARGET)
	$(BUILD_TARGET)

.PHONY: spec
spec: ## Run the spec suite
spec:
	$(CRYSTAL_BIN) spec

.PHONY: clean
clean: ## Remove application binary
clean:
	@rm -f "$(BUILD_TARGET)" "$(BUILD_TARGET).dwarf"

.PHONY: install
install: ## Install application binary into $DESTDIR
install: $(BUILD_TARGET)
	$(INSTALL_BIN) -m 0755 "$(BUILD_TARGET)" "$(BINDIR)/ameba"

.PHONY: bin
bin: build
	mkdir -p $(SHARD_BIN)
	cp $(BUILD_TARGET) $(SHARD_BIN)

.PHONY: test
test: ## Run the spec suite and linter
test: spec lint

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mtargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34moptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mrecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'

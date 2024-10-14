.POSIX:
all:

# Recipes

## Build ameba
##   $ make
##
## Run tests
##   $ make test
##
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

CRFLAGS ?= -Dpreview_mt

SRC_SOURCES := $(shell find src -name '*.cr' 2>/dev/null)

.PHONY: all
all: build

.PHONY: build
build: ## Build the application binary
build: $(BUILD_TARGET)

$(BUILD_TARGET): $(SRC_SOURCES)
	$(SHARDS_BIN) build $(CRFLAGS)

.PHONY: docs
docs: ## Generate API docs
docs: $(SRC_SOURCES)
	$(CRYSTAL_BIN) docs

.PHONY: spec
spec: ## Run the spec suite
spec:
	$(CRYSTAL_BIN) spec

.PHONY: lint
lint: ## Run ameba on its own code base
lint: $(BUILD_TARGET)
	$(BUILD_TARGET)

.PHONY: test
test: ## Run the spec suite and linter
test: spec lint

.PHONY: clean
clean: ## Remove application binary and API docs
clean:
	@rm -f "$(BUILD_TARGET)" "$(BUILD_TARGET).dwarf"
	@rm -rf docs

.PHONY: install
install: ## Install application binary into $DESTDIR
install: $(BUILD_TARGET)
	mkdir -p "$(BINDIR)"
	$(INSTALL_BIN) -m 0755 "$(BUILD_TARGET)" "$(BINDIR)/ameba"

.PHONY: help
help: ## Show this help
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

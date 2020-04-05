.DEFAULT_GOAL := server
SHELL := /bin/bash

# Hugo binary download
HUGO_VERSION ?= 0.54.0
HUGO_PLATFORM ?= macOS-64bit
HUGO_FLAVOR ?= extended_
HUGO_FULL_VERSION = $(HUGO_FLAVOR)$(HUGO_VERSION)_$(HUGO_PLATFORM)
HUGO_URL = "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_FULL_VERSION}.tar.gz"
HUGO = bin/hugo

LN = ln -sf

NODEBIN = node_modules/.bin
HUGO_DEFAULT_ARGS = --destination ../dist --source site --verbose
HUGO_PREVIEW_ARGS = --buildDrafts --buildFuture

$(HUGO): $(HUGO)_$(HUGO_FULL_VERSION)
	@echo "🔗 Linking Hugo"
	$(LN) "$(shell pwd)/$<" $@

$(HUGO)_$(HUGO_FULL_VERSION):
	@echo "👹 Downloading Hugo $(HUGO_VERSION)..."
	mkdir -p bin
	curl -s --output $@.tar.gz -L $(HUGO_URL)
	tar -C bin -xzf $@.tar.gz
	mv $(HUGO) $@
	chmod +x $@
	$@ version > /dev/null
	rm -rf bin/LICENSE bin/README.md
	touch $@


.PHONY = build
build: redirects dist node_modules
dist: $(HUGO)
	$(HUGO) $(HUGO_DEFAULT_ARGS)

.PHONY = redirects
redirects: dist/_redirects
dist/_redirects: dist _redirects
	cp _redirects $@

.PHONY = s serve server
s: serve
serve: server
server: build $(HUGO)
	$(HUGO) server $(HUGO_DEFAULT_ARGS) $(HUGO_PREVIEW_ARGS)

.PHONY = deps
deps: node_modules
node_modules: package.json package-lock.json
	npm ci

clean:
	rm -rf dist
	rm -rf node_modules

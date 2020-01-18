.DEFAULT_GOAL := server
SHELL := /bin/bash

NODEBIN = node_modules/.bin
HUGO_DEFAULT_ARGS = --destination ../dist --source site --verbose
HUGO_PREVIEW_ARGS = --buildDrafts --buildFuture

.PHONY = build
build: redirects dist node_modules
dist: 
	./hugo $(HUGO_DEFAULT_ARGS)

.PHONY = redirects
redirects: dist/_redirects
dist/_redirects: dist _redirects
	cp _redirects $@

.PHONY = s serve server
s: serve
serve: server
server: build
	./hugo server $(HUGO_DEFAULT_ARGS) $(HUGO_PREVIEW_ARGS)

.PHONY = deps
deps: node_modules
node_modules: package.json package-lock.json
	npm ci

clean:
	rm -rf dist
	rm -rf node_modules

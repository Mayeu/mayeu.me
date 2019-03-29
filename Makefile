.DEFAULT_GOAL := server
SHELL := /bin/bash

NODEBIN = node_modules/.bin
HTML_TEMPLATE = $(shell find site -name '*.html')
CSS_FILES = $(shell find src -name '*.css')

.PHONY = build css
build: css
css: site/assets/css/style.css
site/assets/css/style.css: $(HTML_TEMPLATE) $(CSS_FILES) site/assets/css
	$(NODEBIN)/purgecss --css <($(NODEBIN)/cleancss $(CSS_FILES)) \
		--content $(HTML_TEMPLATE) | jq -r ".[] | .css" \
		> $@

.PHONY = build-dev css-dev
build-dev: css-dev
css-dev: $(HTML_TEMPLATE) $(CSS_FILES) site/assets/css
	$(NODEBIN)/cleancss $(CSS_FILES) > site/assets/css/style.css

site/assets/css:
	mkdir -p $@

HUGO_DEFAULT_ARGS = --destination ../dist --source site --verbose
HUGO_PREVIEW_ARGS = --buildDrafts --buildFuture

.PHONY = serve server
serve: server
server: build
	hugo server $(HUGO_DEFAULT_ARGS) #$(HUGO_PREVIEW_ARGS)

# TODO: Not really working, build-dev is a hack
# make build purge the css of anything that is not needed. But if I add a new
# class that was not yet part of the purged files it is not added to it.
# I am not sure why
#
# The current idea is that two things are run, entr(1) wich rebuild the css
# if anything change (to ensuite all the item are present), and in parrallel
# the normal hugo watcher.
# So in theory, if the template or the css changes, the css changes in hugo,
# then hugo rebuild the site with the new css
watch:
	ls -d src/**/* site/**/* | entr -r make build-dev & make server

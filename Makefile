.PHONY: install s serve server build help
.DEFAULT_GOAL := help

bootstrap-live: _plugins/jekyll-hackhack ## Install all the needed dependencies
	@echo "Installing gems"
	@bundle install --path vendor/bundle

bootstrap: _plugins/jekyll-hackhack Gemfile.lock ## Install all the needs dependencies
	@echo "Installing gems"

Gemfile.lock: Gemfile
	@bundle install

_plugins/jekyll-hackhack:
	@git submodule init
	@git submodule update

s: serve ## Start Jekyll server in watch mode

serve: server ## Start Jekyll server in watch mode

server: bootstrap ## Start Jekyll server in watch mode
	@echo "Starting Jekyll server"
	@bundle exec jekyll server --watch --host 0.0.0.0 --drafts

build: ## Build the project
	@echo "Building mayeu.me"
	@bundle exec jekyll build

help: ## This help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

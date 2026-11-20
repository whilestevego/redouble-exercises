.PHONY: build check test ci

build: ## Parse the sources and merge them with the curation
	dart run bin/build.dart

check: ## Fail if a committed output is stale or a dataset rule breaks
	dart run bin/build.dart --check

test:
	dart test

ci: ## Run before you push
	dart format --output=none --set-exit-if-changed lib bin test
	dart analyze --fatal-infos
	dart test
	dart run bin/build.dart --check

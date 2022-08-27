SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
app_name := $(notdir $(patsubst %/,%,$(project_dir)))
slugname := site1

project_files := $(shell find . -type f -not -path './.git/*' -not -path './dist/*' -not -path './.dist' | sort)

# The version string includes the build metadata
VERSION := $(shell cat VERSION)+$(shell cat $(project_files) | md5sum - | cut -d' ' -f1)

# Verify version string compiles with semver.org, output it for chillbox to use.
inspect.VERSION: ## Show the version string along with build metadata
	@printf "%s" '$(VERSION)' | grep -q -P '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$$' - || (printf "\n%s\n" "ERROR Invalid version string '$(VERSION)' See https://semver.org" >&2 && exit 1)
	@printf "%s" '$(VERSION)'

# For debugging what is set in variables.
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := .dist

.PHONY: all
all: $(objects) ## Default is to make all dist files

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: dist
dist: .dist ## Create dist/* files for distribution

# Run the local-scripts/build.sh script to create the dist/* files.
.dist: local-scripts/local-build.sh $(project_files)
	./$< $(slugname) $(app_name) $(project_dir)
	@touch $@

.PHONY: start
start: ## Start local development
	$(project_dir)/local-scripts/local-start.sh -s $(slugname) -a $(app_name) -p $(project_dir)

.PHONY: clean
clean: ## Remove files that were created
	printf '%s\0' $(objects) | xargs -0 rm -r -f
	rm -rf dist/*

SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
slugname := site1

project_files := $(shell find . -type f -not -path './.git/*' -not -path './dist/*' | sort)

# The version string includes the build metadata
VERSION := $(shell cat chill/VERSION)+$(shell cat $(project_files) | md5sum - | cut -d' ' -f1)

# For debugging what is set in variables. Also is needed to get the VERSION
# variable for chillbox to use.
inspect.%:
	@printf $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := dist/artifact.tar.gz dist/immutable.tar.gz

.PHONY: all
all: $(objects)

dist/artifact.tar.gz: bin/artifact.sh
	./$< $(abspath $@)

dist/immutable.tar.gz: bin/immutable.sh
	./$< $(abspath $@)

.PHONY: clean
clean:
	printf '%s\0' $(objects) | xargs -0 rm -f

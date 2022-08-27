#!/usr/bin/env sh
set -o errexit

test -n "$BUILD_SRC_DIR" || (echo "ERROR $0 BUILD_SRC_DIR is not defined" >&2 && exit 1)
test -d "$BUILD_SRC_DIR" || (echo "ERROR $0 BUILD_SRC_DIR is not a directory" >&2 && exit 1)

test -n "$BUILD_DIST_DIR" || (echo "ERROR $0 BUILD_DIST_DIR is not defined" >&2 && exit 1)

# For this example it is only copying the files from the src directory to the
# dist directory.
rm -rf "$BUILD_DIST_DIR"
mkdir -p "$BUILD_DIST_DIR"
find "$BUILD_SRC_DIR" -depth -mindepth 1 -maxdepth 1 -exec cp -Rf {} "$BUILD_DIST_DIR/" \;

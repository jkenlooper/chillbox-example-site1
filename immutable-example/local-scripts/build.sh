#!/usr/bin/env sh
set -o errexit

src_dir="$1"
dist_dir="$2"

# For this example it is only copying the files from the src directory to the
# dist directory.
rm -rf "$dist_dir"
mkdir -p "$dist_dir"
find "$src_dir" -depth -mindepth 1 -maxdepth 1 -exec cp -Rf {} "$dist_dir/" \;

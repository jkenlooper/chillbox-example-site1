#!/usr/bin/env sh
set -o errexit

src_dir="$1"
dist_dir="$2"

# For this example it is only copying the files from the src directory to the
# dist directory.
rm -rf "$dist_dir"
mkdir -p "$dist_dir"
cp "$src_dir/file1.txt" "$dist_dir/file1.txt"
cp "$src_dir/file2.txt" "$dist_dir/file2.txt"

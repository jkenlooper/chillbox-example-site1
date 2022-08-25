#!/usr/bin/env sh
set -o errexit

script_dir="$(dirname "$(realpath "$0")")"

src_dir="$1"
test -n "$src_dir"
test -d "$src_dir"

dist_dir="$2"
test -n "$dist_dir"


"$script_dir/build.sh" "$src_dir" "$dist_dir"

cd "$dist_dir"
python3 -m http.server "$PORT"

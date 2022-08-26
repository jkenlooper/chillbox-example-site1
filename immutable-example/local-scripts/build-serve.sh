#!/usr/bin/env sh
set -o errexit

script_dir="$(dirname "$(realpath "$0")")"

src_dir="$1"
test -n "$src_dir"
test -d "$src_dir"

dist_dir="$2"
test -n "$dist_dir"

"$script_dir/build.sh" "$src_dir" "$dist_dir"

printf "\n%s\n" "
# Warning
#
# http.server is not recommended for production. It only implements basic
# security checks.
"
set -x
python3 -m http.server --directory "$dist_dir" --bind "$BIND" "$PORT"

#!/usr/bin/env sh
set -o errexit

script_dir="$(dirname "$(realpath "$0")")"

test -n "$BUILD_SRC_DIR"
test -d "$BUILD_SRC_DIR"

test -n "$BUILD_DIST_DIR"

"$script_dir/build.sh"

printf "\n%s\n" "
# Warning
#
# http.server is not recommended for production. It only implements basic
# security checks.
"
set -x
python3 -m http.server --directory "$BUILD_DIST_DIR" --bind "$BIND" "$PORT"

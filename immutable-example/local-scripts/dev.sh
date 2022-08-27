#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HEREUSAGE

Watch for changes in the BUILD_SRC_DIR directory; build and serve the
BUILD_DIST_DIR directory on changes.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

Environment Variables:
  BUILD_SRC_DIR=/build/src
  BUILD_DIST_DIR=/build/dist


HEREUSAGE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

test -n "$BUILD_SRC_DIR"
test -d "$BUILD_SRC_DIR"

test -n "$BUILD_DIST_DIR"

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

watch_files() {
  find "$BUILD_SRC_DIR" > "$tmp_watch_files"
  cat "$tmp_watch_files" | entr -rdn "$script_dir/build-serve.sh"
}

set +o errexit
while true; do
  watch_files
  exit_wf="$?"
  if [ "$exit_wf" != "0" ]; then
    watch_files
  else
    exit "$exit_wf"
  fi
done

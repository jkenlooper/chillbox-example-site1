#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HEREUSAGE

Watch for changes in the provided directory; build and serve on changes.

Usage:
  $script_name -h
  $script_name <src_dir>

Options:
  -h                  Show this help message.

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

src_dir="$1"
test -n "$src_dir"
test -d "$src_dir"

dist_dir="$2"
test -n "$dist_dir"

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

find "$src_dir" >> "$tmp_watch_files"

cat "$tmp_watch_files" | entr -rzdn "$script_dir/build-serve.sh" "$src_dir" "$dist_dir"

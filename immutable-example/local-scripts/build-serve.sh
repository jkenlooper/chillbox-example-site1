#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"
invalid_errcode=4

usage() {
  cat <<HEREUSAGE

Executes the build.sh script and then serves the files in BUILD_DIST_DIR with
the python http.server module.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

Environment Variables:
  BUILD_SRC_DIR=/build/src
  BUILD_DIST_DIR=/build/dist
  BIND=0.0.0.0
  PORT=8080


HEREUSAGE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit "$invalid_errcode" ;;
  esac
done
shift $((OPTIND - 1))

check_for_required_commands() {
  for required_command in \
    realpath \
    python3 \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
}

check_env_vars() {
  test -n "$BUILD_SRC_DIR" || (echo "ERROR $script_name: No BUILD_SRC_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -d "$BUILD_SRC_DIR" || (echo "ERROR $script_name: The BUILD_SRC_DIR environment variable is not set to a directory" >&2 && usage && exit "$invalid_errcode")

  test -n "$BUILD_DIST_DIR" || (echo "ERROR $script_name: No BUILD_DIST_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -n "$BIND" || (echo "ERROR $script_name: No BIND environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -n "$PORT" || (echo "ERROR $script_name: No PORT environment variable defined" >&2 && usage && exit "$invalid_errcode")
}

check_for_required_commands
check_env_vars

"$script_dir/build.sh"

printf "\n%s\n" "
# Warning
#
# http.server is not recommended for production. It only implements basic
# security checks.
"
set -x
python3 -m http.server --directory "$BUILD_DIST_DIR" --bind "$BIND" "$PORT"

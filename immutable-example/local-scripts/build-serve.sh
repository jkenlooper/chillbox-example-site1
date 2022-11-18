#!/usr/bin/env sh
set -o errexit

# This file in the parent directory immutable-example was generated from the immutable-make directory in https://github.com/jkenlooper/cookiecutters . Any modifications needed to this file should be done on that originating file.
# Version: 0.0.1-alpha.1

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"
. "$script_dir/check-in-container.sh"
invalid_errcode=4

usage() {
  cat <<HEREUSAGE

Executes the build.sh script and then serves the files in /build/dist/ with
the python http.server module.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

Environment Variables:
  BIND=0.0.0.0
  IMMUTABLE_EXAMPLE_PORT=8080


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

has_python3="$(command -v python3 || printf "")"
has_thttpd="$(command -v thttpd || printf "")"
check_for_required_commands() {
  for required_command in \
    tree \
    realpath \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
  if [ -z "$has_python3" ] && [ -z "$has_thttpd" ]; then
    echo "ERROR $script_name: Requires either 'python3' or 'thttpd' command." >&2
    exit "$invalid_errcode"
  fi
}

check_env_vars() {
  test -n "$BIND" || (echo "ERROR $script_name: No BIND environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -n "$IMMUTABLE_EXAMPLE_PORT" || (echo "ERROR $script_name: No IMMUTABLE_EXAMPLE_PORT environment variable defined" >&2 && usage && exit "$invalid_errcode")
}

check_in_container "make help"

check_for_required_commands
check_env_vars

"$script_dir/build.sh"

tree -a "/build/dist"
if [ -n "$has_thttpd" ]; then
  # Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
  set -x
  thttpd -D -h "$BIND" -p "$IMMUTABLE_EXAMPLE_PORT" -d "/build/dist" -u dev -l - -M 1
elif [ -n "$has_python3" ]; then
  printf "\n%s\n" "
  # Warning
  #
  # http.server is not recommended for production. It only implements basic
  # security checks.
  "
  set -x
  python3 -m http.server --directory "/build/dist" --bind "$BIND" "$IMMUTABLE_EXAMPLE_PORT"
else
  echo "ERROR $script_name: Unhandled condition." >&2
  exit 8
fi

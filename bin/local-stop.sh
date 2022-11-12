#!/usr/bin/env sh

set -o errexit

slugname=site1
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"

. "$script_dir/utils.sh"

stop_and_rm_containers_silently "$slugname"

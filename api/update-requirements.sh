#!/usr/bin/env sh

set -o errexit


script_dir="$(dirname "$(realpath "$0")")"
script_name="$(basename "$0")"

name_hash="$(printf "%s" "$script_dir" | md5sum | cut -d' ' -f1)"
test "${#name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a name hash from the directory ($script_dir)" && exit 1)

usage() {
  cat <<HERE
Update the python requirement txt files.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

HERE
}

slugname=""

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

image_name="update-requirements-$name_hash"
docker image rm "$image_name" > /dev/null 2>&1 || printf ""
DOCKER_BUILDKIT=1 docker build \
  -t "$image_name" \
  -f "$script_dir/update-requirements.Dockerfile" \
  "$script_dir"

container_name="update-requirements-$name_hash"
docker run -d \
  --name "$container_name" \
  "$image_name"

docker cp "$container_name:/home/dev/requirements/." "requirements/"
docker stop --time 0 "$container_name" > /dev/null 2>&1 || printf ""
docker rm "$container_name" > /dev/null 2>&1 || printf ""

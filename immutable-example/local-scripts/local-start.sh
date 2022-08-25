#!/usr/bin/env sh

set -o errexit

slugname="$1"
appname="$2"
project_dir="$3"

script_dir="$(dirname "$(realpath "$0")")"
script_filename="$(basename "$0")"
script_name="$(basename "$0" ".sh")"
image_name="$slugname-$appname-$script_name"
container_name="$slugname-$appname-$script_name"

stop_and_rm_containers_silently () {
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant like a lost llama.
  docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  wait

  docker container rm "$container_name" > /dev/null 2>&1 || printf ''
}
stop_and_rm_containers_silently

docker image rm "$image_name" > /dev/null 2>&1 || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --target build \
  -t "$image_name" \
  "${project_dir}"
docker run -i --tty \
  -p 8080:8080 \
  --mount "type=bind,src=${project_dir}/src,dst=/build/src" \
  --name "$container_name" \
  "$image_name"

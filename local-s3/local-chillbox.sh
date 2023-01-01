#!/usr/bin/env sh

set -o errexit

slugname="site1"

project_dir="$(dirname "$(realpath "$0")")"
script_name="$(basename "$0")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)
project_dir_basename="$(basename "$project_dir")"

site_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/$slugname-$project_dir_basename--$project_name_hash"
mkdir -p "$site_data_home"

usage() {
  cat <<HERE
Start up a local s3 container using minio.

The local minio container is shared between multiple apps on a local machine.
This should skip rebuilding it if it is already up and running. A new user for
the app is created as part of this execution of the script. The docker exec
command is used to accomplish that. The credentials to connect to the local s3
is stored on a docker volume that can be used by other containers that need to
access the local s3.

Usage:
  $script_name -h

Options:
  -h                  Show this help message.

Environment:
  MINIO_ROOT_USER     Default is 'chillbox-admin'
  MINIO_ROOT_PASSWORD Default is 'chillllamabox'

Docker volumes:
  chillbox-minio-data                    Stores Minio data.
  chillbox-local-shared-secrets-var-lib  Has the local s3 credential files

Files:
  $site_data_home/local-chillbox_object_storage-credentials

HERE
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

# UPKEEP due: "2022-06-15" label: "bitnami/minio image" interval: "2 months"
#docker pull bitnami/minio:2022.3.26-debian-10-r4
#docker image ls --digests bitnami/minio
# https://github.com/bitnami/bitnami-docker-minio
minio_image="bitnami/minio:2022.3.26-debian-10-r4@sha256:398ea232ada79b41d2d0b0b96d7d01be723c0c13904b58295302cb2908db7022"

# These are only used for local development. The credentials specified here are
# used for the local S3 object storage server (Minio).
# WARNING: Do NOT use actual AWS credentials here!
# The access key id is also used as the user name and has a limit of 64 characters.
local_chillbox_app_key_id="$(printf "%s" "$slugname-$project_dir_basename--$project_name_hash" | grep -o -E '^.{0,64}')"
local_chillbox_secret_access_key="readwrite-policy-$slugname-$project_dir_basename--$project_name_hash"

# The bucket names are meant to be shared across multiple local apps. This
# matches the chillbox design used in production.
immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
MINIO_ROOT_USER=${MINIO_ROOT_USER:-'chillbox-admin'}
test "${#MINIO_ROOT_USER}" -ge 3 || (echo "Minio root user must be greater than 3 characters" && exit 1)
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-'chillllamabox'}
test "${#MINIO_ROOT_PASSWORD}" -ge 8 || (echo "Minio root password must be greater than 8 characters" && exit 1)

# Only create the chillboxnet network if it doesn't exist. Ignoring any output
# to keep the stdout clean.
chillboxnet_id="$(docker network ls -q -f name=chillboxnet 2> /dev/null || printf "")"
if [ -z "$chillboxnet_id" ]; then
  docker network create chillboxnet --driver bridge > /dev/null 2>&1 || printf ""
fi

is_chillbox_minio_running="$(docker inspect --format '{{.State.Running}}' chillbox-minio 2> /dev/null || printf "")"
if [ "$is_chillbox_minio_running" != "true" ]; then
  docker run --name chillbox-minio \
    -d \
    --tty \
    --env MINIO_ROOT_USER="$MINIO_ROOT_USER" \
    --env MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
    --env MINIO_DEFAULT_BUCKETS="${immutable_bucket_name}:public,${artifact_bucket_name}" \
    --publish 9000:9000 \
    --publish 9001:9001 \
    --network chillboxnet \
    --mount 'type=volume,src=chillbox-minio-data,dst=/data,readonly=false' \
    "$minio_image"
fi

printf "\n%s\n" "Waiting for chillbox-minio container to be in running state."
while true; do
  is_chillbox_minio_running="$(docker inspect --format '{{.State.Running}}' chillbox-minio 2> /dev/null || printf "")"
  if [ "$is_chillbox_minio_running" = "true" ]; then
    printf "."
    # Try to run a minio-client command to check if the minio server is online.
    docker exec chillbox-minio mc admin info local --json | jq --exit-status '.info.mode == "online"' > /dev/null 2>&1 || continue
    # Need to also check if the 'mc admin user list' command will respond
    docker exec chillbox-minio mc admin user list local > /dev/null 2>&1 || continue
    echo ""
    break
  else
    chillbox_minio_state="$(docker inspect --format '{{.State.Status}}' chillbox-minio 2> /dev/null || printf "")"
    printf "%s ..." "$chillbox_minio_state"
  fi
  sleep 0.1
done
echo ""
docker logs chillbox-minio
# The user and policy may already exist. Ignore errors here.
docker exec chillbox-minio mc admin user add local "${local_chillbox_app_key_id}" "${local_chillbox_secret_access_key}" 2> /dev/null || printf ""
docker exec chillbox-minio mc admin policy set local readwrite user="${local_chillbox_app_key_id}" 2> /dev/null || printf ""

# Don't show errors when restarting this container.
docker stop --time 0 chillbox-local-shared-secrets > /dev/null 2>&1 || printf ""
docker rm  chillbox-local-shared-secrets > /dev/null 2>&1 || printf ""
docker image rm chillbox-local-shared-secrets > /dev/null 2>&1 || printf ""
# Avoid adding docker context by using stdin for the Dockerfile.
DOCKER_BUILDKIT=1 docker build --progress=plain -t chillbox-local-shared-secrets - < "$project_dir/local-shared-secrets.Dockerfile" > /dev/null 2>&1
docker run -d --rm \
  --name  chillbox-local-shared-secrets \
  --mount "type=volume,src=chillbox-local-shared-secrets-var-lib,dst=/var/lib/chillbox-shared-secrets,readonly=false" \
  chillbox-local-shared-secrets > /dev/null

printf "\n%s\n" "Waiting for chillbox-local-shared-secrets container to be in running state."
while true; do
  is_chillbox_local_shared_secrets_running="$(docker inspect --format '{{.State.Running}}' chillbox-local-shared-secrets 2> /dev/null || printf "")"
  if [ "$is_chillbox_local_shared_secrets_running" = "true" ]; then
    chillbox_local_shared_secrets_state="$(docker inspect --format '{{.State.Status}}' chillbox-local-shared-secrets 2> /dev/null || printf "")"
    echo "chillbox-local-shared-secrets: $chillbox_local_shared_secrets_state"
    break
  else
    printf "."
    sleep 0.1
  fi
done

cat <<HERE > "$site_data_home/local-chillbox_object_storage-credentials"
[chillbox_object_storage]
# Generated via $0
aws_access_key_id=${local_chillbox_app_key_id}
aws_secret_access_key=${local_chillbox_secret_access_key}
HERE

# Make this local-chillbox_object_storage-credentials available for other
# containers that may need to interact with the local chillbox minio s3 object
# store.
docker exec --user root chillbox-local-shared-secrets mkdir -p "/var/lib/chillbox-shared-secrets/chillbox-minio/$slugname-$project_dir_basename"
docker exec --user root chillbox-local-shared-secrets chmod -R 700 "/var/lib/chillbox-shared-secrets/chillbox-minio/$slugname-$project_dir_basename"
docker exec --user root chillbox-local-shared-secrets chown -R dev:dev "/var/lib/chillbox-shared-secrets/chillbox-minio/$slugname-$project_dir_basename"
docker cp "$site_data_home/local-chillbox_object_storage-credentials" chillbox-local-shared-secrets:"/var/lib/chillbox-shared-secrets/chillbox-minio/$slugname-$project_dir_basename/local-chillbox_object_storage-credentials"

#!/usr/bin/env bash

set -o errexit

warning_message_about_local_use="

***
WARNING The private key is not stored securely! Do not encrypt sensitive information with this script.
***

"

slugname=site1

script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
script_name="$(basename "$0")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)

# Storing the encrypted secrets in the user data directory for this site
# depending on the project directory path at the time.
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
site_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/$slugname--$project_name_hash"

encrypted_secrets_dir="$site_data_home/encrypted-secrets"

not_secure_key_dir="$site_data_home/not-secure-keys


usage() {
  cat <<HERE
For each service that has a secrets config; build and run the secrets
Dockerfile.  The encrypted secrets will be stored in the current user's data
directory.  The encrypted secret files are decrypted by each service container's
private key.

$warning_message_about_local_use

This script is only for local development and any secrets that are encrypted
should not be considered sensitive. Do not use secrets that can be used outside
of the local machine like credentials or API keys to third party services.

The local development of a site should not need access to remote services.
"
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

# TODO The encrypt-file script has been copied from the chillbox repository. May
# want to grab that from a gist or something instead?
# Provide encrypt-file script for the service handler container to use.
cp "$project_dir/bin/encrypt-file" "$not_secure_key_dir"

site_json="$project_dir/local.site.json"

services="$(jq -c '.services // [] | .[]' "$site_json")"
test -n "${services}" || (echo "WARNING $script_name: No services found in $site_json." && exit 0)

for service_obj in $services; do
  test -n "${service_obj}" || continue

  secrets_config="$(echo "$service_obj" | jq -r '.secrets_config // ""')"
  test -n "$secrets_config" || continue
  service_handler="$(echo "$service_obj" | jq -r '.handler')"
  secrets_export_dockerfile="$(echo "$service_obj" | jq -r '.secrets_export_dockerfile // ""')"
  test -n "$secrets_export_dockerfile" || (echo "ERROR $script_name: No secrets_export_dockerfile value set in services, yet secrets_config is defined. $slugname - $service_obj" && exit 1)

  encrypted_secret_service_dir="$encrypted_secrets_dir/$service_handler"
  mkdir -p "$encrypted_secret_service_dir"

  public_key="$not_secure_key_dir/$service_handler.public.pem"
  test -f "$public_key" || (echo "ERROR $script_name: No public key at $public_key" && exit 1)

  replace_secret_file=""
  encrypted_secret_file="$encrypted_secrets_dir/$service_handler/$secrets_config"

  if [ -e "$encrypted_secret_file" ]; then
    echo "The encrypted file already exists at $encrypted_secret_file"
    echo "Replace this file? y/n"
    read -r replace_secret_file
    test "$replace_secret_file" = "y" || continue
  fi
  rm -f "$encrypted_secret_file"

  # TODO continue from line 166 of encrypt-and-upload-secrets.sh

  # ---

  docker image rm "$slugname-api" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
    -t "$slugname-api" \
    "${project_dir}/api"
  # Switch to root user when troubleshooting or using bind mounts
  echo "Running the $slugname-api container with root user."
  docker run -d --tty \
    --name "$slugname-api" \
    --user root \
    --env-file "$site_env_vars_file" \
    -e HOST="localhost" \
    -e PORT="$API_PORT" \
    --network chillboxnet \
    --mount "type=bind,src=${project_dir}/api/src/site1_api,dst=/usr/local/src/app/src/site1_api,readonly" \
    $slugname-api ./flask-run.sh

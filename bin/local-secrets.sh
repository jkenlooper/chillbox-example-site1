#!/usr/bin/env bash

set -o errexit

warning_message_about_local_use="
*** WARNING ***

Do not input sensitive information when using this script.

*** WARNING ***
"

slugname=site1

script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
script_name="$(basename "$0")"
project_dir_basename="$(basename "$project_dir")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)

# Storing the encrypted secrets in the user data directory for this site
# depending on the project directory path at the time.
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
site_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/$project_dir_basename-$slugname--$project_name_hash"

encrypted_secrets_dir="$site_data_home/encrypted-secrets"

not_secure_key_dir="$site_data_home/not-secure-keys"


usage() {
  cat <<HERE
For each service that has a secrets config; build and run the secrets
Dockerfile. To avoid any sense of false security, the encryption of these
secrets does not happen and no actual private or public keys are used.

$warning_message_about_local_use

This script is only for local development and any secrets that are entered
should not be considered sensitive. Do not use secrets that can be used outside
of the local machine like credentials or API keys to third party services.

The local development of a site should not need access to remote services.
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


# The fake-encrypt-file script closely matches the encrypt-file from the
# chillbox repository.
mkdir -p "$not_secure_key_dir"
cat <<'FAKE_ENCRYPT_FILE' > "$not_secure_key_dir/fake-encrypt-file"
#!/usr/bin/env sh

set -o errexit

echo "
WARNING: Not using encryption for the file. This is only for local development.
"

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Fake the encryption of a small (less than 382 bytes) file using a provided
public key file in PEM format. This should only be used for local development
purposes when the file does not have any sensitive information in it. The public
key file is not actually used.

Usage:
  $script_name -h
  $script_name <options> -
  $script_name <options> <file>

Options:
  -h        Show this help message.

  -k        A public key file in PEM format

  -o        Path to output the encrypted file (will NOT be encrypted)

Args:
  -         Encrypt what is passed to stdin (will NOT be encrypted)

  <file>    Encrypt the provided file (will NOT be encrypted)

HERE
}

fake_encrypt_file() {
  printf "%s" "$input_plaintext" | \
  cat > "$output_ciphertext_file"
}

while getopts "hk:o:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    k) public_pem_file=$OPTARG ;;
    o) output_ciphertext_file=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))
input_plaintext_file="${1:--}"
input_plaintext=""

# Need to check the length of plaintext since this key is only meant for small payloads.
# https://crypto.stackexchange.com/questions/42097/what-is-the-maximum-size-of-the-plaintext-message-for-rsa-oaep/42100#42100

if [ "$input_plaintext_file" = "-" ]; then
  IFS="" read -r input_plaintext
  input_plaintext_size="${#input_plaintext}"
  test -n "$input_plaintext" || (echo "ERROR $script_name: No content to encrypt." && exit 1)
  test -n "$input_plaintext_size" || (echo "ERROR $script_name: Failed to get size of plaintext." && exit 1)
  test "$input_plaintext_size" -le "382" || (echo "ERROR $script_name: The plaintext byte length is over the 382 byte limit allowed for the key." && exit 1)
else
  test -e "$input_plaintext_file"
  plaintext_filesize="$(stat -c '%s' "$input_plaintext_file")"
  test -n "$plaintext_filesize" || (echo "ERROR $script_name: Failed to get size of plaintext file." && exit 1)
  test "$plaintext_filesize" -le "382" || (echo "ERROR $script_name: The plaintext byte length is over the 382 byte limit allowed for the key." && exit 1)
  input_plaintext="$(cat "$input_plaintext_file")"
fi

if [ ! -e "$public_pem_file" ]; then
  echo "ERROR $script_name: The public key doesn't exist. $public_pem_file"
  exit 4
fi

fake_encrypt_file
FAKE_ENCRYPT_FILE
chmod +x "$not_secure_key_dir/fake-encrypt-file"

# Sleeper image needs no context.
sleeper_image="$project_name_hash-sleeper"
docker image rm "$sleeper_image" || printf ""
export DOCKER_BUILDKIT=1
< "$project_dir/bin/sleeper.Dockerfile" \
  docker build \
    -t "$sleeper_image" \
    -

site_json="$project_dir/local.site.json"
version="0.0.0-local+$project_name_hash"

services="$(jq -c '.services // [] | .[]' "$site_json")"
test -n "${services}" || (echo "WARNING $script_name: No services found in $site_json." && exit 0)

for service_obj in $services; do
  test -n "${service_obj}" || continue

  secrets_config="$(echo "$service_obj" | jq -r '.secrets_config // ""')"
  test -n "$secrets_config" || continue
  service_handler="$(echo "$service_obj" | jq -r '.handler')"
  secrets_export_dockerfile="$(echo "$service_obj" | jq -r '.secrets_export_dockerfile // ""')"
  test -n "$secrets_export_dockerfile" || (echo "ERROR $script_name: No secrets_export_dockerfile value set in services, yet secrets_config is defined. $slugname - $service_obj" && exit 1)

  encrypted_secret_service_dir="$encrypted_secrets_dir"
  mkdir -p "$encrypted_secret_service_dir"

  public_key="$not_secure_key_dir/$service_handler.public.pem"

  # For local development only! Create the public key as an empty file if it doesn't exist.
  touch "$public_key"

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

  test -f "$project_dir/$service_handler/$secrets_export_dockerfile" || (echo "ERROR: No secrets export dockerfile at path: $project_dir/$service_handler/$secrets_export_dockerfile" && exit 1)

  service_image_name="$slugname-$service_handler-$project_name_hash"
  container_name="$service_image_name"
  tmpfs_dir="/run/tmp/$service_image_name"
  service_persistent_dir="/var/lib/$slugname-$service_handler"
  chillbox_pubkey_dir="/var/lib/chillbox/public-keys"

  docker image rm "$service_image_name" || printf ""
  export DOCKER_BUILDKIT=1
  docker build \
    --build-arg SECRETS_CONFIG="$secrets_config" \
    --build-arg CHILLBOX_PUBKEY_DIR="$chillbox_pubkey_dir" \
    --build-arg TMPFS_DIR="$tmpfs_dir" \
    --build-arg SERVICE_PERSISTENT_DIR="$service_persistent_dir" \
    --build-arg SLUGNAME="$slugname" \
    --build-arg VERSION="$version" \
    --build-arg SERVICE_HANDLER="$service_handler" \
    -t "$service_image_name" \
    -f "$project_dir/$service_handler/$secrets_export_dockerfile" \
    "$project_dir/$service_handler/"
  # Echo out something after a docker build to clear/reset the stdout.
  clear && echo "INFO $script_name: finished docker build of $service_image_name"

  clear && echo "INFO $script_name: Running the container $container_name in interactive mode to encrypt and upload secrets. This container is using docker image $service_image_name and the Dockerfile $project_dir/$service_handler/$secrets_export_dockerfile"
  docker run \
    -i --tty \
    --rm \
    --name "$container_name" \
    -e ENCRYPT_FILE=fake-encrypt-file \
    --mount "type=tmpfs,dst=$tmpfs_dir" \
    --mount "type=volume,src=dir-var-lib-$service_image_name,dst=$service_persistent_dir" \
    --mount "type=bind,src=$not_secure_key_dir,dst=$chillbox_pubkey_dir,readonly=true" \
    "$service_image_name" || (
      exitcode="$?"
      echo "docker exited with $exitcode exitcode. Continue? [y/n]"
      read -r docker_continue_confirm
      test "$docker_continue_confirm" = "y" || exit $exitcode
    )

  docker run \
    -d \
    --name "$container_name-sleeper" \
    --mount "type=volume,src=dir-var-lib-$service_image_name,dst=$service_persistent_dir" \
    "$sleeper_image" || (
      exitcode="$?"
      echo "docker exited with $exitcode exitcode. Ignoring"
    )
  docker cp "$container_name-sleeper:$service_persistent_dir/encrypted-secrets/." "$encrypted_secret_service_dir/" || echo "Ignore docker cp error."
  docker stop --time 0 "$container_name-sleeper" || printf ""
  docker rm "$container_name-sleeper" || printf ""

done

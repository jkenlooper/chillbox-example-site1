#!/usr/bin/env bash

set -o errexit

# Build and run each container in detached mode.
# For development only; each one will rebuild on file changes.

slugname=site1
app_port=8088
NODE_ENV=${NODE_ENV-"development"}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
site_version_string="$(make --silent -C "$project_dir" inspect.VERSION)"
immutable_example_hash="$(make --silent -C "$project_dir/immutable-example/" inspect.HASH)"
immutable_example_port=8080
site_env_vars_file="$project_dir/.local-start-site-env-vars"

cat <<MEOW > "$site_env_vars_file"
ARTIFACT_BUCKET_NAME=chillboxartifact
AWS_PROFILE=chillbox_object_storage
CHILLBOX_ARTIFACT=not-applicable
CHILLBOX_SERVER_NAME=chillbox.test
CHILLBOX_SERVER_PORT=80
IMMUTABLE_BUCKET_DOMAIN_NAME=http://chillbox-minio:9000
IMMUTABLE_BUCKET_NAME=chillboximmutable
LETS_ENCRYPT_SERVER=letsencrypt_test
S3_ENDPOINT_URL=http://chillbox-minio:9000
# Not setting server_name to allow it to be set differently in each Dockerfile
# if needed.
#SERVER_NAME=
SERVER_PORT=$app_port
SITES_ARTIFACT=not-applicable
SLUGNAME=$slugname
TECH_EMAIL=me@local.test
VERSION=$site_version_string
CHILL_STATIC_EXAMPLE_TRY_FILES_LAST_PARAM=@chill-static-example
CHILL_STATIC_EXAMPLE_PATH=/
CHILL_STATIC_EXAMPLE_PORT=5000
CHILL_STATIC_EXAMPLE_SCHEME=http
CHILL_STATIC_EXAMPLE_HOST=$slugname-chill-static-example
CHILL_DYNAMIC_EXAMPLE_PATH=/dynamic/
CHILL_DYNAMIC_EXAMPLE_PORT=5001
CHILL_DYNAMIC_EXAMPLE_SCHEME=http
CHILL_DYNAMIC_EXAMPLE_HOST=$slugname-chill-dynamic-example
API_PATH=/api/
API_PORT=8100
API_SCHEME=http
API_HOST=$slugname-api
IMMUTABLE_EXAMPLE_HASH=$immutable_example_hash
IMMUTABLE_EXAMPLE_PATH=/immutable-example/v1/$immutable_example_hash/
IMMUTABLE_EXAMPLE_PORT=$immutable_example_port
IMMUTABLE_EXAMPLE_URL=http://$slugname-immutable-example:$immutable_example_port/
MEOW
. "$site_env_vars_file"

stop_and_rm_containers_silently () {
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  docker stop --time 1 $slugname-chill-dynamic-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-api > /dev/null 2>&1 &
  docker stop --time 1 $slugname-chill-static-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-immutable-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-nginx > /dev/null 2>&1 &
  wait

  docker container rm $slugname-chill-dynamic-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-api > /dev/null 2>&1 || printf ''
  docker container rm $slugname-chill-static-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-immutable-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-nginx > /dev/null 2>&1 || printf ''
}
stop_and_rm_containers_silently

chillbox_minio_state="$(docker inspect --format '{{.State.Running}}' chillbox-minio || printf "false")"
chillbox_local_shared_secrets_state="$(docker inspect --format '{{.State.Running}}' chillbox-local-shared-secrets || printf "false")"
if [ "${chillbox_minio_state}" = "true" ] && [ "${chillbox_local_shared_secrets_state}" = "true" ]; then
  echo "chillbox local is running"
else
  "${project_dir}/local-s3/local-chillbox.sh"
fi


# The ports on these do not need to be exposed since nginx is in front of them.

build_start_immutable_example() {
  docker image rm "$slugname-immutable-example" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      --target build \
      -t "$slugname-immutable-example" \
      "${project_dir}/immutable-example"
  docker run -d \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=${project_dir}/immutable-example/src,dst=/build/src" \
    --name "$slugname-immutable-example" "$slugname-immutable-example"
}

build_start_api() {
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
}

build_start_chill_static_example() {
  docker image rm "$slugname-chill-static-example" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$slugname-chill-static-example" \
      "${project_dir}/chill-static-example"
  docker run -d \
    --name "$slugname-chill-static-example" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=${project_dir}/chill-static-example/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=${project_dir}/chill-static-example/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=${project_dir}/chill-static-example/templates,dst=/home/chill/app/templates" \
    "$slugname-chill-static-example"
}

build_start_chill_dynamic_example() {
  docker image rm "$slugname-chill-dynamic-example" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$slugname-chill-dynamic-example" \
      "${project_dir}/chill-dynamic-example"
  docker run -d \
    --name "$slugname-chill-dynamic-example" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/templates,dst=/home/chill/app/templates" \
    "$slugname-chill-dynamic-example"
}

build_start_nginx() {
  docker image rm "$slugname-nginx" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$slugname-nginx" \
      "${project_dir}/nginx"
  docker run -d \
    -p "$app_port:$app_port" \
    --name "$slugname-nginx" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=${project_dir}/nginx/templates,dst=/build/templates" \
    "$slugname-nginx"
}

# TODO Prompt to update or create the local secrets file for the api service to
# use. Should create a new asymmetric key pair if no key pair exists yet. The
# secret env file should be encrypted and saved locally. Only the private key
# will be on the container, but since the container is ephemeral it will also be
# encrypted with a public gpg key from the host.

# 1) Add a public gpg key for a local container to use.
# 2) Include public gpg key as a bind mount or save it on a volume which can be
# mounted.
# 3) Create a new asymmetric key on the local container that will use the
# secret.
# 4) Encrypt the new asymmetric secret key with the gpg public key.
# 5) Save the new asymmetric public key in a volume.
# 6) Save the encrypted asymmetric private key in a volume.
# 7)
#
# 1) ...Or just don't care about local secrets as they shouldn't be considered
# sensitive. Bind mount the config file that is in plaintext.
# Should the script run the api-bridge.Dockerfile?
#

build_start_immutable_example
build_start_api
build_start_chill_static_example
build_start_chill_dynamic_example
build_start_nginx

sleep 2
for container_name in \
  $slugname-chill-static-example \
  $slugname-chill-dynamic-example \
  $slugname-immutable-example \
  $slugname-api \
  $slugname-nginx \
  ; do
  echo ""
  echo "### Logs for $container_name ###"
  docker logs $container_name
  echo ""
  echo "### End logs for $container_name ###"
  echo ""
done

for container_name in \
  $slugname-chill-static-example \
  $slugname-chill-dynamic-example \
  $slugname-immutable-example \
  $slugname-api \
  $slugname-nginx \
  ; do
  echo "$container_name $(docker container inspect $container_name | jq '.[0].State.Status + .[0].State.Error')"
done

echo "The $slugname site is running on http://localhost:$app_port/ "



#docker logs --follow $slugname-nginx

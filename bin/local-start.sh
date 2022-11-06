#!/usr/bin/env bash

set -o errexit

# Build and run each container in detached mode.
# For development only; each one will rebuild on file changes.

slugname=site1
app_port=8088
NODE_ENV=${NODE_ENV-"development"}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
IMMUTABLE_EXAMPLE_PORT=8080
CHILL_STATIC_EXAMPLE_PORT=5000
CHILL_DYNAMIC_EXAMPLE_PORT=5001
API_PORT="8100"

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

site_version_string="$(make --silent -C "$project_dir" inspect.VERSION)"
immutable_example_hash="$(make --silent -C "$project_dir/immutable-example/" inspect.HASH)"

# The ports on these do not need to be exposed since nginx is in front of them.

build_start_immutable_example() {
  docker image rm "$slugname-immutable-example" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      --target build \
      -t "$slugname-immutable-example" \
      "${project_dir}/immutable-example"
  docker run -d \
    --network chillboxnet \
    -e PORT="$IMMUTABLE_EXAMPLE_PORT" \
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
    -e SERVER_NAME="site1-api:8100" \
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
    --mount "type=bind,src=${project_dir}/chill-static-example/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=${project_dir}/chill-static-example/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=${project_dir}/chill-static-example/templates,dst=/home/chill/app/templates" \
    -e CHILL_PORT="$CHILL_STATIC_EXAMPLE_PORT" \
    -e CHILL_MEDIA_PATH="/media/" \
    -e CHILL_THEME_STATIC_PATH="/theme/0/" \
    -e CHILL_DESIGN_TOKENS_HOST="/design-tokens/0/" \
    -e IMMUTABLE_EXAMPLE_PATH="/immutable-example/v1/fake-hash/" \
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
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=${project_dir}/chill-dynamic-example/templates,dst=/home/chill/app/templates" \
    -e CHILL_MEDIA_PATH="/media/" \
    -e CHILL_THEME_STATIC_PATH="/theme/0/" \
    -e CHILL_DESIGN_TOKENS_HOST="/design-tokens/0/" \
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
    --mount "type=bind,src=${project_dir}/nginx/templates,dst=/build/templates" \
    -e SLUGNAME="$slugname" \
    -e VERSION="$site_version_string" \
    -e SERVER_PORT="$app_port" \
    -e IMMUTABLE_BUCKET_DOMAIN_NAME="http://chillbox-minio:9000" \
    -e IMMUTABLE_EXAMPLE_URL="http://$slugname-immutable-example:8080/" \
    -e IMMUTABLE_EXAMPLE_PATH="/immutable-example/v1/fake-hash/" \
    -e API_PORT="$API_PORT" \
    -e API_URL="http://$slugname-api:$API_PORT/" \
    -e CHILL_STATIC_EXAMPLE_TRY_FILES_LAST_PARAM="@chill-static-example" \
    -e CHILL_STATIC_EXAMPLE_PORT="$CHILL_STATIC_EXAMPLE_PORT" \
    -e CHILL_STATIC_EXAMPLE_URL="http://$slugname-chill-static-example:$CHILL_STATIC_EXAMPLE_PORT/" \
    -e CHILL_DYNAMIC_EXAMPLE_PORT="$CHILL_DYNAMIC_EXAMPLE_PORT" \
    -e CHILL_DYNAMIC_EXAMPLE_URL="http://$slugname-chill-dynamic-example:$CHILL_DYNAMIC_EXAMPLE_PORT/" \
    "$slugname-nginx"
}

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

#!/usr/bin/env bash

set -o errexit

# Build and run each container in detached mode.
# For development only; each one will rebuild on file changes.

slugname=site1
app_port=8088
NODE_ENV=${NODE_ENV-"development"}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"

stop_and_rm_containers_silently () {
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  docker stop --time 10 $slugname-chill-dynamic-example > /dev/null 2>&1 &
  docker stop --time 10 $slugname-api > /dev/null 2>&1 &
  docker stop --time 10 $slugname-chill-static-example > /dev/null 2>&1 &
  docker stop --time 10 $slugname-immutable-example > /dev/null 2>&1 &
  docker stop --time 10 $slugname-nginx > /dev/null 2>&1 &
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

# Always replace the square/secrets.cfg when starting up.
docker exec -it -u root chillbox-local-shared-secrets mkdir -p /var/lib/chillbox-shared-secrets/awesomemudworks
docker exec -it -u root chillbox-local-shared-secrets chmod -R 700 /var/lib/chillbox-shared-secrets/awesomemudworks
docker exec -it -u root chillbox-local-shared-secrets rm -f /var/lib/chillbox-shared-secrets/awesomemudworks/square.cfg
docker cp "${project_dir}/square/secrets.cfg" chillbox-local-shared-secrets:/var/lib/chillbox-shared-secrets/awesomemudworks/square.cfg

# The ports on these do not need to be exposed since nginx is in front of them.
docker image rm "$slugname-immutable-example" || printf ""
DOCKER_BUILDKIT=1 docker build \
    --target build \
    -t "$slugname-immutable-example" \
    "${project_dir}/immutable-example"
docker run -d \
  --network chillboxnet \
  --mount "type=bind,src=${project_dir}/immutable-example/src,dst=/build/src" \
  --name "$slugname-immutable-example" "$slugname-immutable-example"

#"${project_dir}/square/secrets.cfg.sh"
#secrets_square_config="${project_dir}/square/secrets.cfg"
#docker exec --user root chillbox-local-shared-secrets mkdir -p /var/lib/chillbox-shared-secrets/awesomemudworks
#docker exec --user root chillbox-local-shared-secrets chmod -R 700 /var/lib/chillbox-shared-secrets/awesomemudworks
#docker cp "${secrets_square_config}" chillbox-local-shared-secrets:/var/lib/chillbox-shared-secrets/awesomemudworks/square.cfg
#docker exec --user root chillbox-local-shared-secrets chown -R dev:dev /var/lib/chillbox-shared-secrets/awesomemudworks

# Use the '--network host' in order to connect to the local s3 (minio) when
# building.
docker image rm "$slugname-api" || printf ""
DOCKER_BUILDKIT=1 docker build \
  -t "$slugname-api" \
  --build-arg S3_ENDPOINT_URL="http://$(docker container inspect chillbox-minio | jq -r '.[0].NetworkSettings.IPAddress'):9000" \
  --build-arg ARTIFACT_BUCKET_NAME="chillboxartifact" \
  --build-arg IMMUTABLE_BUCKET_NAME="chillboximmutable" \
  --network host \
  "${project_dir}/api"
# Switch to root user when troubleshooting or using bind mounts
echo "Running the $slugname-api container with root user."
docker run -i --tty \
  --name "$slugname-api" \
  --user root \
  -e SERVER_NAME="localhost:$app_port" \
  -e HOST="0.0.0.0" \
  -e PORT="8100" \
  -e AWS_PROFILE="local-chillbox" \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e ARTIFACT_BUCKET_NAME="chillboxartifact" \
  -e IMMUTABLE_BUCKET_NAME="chillboximmutable" \
  --network chillboxnet \
  --mount "type=volume,src=chillbox-local-shared-secrets-var-lib,dst=/var/lib/chillbox-shared-secrets,readonly=false" \
  --mount "type=bind,src=${project_dir}/api/src/site1_api,dst=/usr/local/src/app/src/site1_api,readonly" \
  $slugname-api sh
  #$slugname-api su -c './dev.sh' dev

docker image rm "$slugname-chill-static-example" || printf ""
DOCKER_BUILDKIT=1 docker build \
    -t "$slugname-chill-static-example" \
    "${project_dir}/chill-static-example"
docker run -d \
  --name "$slugname-chill-static-example" \
  --network chillboxnet \
  --mount "type=bind,src=${project_dir}/chill-static-example/documents,dst=/home/chill/app/documents" \
  --mount "type=bind,src=${project_dir}/chill-static-example/queries,dst=/home/chill/app/queries" \
  --mount "type=bind,src=${project_dir}/chill-static-example/templates,dst=/home/chill/app/templates" \
  -e CHILL_MEDIA_PATH="/media/" \
  -e CHILL_THEME_STATIC_PATH="/theme/0/" \
  -e CHILL_DESIGN_TOKENS_HOST="/design-tokens/0/" \
  "$slugname-chill-static-example"

docker image rm "$slugname-chill-dynamic-example" || printf ""
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

docker image rm "$slugname-nginx" || printf ""
DOCKER_BUILDKIT=1 docker build \
    -t "$slugname-nginx" \
    "${project_dir}/nginx"
docker run -d \
  -p "$app_port:$app_port" \
  --name "$slugname-nginx" \
  --network chillboxnet \
  --mount "type=bind,src=${project_dir}/nginx/templates,dst=/build/templates" \
  -e SITE1_SERVER_NAME="localhost" \
  -e SITE1_SERVER_PORT="$app_port" \
  -e SITE1_PROXY_INTERCEPT_ERRORS="off" \
  -e SITE1_IMMUTABLE__DESIGN_TOKENS="http://$slugname-design-tokens:8080/" \
  -e SITE1_IMMUTABLE__CLIENT_SIDE_PUBLIC="http://$slugname-client-side-public:8082/" \
  -e SITE1_IMMUTABLE__SOURCE_MEDIA="http://$slugname-source-media:8080/" \
  -e SITE1_API="http://$slugname-api:8100" \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e IMMUTABLE_BUCKET_NAME="chillboximmutable" \
  -e SITE1_CHILL_STATIC_EXAMPLE="http://$slugname-chill:5000" \
  -e SITE1_CHILL_DYNAMIC_EXAMPLE="http://$slugname-chill:5001" \
  "$slugname-nginx"

sleep 2
for container_name in \
  $slugname-design-tokens \
  $slugname-client-side-public \
  $slugname-source-media \
  $slugname-api \
  $slugname-chill \
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
  $slugname-design-tokens \
  $slugname-client-side-public \
  $slugname-source-media \
  $slugname-api \
  $slugname-chill \
  $slugname-nginx \
  ; do
  echo "$container_name $(docker container inspect $container_name | jq '.[0].State.Status + .[0].State.Error')"
done

echo "The $slugname site is running on http://localhost:$app_port/ "



#docker logs --follow $slugname-nginx

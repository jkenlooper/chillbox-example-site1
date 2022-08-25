# syntax=docker/dockerfile:1.4.1

# UPKEEP due: "2023-01-23" label: "NGINX base image" interval: "+5 months"
# docker pull nginx:1.22.0-alpine
# docker image ls --digests alpine
FROM nginx:1.22.0-alpine@sha256:98a1e37840fdf90f57df595dae8e27a198278170323744e13464b7f3a927562e

ENV SITE1_SERVER_NAME=localhost
ENV SITE1_SERVER_PORT=80
ENV SITE1_VERSION=0
ENV SITE1_API=http://localhost:9000
ENV SITE1_CHILL_STATIC_EXAMPLE=http://localhost:5000/
ENV SITE1_CHILL_DYNAMIC_EXAMPLE=http://localhost:5001/
ENV SITE1_IMMUTABLE_EXAMPLE=http://localhost:8080/

WORKDIR /build

RUN <<DEFAULT_NGINX_CONF
# Use a minimal NGINX configuration for just this local container.
set -o errexit
cat <<'HERE' > /etc/nginx/conf.d/default.conf
server {
    listen 80 default_server;
    server_name "";
    return 444;
}
HERE
chown nginx:nginx /etc/nginx/conf.d/default.conf

cat <<'HERE' > /etc/nginx/nginx.conf
user  nginx;
error_log  stderr info;
pid        /var/run/nginx.pid;
events {
    worker_connections  512;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    # root should always be set if access_log is.
    root /usr/share/nginx/html;
    access_log  /var/log/nginx/access.log  combined;
    sendfile        on;
    tcp_nopush on;
    tcp_nodelay on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    gzip  on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    include /etc/nginx/conf.d/*.conf;
}
HERE
chown nginx:nginx /etc/nginx/nginx.conf

DEFAULT_NGINX_CONF

COPY --chown=nginx:nginx root /srv/site1/root
RUN <<INSTALL
# Install directories for site1
set -o errexit
mkdir -p /srv/site1/
mkdir -p /var/log/nginx/site1
chown -R nginx:nginx /etc/nginx/conf.d
mkdir -p /srv/site1/.well-known
chown -R nginx:nginx /srv/site1/.well-known

INSTALL

COPY templates /build/templates

RUN <<FILEWATCH_SUPPORT
# Create scripts to help with local development
set -o errexit
apk update
apk add --no-cache \
  gettext \
  entr

mkdir -p .tmp
cat <<'MEOW' > dev.sh
#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HEREUSAGE

Watch for changes in the templates/ directory and reload nginx.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

HEREUSAGE
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

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

for d in templates; do
  find "$project_dir/$d" >> "$tmp_watch_files"
done

# Show the access log along with the nginx output
touch /var/log/nginx/site1/access.log
tail -f /var/log/nginx/site1/access.log &

cat "$tmp_watch_files" | entr -rzdn "$project_dir/reload-templates.sh"
MEOW

cat <<'HISS' > reload-templates.sh
#!/usr/bin/env sh
set -o errexit
script_name="$(basename "$0")"
if [ -f /etc/nginx/conf.d/site1.nginx.conf ]; then
  cp /etc/nginx/conf.d/site1.nginx.conf /etc/nginx/conf.d/site1.nginx.conf.bak
fi
envsubst '$SITE1_SERVER_NAME $SITE1_SERVER_PORT $SITE1_PROXY_INTERCEPT_ERRORS $SITE1_VERSION $SITE1_PROXY_CACHE_VALID $SITE1_API $SITE1_CHILL_STATIC_EXAMPLE $SITE1_CHILL_DYNAMIC_EXAMPLE $SITE1_IMMUTABLE_EXAMPLE' < /build/templates/site1.nginx.conf.template > /etc/nginx/conf.d/site1.nginx.conf
chown -R nginx:nginx /etc/nginx/conf.d/site1.nginx.conf
if nginx -t; then
    echo "INFO $script_name Passed test of nginx configuration."
else
  echo "ERROR $script_name Failed test of nginx configuration."
  if [ -f /etc/nginx/conf.d/site1.nginx.conf.bak ]; then
    echo "INFO $script_name Switching back to previous site1.nginx.conf."
    cp /etc/nginx/conf.d/site1.nginx.conf /etc/nginx/conf.d/site1.nginx.conf.failed
    mv /etc/nginx/conf.d/site1.nginx.conf.bak /etc/nginx/conf.d/site1.nginx.conf
    echo "INFO $script_name Please review failed configuration file /etc/nginx/conf.d/site1.nginx.conf.failed that was generated from /build/templates/site1.nginx.conf.template"
  fi
fi
nginx -t
nginx -g 'daemon off;'
HISS

chmod +x dev.sh
chmod +x reload-templates.sh
FILEWATCH_SUPPORT

# Only the /etc/nginx/conf.d/default.conf and /etc/nginx/nginx.conf have been
# created at this point. These should be valid since they are included in this
# same Dockerfile.
RUN nginx -t

EXPOSE 8083

CMD ["./dev.sh"]

# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad as build

## Build dependencies
WORKDIR /usr/local/src/app-venv
COPY requirements.txt ./
RUN <<BUILD_DEPENDENCIES
set -o errexit
apk update
apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev
ln -s /usr/bin/python3 /usr/bin/python
python -m venv .
/usr/local/src/app-venv/bin/pip install --upgrade pip wheel
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt
apk --purge del \
  gcc \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev
BUILD_DEPENDENCIES

WORKDIR /usr/local/src/app
COPY . ./
RUN <<PIP_INSTALL_APP
set -o errexit
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check --compile .
export PATH=/usr/local/src/app-venv/bin/:$PATH
PIP_INSTALL_APP

## Stage 2

# UPKEEP due: "2022-10-08" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.0
# docker image ls --digests alpine
FROM alpine:3.16.0@sha256:686d8c9dfa6f3ccfc8230bc3178d23f84eeaf7e457f36f271ab1acc53015037c

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/
COPY --from=build --chown=dev /usr/local/src/app-venv /usr/local/src/app-venv
COPY --from=build --chown=dev /usr/local/src/app /usr/local/src/app

ENV PATH=/usr/local/src/app-venv/bin/:$PATH

ARG FLASK_INSTANCE_PATH=/var/lib/site1/
ENV FLASK_INSTANCE_PATH=$FLASK_INSTANCE_PATH

RUN <<APP_DEPENDENCIES
set -o errexit
apk update
apk add --no-cache \
  python3 \
  sqlite
ln -s /usr/bin/python3 /usr/bin/python

mkdir -p $FLASK_INSTANCE_PATH
chown -R dev:dev $FLASK_INSTANCE_PATH

mkdir -p /usr/local/src/app
chown -R dev:dev /usr/local/src/app

APP_DEPENDENCIES

ENV FLASK_APP=site1_api.app
ENV FLASK_ENV=production
ENV SECRETS_CONFIG="/var/lib/chillbox-shared-secrets/site1/api.cfg"

ENV API_HOST="0.0.0.0"
ENV API_PORT="8100"

ENV HOST="0.0.0.0"
ENV PORT=$API_PORT
ENV SERVER_NAME="$API_HOST:$API_PORT"

WORKDIR /usr/local/src/app/

RUN <<FILEWATCH_SUPPORT

cat <<'FLASK_RUN_SH' > flask-run.sh
#!/usr/bin/env sh

set -o errexit

current_user="$(id -un)"
echo "current user = $current_user or $USER"
if [ "${current_user}" != "root" ]; then
  echo "ERROR: Must run $0 as the 'root' user because this uses bind mount of the src/site1_api/ directory."
  exit 1
fi

# pip install in editable mode
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check -e .

export FLASK_ENV=development

/usr/local/src/app-venv/bin/flask init-db
/usr/local/src/app-venv/bin/flask run \
  --port ${PORT} \
  --host ${HOST}

# /usr/local/src/app-venv/bin/pytest

# /usr/local/src/app-venv/bin/coverage run -m pytest

# /usr/local/src/app-venv/bin/coverage report

FLASK_RUN_SH

chmod +x flask-run.sh
FILEWATCH_SUPPORT

USER dev

CMD ["/usr/local/src/app-venv/bin/start"]

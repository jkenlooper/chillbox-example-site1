# syntax=docker/dockerfile:1.4.3

# This file in the parent directory api was generated from the flask-service directory in https://github.com/jkenlooper/cookiecutters . Any modifications needed to this file should be done on that originating file.

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/app/

RUN <<SERVICE_DEPENDENCIES
set -o errexit
apk update
# Support python services and python Pillow
# Should match the list from chillbox install-service-dependencies.sh
apk add --no-cache \
  -q --no-progress \
  build-base \
  freetype \
  freetype-dev \
  fribidi \
  fribidi-dev \
  gcc \
  harfbuzz \
  harfbuzz-dev \
  jpeg \
  jpeg-dev \
  lcms2 \
  lcms2-dev \
  libffi-dev \
  libjpeg \
  musl-dev \
  openjpeg \
  openjpeg-dev \
  py3-pip \
  python3 \
  python3-dev \
  sqlite \
  tcl \
  tcl-dev \
  tiff \
  tiff-dev \
  tk \
  tk-dev \
  zlib \
  zlib-dev

# Support for python flask with gunicorn and gevent
apk add --no-cache \
  -q --no-progress \
  py3-gunicorn

ln -s /usr/bin/python3 /usr/bin/python
SERVICE_DEPENDENCIES

ENV PATH=/usr/local/src/app-venv/bin/:$PATH
ARG FLASK_INSTANCE_PATH=/var/lib/site1/
ENV FLASK_INSTANCE_PATH=$FLASK_INSTANCE_PATH
RUN <<FLASK_SETUP
set -o errexit
mkdir -p /usr/local/src/app
mkdir -p $FLASK_INSTANCE_PATH
chown -R dev:dev $FLASK_INSTANCE_PATH

mkdir -p /usr/local/src/app
chown -R dev:dev /usr/local/src/app
FLASK_SETUP

ARG LOCAL_PYTHON_PACKAGES=/var/lib/chillbox/python
ENV LOCAL_PYTHON_PACKAGES=$LOCAL_PYTHON_PACKAGES
COPY requirements.txt /usr/local/src/app/requirements.txt
RUN <<PIP_INSTALL_REQ
set -o errexit
mkdir -p "$LOCAL_PYTHON_PACKAGES"
/usr/bin/pip3 download \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    pip wheel
#/usr/bin/pip3 install --disable-pip-version-check --compile -r /usr/local/src/app/requirements.txt
/usr/bin/pip3 download --disable-pip-version-check \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    -r /usr/local/src/app/requirements.txt || echo 'ignore'
PIP_INSTALL_REQ

COPY pyproject.toml /usr/local/src/app/pyproject.toml
COPY setup.cfg /usr/local/src/app/setup.cfg
COPY setup.py /usr/local/src/app/setup.py
COPY README.md /usr/local/src/app/README.md
COPY src /usr/local/src/app/src
RUN <<PIP_INSTALL_APP
set -o errexit

# Only pip install with the local python packages cache.
/usr/bin/python3 -m venv /usr/local/src/app-venv
/usr/local/src/app-venv/bin/pip3 install --disable-pip-version-check --compile \
    --no-index --find-links="$LOCAL_PYTHON_PACKAGES" \
    -e /usr/local/src/app || echo 'ignore'

PIP_INSTALL_APP

ENV FLASK_APP=site1_api.app
ENV FLASK_ENV=production

# TODO set secrets for local
ENV SECRETS_CONFIG="/var/lib/chillbox-shared-secrets/site1/api.cfg"

ENV API_PORT=8100

ENV SERVER_NAME="localhost"


RUN <<FILEWATCH_SUPPORT
cat <<'SLEEP_SH' > sleep.sh
#!/usr/bin/env sh

set -o errexit
echo "Sleeping."
while true; do
  printf "."
  sleep 60
done
SLEEP_SH
chmod +x sleep.sh

cat <<'FLASK_RUN_SH' > flask-run.sh
#!/usr/bin/env sh

set -o errexit

current_user="$(id -un)"
echo "current user = $current_user or $USER"
if [ "${current_user}" != "root" ]; then
  echo "ERROR: Must run $0 as the 'root' user because this uses bind mount of the src/site1_api/ directory."
  exit 1
fi

# # pip install in editable mode
# /usr/bin/python3 -m venv /usr/local/src/app-venv
# /usr/local/src/app-venv/bin/pip install --disable-pip-version-check \
#     --no-index --find-links="$LOCAL_PYTHON_PACKAGES" \
#     -e .

export FLASK_ENV=development

/usr/local/src/app-venv/bin/flask init-db

# Setting host to 0.0.0.0 (externally visible) to work with docker network.
/usr/local/src/app-venv/bin/flask run \
  --port "$API_PORT" \
  --host "0.0.0.0"

# /usr/local/src/app-venv/bin/pytest

# /usr/local/src/app-venv/bin/coverage run -m pytest

# /usr/local/src/app-venv/bin/coverage report

FLASK_RUN_SH

chmod +x flask-run.sh
FILEWATCH_SUPPORT

USER dev

CMD ["/usr/local/src/app-venv/bin/start"]

# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

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

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /home/dev/app
/usr/bin/python3 -m venv /home/dev/app/.venv
# The dev user will need write access since pip install will be adding files to
# the .venv directory.
chown -R dev:dev /home/dev/app/.venv
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


RUN <<SETUP
set -o errexit
cat <<'HERE' > /home/dev/sleep.sh
#!/usr/bin/env sh
while true; do
  printf 'z'
  sleep 60
done
HERE
chmod +x /home/dev/sleep.sh

mkdir -p /home/dev/requirements
chown -R dev:dev /home/dev/requirements
SETUP

ARG LOCAL_PYTHON_PACKAGES=/var/lib/chillbox/python
ENV LOCAL_PYTHON_PACKAGES=$LOCAL_PYTHON_PACKAGES

COPY --chown=dev:dev setup.py /home/dev/app/setup.py
COPY --chown=dev:dev README.md /home/dev/app/README.md
# Only the __init__.py is needed when using pip download.
COPY --chown=dev:dev src/site1_api/__init__.py /home/dev/app/src/site1_api/__init__.py

RUN <<PIP_INSTALL_REQ
set -o errexit
mkdir -p "$LOCAL_PYTHON_PACKAGES"
pip download \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    pip wheel
pip download --disable-pip-version-check \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    /home/dev/app
PIP_INSTALL_REQ

USER dev

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirments.txt file that the main container will use.
python -m pip install --upgrade pip-tools
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="$LOCAL_PYTHON_PACKAGES" \
    --output-file /home/dev/requirements/requirements.txt \
    /home/dev/app/setup.py
UPDATE_REQUIREMENTS

CMD ["/home/dev/sleep.sh"]

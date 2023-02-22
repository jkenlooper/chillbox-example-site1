# syntax=docker/dockerfile:1.4.3

# This file in the parent directory worker was generated from the python-worker directory in https://github.com/jkenlooper/cookiecutters . Any modifications needed to this file should be done on that originating file.

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

# UPKEEP due: "2023-03-23" label: "Chillbox cli shared scripts" interval: "+3 months"
# https://github.com/jkenlooper/chillbox
ARG CHILLBOX_CLI_VERSION="0.0.1-beta.30"
RUN <<CHILLBOX_PACKAGES
# Download and extract shared scripts from chillbox.
set -o errexit
# The /etc/chillbox/bin/ directory is a hint that the
# install-chillbox-packages.sh script is the same one that chillbox uses.
mkdir -p /etc/chillbox/bin
tmp_tar_gz="$(mktemp)"
wget -q -O "$tmp_tar_gz" \
  "https://github.com/jkenlooper/chillbox/releases/download/$CHILLBOX_CLI_VERSION/chillbox-cli.tar.gz"
tar x -f "$tmp_tar_gz" -z -C /etc/chillbox/bin --strip-components 4 ./src/chillbox/bin/install-chillbox-packages.sh
# TODO
# tar x -f "$tmp_tar_gz" -z -C /etc/chillbox --strip-components 3 ./src/chillbox/pip-requirements.txt
chown root:root /etc/chillbox/bin/install-chillbox-packages.sh
rm -f "$tmp_tar_gz"
CHILLBOX_PACKAGES

RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
/etc/chillbox/bin/install-chillbox-packages.sh

SERVICE_DEPENDENCIES

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /home/dev/app
chown -R dev:dev /home/dev/app
su dev -c '/usr/bin/python3 -m venv /home/dev/app/.venv'
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# TODO
COPY --chown=dev:dev pip-requirements.txt /etc/chillbox/pip-requirements.txt

RUN <<PIP_INSTALL
# Install pip and wheel
set -o errexit
su dev -c "python -m pip install -r /etc/chillbox/pip-requirements.txt"
PIP_INSTALL

# UPKEEP due: "2023-03-23" label: "pip-tools" interval: "+3 months"
# https://pypi.org/project/pip-tools/
ARG PIP_TOOLS_VERSION=6.12.1
RUN <<PIP_TOOLS_INSTALL
# Install pip-tools
set -o errexit
su dev -c "python -m pip install 'pip-tools==$PIP_TOOLS_VERSION'"
PIP_TOOLS_INSTALL

# UPKEEP due: "2023-03-23" label: "Python auditing tool pip-audit" interval: "+3 months"
# https://pypi.org/project/pip-audit/
ARG PIP_AUDIT_VERSION=2.4.10
RUN <<INSTALL_PIP_AUDIT
# Install pip-audit
set -o errexit
su dev -c "python -m pip install 'pip-audit==$PIP_AUDIT_VERSION'"
INSTALL_PIP_AUDIT

# UPKEEP due: "2023-06-23" label: "Python security linter tool: bandit" interval: "+6 months"
# https://pypi.org/project/bandit/
ARG BANDIT_VERSION=1.7.4
RUN <<BANDIT_INSTALL
# Install bandit to find common security issues
set -o errexit
su dev -c "python -m pip install 'bandit==$BANDIT_VERSION'"
BANDIT_INSTALL

USER dev

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
SETUP

COPY --chown=dev:dev pyproject.toml /home/dev/app/pyproject.toml
COPY --chown=dev:dev README.md /home/dev/app/README.md
COPY --chown=dev:dev dep /home/dev/app/dep
# Only the __init__.py is needed when using pip download.
#COPY --chown=dev:dev src/site1_worker/__init__.py /home/dev/app/src/site1_worker/__init__.py

RUN <<PIP_INSTALL_REQ
# Download python packages described in pyproject.toml
set -o errexit
mkdir -p "/home/dev/app/dep"
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --destination-directory "./dep" \
    .
PIP_INSTALL_REQ

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirements.txt file that the main container will use.
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="./dep" \
    --output-file ./requirements.txt \
    pyproject.toml
UPDATE_REQUIREMENTS

COPY --chown=dev:dev verify-run-audit.sh ./
RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
./verify-run-audit.sh
AUDIT

COPY --chown=dev:dev src/site1_worker/ /home/dev/app/src/site1_worker/
RUN <<BANDIT
# Use bandit to find common security issues
set -o errexit
bandit \
    --recursive \
    /home/dev/app/src/ > /home/dev/security-issues-from-bandit.txt || echo "WARNING: Issues found."
BANDIT

CMD ["/home/dev/sleep.sh"]

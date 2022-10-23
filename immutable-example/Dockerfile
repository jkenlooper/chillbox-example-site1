# syntax=docker/dockerfile:1.4.1

# UPKEEP due: "2022-10-08" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.0
# docker image ls --digests alpine
FROM alpine:3.16.0@sha256:686d8c9dfa6f3ccfc8230bc3178d23f84eeaf7e457f36f271ab1acc53015037c as build

WORKDIR /build

RUN <<DEV_USER
# Create an unprivileged user that will only have access to /build directory.
addgroup -g 2000 dev
adduser -u 2000 -G dev -s /bin/sh -D dev
chown -R dev:dev /build
DEV_USER

RUN <<FILEWATCH_SUPPORT
# Support for doing local development
set -o errexit
apk update
apk add --no-cache \
  thttpd \
  tree \
  gettext \
  entr
FILEWATCH_SUPPORT

COPY --chown=dev:dev local-scripts/dev.sh /build/dev.sh
COPY --chown=dev:dev local-scripts/build-serve.sh /build/build-serve.sh
COPY --chown=dev:dev local-scripts/build.sh /build/build.sh

# Only the src/ directory is copied to the container.
COPY --chown=dev:dev src /build/src

ENV BUILD_SRC_DIR=/build/src
ENV BUILD_DIST_DIR=/build/dist

USER dev

# Build the dist files inside the container
RUN ./build.sh

# Need to bind to all addresses (0.0.0.0) as the default when within the site's
# network.
ENV BIND=0.0.0.0
ENV PORT=8080
EXPOSE 8080


# Default command is to run the dev.sh script to watch files and build and serve
# them.
CMD ["./dev.sh"]

### Serve
FROM lipanski/docker-static-website:1.0.0@sha256:ea8516e6b2928c3c1b1c6737f7e32e03b10a04f978080592e61c3dbe2871ff1a


COPY --from=build /build/dist /home/static

# Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
CMD ["/thttpd", "-D", "-h", "$BIND", "-p", "$PORT", "-d", "/home/static", "-u", "static", "-l", "-", "-M", "0"]

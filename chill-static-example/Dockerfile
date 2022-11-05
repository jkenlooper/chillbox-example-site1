# syntax=docker/dockerfile:1.4.3

FROM chill:latest

USER root
RUN <<FILEWATCH_SUPPORT
apk update
apk add --no-cache \
  entr

cat <<'MEOW' > dev.sh
#!/usr/bin/env sh

rm -rf $CHILL_DATABASE_URI
chill initdb
chill load --yaml chill-data.yaml

rm -f /tmp/watch_files
for d in templates queries documents; do
  find ./$d >> /tmp/watch_files
done
cat /tmp/watch_files | entr -rzdn chill run
MEOW
chmod +x dev.sh
chown chill:chill dev.sh
FILEWATCH_SUPPORT

COPY --chown=chill:chill . .

ENV IMMUTABLE_EXAMPLE_URI="/notset/"
ENV CHILL_PORT="5000"
ENV CHILL_MEDIA_PATH="/media/"
ENV CHILL_THEME_STATIC_PATH="/theme/0/"

VOLUME /var/lib/chill/sqlite3
VOLUME /home/chill/app

USER chill

ENTRYPOINT ["/bin/sh"]
CMD ["./dev.sh"]

#!/usr/bin/env sh

set -o errexit

slugname=site1

projectdir="$(dirname "$(dirname "$(realpath "$0")")")"

# archive file path should be absolute
archive="$(realpath "$1")"
echo "$archive" | grep -q "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/$slugname"

mkdir -p "$tmpdir/$slugname/immutable-example"
make -C "$projectdir/immutable-example"
find "$projectdir/immutable-example/dist/" -depth -mindepth 1 -maxdepth 1 -exec cp -R {} "$tmpdir/$slugname/immutable-example/" \;

archive_dir="$(dirname "$archive")"
mkdir -p "$archive_dir"
tar c \
  -C "$tmpdir" \
  -h \
  -z \
  -f "${archive}" \
  "$slugname"

# Clean up
rm -rf "${tmpdir}"

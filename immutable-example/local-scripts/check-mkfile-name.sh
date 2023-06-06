#!/usr/bin/env sh

set -o errexit

# This file in the parent directory immutable-example was generated from the immutable-make directory in https://github.com/jkenlooper/cookiecutters . Any modifications needed to this file should be done on that originating file.
# Version: 0.0.1-alpha.2

check_mkfile_name() {
  if [ -z "$MKFILE_NAME" ] || [ "$MKFILE_NAME" != "Makefile" ]; then
    echo "MKFILE_NAME is currently set to '$MKFILE_NAME'"
    echo "Failed check if environment variable MKFILE_NAME equals 'Makefile'."
    echo "WARNING $script_name: Not being started from the Makefile. It is recommended to start this script with the following command:"
    echo ""
    echo "$1"
    echo ""
    echo "Continue running $script_name script? [y/n]"
    read -r confirm
    test "$confirm" = "y" || exit 1
  fi
}

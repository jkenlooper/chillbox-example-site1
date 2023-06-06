#!/usr/bin/env sh

set -o errexit

# This file in the parent directory immutable-example was generated from the immutable-make directory in https://github.com/jkenlooper/cookiecutters . Any modifications needed to this file should be done on that originating file.
# Version: 0.0.1-alpha.2

check_in_container() {
  if [ -z "$LOCAL_CONTAINER" ] || [ "$LOCAL_CONTAINER" != "yes" ]; then
    echo "LOCAL_CONTAINER is currently set to '$LOCAL_CONTAINER'"
    echo "Failed check if environment variable LOCAL_CONTAINER equals 'yes'."
    echo "WARNING $script_name: Not being started from within a local container. It is recommended to use the following command:"
    echo ""
    echo "$1"
    echo ""
    echo "Continue running $script_name script? [y/n]"
    read -r confirm
    test "$confirm" = "y" || exit 1
  fi
}

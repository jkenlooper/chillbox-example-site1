#!/usr/bin/env bash

set -o errexit
set -o nounset

stop_and_rm_containers_silently () {
  slugname="$1"
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  docker stop --time 1 $slugname-chill-dynamic-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-api > /dev/null 2>&1 &
  docker stop --time 1 $slugname-chill-static-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-immutable-example > /dev/null 2>&1 &
  docker stop --time 1 $slugname-nginx > /dev/null 2>&1 &
  wait

  docker container rm $slugname-chill-dynamic-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-api > /dev/null 2>&1 || printf ''
  docker container rm $slugname-chill-static-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-immutable-example > /dev/null 2>&1 || printf ''
  docker container rm $slugname-nginx > /dev/null 2>&1 || printf ''
}

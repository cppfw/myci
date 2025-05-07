#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

echo "remove stopped containers"
docker container prune --force
echo ""

echo "remove unused volumes"
docker volume prune --all --force
echo ""

echo "remove dangling images"
docker image prune --force

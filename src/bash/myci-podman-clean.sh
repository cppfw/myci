#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

echo "remove stopped containers"
podman container prune --force
echo ""

echo "remove unused volumes"
podman volume prune --force
echo ""

echo "remove dangling images"
podman image prune --force

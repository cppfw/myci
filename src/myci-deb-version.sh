#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

changelog_file=$1

if [ -z "$changelog_file" ]; then
    changelog_file="debian/changelog"
fi

if [ ! -f "$changelog_file" ]; then
    error "no '$changelog_file' found"
fi

head -1 $changelog_file | sed -n -e 's/.*(\([\.0-9]*\)\(-[0-9]*\)\{0,1\}).*/\1/p'

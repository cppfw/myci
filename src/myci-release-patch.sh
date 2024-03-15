#!/bin/bash

# script for quick release of new revision, i.e. version maj.min.rev+1.

# Revision from debian changelog will be incremented
# and a comment passed as argument is added.

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

[ ! -z "$1" ] || source myci-error.sh "comment as argument expected"

source ${script_dir}myci-release-check.sh --no-unreleased-check

echo "check that debian/changelog is not UNRELEASED"
distro=$(${script_dir}myci-deb-get-dist.sh)
[ "$distro" != "UNRELEASED" ] || source ${script_dir}myci-error.sh "the debian/changelog is in UNRELEASED state, cannot make patch release. Do general release instead."

source ${script_dir}myci-deb-bump-version.sh --revision "$1"

source ${script_dir}myci-release.sh --no-release-checks

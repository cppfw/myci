#!/bin/bash

# script for quick release of new revision, i.e. version maj.min.rev+1.

# Revision from debian changelog will be incremented
# and a comment passed as argument is added.

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

[ ! -z "$1" ] || source myci-error.sh "comment as argument expected"

source $(dirname $0)/do-release-checks.sh --no-unreleased-check

source $(dirname $0)/bump-version.sh --revision "$1"

source $(dirname $0)/release.sh --no-release-checks

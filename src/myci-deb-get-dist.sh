#!/bin/bash

# this script extracts distribution name from latest release from debian/changelog

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

head -1 debian/changelog | sed -E -n -e 's/[^\(]*\([0-9\.-]*\) (.*);.*/\1/p'

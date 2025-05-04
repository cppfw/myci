#!/bin/bash

# this script extracts distribution name from latest release from debian/changelog

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

if [ -d build/debian ]; then
	deb_root_dir=build
elif [ -d debian ]; then
	deb_root_dir=.
fi

head -1 $deb_root_dir/debian/changelog | sed -E -n -e 's/[^\(]*\([0-9\.-]*\) (.*);.*/\1/p'

#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# script installing debian package build dependencies listed in debian/control

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0)"
			echo " "
			echo "The script shuld be run from within the directory containing the debian/control."
			echo " "
			echo "Example:"
			echo "	$(basename $0)"
			exit 0
			;;
		*)
			echo "Error: no arguments expected"
            exit 1
			;;
	esac
	[[ $# > 0 ]] && shift;
done

echo "Checking for missing build dependencies."

builddeps=$(dpkg-checkbuilddeps 2>&1 || true)

unmetDepsMsg="dpkg-checkbuilddeps: error: Unmet build dependencies: "

[ ! -z "$builddeps" ] && [ -z "$(echo $builddeps | sed -n -e "s/^$unmetDepsMsg//p")" ] && myci-error.sh "Could not check for unmet build dependencies.\nError message: $builddeps";

# remove version restrictions from list of unmet dependencies
deps=$(echo $builddeps | sed -n -e "s/^$unmetDepsMsg//p" | sed -e 's/ ([^)]*)//g')

if [ -z "$deps" ]; then
    echo "All dependencies satisfied."
    exit 0;
else
    echo "Installing missing dependency packages: $deps"
fi

apt --quiet install --assume-yes $deps

# finally, check again that all dependencies were installed successfully.
dpkg-checkbuilddeps

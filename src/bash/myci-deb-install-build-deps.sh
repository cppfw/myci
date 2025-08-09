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
			echo "The script should be run from within the directory containing the build/debian/control or debian/control."
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

if [ -f "build/debian/control" ]; then
	pushd build > /dev/null
fi

checkbuilddeps_out=$(dpkg-checkbuilddeps 2>&1 || true)

# TODO: check for dpkg-checkbuilddeps return code
# 1 = there are unmet dependencies
# other codes = other errors

# echo "checkbuilddeps_out = $checkbuilddeps_out"

# On debian trixie the error output of dpkg-checkbuilddeps changed from capital to small letter, so use [Uu] in the regex.
unmet_deps_msg="dpkg-checkbuilddeps: error: [Uu]nmet build dependencies: "

builddeps=$(echo $checkbuilddeps_out | sed -n -e "s/^$unmet_deps_msg//p")

[ ! -z "$checkbuilddeps_out" ] && [ -z "$builddeps" ] && myci-error.sh "Could not check for unmet build dependencies.\nError message: $unmet_deps_msg";

# remove version restrictions from list of unmet dependencies
deps=$(echo $builddeps | sed -e 's/ ([^)]*)//g')

if [ -z "$deps" ]; then
    echo "All dependencies satisfied."
    exit 0;
else
    echo "Installing missing dependency packages: $deps"
fi

apt --quiet install --assume-yes $deps

# finally, check again that all dependencies were installed successfully.
dpkg-checkbuilddeps

if [ -f "build/debian/control" ]; then
	popd > /dev/null
fi

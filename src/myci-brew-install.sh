#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for installing or upgrading homebrew packages

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) [<package-name> ...]"
			echo " "
			echo "Install or upgrade homebrew packages."
			echo " "
			echo "Example:"
			echo "	$(basename $0) liba libb"
			exit 0
			;;
		*)
			inputs="$inputs $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$inputs" ] && echo "Error: no packages to install specified" && exit 1;

# echo inputs = $inputs

for i in $inputs; do
    echo $i
    # check if package is already installed
    set +e
    brew list $i > /dev/null 2>&1
    exit_code=$?
    set -e
    if [ $exit_code != 0 ]; then
        echo "no package '$i' installed, install it";
        brew install --overwrite $i;
    else
        echo "package '$i' is already installed, upgrade it";
        brew upgrade $i;
    fi;
done

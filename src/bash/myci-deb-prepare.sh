#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

# this script is used for preparing the debian package before building with dpkg-buildpackage.

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) [--soname <soname> --debian-dir <path-to-debianization-dir>]"
            echo " "
            echo "If '--soname' parameter is not given the script tries to read soname from src/soname.txt file."
			echo "If '--debian-dir' parameter is not given the script tries to locate debianization files first in 'debian' or then in 'build/debian' directory."
            echo " "
            echo "Example:"
            echo "	$(basename $0) --soname 4 --debian-dir debian"
            exit 0
			;;
		--soname)
			shift
			soname=$1
			;;
		--debian-dir)
			shift
			debianization_dir=$1
			;;
    esac

	[[ $# > 0 ]] && shift;
done

echo "preparing debian package for building"

if [ -z "$debianization_dir" ]; then
	if [ -d build/debian ]; then
		echo "debianization directory found at 'build/debian'"
		debianization_dir=build/debian
	fi

	if [ -d debian ]; then
		echo "debianization directory found at 'debian'"
		debianization_dir=debian
	fi
fi

if [ -z "$debianization_dir" ]; then
	$script_dir/myci-error.sh "debianization directory not specified and not found"
fi

if [ -z "$soname" ]; then
	soname=$(cat src/soname.txt 2>/dev/null || true) # ignore error if there is no soname.txt file
fi

if [ -z "$soname" ]; then
	$script_dir/myci-warning.sh "no soname found, using empty soname"
	soname=
else
	echo "detected soname = $soname"
fi

list_of_installs=$(ls $debianization_dir/*.install.in 2>/dev/null || true) # allow package without *.install.in

for i in $list_of_installs; do
	echo "applying soname to $i"

	# BACKWARDS COMPATIBILITY: in case file name does not contain $ sign, then do not
	#                          substitute $(soname) variable in file name, but just append soname value to it.
	#                          Otherwise do $(soname) substitution in file name.
	if [ "$(echo "$i" | sed -n -e "s/.*\$.*/true/p")" == "true" ]; then
		${script_dir}myci-subst-var.sh --var soname --val $soname $i
	else
		${script_dir}myci-warning.sh "DEPRECATED: package.install.in file without \$(soname)"
		sed -e "s/\$(soname)/$soname/g" $i > ${i%.install.in}$soname.install
	fi
done

echo "applying soname to $debianization_dir/control.in"

sed -e "s/\$(soname)/$soname/g" $debianization_dir/control.in > $debianization_dir/control

echo "debian package prepared for building"

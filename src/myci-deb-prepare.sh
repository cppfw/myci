#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# this script is used for preparing the debian package before building with dpkg-buildpackage.

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) [-s/--soname <soname> -d/--debian-dir <path-to-debianization-dir>]"
            echo " "
            echo "If '-s' parameter is not given the script tries to read soname from src/soname.txt file."
			echo "If '-d' parameter is not given the script tries to locate debianization files in 'debian' directory."
            echo " "
            echo "Example:"
            echo "	$(basename $0) -s 4 -d debian"
            exit 0
			;;
        -s)
			shift
			soname=$1
			;;
		--soname)
			shift
			soname=$1
			;;
		-d)
			shift
			debianization=$1
			;;
		--debian-dir)
			shift
			debianization=$1
			;;
    esac

	[[ $# > 0 ]] && shift;
done

echo "Preparing Debian package for building"

if [ -z "$debianization" ]; then
	debianization=debian
fi

if [ -z "$soname" ]; then
	soname=$(cat src/soname.txt 2>/dev/null || true) # ignore error if there is no soname.txt file
fi

if [ -z "$soname" ]; then
	echo "no soname found, using empty soname"
	soname=
else
	echo "detected soname = $soname"
fi

listOfInstalls=$(ls $debianization/*.install.in 2>/dev/null || true) # allow package without *.install.in

for i in $listOfInstalls; do
	echo "applying soname to $i"
	cp $i ${i%.install.in}$soname.install
done

echo "applying soname to $debianization/control.in"

sed -e "s/\$(soname)/$soname/g" $debianization/control.in > $debianization/control

echo "Debian package prepared for building!"

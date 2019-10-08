#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail


while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for packing the library to ZIP package."
			echo "Usage:"
			echo "	$(basename $0) -h <headers-dir> [-a <static-lib>] <output-package-filename>"
			echo " "
			echo "The script packs supplied headers (.hpp and .h) preserving directory structure."
			echo "Static library file is added to the root of the archive."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -h ./src -a xcode/build/libsomething.a libsomething.zip"
			exit 0
			;;
		-h)
			shift
			hdrdir=$1
			shift
			;;
		-a)
			shift
			staticlib=$1
			shift
			;;
		*)
			outpkg="$1"
			shift
			;;
	esac
done

[ -z "$outpkg" ] && source myci-error.sh "output package filename is not given";

[ -z "$hdrdir" ] && source myci-error.sh "headers directory is not given";

# make sure header dir ends with '/' (remove '/' suffix if it is there and then add '/' again)
hdrdir="${hdrdir%/}/"

echo "Creating ZIP package"

# delete old archive if one exists
rm -f $outpkg

headers=$(find $hdrdir -type f -name "*.hpp" -o -name "*.h")

tmp_dir=$(mktemp -d -t myci-XXXXXXXXXXXXXXXXX)

# copy headers to temporary directory

for header in $headers; do
	f=${header#"$hdrdir"}
	dstf="$tmp_dir/include/$f"
	dstdir=$(dirname $dstf)
	mkdir -p $dstdir
	cp $header $dstdir
done

# copy static lib

if [ ! -z "$staticlib" ]; then
	dstdir=$tmp_dir/lib
	mkdir -p $dstdir
	cp $staticlib $dstdir
fi

# create zip package

thisdir=$(pwd)

(cd $tmp_dir && zip -r $thisdir/$outpkg *)

rm -rf $tmp_dir

echo "Done creating ZIP package"

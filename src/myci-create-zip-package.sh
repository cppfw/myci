#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail


while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for packing the library to ZIP package."
			echo "Usage:"
			echo "	$(basename $0) -h <headers-dir>[///<headers-dest-subdir>] [-f <source-filename>[///<destination-directory-within-archive>] ...] <output-package-filename>"
			echo " "
			echo "The script packs supplied headers (.hpp and .h) preserving directory structure into the 'include' directory withing archive."
			echo "There can be any number of -f keys. The '///<destination-directory-within-archive>' part of the -f key value can be omitted,"
			echo "the file is then added to the root directory within the archive."
			echo "The '///<headers-dest-subdir>' part of the -h key can be omitted, then header files are copied to 'include' directory of the archive."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -h ./src -f xcode/build/libsomething.a///lib/ios/ -f licenses/MyLICENSE.txt libsomething.zip"
			exit 0
			;;
		-h)
			shift
			hdrdir=$1
			;;
		-f)
			shift
			files="$files $1"
			;;
		*)
			outpkg="$1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$outpkg" ] && source myci-error.sh "output package filename is not given";

[ -z "$hdrdir" ] && source myci-error.sh "headers directory is not given";

# split header files source and destination directories
hdrdir_srcdst=(${hdrdir//\/\/\// })

# make sure header dirs end with '/' (remove '/' suffix if it is there and then add '/' again)
hdrdir="${hdrdir_srcdst[0]%/}/"

hdrdir_dst=${hdrdir_srcdst[1]}
if [ ! -z "$hdrdir_dst" ]; then
	hdrdir_dst="${hdrdir_dst%/}/"
fi

echo "hdrdir=$hdrdir"
echo "hdrdir_dst=$hdrdir_dst"

echo "Creating ZIP package"

# delete old archive if one exists
rm -f $outpkg

headers=$(find $hdrdir -type f -name "*.hpp" -o -name "*.h")

tmp_dir=$(mktemp -d -t myci-XXXXXXXXXXXXXXXXX)

# copy headers to temporary directory

for header in $headers; do
	f=${header#"$hdrdir"}
	dstf="$tmp_dir/include/$hdrdir_dst$f"
	dstdir=$(dirname $dstf)
	mkdir -p $dstdir
	cp $header $dstdir
done

# copy files

for f in $files; do
	srcdst=(${f//\/\/\// })
	srcdst[1]=$tmp_dir/${srcdst[1]}
	mkdir -p ${srcdst[1]}
	cp -r ${srcdst[0]} ${srcdst[1]}
done

# create zip package

thisdir=$(pwd)

(cd $tmp_dir && zip -r $thisdir/$outpkg *)

rm -rf $tmp_dir

echo "Done creating ZIP package"

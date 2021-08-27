#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "myci apply version utility. Replaces all occurrences of '\$(version)' in a file with given version string."
			echo ""
			echo "usage:"
			echo "	$(basename $0) <options> <list-of-input-files>"
			echo ""
			echo "input files must have '.in' suffix"
			echo ""
			echo "options:"
			echo "  -v, --version <version>  version string to apply"
			echo "      --filename-only      apply version only to file name"
			echo "      --out-dir <dir>      directory where to put resulting files, if not specified, the files are placed next to input files"
			exit 0
			;;
		-v)
			shift
			version=$1
			;;
		--version)
			shift
			version=$1
			;;
		--filename-only)
			filenameonly="true"
			;;
		--out-dir)
			shift
			out_dir=$1
			;;
		*)
			infiles="$infiles $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

if [ -z "$version" ]; then
	echo "version is not given, trying to extract it from debian/changelog"
	version="$(${script_dir}myci-deb-version.sh)"
fi

# make sure the out_dir ends with slash
if [ ! -z "$out_dir" ]; then
	if [[ "$out_dir" != */ ]]; then
		out_dir="${out_dir}/"
	fi
fi

echo "Applying version $version to files:"

for i in $infiles; do
	outfile=$(echo $i | sed -e "s/\(.*\)\.in$/\1/" | sed -e "s/\$(version)/$version/g")

	outfile="${out_dir}$(basename $outfile)"

	echo "	$i -> $outfile"

	if [ -z "$filenameonly" ]; then
		sed -e "s/\$(version)/$version/g" $i > $outfile
	else
		cp $i $outfile
	fi
done

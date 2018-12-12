#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "Prorab apply version utility."
			echo "Usage:"
			echo "	myci-apply-version.sh -v <version> <list-of-input-files> [--filename-only]"
			echo "Input files are files with '.in' extension"
			exit
			;;
		-v)
			shift
			version=$1
			shift
			;;
		--filename-only)
			filenameonly="true"
			shift
			;;
		*)
			infiles="$infiles $1"
			shift
			;;
	esac
done

echo "Applying version $version to files..."

for i in $infiles; do
	echo "	$i"

	outfile=$(echo $i | sed -b -e "s/\(.*\)\.in$/\1/" | sed -b -e "s/\$(version)/$version/g")

	if [ -z "$filenameonly" ]; then
		sed -b -e "s/\$(version)/$version/g" $i > $outfile
	else
		cp $i $outfile
	fi
done

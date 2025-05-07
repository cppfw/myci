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
			echo "  --version <version>  version string to apply"
			echo "  --filename-only      apply version only to file name"
			echo "  --out-dir <dir>      directory where to put resulting files, if not specified, the files are placed next to input files"
			exit 0
			;;
		-v)
			shift
			echo "DEPRECATED: -v command line option is deprecated, use --version"
			version=$1
			;;
		--version)
			shift
			version=$1
			;;
		--filename-only)
			args="$args --filename-only"
			;;
		--out-dir)
			shift
			args="$args --out-dir $1"
			;;
		*)
			infiles="$infiles $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

if [ -z "$version" ]; then
	echo "version is not given, trying to extract it from debian/changelog"
	version=$(${script_dir}myci-deb-version.sh)
fi

echo "applying version = $version"

${script_dir}myci-subst-var.sh --var version --val $version $args $infiles

echo "done applying version"

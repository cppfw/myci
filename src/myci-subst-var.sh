#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "myci substitute variable utility. Replaces all occurrences of '\$(variable)' in a file with given string."
            echo "Also does the substitution in the file name."
			echo ""
			echo "usage:"
			echo "	$(basename $0) <options> <list-of-input-files>"
			echo ""
			echo "input files must have '.in' suffix"
			echo ""
			echo "options:"
            echo "  --var <variable>  variable name to substitute."
			echo "  --val <value>     version string to apply"
			echo "  --filename-only   substitute only in file name, not in file contents"
			echo "  --out-dir <dir>   directory where to put resulting files, if not specified, the files are placed next to input files"
			exit 0
			;;
		--var)
			shift
			variable=$1
			;;
		--val)
			shift
			value=$1
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

if [ -z "$variable" ]; then
	error "variable name is not given"
fi

# make sure the out_dir ends with slash
if [ ! -z "$out_dir" ]; then
	if [[ "$out_dir" != */ ]]; then
		out_dir="${out_dir}/"
	fi
fi

echo "substituting variable '$variable' in files:"

for i in $infiles; do
	outfile=$(echo $i | sed -e "s/\(.*\)\.in$/\1/" | sed -e "s/\$($variable)/$value/g")

	if [ ! -z "$out_dir" ]; then
		outfile="${out_dir}$(basename $outfile)"
	fi

	echo "	$i -> $outfile"

	if [ -z "$filenameonly" ]; then
		sed -e "s/\$($variable)/$value/g" $i > $outfile
	else
		cp $i $outfile
	fi
done

#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

# define required options to empty values
declare -A local opts=( \
    [license]= \
    [suffixes]="cpp,hpp,cxx,hxx" \
    [check]="false" \
)

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "myci apply license utility. Applies license to source files."
			echo ""
			echo "usage:"
			echo "	$(basename $0) <options> [<list-of-input-files>]"
			echo ""
			echo "options:"
            echo "  --help                  show this help text."
			echo "  --license <file>        file containing the license text. Required option."
            echo "  --dir <dir>             directory to search for source files recursively."
            echo "  --suffixes <s1,s2,...>  comma separated file suffixes to serch for. Defaults to 'cpp,hpp,cxx,hxx'."
            echo "  --check                 just check for license presense, do not modify any files."
			exit 0
			;;
		--license)
			shift
			opts[license]=$1
			;;
		--dir)
            shift
			opts[dir]=$1
			;;
		--pattern)
			shift
			opts[pattern]=$1
			;;
        --check)
            opts[check]="true"
            ;;
		*)
			infiles="$infiles $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

for opt in ${!opts[@]}; do
    [ ! -z "${opts[$opt]}" ] || error "missing option: --$opt"
done

if [ ! -z "${opts[dir]}" ]; then
    find_patterns=
    joiner="-name"
    for s in ${opts[suffixes]//,/ }; do
        find_patterns="$find_patterns $joiner *.$s"
        joiner="-or -name"
    done

    # echo "find_patterns = $find_patterns"
    find_cmd=(find ${opts[dir]} -type f $find_patterns)

    infiles="$infiles $(${find_cmd[@]})"
fi

# echo "infiles = $infiles"

license_length=$(wc -l ${opts[license]} | cut --fields=1 --delimiter=' ')
echo "license_length = $license_length"

for f in $infiles; do

    license_end_line=$(awk '/^\/\/ ================ LICENSE END ================ \/\/$/{ print NR; exit }' $f)

    echo "license_end_line = $license_end_line"

done

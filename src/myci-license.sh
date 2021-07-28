#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

suffixes="cpp,hpp,cxx,hxx"

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
			license=$1
			;;
		--dir)
            shift
			dir=$1
			;;
		--suffixes)
			shift
			suffixes=$1
			;;
        --check)
            check="true"
            ;;
		*)
			infiles="$infiles $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ ! -z "$license" ] || error "missing option: --license"

if [ ! -z "${dir}" ]; then
    find_patterns=
    joiner="-name"
    for s in ${suffixes//,/ }; do
        find_patterns="$find_patterns $joiner *.$s"
        joiner="-or -name"
    done

    # echo "find_patterns = $find_patterns"
    find_cmd=(find ${dir} -type f $find_patterns)

    infiles="$infiles $(${find_cmd[@]})"
fi

# echo "infiles = $infiles"

license_end="/* ================ LICENSE END ================ */"

# generate temporary file
# Note, that mktemp on MacOS doesn't support long key names, so use short ones '-p -d'
tmp_dir=$(mktemp -d /tmp/myci.XXXXXXXXXX)
trap "rm -rf $tmp_dir" EXIT ERR
# echo "tmp_dir = $tmp_dir"

tmp_file="${tmp_dir}/tmp_file"

license_file="${tmp_dir}/license"

echo "/*" > $license_file
cat ${license} >> $license_file
echo "*/" >> $license_file
echo "" >> $license_file
echo "$license_end" >> $license_file

license_length=$(wc -l $license_file | awk '{print $1}')
# echo "license_length = $license_length"

# escape license end for awk
license_end=${license_end//\//\\/}
license_end=${license_end//\*/\\*}
# echo "license_end = $license_end"

error="false"

for f in $infiles; do
    license_end_line=$(awk "/^${license_end}$/{ print NR; exit }" $f)
	# echo "license_end_line = $license_end_line"

	if [ -z "$license_end_line" ]; then
		if [ "${check}" == "true" ]; then
			echo "$f: error: no license"
			error="true"
		else
			echo "append license $f"
			cat $license_file > $tmp_file
			echo "" >> $tmp_file
			cat $f >> $tmp_file
			mv $tmp_file $f
		fi
		continue
	fi

	if [ ! -z "$(head -$license_length $f | diff $license_file -)" ]; then
		if [ "${check}" == "true" ]; then
			echo "$f: error: wrong license"
			head -$license_length $f | diff $license_file -
			error="true"
		else
			echo "replace license $f"
			cat $license_file > $tmp_file
			tail -n +$((license_end_line+1)) $f >> $tmp_file
			mv $tmp_file $f
		fi
	fi
done

if [ "$error" == "true" ]; then
	error "some files doesn't have proper license"
fi

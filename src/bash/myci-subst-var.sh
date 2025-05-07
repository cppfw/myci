#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "Substitute variable utility. Replaces all occurrences of '\$(variable_key)' in a file with given value."
            echo "Also does the substitution in the file name."
			echo ""
			echo "usage:"
			echo "	$(basename $0) <options> <list-of-input-files>"
			echo ""
			echo "input files must have '.in' suffix"
			echo ""
			echo "options:"
            echo "  --var <variable>  variable name to substitute. Can appear several times."
			echo "  --val <value>     version string to apply. Can appear several times, must match number of --var keys."
			echo "  --filename-only   substitute only in file name, not in file contents."
			echo "  --out-dir <dir>   directory where to put output files. If not specified, the files are placed next to input files."
			exit 0
			;;
		--var)
			shift
			# append key to array of keys
			key+=($1)
			;;
		--val)
			shift
			# append value to array of values
			value+=($1)
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

[ "${#key[@]}" != 0 ] || error "no variables given with --var option"

[ "${#key[@]}" == "${#value[@]}" ] || error "number of given variable keys doesn't match number of given values"

# make sure the out_dir ends with slash
if [ ! -z "$out_dir" ]; then
	if [[ "$out_dir" != */ ]]; then
		out_dir="${out_dir}/"
	fi
fi

if [ ! -d $out_dir ]; then
	${script_dir}myci-error.sh "specified output directory '$out_dir' does not exist"
fi

# construct sed commands
for i in ${!key[@]}; do
	subst_cmd+=("sed -e s/\$(${key[$i]})/${value[$i]}/g")
done

# echo "subst_cmd = ${subst_cmd[@]}"

echo "substituting variables:"
for i in ${!key[@]}; do
	echo "  ${key[$i]} = ${value[$i]}"
done

echo "in files:"

for i in $infiles; do
	outfile=$(echo $i | sed -e "s/\(.*\)\.in\$/\1/")

	for k in ${!key[@]}; do
		# echo "subst_cmd[$k] = ${subst_cmd[$k]}"
		outfile=$(echo $outfile | ${subst_cmd[$k]})
	done

	if [ ! -z "$out_dir" ]; then
		outfile="${out_dir}$(basename $outfile)"
	fi

	echo "	$i -> $outfile"

	if [ -z "$filenameonly" ]; then
		# substitute the first variable
		${subst_cmd[0]} $i > $outfile

		# substitute the rest of variables
		for k in ${!key[@]}; do
			[ "$k" != 0 ] || continue
			# macos sed requires backup suffix to be given with -i
			${subst_cmd[$k]} -i'.bak' $outfile
		done
		rm -f "${outfile}.bak"
	else
		cp $i $outfile
	fi
done

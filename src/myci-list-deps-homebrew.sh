#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for extracting list of dependencies from homebrew formulae description file

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) [<formulae-filename> ...]"
			echo " "
			echo "If no input files are give, all dependencies from all files under 'homebrew' directory are listed."
			echo " "
			echo "Example:"
			echo "	$(basename $0) homebrew/myformulae.rb.in"
			exit 0
			;;
		*)
			input_files="$input_files $1"
			shift
			;;
	esac
done

if [ -z "$input_files" ]; then
    input_files=$(ls homebrew/*)
fi

# echo input_files = $input_files

for input_file in $input_files; do
    while read line; do
        regexp="s/[ \t]*depends_on[ \t]*\"\([^\"]*\)\".*/\1/p"
        # echo re = $regexp
        dep=$(echo $line | sed -n -e "$regexp")
        # echo line = $line dep = $dep
        deps="$deps $dep"
    done < $input_file
done

echo $deps

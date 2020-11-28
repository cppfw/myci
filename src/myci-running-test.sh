#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Print 'running test' message to the console."
			echo ""
			echo "Usage:"
			echo -e "\t$(basename $0) \"test name\""
			echo ""
			echo "Examples:"
			echo -e "\t$(basename $0) \"test1\""
			exit 0
			;;
		*)
			if [ -z "$testName" ]; then
				testName="$1"
			else
				testName="$testName $1"
			fi
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$testName" ] && echo "Error: no test name supplied" && exit 1;

test -t 1 && printf "\e[4mRunning test\e[0m \e[1;33m$testName\e[0m\n" || printf "Running test $testName\n"

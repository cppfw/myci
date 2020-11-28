#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Report an error to console and exit with exit code."
			echo ""
			echo "Usage:"
			echo -e "\t$(basename $0) <options> \"error message\""
			echo ""
			echo "Options:"
			echo -e "\t-e,--exit-code <exit-code>"
			echo -e "\tExit code to pass to the 'exit' command. Default value is 1."
			echo ""
			echo "Examples:"
			echo -e "\t$(basename $0) \"file not found!\""
			echo -e "\t$(basename $0) -e 37 \"internal error!\""
			exit 0
			;;
		-e)
			;&
		--exit-code)
			shift
			exitCode=$1
			shift
			;;
		*)
			[ ! -z "$message" ] && echo "only one message is allowed" && exit 1;
			message="$1"
			shift
			;;
	esac
done

test -t 1 && printf "\t\e[1;31mERROR\e[0m: $message\n" || printf "\tERROR: $message\n"
exit 1

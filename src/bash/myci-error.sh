#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

message=
exit_code=1

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Report an error to console and exit with exit code."
			echo ""
			echo "usage:"
			echo "  $(basename $0) <options> \"error message\""
			echo ""
			echo "options:"
			echo "  -e,--exit-code <exit-code>    Exit code to pass to the 'exit' command. Default value is 1."
			echo ""
			echo "Examples:"
			echo "  $(basename $0) \"file not found!\""
			echo "  $(basename $0) -e 37 \"internal error!\""
			exit 0
			;;
		-e)
			shift
			exit_code=$1
			;;
		--exit-code)
			shift
			exit_code=$1
			;;
		*)
			[ ! -z "$message" ] && echo "ASSERT(false): myci-error.sh: only one message is allowed: $1" && exit 1;
			message="$1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

test -t 1 && printf "\t\e[1;31mERROR\e[0m: $message\n" || printf "\tERROR: $message\n"
exit $exit_code

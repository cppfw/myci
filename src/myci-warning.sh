#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Report a warning to console."
			echo ""
			echo "Usage:"
			echo -e "\t$(basename $0) \"warning message\""
			echo ""
			echo "Examples:"
			echo -e "\t$(basename $0) \"file missing!\""
			exit 0
			;;
		*)
			[ ! -z "$message" ] && echo "only one message is allowed" && exit 1;
			message="$1"
			shift
			;;
	esac
done

test -t 1 && printf "\t\\033[1;95mWARNING\\033[0m: $message\n" || printf "\tWARNING: $message\n"

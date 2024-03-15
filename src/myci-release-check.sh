#!/bin/bash

# this script checks that we are on main branch, there are no uncommitted changes,
# and latest changes are pulled from remote

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "  $(basename $0) [<options>]"
			echo " "
            echo "options:"
            echo "  --no-unreleased-check    do not perform check for debian/changelog UNRELEASED"
            echo " "
			echo "Example:"
			echo "  $(basename $0)"
			exit 0
			;;
        --no-unreleased-check)
            no_unreleased_check=true;
            ;;
		*)
            source myci-error.sh "unknown argument specified: $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

echo "check that we are on main branch"
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" == "main" ] || source myci-error.sh "not on main branch"

echo "check for uncommitted changes"
[ -z "$(git diff-index HEAD --)" ] || source myci-error.sh "uncommitted changes detected"

echo "fetch latest"
git fetch || source myci-error.sh "git fetch failed"

echo "check for main up to date"
[ -z "$(git status --short --branch | sed -E -n -e 's/.*(behind).*/true/p')" ] || source myci-error.sh "local main is behind remote main, do git pull and try again"

if [ "$no_unreleased_check" != "true" ]; then
    echo "check that debian/changelog is UNRELEASED"
    distro=$($(dirname $0)/get-distribution.sh)
    [ "$distro" == "UNRELEASED" ] || source myci-error.sh "the debian/changelog is not in UNRELEASED state: $distro"
fi

echo "all ok"

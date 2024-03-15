#!/bin/bash

# this script releases the current version

# it changes the debian record to unstable release
# and pushes the release to git repo adding the release tag

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

[[ ! -z ${DEBEMAIL+x} ]] || source myci-error.sh "DEBEMAIL is unset"
[[ ! -z ${DEBFULLNAME+x} ]] || source myci-error.sh "DEBFULLNAME is unset"

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "  $(basename $0) [<options>]"
			echo " "
            echo "options:"
            echo "  --no-release-checks    do not perform checks before release"
            echo " "
			echo "Example:"
			echo "  $(basename $0)"
			exit 0
			;;
        --no-release-checks)
            no_release_checks=true;
            ;;
		*)
            source myci-error.sh "unknown argument specified: $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ "$no_release_checks" == "true" ] || source $(dirname $0)/do-release-checks.sh

version=$(myci-deb-version.sh debian/changelog)

# echo $version

dch --release --distribution=unstable "" || source myci-error.sh "dch --release failed"

git commit --all --message="release $version" || source myci-error.sh "git commit failed"

git branch --force latest HEAD || source myci-error.sh "git branch --force latest HEAD failed"

git push --set-upstream origin latest master || source myci-error.sh "git push failed"

git tag $version || source myci-error.sh "git tag failed"

git push --force --tags || source myci-error.sh "git push --tags failed"

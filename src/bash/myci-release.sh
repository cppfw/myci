#!/bin/bash

# this script releases the current version

# it changes the debian record to unstable release
# and pushes the release to git repo adding the release tag

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

[[ ! -z ${DEBEMAIL+x} ]] || source ${script_dir}myci-error.sh "DEBEMAIL is unset"
[[ ! -z ${DEBFULLNAME+x} ]] || source ${script_dir}myci-error.sh "DEBFULLNAME is unset"

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
            source ${script_dir}myci-error.sh "unknown argument specified: $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ "$no_release_checks" == "true" ] || source ${script_dir}myci-release-check.sh

version=$(${script_dir}myci-deb-version.sh)

# echo $version

if [ -d build/debian ]; then
	deb_root_dir=build
elif [ -d debian ]; then
	deb_root_dir=.
fi

(cd $deb_root_dir; dch --release --distribution=unstable "" || source ${script_dir}myci-error.sh "dch --release failed")

git commit --all --message="release $version" || source ${script_dir}myci-error.sh "git commit failed"

git branch --force latest HEAD || source ${script_dir}myci-error.sh "git branch --force latest HEAD failed"

GIT_ASKPASS=${script_dir}myci-git-askpass.sh git push --set-upstream origin main || source ${script_dir}myci-error.sh "git push main failed"
GIT_ASKPASS=${script_dir}myci-git-askpass.sh git push --force --set-upstream origin latest || source ${script_dir}myci-error.sh "git push latest failed"

git tag $version || source ${script_dir}myci-error.sh "git tag failed"

GIT_ASKPASS=${script_dir}myci-git-askpass.sh git push --force --tags || source ${script_dir}myci-error.sh "git push --tags failed"

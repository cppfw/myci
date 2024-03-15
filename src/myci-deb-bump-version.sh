#!/bin/bash

# script for quick bumping up the minor version,
# i.e. version maj.min+1.0.

# Minor version from debian changelog will be incremented
# and a comment passed as argument is added.

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

[[ ! -z ${DEBEMAIL+x} ]] || source myci-error.sh "DEBEMAIL is unset"
[[ ! -z ${DEBFULLNAME+x} ]] || source myci-error.sh "DEBFULLNAME is unset"

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "  $(basename $0) [--revision] <first-comment>"
			echo " "
			echo "By default minor version is bumped. If --revision is supplied then revision version is bumped."
			echo " "
			echo "Example:"
			echo "  $(basename $0) \"first comment item in new version changelog\""
			exit 0
			;;
		--revision)
			is_revision=true
			;;
		*)
            [ -z "$comment" ] || source myci-error.sh "more than one comment specified"
			comment="$1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ ! -z "$comment" ] || source myci-error.sh "comment as argument expected"

version=$(myci-deb-version.sh debian/changelog)

# echo $version

maj=$(echo $version | sed -n -e 's/^\([0-9]*\)\.[0-9]*\.[0-9]*$/\1/p')
min=$(echo $version | sed -n -e 's/^[0-9]*\.\([0-9]*\)\.[0-9]*$/\1/p')
rev=$(echo $version | sed -n -e 's/^[0-9]*\.[0-9]*\.\([0-9]*\)$/\1/p')

echo old version = $maj.$min.$rev

if [ "$is_revision" == "true" ]; then
    echo bump revision version
    newver=$maj.$min.$((rev+1))
else
    echo bump minor version
    newver=$maj.$((min+1)).0
fi

echo new version = $newver

dch --newversion="$newver" "$comment" || source myci-error.sh "updating debian/changelog failed"

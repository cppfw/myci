#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to cocoapods.
# It assumes that cocoapods specs to deploy are in 'cocoapods' directory.


while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) -r <repo-name> [<spec.podspec.in>]"
            echo " "
            echo "Environment variable MYCI_GIT_ACCESS_TOKEN can be set to git access token, so that it will be stripped out from the script output."
            echo " "
            echo "Example:"
            echo "	$(basename $0) -r igagis cocoapods/*.podspec.in"
            exit 0
			;;
        -r)
			shift
			reponame=$1
			shift
			;;
		*)
			if [ ! -z "$podspecfile" ]; then
				echo "error: more than one podspec file supplied"
				exit 1
			fi
			podspecfile="$1"
			shift
			;;
    esac
done

if [ -z "$podspecfile" ]; then
	podspecfile=$(ls cocoapods/*.podspec.in)
fi
set -- $podspecfile
podspecfile="$1"

echo "Deploying to cocoapods"

# update version numbers
version=$(myci-deb-version.sh debian/changelog)

echo "current package version is $version, applying it to podspecs"

myci-apply-version.sh -v $version $podspecfile

echo "version $version applied to podspec"

# Make sure MYCI_GIT_ACCESS_TOKEN is set
[ -z "$MYCI_GIT_ACCESS_TOKEN" ] && echo "Error: MYCI_GIT_ACCESS_TOKEN is not set" && exit 1;

cutSecret="sed -e s/$MYCI_GIT_ACCESS_TOKEN/<secret>/"

echo "Cocoapods version = $(pod --version)"

outpodspecfile=$(echo $podspecfile | sed -n -e 's/\(.*\)\.in$/\1/p')

# Need to pass --use-libraries because before pushing the spec it will run 'pod lint'
# on it. And 'pod lint' uses framework integration by default which will fail to copy
# some header files to the right places.
pod repo push $reponame $outpodspecfile --use-libraries --skip-import-validation --allow-warnings 2>&1 | $cutSecret

echo "Deploying to cocoapods done!"

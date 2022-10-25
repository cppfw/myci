#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to cocoapods.
# It assumes that cocoapods specs to deploy are in 'cocoapods' directory.
# The binary zip packages are deployed to JFrog artifactory generic repository.

source myci-common.sh

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) -r/--repo <cocoapods-repo-name> -v/--version <version> [-o/--domain <jfrog-repo-domain> -b/--jfrog-repo <jfrog-repo> -p/--package-file <package-file>] <spec.podspec.in>"
            echo " "
            echo "Environment variable MYCI_GIT_PASSWORD can be set to git access token, so that it will be stripped out from the script output."
			echo "When uploading binary package to jfrog artifactory MYCI_JFROG_USERNAME and MYCI_JFROG_PASSWORD must be set."
			echo "Package name will be taken from podspec filename."
            echo " "
            echo "Example:"
            echo "	$(basename $0) -r cppfw -v 1.0.0 -o igagis -b cocoapods -p mypackage-1.0.0.zip cocoapods/mypackage.podspec.in"
            exit 0
			;;
        -r)
			shift
			reponame=$1
			;;
		--repo)
			shift
			reponame=$1
			;;
		-v)
			shift
			version=$1
			;;
		--version)
			shift
			version=$1
			;;
		-o)
			shift
			domain=$1
			;;
		--domain)
			shift
			domain=$1
			;;
		-b)
			shift
			jfrog_repo=$1
			;;
		--jfrog-repo)
			shift
			jfrog_repo=$1
			;;
		-p)
			shift
			zip_package_file=$1
			;;
		--package-file)
			shift
			zip_package_file=$1
			;;
		*)
			if [ ! -z "$podspecfile" ]; then
				echo "error: more than one podspec file supplied"
				exit 1
			fi
			podspecfile="$1"
			;;
    esac

	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_GIT_PASSWORD" ] && source myci-error.sh "MYCI_GIT_PASSWORD is not set";

[ -z "$reponame" ] && source myci-error.sh "cocoapods reponame is not given";

if [ -z "$podspecfile" ]; then
	echo "DEPRECATED: no podspec file supplied. Using first one found in cocoapods directory."
	podspecfile=$(ls cocoapods/*.podspec.in)
	set -- $podspecfile
	podspecfile="$1"
	echo "	using '$podspecfile'"
fi

if [ -z "$version" ]; then
	echo "DEPRECATED: no version is supplied via -v key. Trying to extract version from debian/changelog..."
	version=$(myci-deb-version.sh debian/changelog)
	echo "	using $version extracted from debian/changelog."
fi

if [ ! -z "$domain" ] || [ ! -z "$jfrog_repo" ] || [ ! -z "$zip_package_file" ]; then
	echo "will also upload package to JFrog artifactory generic repo"
	[ -z "$MYCI_JFROG_USERNAME" ] && source myci-error.sh "MYCI_JFROG_USERNAME is not set";
	[ -z "$MYCI_JFROG_PASSWORD" ] && source myci-error.sh "MYCI_JFROG_PASSWORD is not set";
	[ -z "$domain" ] && source myci-error.sh "JFrog artifactory domain is not given";
	[ -z "$jfrog_repo" ] && source myci-error.sh "JFrog artifactory repo name is not given";
	[ -z "$zip_package_file" ] && source myci-error.sh "package file for uploading to JFrog artifactory is not given";
fi

myci-apply-version.sh --version $version $podspecfile

outpodspecfile=$(echo $podspecfile | sed -n -e 's/\(.*\)\.in$/\1/p')

package=$(echo $(basename $podspecfile) | sed -n -e 's/\(.*\)\.podspec.in$/\1/p')

if [ ! -z "$domain" ]; then
	echo "upload file '$zip_package_file' to JFrog artifactory"
	url="https://$domain.jfrog.io/artifactory/$jfrog_repo"
	http_upload_file "$MYCI_JFROG_USERNAME:$MYCI_JFROG_PASSWORD" $url/$(basename $zip_package_file) $zip_package_file

	echo "done deploying '$package' package version $version to JFrog artifactory generic repo"
fi

echo "deploy to cocoapods"

echo "Cocoapods version = $(pod --version)"

# Need to pass --use-libraries because before pushing the spec it will run 'pod lint'
# on it. And 'pod lint' uses framework integration by default which will fail to copy
# some header files to the right places.

GIT_ASKPASS=myci-git-askpass.sh pod repo push $reponame $outpodspecfile --use-libraries --skip-import-validation --allow-warnings

echo "done deploying to cocoapods"

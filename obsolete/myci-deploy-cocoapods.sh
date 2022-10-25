#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to cocoapods.
# It assumes that cocoapods specs to deploy are in 'cocoapods' directory.

source myci-common.sh

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) -r/--repo <cocoapods-repo-name> -v/--version <version> [-o/--bintray-owner <bintray-repo-owner> -b/--bintray-repo <bintray-repo> -p/--package-file <package-file>] <spec.podspec.in>"
            echo " "
            echo "Environment variable MYCI_GIT_PASSWORD can be set to git access token, so that it will be stripped out from the script output."
			echo "When uploading binary package to bintray MYCI_BINTRAY_API_KEY must be set to Bintray API key token and MYCI_BINTRAY_USERNAME muste be set to bintray user name."
			echo "Package name will be taken from podspec filename."
            echo " "
            echo "Example:"
            echo "	$(basename $0) -r igagis -v 1.0.0 -o igagis -b cocoapods -p mypackage-1.0.0.zip cocoapods/mypackage.podspec.in"
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
			bintray_owner=$1
			;;
		--bintray-owner)
			shift
			bintray_owner=$1
			;;
		-b)
			shift
			bintray_repo=$1
			;;
		--bintray-repo)
			shift
			bintray_repo=$1
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
	echo "	Using $version extracted from debian/changelog."
fi

if [ ! -z "$bintray_owner" ] || [ ! -z "$bintray_repo" ] || [ ! -z "$zip_package_file" ]; then
	echo "Will also upload package to Bintray"
	[ -z "$MYCI_BINTRAY_USERNAME" ] && source myci-error.sh "MYCI_BINTRAY_USERNAME is not set";
	[ -z "$MYCI_BINTRAY_API_KEY" ] && source myci-error.sh "MYCI_BINTRAY_API_KEY is not set";
	[ -z "$bintray_owner" ] && source myci-error.sh "Bintray repo owner is not given";
	[ -z "$bintray_repo" ] && source myci-error.sh "Bintray repo name is not given";
	[ -z "$zip_package_file" ] && source myci-error.sh "package file for uploading to Bintray is not given";
fi

myci-apply-version.sh --version $version $podspecfile

outpodspecfile=$(echo $podspecfile | sed -n -e 's/\(.*\)\.in$/\1/p')

package=$(echo $(basename $podspecfile) | sed -n -e 's/\(.*\)\.podspec.in$/\1/p')

if [ ! -z "$bintray_owner" ]; then
	echo "Uploading package to Bintray"

	echo "Creating package '$package' on Bintray"
	createPackageOnBintray $bintray_owner $bintray_repo $package

	echo "Creating version $version of the '$package' on Bintray"
	createVersionOnBintray $bintray_owner $bintray_repo $package $version

	echo "Uploading file '$zip_package_file' to Bintray"
	uploadFileToGenericBintray $zip_package_file $bintray_owner $bintray_repo $package/$version $package $version

	echo "Done deploying '$package' package version $version to Bintray Generic repo."
fi

echo "Deploying to cocoapods"

echo "Cocoapods version = $(pod --version)"

# Need to pass --use-libraries because before pushing the spec it will run 'pod lint'
# on it. And 'pod lint' uses framework integration by default which will fail to copy
# some header files to the right places.

GIT_ASKPASS=myci-git-askpass.sh pod repo push $reponame $outpodspecfile --use-libraries --skip-import-validation --allow-warnings

echo "Deploying to cocoapods done!"

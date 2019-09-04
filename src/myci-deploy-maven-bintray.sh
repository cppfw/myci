#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved.
set -eo pipefail

# Script for quick deployment of maven package (.aar and .pom files) to bintray Maven repo.

source src/myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying AAR packages to Bintray Maven repo."
			echo "Usage:"
			echo "	$(basename $0) -u <bintray-user-name> -r <bintray-repo-name> -p <repo-path> <package-aar-filename>"
			echo " "
			echo "Environment variable MYCI_BINTRAY_API_KEY must be set to Bintray API key token, it will be stripped out from the script output."
			echo "POM file should be named same as AAR file but with .pom suffix and should reside right next to .aar file."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -u igagis -r android -p io/github/igagis libawesome.aar"
			exit 0
			;;
		-r)
			shift
			reponame=$1
			shift
			;;
		-u)
			shift
			username=$1
			shift
			;;
		-p)
			shift
			repoPath=$1
			shift
			;;
		-a)
			shift
			aarFile=$1
			shift
			;;
		*)
			[ ! -z "$aarFile" ] && source myci-error.sh "more than one file is given, expecting only one";
			aarFile=$1
			shift
			;;

	esac
done

[ -z "$MYCI_BINTRAY_API_KEY" ] && source myci-error.sh "MYCI_BINTRAY_API_KEY is not set";

[ -z "$username" ] && source myci-error.sh "Bintray user name is not given";

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

[ -z "$repoPath" ] && source myci-error.sh "repo path is not given";

[ -z "$aarFile" ] && source myci-error.sh "AAR file is not given, use -a option";

# make POM filename from AAR filename.
pomFile=${aarFile%.*}.pom

#echo "POM file = $pomFile"

# check POM file exists.
[ ! -f "$pomFile" ] && source myci-error.sh "POM file ($pomFile) not found";


echo "Deploying AAR package to Bintray"

filename=$(basename $aarFile)

package=$(package_from_package_version_filename $filename)
version=$(version_from_package_version_filename $filename)

echo "package = $package"
echo "version = $version"

echo "Creating package '$package' on Bintray"
createPackageOnBintray $username $reponame $package

echo "Creating version $version of the '$package' on Bintray"
createVersionOnBintray $username $reponame $package $version

echo "Uploading file '$aarFile' to Bintray"
uploadFileToGenericBintray $aarFile $username $reponame $repoPath/$package/$version $package $version
echo "Uploading file '$pomFile' to Bintray"
uploadFileToGenericBintray $pomFile $username $reponame $repoPath/$package/$version $package $version

echo "Done deploying '$package' package version $version to Bintray Maven repo."

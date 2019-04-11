#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

#Script for quick deployment of debian package to bintray repo

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) -u <bintray-user-name> -r <bintray-repo-name> -p <package-name> -c <deb_component> -d <deb_distribution> <package-filename> [<package-filename> ...]"
			echo " "
			echo "Environment variable MYCI_BINTRAY_API_KEY must be set to Bintray API key token, it will be stripped out from the script output."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -u igagis -r deb-stretch -p myci -c main -d unstable ../myci_0.1.29_all.deb"
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
			packageName=$1
			shift
			;;
        -c)
            shift
            component=$1
            shift
            ;;
        -d)
            shift
            distribution=$1
            shift
            ;;
		*)
			packageFiles="$packageFiles $1"
			shift
			;;
	esac
done

[ -z "$MYCI_BINTRAY_API_KEY" ] && source myci-error.sh "MYCI_BINTRAY_API_KEY is not set";

[ -z "$username" ] && source myci-error.sh "Bintray user name is not given";

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

[ -z "$packageName" ] && source myci-error.sh "package name is not given";

[ -z "$packageFiles" ] && source myci-error.sh "package files are not given";

[ -z "$component" ] && source myci-error.sh "debian component/s is/are not given";

[ -z "$distribution" ] && source myci-error.sh "debian distribution/s is/are not given";


# Create package on bintray if it does not exist.
createPackageOnBintray $username $reponame $packageName

# For each package file create a version and upload the file to Bintray
for f in $packageFiles; do
    versionName=$(echo "$f" | sed -n -e"s/.*_\([^_]*\)_[^_]*.deb$/\1/p")
    architecture=$(echo "$f" | sed -n -e"s/.*_\([^_]*\).deb$/\1/p")
#    echo $versionName
#    echo $architecture
    createVersionOnBintray $username $reponame $packageName $versionName
    uploadFileToDebianBintray $f $username $reponame $packageName $versionName $distribution $component $architecture
done



#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment of pacman package (Arch linux package manager system) to bintray repo

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying pacman packages to Bintray Generic repo."
			echo "Usage:"
			echo "	$(basename $0) -o/--owner <bintray-repo-owner> -r/--repo <bintray-repo-name> -p/--path <repo-path> -d/--database <database-name> <package-filename>"
			echo " "
			echo "Environment variable MYCI_BINTRAY_USERNAME must be set to Bintray username."
			echo "Environment variable MYCI_BINTRAY_API_KEY must be set to Bintray API key."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -o igagis -r msys2 -p mingw/x86_64 -d igagis_mingw64 *.xz"
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
		-o)
			shift
			owner=$1
			;;
		--owner)
			shift
			owner=$1
			;;
		-p)
			shift
			repoPath=$1
			;;
		--path)
			shift
			repoPath=$1
			;;
		-d)
			shift
			dbName=$1
			;;
		--database)
			shift
			dbName=$1
			;;
		*)
			[ ! -z "$packageFile" ] && source myci-error.sh "more than one package file is given, expected only one"
			packageFile="$1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_BINTRAY_USERNAME" ] && source myci-error.sh "MYCI_BINTRAY_USERNAME is not set";
[ -z "$MYCI_BINTRAY_API_KEY" ] && source myci-error.sh "MYCI_BINTRAY_API_KEY is not set";

[ -z "$owner" ] && source myci-error.sh "Bintray repo owner is not given";

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

[ -z "$repoPath" ] && source myci-error.sh "repo path is not given";

[ -z "$dbName" ] && source myci-error.sh "database name is not given";

[ -z "$packageFile" ] && source myci-error.sh "package file is not given";

echo "Deploying pacman package to Bintray"

# Get latest version of pacman database package

latestDbVer=$(curl --silent https://api.bintray.com/packages/$owner/$reponame/$dbName/versions/_latest | sed -n -e 's/.*"name":"\([^"]*\)".*/\1/p')

echo "Latest pacman DB version = $latestDbVer"

if [ -z "$latestDbVer" ]; then
        newDbVer=0;
else
	echo "bumping db version"
	newDbVer=$((latestDbVer+1));
fi

echo "New pacman DB version = $newDbVer"

# Download current pacman database
uncompressedDbFilename=$dbName.db
dbFilename=$uncompressedDbFilename.tar.gz
versionedDbFilename=$dbName-$newDbVer.db.tar.gz

res=$(curl --silent --location --write-out "%{http_code}" https://dl.bintray.com/content/$owner/$reponame/$repoPath/$dbFilename -o $dbFilename)

if [ $res -eq 404 ]; then
	echo "no database found on bintray, creating new database package '$dbName' on Bintray"
	createPackageOnBintray $owner $reponame $dbName
elif [ $res -ne 200 ]; then
	rm $dbFilename
	source myci-error.sh "could not download current pacman database, HTTP response code was $res, expected 200"
fi

echo "Adding package '$packageFile' to the database"
repo-add $dbFilename $packageFile

ln -f -s $dbFilename $versionedDbFilename

# create new versions of packages

#echo "package file = $packageFile"
packageFilename=$(basename $packageFile)
#echo "package filename = $packageFilename"
package=$(echo "$packageFilename" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[^-]*\.pkg\..*/\1/p')
version=$(echo "$packageFilename" | sed -n -e"s/^$package-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-[0-9]\+-[^-]*\.pkg\..*/\1/p")

echo "creating package '$package' on Bintray"
createPackageOnBintray $owner $reponame $package

echo "creating version $version for package '$package' on Bintray"
createVersionOnBintray $owner $reponame $package $version

echo "creating version $newDbVer for pacman database on Bintray"
createVersionOnBintray $owner $reponame $dbName $newDbVer

# Upload packages

echo "Uploading package file '$packageFilename' to Bintray"
uploadFileToGenericBintray $packageFile $owner $reponame $repoPath $package $version

echo "Uploading versioned pacman database to Bintray"
uploadFileToGenericBintray $versionedDbFilename $owner $reponame $repoPath $dbName $newDbVer

echo "Deleting old pacman database"
deleteFileFromBintray $dbFilename $owner $reponame $repoPath
deleteFileFromBintray $uncompressedDbFilename $owner $reponame $repoPath
deleteFileFromBintray $dbName.files $owner $reponame $repoPath

echo "Uploading actual pacman database to Bintray"
uploadFileToGenericBintray $dbFilename $owner $reponame $repoPath $dbName $newDbVer
uploadFileToGenericBintray $uncompressedDbFilename $owner $reponame $repoPath $dbName $newDbVer
uploadFileToGenericBintray $dbName.files $owner $reponame $repoPath $dbName $newDbVer

echo "Done deploying '$package' version $version to Bintray."

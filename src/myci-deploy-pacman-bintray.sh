#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

#Script for quick deployment of pacman package (Arch linux package manager system) to bintray repo

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying pacman packages to Bintray Generic repo."
			echo "Usage:"
			echo "	$(basename $0) -u <bintray-user-name> -r <bintray-repo-name> -p <repo-path> -d <database-name> <package-filename>"
			echo " "
			echo "Environment variable MYCI_BINTRAY_API_KEY must be set to Bintray API key token, it will be stripped out from the script output."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -u igagis -r msys2 -p mingw/x86_64 -d igagis_mingw64 *.xz"
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
		-d)
			shift
			dbName=$1
			shift
			;;
		*)
			packageFile="$1"
			shift
			;;
	esac
done

[ -z "$MYCI_BINTRAY_API_KEY" ] && source myci-error.sh "MYCI_BINTRAY_API_KEY is not set";

[ -z "$username" ] && source myci-error.sh "Bintray user name is not given";

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

[ -z "$repoPath" ] && source myci-error.sh "repo path is not given";

[ -z "$dbName" ] && source myci-error.sh "database name is not given";

[ -z "$packageFile" ] && source myci-error.sh "package file is not given";

echo "Deploying pacman package to Bintray"

#Get latest version of pacman database package

latestDbVer=$(curl -s https://api.bintray.com/packages/$username/$reponame/$dbName/versions/_latest | sed -n -e 's/.*"name":"\([^"]*\)".*/\1/p')

echo "Latest pacman DB version = $latestDbVer"

if [ -z "$latestDbVer" ]; then
        newDbVer=0;
else
	echo "bumping db version"
	newDbVer=$((latestDbVer+1));
fi

echo "New pacman DB version = $newDbVer"


#Download current pacman database
uncompressedDbFilename=$dbName.db
dbFilename=$uncompressedDbFilename.tar.gz
versionedDbFilename=$dbName-$newDbVer.db.tar.gz

res=$(curl -s -L --write-out "%{http_code}" https://dl.bintray.com/content/$username/$reponame/$repoPath/$dbFilename -o $dbFilename)

#echo "http code = $res"

if [ $res -ne 200 ]; then
	rm $dbFilename
fi

echo "Adding package to the database"
repo-add $dbFilename $packageFile

ln -f -s $dbFilename $versionedDbFilename


#create new versions of packages

#echo "package file = $packageFile"
packageFilename=$(basename $packageFile)
#echo "package filename = $packageFilename"
package=$(echo "$packageFilename" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[^-]*\.pkg\.tar\.xz$/\1/p')
version=$(echo "$packageFilename" | sed -n -e"s/^$package-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-[0-9]\+-[^-]*\.pkg\.tar\.xz$/\1/p")

echo "creating version $version for package '$package' on Bintray"
createVersionOnBintray $username $reponame $package $version

echo "creating version $newDbVer for pacman database on Bintray"
createVersionOnBintray $username $reponame $dbName $newDbVer


#Upload packages

echo "Uploading package file '$packageFilename' to Bintray"
uploadFileToGenericBintray $packageFile $username $reponame $repoPath $package $version

echo "Uploading versioned pacman database to Bintray"
uploadFileToGenericBintray $versionedDbFilename $username $reponame $repoPath $dbName $newDbVer

echo "Deleting old pacman database"
deleteFileFromBintray $dbFilename $username $reponame $repoPath
deleteFileFromBintray $uncompressedDbFilename $username $reponame $repoPath
deleteFileFromBintray $dbName.files $username $reponame $repoPath

echo "Uploading actual pacman database to Bintray"
uploadFileToGenericBintray $dbFilename $username $reponame $repoPath $dbName $newDbVer
uploadFileToGenericBintray $uncompressedDbFilename $username $reponame $repoPath $dbName $newDbVer
uploadFileToGenericBintray $dbName.files $username $reponame $repoPath $dbName $newDbVer

echo "Done deploying '$package' version $version to Bintray."

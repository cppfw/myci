#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

#Script for quick deployment of pacman package (Arch linux package manager system) to bintray repo


while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) -u <bintray-user-name> -r <bintray-repo-name> -p <repo-path> <package-filename>"
			echo " "
			echo "Environment variable MYCI_BINTRAY_API_KEY must be set to Bintray API key token, it will be stripped out from the script output."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -u igagis -r msys2 -p mingw/x86_64 *.xz"
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

[ -z "$packageFile" ] && source myci-error.sh "package file is not given";

echo "Deploying pacman package to Bintray..."

#Get latest version of pacman database package

latestDbVer=$(curl -s https://api.bintray.com/packages/$username/$reponame/pacman-db/versions/_latest | sed -n -e 's/.*"name":"\([^"]*\)".*/\1/p')

echo "Latest pacman DB version = $latestDbVer"

if [ -z "$latestDbVer" ]; then
        newDbVer=0;
else
	echo "bumping db version..."
	newDbVer=$((latestDbVer+1));
fi

echo "New pacman DB version = $newDbVer"


#Download current pacman database
dbFilename=pacman.db.tar.gz
versionedDbFilename=pacman-$newDbVer.db.tar.gz

res=$(curl -s -L --write-out "%{http_code}" https://dl.bintray.com/content/$username/$reponame/$repoPath/$dbFilename -o $dbFilename)

#echo "http code = $res"

if [ $res -ne 200 ]; then
	rm $dbFilename
fi

echo "Adding package to the database..."
repo-add $dbFilename $packageFile

ln -f -s $dbFilename $versionedDbFilename


#create new versions of packages

function createPackageVersionOnBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$username:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$2\",\"desc\":\"\"}" https://api.bintray.com/packages/$username/$reponame/$1/versions);
	[ $res -ne 201 ] && myci-warning.sh "creating version $2 on Bintray for package '$1' failed, HTTP code = $res";
	return 0;
}

#echo "package file = $packageFile"
packageFilename=$(basename $packageFile)
#echo "package filename = $packageFilename"
package=$(echo "$packageFilename" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[^-]*\.pkg\.tar\.xz$/\1/p')
version=$(echo "$packageFilename" | sed -n -e"s/^$package-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-[0-9]\+-[^-]*\.pkg\.tar\.xz$/\1/p")

echo "creating version $version for package '$package' on Bintray..."
createPackageVersionOnBintray $package $version

echo "creating version $newDbVer for pacman database on Bintray..."
createPackageVersionOnBintray pacman-db $newDbVer


#Upload packages

function uploadFileToPackageVersionOnBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$username:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$2" -H"X-Bintray-Version:$3" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$username/$reponame/$repoPath/);
	[ $res -ne 201 ] && myci-error.sh "uploading file '$1' to Bintray package '$2' version $3 failed, HTTP code = $res";
	return 0;
}

function deleteFileFromBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$username:$MYCI_BINTRAY_API_KEY -X DELETE https://api.bintray.com/content/$username/$reponame/$repoPath/$1);
	[ $res -ne 200 ] && myci-warning.sh "deleting file '$1' from Bintray failed, HTTP code = $res";
	return 0;
}

echo "Uploading package file '$packageFilename' to Bintray..."
uploadFileToPackageVersionOnBintray $packageFile $package $version

echo "Uploading versioned pacman database to Bintray..."
uploadFileToPackageVersionOnBintray $versionedDbFilename pacman-db $newDbVer

echo "Deleting old pacman database..."
deleteFileFromBintray $dbFilename

echo "Uploading actual pacman database to Bintray..."
uploadFileToPackageVersionOnBintray $dbFilename pacman-db $newDbVer

echo "Done deploying '$package' version $version to Bintray."


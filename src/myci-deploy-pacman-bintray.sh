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

res=$(curl -s -L --write-out "%{http_code}" https://dl.bintray.com/content/$username/$reponame/$repoPath/$dbFilename -o $dbFilename)

#echo "http code = $res"

if [ $res -ne 200 ]; then
	rm $dbFilename
fi

echo "Adding package to the database..."
repo-add $dbFilename $packageFile


#create new versions of packages

function createPackageVersionOnBintray {
	local res=$(curl -s --write-out "%{http_code}" -o /dev/null -u$username:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$2\",\"desc\":\"\"}" https://api.bintray.com/packages/$username/$reponame/$1/versions)
	[ $res -ne 201 ] && source myci-warning.sh "creating version $2 on Bintray for package '$1' failed, HTTP code = $res"
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
	local res=$(curl -s -o /dev/null --write-out "%{http_code}" -u$username:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$2" -H"X-Bintray-Version:$3" -H"X-Bintray-Override:1" https://api.bintray.com/content/$username/$reponame/$repoPath/)
	[ $res -ne 201 ] && source myci-error.sh "uploading file '$1' to Bintray package '$2' version $3 failed, HTTP code = $res"
}

echo "Uploading package file '$packageFilename' to Bintray..."
uploadFileToPackageVersionOnBintray $packageFile $package $version



exit 0















#update version numbers
version=$(myci-deb-version.sh debian/changelog)

#echo "current package version is $version, applying it to cygport files..."
#
#myci-apply-version.sh -v $version $infiles
#
#echo "version $version applied to cygport files"



#=== clone repo ===

#Make sure MYCI_GIT_USERNAME is set
[ -z "$MYCI_GIT_USERNAME" ] && source myci-error.sh "Error: MYCI_GIT_USERNAME is not set";

#Make sure MYCI_GIT_ACCESS_TOKEN is set
[ -z "$MYCI_GIT_ACCESS_TOKEN" ] && source myci-error.sh "Error: MYCI_GIT_ACCESS_TOKEN is not set";

cutSecret="sed -e s/$MYCI_GIT_ACCESS_TOKEN/<secret>/"

repodir=cygwin-repo

#clean if needed
rm -rf $repodir

repo=https://$MYCI_GIT_USERNAME:$MYCI_GIT_ACCESS_TOKEN@github.com/$reponame.git

git clone $repo $repodir 2>&1 | $cutSecret

[ $? -ne 0 ] && source myci-error.sh "'git clone' failed";

#--- repo cloned ---


architecture=$(uname -m)
if [[ "$architecture" == "i686" || "$architecture" == "i386" ]]; then architecture="x86"; fi


#=== create directory tree if needed ===
mkdir -p $repodir/$architecture/release
#---

#=== copy packages to repo and add them to git commit ===
for fin in $infiles
do
	#note that sometimes arch is i686 instead of x86, but mksetupini script only accepts x86,
	#so invoke $(uname -m) again here instead of using $architecture variable
	dist=$(echo $fin | sed -n -e 's/\(.*\)\.cygport\.in$/\1/p')-$version-1.$(uname -m)/dist

#	echo $dist
	cp -r $dist/* $repodir/$architecture/release
	[ $? -ne 0 ] && source myci-error.sh "could not copy packages to cygwin repo directory tree";

	f=$(echo $fin | sed -n -e 's/\(.*\)\.cygport\.in$/\1/p' | sed -n -e 's/.*\///p')

	if [ -z "$packages" ]; then packages="$f"; else packages="$packages, $f"; fi
done 
#---

(
cd $repodir

	#run mksetupini
	mksetupini --arch $architecture --inifile=$architecture/setup.ini --releasearea=. --disable-check=missing-depended-package,missing-required-package,curr-most-recent
	[ $? -ne 0 ] && source myci-error.sh "'mksetupini' failed";

	bzip2 <$architecture/setup.ini >$architecture/setup.bz2
	xz -6e <$architecture/setup.ini >$architecture/setup.xz

	git config user.email "myci@myci.org"
	git config user.name "Prorab Prorabov"

	git add .
	git commit -a -m"version $version of $packages"
	git push 2>&1 | $cutSecret

cd ..
)

#clean
echo "Removing cloned repo..."
rm -rf $repodir

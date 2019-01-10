#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

#Script for quick deployment to custom github-based cygwin repository.


while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) -r <repo-name> [<spec1.cygport.in> <spec2.cygport.in>...]"
            echo " "
            echo "Environment variable MYCI_GIT_ACCESS_TOKEN should be set to git access token, it will be stripped out from the script output."
            echo " "
            echo "Example:"
            echo "	$(basename $0) -r igagis/cygwin-repo cygwin/*.cygport.in"
            exit 0
        ;;
        -r)
			shift
			reponame=$1
			shift
			;;
		*)
			infiles="$infiles $1"
			shift
			;;
    esac
done

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

if [ -z "$infiles" ]; then
	infiles=$(ls cygwin/*.cygport.in)
fi

[ -z "$infiles" ] && source myci-error.sh "no input files found";

echo "Deploying to cygwin"

#update version numbers
version=$(myci-deb-version.sh debian/changelog)

#echo "current package version is $version, applying it to cygport files"
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
echo "Removing cloned repo"
rm -rf $repodir

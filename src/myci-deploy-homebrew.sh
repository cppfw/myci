#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to homebrew.
# It assumes that homebrew recipes to deploy are in 'homebrew' directory.

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "\t$(basename $0) -t/--tap <tap-name> <recipe-file-name.rb.in> ..."
			echo " "
			echo "GitHub username and access token should be in MYCI_GIT_USERNAME and MYCI_GIT_PASSWORD environment variables."
			echo " "
			echo "Example:"
			echo "\t$(basename $0) -t igagis/tap homebrew/*.rb.in"
			exit 0
			;;
		-t)
			shift
			tapname=$1
			;;
		--tap)
			shift
			tapname=$1
			;;
		*)
			infiles="$infiles $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

echo "Deploying to homebrew repo"

[ -z "$tapname" ] && echo "Error: -t option is not given" && exit 1;

if [ -z "$infiles" ]; then
	echo "No input files specified, taking all files from 'homebrew' folder"
	infiles=$(ls homebrew/*.rb.in)
fi

# parse homebrew tap name
tap=(${tapname//\// })

username="${tap[0]}"
tapname="homebrew-${tap[1]}"

echo "username: ${username}, tapname: ${tapname}"

# update version numbers
echo "getting version from Debian changelog"
version=$(myci-deb-version.sh debian/changelog)

# echo $version
myci-apply-version.sh -v $version $infiles

# clean if needed
rm -rf $tapname

[ -z "$MYCI_GIT_USERNAME" ] && source myci-error.sh "Error: MYCI_GIT_USERNAME is not set";
[ -z "$MYCI_GIT_PASSWORD" ] && source myci-error.sh "Error: MYCI_GIT_PASSWORD is not set";

echo "Cloning tap repo from github"
GIT_ASKPASS=myci-git-askpass.sh git clone https://$MYCI_GIT_USERNAME@github.com/$username/$tapname.git

[ $? != 0 ] && echo "Error: 'git clone' failed" && exit 1;

#echo "infiles = $infiles"

for fin in $infiles
do
	f=$(echo $fin | sed -n -e 's/\(.*\)\.in$/\1/p')
	url=$(awk '/\ *url\ *"http.*\.tar.gz"$/{print $2}' $f | sed -n -e 's/^"\(.*\)"$/\1/p')
#    echo "url = $url"
	filename=$(echo $url | sed -n -e 's/.*\/\([^\/]*\.tar\.gz\)$/\1/p')
	curl -L -O $url
	echo "downloaded $filename"
	sha=($(shasum -a 256 $filename))
	sha=${sha[0]}
	echo "calculated sha256 = $sha"
	sedcommand="s/\$(sha256)/$sha/"
#    echo "sedcommand = $sedcommand"
	sed $sedcommand $f > $f.out
	mv $f.out $f
	cp $f $tapname
	specfilename=$(echo $f | sed -n -e 's/^homebrew\/\(.*\)$/\1/p')

	# do the commit only if there is something to commit, so check that with 'git diff-index'
	(cd $tapname && git add $specfilename && [ ! -z "$(git diff-index HEAD --)" ] && git commit -a -m"version $version of $specfilename")
done

(cd $tapname; GIT_ASKPASS=myci-git-askpass.sh git push)

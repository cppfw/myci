#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to vcpkg github repo.

source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "  $(basename $0) --repo <repo-name> --port-dir <vcpkg-port-dir>"
			echo " "
            echo "Options:"
            echo "  --repo      repository on github, with owner part."
            echo "  --port-dir  path to vcpkg package port directory, the one which contains portfile.cmake."
            echo " "
			echo "GitHub username and access token should be in MYCI_GIT_USERNAME and MYCI_GIT_PASSWORD environment variables."
			echo " "
			echo "Example:"
			echo "  $(basename $0) --repo cppfw/vcpkg-repo --port-dir vcpkg/overlay/myport"
			exit 0
			;;
		--repo)
			shift
			reponame=$1
			;;
		--port-dir)
			shift
			port_dir=$1
			;;
		*)
			error "unknown command line option: $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

echo "Deploying to vcpkg github repo"

[ ! -z "$reponame" ] || error "--repo option is not given";
[ ! -z "$port_dir" ] || error "--port-dir option is not given";

# parse reponame
repo_parts=(${reponame//\// })

owner="${repo_parts[0]}"
repo="${repo_parts[1]}"

echo "owner: ${owner}, repo: ${repo}"

# clean if needed
rm -rf $repo

[ ! -z "$MYCI_GIT_USERNAME" ] || error "MYCI_GIT_USERNAME is not set";
[ ! -z "$MYCI_GIT_PASSWORD" ] || error "MYCI_GIT_PASSWORD is not set";

echo "clone vcpkg repo from github"
GIT_ASKPASS=myci-git-askpass.sh git clone https://$MYCI_GIT_USERNAME@github.com/$owner/$repo.git || error "'git clone' failed";

echo "copy port files to the repo"
mkdir -p $repo/ports
cp -r $port_dir $repo/ports

echo "commit port to the git repo"
cd $repo

git config user.email "unknown@unknown.com"
git config user.name "MYCI vcpkg deploy script"

git add ports/
git commit --message="add new port"

echo "update vcpkg repo versions database"
vcpkg --x-builtin-ports-root=./ports --x-builtin-registry-versions-dir=./versions x-add-version --all --verbose

echo "commit updated versions database"
git add .
git commit --message="update versions database"

echo "push vcpkg repo"
GIT_ASKPASS=myci-git-askpass.sh git push

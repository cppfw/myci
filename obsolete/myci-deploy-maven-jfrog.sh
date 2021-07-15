#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved.
set -eo pipefail

# Script for quick deployment of maven package (.aar and .pom files) to JFrog artifactory maven repo.

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying AAR packages to JFrog artifactory maven repo."
			echo "Usage:"
			echo "	$(basename $0) -d/--domain <jfrog-repo-owner> -r/--repo <jfrog-repo-name> -p/--path <repo-path> <package-aar-filename>"
			echo " "
			echo "Environment variable MYCI_JFROG_USERNAME must be set to JFrog username."
			echo "Environment variable MYCI_JFROG_PASSWORD must be set to JFrog password."
			echo "The AAR file should be named in form <package_name-X.Y.Z.aar>, where X, Y, Z are numbers."
			echo "	Example: myawesomelib-1.3.14.aar"
			echo "The POM file should be named same as AAR file but with .pom suffix and should reside right next to .aar file."
			echo "The repo-path must always be in a form <java-package-path>/<version>, see example below."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -d cppfw -r android -p io/github/cppfw/myawesomelib/1.3.14 myawesomelib-1.3.14.aar"
			exit 0
			;;
		-r)
			shift
			repo=$1
			;;
		--repo)
			shift
			repo=$1
			;;
		-d)
			shift
			domain=$1
			;;
		--domain)
			shift
			domain=$1
			;;
		-a)
			shift
			aar_file=$1
			;;
		--aar)
			shift
			aar_file=$1
			;;
		-p)
			shift
			path=$1
			;;
		--path)
			shift
			path=$1
			;;
		*)
			[ ! -z "$aar_file" ] && source myci-error.sh "more than one file is given, expecting only one";
			aar_file=$1
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_JFROG_USERNAME" ] && source myci-error.sh "MYCI_JFROG_USERNAME is not set";
[ -z "$MYCI_JFROG_PASSWORD" ] && source myci-error.sh "MYCI_JFROG_PASSWORD is not set";

[ -z "$domain" ] && source myci-error.sh "JFrog artifactory domain (--domain) is not given";

[ -z "$repo" ] && source myci-error.sh "repo name (--repo) is not given";

[ -z "$aar_file" ] && source myci-error.sh "AAR file is not given";

[ -z "$path" ] && source myci-error.sh "repo path (--path) is not given";

# make POM filename from AAR filename.
pom_file=${aar_file%.*}.pom

#echo "POM file = $pom_file"

# check POM file exists.
[ ! -f "$pom_file" ] && source myci-error.sh "POM file '$pom_file' not found";

echo "deploy AAR package to JFrog artifactory"

creds="$MYCI_JFROG_USERNAME:$MYCI_JFROG_PASSWORD"

url="https://$domain.jfrog.io/artifactory/$repo/$path"

echo "upload file '$aar_file' to JFrog artifactory"
http_upload_file $creds $url/$(basename $aar_file) $aar_file

echo "upload file '$pom_file' to JFrog artifactory"
http_upload_file $creds $url/$(basename $pom_file) $pom_file

echo "done deploying to JFrog artifactory maven repo"

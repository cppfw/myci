#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment of pacman package (Arch linux package manager system) to jfrog artifactory repo

source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying pacman packages to JFrog artifactory."
			echo "Usage:"
			echo "	$(basename $0) -o/--domain <jfrog-repo-domain> -r/--repo <jfrog-repo-name> -p/--path <repo-path> -d/--database <database-name> <package-filename>"
			echo " "
			echo "Environment variable MYCI_JFROG_USERNAME must be set to JFrog username."
			echo "Environment variable MYCI_JFROG_PASSWORD must be set to JFrog password."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -o cppfw -r msys2 -p mingw/x86_64 -d igagis_mingw64 *.xz"
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
		-o)
			shift
			domain=$1
			;;
		--domain)
			shift
			domain=$1
			;;
		-p)
			shift
			repo_path=$1
			;;
		--path)
			shift
			repo_path=$1
			;;
		-d)
			shift
			db_name=$1
			;;
		--database)
			shift
			db_name=$1
			;;
		*)
			[ ! -z "$package_file" ] && source myci-error.sh "more than one package file is given, expected only one"
			package_file="$1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_JFROG_USERNAME" ] && source myci-error.sh "MYCI_JFROG_USERNAME is not set";
[ -z "$MYCI_JFROG_PASSWORD" ] && source myci-error.sh "MYCI_JFROG_PASSWORD is not set";

creds="$MYCI_JFROG_USERNAME:$MYCI_JFROG_PASSWORD"

[ -z "$domain" ] && source myci-error.sh "JFrog repo domain is not given";

[ -z "$repo" ] && source myci-error.sh "repo name is not given";

[ -z "$repo_path" ] && source myci-error.sh "repo path is not given";

[ -z "$db_name" ] && source myci-error.sh "database name is not given";

[ -z "$package_file" ] && source myci-error.sh "package file is not given";

url="https://$domain.jfrog.io/artifactory/$repo/$repo_path"

echo "deploy pacman package to JFrog artifactory"

# Get latest version of pacman database package

http_download_file $creds $url/$db_name.version $db_name.version

if [ $func_result -eq 200 ]; then
	latest_db_ver=$(cat $db_name.version)
elif [ $func_result -eq 404 ]; then
	echo "no database version file found, perhaps clean repo"
else
	source myci-error.sh "could not get database version"
fi

echo "latest pacman DB version = $latest_db_ver"

if [ -z "$latest_db_ver" ]; then
        new_db_ver=0;
else
	echo "bumping db version"
	new_db_ver=$((latest_db_ver+1));
fi

echo $new_db_ver > $db_name.version

echo "new pacman DB version = $new_db_ver"

# Download current pacman database
uncompressed_db_filename=$db_name.db
db_filename=$uncompressed_db_filename.tar.gz
versioned_db_filename=$db_name-$new_db_ver.db.tar.gz

http_download_file $creds $url/$db_filename $db_filename

if [ $func_result -eq 404 ]; then
	echo "no database found in the repo, perhaps clean repo"
	rm $db_filename # delete the file as it probrably contains the http response payload
elif [ $func_result -ne 200 ]; then
	rm $db_filename
	source myci-error.sh "could not download current pacman database"
fi

echo "add package '$package_file' to the database"
repo-add $db_filename $package_file

ln -f -s $db_filename $versioned_db_filename

package_filename=$(basename $package_file)
# echo "package filename = $package_filename"
package=$(echo "$package_filename" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[^-]*\.pkg\..*/\1/p')
version=$(echo "$package_filename" | sed -n -e"s/^$package-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-[0-9]\+-[^-]*\.pkg\..*/\1/p")

# Upload packages

echo "upload package file '$package_filename'"
http_upload_file $creds $url/$package_filename $package_file

echo "upload versioned pacman database to JFrog artifactory"
http_upload_file $creds $url/$versioned_db_filename $versioned_db_filename

echo "delete old pacman database from JFrog artifactory"
http_delete_file $creds $url/$db_filename
http_delete_file $creds $url/$uncompressed_db_filename
http_delete_file $creds $url/$db_name.files
http_delete_file $creds $url/$db_name.version

echo "upload actual pacman database to JFrog artifactory"
http_upload_file $creds $url/$db_name.version $db_name.version
http_upload_file $creds $url/$db_filename $db_filename
http_upload_file $creds $url/$uncompressed_db_filename $uncompressed_db_filename
http_upload_file $creds $url/$db_name.files $db_name.files

echo "done deploying '$package' version $version to JFrog artifactory"

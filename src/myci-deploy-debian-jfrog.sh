#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# script for quick deployment of debian package to jfrog artifactory debian repo

# source myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) -o/--domain <repo-domain> -r/--repo <repo-name> -c/--component <deb_component> -d/--distro <deb_distribution> <package-filename> [<package-filename> ...]"
			echo " "
			echo "Environment variable MYCI_JFROG_USERNAME must be set to JFrog username."
			echo "Environment variable MYCI_JFROG_PASSWORD must be set to JFrog password."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -o cppfw -r debian -d buster -c main ../myci_0.1.29_all.deb"
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
			domain=$1
			;;
		--domain)
			shift
			domain=$1
			;;
        -c)
			shift
            component=$1
            ;;
		--component)
            shift
            component=$1
            ;;
        -d)
			shift
            distribution=$1
            ;;
		--distro)
            shift
            distribution=$1
            ;;
		*)
			package_files="$package_files $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_JFROG_USERNAME" ] && source myci-error.sh "MYCI_JFROG_USERNAME is not set";
[ -z "$MYCI_JFROG_PASSWORD" ] && source myci-error.sh "MYCI_JFROG_PASSWORD is not set";

[ -z "$domain" ] && source myci-error.sh "JFrog domain is not given";

[ -z "$reponame" ] && source myci-error.sh "repo name is not given";

[ -z "$distribution" ] && source myci-error.sh "debian distribution/s is/are not given";

[ -z "$component" ] && source myci-error.sh "debian component/s is/are not given";

[ -z "$package_files" ] && source myci-error.sh "package files are not given";

# Uploads a file to JFrog artifactory debian repo.
# Usage:
#     upload_to_debian_jfrog <file-to-upload> <repo-domain> <repo-name> <distribution> <component> <arch>
function upload_to_debian_jfrog {
	local file=$1
	local domain=$2
	local repo=$3
	local distro=$4
	local comp=$5
	local arch=$6

	local md5=$(md5sum $file | awk -F" " {'print $1'})
	local sha1=$(sha1sum $file | awk -F" " {'print $1'})

	local res=$(curl --output jfrog.log --silent --write-out "%{http_code}" \
			--user $MYCI_JFROG_USERNAME:$MYCI_JFROG_PASSWORD \
			--upload-file $file \
			--request PUT \
			--header "X-Checksum-Md5:$md5" \
			--header "X-Checksum-Sha1:$sha1" \
			"https://$domain.jfrog.io/artifactory/$repo/pool/$(basename $file);deb.distribution=$distro;deb.component=$comp;deb.architecture=$arch" \
		);

    [ -z "$res" ] && source myci-error.sh "curl failed while uploading to Debian repo on JFrog";
    echo '' >> jfrog.log # to add a newline to the log
	[ $res -ne 201 ] && cat jfrog.log && myci-error.sh "uploading file '$file' to JFrog failed, HTTP code = $res";
    echo "File '$file' uploaded to JFrog."
	return 0;
}

# for each package file upload it to JFrog artifactory
for f in $package_files; do
    architecture=$(echo "$f" | sed -n -e"s/.*_\([^_]*\)\.deb$/\1/p")
	# echo architecture=$architecture
	upload_to_debian_jfrog $f $domain $reponame $distribution $component $architecture
done


#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved.
set -eo pipefail

# Script for quick deployment of maven package (.aar and .pom files) to Sonatype Nexus maven repo.

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Script for deploying AAR packages to Sonatype Nexus maven repo."
			echo "Usage:"
			echo "	$(basename $0) <options> <package-aar-filename>"
			echo " "
			echo "Environment variable MYCI_NEXUS_USERNAME must be set to Nexus username."
			echo "Environment variable MYCI_NEXUS_PASSWORD must be set to Nexus password."
			echo "The AAR file should be named in form <package_name-X.Y.Z.aar>, where X, Y, Z are numbers."
			echo "	Example: myawesomelib-1.3.14.aar"
			echo "The POM file should be named same as AAR file but with .pom suffix and should reside right next to .aar file."
            echo ""
            echo "options:"
            echo "  --base-url <url>    Nexus API base url"
            echo "  --repo <repo-name>  Repository name."
			exit 0
			;;
        --base-url)
            shift
            base_url=$1
            ;;
		--repo)
			shift
			repo=$1
			;;
		*)
			[ -z "$aar_file" ] || error "more than one file is given, expecting only one";
			aar_file=$1
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ ! -z "$MYCI_NEXUS_USERNAME" ] || error "MYCI_NEXUS_USERNAME is not set";
[ ! -z "$MYCI_NEXUS_PASSWORD" ] || error "MYCI_NEXUS_PASSWORD is not set";

[ ! -z "$base_url" ] || error "missing required option: --base-url";
[ ! -z "$repo" ] || error "missing required option: --repo";

[ ! -z "$aar_file" ] || error "AAR file is not given";

# make POM filename from AAR filename.
pom_file=${aar_file%.*}.pom

#echo "POM file = $pom_file"

# check files exists.
[ -f "$aar_file" ] || error "AAR file '$aar_file' not found";
[ -f "$pom_file" ] || error "POM file '$pom_file' not found";

echo "deploy AAR package to Nexus maven repo"

MYCI_CREDENTIALS="$MYCI_NEXUS_USERNAME:$MYCI_NEXUS_PASSWORD"

url="${base_url}/service/rest/v1/components?repository=$repo"

echo "upload '$aar_file' and '$pom_file' files"
make_curl_req \
        POST \
        $url \
        204 \
        form \
        "maven2.generate-pom=false" \
        "maven2.asset1=@$pom_file" \
        "maven2.asset1.extension=pom" \
        "maven2.asset2=@$aar_file;type=application/java-archive" \
        "maven2.asset2.extension=jar"

echo "done deploying to Nexus maven repo"

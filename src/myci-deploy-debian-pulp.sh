#!/bin/bash

#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# script for quick deployment of debian package to pulp debian repo

script_dir=$(dirname $0)

function error {
    local message=$1
    source $script_dir/myci-error.sh "$message"
}

function pulp {
    $script_dir/myci-pulp.sh --domain $domain --type deb $@
}

domain=$MYCI_PULP_DOMAIN

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) <options> <package-filename> [<package-filename> ...]"
			echo " "
			echo "Environment variable MYCI_PULP_USERNAME must be set to Pulp username."
			echo "Environment variable MYCI_PULP_PASSWORD must be set to Pulp password."
            echo "Environment variable MYCI_PULP_DOMAIN can be set to avoid supplying --domain command line argument."
            echo ""
            echo "options:"
            echo "  --domain <http-domain>    Pulp domain. E.g. http://gagis.hopto.org. Overrides MYCI_PULP_DOMAIN value."
            echo "  --subdomain <subdoman>"
			echo "  --repo <repo-name>"
            echo "  --distro <debian-distro-name>"
            echo ""
			exit 0
			;;
		--repo)
			shift
			repo_name=$1
			;;
		--domain)
			shift
			domain=$1
			;;
        --subdomain)
			shift
			subdomain=$1
			;;
		--distro)
            shift
            distro=$1
            ;;
		*)
			package_files="$package_files $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ -z "$MYCI_PULP_USERNAME" ] && error "MYCI_PULP_USERNAME is not set";
[ -z "$MYCI_PULP_PASSWORD" ] && error "MYCI_PULP_PASSWORD is not set";

[ -z "$domain" ] && error "--domain is not given";
[ -z "$subdomain" ] && error "--subdomain is not given";

[ -z "$repo_name" ] && error "--repo is not given";

[ -z "$distro" ] && error "--distro not given";

[ -z "$package_files" ] && error "package files are not given";

pulp_repo_name=${subdomain}_${repo_name}_${distro}

# check if the repo exists
if [ -z "$(pulp repo list --name $pulp_repo_name)" ]; then
    echo "repo $pulp_repo_name does not exist, create the repo..."
    pulp repo create --name $pulp_repo_name
    echo "create distribution"
    pulp dist create --repo $pulp_repo_name --name $pulp_repo_name --base-path ${subdomain}/${repo_name}/${distro}
    # echo "content URL:"
    # pulp dist list --name $pulp_repo_name --full | jq -r -M '.results[0].base_url'
fi

# for each package file upload it to pulp repo
for f in $package_files; do
    echo "upload '$f'..."
    pulp package upload --repo $pulp_repo_name --file $f
done

echo "Publish uploaded files..."
pulp publ create --repo $pulp_repo_name

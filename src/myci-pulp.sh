#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

domain=$MYCI_PULP_DOMAIN

function set_repo_path {
    case $repo_type in
        deb)
            repo_path=deb/apt/
            ;;
        *)
            source myci-error.sh "unknown value of --type argument: $type";
            ;;
    esac
}

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) [--help] [--domain <pulp-domain>] [--trusted] [--type <repo-type>] <command> [<command-options> ...]"
			echo " "
			echo "Environment variable MYCI_PULP_USERNAME must be set to Pulp username."
			echo "Environment variable MYCI_PULP_PASSWORD must be set to Pulp password."
            echo "If --domain argument is not given, then environment variable MYCI_PULP_DOMAIN must be set to Pulp domain."
            echo " "
            echo "options:"
            echo "  --trusted  Allow self-signed certificate."
            echo "  --type     Repository type: deb, maven, file."
            echo " "
            echo "create-repo:"
            echo "  --name     Repository name."
			echo " "
			echo "Example:"
			echo "	$(basename $0) -o cppfw -r debian -d buster -c main ../myci_0.1.29_all.deb"
			exit 0
			;;
        --trusted)
            trusted=-k;
            ;;
		--domain)
			shift
			domain=$1
			;;
        --type)
            shift
            repo_type=$1;
            set_repo_path;
            ;;
		*)
            command=$1
			;;
	esac
	[[ $# > 0 ]] && shift;

    if [ ! -z "$command" ]; then break; fi
done

[ -z "$MYCI_PULP_USERNAME" ] && source myci-error.sh "MYCI_PULP_USERNAME is not set";
[ -z "$MYCI_PULP_PASSWORD" ] && source myci-error.sh "MYCI_PULP_PASSWORD is not set";

[ -z "$domain" ] && source myci-error.sh "MYCI_PULP_DOMAIN is not set and --domain argument is not given";

credentials=$MYCI_PULP_USERNAME:$MYCI_PULP_PASSWORD

pulp_api_url=https://$domain/pulp/api/v3/

function check_type_argument {
    [ -z "$repo_type" ] && source myci-error.sh "--type argument is not given";
    return 0;
}

function list_repos {
    curl \
            --location \
            $trusted \
            --user $credentials \
            --request GET \
            ${pulp_api_url}repositories/$repo_path
}

function create_deb_repo {
    while [[ $# > 0 ]] ; do
        case $1 in
            --name)
                shift
                local repo_name=$1;
                ;;
            *)
                source myci-error.sh "unknown arguemnt to create-repo command: $1";
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ -z "$repo_name" ] && source myci-error.sh "--name argument is not given";

    curl \
            --location \
            $trusted \
            --user $credentials \
            --data "{ \"pulp_labels\":{}, \"name\":\"$repo_name\", \"description\":\"debian repo\", \"retained_versions\": 2, \"remote\":null}" \
            --header "Content-Type: application/json" \
            --request POST \
            ${pulp_api_url}repositories/$repo_path
}

function delete_deb_repo {
    echo TODO:
}

case $command in
    list-repos)
        check_type_argument;
        list_repos $@
        ;;
    create-repo)
        check_type_argument;
        case $repo_type in
            deb)
                create_deb_repo $@;
                ;;
            *)
                source myci-error.sh "unknown --type argument value"
                ;;
        esac
        ;;
    delete-repo)
        check_type_argument;
        case $repo_type in
            deb)
                delete_deb_repo $@;
                ;;
            *)
                source myci-error.sh "unknown --type argument value"
                ;;
        esac
        ;;
    *)
        source myci-error.sh "unknown command: $command";
        ;;
esac

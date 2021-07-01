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
			echo "	$(basename $0) [--help] [<options>] <command> [<command-options>] [...]"
			echo " "
			echo "Environment variable MYCI_PULP_USERNAME must be set to Pulp username."
			echo "Environment variable MYCI_PULP_PASSWORD must be set to Pulp password."
            echo "If --domain argument is not given, then environment variable MYCI_PULP_DOMAIN must be set to Pulp domain."
            echo " "
            echo "options:"
            echo "  --help    Show this help text and do nothing."
            echo "  --domain <pulp-domain>    Specify pulp server domain name. This overrides MYCI_PULP_DOMAIN env var value."
            echo "  --trusted  Allow self-signed certificate."
            echo "  --type <repo-type>    Repository type: deb, maven, file."
            echo " "
            echo "commands:"
            echo "  repo    Operations on repositories."
			echo " "
            echo "command-options:"
            echo "  --help    Show help text on specific command and do nothing."
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
            if [ "$1" == "repo" ] || [ "$1" == "list-repos" ]; then
                command=$1
            else
                source myci-error.sh "unknown command or argument: $1"
            fi
			;;
	esac
	[[ $# > 0 ]] && shift;

    if [ ! -z "$command" ]; then break; fi
done

[ -z "$MYCI_PULP_USERNAME" ] && source myci-error.sh "MYCI_PULP_USERNAME is not set";
[ -z "$MYCI_PULP_PASSWORD" ] && source myci-error.sh "MYCI_PULP_PASSWORD is not set";

[ -z "$domain" ] && source myci-error.sh "MYCI_PULP_DOMAIN is not set and --domain argument is not given";

credentials=$MYCI_PULP_USERNAME:$MYCI_PULP_PASSWORD

pulp_url=https://$domain

pulp_api_url=$pulp_url/pulp/api/v3/

function check_type_argument {
    [ -z "$repo_type" ] && source myci-error.sh "--type argument is not given";
    return 0;
}

function get_repos {
    local tmpfile=$(mktemp)
    trap "rm -f $tmpfile" 0 2 3 9 15
    # this api request is same for all repo types
    local res=($(curl \
            --location \
            --silent \
            --output $tmpfile \
            --write-out "%{http_code} %{ssl_verify_result}" \
            $trusted \
            --user $credentials \
            --request GET \
            ${pulp_api_url}repositories/$repo_path \
        ));
    func_res=$(cat $tmpfile)
    [ ! -z "$trusted" ] || [ ${res[1]} -eq 0 ] || source myci-error.sh "SSL verification failed, ssl_verify_result = ${res[1]}, func_res = $func_res";
    if [ ${res[0]} -ne 200 ]; then
        source myci-error.sh "getting repos failed, HTTP code = ${res[0]}, func_res = $func_res"
    fi
}

function list_repos {
    get_repos
    echo $func_res | jq; # '.results[].name'
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

function handle_repo_command {
    check_type_argument;
    
    while [[ $# > 0 ]] ; do
        case $1 in
            --name)
                shift
                repo_name=$1;
                ;;
            *)
                [ -z "$subcommand" ] || source myci-error.sh "more than one subcommand given: $1";

                if [ "$1" == "list" ] || [ "$1" == "create" ]; then
                    subcommand=$1
                else
                    source myci-error.sh "unknown arguemnt to repo command: $1";
                fi
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    # TODO:
}

case $command in
    repo)
        handle_repo_sommand;
        ;;
    list-repos)
        check_type_argument;
        list_repos $@
        ;;
    *)
        source myci-error.sh "unknown command: $command";
        ;;
esac

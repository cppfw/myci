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
            trusted=--insecure;
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

function check_name_argument {
    [ -z "$name" ] && source myci-error.sh "--name argument is not given";
    return 0;
}

function make_curl_req {
    local method=$1
    local url=$2
    local expected_http_code=$3

    local data_arg=
    
    case $method in
        POST)
            local content_type=$4
            local data=$5
            case $content_type in
                json)
                    data_arg="--data"
                    local content_type_header="Content-Type: application/json"
                    ;;
                *)
                    source myci-error.sh "unknown content type: $content_type"
            esac
            ;;
    esac

    # echo "content_type_header = $content_type_header"
    # echo "data_arg = $data_arg"

    local tmpfile=$(mktemp)
    trap "rm -f $tmpfile" 0 2 3 9 15
    
    local curl_cmd=(curl --location --silent $trusted --output $tmpfile \
            --write-out "%{http_code} %{ssl_verify_result}" \
            --user $credentials \
            --request $method \
            $url)
    
    if [ ! -z "$data_arg" ]; then
        curl_cmd+=(--header "$content_type_header")
        curl_cmd+=($data_arg "$data")
    fi

    # echo "curl_cmd ="; printf '%s\n' "${curl_cmd[@]}"

    local curl_res=($("${curl_cmd[@]}" || true));
    func_res=$(cat $tmpfile)

    # echo "curl_res[0] = ${curl_res[0]}"

    if [ -z "$trusted" ] && [ ${curl_res[1]} -ne 0 ]; then
        source myci-error.sh "SSL verification failed, ssl_verify_result = ${curl_res[1]}, func_res = $func_res";
    fi

    if [ ${curl_res[0]} -ne $expected_http_code ]; then
        source myci-error.sh "request failed, HTTP code = ${curl_res[0]} (expected $expected_http_code), func_res = $func_res"
    fi
}

function get_repos {
    make_curl_req GET ${pulp_api_url}repositories/$repo_path 200
}

function list_repos {
    get_repos
    echo $func_res | jq -r '.results[].name'
}

function list_repos_full {
    get_repos
    echo $func_res | jq
}


function get_repo_href {
    local repo_name=$1
    make_curl_req GET ${pulp_api_url}repositories/$repo_path?name=$repo_name 200
    func_res=$(echo $func_res | jq -r '.results[].pulp_href')
}

function create_deb_repo {
    check_name_argument

    make_curl_req \
            POST \
            ${pulp_api_url}repositories/$repo_path \
            201 \
            json \
            "{ \
              \"pulp_labels\":{}, \
              \"name\":\"$name\", \
              \"description\":\"debian repo\", \
              \"retained_versions\":2, \
              \"remote\":null \
            }"
}

function delete_deb_repo {
    check_name_argument

    get_repo_href $name

    [ ! -z "$func_res" ] || source myci-error.sh "repository '$name' not found"

    # echo $func_res

    make_curl_req DELETE ${pulp_url}$func_res 202

    echo "repository '$name' deleted"
}

function check_subcommand {
    [ ! -z "$subcommand" ] || source myci-error.sh "subcommand expected right after command";
}

function handle_repo_command {
    check_type_argument;
    
    while [[ $# > 0 ]] ; do
        case $1 in
            --name)
                check_subcommand
                shift
                name=$1
                ;;
            *)
                [ -z "$subcommand" ] || source myci-error.sh "more than one subcommand given: $1";

                subcommand=$1
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    case $subcommand in
        list)
            list_repos
            ;;
        list-full)
            list_repos_full
            ;;
        create)
            create_${repo_type}_repo
            ;;
        delete)
            delete_${repo_type}_repo
            ;;
        *)
            source myci-error.sh "unknown argument to repo command: $subcommand"
            ;;
    esac
}

case $command in
    repo)
        handle_repo_command $@
        ;;
    *)
        source myci-error.sh "unknown command: $command";
        ;;
esac

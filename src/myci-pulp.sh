#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

domain=$MYCI_PULP_DOMAIN

function set_repo_path {
    case $repo_type in
        deb)
            repo_path=deb/apt/
            ;;
        docker)
            repo_path=container/container/
            ;;
        *)
            source myci-error.sh "unknown value of --type argument: $type";
            ;;
    esac
}

declare -A commands=( \
        [repo]=1 \
        [task]=1 \
        [package]=1 \
    )

declare -A repo_subcommands=( \
        [list]=1 \
        [create]=1 \
        [delete]=1 \
    )

declare -A task_subcommands=( \
        [list]=1 \
    )

declare -A package_subcommands=( \
        [list]=1 \
    )

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "Usage:"
			echo "	$(basename $0) [--help] [<options>] <command> <subcommand> [--help] [...]"
			echo " "
			echo "Environment variable MYCI_PULP_USERNAME must be set to Pulp username."
			echo "Environment variable MYCI_PULP_PASSWORD must be set to Pulp password."
            echo "If --domain argument is not given, then environment variable MYCI_PULP_DOMAIN must be set to Pulp domain."
            echo " "
            echo "options:"
            echo "  --help                  Show this help text and do nothing."
            echo "  --domain <pulp-domain>  Specify pulp server domain name. This overrides MYCI_PULP_DOMAIN env var value."
            echo "  --trusted               Allow self-signed certificate."
            echo "  --type <repo-type>      Repository type: deb, maven, file, rpm, docker."
            echo " "
            echo "commands:"
            for i in "${!commands[@]}"; do {
                echo "  $i"
                eval "subcommands=\"\${!${i}_subcommands[@]}\""
                for j in $subcommands; do
                echo "    - $j"
                done
            } done
            echo " "
			echo "Example:"
			echo "	TODO: $(basename $0) -o cppfw -r debian -d buster -c main ../myci_0.1.29_all.deb"
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
            command=$1
            # echo "command handler = ${commands[$command]}"
            [ ! -z "${commands[$command]}" ] || source myci-error.sh "unknown command: $command"
			;;
	esac
	[[ $# > 0 ]] && shift;

    if [ ! -z "$command" ]; then break; fi
done

subcommand=$1
shift
[ ! -z "$subcommand" ] || source myci-error.sh "subcommand is not given"
eval "subcommand_valid=\${${command}_subcommands[$subcommand]}"
[ ! -z "$subcommand_valid" ] || source myci-error.sh "unknown subcommand: $subcommand"

[ -z "$MYCI_PULP_USERNAME" ] && source myci-error.sh "MYCI_PULP_USERNAME is not set";
[ -z "$MYCI_PULP_PASSWORD" ] && source myci-error.sh "MYCI_PULP_PASSWORD is not set";

[ -z "$domain" ] && source myci-error.sh "MYCI_PULP_DOMAIN is not set and --domain argument is not given";

MYCI_CREDENTIALS=$MYCI_PULP_USERNAME:$MYCI_PULP_PASSWORD

pulp_url=https://$domain

pulp_api_url=$pulp_url/pulp/api/v3/

function check_type_argument {
    [ -z "$repo_type" ] && source myci-error.sh "--type argument is not given";
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

    local tmpfile=$(mktemp)

    # delete temporary file on exit or signal caught
    trap "rm -f $tmpfile" 0 2 3 9 15
    
    local curl_cmd=(curl --location --silent $trusted --output $tmpfile \
            --write-out "%{http_code} %{ssl_verify_result}" \
            --request $method \
            $url)

    if [ ! -z "$MYCI_CREDENTIALS" ]; then
        curl_cmd+=(--user "$MYCI_CREDENTIALS")
    fi

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

function handle_repo_list_command {
    local jq_cmd=(jq -r '.results[].name')

    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help  Show this help text and do nothing."
                echo "  --full  Show full info."
                exit 0
                ;;
            --full)
                jq_cmd=(jq)
                ;;
            *)
                source myci-error.sh "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    get_repos
    echo $func_res | "${jq_cmd[@]}"
}

function get_repo_href {
    local repo_name=$1
    make_curl_req GET ${pulp_api_url}repositories/$repo_path?name=$repo_name 200
    func_res=$(echo $func_res | jq -r '.results[].pulp_href')
}

function handle_deb_repo_create_command {
    local name=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help              Show this help text and do nothing."
                echo "  --name <repo_name>  Repository name."
                exit 0
                ;;
            --name)
                shift
                name=$1
                ;;
            *)
                source myci-error.sh "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$name" ] || source myci-error.sh "missing required argument: --name"

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
    
    echo "repository '$name' created"
}

function handle_deb_repo_delete_command {
    local name=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help              Show this help text and do nothing."
                echo "  --name <repo_name>  Repository name."
                exit 0
                ;;
            --name)
                shift
                name=$1
                ;;
            *)
                source myci-error.sh "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$name" ] || source myci-error.sh "missing required argument: --name"

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
                # [ -z "$subcommand" ] || source myci-error.sh "more than one subcommand given: $1";

                # subcommand=$1
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
            source myci-error.sh "unknown subcommand: $subcommand"
            ;;
    esac
}

function list_tasks {
    make_curl_req GET ${pulp_api_url}tasks/ 200
    echo $func_res | jq
}

function get_task {
    local task_href=$1

    make_curl_req GET ${pulp_url}$task_href 200
}

function handle_task_list_command {
    make_curl_req GET ${pulp_api_url}tasks/ 200
    echo $func_res | jq
}

function handle_package_list_command {
    echo TODO
}

function handle_repo_create_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_repo_delete_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

handle_${command}_${subcommand}_command $@

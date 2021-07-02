#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

domain=$MYCI_PULP_DOMAIN

function set_repo_path {
    case $repo_type in
        deb)
            repo_url_path=deb/apt/
            package_url_path=content/deb/packages/
            ;;
        docker)
            repo_url_path=container/container/
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
        [upload]=1 \
        [delete]=1 \
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
                form)
                    data_arg="--form"
                    local content_type_header="Content-Type: multipart/form-data"
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
    make_curl_req GET ${pulp_api_url}repositories/$repo_url_path 200
}

function get_repo {
    local repo_name=$1
    make_curl_req GET ${pulp_api_url}repositories/$repo_url_path?name=$repo_name 200
}

function get_repo_href {
    local repo_name=$1
    get_repo $repo_name
    func_res=$(echo $func_res | jq -r '.results[].pulp_href')
}

function get_repo_latest_version_href {
    local repo_name=$1
    get_repo $repo_name
    func_res=$(echo $func_res | jq -r '.results[].latest_version_href')
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

function handle_repo_create_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_repo_delete_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
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
            ${pulp_api_url}repositories/$repo_url_path \
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

function get_task {
    local task_href=$1

    make_curl_req GET ${pulp_url}$task_href 200
}

function wait_task_finish {
    local task_href=$1
    local timeout_sec=$2

    [ ! -z "$task_href" ] || source myci-error.sh "ASSERT(false): wait_task_finish needs task href"

    if [ -z "$timeout_sec" ]; then
        timeout_sec=20
    fi

    echo "wait for task to finish"

    while [[ $timeout_sec > 0 ]]; do
        get_task $task_href
        # echo $func_res | jq
        local state=$(echo $func_res | jq -r ".state")

        if [ "$state" != "running" ]; then
            break
        fi

        timeout_sec=$((timeout_sec-1))
        sleep 1
    done

    [ "$state" != "running" ] || source myci-error.sh "timeout hit while waiting for task to finish"

    case $state in
        completed)
            echo "task completed"
            ;;
        failed)
            source myci-error.sh "task failed: $(echo $func_res | jq -r '.error.description')"
            ;;
        *)
            source myci-error.sh "ASSERT(false): unknown task state encountered: $state"
            ;;
    esac
}

function handle_task_list_command {
    make_curl_req GET ${pulp_api_url}tasks/ 200
    echo $func_res | jq
}

function handle_package_list_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function get_deb_package {
    local file_name=$1

    local pkg=($(echo $file_name | sed -E -e 's/^([^_]*)_([^_]*)_([^_]*).deb$/\1 \2 \3/g'))

    [[ ${#pkg[@]} == 3 ]] || source myci-error.sh "malformed debian package name format: $file_name"

    make_curl_req GET "${pulp_api_url}${package_url_path}?package=${pkg[0]}&version=${pkg[1]}&architecture=${pkg[2]}" 200

    local num_found=$(echo $func_res | jq -r '.count')

    case $num_found in
        0)
            func_res=
            ;;
        1)
            func_res=$(echo $func_res | jq -r '.results[0]')
            ;;
        *)
            source myci-error.sh "ASSERT(false) more than one package found"
            ;;
    esac
}

function handle_deb_package_list_command {
    local repo_name=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help                      Show this help text and do nothing."
                echo "  --repo <repository-name>    Repository to packages of."
                exit 0
                ;;
            --repo)
                shift
                repo_name=$1
                ;;
            *)
                source myci-error.sh "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    local args=

    # TODO: debug
    if [ ! -z "$repo_name" ]; then
        get_repo_latest_version_href $repo_name
        args="$args&repository_version=$func_res"
    fi

    if [ ! -z "$args" ]; then
        args="?$args"
    fi

    make_curl_req GET "${pulp_api_url}${package_url_path}${args}" 200
    echo $func_res | jq
}

function handle_package_upload_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_deb_package_upload_command {
    local file_name=
    local repo_name=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help                      Show this help text and do nothing."
                echo "  --file <package-file-name>  Package file to upload."
                echo "  --repo <repository-name>    Repository to upload the file to."
                exit 0
                ;;
            --file)
                shift
                file_name=$1
                ;;
            --repo)
                shift
                repo_name=$1
                ;;
            *)
                source myci-error.sh "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$file_name" ] || source myci-error.sh "missing required argument: --file"
    [ ! -z "$repo_name" ] || source myci-error.sh "missing required argument: --repo"

    get_deb_package $(basename $file_name)
    # echo $func_res

    get_repo_href $repo_name
    local repo_href=$func_res
    # echo "repo_href = $repo_href"

    # get_repo_latest_version_href $repo_name

    [ ! -z "$repo_href" ] || source myci-error.sh "repository '$repo_name' not found"

    make_curl_req \
            POST \
            ${pulp_api_url}$package_url_path \
            202 \
            form \
            "file=@$file_name"
            # "file=@$file_name;repository=$pulp_url$repo_href"

    local task_href=$(echo $func_res | jq -r '.task')
    # echo "task_href = $task_href"
    wait_task_finish $task_href

    local package_href=$(echo $func_res | jq -r '.created_resources[0]')
    echo "package_href = $package_href"
    [ ! -a "$package_href" ] || source myci-error.sh "ASSERT(false): handle_deb_package_upload_command: package_href is empty"

    # add package to the repo

    make_curl_req \
            POST \
            ${pupl_url}${repo_href}modify/ \
            202 \
            json \
            "{ \
              \"add_content_units\":[\"${pupl_url}$package_href\"], \
            }"
    
    local task_href=$(echo $func_res | jq -r '.task')
    echo "task_href = $task_href"
    wait_task_finish $task_href

    echo "package '$(basename $file_name)' uploaded to '$repo_name' repository"
}

handle_${command}_${subcommand}_command $@

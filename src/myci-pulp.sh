#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir=$(dirname $0)

function error {
    local message=$1
    source $script_dir/myci-error.sh "$message"
}

function warning {
    local message=$1
    source $script_dir/myci-warning.sh "$message"
}

domain=$MYCI_PULP_DOMAIN

function set_repo_path {
    case $repo_type in
        deb)
            pulp_api_url_suffix=deb/apt/
            package_url_path=content/deb/packages/
            ;;
        docker)
            pulp_api_url_suffix=container/container/
            ;;
        *)
            error "unknown value of --type argument: $type";
            ;;
    esac
}

declare -A commands=( \
        [repo]=1 \
        [task]=1 \
        [package]=1 \
        [orphans]=1 \
        [dist]=1 \
        [publ]=1 \
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

declare -A orphans_subcommands=( \
        [delete]=1 \
    )

declare -A dist_subcommands=( \
        [list]=1 \
        [create]=1 \
        [delete]=1 \
    )

declare -A publ_subcommands=( \
        [list]=1 \
        [create]=1 \
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
            echo "  --domain <pulp-domain>  Specify pulp server domain name (e.g. https://mypulp.org). This overrides MYCI_PULP_DOMAIN env var value."
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
            [ ! -z "${commands[$command]}" ] || error "unknown command: $command"
			;;
	esac
	[[ $# > 0 ]] && shift;

    if [ ! -z "$command" ]; then break; fi
done

subcommand=$1
shift
[ ! -z "$subcommand" ] || error "subcommand is not given"
eval "subcommand_valid=\${${command}_subcommands[$subcommand]}"
[ ! -z "$subcommand_valid" ] || error "unknown subcommand: $subcommand"

[ -z "$MYCI_PULP_USERNAME" ] && error "MYCI_PULP_USERNAME is not set";
[ -z "$MYCI_PULP_PASSWORD" ] && error "MYCI_PULP_PASSWORD is not set";

[ -z "$domain" ] && error "MYCI_PULP_DOMAIN is not set and --domain argument is not given";

MYCI_CREDENTIALS=$MYCI_PULP_USERNAME:$MYCI_PULP_PASSWORD

pulp_api_url=$domain/pulp/api/v3/

function check_type_argument {
    [ -z "$repo_type" ] && error "--type argument is not given";
    return 0;
}

function make_curl_req {
    local method=$1
    shift
    local url=$1
    shift
    local expected_http_code=$1
    shift

    local data_arg=
    
    case $method in
        POST)
            local content_type=$1
            shift
            local data=("$@")
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
                    error "unknown content type: $content_type"
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
        for i in "${data[@]}"; do
            curl_cmd+=($data_arg "$i")
        done
    fi

    # echo "curl_cmd ="; printf '%s\n' "${curl_cmd[@]}"

    local curl_res=($("${curl_cmd[@]}" || true));
    func_res=$(cat $tmpfile)

    # echo "curl_res[0] = ${curl_res[0]}"

    if [ -z "$trusted" ] && [ ${curl_res[1]} -ne 0 ]; then
        error "SSL verification failed, ssl_verify_result = ${curl_res[1]}, func_res = $func_res";
    fi

    if [ ${curl_res[0]} -ne $expected_http_code ]; then
        error "request failed, HTTP code = ${curl_res[0]} (expected $expected_http_code), func_res = $func_res"
    fi
}

function get_repos {
    make_curl_req GET ${pulp_api_url}repositories/$pulp_api_url_suffix 200
}

function get_repo {
    local repo_name=$1
    make_curl_req GET ${pulp_api_url}repositories/$pulp_api_url_suffix?name=$repo_name 200

    if [[ $(echo $func_res | jq -r '.count') == 0 ]]; then
        error "repository '$repo_name' not found"
    fi

    func_res=$(echo $func_res | jq -r '.results[0]')
}

function get_repo_href {
    local repo_name=$1
    get_repo $repo_name
    func_res=$(echo $func_res | jq -r '.pulp_href')
}

function get_repo_latest_version_href {
    local repo_name=$1
    get_repo $repo_name
    func_res=$(echo $func_res | jq -r '.latest_version_href')
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
                error "unknown command line argument: $1"
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
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$name" ] || error "missing required argument: --name"

    make_curl_req \
            POST \
            ${pulp_api_url}repositories/$pulp_api_url_suffix \
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
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$name" ] || error "missing required argument: --name"

    get_repo_href $name

    [ ! -z "$func_res" ] || error "repository '$name' not found"

    # echo $func_res

    make_curl_req DELETE ${domain}$func_res 202

    echo "repository '$name' deleted"
}

function get_task {
    local task_href=$1

    make_curl_req GET ${domain}$task_href 200
}

function wait_task_finish {
    local task_href=$1
    local timeout_sec=$2

    [ ! -z "$task_href" ] || error "ASSERT(false): wait_task_finish needs task href"

    if [ -z "$timeout_sec" ]; then
        timeout_sec=20
    fi

    echo "wait for task to finish"

    while [[ $timeout_sec > 0 ]]; do
        echo "poll task status $timeout_sec"
        get_task $task_href
        # echo $func_res | jq
        local state=$(echo $func_res | jq -r ".state")

        if [ "$state" != "running" ]; then
            break
        fi

        timeout_sec=$((timeout_sec-1))
        sleep 1
    done

    [ "$state" != "running" ] || error "timeout hit while waiting for task to finish"

    case $state in
        completed)
            echo "task completed"
            ;;
        failed)
            error "task failed: $(echo $func_res | jq -r '.error.description')"
            ;;
        *)
            error "ASSERT(false): unknown task state encountered: $state"
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
    local repo_name=$2

    local pkg=($(echo $file_name | sed -E -e 's/^([^_]*)_([^_]*)_([^_]*).deb$/\1 \2 \3/g'))

    [[ ${#pkg[@]} == 3 ]] || error "malformed debian package name format: $file_name"

    local repo_filter=
    if [ ! -z "$repo_name" ]; then
        get_repo_latest_version_href $repo_name
        repo_filter="&repository_version=$func_res"
    fi

    make_curl_req GET "${pulp_api_url}${package_url_path}?package=${pkg[0]}&version=${pkg[1]}&architecture=${pkg[2]}${repo_filter}" 200

    local num_found=$(echo $func_res | jq -r '.count')

    case $num_found in
        0)
            func_res=
            ;;
        1)
            func_res=$(echo $func_res | jq -r '.results[0]')
            ;;
        *)
            error "ASSERT(false) more than one package found"
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
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    local args=

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
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$file_name" ] || error "missing required argument: --file"
    [ ! -z "$repo_name" ] || error "missing required argument: --repo"

    local base_file_name=$(basename $file_name)

    get_deb_package $base_file_name $repo_name
    if [ ! -z "$func_res" ]; then
        warning "package '$base_file_name' already exists in repo '$repo_name', doing nothing"
        exit 0
    fi

    get_repo_href $repo_name
    local repo_href=$func_res
    # echo "repo_href = $repo_href"

    # get_repo_latest_version_href $repo_name

    [ ! -z "$repo_href" ] || error "repository '$repo_name' not found"

    make_curl_req \
            POST \
            ${pulp_api_url}$package_url_path \
            202 \
            form \
            "file=@$file_name" \
            "relative_path=pool/$repo_name/${base_file_name:0:1}/$base_file_name" \
            "repository=$domain$repo_href"
    # echo "resp = $func_res"

    local task_href=$(echo $func_res | jq -r '.task')
    # echo "task_href = $task_href"
    wait_task_finish $task_href

    # add package to repository is not needed as it is added right away in the previous request
    # TODO: remove commented code

    # local package_href=$(echo $func_res | jq -r '.created_resources[0]')
    # # echo "package_href = $package_href"
    # [ ! -a "$package_href" ] || error "ASSERT(false): handle_deb_package_upload_command: package_href is empty"

    # # add package to the repo

    # make_curl_req \
    #         POST \
    #         ${domain}${repo_href}modify/ \
    #         202 \
    #         json \
    #         "{\"add_content_units\":[\"${domain}$package_href\"]}"
    # # echo $func_res
    
    # local task_href=$(echo $func_res | jq -r '.task')
    # # echo "task_href = $task_href"
    # wait_task_finish $task_href

    echo "package '$base_file_name' uploaded to '$repo_name' repository"
}

function handle_orphans_delete_command {
    make_curl_req DELETE ${pulp_api_url}orphans/ 202
    local task_href=$(echo $func_res | jq -r '.task')
    # echo "task_href = $task_href"
    wait_task_finish $task_href
    echo "orphaned content deleted"
}

function handle_dist_list_command {
    local jq_cmd=(jq -r '.results[].name')

    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help    Show this help text and do nothing."
                echo "  --full    Show full info."
                exit 0
                ;;
            --full)
                jq_cmd=(jq)
                ;;
            *)
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    make_curl_req \
            GET \
            ${pulp_api_url}distributions/${pulp_api_url_suffix} \
            200
    
    echo $func_res | "${jq_cmd[@]}"
}

function get_dist {
    local name=$1
    make_curl_req \
            GET \
            ${pulp_api_url}distributions/${pulp_api_url_suffix}?name=${name} \
            200
    local num_dists=$(echo $func_res | jq -r '.count')

    case $num_dists in
        0)
            error "distribution '$dist_name' not found"
            ;;
        1)
            ;;
        *)
            error "ASSERT(false): more than one distribution with name '$dist_name' found, func_res = $func_res"
            ;;
    esac
    
    func_res=$(echo $func_res | jq -r '.results[0]')
}

function handle_dist_create_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_deb_dist_create_command {
    local name=
    local repo_name=
    local base_path=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help         Show this help text and do nothing."
                echo "  --name         Distribution name."
                echo "  --repo         Repository name to serve via distribution."
                echo "  --base-path    Distribution base path."
                exit 0
                ;;
            --name)
                shift
                name=$1
                ;;
            --repo)
                shift
                repo_name=$1
                ;;
            --base-path)
                shift
                base_path=$1
                ;;
            *)
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$name" ] || error "missing required argument: --name"
    [ ! -z "$repo_name" ] || error "missing required argument: --repo"
    [ ! -z "$base_path" ] || error "missing required argument: --base-path"

    get_repo_href $repo_name
    local repo_href=$func_res

    make_curl_req \
            POST \
            ${pulp_api_url}distributions/${pulp_api_url_suffix} \
            202 \
            json \
            "{\"base_path\":\"$base_path\",\"name\":\"$name\",\"repository\":\"${domain}${repo_href}\"}"

    local task_href=$(echo $func_res | jq -r '.task')
    # echo "task_href = $task_href"
    wait_task_finish $task_href

    echo "distribution '$name' created"
}

function handle_publ_list_command {
    make_curl_req \
            GET \
            ${pulp_api_url}publications/${pulp_api_url_suffix} \
            200
    echo $func_res | jq
}

function handle_publ_create_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_deb_publ_create_command {
    local repo_name=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help    Show this help text and do nothing."
                echo "  --repo    Repository name to publish."
                exit 0
                ;;
            --repo)
                shift
                repo_name=$1
                ;;
            *)
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$repo_name" ] || error "missing required argument: --repo"

    get_repo_href $repo_name
    local repo_href=$func_res

    make_curl_req \
            POST \
            ${pulp_api_url}publications/${pulp_api_url_suffix} \
            202 \
            json \
            "{\"repository\":\"${domain}${repo_href}\",\"simple\":true}"
    
    local task_href=$(echo $func_res | jq -r '.task')
    # echo "task_href = $task_href"
    wait_task_finish $task_href

    echo "publication of repo '$repo_name' created"
}

function handle_publ_delete_command {
    check_type_argument
    handle_${repo_type}_${command}_${subcommand}_command $@
}

function handle_deb_publ_delete_command {
    local publ_href=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "options:"
                echo "  --help    Show this help text and do nothing."
                echo "  --href    href of the publication to delete."
                exit 0
                ;;
            --href)
                shift
                publ_href=$1
                ;;
            *)
                error "unknown command line argument: $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$publ_href" ] || error "missing required argument: --href"

    make_curl_req \
            DELETE \
            ${domain}$publ_href \
            204
    
    echo "publication deleted"
}

handle_${command}_${subcommand}_command $@

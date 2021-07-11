#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

declare -A commands=( \
        [add]=1 \
    )

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) <options> <command> [--help] [...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
			echo "  --base-dir <base-dir>    required option, base directory where all repos are stored."
            echo "  --owner <owner>          required option, owner name."
            echo "  --repo <repo>            required option, repository name."
            echo "  --component <component>  debian repo component."
            echo ""
            echo "commands:"
            for i in "${!commands[@]}"; do {
                echo "  $i"
            } done
			exit 0
			;;
		--base-dir)
			shift
			base_dir=$1/
            [ -d "$base_dir" ] || error "base directory '$base_dir' does not exist"
			;;
		--owner)
			shift
			owner=$1
			;;
		--repo)
            shift
            repo=$1
            ;;
		*)
            command=$1
            [ ! -z "${commands[$command]}" ] || error "unknown command: $command"
			;;
	esac
	[[ $# > 0 ]] && shift;

    if [ ! -z "$command" ]; then break; fi
done

[ ! -z "$base_dir" ] || error "missing required argument: --base-dir"
[ ! -z "$owner" ] || error "missing required argument: --owner"
[ ! -z "$repo" ] || error "missing required argument: --repo"

[ ! -z "$command" ] || error "command is not given"

repo_dir="${base_dir}${owner}/${repo}/"
conf_dir="${repo_dir}conf/"
conf_distros_file="${conf_dir}distributions"

function create_repo {
    if [ ! -f "$conf_distros_file" ]; then
        mkdir -p $conf_dir
        touch $conf_distros_file
    fi
}

function create_distro {
    local distro=$1

    local distro_basename_file="${distro}.dist"
    local distro_file="${conf_dir}${distro_basename_file}"

    if [ ! -f "${distro_file}" ]; then
        echo "Codename: ${distro}" >> ${distro_file}
        echo "Architectures: source" >> ${distro_file}
        echo "Components: " >> ${distro_file}
        echo "SignWith: default" >> ${distro_file}

        echo "!include: ${distro_basename_file}" >> ${conf_distros_file}
    fi

    func_res=$distro_file
}

function is_in {
    local str=$1
    local strings=$2

    for s in $strings; do
        if [ "$s" == "$str" ]; then
            echo "true"
            return
        fi
    done
}

function handle_add_command {
    local distro=
    local component=
    local files=
    while [[ $# > 0 ]] ; do
        case $1 in
            --help)
                echo "usage:"
			    echo "	$(basename $0) <...> add <options> <deb-file> [<deb-file> ...]"
                echo ""
                echo "options:"
                echo "  --help    show this help text and do nothing."
                echo "  --distro  required option, distribution codename."
                exit 0
                ;;
            --distro)
                shift
                distro=$1
                ;;
            --component)
                shift
                component=$1
                ;;
            *)
                files="$files $1"
                ;;
        esac
        [[ $# > 0 ]] && shift;
    done

    [ ! -z "$distro" ] || error "missing required option: --distro"
    [ ! -z "$component" ] || error "missing required argument: --component"
    [ ! -z "$files" ] || error "missing deb files to add"

    create_distro ${distro}
    local distro_file=$func_res

    # read distro components
    local comps=$(cat ${distro_file} | awk '$1 == "Components:" {$1=""; print $0}')
    if [ -z "$(is_in $component "$comps")" ]; then
        echo "add new component '$component'"
        comps="${comps} ${component}"
        sed -E -i -e "s/^(Components:).*$/\1${comps}/g" ${distro_file}
    fi

    # read distro archs
    local archs=$(cat ${distro_file} | awk '$1 == "Architectures:" {$1=""; print $0}')
    # echo "archs = $archs"

    local archs_to_add=

    for f in $files; do
        parse_deb_file_name $(basename $f)
        local arch=${func_res[2]}
        if [ "$arch" == "all" ]; then continue; fi
        # echo "arch = $arch"
        if [ -z "$(is_in $arch "$archs")" ]; then
            archs_to_add="$archs_to_add $arch"
        fi
    done

    # update architectures
    if [ ! -z "$archs_to_add" ]; then
        archs="${archs}${archs_to_add}"
        sed -E -i -e "s/^(Architectures:).*$/\1${archs}/g" ${distro_file}
    fi

    reprepro --basedir ${repo_dir} --component ${component} includedeb ${distro} ${files}

    # copy 'all' arch packages to newly added archs, i.e. flood distro
    if [ ! -z "$archs_to_add" ]; then
        reprepro --basedir ${repo_dir} flood ${distro}
    fi
}

create_repo

(
    flock --exclusive --timeout 60 200

    handle_${command}_command $@
) 200>${repo_dir}lock

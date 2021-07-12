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
			echo "	$(basename $0) [--help] <options> <deb-file> [<deb-file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
			echo "  --base-dir <base-dir>    required option, base directory where all repos are stored."
            echo "  --owner <owner>          required option, owner name, e.g. ivan"
            echo "  --repo <repo>            required option, repository name, e.g. debian"
			echo "  --distro <distro>        required option, debian repo distro, e.g. buster."
            echo "  --component <component>  required option, debian repo component, e.g. main"
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

[ ! -z "$base_dir" ] || error "missing required argument: --base-dir"
[ ! -z "$owner" ] || error "missing required argument: --owner"
[ ! -z "$repo" ] || error "missing required argument: --repo"
[ ! -z "$distro" ] || error "missing required option: --distro"
[ ! -z "$component" ] || error "missing required argument: --component"
[ ! -z "$files" ] || error "missing deb files to add"

repo_dir="${base_dir}${owner}/${repo}/"
conf_file="${repo_dir}/etc/freight.conf"

# create repo if needed

if [ ! -f "${conf_file}" ]; then
	mkdir -p $repo_dir
	# mkdir -p ${repo_dir}lib
	first_key_email=$(gpg --list-keys | sed -E -n -e 's/.*<([^ >]*)>.*/\1/p' | head -1)
	[ ! -z "$first_key_email" ] || error "no default GPG key found"
	freight-init --gpg=$first_key_email --libdir=${repo_dir}lib --cachedir=${repo_dir} ${repo_dir}
fi

(
    flock --exclusive --timeout 60 200
    
	for f in $files; do
		freight-add -c ${conf_file} $f apt/$distro
	done
	
	freight-cache -c ${conf_file}
) 200>${repo_dir}lock



#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) [--help] <options> <deb-file> [<deb-file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
			echo "  --base-dir <base-dir>    required option, base directory where all repos are stored."
			echo "  --repo <repo>            required option, repository name, e.g. 'cppfw/debian'."
			echo "  --distro <distro>        required option, debian repo distro, e.g. 'buster'."
            echo "  --component <component>  required option, debian repo component, e.g. 'main'."
			exit 0
			;;
		--base-dir)
			shift
			base_dir=$1/
            [ -d "$base_dir" ] || error "base directory '$base_dir' does not exist"
			;;
		--owner)
			echo "DEPRECATED: --owner, use --repo <owner>/<repo-name> instead"
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
[ ! -z "$repo" ] || error "missing required argument: --repo"
[ ! -z "$distro" ] || error "missing required option: --distro"
[ ! -z "$component" ] || error "missing required argument: --component"
[ ! -z "$files" ] || error "missing deb files to add"

repo_dir="$(realpath --canonicalize-missing ${base_dir}${owner}/${repo})/"

# echo "repo_dir = $repo_dir"

# create repo dir if needed
if [ ! -d "$repo_dir" ]; then
	mkdir -p $repo_dir
fi

function perform_aptian_add {
	local conf_file="${repo_dir}aptian.conf"

	if [ ! -f "${conf_file}" ]; then
		first_key_email=$(gpg --list-keys | sed -E -n -e 's/.*<([^ >]*)>.*/\1/p' | head -1)
		[ ! -z "$first_key_email" ] || error "no default GPG key found"
        aptian init --gpg=$first_key_email --dir=${repo_dir}
	fi

    aptian add --dir=${repo_dir} --dist=$distro --comp=$component $files
}

(
	# 1 hour timeout = 3600 seconds
	flock --verbose --exclusive --timeout 3600 200
    
	perform_aptian_add
) 200>${repo_dir}lock

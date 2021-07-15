#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"
source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) [--help] <options> <pkg-file> [<pkg-file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
			echo "  --base-dir <base-dir>    required option, base directory where all repos are stored."
			echo "  --repo <repo>            required option, repository name, e.g. cppfw/msys2/mingw32"
			echo "  --database <name>        required option, debian repo distro, e.g. cppfw_mingw32."
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
		--database)
			shift
			database=$1
			;;
		*)
            files="$files $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ ! -z "$base_dir" ] || error "missing required argument: --base-dir"
[ ! -z "$repo" ] || error "missing required argument: --repo"
[ ! -z "$database" ] || error "missing required option: --database"
[ ! -z "$files" ] || error "missing package files to add"

repo_dir="$(realpath --canonicalize-missing ${base_dir}${owner}/${repo})/"

if [ ! -d "$repo_dir" ]; then
    mkdir -p $repo_dir;
fi

function perform_pacman_add {
    first_key_email=$(gpg --list-keys | sed -E -n -e 's/.*<([^ >]*)>.*/\1/p' | head -1)

    for file in $files; do
        cp --no-clobber $file $repo_dir
        local f=$(basename $file)
        echo "add package '$f' to database"
        repo-add --new --verify --key $first_key_email --sign ${repo_dir}$database.db.tar.gz ${repo_dir}$f
    done
}

(
    flock --exclusive --timeout 60 200
    
	perform_pacman_add
) 200>${repo_dir}lock

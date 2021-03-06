#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment of pacman package (Arch linux package manager system) to self-hosted repo via ssh

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

user=repo
base_dir=/var/www/repo/

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) [--help] <options> <pkg-file> [<pkg-file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
            echo "  --key <ssh-key>          ssh private key to authenticate to the server."
			echo "  --server <server>        ssh server"
            echo "  --user <user>            linux user name on the server, defaults to 'repo'"
            echo "  --base-dir <path>        repositories base directory on the server, defaults to 'repo'"
            echo "  --repo <repo>            repo name, e.g. cppfw/msys/mingw32"
            echo "  --database <name>        pacman database name"
			exit 0
			;;
        --key)
            shift
            ssh_key=$1
            ;;
        --server)
            shift
            server=$1
            ;;
        --user)
            shift
            user=$1
            ;;
		--base-dir)
			shift
			base_dir=$1/
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

[ ! -z "$server" ] || error "required option is not given: --server"
[ ! -z "$ssh_key" ] || error "required option is not given: --key"
[ ! -z "$repo" ] || error "required option is not given: --repo"
[ ! -z "$database" ] || error "required option is not given: --database"
[ ! -z "$files" ] || error "no package files given"

# TODO: --owner is DEPRECATED, remove when support for --owner is removed
if [ ! -z "$owner" ]; then
    owner="${owner}/"
fi

ssh_opts="-i ${ssh_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

tmp_dir=$(ssh ${ssh_opts} $user@$server mktemp --tmpdir --directory myci_upload.XXXXXXXXXX)
# echo "tmp_dir = $tmp_dir"
trap "ssh ${ssh_opts} $user@$server rm -rf $tmp_dir" EXIT ERR

scp ${ssh_opts} $files $user@$server:$tmp_dir

remote_files=$(ssh ${ssh_opts} $user@$server ls -d $tmp_dir/*)

ssh ${ssh_opts} $user@$server myci-pacman-add.sh --base-dir $base_dir --repo ${owner}${repo} --database $database $remote_files

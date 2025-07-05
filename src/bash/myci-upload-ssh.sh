#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

dst_dir=./

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) [--help] <options> <file> [<file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
            echo "  --key <ssh-key>          ssh private key to authenticate to the server. Required."
			echo "  --server <server>        ssh server. Required."
            echo "  --user <user>            linux user name on the server. Required."
            echo "  --dir <path>             destination directory path on the server. Optional, defaults to user home dir."
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
		--dir)
			shift
			dst_dir=$1/
			;;
		*)
            files="$files $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

[ ! -z "$server" ] || error "required option is not given: --server"
[ ! -z "$ssh_key" ] || error "required option is not given: --key"
[ ! -z "$user" ] || error "required option is not given: --user"
[ ! -z "$files" ] || error "no files to upload given"

ssh_opts="-i ${ssh_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

tmp_dir=$(ssh ${ssh_opts} $user@$server mktemp --tmpdir --directory myci_upload.XXXXXXXXXX)
# echo "tmp_dir = $tmp_dir"
trap "ssh ${ssh_opts} $user@$server rm -rf $tmp_dir" EXIT ERR

echo "local_files = $files"
echo "copying local files to remote server"
scp ${ssh_opts} $files $user@$server:$tmp_dir

remote_files=$(ssh ${ssh_opts} $user@$server "ls --directory $tmp_dir/* | tr '\n' ' '")
echo "done copying local files to remote server"
echo "remote_files = $remote_files"

echo "move temprorary remote files to $dst_dir"

ssh ${ssh_opts} $user@$server "for f in $remote_files; do mv \$f $dst_dir; done"

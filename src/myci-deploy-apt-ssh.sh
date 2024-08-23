#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

user=repo
base_dir=/var/www/repo/

while [[ $# > 0 ]] ; do
	case $1 in
		--help)
			echo "usage:"
			echo "	$(basename $0) [--help] <options> <deb-file> [<deb-file>...]"
			echo " "
			echo "options:"
            echo "  --help                   show this help text and do nothing."
            echo "  --key <ssh-key>          ssh private key to authenticate to the server."
			echo "  --server <server>        ssh server."
            echo "  --user <user>            linux user name on the server, defaults to 'repo'."
            echo "  --base-dir <path>        repositories base directory on the server, defaults to 'repo'."
            echo "  --repo <repo>            debian repo name, e.g. 'cppfw/debian'."
            echo "  --distro <distro>        debian distro name, e.g. 'bookworm'."
            echo "  --component <component>  debian repo component, e.g. 'main'."
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

[ ! -z "$server" ] || error "required option is not given: --server"
[ ! -z "$ssh_key" ] || error "required option is not given: --key"
[ ! -z "$repo" ] || error "required option is not given: --repo"
[ ! -z "$distro" ] || error "required option is not given: --distro"
[ ! -z "$component" ] || error "required option is not given: --component"
[ ! -z "$files" ] || error "no package files given"

# TODO: --owner is DEPRECATED, remove when support for --owner is removed
if [ ! -z "$owner" ]; then
    owner="${owner}/"
fi

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

ssh ${ssh_opts} $user@$server myci-aptian-add.sh --base-dir $base_dir --repo ${owner}${repo} --distro $distro --component $component $remote_files

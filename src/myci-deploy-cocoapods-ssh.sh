#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

# Script for quick deployment to cocoapods.
# It assumes that cocoapods specs to deploy are in 'cocoapods' directory.
# The binary zip packages are deployed to self-hosted generic repo via ssh.

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

user=repo
base_dir=/var/www/repo/

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) <options> <spec.podspec.in>"
            echo " "
            echo "Environment variable MYCI_GIT_PASSWORD must be set to cocoapods-repo's git access token."
			echo "Package name will be taken from podspec filename."
            echo " "
            echo "options:"
            echo "  --repo <cocoapods-repo-name>  name of the cocoapods repo."
            echo "  --version <version>           package version."
            echo "  --server <server>             ssh server."
            echo "  --key <ssh-key>               ssh key."
            echo "  --user <ssh-user>             ssh user. Defaults to 'repo'."
            echo "  --base-dir <dir>              generic repo base dir. Dir on the server where repos reside. Defaults to '/var/www/repo/'"
            echo "  --owner <repo-owner>          generic repo owner, e.g. ivan."
            echo "  --generic-repo <repo>         generice repo name, e.g. cocoapods."
            echo "  --package <package-file>      binary package name."
            exit 0
			;;
		--repo)
			shift
			repo=$1
			;;
		--version)
			shift
			version=$1
			;;
		--server)
			shift
			server=$1
			;;
		--key)
			shift
			ssh_key=$1
			;;
		--user)
			shift
			user=$1
			;;
        --base-dir)
            shift
            base_dir=$1
            ;;
        --owner)
            shift
            owner=$1
            ;;
        --generic-repo)
            shift
            generic_repo=$1
            ;;
		--package)
			shift
			package=$1
			;;
		*)
			if [ ! -z "$podspecfile" ]; then
				echo "error: more than one podspec file supplied"
				exit 1
			fi
			podspec="$1"
			;;
    esac

	[[ $# > 0 ]] && shift;
done

[ ! -z "$MYCI_GIT_PASSWORD" ] || error "MYCI_GIT_PASSWORD is not set"
[ ! -z "$repo" ] || error "missing required option: --repo"
[ ! -z "$version" ] || error "missing required option: --version"
[ ! -z "$podspec" ] || error "podspec file is not given"

if [ ! -z "$server" ] ||
        [ ! -z "$ssh_key" ] ||
        [ ! -z "$user" ] ||
        [ ! -z "$base_dir" ] ||
        [ ! -z "$owner" ] ||
        [ ! -z "$generic_repo" ] ||
        [ ! -z "$package" ];
then
	echo "will also upload binary package to generic repo"
    [ ! -z "$server" ] || error "missing required option: --server"
    [ ! -z "$ssh_key" ] || error "missing required option: --key"
    [ ! -z "$user" ] || error "missing required option: --user"
    [ ! -z "$base_dir" ] || error "missing required option: --base_dir"
    [ ! -z "$owner" ] || error "missing required option: --owner"
    [ ! -z "$generic_repo" ] || error "missing required option: --generic_repo"
    [ ! -z "$package" ] || error "missing required option: --package"
fi

${script_dir}myci-apply-version.sh -v $version $podspec

outpodspec=$(echo $podspec | sed -n -e 's/\(.*\)\.in$/\1/p')

package_name=$(echo $(basename $podspec) | sed -n -e 's/\(.*\)\.podspec.in$/\1/p')

if [ ! -z "$server" ]; then
	echo "upload binary file '$package' to generic repo"

    ssh_opts="-i ${ssh_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

    tmp_dir=$(ssh ${ssh_opts} $user@$server mktemp --tmpdir --directory myci_upload.XXXXXXXXXX)
    # echo "tmp_dir = $tmp_dir"
    trap "ssh ${ssh_opts} $user@$server rm -rf $tmp_dir" EXIT ERR

    scp ${ssh_opts} $package $user@$server:$tmp_dir

    remote_files=$(ssh ${ssh_opts} $user@$server ls -d $tmp_dir/*)
    # echo "remote_files = $remote_files"

    ssh ${ssh_opts} $user@$server myci-generic-add.sh --base-dir $base_dir --owner $owner --repo $repo $remote_files

	echo "done deploying '$package_name' binary package version $version to generic repo"
fi

echo "deploy to cocoapods"

echo "cocoapods version = $(pod --version)"

# Need to pass --use-libraries because before pushing the spec it will run 'pod lint'
# on it. And 'pod lint' uses framework integration by default which will fail to copy
# some header files to the right places.

GIT_ASKPASS=${script_dir}myci-git-askpass.sh pod repo push $repo $outpodspec --use-libraries --skip-import-validation --allow-warnings

echo "done deploying to cocoapods"

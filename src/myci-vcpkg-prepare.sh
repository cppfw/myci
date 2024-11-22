#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) --git-ref <git-ref> [--version <soname> --vcpkg-dir <path-to-vcpkgization-dir>]"
            echo " "
            echo "Options:"
			echo "  --git-ref    git ref, e.g. commit hash or tag."
            echo "  --version    package version. If not given, then will try to fetch version from debian/changelog."
			echo "  --vcpkg-dir  directory with vcpkgization input files. Defaults to 'vcpkg'."
            echo " "
            echo "Example:"
            echo "	$(basename $0) --version 1.1.13 --vcpk-dir vcpkg"
            exit 0
			;;
		--git-ref)
			shift
			git_ref=$1
			;;
		--version)
			shift
			version=$1
			;;
		--vcpkg-dir)
			shift
			vcpkgization_dir=$1
			;;
    esac

	[[ $# > 0 ]] && shift;
done

[ ! -z "$git_ref" ] || error "required option is not given: --git-ref"

echo "preparing vcpkg package"

if [ -z "$vcpkgization_dir" ]; then
	vcpkgization_dir=vcpkg
fi

if [ ! -z "$version" ]; then
	version_arg="--version $version"
else
	version_arg=
fi

${script_dir}myci-apply-version.sh $version_arg $vcpkgization_dir/vcpkg.json.in

homepage=$(jq -r .homepage $vcpkgization_dir/vcpkg.json)
package_name=$(jq -r .name $vcpkgization_dir/vcpkg.json)

archive_url=$homepage/archive/$git_ref.tar.gz

echo "download archive from $archive_url"
sha512=$(curl --fail --location --silent --show-error $archive_url | sha512sum - | cut -d " " -f 1)

# echo "sha512 = $sha512"

overlay_package_dir=$vcpkgization_dir/overlay/$package_name

mkdir -p $overlay_package_dir

${script_dir}myci-subst-var.sh --var archive_hash --val $sha512 --var git_ref --val $git_ref --out-dir $overlay_package_dir $vcpkgization_dir/portfile.cmake.in

echo "format vcpkg.json"
vcpkg format-manifest $vcpkgization_dir/vcpkg.json

mv $vcpkgization_dir/vcpkg.json $overlay_package_dir
cp $vcpkgization_dir/usage $overlay_package_dir

echo "vcpkg package prepared"

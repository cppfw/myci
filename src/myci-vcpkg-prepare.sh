#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

source ${script_dir}myci-common.sh

# this script is used for preparing the debian package before building with dpkg-buildpackage.

while [[ $# > 0 ]] ; do
    case $1 in
        --help)
            echo "Usage:"
            echo "	$(basename $0) --version <soname> [--vcpkg-dir <path-to-vcpkgization-dir>]"
            echo " "
            echo "Options:"
            echo "  --version    package version, can be git commit hash."
			echo "  --vcpkg-dir  directory with vcpkgization input files. Defaults to 'vcpkg'."
            echo " "
            echo "Example:"
            echo "	$(basename $0) --version 1.1.13 --vcpk-dir vcpkg"
            exit 0
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

echo "preparing vcpkg package"

if [ -z "$vcpkgization_dir" ]; then
	vcpkgization_dir=vcpkg
fi

[ ! -z "$version" ] || error "required option is not given: --version"

${script_dir}myci-apply-version.sh --version $version --out-dir $vcpkgization_dir/overlay/thepackage $vcpkgization_dir/vcpkg.json.in

homepage=$(jq -r .homepage $vcpkgization_dir/overlay/thepackage/vcpkg.json)

archive_url=$homepage/archive/$version.tar.gz

echo "download archive from $archive_url"
sha512=$(curl --fail --location --silent --show-error $archive_url | sha512sum - | cut -d " " -f 1)

# echo "sha512 = $sha512"

${script_dir}myci-subst-var.sh --var archive_hash --val $sha512 --out-dir $vcpkgization_dir/overlay/thepackage $vcpkgization_dir/portfile.cmake.in

echo "vcpkg package prepared"

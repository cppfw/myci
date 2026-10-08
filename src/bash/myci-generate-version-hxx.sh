#!/bin/bash

# generates src/version.hxx with the given version

# by default it generates the file only if it does not exist yet
# with --update it updates the existing file and does nothing if the file is not present

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

version_file=src/version.hxx
version=
update=false

while [[ $# > 0 ]] ; do
	case "$1" in
		--help)
			echo "myci generate src/version.hxx file utility."
			echo ""
			echo "usage:"
			echo "  $(basename $0) <options>"
			echo ""
			echo "options:"
			echo "  --version <version>  version string to put into the file; if not given, the version is taken from the debian changelog"
			echo "  --update             do not generate, but update the existing file; ignore if the file is not present"
			echo ""
			echo "By default the file is generated only if it does not exist yet."
			echo ""
			echo "examples:"
			echo "  $(basename $0)                           generate src/version.hxx if it does not exist"
			echo "  $(basename $0) --version 1.2.3           generate src/version.hxx with version 1.2.3 if it does not exist"
			echo "  $(basename $0) --update --version 1.2.3  update src/version.hxx to version 1.2.3 if it exists"
			exit 0
			;;
		--version)
			shift
			version=$1
			;;
		--update)
			update=true
			;;
		*)
			source ${script_dir}myci-error.sh "unknown argument specified: $1"
			;;
	esac
	[[ $# > 0 ]] && shift;
done

if [ -z "$version" ]; then
	echo "version is not given, trying to extract it from debian/changelog"
	version=$(${script_dir}myci-deb-version.sh)
fi

write_version_file() {
	cat > $version_file <<EOF
// AUTO-GENERATED VERSION FILE!!!
#pragma once
constexpr auto program_version = "${version}";
EOF
}

if [ "$update" == "true" ]; then
	if [ -f $version_file ]; then
		echo "update $version_file"
		write_version_file
	else
		echo "no $version_file present, not generating it"
	fi
else
	if [ -f $version_file ]; then
		echo "$version_file present, not updating it"
	else
		[ -d src ] || source ${script_dir}myci-error.sh "no src directory present, cannot generate src/version.hxx file"
		echo "generating $version_file"
		write_version_file
	fi
fi

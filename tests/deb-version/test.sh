#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/myci-running-test.sh $testname

version=$(../../src/myci-deb-version.sh)

echo "version = $version"

[ "$version" == "1.2.3" ] || ../../src/myci-error.sh "version is not as expected: $version != 1.2.3"

../../src/myci-passed.sh

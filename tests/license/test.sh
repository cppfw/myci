#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/myci-running-test.sh $testname

rm -rf tmp
cp -r src tmp

../../src/myci-license.sh --license LICENSE --dir tmp

../../src/myci-license.sh --license LICENSE --dir tmp --check src/main_with_license.cpp

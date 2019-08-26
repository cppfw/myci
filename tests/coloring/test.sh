#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/myci-running-test.sh $testname

../../src/myci-error.sh "not a real error, just testing" || true
../../src/myci-warning.sh "not a real warning, just testing"
../../src/myci-passed.sh

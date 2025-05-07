#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/bash/myci-running-test.sh $testname

../../src/bash/myci-error.sh "not a real error, just testing" || true
../../src/bash/myci-warning.sh "not a real warning, just testing"
../../src/bash/myci-passed.sh

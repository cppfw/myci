#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/myci-running-test.sh $testname

rm -f *.txt
../../src/myci-apply-version.sh -v 1.2.3 *.in
if [ ! -f test-1.2.3.txt ]; then ../../src/myci-error.sh "test-1.2.3.txt file not found"; fi
cmp test-1.2.3.txt test.smp || ../../src/myci-error.sh "test-1.2.3.txt contents are not as expected";
rm -f *.txt
../../src/myci-apply-version.sh -v 1.2.3 *.in --filename-only
if [ ! -f test-1.2.3.txt ]; then ../../src/myci-error.sh "test-1.2.3.txt file not found"; fi
cmp test-1.2.3.txt test-\$\(version\).txt.in || ../../src/myci-error.sh "test-1.2.3.txt contents are not as expected (test-\$(version).txt.in)";
../../src/myci-passed.sh
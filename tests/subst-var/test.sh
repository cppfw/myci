#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/bash/myci-running-test.sh $testname

rm -f *.txt
../../src/bash/myci-subst-var.sh --var varname --val varval --var 1 --val 11 ./*.in
if [ ! -f test-varval.txt ]; then
	../../src/bash/myci-error.sh "test-varval.txt file not found";
fi
cmp test-varval.txt test.smp || (echo "test-varval.txt =" && hexdump -C test-varval.txt && echo "test.smp =" && hexdump -C test.smp && ../../src/bash/myci-error.sh "test-varval.txt contents are not as expected");

rm -f *.txt
../../src/bash/myci-subst-var.sh --var varname --val varval ./*.in --filename-only
if [ ! -f test-varval.txt ]; then
	../../src/bash/myci-error.sh "test-varval.txt file not found";
fi
cmp test-varval.txt test-\$\(varname\).txt.in || ../../src/bash/myci-error.sh "test-varval.txt contents are not as expected (test-\$(version).txt.in)";

mkdir -p out
../../src/bash/myci-subst-var.sh --var varname --val varval ./*.in --out-dir out/
if [ ! -f out/test-varval.txt ]; then
	../../src/bash/myci-error.sh "out/test-varval.txt file not found";
fi
cmp out/test-varval.txt test.smp || ../../src/bash/myci-error.sh "out/test-varval.txt contents are not as expected (test-\$(version).txt.in)";
rm -rf out

../../src/bash/myci-passed.sh

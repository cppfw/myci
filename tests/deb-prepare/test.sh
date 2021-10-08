#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/myci-running-test.sh $testname

rm -f debian/libtest*.install
rm -f debian/control
../../src/myci-deb-prepare.sh
if [ ! -f debian/control ]; then ../../src/myci-error.sh "debian/control file not found"; fi
if [ ! -f debian/libtesta4.install ]; then ../../src/myci-error.sh "debian/libtesta4.install file not found"; fi
if [ ! -f debian/libtestb4.install ]; then ../../src/myci-error.sh "debian/libtestb4.install file not found"; fi
cmp debian/control samples/control || ../../src/myci-error.sh "debian/control contents are not as expected";
../../src/myci-passed.sh

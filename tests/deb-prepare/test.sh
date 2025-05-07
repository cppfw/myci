#!/bin/bash

# we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

testname=$(pwd)
testname=${testname##*/}
../../src/bash/myci-running-test.sh $testname

rm -f debian/libtest*.install
rm -f debian/control
../../src/bash/myci-deb-prepare.sh
if [ ! -f debian/control ]; then ../../src/bash/myci-error.sh "debian/control file not found"; fi
if [ ! -f debian/libtesta4.install ]; then ../../src/bash/myci-error.sh "debian/libtesta4.install file not found"; fi
if [ ! -f debian/libtestb4.install ]; then ../../src/bash/myci-error.sh "debian/libtestb4.install file not found"; fi
cmp debian/control samples/control || ../../src/bash/myci-error.sh "debian/control contents are not as expected";
../../src/bash/myci-passed.sh

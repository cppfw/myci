#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

tests=$(ls -d */)

for t in $tests
do
	(cd $t && ./test.sh)
done

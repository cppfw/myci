#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

script_dir="$(dirname $0)/"

tests=$(ls -d $script_dir/*/)

for t in $tests
do
	(cd $t && ./test.sh)
done

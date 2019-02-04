#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

printf "\t"
test -t 1 && printf "\\033[1;32m" || true
printf "PASSED"
test -t 1 && printf "\\033[0m" || true
printf "\n"

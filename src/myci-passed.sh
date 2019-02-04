#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

test -t 1 && printf "\t\\033[1;32mPASSED\\033[0m\n" || printf "\tPASSED\n"

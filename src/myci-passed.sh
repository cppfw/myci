#!/bin/bash

#we want exit immediately if any command fails and we want error in piped commands to be preserved
set -eo pipefail

test -t 1 && printf "\t\e[1;32mPASSED\e[0m\n" || printf "\tPASSED\n"

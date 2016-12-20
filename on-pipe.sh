#!/bin/sh

cmd=${1:-id}
test -n "$1" && shift
xargs -L1 | cut -d' ' -f1 | xargs -L1 -Ixx ./plan.sh "$cmd" xx "$@"

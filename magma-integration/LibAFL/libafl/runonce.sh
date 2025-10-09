#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (should be found in $OUT)
##

export TIMELIMIT=0.3s

TC="$1"
if [ -z "$TC" ]; then
  echo "Usage: $0 <testcase>"
  exit 1
fi

export ASAN_OPTIONS="abort_on_error=0:allocator_may_return_null=1"
export UBSAN_OPTIONS="abort_on_error=0"

timeout -s KILL --preserve-status $TIMELIMIT bash -c "'$OUT/$PROGRAM' '$1'"

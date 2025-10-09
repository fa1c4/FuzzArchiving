#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

if [ ! -d "$FUZZER/repo" ]; then
  git clone https://github.com/AFLplusplus/LibAFL "$FUZZER/repo"
fi

git -C "$FUZZER/repo" fetch --all
git -C "$FUZZER/repo" checkout f856092f3d393056b010fcae3b086769377cba18 || true

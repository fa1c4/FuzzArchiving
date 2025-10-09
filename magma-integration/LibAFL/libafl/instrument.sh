#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

"$MAGMA/build.sh"

SANITIZER_FLAGS="-fsanitize=address -mllvm -asan-stack=0"
export CC="$FUZZER/repo/fuzzers/fuzzbench/fuzzbench/target/release/libafl_cc"
export CXX="$FUZZER/repo/fuzzers/fuzzbench/fuzzbench/target/release/libafl_cxx"
export CFLAGS="$CFLAGS $SANITIZER_FLAGS --libafl"
export CXXFLAGS="$CXXFLAGS $SANITIZER_FLAGS --libafl"
export LDFLAGS="$LDFLAGS"
export LIB_FUZZING_ENGINE="$OUT/stub_rt.a"

"$TARGET/build.sh"

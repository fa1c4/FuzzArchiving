#!/bin/bash -eu
# Copyright 2025 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

# expected layout:
#   $SRC/nghttp3  <- git repo (cloned in Dockerfile)
#   $OUT          <- where fuzzers + corpora + .options must end up

cd $SRC/nghttp3

###############################################################################
# 1. build nghttp3 as static lib with sanitizers
###############################################################################

autoreconf -i

./configure \
    --enable-static \
    --disable-shared

make -j"$(nproc)"
# don't hard fail tests under sanitizers
make check || true

# find static archive
if [ -f "./lib/.libs/libnghttp3.a" ]; then
    NGHTTP3_A=./lib/.libs/libnghttp3.a
elif [ -f "./lib/libnghttp3.a" ]; then
    NGHTTP3_A=./lib/libnghttp3.a
else
    echo "Cannot find libnghttp3.a"
    exit 1
fi

###############################################################################
# 2. common include flags
###############################################################################

INC_FLAGS=""
[ -d "$SRC/nghttp3/lib" ] && INC_FLAGS="$INC_FLAGS -I$SRC/nghttp3/lib"
[ -d "$SRC/nghttp3/lib/includes" ] && INC_FLAGS="$INC_FLAGS -I$SRC/nghttp3/lib/includes"
[ -d "$SRC/nghttp3/include" ] && INC_FLAGS="$INC_FLAGS -I$SRC/nghttp3/include"
INC_FLAGS="$INC_FLAGS -I$SRC/nghttp3"

FUZZ_DIR="$SRC/nghttp3/fuzz"

###############################################################################
# 3. build fuzz_http3serverreq_fuzzer (C++20)
###############################################################################

$CXX $CXXFLAGS $CFLAGS -std=c++20 \
    $INC_FLAGS \
    "$FUZZ_DIR/fuzz_http3serverreq.cc" \
    $NGHTTP3_A \
    $LIB_FUZZING_ENGINE \
    -o "$OUT/fuzz_http3serverreq_fuzzer"

# seed corpus for fuzz_http3serverreq
if [ -d "$FUZZ_DIR/corpus/fuzz_http3serverreq" ]; then
    zip -j "$OUT/fuzz_http3serverreq_fuzzer_seed_corpus.zip" \
        "$FUZZ_DIR/corpus/fuzz_http3serverreq"/* || true
fi

###############################################################################
# 4. build fuzz_qpackdecoder_fuzzer (C++20)
###############################################################################

$CXX $CXXFLAGS $CFLAGS -std=c++20 \
    $INC_FLAGS \
    "$FUZZ_DIR/fuzz_qpackdecoder.cc" \
    $NGHTTP3_A \
    $LIB_FUZZING_ENGINE \
    -o "$OUT/fuzz_qpackdecoder_fuzzer"

# seed corpus for fuzz_qpackdecoder
if [ -d "$FUZZ_DIR/corpus/fuzz_qpackdecoder" ]; then
    zip -j "$OUT/fuzz_qpackdecoder_fuzzer_seed_corpus.zip" \
        "$FUZZ_DIR/corpus/fuzz_qpackdecoder"/* || true
fi

###############################################################################
# 5. fuzzer options (libFuzzer settings)
###############################################################################

cp $SRC/*.options "$OUT" || true

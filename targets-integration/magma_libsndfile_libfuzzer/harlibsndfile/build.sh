#!/bin/bash
set -eu

# Expected env (set by magma/fuzzers/libfuzzer/instrument.sh):
#   TARGET  = /magma/targets/harlibsndfile
#   OUT     = /magma_out
#   CC/CXX  = clang/clang++
#   CFLAGS/CXXFLAGS/LDFLAGS include sanitizer + magma instrumentation
#   LIBS    includes magma.o, driver.o, libFuzzer.a, -lstdc++

TARGET_REPO="$TARGET/repo"
SNDFILE_A="$TARGET_REPO/src/.libs/libsndfile.a"
HARNESS_DIR="$TARGET/harness"
HARNESS_SRC="$HARNESS_DIR/sndfile_fuzzer.cc"
OUT_BIN="$OUT/sndfile_fuzzer"

if [ ! -d "$TARGET_REPO" ]; then
    echo "fatal: missing $TARGET_REPO (run fetch.sh first)" >&2
    exit 1
fi

# 1. configure & build libsndfile (static .a inside .la)
(
    cd "$TARGET_REPO"

    ./autogen.sh || autoreconf -vif
    ./configure --disable-shared --enable-ossfuzzers

    make -j"$(nproc)" clean || true
    make -j"$(nproc)" src/libsndfile.la
)

if [ ! -f "$SNDFILE_A" ]; then
    echo "fatal: did not find $SNDFILE_A" >&2
    exit 1
fi

# Audio/codec libs libsndfile expects when built with all features
AUDIO_LIBS=(
    -lvorbisenc -lvorbis -logg
    -lopus
    -lFLAC
    -lmp3lame -lmpg123
    -lasound
)

# 2. build the actual fuzz target (libFuzzer-style main from $LIBS)
"$CXX" $CXXFLAGS \
    -I"$TARGET_REPO" \
    -I"$TARGET_REPO/src" \
    -I"$TARGET_REPO/include" \
    -I"$HARNESS_DIR" \
    -L"$OUT" \
    $LDFLAGS \
    "$HARNESS_SRC" \
    "$SNDFILE_A" \
    "${AUDIO_LIBS[@]}" \
    $LIBS \
    -lm \
    -o "$OUT_BIN"

# 3. default libFuzzer options
cat > "${OUT_BIN}.options" <<EOF
[libfuzzer]
close_fd_mask = 3
EOF

echo "Built fuzz target:"
ls -l "$OUT_BIN" "$OUT_BIN.options"

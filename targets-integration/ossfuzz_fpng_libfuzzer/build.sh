#!/bin/bash -eu
# fpng OSS-Fuzz build script

# Source directory
PROJ_DIR="$SRC/fpng"
OUT_DIR="$OUT"

# Common compilation unit: fpng single-file implementation
FPNG_SRC="$PROJ_DIR/src/fpng.cpp"
FPNG_INC="-I$PROJ_DIR/src"

# Try to enable SSE4.1 + PCLMUL; fall back to pure scalar implementation on failure
try_build() {
  local outbin="$1"; shift
  $CXX $CXXFLAGS $FPNG_INC "$@" "$FPNG_SRC" $LIB_FUZZING_ENGINE -o "$outbin"
}

# 1) Build fuzz_decode
if ! try_build "$OUT_DIR/fpng_decode" -O2 -g -fno-omit-frame-pointer -msse4.1 -mpclmul "$SRC/fuzz_decode.cc"; then
  echo "SSE path failed; rebuilding fuzz_decode with -DFPNG_NO_SSE"
  try_build "$OUT_DIR/fpng_decode" -O2 -g -fno-omit-frame-pointer -DFPNG_NO_SSE "$SRC/fuzz_decode.cc"
fi

# 2) Build fuzz_encode
if ! try_build "$OUT_DIR/fpng_encode" -O2 -g -fno-omit-frame-pointer -msse4.1 -mpclmul "$SRC/fuzz_encode.cc"; then
  echo "SSE path failed; rebuilding fuzz_encode with -DFPNG_NO_SSE"
  try_build "$OUT_DIR/fpng_encode" -O2 -g -fno-omit-frame-pointer -DFPNG_NO_SSE "$SRC/fuzz_encode.cc"
fi

# 3) Prepare decoding corpus: use the example.png provided in the repository
if [ -f "$PROJ_DIR/example.png" ]; then
  ( cd "$PROJ_DIR" && zip -qj "$OUT_DIR/fpng_decode_seed_corpus.zip" example.png )
fi

# 4) Copy PNG dictionary to both fuzzers (libFuzzer searches by name automatically, or they can be shared)
cp "$SRC/png.dict" "$OUT_DIR/fpng_decode.dict" || true
cp "$SRC/png.dict" "$OUT_DIR/fpng_encode.dict" || true

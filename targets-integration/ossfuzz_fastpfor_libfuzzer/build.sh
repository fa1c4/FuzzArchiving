#!/bin/bash -eu
# oss-fuzz/projects/fastpfor/build.sh

# 0) Generate structured seed corpus
python3 $SRC/gen_seed_corpus.py $WORK/seed && \
  (cd $WORK/seed && zip -q $OUT/fastpfor_roundtrip_fuzzer_seed_corpus.zip ./* || true)

# 1) First compile FastPFOR's src/ source code into object files (both C and C++ might exist)
INC="-I$SRC/FastPFOR/headers -I$SRC/FastPFOR/src"
ISA_FLAGS="-msse3 -mssse3 -msse4.1"   # ★ Added: Unified SIMD instruction set flags
OBJS=""

# Compile C sources
if ls $SRC/FastPFOR/src/*.c >/dev/null 2>&1; then
  for f in $SRC/FastPFOR/src/*.c; do
    o="$WORK/fastpfor_$(basename "${f%.c}").o"
    $CC $CFLAGS -O1 -fno-omit-frame-pointer $ISA_FLAGS -c "$f" $INC -o "$o"
    OBJS="$OBJS $o"
  done
fi

# Compile C++ sources
if ls $SRC/FastPFOR/src/*.cpp >/dev/null 2>&1; then
  for f in $SRC/FastPFOR/src/*.cpp; do
    base="$(basename "$f")"
    case "$base" in
      benchbitpacking.cpp|unit.cpp|inmemorybenchmark.cpp|example.cpp|codecs.cpp)
        # These are benchmarks/unit tests/examples/drivers containing main or redefining test symbols, skip them
        continue
        ;;
    esac
    # Fallback: Skip any source containing main (to prevent issues with future repository changes)
    if grep -qE '^[[:space:]]*int[[:space:]]+main[[:space:]]*\(' "$f"; then
      continue
    fi
    o="$WORK/fastpfor_$(basename "${f%.cpp}").o"
    $CXX $CXXFLAGS -std=c++11 -O1 -fno-omit-frame-pointer $ISA_FLAGS -c "$f" $INC -o "$o"
    OBJS="$OBJS $o"
  done
fi

# Compile and link the fuzzer (with the same ISA flags)
$CXX $CXXFLAGS -std=c++11 $ISA_FLAGS \
  $SRC/fastpfor_roundtrip_fuzzer.cc \
  $INC $OBJS -o $OUT/fastpfor_roundtrip_fuzzer \
  $LIB_FUZZING_ENGINE

# === 2.1) Second target: decode-only ===
$CXX $CXXFLAGS -std=c++11 $ISA_FLAGS \
  $SRC/fastpfor_decode_fuzzer.cc \
  $INC $OBJS -o $OUT/fastpfor_decode_fuzzer \
  $LIB_FUZZING_ENGINE

# Share the same seed corpus (symlink for quick startup)
ln -sf fastpfor_roundtrip_fuzzer_seed_corpus.zip \
      $OUT/fastpfor_decode_fuzzer_seed_corpus.zip

# === 2.2) Write libFuzzer runtime options for both targets ===
cat > $OUT/fastpfor_roundtrip_fuzzer.options <<'EOF'
[libfuzzer]
max_len = 262144
use_value_profile = 1
EOF

cat > $OUT/fastpfor_decode_fuzzer.options <<'EOF'
[libfuzzer]
max_len = 262144
use_value_profile = 1
len_control = 0
EOF

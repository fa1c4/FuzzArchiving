#!/bin/bash -eu
# Copyright 2025 ...
#
# OSS-Fuzz build script for struct2json.
#
# Conventions:
#   - Upstream source is located at $SRC/struct2json
#   - fuzz_*.c in this directory (projects/struct2json) will be copied to $SRC/ by the Dockerfile
#   - Each fuzz_*.c implements LLVMFuzzerTestOneInput and includes necessary struct2json headers
# struct2json build.sh

# Project root directory
PROJECT_SRC="$SRC/struct2json"
WORKDIR="$WORK"

# Unify includes for convenience
INCLUDES="-I${PROJECT_SRC}/struct2json/inc -I${PROJECT_SRC}/cJSON"

# 1. Compile cJSON and struct2json core
$CC $CFLAGS $INCLUDES -c "${PROJECT_SRC}/cJSON/cJSON.c" -o "${WORKDIR}/cJSON.o"
$CC $CFLAGS $INCLUDES -c "${PROJECT_SRC}/struct2json/src/s2j.c" -o "${WORKDIR}/s2j.o"

# 2. Generate corresponding fuzzer executables for each fuzz_*.c
for fuzz_src in "$SRC"/fuzz_*.c; do
  # Defensive exit if no fuzz_*.c files are matched
  if [ ! -e "$fuzz_src" ]; then
    echo "No fuzz_*.c found under \$SRC, skipping."
    break
  fi

  fuzz_name="$(basename "$fuzz_src" .c)"
  obj_file="${WORKDIR}/${fuzz_name}.o"
  out_bin="${OUT}/${fuzz_name}"

  echo "Building fuzzer ${fuzz_name} from ${fuzz_src}"

  # Compile fuzz harness
  $CC $CFLAGS $INCLUDES -c "$fuzz_src" -o "$obj_file"

  # Link: Use $CXX for linking even for pure C, and explicitly link $LIB_FUZZING_ENGINE
  $CXX $CXXFLAGS "$obj_file" "${WORKDIR}/s2j.o" "${WORKDIR}/cJSON.o" \
        $LIB_FUZZING_ENGINE -lm -o "$out_bin"
done

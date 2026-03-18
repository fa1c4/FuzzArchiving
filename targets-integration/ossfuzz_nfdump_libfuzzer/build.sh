#!/bin/bash -eu
# Copyright 2025 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

# LeakSanitizer is prone to false positives on long-running daemons; disable it here globally.
export ASAN_OPTIONS="detect_leaks=0"

# Usually use C++ harness + libFuzzer
export CXXFLAGS="${CXXFLAGS} -std=c++17"

###############################################################################
# 1. Build nfdump core (prioritize static libraries)
###############################################################################
cd "$SRC/nfdump"

# The v1.7.7 source package does not include a pre-generated configure script; 
# need to run autogen.sh first.
if [ ! -x ./configure ]; then
  echo "configure not found, running ./autogen.sh ..."
  if [ -x ./autogen.sh ]; then
    ./autogen.sh
  else
    echo "Error: neither configure nor autogen.sh found in nfdump checkout"
    ls -la
    exit 1
  fi
fi

# Build static libraries as much as possible to reduce runtime dependencies.
./configure \
  --disable-shared \
  --enable-static

make -j"$(nproc)"
make install

# Ensure pkg-config can find the newly installed .pc file.
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

###############################################################################
# 1.5 (Optional) Copy some internal headers to /src for easy inclusion by other fuzzers.
###############################################################################
find "$SRC/nfdump/src" \( -name '*.h' -o -name '*.c' \) -exec cp -u {} "$SRC/" \; || true

###############################################################################
# 2. Extract compilation/linking options
###############################################################################
NFDUMP_CFLAGS="$(pkg-config --cflags nfdump 2>/dev/null || echo "-I$SRC/nfdump/src -I$SRC/nfdump/src/include")"
NFDUMP_LIBS="$(pkg-config --libs nfdump 2>/dev/null || echo "-L/usr/local/lib -lnfdump -lnffile")"

# Add the internal source subdirectories used by harnesses that include parser
# sources and collector-private headers directly.
NFDUMP_CFLAGS="${NFDUMP_CFLAGS} \
  -I$SRC/nfdump \
  -I$SRC/nfdump/src \
  -I$SRC/nfdump/src/collector \
  -I$SRC/nfdump/src/include \
  -I$SRC/nfdump/src/inline \
  -I$SRC/nfdump/src/libnfdump \
  -I$SRC/nfdump/src/libnffile \
  -I$SRC/nfdump/src/netflow"

NFDUMP_LIBS="${NFDUMP_LIBS} -llz4 -lzstd -lbz2"

echo "Using NFDUMP_CFLAGS: ${NFDUMP_CFLAGS}"
echo "Using NFDUMP_LIBS:   ${NFDUMP_LIBS}"

###############################################################################
# 3. Compile fuzzers — supports both fuzz_*.cc and fuzz_*.c
###############################################################################
BUILT_ANY=0

for SRC_FILE in "$SRC"/fuzz_*.cc "$SRC"/fuzz_*.c; do
  # If no files match, the glob remains as the pattern string; skip it.
  case "$SRC_FILE" in
    "$SRC/fuzz_*.cc" | "$SRC/fuzz_*.c")
      continue
      ;;
  esac
  [ -f "$SRC_FILE" ] || continue

  # Only compile harnesses that actually contain LLVMFuzzerTestOneInput
  if ! grep -q "LLVMFuzzerTestOneInput" "$SRC_FILE"; then
    echo "Skipping ${SRC_FILE}: no LLVMFuzzerTestOneInput found"
    continue
  fi

  f="$(basename "$SRC_FILE")"
  f="${f%.*}"

  ext="${SRC_FILE##*.}"
  if [ "$ext" = "c" ]; then
    compiler="$CC"
    cflags="$CFLAGS"
  else
    compiler="$CXX"
    cflags="$CXXFLAGS"
  fi

  echo "Building fuzzer ${f} from ${SRC_FILE} using ${compiler} ..."
  $compiler $cflags $NFDUMP_CFLAGS "$SRC_FILE" \
    $NFDUMP_LIBS $LIB_FUZZING_ENGINE \
    -o "$OUT/${f}"

  BUILT_ANY=1
done

# At least one fuzzer must be built; otherwise, consider the build failed.
if [ "$BUILT_ANY" -eq 0 ] && ! ls "$OUT" | grep -q 'fuzz'; then
  echo "No fuzzers were built. Please ensure at least one fuzz_*.c/cc defines LLVMFuzzerTestOneInput."
  exit 1
fi

###############################################################################
# 4. Recursively package runtime dependencies: ldd -> copy to /out/lib -> set rpath=$ORIGIN/lib
###############################################################################
mkdir -p "$OUT/lib"

copy_deps() {
  local bin="$1"
  # Only process regular executable files
  if [ ! -f "$bin" ] || [ ! -x "$bin" ]; then
    return 0
  fi

  echo "Collecting shared libs for $bin"
  ldd "$bin" 2>/dev/null | \
    sed -n 's/.*=> \(\/[^ ]*\) (0x[0-9a-fA-F]\+)/\1/p' | \
    while read -r lib; do
      if [ -f "$lib" ]; then
        cp -u "$lib" "$OUT/lib/" || true
      fi
    done
}

# Collect dependencies for all fuzz_* executables
for bin in "$OUT"/fuzz_*; do
  [ -e "$bin" ] || continue
  copy_deps "$bin"
done

# Use patchelf to set rpath=$ORIGIN/lib
for bin in "$OUT"/fuzz_*; do
  [ -f "$bin" ] || continue
  if command -v patchelf >/dev/null 2>&1; then
    echo "Setting rpath for $bin"
    patchelf --set-rpath '$ORIGIN/lib' "$bin" || true
  fi
done

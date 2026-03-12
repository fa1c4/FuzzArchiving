#!/bin/bash -eu

# 1. Only build RMG-Core (do not touch Qt GUI, RMG-Input, etc.)
cd "$SRC/RMG"

mkdir -p build-core
cmake -S Source/RMG-Core -B build-core -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo

cmake --build build-core -j"$(nproc)"

CORE_LIB=$(find build-core -name 'libRMG-Core.*' | head -n 1 || true)

if [[ -z "${CORE_LIB}" ]]; then
  echo "[-] libRMG-Core.* not found under build-core/"
  exit 1
fi

###############################################################################
# 1.5 Manually compile the 7zip SDK (Source/3rdParty/lzma) into a static library, supplying SzArEx_* and other symbols
###############################################################################
LZMA_DIR="$SRC/RMG/Source/3rdParty/lzma"
LZMA_LIB="$SRC/lib7z-fuzz.a"

echo "[*] Building local 7zip SDK static library from $LZMA_DIR"

pushd "$LZMA_DIR" >/dev/null

LZMA_OBJS=()
for c in *.c; do
  obj="${c%.c}.o"
  echo "  - compiling $c -> $obj"
  # Use the CC/CFLAGS provided by OSS-Fuzz to ensure ASan/UBSan, etc., are included
  $CC $CFLAGS -std=c11 -I"$LZMA_DIR" -c "$c" -o "$obj"
  LZMA_OBJS+=("$obj")
done

# Build a static library
ar rcs "$LZMA_LIB" "${LZMA_OBJS[@]}"

popd >/dev/null

# 2. Common compilation / linking arguments
FUZZ_CXXFLAGS="${CXXFLAGS} -std=c++20 \
  -I${SRC}/RMG/Source \
  -I${SRC}/RMG/Source/RMG-Core"

# Use RMG-Core dynamic library + our custom-built 7zip static library + system minizip/zlib
FUZZ_LDFLAGS="${LIB_FUZZING_ENGINE:-} ${LDFLAGS:-} \
  ${CORE_LIB} ${LZMA_LIB} \
  -lminizip -lz -ldl -lpthread"

# 3. Compile each fuzzer

# 3.1 Cheats fuzzer
$CXX ${FUZZ_CXXFLAGS} \
  "$SRC/cheats_fuzzer.cc" \
  -o "$OUT/rmg_cheats_fuzzer" \
  ${FUZZ_LDFLAGS}

# 3.2 Archive fuzzer
$CXX ${FUZZ_CXXFLAGS} \
  "$SRC/archive_fuzzer.cc" \
  -o "$OUT/rmg_archive_fuzzer" \
  ${FUZZ_LDFLAGS}

# 3.3 VRU fuzzer temporarily not compiled (missing Qt6/SDL3)
# If Qt6/SDL3 are resolved in the future, uncomment this section:
# $CXX ${FUZZ_CXXFLAGS} \
#   "$SRC/vru_fuzzer.cc" \
#   -o "$OUT/rmg_vru_fuzzer" \
#   ${FUZZ_LDFLAGS} \
#   $(pkg-config --libs --cflags Qt6Core Qt6Gui Qt6Widgets) -lSDL3

# 4. Recursively copy dependencies to /out/lib and set rpath
mkdir -p "$OUT/lib"

# 4.0 First drop RMG's own core .so in (most critical)
cp -n "$CORE_LIB" "$OUT/lib/" || true

for bin in "$OUT"/rmg_*_fuzzer; do
  [ -x "$bin" ] || continue

  # Correctly parse ldd output:
  #  - "libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x...)"
  #  - "/lib64/ld-linux-x86-64.so.2 (0x...)"
  while read -r name arrow path rest; do
    candidate=""
    if [[ "$arrow" == "=>" ]]; then
      candidate="$path"
    else
      candidate="$name"
    fi
    if [[ -f "$candidate" ]]; then
      cp -n "$candidate" "$OUT/lib/" || true
    fi
  done < <(ldd "$bin" 2>/dev/null || true)

  # Set rpath = $ORIGIN/lib
  patchelf --set-rpath '$ORIGIN/lib' "$bin" || true
done

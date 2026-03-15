#!/bin/bash -eu
# Copyright 2025 Google LLC
# ... [License Header] ...

################################################################################

# Directory Conventions:
#   $SRC/vectordb      -> upstream repository
#   $SRC/*.cc          -> Source code of fuzz targets we wrote
#   $OUT               -> fuzz binaries and dependencies

# Provide default values for common build variables to avoid "unbound variable" errors when set -u is active
: "${CFLAGS:=}"
: "${CXXFLAGS:=}"
: "${LDFLAGS:=}"
: "${LIB_FUZZING_ENGINE:=}"

# ======================================================================
# 0) Compatibility macros for libc++ / old Boost / legacy code
# ======================================================================
export CXXFLAGS="$CXXFLAGS -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION"
export CXXFLAGS="$CXXFLAGS -D_LIBCPP_ENABLE_CXX17_REMOVED_RANDOM_SHUFFLE"
export CXXFLAGS="$CXXFLAGS -include sstream"

# ======================================================================
# 0.5) Dummy OpenMP Header (if <omp.h> is missing from the system)
# ======================================================================
if ! echo '#include <omp.h>' | $CXX -E -xc++ - >/dev/null 2>&1; then
  echo "[+] <omp.h> not found, installing dummy stub into /tmp/omp.h"

  cat > /tmp/omp.h << 'EOF'
#pragma once
// Dummy OpenMP header for OSS-Fuzz build.
// We don't need real parallelism for fuzzing, just avoid compile failures.

static inline int  omp_get_max_threads(void) { return 1; }
static inline int  omp_get_thread_num(void)  { return 0; }
static inline int  omp_get_num_threads(void) { return 1; }
static inline int  omp_get_num_procs(void)   { return 1; }
static inline void omp_set_num_threads(int)  { /* no-op for fuzzing */ }
EOF

  export CXXFLAGS="$CXXFLAGS -I/tmp"
  export CFLAGS="$CFLAGS -I/tmp"
fi

# ======================================================================
# 1) Build vectordb C++ Core
# ======================================================================

pushd "$SRC/vectordb/engine"

# 1.0) Disable OpenMP: otherwise references to symbols like __kmpc_dispatch_deinit will be generated
echo "[+] Patching CMakeLists to disable OpenMP for OSS-Fuzz build"
find . -name 'CMakeLists.txt' -print0 | while IFS= read -r -d '' f; do
  sed -i 's/find_package(OpenMP REQUIRED)/# find_package(OpenMP REQUIRED)/g' "$f" || true
  sed -i 's/find_package(OpenMP)/# find_package(OpenMP)/g' "$f" || true

  sed -i 's/OpenMP::OpenMP_CXX//g' "$f" || true
  sed -i 's/${OpenMP_CXX_FLAGS}//g' "$f" || true
  sed -i 's/${OpenMP_CXX_LIBRARIES}//g' "$f" || true

  sed -i 's/-fopenmp=libiomp5//g' "$f" || true
  sed -i 's/-fopenmp//g' "$f" || true
done

# Install oatpp modules and other dependencies (recommended official README process)
if [ -d scripts ]; then
  pushd scripts
  bash setup-dev.sh || true
  bash install_oatpp_modules.sh || true
  popd
fi

# Official build.sh usually compiles libvectordb_dylib.so / epsilla.so using cmake/make
if [ -x build.sh ]; then
  chmod +x build.sh
  ./build.sh || true
fi

popd

# ======================================================================
# 2) Copy core .so files to link against into $OUT
# ======================================================================
ENGINE_BUILD_DIR="$SRC/vectordb/engine/build"

mkdir -p "$OUT"
CORE_LIB=""

if [ -f "$ENGINE_BUILD_DIR/libvectordb_dylib.so" ]; then
  cp "$ENGINE_BUILD_DIR/libvectordb_dylib.so" "$OUT/"
  CORE_LIB="$OUT/libvectordb_dylib.so"
elif [ -f "$ENGINE_BUILD_DIR/libvectordb.so" ]; then
  cp "$ENGINE_BUILD_DIR/libvectordb.so" "$OUT/"
  CORE_LIB="$OUT/libvectordb.so"
elif ls "$ENGINE_BUILD_DIR"/*.so 1>/dev/null 2>&1; then
  first_so="$(ls "$ENGINE_BUILD_DIR"/*.so | head -n1)"
  cp "$first_so" "$OUT/"
  CORE_LIB="$OUT/$(basename "$first_so")"
else
  echo "[-] Cannot find vectordb core shared library in $ENGINE_BUILD_DIR"
  ls -R "$ENGINE_BUILD_DIR" || true
  exit 1
fi

# Place the core so in $OUT/lib as well, so rpath = '$ORIGIN/lib' can locate it
mkdir -p "$OUT/lib"
cp "$CORE_LIB" "$OUT/lib/"

# ======================================================================
# 3) Use ldd to copy the first layer of CORE_LIB dependencies to $OUT/lib
# ======================================================================
set +e
for lib in $(ldd "$CORE_LIB" | awk '{print $3}' | grep -E '^/'); do
  cp -v "$lib" "$OUT/lib/" || true
done
set -e

# ======================================================================
# 4) Compile all vectordb_*_fuzzer.cc -> corresponding executables
# ======================================================================

INCLUDE_FLAGS="-I$SRC/vectordb/engine"

if [ -d "$SRC/vectordb/engine/include" ]; then
  INCLUDE_FLAGS="$INCLUDE_FLAGS -I$SRC/vectordb/engine/include"
fi
if [ -d "$SRC/vectordb/engine/src" ]; then
  INCLUDE_FLAGS="$INCLUDE_FLAGS -I$SRC/vectordb/engine/src"
fi
if [ -d "$ENGINE_BUILD_DIR" ]; then
  INCLUDE_FLAGS="$INCLUDE_FLAGS -I$ENGINE_BUILD_DIR"
fi

for f in "$SRC"/vectordb_*_fuzzer.cc; do
  [ -e "$f" ] || continue
  fuzzer_name=$(basename "$f" .cc)
  echo "[+] Building fuzzer $fuzzer_name from $f"

  $CXX $CXXFLAGS $INCLUDE_FLAGS \
      "$f" "$CORE_LIB" \
      $LIB_FUZZING_ENGINE $LDFLAGS \
      -std=c++17 \
      -o "$OUT/$fuzzer_name" \
      -Wl,-rpath,'$ORIGIN:$ORIGIN/lib'
done

# ======================================================================
# 5) Final Pass: ldd all ELF executables/so in /out and sweep all found deps into /out/lib
#    This helps cover most indirect dependencies
# ======================================================================
echo "[+] Sweeping all ELF binaries in /out to collect shared library deps"
for bin in "$OUT"/*; do
  if [ -f "$bin" ] && file "$bin" 2>/dev/null | grep -q 'ELF'; then
    echo "[+]   ldd $bin"
    set +e
    for lib in $(ldd "$bin" | awk '{print $3}' | grep -E '^/'); do
      cp -v "$lib" "$OUT/lib/" || true
    done
    set -e
  fi
done

# ======================================================================
# 6) Specific Case: Use ldconfig to find Boost.Filesystem and ensure it is packaged
# ======================================================================
echo "[+] Ensuring libboost_filesystem.so.1.71.x is packaged"
boost_path="$(ldconfig -p 2>/dev/null | grep 'libboost_filesystem.so.1.71' | head -n1 | awk '{print $4}')"
if [ -n "$boost_path" ] && [ -f "$boost_path" ]; then
  echo "[+]   Found via ldconfig: $boost_path"
  cp -v "$boost_path" "$OUT/lib/" || true
  cp -v "$boost_path" "$OUT/" || true
else
  echo "[!]   WARNING: libboost_filesystem.so.1.71.x not found via ldconfig"
fi

echo "[+] Final /out tree:"
ls -R "$OUT" || true

# ======================================================================
# 7) Use patchelf to write RPATH into core so and fuzzer
# ======================================================================
if command -v patchelf >/dev/null 2>&1; then
  echo "[+] Patching RPATH with patchelf"

  core_basename="$(basename "$CORE_LIB")"

  # 1) Core so in /out/lib: let it find dependencies in its own directory
  if [ -f "$OUT/lib/$core_basename" ]; then
    echo "[+]   Setting RPATH on $OUT/lib/$core_basename to \$ORIGIN"
    patchelf --set-rpath '$ORIGIN' "$OUT/lib/$core_basename" || true
  fi

  # 2) The version in the /out root (if it exists): search in both same directory and lib/
  if [ -f "$OUT/$core_basename" ]; then
    echo "[+]   Setting RPATH on $OUT/$core_basename to \$ORIGIN:\$ORIGIN/lib"
    patchelf --set-rpath '$ORIGIN:$ORIGIN/lib' "$OUT/$core_basename" || true
  fi

  # 3) All vectordb_*_fuzzer: hardcode RPATH similarly
  for bin in "$OUT"/vectordb_*_fuzzer; do
    [ -f "$bin" ] || continue
    echo "[+]   Setting RPATH on $bin to \$ORIGIN:\$ORIGIN/lib"
    patchelf --set-rpath '$ORIGIN:$ORIGIN/lib' "$bin" || true
  done
else
  echo "[!] patchelf not found; relying only on -Wl,-rpath (may break transitive deps)"
fi

echo "[+] Final /out tree:"
ls -R "$OUT" || true

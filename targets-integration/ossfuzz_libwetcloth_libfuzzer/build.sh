#!/bin/bash -eu
# Copyright 2025 Google Inc.
# ... [License Header] ...

################################################################################

LIBWETCLOTH_SRC="$SRC/libwetcloth"
BUILD_DIR="$WORK/libwetcloth_build"
FUZZ_DIR="$LIBWETCLOTH_SRC/fuzz"

###############################################################################
# 0) Hack: Fix compatibility issues between old libtbb versions and new Clang
###############################################################################
if [ -f /usr/include/tbb/task.h ]; then
  sed -i \
    's/static const kind_type binding_completed = kind_type(bound+1);/static const kind_type binding_completed = bound;/' \
    /usr/include/tbb/task.h || true
  sed -i \
    's/static const kind_type detached = kind_type(binding_completed+1);/static const kind_type detached = bound;/' \
    /usr/include/tbb/task.h || true
  sed -i \
    's/static const kind_type dying = kind_type(detached+1);/static const kind_type dying = bound;/' \
    /usr/include/tbb/task.h || true
fi

###############################################################################
# 1) Compile libWetCloth with CMake (Disable OpenGL, build library only, skip GUI Apps)
###############################################################################
mkdir -p "$BUILD_DIR"
cmake -S "$LIBWETCLOTH_SRC" -B "$BUILD_DIR" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DUSE_OPENGL=OFF

# Build the static library target "WetCloth" only to avoid GUI programs
cmake --build "$BUILD_DIR" --target WetCloth -j"$(nproc)"

###############################################################################
# 2) Collect the built libraries (static/shared)
###############################################################################
WETCLOTH_LIBS=$(find "$BUILD_DIR" -type f \( -name 'lib*.a' -o -name 'lib*.so' \) 2>/dev/null || true)

if [ -z "$WETCLOTH_LIBS" ]; then
  echo "ERROR: No static/shared libraries found in $BUILD_DIR; cannot link fuzzers." >&2
  exit 1
fi

echo "Found libraries:"
echo "$WETCLOTH_LIBS"

###############################################################################
# 3) General include paths
###############################################################################
INCLUDES=(
  "-I$LIBWETCLOTH_SRC/include"          # thirdparty (Eigen / libIGL etc.)
  "-I$LIBWETCLOTH_SRC/libWetCloth/Core"
  "-I$LIBWETCLOTH_SRC/libWetCloth/App"
  "-I/usr/include/eigen3"               # System installed Eigen (libeigen3-dev)
  "-I$LIBWETCLOTH_SRC/include/rapidxml" # rapidxml
)

###############################################################################
# 4) Dynamically fetch App source files, excluding Main.cpp which contains main()
###############################################################################
APP_SOURCES=($(find "$LIBWETCLOTH_SRC/libWetCloth/App" -name "*.cpp" ! -name "Main.cpp"))

###############################################################################
# 5) General fuzzer build function (links no OpenGL-related libraries)
###############################################################################
build_fuzzer() {
  local src="$1"   # Source file (under $FUZZ_DIR)
  local out="$2"   # Output fuzzer name (filename under /out)

  if [ ! -f "$FUZZ_DIR/$src" ]; then
    echo "Skipping $src (not present in $FUZZ_DIR)" >&2
    return
  fi

  echo "Building fuzzer $out from $src"

  $CXX $CXXFLAGS -std=c++11 \
      "${INCLUDES[@]}" \
      "$FUZZ_DIR/$src" \
      "${APP_SOURCES[@]}" \
      -Wl,--start-group $WETCLOTH_LIBS -Wl,--end-group \
      -ltbb \
      $LIB_FUZZING_ENGINE \
      -o "$OUT/$out"
}

###############################################################################
# 6) Actual fuzz targets to build
###############################################################################
build_fuzzer wetcloth_xml_scene_fuzzer.cc wetcloth_xml_scene_fuzzer
# Add more fuzzers here if needed:
# build_fuzzer wetcloth_state_binary_fuzzer.cc wetcloth_state_binary_fuzzer

###############################################################################
# 7) Package seed corpus for XML fuzzer: Use the assets/ directory in the repo
###############################################################################
if [ -d "$LIBWETCLOTH_SRC/assets" ]; then
  (cd "$LIBWETCLOTH_SRC" && \
    zip -r "$OUT/wetcloth_xml_scene_fuzzer_seed_corpus.zip" assets)
fi

###############################################################################
# 8) Copy runtime .so dependencies to /out/lib and set RPATH
###############################################################################
mkdir -p "$OUT/lib"

for f in "$OUT"/wetcloth_*_fuzzer; do
  [ -x "$f" ] || continue
  while read -r line; do
    so=$(echo "$line" | awk '{print $3}')
    if [[ -n "$so" && -f "$so" ]]; then
      cp -u "$so" "$OUT/lib/" || true
    fi
  done < <(ldd "$f" 2>/dev/null || true)
  patchelf --set-rpath '$ORIGIN/lib' "$f" || true
done

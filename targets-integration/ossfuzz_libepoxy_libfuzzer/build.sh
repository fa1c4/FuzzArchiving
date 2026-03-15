#!/bin/bash -eu
# Copyright 2025 ...
#
# libepoxy integration script written following the style 
# of existing media projects (like ffmpeg/libmpeg2).

# Source directory: $SRC/libepoxy
cd "$SRC/libepoxy"

# Perform out-of-tree build using Meson and install into $WORK
# - default_library=static: Generate static libepoxy.a for easier static linking with the fuzzer
# - docs=false, tests=false: Doxygen docs and test programs are not needed
# - glx=no, x11=false: Avoid dependencies on X11 / GLX to reduce environment complexity
meson setup _build \
    -Dprefix="$WORK/libepoxy-install" \
    -Ddefault_library=static \
    -Ddocs=false \
    -Dtests=false \
    -Dglx=no \
    -Dx11=false \
    --libdir=lib

ninja -C _build
meson install -C _build

# General include / lib paths
INCLUDE_FLAGS="-I$WORK/libepoxy-install/include -I$SRC/libepoxy/include"
LIBS="$WORK/libepoxy-install/lib/libepoxy.a"

FUZZ_DIR="$SRC/libepoxy/fuzz"

build_fuzzer () {
  local name="$1"
  local src="$FUZZ_DIR/${name}.c"
  if [ -f "$src" ]; then
    echo "Building fuzzer ${name} from ${src}"
    $CC $CFLAGS $INCLUDE_FLAGS \
        "$src" \
        $LIBS \
        $LIB_FUZZING_ENGINE $LDFLAGS \
        -o "$OUT/libepoxy_${name}_fuzzer"
  else
    echo "WARNING: ${src} not found, skipping."
  fi
}

# Drivers you need to provide:
#   $SRC/libepoxy/fuzz/fuzz_gl_version.c
#   $SRC/libepoxy/fuzz/fuzz_get_proc_address.c
build_fuzzer fuzz_gl_version
build_fuzzer fuzz_get_proc_address

# ========= Below is your preferred recursive .so copying + rpath logic =========

mkdir -p "$OUT/lib"

for bin in "$OUT"/libepoxy_*_fuzzer; do
  # Avoid cases where glob expansion fails
  if [ ! -e "$bin" ]; then
    continue
  fi

  if [ ! -x "$bin" ]; then
    continue
  fi

  echo "Collecting shared library deps for $bin"

  # Use ldd to find the absolute paths of all dependent .so files
  # (Note: some lines' third column might be "not found", filter with grep '^/')
  for lib in $(ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -E '^/' || true); do
    cp -n "$lib" "$OUT/lib/" 2>/dev/null || true
  done

  # Set RPATH=$ORIGIN/lib for the fuzzer so ClusterFuzz can locate these .so files
  if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN/lib' "$bin" || true
  fi
done

# Compile fuzz_epoxy_extension_in_string.c
$CC $CFLAGS $INCLUDE_FLAGS \
    -c $SRC/fuzz_epoxy_extension_in_string.c \
    -o $WORK/fuzz_epoxy_extension_in_string.o

# Link using the static library $LIBS prepared earlier
# $LIBS=/work/libepoxy-install/lib/libepoxy.a
$CXX $CXXFLAGS \
    $WORK/fuzz_epoxy_extension_in_string.o \
    $LIBS \
    -ldl \
    $LIB_FUZZING_ENGINE \
    -o $OUT/libepoxy_extension_in_string_fuzzer
    
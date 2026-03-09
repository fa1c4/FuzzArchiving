#!/bin/bash -eu
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# ...

# Source directory: the turbovnc repository will be cloned into $SRC/turbovnc
cd "$SRC/turbovnc"

###############################################################################
# 1. Build TurboVNC (especially the Xvnc part) normally using CMake
###############################################################################

mkdir -p build
cd build

cmake .. \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
  -DTVNC_BUILDSERVER=ON \
  -DTVNC_BUILDVIEWER=OFF \
  -DBUILD_JAVA=OFF \
  -DTJPEG_INCLUDE_DIR=/usr/include \
  -DTJPEG_LIBRARY=/usr/lib/x86_64-linux-gnu/libturbojpeg.so

# Compile all libraries and Xvnc; can be changed to `--target Xvnc` if needed
make -j"$(nproc)"

###############################################################################
# 2. Compile the fuzz harness
###############################################################################

# The harness only depends on the set of headers used by ws_decode.h / ws_decode.c;
# use the include paths from the source tree.
$CC $CFLAGS \
  -I"$SRC/turbovnc/unix/Xvnc/include" \
  -I"$SRC/turbovnc/unix/include" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/hw/vnc" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/include" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/dix" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/os" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/mi" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/Xext" \
  -I"$SRC/turbovnc/unix/Xvnc/programs/Xserver/randr" \
  -I"$SRC/turbovnc/common/rfb" \
  -I/usr/include/pixman-1 \
  -c "$SRC/turbovnc/fuzz_ws_decode.c" \
  -o fuzz_ws_decode.o

###############################################################################
# 3. Linking: Pull in all static libraries from the TurboVNC build directory
###############################################################################

# Find all lib*.a in build/
LIBS=$(find . -name 'lib*.a' -print)

# Note: These libraries do not contain main(), so linking them with the fuzz harness is fine.
# Potential system libraries needed: zlib, X11, Xext, pthread, m, ssl, crypto, etc.
# If more are needed, add them later based on link errors.
$CXX $CXXFLAGS \
  fuzz_ws_decode.o \
  $LIBS \
  -o "$OUT/fuzz_ws_decode" \
  -Wl,-rpath,'$ORIGIN' \
  $LIB_FUZZING_ENGINE \
  -lz -lpthread -lm -lssl -lcrypto

###############################################################################
# 4. Copy shared libraries required at runtime to /out
###############################################################################
RUNTIME_LIB_DIR=/usr/lib/x86_64-linux-gnu

for pattern in \
  "libX11.so*" \
  "libXext.so*" \
  "libX11-xcb.so*" \
  "libxcb.so*" \
  "libXau.so*" \
  "libXdmcp.so*" \
  "libXrender.so*" \
  "libXfixes.so*" \
  "libXtst.so*" \
  "libxshmfence.so*" \
  "libdrm.so*" \
  "libgbm.so*" \
  "libturbojpeg.so*" \
  "libssl.so*" \
  "libcrypto.so*"
do
  if ls "$RUNTIME_LIB_DIR"/$pattern >/dev/null 2>&1; then
    cp "$RUNTIME_LIB_DIR"/$pattern "$OUT"/
  fi
done

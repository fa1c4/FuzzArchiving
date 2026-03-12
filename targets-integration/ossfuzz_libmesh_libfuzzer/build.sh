#!/bin/bash -eu
# projects/libmesh/build.sh
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# ...

LIBMESH_SRC="$SRC/libmesh"
LIBMESH_INSTALL="$SRC/libmesh-install"

# 1) Build libMesh
cd "$LIBMESH_SRC"

# Running this again is fine; it ensures all submodules are complete.
git submodule update --init --recursive

mkdir -p build
cd build

# Disable MPI and large optional packages; perform a static library build.
../configure \
  CC="$CC" CXX="$CXX" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" \
  --disable-mpi \
  --disable-optional \
  --disable-shared \
  --enable-static \
  METHODS="opt" \
  --prefix="$LIBMESH_INSTALL"

make -j"$(nproc)"
make install

# 2) Build fuzzers using libmesh-config
cd "$SRC"

LIBMESH_CONFIG="$LIBMESH_INSTALL/bin/libmesh-config"

# Use only its flags, not its --cxx; maintain the use of clang/clang++ provided by OSS-Fuzz.
CXXFLAGS_FUZZ="$($LIBMESH_CONFIG --cxxflags --include)"
LDFLAGS_FUZZ="$($LIBMESH_CONFIG --ldflags --libs)"

FUZZERS="fuzz_gmsh_io"

for f in $FUZZERS; do
  $CXX $CXXFLAGS $CXXFLAGS_FUZZ -std=c++17 \
    "$SRC/${f}.cc" -o "$OUT/$f" \
    $LIB_FUZZING_ENGINE $LDFLAGS_FUZZ
done

# If a seed corpus or dictionary is required, add it here:
# cp $SRC/*.zip $OUT/ || true
# cp $SRC/*.dict $OUT/ || true

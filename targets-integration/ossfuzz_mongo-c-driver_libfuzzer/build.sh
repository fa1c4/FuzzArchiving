#!/bin/bash -eu
# mongo-c-driver / libbson / libmongoc OSS-Fuzz build script

# 1. Build and install libbson + libmongoc to $SRC/mongo-c-driver/_install
cd "$SRC/mongo-c-driver"

BUILD_DIR=_build
INSTALL_DIR="$SRC/mongo-c-driver/_install"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

cmake -S . -B "$BUILD_DIR" \
  -D ENABLE_MONGOC=ON \
  -D ENABLE_TESTS=OFF \
  -D ENABLE_EXAMPLES=OFF \
  -D ENABLE_SASL=OFF \
  -D ENABLE_SSL=OFF \
  -D ENABLE_STATIC=ON \
  -D ENABLE_SHARED=OFF \
  -D CMAKE_BUILD_TYPE=RelWithDebInfo \
  -D CMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -D CMAKE_C_COMPILER="$CC" \
  -D CMAKE_C_FLAGS="$CFLAGS"

cmake --build "$BUILD_DIR" --parallel
cmake --install "$BUILD_DIR" --prefix "$INSTALL_DIR"

# 2. Automatically detect include and static libs

# 2.1 include directories (bson-2.x.y / mongoc-2.x.y)
BSON_INCLUDE_DIR=$(ls -d "$INSTALL_DIR"/include/bson-* 2>/dev/null | head -n1 || true)
MONGOC_INCLUDE_DIR=$(ls -d "$INSTALL_DIR"/include/mongoc-* 2>/dev/null | head -n1 || true)

INCLUDES=""
if [ -n "$BSON_INCLUDE_DIR" ]; then
  INCLUDES="$INCLUDES -I$BSON_INCLUDE_DIR"
fi
if [ -n "$MONGOC_INCLUDE_DIR" ]; then
  INCLUDES="$INCLUDES -I$MONGOC_INCLUDE_DIR"
fi
# Fallback: add a generic include root directory
INCLUDES="$INCLUDES -I$INSTALL_DIR/include"

# 2.2 static libs (libmongoc*.a / libbson*.a)
LIBMONGOC=$(ls "$INSTALL_DIR"/lib/libmongoc*.a 2>/dev/null | head -n1 || true)
LIBBSON=$(ls "$INSTALL_DIR"/lib/libbson*.a 2>/dev/null | head -n1 || true)

if [ ! -f "$LIBBSON" ]; then
  echo "libbson static library not found under $INSTALL_DIR/lib" >&2
  exit 1
fi

COMMON_LIBS="$LIBBSON"
# Link mongoc together if it exists (needed by mongoc_read_prefs_fuzzer / mongoc_uri_fuzzer)
if [ -f "$LIBMONGOC" ]; then
  COMMON_LIBS="$LIBMONGOC $COMMON_LIBS"
fi

# libmongoc usually depends on these system libraries; add them in advance to avoid link errors
EXTRA_LIBS="-lpthread -lm -ldl"

# 3. Compile the three fuzzers
# Note: bson_new_from_data_fuzzer.c / mongoc_read_prefs_fuzzer.c / mongoc_uri_fuzzer.c
# are all copied to $SRC (/src) by the Dockerfile

# 3.1 libbson-only fuzzer
$CC $CFLAGS \
  $INCLUDES \
  "$SRC/bson_new_from_data_fuzzer.c" \
  "$LIBBSON" \
  $EXTRA_LIBS \
  $LIB_FUZZING_ENGINE \
  -o "$OUT/bson_new_from_data_fuzzer"

# 3.2 mongoc_read_prefs_fuzzer
$CC $CFLAGS \
  $INCLUDES \
  "$SRC/mongoc_read_prefs_fuzzer.c" \
  $COMMON_LIBS \
  $EXTRA_LIBS \
  $LIB_FUZZING_ENGINE \
  -o "$OUT/mongoc_read_prefs_fuzzer"

# 3.3 mongoc_uri_fuzzer
$CC $CFLAGS \
  $INCLUDES \
  "$SRC/mongoc_uri_fuzzer.c" \
  $COMMON_LIBS \
  $EXTRA_LIBS \
  $LIB_FUZZING_ENGINE \
  -o "$OUT/mongoc_uri_fuzzer"

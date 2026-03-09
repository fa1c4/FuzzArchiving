#!/bin/bash -eu
# Copyright 2026 Google LLC
# ...
set -eux

SRC_DIR="$SRC/libfsm"

# Remove fuzzer-no-link to avoid libFuzzer requirements during the library compilation phase; 
# ASan/UBSan flags can be kept.
HOST_CFLAGS="$(echo "$CFLAGS -O1 -fno-omit-frame-pointer" | sed 's/-fsanitize=fuzzer-no-link//g')"
HOST_LDFLAGS="$HOST_CFLAGS"

pushd "$SRC_DIR"

# Pre-build dependency files and directory tree
mkdir -p build build/pc build/lib || true
: > build/src.mk
touch -d "2037-01-01 00:00:00" build/src.mk || true
find src -type d -exec mkdir -p build/{} \;

# Build static libraries only (avoids linking the CLI)
env CC="$CC" CFLAGS="$HOST_CFLAGS" LDFLAGS="$HOST_LDFLAGS" MKDEP=":" \
  bmake -r -j1 -DNODOC build/lib/libre.a build/lib/libfsm.a

# Verify that libraries exist
test -f build/lib/libre.a  || (echo "missing build/lib/libre.a"  && exit 1)
test -f build/lib/libfsm.a || (echo "missing build/lib/libfsm.a" && exit 1)

popd

# Direct static linking (bypass pkg-config and installation steps)
INCLUDE_DIR="$SRC_DIR/include"
LIB_DIR="$SRC_DIR/build/lib"

$CC $CFLAGS \
    -I"$INCLUDE_DIR" \
    -Wall -Wextra -Wno-unused-parameter -O1 -fno-omit-frame-pointer \
    "$SRC/fuzz_regex_compile.c" \
    "$LIB_DIR/libre.a" "$LIB_DIR/libfsm.a" \
    $LIB_FUZZING_ENGINE \
    -o "$OUT/fuzz_regex_compile"

# Lightweight seed corpus & dictionary
mkdir -p "$OUT/corpus"
printf "(a|b)*abb\n[a-z]+\\d{2}\n^foo(bar|baz)?$\n" > "$OUT/corpus/seeds.txt"
zip -j "$OUT/fuzz_regex_compile_seed_corpus.zip" "$OUT/corpus/seeds.txt"

cat > "$OUT/regex.dict" << 'DICT'
"("  ")"  "["  "]"  "{"  "}"  "*"  "+"  "?"  "|"  "^"  "$"  "."  "\\d"  "\\w"  "\\s"
DICT
cp "$OUT/regex.dict" "$OUT/fuzz_regex_compile.dict"

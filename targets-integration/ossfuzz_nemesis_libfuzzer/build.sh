#!/bin/bash -eu
# OSS-Fuzz build for nemesis
# Strategy:
#   1) Bootstrap + configure: only generate build artifacts without linking the upstream executable.
#   2) Collect src/*.o (excluding nemesis.o which contains main()), and archive into libnemesis-fuzz.a.
#   3) Compile our libFuzzer harness: fuzz_print.c.
#   4) Link the final binary to /out/fuzz_nemesis_print.
#   5) Package a minimal seed corpus.

set -eux
set -o pipefail

################################################################################
# 0. Source directories
################################################################################
PROJ_DIR="$SRC/nemesis"
OUT_DIR="$OUT"

################################################################################
# 1. Autotools: Generate Makefile, etc. (no optimization on linking yet)
################################################################################
cd "$PROJ_DIR"

if [ -f ./autogen.sh ]; then
  ./autogen.sh
fi

# Use compilers and flags injected by OSS-Fuzz; 
# Remove fuzzer-no-link to compile objects before the final linking stage.
HOST_CFLAGS="$(echo "$CFLAGS -O1 -fno-omit-frame-pointer" | sed 's/-fsanitize=fuzzer-no-link//g')"
HOST_CXXFLAGS="$(echo "$CXXFLAGS -O1 -fno-omit-frame-pointer" | sed 's/-fsanitize=fuzzer-no-link//g')"

./configure CC="$CC" CXX="$CXX" \
  CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS"

# Only compile object files; some versions might fail during the final link, 
# so we tolerate non-zero exits as long as the .o files are generated.
make -j"$(nproc)" || true

################################################################################
# 2. Compile objects required for "print/dump" path + provide local stubs for missing symbols
################################################################################
cd "$PROJ_DIR"

mkdir -p src/fuzzobj
cd src/fuzzobj

INC="-I$PROJ_DIR/src -I$PROJ_DIR"

# Required: hexdump/printing implementation
$CC $HOST_CFLAGS $INC -c "$PROJ_DIR/src/nemesis-printout.c" -o nemesis-printout.o

# Provide local stubs for missing strlcpy/strlcat and global errbuf
cat > fuzz_stubs.c << 'EOF'
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#ifndef LIBNET_ERRBUF_SIZE
#define LIBNET_ERRBUF_SIZE 512
#endif

/* nemesis-printout.c references this global buffer */
char errbuf[LIBNET_ERRBUF_SIZE];

/* Simple, compatible strlcpy/strlcat implementation (BSD semantics) */
size_t strlcpy(char *dst, const char *src, size_t siz) {
    size_t srclen = strlen(src);
    if (siz) {
        size_t n = (srclen >= siz) ? siz - 1 : srclen;
        memcpy(dst, src, n);
        dst[n] = '\0';
    }
    return srclen;
}

size_t strlcat(char *dst, const char *src, size_t siz) {
    size_t dlen = strnlen(dst, siz);
    size_t srclen = strlen(src);
    if (dlen == siz) return dlen + srclen; /* no space */
    size_t n = siz - dlen - 1;
    if (n > 0) {
        size_t tocopy = srclen < n ? srclen : n;
        memcpy(dst + dlen, src, tocopy);
        dst[dlen + tocopy] = '\0';
    }
    return dlen + srclen;
}
EOF

$CC $HOST_CFLAGS $INC -c fuzz_stubs.c -o fuzz_stubs.o

# Create a static library with only the minimal set of objects to avoid libnet dependencies
ar rcs libnemesis-fuzz.a nemesis-printout.o fuzz_stubs.o

################################################################################
# 3. Compile libFuzzer harness
################################################################################
$CC $CFLAGS -I"$PROJ_DIR/src" -I"$PROJ_DIR" -c "$SRC/fuzz_print.c" -o fuzz_print.o

################################################################################
# 4. Link final fuzzer (without introducing libnet)
################################################################################
$CXX $CXXFLAGS fuzz_print.o -o "$OUT_DIR/fuzz_nemesis_print" \
  libnemesis-fuzz.a $LIB_FUZZING_ENGINE


################################################################################
# 5. Seed corpus
################################################################################
mkdir -p seed
printf "GET / HTTP/1.1\r\n\r\n" > seed/http_like.bin
printf "\x00\x01\x02\x03\xff" > seed/binary.bin
zip -r "$OUT_DIR/fuzz_nemesis_print_seed_corpus.zip" seed >/dev/null

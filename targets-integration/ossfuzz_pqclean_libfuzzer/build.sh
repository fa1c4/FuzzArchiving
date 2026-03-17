#!/bin/bash

# Install necessary packages
apt-get update && apt-get install -y make llvm

# Set up environment variables with required include paths
if [ -z "${CFLAGS:-}" ]; then
  CFLAGS="-I$SRC -I$SRC/PQClean.git/common -I$SRC/PQClean.git/crypto_kem/ml-kem-768/clean"
else
  CFLAGS="$CFLAGS -I$SRC -I$SRC/PQClean.git/common -I$SRC/PQClean.git/crypto_kem/ml-kem-768/clean"
fi

if [ -z "${CXXFLAGS:-}" ]; then
  CXXFLAGS="-I$SRC -I$SRC/PQClean.git/common -I$SRC/PQClean.git/crypto_kem/ml-kem-768/clean"
else
  CXXFLAGS="$CXXFLAGS -I$SRC -I$SRC/PQClean.git/common -I$SRC/PQClean.git/crypto_kem/ml-kem-768/clean"
fi

# Navigate to the project directory
cd $SRC/PQClean.git

# Build common components
cd common
$CC $CFLAGS -c aes.c sha2.c fips202.c nistseedexpander.c sp800-185.c randombytes.c
cd ..

# Build the specific target scheme (ML-KEM-768 clean implementation)
# We use EXTRAFLAGS to pass the required namespace and environment CFLAGS
cd crypto_kem/ml-kem-768/clean
make clean
make CC="$CC" EXTRAFLAGS="-DPQCLEAN_NAMESPACE=PQCLEAN_MLKEM768_CLEAN $CFLAGS"
cd ../../../

# Collect all object files into a single static library for the fuzzer
# This includes both the scheme-specific objects and the common cryptographic primitives
llvm-ar r $SRC/PQClean.git/libtarget.a \
    $SRC/PQClean.git/common/aes.o \
    $SRC/PQClean.git/common/sha2.o \
    $SRC/PQClean.git/common/fips202.o \
    $SRC/PQClean.git/common/nistseedexpander.o \
    $SRC/PQClean.git/common/sp800-185.o \
    $SRC/PQClean.git/common/randombytes.o \
    $SRC/PQClean.git/crypto_kem/ml-kem-768/clean/*.o

# Compile and link the fuzzing harness
$CC $CFLAGS $LIB_FUZZING_ENGINE $SRC/empty-fuzzer.c \
    -o $OUT/empty-fuzzer \
    -I$SRC/PQClean.git/common \
    -I$SRC/PQClean.git/crypto_kem/ml-kem-768/clean \
    -Wl,--whole-archive $SRC/PQClean.git/libtarget.a -Wl,--no-whole-archive
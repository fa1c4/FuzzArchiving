#!/bin/bash -eu
# Build fuzzers for par

# Source code is in $SRC/par
cd $SRC/par

# Common compilation flags
# -std=c99 is the official recommended standard for par
COMMON_FLAGS="$CFLAGS -std=c99 -Wall -Wextra -Wno-unused-parameter"

# par_msquares_fuzzer (marching squares)
$CC $COMMON_FLAGS \
    -I$SRC/par \
    fuzz_msquares.c \
    -o $OUT/par_msquares_fuzzer \
    $LIB_FUZZING_ENGINE -lm

# par_streamlines_fuzzer (wide lines & curves)
$CC $COMMON_FLAGS \
    -I$SRC/par \
    fuzz_streamlines.c \
    -o $OUT/par_streamlines_fuzzer \
    $LIB_FUZZING_ENGINE -lm

# par_shapes_lsystem_fuzzer (L-system parser)
$CC $COMMON_FLAGS \
    -I$SRC/par \
    fuzz_par_shapes_lsystem.c \
    -o $OUT/par_shapes_lsystem_fuzzer \
    $LIB_FUZZING_ENGINE -lm

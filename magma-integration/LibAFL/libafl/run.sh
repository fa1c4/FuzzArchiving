#!/bin/bash -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

export ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:malloc_context_size=0:symbolize=0:allocator_may_return_null=1:detect_odr_violation=0:handle_segv=0:handle_sigbus=0:handle_abort=0:handle_sigfpe=0:handle_sigill=0"
export UBSAN_OPTIONS="abort_on_error=1:allocator_release_to_os_interval_ms=500:handle_abort=0:handle_segv=0:handle_sigbus=0:handle_sigfpe=0:handle_sigill=0:print_stacktrace=0:symbolize=0:symbolize_inline_frames=0"

mkdir -p "$SHARED/findings"

"$OUT/$PROGRAM" \
    -i "$TARGET/corpus/$PROGRAM" \
    -o "$SHARED/findings" \
    $FUZZARGS

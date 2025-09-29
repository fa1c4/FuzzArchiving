#!/bin/bash
# need to echo "core" | sudo tee /proc/sys/kernel/core_pattern at the host machine
##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
##
set +e

export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

mkdir -p "$SHARED/findings"
OUTDIR="${SHARED}/findings"
SEEDS_DIR="$TARGET/corpus/$PROGRAM"
TARGET_BIN="$OUT/afl/$PROGRAM"

flag_cmplog=(-m none -c "$OUT/cmplog/$PROGRAM")

[[ -d "$SEEDS_DIR"  ]] || { echo "[-] seeds dir not found: $SEEDS_DIR";  exit 2; }
[[ -x "$TARGET_BIN" ]] || { echo "[-] target bin not found/executable: $TARGET_BIN"; exit 2; }

export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1
export AFL_NO_UI=1
export AFL_MAP_SIZE=256000
# export AFL_DRIVER_DONT_DEFER=1

# clean_mb_dirs() {
#   rm -rf \
#     "$OUTDIR/default/mb_seeds" \
#     "$OUTDIR/default/mb_record" \
#     "$OUTDIR/default/subseeds" 2>/dev/null || true
# }
clean_mb_dirs() {
  rm -rf "$OUTDIR/default" || true
}

# "$FUZZER/repo/afl-fuzz" -i "$TARGET/corpus/$PROGRAM" -o "$SHARED/findings" \
#     "${flag_cmplog[@]}" -d \
#     $FUZZARGS -- "$OUT/afl/$PROGRAM" $ARGS 2>&1


run_mode() {
    local mode="$1"; shift
    local timeout_ms="${1:-5000}"

    clean_mb_dirs

    echo "running bazzafl with -z $mode"

    # "${flag_cmplog[@]}" \
    "$FUZZER/repo/afl-fuzz" \
        -i "$SEEDS_DIR" -o "$OUTDIR" \
        -d -z "$mode" -t "$timeout_ms" -- \
        "$TARGET_BIN" ${ARGS:-}
    local rc=$?
    return "$rc"
}

# try 4→3→2→1→0
final_rc=1
for mode in 4 3 2 1 0; do
  echo "[*] Trying BazzAFL mode: -z $mode"
  run_mode "$mode" 6000
  rc=$?

  if [[ $rc -eq 0 ]]; then
    exit 0
  fi

  echo "[!] afl-fuzz with -z $mode exited rc=$rc"
  if [[ $rc -eq 139 ]]; then
    echo "[!] Segmentation fault detected at -z $mode (maybe P empty: BazzAFL bug)"
  fi

  final_rc=$rc
done

exit "$final_rc"

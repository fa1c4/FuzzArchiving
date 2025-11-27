#!/bin/bash -eu
# projects/kate/build.sh
# SPDX-License-Identifier: Apache-2.0

FUZZ_SRC="$SRC/kate/fuzz_kate_fuzzy_match.cpp"

# Use Qt5 (Ubuntu 20.04 provides Qt 5.12.x)
if pkg-config --exists Qt5Core; then
  # We need QtCore and QtGui headers (the original kfts_fuzzy_match.h includes QTextLayout, etc.)
  QT_CFLAGS="$(pkg-config --cflags Qt5Core Qt5Gui)"
  # But we only link against Qt5Core, not Qt5Gui, to avoid a libGL dependency
  QT_LIBS="$(pkg-config --libs Qt5Core)"
else
  echo "Qt5 (qtbase5-dev) is required: pkg-config cannot find Qt5Core." >&2
  exit 1
fi

# 0) Prepare a modified kfts_fuzzy_match header under $WORK
MOD_DIR="$WORK/kate_ossfuzz"
mkdir -p "$MOD_DIR"
cp "$SRC/kate/apps/lib/kfts_fuzzy_match.h" \
   "$MOD_DIR/kfts_fuzzy_match_ossfuzz.h"

# Replace all QStringView with QString so the implementation uses QString APIs
# (this avoids differences in Qt5's QStringView APIs)
sed -i 's/QStringView/QString/g' \
   "$MOD_DIR/kfts_fuzzy_match_ossfuzz.h"

# 1) Build the fuzzer: set rpath to $ORIGIN/lib
OUT_LIB="$OUT/lib"
mkdir -p "$OUT_LIB"

$CXX $CXXFLAGS -std=c++17 \
  $QT_CFLAGS \
  -I"$MOD_DIR" \
  "$FUZZ_SRC" \
  -o "$OUT/fuzz_kate_fuzzy_match" \
  $LIB_FUZZING_ENGINE \
  $QT_LIBS \
  -Wl,-rpath,'$ORIGIN/lib' -Wl,--disable-new-dtags

# 2) Recursively copy fuzz_kate_fuzzy_match and all of its .so dependencies into /out/lib
copy_dep() {
  local lib="$1"
  if [ -z "$lib" ] || [ ! -f "$lib" ]; then
    return
  fi
  local dest="$OUT_LIB/$(basename "$lib")"
  # Skip if it has already been copied
  if [ -f "$dest" ]; then
    return
  fi
  echo "Copying dep: $lib -> $dest"
  cp -v "$lib" "$dest"
}

# Only take absolute paths (starting with /) from ldd output to avoid garbage tokens like "not"
seed_libs=$(ldd "$OUT/fuzz_kate_fuzzy_match" \
  | awk '{print $3}' \
  | sed -n 's|^\(/.*\)|\1|p')

queue="$seed_libs"
seen=""

while [ -n "$queue" ]; do
  new_queue=""
  for lib in $queue; do
    # De-duplicate: skip dependencies that have already been processed
    case " $seen " in *" $lib "*) continue ;; esac
    seen="$seen $lib"

    # Copy the current dependency
    copy_dep "$lib"

    # Run ldd on the current library and recursively collect its dependencies
    for dep in $(ldd "$lib" \
      | awk '{print $3}' \
      | sed -n 's|^\(/.*\)|\1|p'); do
      case " $seen " in *" $dep "*) ;; *) new_queue="$new_queue $dep" ;; esac
    done
  done
  queue="$new_queue"
done

#!/bin/bash -eu
# oss-fuzz/projects/libtorrent/build.sh

# 1) Build and install libtorrent (static)
cd "$SRC/libtorrent"

# Some base images lack a generated configure script; follow README recommendations
autoreconf -ivf

# Build static library only to avoid linking to system shared libraries later
# Disable examples/tests (they aren't installed by default, so keeping them is fine)
./configure \
  --enable-static --disable-shared \
  CC="$CC" CXX="$CXX" \
  CFLAGS="$CFLAGS -fno-omit-frame-pointer -O1" \
  CXXFLAGS="$CXXFLAGS -fno-omit-frame-pointer -O1" \
  LDFLAGS="$CFLAGS"

make -j"$(nproc)"
make install

# pkg-config sometimes installs to /usr/local/lib/pkgconfig; ensure it's found
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# 2) Compile fuzz targets
# Common includes and libraries (retrieved via pkg-config)
PC_CFLAGS="$(pkg-config --cflags libtorrent || true)"
PC_LIBS="$(pkg-config --libs --static libtorrent || true)"

# If pkg-config is unavailable, fall back to common installation paths
INC_FALLBACK="-I/usr/local/include -I/usr/include"
LIB_FALLBACK="-L/usr/local/lib -L/usr/lib -ltorrent -lcurl -lssl -lcrypto -lz -lpthread"

CXXFLAGS_ALL="${CXXFLAGS} -std=c++17 -fno-omit-frame-pointer -O1 ${PC_CFLAGS:-$INC_FALLBACK}"
LIBS_ALL="${LIB_FUZZING_ENGINE} ${PC_LIBS:-$LIB_FALLBACK}"

# fuzz_bencode
$CXX $CXXFLAGS_ALL "$SRC/fuzz_bencode.cc" -o "$OUT/fuzz_bencode" $LIBS_ALL

# fuzz_metainfo
$CXX $CXXFLAGS_ALL "$SRC/fuzz_metainfo.cc" -o "$OUT/fuzz_metainfo" $LIBS_ALL

# 3) Optional: Provide some seed corpus for .torrent / bencode (empty zip is also fine)
# This step can be supplemented with real corpora locally later
zip -q -r "$OUT/fuzz_bencode_seed_corpus.zip" /dev/null || true
zip -q -r "$OUT/fuzz_metainfo_seed_corpus.zip" /dev/null || true

# 4) Default options for libFuzzer
cat > "$OUT/fuzz_bencode.options" <<'EOF'
[libfuzzer]
max_len = 1048576
timeout = 25
EOF

cp "$OUT/fuzz_bencode.options" "$OUT/fuzz_metainfo.options"

#!/bin/bash
set -euo pipefail

# Expectations:
# - Running as user 'magma' during fuzzers/libfuzzer/instrument.sh
# - Env provided by Dockerfile + libfuzzer/instrument.sh:
#     CC, CXX, CFLAGS, CXXFLAGS, LDFLAGS, LIBS
#     TARGET (e.g. /magma/targets/liblua)
#     OUT    (e.g. /magma_out)
# - $TARGET/fetch.sh already cloned Lua source to $TARGET/repo

if [ ! -d "${TARGET}/repo" ]; then
    echo "[liblua] ERROR: repo not found. Did fetch.sh run?" >&2
    exit 1
fi

echo "[liblua] Building liblua.a with CC=${CC}"

pushd "${TARGET}/repo" >/dev/null

# clean first to avoid mixing objects from previous builds
make -j"$(nproc)" clean || true

# Build static liblua.a.
# We deliberately DO NOT override AR/RANLIB here,
# because Lua's Makefile expects AR="ar rcu" style, not just "ar".
# We only inject CC/MYCFLAGS/MYLDFLAGS to pick up Magma's instrumentation.
make -j"$(nproc)" \
    CC="${CC}" \
    MYCFLAGS="${CFLAGS}" \
    MYLDFLAGS="${LDFLAGS}" \
    liblua.a

cp -f liblua.a "${OUT}/"

popd >/dev/null

echo "[liblua] Building fuzz harness (lua_fuzzer)..."

# We'll compile lua_fuzzer.c and link it with:
#   - the freshly built liblua.a
#   - $LIBS   (set by libfuzzer/instrument.sh: driver.o, libFuzzer.a, -lstdc++)
#   - plus Lua runtime deps: -lm -ldl -lpthread
#
# Lua headers live directly under $TARGET/repo (official Lua layout).

LUA_INC="${TARGET}/repo"

${CC} ${CFLAGS} ${LDFLAGS} \
    -I"${LUA_INC}" \
    "${TARGET}/lua_fuzzer.c" \
    "${OUT}/liblua.a" \
    ${LIBS} \
    -lm -ldl -lpthread \
    -o "${OUT}/lua_fuzzer"

echo "[liblua] Build complete. Artifacts in ${OUT}:"
ls -l "${OUT}/lua_fuzzer" "${OUT}/liblua.a" || true

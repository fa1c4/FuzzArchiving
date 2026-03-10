# oss-fuzz/projects/libtorrent/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

# libtorrent is an autotools project; these dependencies are required
RUN apt-get update && apt-get install -y \
    autoconf automake libtool pkg-config \
    libsigc++-2.0-dev zlib1g-dev libssl-dev libcurl4-openssl-dev \
    make cmake git

# Pull source code (following OSS-Fuzz convention: place in $SRC/libtorrent)
RUN git clone --depth 1 https://github.com/rakshasa/libtorrent.git libtorrent

# Copy build script and fuzzer source files
WORKDIR /src
COPY build.sh fuzz_bencode.cc fuzz_metainfo.cc $SRC/

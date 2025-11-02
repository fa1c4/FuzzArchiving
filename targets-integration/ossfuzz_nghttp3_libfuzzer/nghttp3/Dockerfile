# Base OSS-Fuzz builder image
FROM gcr.io/oss-fuzz-base/base-builder

# Install build deps for nghttp3
RUN apt-get update && apt-get install -y \
    make \
    autoconf \
    automake \
    libtool \
    pkg-config \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Fetch nghttp3 (shallow clone for speed)
RUN git clone --recursive --shallow-submodules --depth 1 https://github.com/ngtcp2/nghttp3.git

# All subsequent work is in the repo
WORKDIR nghttp3

# Copy build scripts from oss-fuzz into the image
COPY build.sh run_tests.sh *.options $SRC/

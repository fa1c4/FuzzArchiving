# oss-fuzz/projects/nemesis/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

# Build dependencies: Autotools + libnet development headers
RUN apt-get update && apt-get install -y \
    autoconf automake libtool pkg-config \
    make gcc g++ \
    libnet1-dev \
 && rm -rf /var/lib/apt/lists/*

# Pull source code (upstream repository)
RUN git clone --depth 1 https://github.com/libnet/nemesis.git nemesis

WORKDIR $SRC
COPY build.sh $SRC/
COPY fuzz_print.c $SRC/

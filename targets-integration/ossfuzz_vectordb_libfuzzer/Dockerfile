FROM gcr.io/oss-fuzz-base/base-builder

RUN apt install -y valgrind gdb

# Pull source code
RUN git clone --depth 1 https://github.com/epsilla-cloud/vectordb.git "$SRC/vectordb"

# Install build dependencies
# - libboost-dev: Provides Boost headers and other basics
# - libboost-filesystem-dev: Provides Boost.Filesystem library and CMake config (fixes "missing: filesystem")
# - pkg-config + libcurl4-openssl-dev: Locate libcurl for oatpp-curl
# - libomp-dev: Provides omp.h, avoiding "<omp.h> not found" error
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake ninja-build python3 python3-pip \
    libssl-dev zlib1g-dev \
    libboost-dev \
    libboost-filesystem-dev \
    pkg-config \
    libcurl4-openssl-dev \
    libomp-dev \
    patchelf \
    && rm -rf /var/lib/apt/lists/*

# Copy oss-fuzz project scripts & fuzzer source code
COPY build.sh $SRC/
COPY vectordb_*.cc $SRC/

WORKDIR $SRC

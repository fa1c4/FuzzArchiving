# oss-fuzz/projects/rmg/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

# Only keep dependencies needed for RMG-Core build here; do not install Qt6/SDL3
RUN apt-get update && apt-get install -y \
    git cmake ninja-build pkg-config nasm patchelf \
    libusb-1.0-0-dev libhidapi-dev \
    libsamplerate0-dev libspeex-dev libspeexdsp-dev \
    libminizip-dev zlib1g-dev \
    libsdl2-dev \
    libfreetype6-dev libpng-dev \
    libgl1-mesa-dev libglu1-mesa-dev \
    libcurl4-openssl-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Fetch RMG source code
RUN git clone --depth 1 https://github.com/Rosalie241/RMG.git /src/RMG

WORKDIR /src

# Copy build.sh and fuzz harness source code in
COPY build.sh \
     cheats_fuzzer.cc \
     archive_fuzzer.cc \
     vru_fuzzer.cc \
     $SRC/
     
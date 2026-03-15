# Copyright 2025
#
# Vangers integration for OSS-Fuzz (RLE only for now).
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder

RUN apt-get update && \
    apt-get install -y \
        cmake \
    && rm -rf /var/lib/apt/lists/*

# Clone the target project
RUN git clone --depth 1 https://github.com/KranX/Vangers.git Vangers

# Currently only fuzzing RLE, so only copy these two files
COPY build.sh \
     vangers_rle_fuzzer.cc \
     $SRC/

WORKDIR $SRC

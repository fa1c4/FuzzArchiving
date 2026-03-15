# Copyright 2025 Google LLC
# ... (License header) ...

FROM gcr.io/oss-fuzz-base/base-builder

# Fetch CorsairLightingProtocol source code
RUN git clone https://github.com/Legion2/CorsairLightingProtocol.git

# Change to source directory (actual compilation logic resides in build.sh)
WORKDIR $SRC/CorsairLightingProtocol

# Copy build scripts and fuzzer source code
COPY build.sh run_tests.sh $SRC/
COPY fuzz_* $SRC/

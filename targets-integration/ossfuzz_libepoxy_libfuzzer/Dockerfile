FROM gcr.io/oss-fuzz-base/base-builder

# Basic build dependencies: Meson + Ninja + Headers (EGL)
RUN apt-get update && \
    apt-get install -y \
        meson \
        ninja-build \
        pkg-config \
        python3 \
        python3-pip \
        libegl1-mesa-dev \
        patchelf && \
    rm -rf /var/lib/apt/lists/*

# Upgrade meson/ninja (optional)
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -U "meson==1.7.2" ninja

# Fetch upstream source code
RUN git clone --depth 1 https://github.com/anholt/libepoxy.git libepoxy

# Copy the OSS-Fuzz build script and fuzzer source code
COPY build.sh fuzz_epoxy_extension_in_string.c $SRC/

# Default working directory points to the source
WORKDIR /src/libepoxy

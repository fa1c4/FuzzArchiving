FROM gcr.io/oss-fuzz-base/base-builder

# Install build dependencies for TurboVNC
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cmake make pkg-config \
        libturbojpeg0-dev \
        libjpeg-turbo8-dev libx11-dev libxext-dev libxrender-dev \
        libxtst-dev libxfixes-dev libssl-dev \
        libpixman-1-dev zlib1g-dev \
        libxfont-dev \
        libgl1-mesa-dev \
        libdrm-dev \
        libpam0g-dev \
        libgbm-dev \
        mesa-common-dev \
        libxshmfence-dev \
        libxkbfile-dev && \
    rm -rf /var/lib/apt/lists/*

# Fetch TurboVNC source code
RUN git clone --depth=1 https://github.com/TurboVNC/turbovnc.git $SRC/turbovnc

# Copy the build script
COPY build.sh $SRC/

# Copy the fuzz harness source code to the root of the turbovnc repository
COPY fuzz_ws_decode.c $SRC/turbovnc/

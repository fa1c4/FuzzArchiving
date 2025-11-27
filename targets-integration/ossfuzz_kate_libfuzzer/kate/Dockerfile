# projects/kate/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

# Install dependencies needed to build the fuzz target: pkg-config + Qt5 Core/Gui
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        pkg-config \
        qtbase5-dev \
        && \
    rm -rf /var/lib/apt/lists/*

# Clone Kate sources to obtain apps/lib/kfts_fuzzy_match.h and related headers
RUN git clone --depth 1 https://github.com/KDE/kate.git "$SRC/kate"

# Copy OSS-Fuzz project files
COPY build.sh                  "$SRC/"
COPY fuzz_kate_fuzzy_match.cpp "$SRC/kate/"
COPY project.yaml              "$SRC/"

WORKDIR "$SRC/kate"

FROM gcr.io/oss-fuzz-base/base-builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y \
        autoconf \
        automake \
        libtool \
        gettext \
        autopoint \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/laurikari/tre.git tre

COPY . $SRC/
WORKDIR $SRC/tre

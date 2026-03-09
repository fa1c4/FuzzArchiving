FROM gcr.io/oss-fuzz-base/base-builder

# bmake is required; doc-related packages can be kept (we use NODOC), or removed
RUN apt-get update && apt-get install -y --no-install-recommends \
    bmake pkg-config libxml2-utils xsltproc docbook-xml docbook-xsl \
    && rm -rf /var/lib/apt/lists/*

# Must use --recursive to fetch submodules
RUN git clone --recursive https://github.com/katef/libfsm.git

WORKDIR /src
COPY build.sh $SRC/
COPY fuzz_regex_compile.c $SRC/
WORKDIR /src/libfsm

# Copyright 2025 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder

# Install build dependencies:
# - pkg-config, various compression libraries, libpcap: nfdump dependencies
# - patchelf: used later to set rpath=$ORIGIN/lib
# - wget: download nfdump source code release
# - autoconf/automake/libtool/flex/bison: required for running autogen.sh / configure
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        pkg-config \
        libbz2-dev \
        liblz4-dev \
        libzstd-dev \
        libpcap-dev \
        patchelf \
        wget \
        autoconf \
        automake \
        libtool \
        flex \
        bison && \
    rm -rf /var/lib/apt/lists/*

# Fetch upstream nfdump v1.7.7 source (includes configure.ac + autogen.sh, requires running autogen.sh)
WORKDIR /src
RUN wget -O nfdump.tar.gz \
      https://github.com/phaag/nfdump/archive/refs/tags/v1.7.7.tar.gz && \
    tar xzf nfdump.tar.gz && \
    mv nfdump-1.7.7 nfdump && \
    rm nfdump.tar.gz

# nfdump will be built in /src/nfdump
WORKDIR /src/nfdump

# Copy build script and fuzz entry points
COPY build.sh /src/
COPY fuzz_*.cc /src/
COPY fuzz_*.c  /src/

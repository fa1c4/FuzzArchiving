# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG parent_image
FROM $parent_image

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        python3-dev \
        python3-setuptools \
        automake \
        cmake \
        git \
        flex \
        bison \
        libglib2.0-dev \
        libpixman-1-dev \
        cargo \
        libgtk-3-dev \
        # for QEMU mode
        ninja-build \
        gcc-$(gcc --version|head -n1|sed 's/\..*//'|sed 's/.* //')-plugin-dev \
        libstdc++-$(gcc --version|head -n1|sed 's/\..*//'|sed 's/.* //')-dev

# install llvm-13
# RUN rm -f /usr/local/bin/clang /usr/local/bin/clang++ /usr/local/bin/llvm-config && \
#     apt-get update && apt-get install -y --fix-missing \
#     wget \
#     lsb-release \
#     gnupg \
#     software-properties-common \
#     curl && \
#     wget https://apt.llvm.org/llvm-snapshot.gpg.key && \
#     apt-key add llvm-snapshot.gpg.key && \
#     wget https://apt.llvm.org/llvm.sh && \
#     chmod +x llvm.sh && \
#     ./llvm.sh 13 && \
#     apt-get install -y llvm-13-dev llvm-13-tools && \
#     update-alternatives --install /usr/local/bin/clang clang /usr/bin/clang-13 100 && \
#     update-alternatives --install /usr/local/bin/clang++ clang++ /usr/bin/clang++-13 100 && \
#     update-alternatives --install /usr/local/bin/llvm-config llvm-config /usr/bin/llvm-config-13 100

RUN rm -f /usr/local/bin/clang /usr/local/bin/clang++ /usr/local/bin/llvm-config && \
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz && \
    tar -xf clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz -C /opt && \
    rm clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz && \
    ln -sf /opt/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04/bin/* /usr/local/bin/

# Download BazzAFL.
RUN git clone https://github.com/BazzAFL/BazzAFL.git /afl

# Build without Python support as we don't need it.
# Set AFL_NO_X86 to skip flaky tests.
RUN cd /afl && \
    unset CFLAGS CXXFLAGS && \
    export CC=clang AFL_NO_X86=1 && \
    PYTHON_INCLUDE=/ make CFLAGS="-O2 -fcommon" && \
    cp utils/aflpp_driver/libAFLDriver.a /

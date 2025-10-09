#!/bin/bash
set -ex

apt-get update && \
    apt-get install -y git wget curl \
                       gnupg lsb-release software-properties-common

alias curl="curl --proto '=https' --tlsv1.2 -sSf"

add-apt-repository -y ppa:ubuntu-toolchain-r/test

curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 17
rm -f llvm.sh

# clang/llvm alternatives
update-alternatives \
  --install /usr/lib/llvm llvm /usr/lib/llvm-17 20 \
  --slave /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-17 \
  --slave /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-17 \
  --slave /usr/bin/llvm-as llvm-as /usr/bin/llvm-as-17 \
  --slave /usr/bin/llvm-dis llvm-dis /usr/bin/llvm-dis-17 \
  --slave /usr/bin/llvm-nm llvm-nm /usr/bin/llvm-nm-17 \
  --slave /usr/bin/llvm-objdump llvm-objdump /usr/bin/llvm-objdump-17 \
  --slave /usr/bin/llvm-ranlib llvm-ranlib /usr/bin/llvm-ranlib-17 \
  --slave /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-17

update-alternatives \
  --install /usr/bin/clang clang /usr/bin/clang-17 20 \
  --slave /usr/bin/clang++ clang++ /usr/bin/clang++-17 \
  --slave /usr/bin/clang-cpp clang-cpp /usr/bin/clang-cpp-17

apt-get install -y libjemalloc2

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /rustup.sh
sudo -u magma -H sh /rustup.sh --default-toolchain nightly-2024-08-12 -y

# preinstall.sh
set -e

# llvm-13 is not available
# apt-get update && \
#   DEBIAN_FRONTEND=noninteractive apt-get install -y \
#     wget software-properties-common ca-certificates gnupg \
#     build-essential git pkg-config \
#     clang-13 lldb-13 lld-13 llvm-13 llvm-13-dev \
#     libc++-13-dev libc++abi-13-dev \
#     libglib2.0-dev \
#     make python3 python3-pip

# use prebuilt binaries from apt.llvm.org
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  wget curl ca-certificates gnupg2 lsb-release \
  build-essential git pkg-config \
  libglib2.0-dev \
  libtinfo-dev \
  make python3 python3-pip xz-utils \
  libc++1 libc++abi1

. /etc/os-release || true
codename="${VERSION_CODENAME:-focal}"
LLVM_VER="13.0.0"
if [ "$codename" = "bionic" ]; then
  CANDIDATES="clang+llvm-${LLVM_VER}-x86_64-linux-gnu-ubuntu-16.04.tar.xz clang+llvm-${LLVM_VER}-x86_64-linux-gnu-ubuntu-20.04.tar.xz"
else
  CANDIDATES="clang+llvm-${LLVM_VER}-x86_64-linux-gnu-ubuntu-20.04.tar.xz clang+llvm-${LLVM_VER}-x86_64-linux-gnu-ubuntu-16.04.tar.xz"
fi

TMP_TAR=""
LLVM_DIR=""
for pkg in ${CANDIDATES}; do
  url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/${pkg}"
  out="/tmp/${pkg}"
  echo "[*] Trying ${url}"
  if curl -L --fail -o "${out}" "${url}" || wget -O "${out}" "${url}"; then
    tar -tf "${out}" >/dev/null
    TMP_TAR="${out}"
    LLVM_DIR="/opt/${pkg%.tar.xz}"
    break
  fi
done

if [ -z "$TMP_TAR" ]; then
  echo "[-] No suitable LLVM 13 tarball found for ${codename}."
  exit 1
fi

rm -f /usr/local/bin/clang /usr/local/bin/clang++ /usr/local/bin/llvm-config \
      /usr/bin/clang /usr/bin/clang++ /usr/bin/llvm-config || true

mkdir -p /opt
tar -xf "$TMP_TAR" -C /opt
rm -f "$TMP_TAR"
ln -sf "${LLVM_DIR}/bin/"* /usr/local/bin/

# rm -f /usr/local/bin/clang /usr/local/bin/clang++ /usr/local/bin/llvm-config /usr/bin/clang /usr/bin/clang++ /usr/bin/llvm-config && \
#     wget https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz && \
#     tar -xf clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz -C /opt && \
#     rm clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz && \
#     ln -sf /opt/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04/bin/* /usr/local/bin/

# set default clang/llvm
if [ -x /usr/local/bin/clang ] && [ -x /usr/local/bin/llvm-config ]; then
  update-alternatives \
    --install /usr/bin/clang       clang       /usr/local/bin/clang       100 \
    --slave   /usr/bin/clang++     clang++     /usr/local/bin/clang++ \
    --slave   /usr/bin/clang-cpp   clang-cpp   /usr/local/bin/clang-cpp

  update-alternatives \
    --install /usr/bin/llvm-config llvm-config /usr/local/bin/llvm-config 100
else
  echo "[-] LLVM binaries not found under /usr/local/bin after extraction."
  ls -l /usr/local/bin | sed -n '1,200p' || true
  exit 2
fi

# if [ "$codename" = "bionic" ]; then
#   apt-get install -y --no-install-recommends libtinfo5 || true
# fi

export AFL_NO_X86=1

# ldconfig
RES_DIR="$(clang -print-resource-dir)"                # e.g. /opt/clang+llvm-13.0.0-.../lib/clang/13.0.0
RT_DIR="${RES_DIR}/lib/linux"                         # contains libclang_rt.*.so

if [ -d "$RT_DIR" ]; then
  echo "$RT_DIR" > /etc/ld.so.conf.d/clangrt.conf
  ldconfig
fi
export LD=ld 

# test
echo "[+] clang path: $(command -v clang)"
echo "[+] llvm-config path: $(command -v llvm-config)"
clang --version || (echo "[-] clang not working"; exit 2)
llvm-config --version || (echo "[-] llvm-config not working"; exit 2)

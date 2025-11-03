# oss-fuzz/projects/ngrep/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

# We intentionally use the distro's libpcap-dev instead of building libpcap
# ourselves. Reason:
#   - ngrep's autotools checks for a "complete set of pcap headers", including
#     legacy/pcap-int.h style headers that upstream libpcap installs on distros
#     but are annoying to reconstruct manually.
#   - Using libpcap-dev lets ./configure succeed with --enable-pcre2 and keeps
#     packet-parsing code happy.
#
# We also pull libpcre2-dev so ngrep can use PCRE2 instead of its bundled
# legacy regex engine.
RUN apt-get update && apt-get install -y \
    autoconf automake libtool pkg-config \
    make gcc g++ \
    flex bison \
    libpcap-dev \
    libpcre2-dev \
 && rm -rf /var/lib/apt/lists/*

# Get ngrep sources
RUN git clone --depth 1 https://github.com/jpr5/ngrep.git ngrep

WORKDIR $SRC

# Add our build script and fuzz harness
COPY build.sh $SRC/
COPY fuzz_ngrep.c $SRC/

# oss-fuzz/projects/mongo-c-driver/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder

RUN apt-get update && \
    apt-get install -y cmake pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Fetch source code
RUN git clone --depth 1 https://github.com/mongodb/mongo-c-driver.git mongo-c-driver

# mongo-c-driver's own source directory
WORKDIR /src/mongo-c-driver

# Copy build.sh + three fuzzer source files to $SRC (/src)
# This way the container will have:
#   /src/build.sh
#   /src/bson_new_from_data_fuzzer.c
#   /src/mongoc_read_prefs_fuzzer.c
#   /src/mongoc_uri_fuzzer.c
COPY build.sh bson_new_from_data_fuzzer.c mongoc_read_prefs_fuzzer.c mongoc_uri_fuzzer.c $SRC/

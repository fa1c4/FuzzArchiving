FROM gcr.io/oss-fuzz-base/base-builder

# Pull source code
RUN git clone --depth 1 https://github.com/richgel999/fpng.git fpng

# Common tools (zip is used to package the seed corpus)
RUN apt-get update && apt-get install -y zip

# Pull PNG dictionary (reusing AFL's png.dict)
ADD https://raw.githubusercontent.com/google/AFL/master/dictionaries/png.dict $SRC/png.dict

WORKDIR fpng
# Copy build script and fuzzer source code
COPY build.sh $SRC/
COPY fuzz_decode.cc $SRC/
COPY fuzz_encode.cc $SRC/

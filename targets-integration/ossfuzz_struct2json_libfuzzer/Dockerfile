# struct2json Dockerfile
# Base image for typical C/C++ projects
FROM gcr.io/oss-fuzz-base/base-builder

RUN apt install -y valgrind gdb

# Pull struct2json source code
RUN git clone --depth 1 https://github.com/armink/struct2json.git $SRC/struct2json

# Copy scripts and fuzz harness source code from this project directory to the container
# (Assuming files like fuzz_json_to_struct.c / fuzz_struct_to_json.c / fuzz_roundtrip.c 
# are placed in the projects/struct2json directory)
COPY build.sh $SRC/
COPY fuzz_*.c $SRC/

# The build.sh script will handle changing directory to $SRC/struct2json
WORKDIR $SRC/struct2json

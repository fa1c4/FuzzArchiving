# projects/libmesh/Dockerfile
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# ...

FROM gcr.io/oss-fuzz-base/base-builder

# Fetch libMesh source code
RUN git clone --depth 1 https://github.com/libMesh/libmesh.git libmesh

# Pull submodules (TIMPI, contrib, etc.)
WORKDIR /src/libmesh
RUN git submodule update --init --recursive

# Copy build script and fuzz target source code
WORKDIR /src
COPY build.sh /src/
COPY *.cc /src/

# Default working directory
WORKDIR /src

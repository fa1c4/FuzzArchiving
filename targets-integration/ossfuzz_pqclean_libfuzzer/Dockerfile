# Copyright 2025 Google LLC.
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
RUN apt-get update && apt-get install -y make autoconf automake autopoint \
                      libtool cmake pkg-config curl check libcpputest-dev \
                      flex bison re2c protobuf-compiler uuid uuid-dev
 
COPY *.sh $SRC/
RUN mkdir -p $SRC/
COPY *.cpp *.c $SRC/
# Disable light for now. This is to speed up performance and we currently
# do not use light during build generation.
# TODO(David): enable this and make sure performance is too
# exhaustive (100+ min for some projects)
ENV FI_DISABLE_LIGHT=1
RUN git clone --recurse-submodules https://github.com/PQClean/PQClean.git PQClean.git
WORKDIR $SRC/PQClean.git

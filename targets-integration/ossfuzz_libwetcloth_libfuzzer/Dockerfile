# Use the base builder image
FROM gcr.io/oss-fuzz-base/base-builder

# Extra dependencies:
# - libtbb-dev: TBB parallel library
# - libeigen3-dev: Eigen headers (required by Camera.h for <Eigen/Dense>)
# - libgl1-mesa-glx: Libraries providing OpenGL support
# - libglvnd0: Provides libGLdispatch.so.0
# - libglu1-mesa-dev: Libraries providing OpenGL and GLUT support
# - librapidxml-dev: Provides rapidxml.hpp (required by TwoDSceneXMLParser)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake \
        ninja-build \
        libtbb-dev \
        libeigen3-dev \
        libgl1-mesa-glx \
        libglvnd0 \
        libglu1-mesa-dev \
        freeglut3-dev \
        librapidxml-dev \
        libx11-dev \
        patchelf \
        zip && \
    rm -rf /var/lib/apt/lists/*

# Upstream source code
RUN git clone --depth 1 https://github.com/raymondyfei/libwetcloth.git $SRC/libwetcloth

# Directory for fuzz harness source code
RUN mkdir -p $SRC/libwetcloth/fuzz

# Copy the script and fuzz source code from the project directory into the image
COPY build.sh $SRC/
COPY *.cc $SRC/libwetcloth/fuzz/

WORKDIR $SRC/libwetcloth

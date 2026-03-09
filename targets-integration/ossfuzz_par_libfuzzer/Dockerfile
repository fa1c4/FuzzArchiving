# oss-fuzz base image
FROM gcr.io/oss-fuzz-base/base-builder

# Place par source code under /src/par
RUN git clone --depth 1 https://github.com/prideout/par.git $SRC/par

# Switch working directory to par
WORKDIR $SRC/par

# Copy build.sh and fuzz harness source code
COPY build.sh $SRC/
COPY fuzz_msquares.c            $SRC/par/
COPY fuzz_streamlines.c         $SRC/par/
COPY fuzz_par_shapes_lsystem.c  $SRC/par/
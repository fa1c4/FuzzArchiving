# oss-fuzz/projects/fastpfor/Dockerfile
FROM gcr.io/oss-fuzz-base/base-builder
RUN apt-get update && apt-get install -y python3
# 使用你的 fork；如要对接上游可改为 lemire/FastPFOR
RUN git clone --depth 1 https://github.com/fast-pack/FastPFOR.git $SRC/FastPFOR
WORKDIR $SRC/FastPFOR

# 拷贝工程文件
COPY build.sh           $SRC/
COPY project.yaml       $SRC/
COPY gen_seed_corpus.py $SRC/
COPY *.cc               $SRC/

#!/usr/bin/env python3
import os, sys, struct, random

def dump(path, arr):
    # Write directly to disk as little-endian uint32_t, typical FastPFOR input
    with open(path, "wb") as f:
        for x in arr:
            f.write(struct.pack("<I", x & 0xffffffff))

def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    # 1) Empty / extremely small
    dump(os.path.join(outdir, "empty"), [])
    dump(os.path.join(outdir, "single"), [1])
    # 2) All zeros, uniformly small values
    dump(os.path.join(outdir, "all_zero_1k"), [0]*1024)
    dump(os.path.join(outdir, "small_rand_2k"),
         [random.randrange(0, 256) for _ in range(2048)])
    # 3) Monotonically increasing (delta-friendly)
    base = 0
    inc = []
    for _ in range(4096):
        base += random.randrange(0, 8)  # Small step size
        inc.append(base)
    dump(os.path.join(outdir, "monotone_4k"), inc)
    # 4) Mixed high/low + long tail
    mix = []
    for _ in range(4096):
        if random.random() < 0.9:
            mix.append(random.randrange(0, 1024))
        else:
            mix.append(random.randrange(0, 1<<31))
    dump(os.path.join(outdir, "mixed_long_tail_4k"), mix)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: gen_seed_corpus.py <outdir>")
        sys.exit(2)
    main(sys.argv[1])

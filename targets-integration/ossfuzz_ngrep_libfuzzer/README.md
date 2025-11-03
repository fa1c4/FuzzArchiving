# ngrep integrated into oss-fuzz 

```shell
cp -r ngrep /path/to/oss-fuzz/projects/ngrep
```

building and running
```shell
python infra/helper.py build_fuzzers --sanitizer address --engine libfuzzer ngrep

python infra/helper.py run_fuzzer --engine libfuzzer ngrep fuzz_ngrep
```

# kate integrated into oss-fuzz 

```shell
cp -r kate /path/to/oss-fuzz/projects/kate
```

building and running
```shell
python infra/helper.py build_fuzzers --sanitizer address --engine libfuzzer kate

python infra/helper.py run_fuzzer --engine libfuzzer kate fuzz_kate_fuzzy_match
```

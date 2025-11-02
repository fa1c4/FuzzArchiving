# nghttp3 integrated into oss-fuzz 

```shell
cp -r nghttp3 /path/to/oss-fuzz/projects/nghttp3
```

building and running
```shell
python infra/helper.py build_fuzzers --sanitizer address --engine libfuzzer nghttp3

python infra/helper.py run_fuzzer --engine libfuzzer nghttp3 fuzz_http3serverreq_fuzzer
python infra/helper.py run_fuzzer --engine libfuzzer nghttp3 fuzz_qpackdecoder_fuzzer
```

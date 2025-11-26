# ffmpeg-rockchip integrated into oss-fuzz 

```shell
cp -r ffmpeg-rockchip /path/to/oss-fuzz/projects/ffmpeg-rockchip
```

building and running
```shell
python infra/helper.py build_fuzzers --sanitizer address --engine libfuzzer ffmpeg-rockchip

# see the fuzz target names
ls /path/to/oss-fuzz/build/out/ffmpeg-rockchip
# target_names ...

python infra/helper.py run_fuzzer --engine libfuzzer ffmpeg-rockchip target_name_1
python infra/helper.py run_fuzzer --engine libfuzzer ffmpeg-rockchip target_name_2
# ...
python infra/helper.py run_fuzzer --engine libfuzzer ffmpeg-rockchip target_name_n
```

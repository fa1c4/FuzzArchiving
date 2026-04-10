put the batch_ossfuzz_tmux.py to oss-fuzz root directory then run in batch for all projects in the oss-fuzz

```shell
python batch_ossfuzz_tmux.py \
  --start-index 0 \
  --end-index 50 \
  --max-tmuxs 8 \
  --fuzz-time 72
```

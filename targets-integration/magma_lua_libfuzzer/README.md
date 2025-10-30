# Lua into Magma
Integrate libfuzzer style Lua fuzzing configurations into Magma.

```shell
cp -r liblua /path/to/magma/targets/liblua
```

Then set the fuzzer_TARGETS=(liblua) in captainrc of magma.

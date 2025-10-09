# LibAFL 
Github Link: https://github.com/AFLplusplus/LibAFL

```shell
cp -r libafl/ /path/to/magma/fuzzers
```

+ complete the harness.cc for each target programs
+ then add `$LIB_FUZZING_ENGINE` to every target build.sh (add at the end of libs)
for example
```shell
for fuzzer in libxml2_xml_read_memory_fuzzer libxml2_xml_reader_for_file_fuzzer; do
  $CXX $CXXFLAGS -std=c++11 -Iinclude/ -I"$TARGET/src/" \
      "$TARGET/src/$fuzzer.cc" -o "$OUT/$fuzzer" \
      .libs/libxml2.a $LDFLAGS $LIBS -lz -llzma $LIB_FUZZING_ENGINE # <- add here
done
```

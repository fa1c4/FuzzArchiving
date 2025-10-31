# Har(ness)Libsndfile into Magma
Integrate libfuzzer style libsndfile fuzzing configurations into Magma.

```shell
cp -r harlibsndfile /path/to/magma/targets/harlibsndfile
```

Then set the fuzzer_TARGETS=(harlibsndfile) in captainrc of magma. 
(You can modify the name of harlibsndfile as you like)

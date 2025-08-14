# aflplusplus

BazzAFL fuzzer instance that has the following config active for all benchmarks:
  - PCGUARD instrumentation 
  - cmplog feature
  - dict2file feature
  - "fast" power schedule
  - persistent mode + shared memory test cases

Repository: [https://github.com/BazzAFL/BazzAFL.git](https://github.com/BazzAFL/BazzAFL.git)

[builder.Dockerfile](builder.Dockerfile)
[fuzzer.py](fuzzer.py)
[runner.Dockerfile](runner.Dockerfile)

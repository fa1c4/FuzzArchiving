// vectordb_http_query_fuzzer.cc
#include <cstddef>
#include <cstdint>
#include <string>

#include "utils/json.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  // Treat fuzz data as an HTTP request body (JSON text)
  std::string body(reinterpret_cast<const char *>(data), size);

  vectordb::Json json;   // ⭐ Use vectordb::Json instead of vectordb::engine::Json

  // Assume LoadFromString will attempt to parse the body as JSON.
  // Success or failure doesn't matter; the priority is avoiding crashes/UB.
  json.LoadFromString(body);

  return 0;
}

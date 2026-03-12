// oss-fuzz/projects/rmg/archive_fuzzer.cc
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <vector>

#include "Archive.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return 0;

  // Fixed path to avoid generating a bunch of garbage files
  const std::filesystem::path tmpDir = "/tmp";
  const std::filesystem::path archivePath = tmpDir / "rmg_fuzz_archive.zip";

  FILE *f = std::fopen(archivePath.c_str(), "wb");
  if (!f) return 0;
  std::fwrite(data, 1, size, f);
  std::fclose(f);

  std::filesystem::path extractedName;
  bool isDisk = false;
  std::vector<char> buffer;

  // 1) Take the CoreReadArchiveFile path (internally selects zip/7z based on extension)
  CoreReadArchiveFile(archivePath, extractedName, isDisk, buffer);

  // 2) Take the CoreUnzip path
  const std::filesystem::path unzipDir = tmpDir / "rmg_fuzz_unzip";
  CoreUnzip(archivePath, unzipDir);

  return 0;
}

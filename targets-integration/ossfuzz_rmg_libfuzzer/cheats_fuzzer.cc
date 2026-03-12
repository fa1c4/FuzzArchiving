// oss-fuzz/projects/rmg/cheats_fuzzer.cc
#include <cstdint>
#include <string>
#include <vector>

#include "Cheats.hpp"

// Helpers: split fuzzer data into lines by '\n'
static void SplitLines(const std::string &input,
                       std::vector<std::string> &lines) {
  size_t pos = 0;
  while (pos < input.size()) {
    size_t nl = input.find('\n', pos);
    if (nl == std::string::npos) nl = input.size();
    lines.emplace_back(input.substr(pos, nl - pos));
    pos = nl + 1;
  }
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return 0;

  std::string s(reinterpret_cast<const char *>(data), size);
  std::vector<std::string> lines;
  SplitLines(s, lines);

  CoreCheat cheat;
  CoreParseCheat(lines, cheat);  // It doesn't matter if it fails, as long as the code path is executed once

  if (!cheat.CheatCodes.empty() || cheat.HasOptions) {
    // Export to code lines / option lines, then do a lightweight round-trip
    std::vector<std::string> codeLines;
    std::vector<std::string> optionLines;
    CoreGetCheatLines(cheat, codeLines, optionLines);

    // Attempt a "headerless" parse using the generated codeLines
    if (!codeLines.empty()) {
      CoreCheat tmp;
      CoreParseCheat(codeLines, tmp);
    }

    if (!optionLines.empty()) {
      CoreCheat tmpOpt;
      CoreParseCheat(optionLines, tmpOpt);
    }
  }

  return 0;
}

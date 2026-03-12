#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include <tre/tre.h>  // Installed TRE header file

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  // Limit the size to avoid extreme O(M^2 * N) cases caused by very large inputs
  if (size < 4 || size > 4096) {
    return 0;
  }

  // The first byte determines which compilation/execution API combination to use
  uint8_t mode = data[0];
  // The second and third bytes are used to generate cflags / eflags
  uint8_t flags1 = data[1];
  uint8_t flags2 = data[2];

  const uint8_t *payload = data + 3;
  size_t payload_size = size - 3;
  if (payload_size == 0) {
    return 0;
  }

  // Split the remaining data: the first half for the pattern, the second half for the text
  size_t pat_len = payload_size / 2;
  if (pat_len == 0) {
    pat_len = 1;  // Leave at least one byte for the pattern
  }
  if (pat_len > payload_size) {
    return 0;
  }
  size_t text_len = payload_size - pat_len;

  if (text_len == 0) {
    // We could test the compilation path even without text, but we return here for simplicity
    return 0;
  }

  std::string pattern(reinterpret_cast<const char *>(payload), pat_len);
  std::string text(reinterpret_cast<const char *>(payload + pat_len), text_len);

  // Construct cflags
  int cflags = 0;
  if (flags1 & 0x01) cflags |= REG_EXTENDED;
  if (flags1 & 0x02) cflags |= REG_ICASE;
  if (flags1 & 0x04) cflags |= REG_NEWLINE;
  if (flags1 & 0x08) cflags |= REG_NOSUB;
#ifdef REG_LITERAL
  if (flags1 & 0x10) cflags |= REG_LITERAL;
#endif
#ifdef REG_UNGREEDY
  if (flags1 & 0x20) cflags |= REG_UNGREEDY;
#endif

  // Construct eflags
  int eflags = 0;
  if (flags2 & 0x01) eflags |= REG_NOTBOL;
  if (flags2 & 0x02) eflags |= REG_NOTEOL;
#ifdef REG_BACKTRACKING_MATCHER
  if (flags2 & 0x04) eflags |= REG_BACKTRACKING_MATCHER;
#endif
#ifdef REG_APPROX_MATCHER
  if (flags2 & 0x08) eflags |= REG_APPROX_MATCHER;
#endif

  regex_t preg;
  std::memset(&preg, 0, sizeof(preg));

  int compile_res = 0;

  // Choose between different compilation APIs
  switch (mode & 0x03) {
    case 0:
      // "Normal" API with length
      compile_res =
          tre_regncomp(&preg, pattern.data(), pattern.size(), cflags);
      break;
    case 1:
      // "Normal" API terminated by '\0'
      compile_res = tre_regcomp(&preg, pattern.c_str(), cflags);
      break;
    case 2:
      // "Bytes" API with length
      compile_res =
          tre_regncompb(&preg, pattern.data(), pattern.size(), cflags);
      break;
    case 3:
      // "Bytes" API terminated by '\0'
      compile_res = tre_regcompb(&preg, pattern.c_str(), cflags);
      break;
  }

  if (compile_res != 0) {
    // If compilation fails, return directly; tre_regfree must not be called
    return 0;
  }

  // re_nsub: number of capturing groups, +1 for the whole match itself
  size_t max_subs = preg.re_nsub + 1;
  if (max_subs == 0) {
    max_subs = 1;
  }
  if (max_subs > 32) {
    max_subs = 32;  // Set an upper bound
  }

  std::vector<regmatch_t> pmatch(max_subs);

  // Choose between different execution APIs
  int exec_res = 0;
  switch ((mode >> 2) & 0x03) {
    case 0:
      // "Normal" API with length
      exec_res = tre_regnexec(&preg,
                              text.data(),
                              text.size(),
                              pmatch.size(),
                              pmatch.data(),
                              eflags);
      break;
    case 1:
      // "Normal" API terminated by '\0'
      exec_res = tre_regexec(&preg,
                             text.c_str(),
                             pmatch.size(),
                             pmatch.data(),
                             eflags);
      break;
    case 2:
      // "Bytes" API with length
      exec_res = tre_regnexecb(&preg,
                               text.data(),
                               text.size(),
                               pmatch.size(),
                               pmatch.data(),
                               eflags);
      break;
    case 3:
      // "Bytes" API terminated by '\0'
      exec_res = tre_regexecb(&preg,
                              text.c_str(),
                              pmatch.size(),
                              pmatch.data(),
                              eflags);
      break;
  }

  (void)exec_res;  // We only care about sanitizer reports, not the return value

  tre_regfree(&preg);
  return 0;
}

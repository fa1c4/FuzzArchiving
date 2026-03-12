#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include <tre/tre.h>  // Installed TRE header file

// Approximate matching fuzzer
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  // Limit input size to avoid excessive runtime in extreme O(M^2 * N) cases
  if (size < 7 || size > 4096) {
    return 0;
  }

  // Data layout:
  //   data[0] : Compilation mode (selects tre_regncomp/tre_regcomp/tre_regncompb/tre_regcompb)
  //   data[1] : cflags source
  //   data[2] : eflags source
  //   data[3] : cost parameters
  //   data[4] : limit parameters
  //   Remainder: pattern + text
  uint8_t mode    = data[0];
  uint8_t flags1  = data[1];
  uint8_t flags2  = data[2];
  uint8_t pcost   = data[3];
  uint8_t plimit  = data[4];

  const uint8_t *payload = data + 5;
  size_t payload_size = size - 5;
  if (payload_size < 2) {
    return 0;  // Ensure at least 1 byte each for pattern and text
  }

  // Split payload: half for pattern, half for text
  size_t pat_len = payload_size / 2;
  if (pat_len == 0) pat_len = 1;
  if (pat_len >= payload_size) return 0;
  size_t text_len = payload_size - pat_len;

  std::string pattern(reinterpret_cast<const char *>(payload), pat_len);
  std::string text(reinterpret_cast<const char *>(payload + pat_len), text_len);

  // ===== Construct cflags =====
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

  // ===== Construct eflags =====
  int eflags = 0;
  if (flags2 & 0x01) eflags |= REG_NOTBOL;
  if (flags2 & 0x02) eflags |= REG_NOTEOL;
#ifdef REG_BACKTRACKING_MATCHER
  if (flags2 & 0x04) eflags |= REG_BACKTRACKING_MATCHER;
#endif
#ifdef REG_APPROX_MATCHER
  if (flags2 & 0x08) eflags |= REG_APPROX_MATCHER;
#endif

  // ===== Compile Regex =====
  regex_t preg;
  std::memset(&preg, 0, sizeof(preg));

  // compile_mode determines which regcomp variant to use and whether to use bytes mode
  int compile_res = 0;
  bool bytes_mode = false;

  switch (mode & 0x03) {
    case 0:
      // tre_regncomp: Standard API with length
      compile_res = tre_regncomp(&preg, pattern.data(), pattern.size(), cflags);
      bytes_mode = false;
      break;
    case 1:
      // tre_regcomp: Standard API, null-terminated
      compile_res = tre_regcomp(&preg, pattern.c_str(), cflags);
      bytes_mode = false;
      break;
    case 2:
      // tre_regncompb: Bytes API with length
      compile_res =
          tre_regncompb(&preg, pattern.data(), pattern.size(), cflags);
      bytes_mode = true;
      break;
    case 3:
    default:
      // tre_regcompb: Bytes API, null-terminated
      compile_res = tre_regcompb(&preg, pattern.c_str(), cflags);
      bytes_mode = true;
      break;
  }

  if (compile_res != 0) {
    // If compilation fails, tre_regfree is not needed
    return 0;
  }

  // ===== Prepare regamatch_t / regaparams_t =====
  // nmatch = re_nsub + 1 (+1 for the whole match), capped at 32 to avoid excessive stack/heap usage
  size_t nmatch = preg.re_nsub + 1;
  if (nmatch == 0) nmatch = 1;
  if (nmatch > 32) nmatch = 32;

  std::vector<regmatch_t> pmatch(nmatch);

  regamatch_t match;
  std::memset(&match, 0, sizeof(match));
  match.nmatch = nmatch;
  match.pmatch = pmatch.data();

  regaparams_t params;
  tre_regaparams_default(&params);

  // Use pcost / plimit to control parameters within a small range to prevent excessive search spaces
  params.cost_ins   = 1 + (pcost & 0x03);           // 1..4
  params.cost_del   = 1 + ((pcost >> 2) & 0x03);    // 1..4
  params.cost_subst = 1 + ((pcost >> 4) & 0x03);    // 1..4

  // Max cost & error counts are controlled within a small range
  params.max_cost   = (plimit & 0x07);              // 0..7
  if (params.max_cost == 0) params.max_cost = 1;    // 1..7
  params.max_ins    = 1 + ((plimit >> 3) & 0x03);   // 1..4
  params.max_del    = 1 + ((plimit >> 5) & 0x03);   // 1..4
  params.max_subst  = 1 + ((plimit >> 7) & 0x01);   // 1..2
  // max_err must be at least >= the sum of various edit limits, otherwise pruning occurs immediately
  params.max_err    = params.max_ins + params.max_del + params.max_subst;

  // ===== Invoke approximate matching API =====
  int exec_res = 0;

  if (bytes_mode) {
    // Pattern was compiled using tre_reg*compb; use the bytes version of the approx API
    exec_res = tre_regaexecb(&preg,
                             text.c_str(),  // Requires null termination
                             &match,
                             params,
                             eflags);
  } else {
    // Normal mode: randomly choose between tre_reganexec / tre_regaexec
    switch ((mode >> 2) & 0x01) {
      case 0:
        // Explicit length version
        exec_res = tre_reganexec(&preg,
                                 text.data(),
                                 text.size(),
                                 &match,
                                 params,
                                 eflags);
        break;
      case 1:
      default:
        // No length provided, C-string (null-terminated)
        exec_res = tre_regaexec(&preg,
                                text.c_str(),
                                &match,
                                params,
                                eflags);
        break;
    }
  }

  (void)exec_res;  // We don't care about the return value, only about sanitizer reports

  tre_regfree(&preg);
  return 0;
}

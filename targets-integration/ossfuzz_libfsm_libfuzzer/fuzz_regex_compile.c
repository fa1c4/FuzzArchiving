// fuzz_regex_compile.c
// Fuzz only the regex->NFA compile path (libre); no determinise/minimise yet.

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>      // for EOF in re_getchar_fun contracts

#include <re/re.h>
#include <fsm/fsm.h>

// simple bounded INPUT reader for libre's re_getchar_fun
struct InBuf {
  const unsigned char *p;
  size_t n;
  size_t i;
};

static int inbuf_getc(void *opaque) {
  struct InBuf *in = (struct InBuf *)opaque;
  if (in->i >= in->n) return EOF;
  return (int)in->p[in->i++];
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (!data || size == 0) return 0;

  // Cap length to avoid pathological compile time on huge inputs
  const size_t cap = size > 4096 ? 4096 : size;

  struct InBuf in = { data, cap, 0 };
  struct re_err err;
  (void)memset(&err, 0, sizeof(err));

  // Be conservative: dialect/flags = 0 (use defaults)
  const enum re_dialect dialect = (enum re_dialect)0;
  const enum re_flags   flags   = (enum re_flags)0;

  // alloc = NULL -> use default allocator if supported by this build
  struct fsm *nfa = re_comp(dialect, inbuf_getc, &in, NULL, flags, &err);

  if (nfa != NULL) {
    // We only exercise the compile path for now
    fsm_free(nfa);
  }
  return 0;
}

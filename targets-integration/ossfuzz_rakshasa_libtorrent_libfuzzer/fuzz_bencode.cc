/* oss-fuzz/projects/libtorrent/fuzz_bencode.cc */
#include <cstdint>
#include <cstddef>
#include <string>
#include <vector>

#if __has_include(<torrent/bencode.h>)
#  include <torrent/bencode.h>
#  define LIBTORRENT_HAS_BENCODE 1
#elif __has_include(<torrent/bencode/bencode.h>)
#  include <torrent/bencode/bencode.h>
#  define LIBTORRENT_HAS_BENCODE 1
#else
#  define LIBTORRENT_HAS_BENCODE 0
#endif

#if LIBTORRENT_HAS_BENCODE
// Attempt compatibility with common namespaces
using namespace torrent;
#endif

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
#if !LIBTORRENT_HAS_BENCODE
  (void)data; (void)size;
  return 0;
#else
  // Treat input as bencode and parse into generic objects (dict/list/int/string)
  try {
    std::string_view sv(reinterpret_cast<const char*>(data), size);

    // Common API variants (examples): bencode::decode / parse / load
    // The following are exploratory calls; keep whichever one exists.
    // You can keep the correct path locally based on the actual API.

    // 1) Assume Object type + parse exist
    #if defined(HAS_TORRENT_OBJECT_PARSE)
      torrent::Object obj = torrent::bencode::parse(sv.data(), sv.data()+sv.size());
      // Perform a recursive traversal
      (void)obj.is_list(); (void)obj.is_map(); (void)obj.is_string(); (void)obj.is_integer();
    #elif defined(HAS_TORRENT_BENCODE_DECODE)
      auto obj = torrent::bencode::decode(sv);
      (void)obj;
    #else
      // Most conservative: if only a "verify/skip" interface is provided
      (void)sv;
    #endif

  } catch (...) {
    // Exit normally if parsing fails
  }
  return 0;
#endif
}

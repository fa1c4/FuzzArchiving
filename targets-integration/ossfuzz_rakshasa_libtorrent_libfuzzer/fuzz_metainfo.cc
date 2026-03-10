/* oss-fuzz/projects/libtorrent/fuzz_metainfo.cc */
#include <cstdint>
#include <cstddef>
#include <string>
#include <string_view>

#if __has_include(<torrent/torrent.h>)
#  include <torrent/torrent.h>
#  define LIBTORRENT_HAS_META 1
#elif __has_include(<torrent/metadata.h>)
#  include <torrent/metadata.h>
#  define LIBTORRENT_HAS_META 1
#else
#  define LIBTORRENT_HAS_META 0
#endif

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
#if !LIBTORRENT_HAS_META
  (void)data; (void)size;
  return 0;
#else
  try {
    std::string_view sv(reinterpret_cast<const char*>(data), size);

    // Pseudo-code style multi-branch; keep the one that compiles in your environment:
    // 1) If Metainfo::load / parse exists
    #if defined(HAS_TORRENT_META_LOAD)
      torrent::Metainfo mi;
      mi.load(sv);                      // or mi.parse(sv.begin(), sv.end());
      (void)mi.info_hash();
      (void)mi.name();
      (void)mi.files();
    // 2) Or higher-level helpers: torrent::parse_torrent / read_torrent
    #elif defined(HAS_TORRENT_PARSE_TORRENT)
      auto mi = torrent::parse_torrent(sv);
      (void)mi;
    #else
      // If unavailable, no-op
      (void)sv;
    #endif

  } catch (...) {
    // Swallow both parsing and validation failures
  }
  return 0;
#endif
}

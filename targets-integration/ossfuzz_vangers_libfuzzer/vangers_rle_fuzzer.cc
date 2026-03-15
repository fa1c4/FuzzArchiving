#include <cstddef>
#include <cstdint>
#include <cstring>
#include <memory>
#include <cstdlib>

// Define uchar locally to avoid dependencies on global.h / xglobal.h
using uchar = unsigned char;

// ====== Implementation copied from Vangers/src/rle.cpp ======

int RLE_ANALISE(uchar* _buf, int len, uchar*& out) {
    int i = 0;
    int pack_len = 0;
    uchar c_len = 0;
    uchar* buf = _buf;
    uchar* _out = new uchar[len * 2];
    uchar* p = _out;
    uchar _ch = *buf++;

    while (i < len) {
        // run-length (repeated) part
        while ((i < len) && (_ch == *buf) && (c_len < 127)) {
            c_len++;
            buf++;
            i++;
        }

        if (c_len) {
            *p++ = c_len;
            *p++ = _ch;

            _ch = *buf++;

            pack_len += 2;
            c_len = 0;
            i++;
        }

        // non-repeated (literal) part
        while ((i < len) && (_ch != *buf) && (c_len < 127)) {
            c_len++;
            _ch = *buf++;
            i++;
        }

        if (c_len) {
            *p++ = static_cast<uchar>(128 + (c_len - 1));
            std::memcpy(p, buf - c_len - 1, c_len);
            p += c_len;
            pack_len += c_len + 1;
            c_len = 0;
        }
    } // end while

    out = new uchar[pack_len];
    std::memcpy(out, _out, pack_len);
    delete[] _out;

    return pack_len;
}

void RLE_UNCODE(uchar* _buf, int len, uchar* out) {
    uchar* buf = _buf;
    uchar c_len = 0;
    uchar* p = out;

    int i = 0;
    while (i < len) {
        c_len = *p++;

        if (c_len & 128) {
            c_len ^= 128;
            std::memcpy(buf, p, ++c_len);

            i += c_len;
            p += c_len;
            buf += c_len;
        } else {
            std::memset(buf, *p++, ++c_len);
            i += c_len;
            buf += c_len;
        } // end if
    } // end while
}

// ====== fuzz harness ======

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    // Requires at least one mode byte + 1 byte of data
    if (size <= 1) {
        return 0;
    }

    uint8_t mode = data[0];
    const uchar* buf = reinterpret_cast<const uchar*>(data + 1);
    int len = static_cast<int>(size - 1);

    if (len <= 0) {
        return 0;
    }

    switch (mode % 3) {
    case 0: {
        // Mode 0: Encoding only
        uchar* encoded = nullptr;
        int encoded_len = RLE_ANALISE(
            const_cast<uchar*>(buf),
            len,
            encoded
        );
        (void)encoded_len; // Currently unused

        if (encoded) {
            delete[] encoded;
        }
        break;
    }

    case 1: {
        // Mode 1: encode -> decode -> comparison
        uchar* encoded = nullptr;
        int encoded_len = RLE_ANALISE(
            const_cast<uchar*>(buf),
            len,
            encoded
        );

        if (encoded_len > 0 && encoded != nullptr) {
            std::unique_ptr<uchar[]> decoded(new uchar[len]);

            // Note: Parameter order is (output_buf, decoded_len, encoded_data)
            RLE_UNCODE(decoded.get(), len, encoded);

            if (std::memcmp(decoded.get(), buf,
                            static_cast<std::size_t>(len)) != 0) {
                // Logic errors are treated as bugs
                std::abort();
            }
        }

        if (encoded) {
            delete[] encoded;
        }
        break;
    }

    case 2: {
        // Mode 2: Directly fuzz the decoder, treating input as an "encoded stream"
        if (len < 3) {
            break;
        }

        uint16_t decoded_len =
            (static_cast<uint16_t>(buf[0]) << 8) |
            static_cast<uint16_t>(buf[1]);

        // Limit range to avoid meaningless large allocations
        if (decoded_len == 0 || decoded_len > 0x10000) {
            break;
        }

        const uchar* encoded = buf + 2;
        int encoded_size = len - 2;
        if (encoded_size <= 0) {
            break;
        }

        std::unique_ptr<uchar[]> decoded(new uchar[decoded_len]);

        RLE_UNCODE(decoded.get(),
                   static_cast<int>(decoded_len),
                   const_cast<uchar*>(encoded));
        break;
    }

    default:
        break;
    }

    return 0;
}

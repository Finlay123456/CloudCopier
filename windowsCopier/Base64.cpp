#include "Base64.h"

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string base64_encode(const unsigned char* data, size_t len) {
    std::string out((len + 2) / 3 * 4, '=');
    size_t outpos = 0;
    for (size_t i = 0; i < len;) {
        uint32_t octet_a = i < len ? data[i++] : 0;
        uint32_t octet_b = i < len ? data[i++] : 0;
        uint32_t octet_c = i < len ? data[i++] : 0;
        uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;

        out[outpos++] = b64_table[(triple >> 18) & 0x3F];
        out[outpos++] = b64_table[(triple >> 12) & 0x3F];
        out[outpos++] = b64_table[(triple >> 6) & 0x3F];
        out[outpos++] = b64_table[triple & 0x3F];
    }
    return out;
}

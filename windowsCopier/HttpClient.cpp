#include <windows.h>
#include <winhttp.h>
#include <string>
#include <sstream>
#include <iomanip>  // for std::setw, std::setfill, std::hex
#pragma comment(lib, "winhttp.lib")

std::string jsonEscape(const std::string& input) {
    std::ostringstream ss;
    for (char c : input) {
        switch (c) {
        case '\"': ss << "\\\""; break;
        case '\\': ss << "\\\\"; break;
        case '\b': ss << "\\b";  break;
        case '\f': ss << "\\f";  break;
        case '\n': ss << "\\n";  break;
        case '\r': ss << "\\r";  break;
        case '\t': ss << "\\t";  break;
        default:
            if (static_cast<unsigned char>(c) < 0x20 || static_cast<unsigned char>(c) > 0x7F) {
                ss << "\\u"
                    << std::hex << std::uppercase
                    << std::setfill('0') << std::setw(4)
                    << static_cast<int>(static_cast<unsigned char>(c));
            }
            else {
                ss << c;
            }
        }
    }
    return ss.str();
}

void postClipboard(const std::string& payload) {
    HINTERNET hSession = WinHttpOpen(L"ClipboardUploader/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    HINTERNET hConnect = WinHttpConnect(hSession, L"localhost", 3000, 0);
    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"POST", L"/clipboard", nullptr, WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES, 0);

    std::wstring hdrs = L"Content-Type: application/json";
    WinHttpSendRequest(hRequest, hdrs.c_str(), -1, (LPVOID)payload.c_str(), payload.size(), payload.size(), 0);
    WinHttpReceiveResponse(hRequest, nullptr);

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
}

void postClipboardText(const std::string& text) {
    std::ostringstream oss;
    oss << "{\"type\":\"text\",\"data\":\"" << jsonEscape(text) << "\"}";
    postClipboard(oss.str());
}

void postClipboardImage(const std::string& base64Image) {
    std::ostringstream oss;
    oss << "{\"type\":\"image\",\"data\":\"" << base64Image << "\"}";
    postClipboard(oss.str());
}

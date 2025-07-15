#include <windows.h>
#include <string>
#include "HttpClient.h"
#include "PngEncoder.h"
#include "Base64.h"

void handleClipboardUpdate() {
    OutputDebugStringW(L"[handleClipboardUpdate] Triggered\n");

    bool clipboardOpened = false;
    for (int i = 0; i < 10; ++i) {  // Try up to 10 times
        if (OpenClipboard(nullptr)) {
            clipboardOpened = true;
            break;
        }
        Sleep(10);  // wait 10 ms before retrying
    }
    if (!clipboardOpened) {
        OutputDebugStringW(L"Failed to open clipboard after retries\n");
        return;
    }


    if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
        OutputDebugStringW(L"Text format detected\n");

        HANDLE hText = GetClipboardData(CF_UNICODETEXT);
        if (hText) {
            LPCWSTR wText = static_cast<LPCWSTR>(GlobalLock(hText));
            if (wText) {
                int len = WideCharToMultiByte(CP_UTF8, 0, wText, -1, nullptr, 0, nullptr, nullptr);
                std::vector<char> utf8Text(len);
                WideCharToMultiByte(CP_UTF8, 0, wText, -1, utf8Text.data(), len, nullptr, nullptr);

                OutputDebugStringW(L"Sending text to server...\n");
                postClipboardText(std::string(utf8Text.data()));

                GlobalUnlock(hText);
            }
            else {
                OutputDebugStringW(L"Failed to lock text handle\n");

            }
        }
        else {
            OutputDebugStringW(L"Failed to get text from clipboard\n");
        }
    }
    else if (IsClipboardFormatAvailable(CF_BITMAP)) {
        OutputDebugStringW(L"Bitmap format detected\n");

        HBITMAP hBitmap = (HBITMAP)GetClipboardData(CF_BITMAP);
        if (hBitmap) {
            std::vector<unsigned char> pngData;
            if (encodeHBITMAPToPNG(hBitmap, pngData)) {
                std::string base64Img = "data:image/png;base64," + base64_encode(pngData.data(), pngData.size());

                OutputDebugStringW(L"Sending image to server...\n");
                postClipboardImage(base64Img);
            }
            else {
                OutputDebugStringW(L"Failed to encode HBITMAP to PNG\n");
            }
        }
        else {
            OutputDebugStringW(L"Failed to get bitmap from clipboard\n");
        }
    }
    else {
        OutputDebugStringW(L"Unsupported clipboard format\n");
    }

    CloseClipboard();
}

#include <windows.h>
#include <string>
#include <vector>
#include <map>
#include <shlobj.h>
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

    std::map<std::string, std::string> formats;

    // Handle Unicode text
    if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
        OutputDebugStringW(L"Unicode text format detected\n");
        HANDLE hText = GetClipboardData(CF_UNICODETEXT);
        if (hText) {
            LPCWSTR wText = static_cast<LPCWSTR>(GlobalLock(hText));
            if (wText) {
                int len = WideCharToMultiByte(CP_UTF8, 0, wText, -1, nullptr, 0, nullptr, nullptr);
                std::vector<char> utf8Text(len);
                WideCharToMultiByte(CP_UTF8, 0, wText, -1, utf8Text.data(), len, nullptr, nullptr);
                formats["text"] = std::string(utf8Text.data());
                GlobalUnlock(hText);
            }
        }
    }

    // Handle regular text (fallback)
    if (formats.find("text") == formats.end() && IsClipboardFormatAvailable(CF_TEXT)) {
        OutputDebugStringW(L"ANSI text format detected\n");
        HANDLE hText = GetClipboardData(CF_TEXT);
        if (hText) {
            LPCSTR text = static_cast<LPCSTR>(GlobalLock(hText));
            if (text) {
                formats["text"] = std::string(text);
                GlobalUnlock(hText);
            }
        }
    }

    // Handle RTF (Rich Text Format)
    UINT rtfFormat = RegisterClipboardFormat(L"Rich Text Format");
    if (IsClipboardFormatAvailable(rtfFormat)) {
        OutputDebugStringW(L"RTF format detected\n");
        HANDLE hRtf = GetClipboardData(rtfFormat);
        if (hRtf) {
            LPCSTR rtfData = static_cast<LPCSTR>(GlobalLock(hRtf));
            if (rtfData) {
                formats["rtf"] = std::string(rtfData);
                GlobalUnlock(hRtf);
            }
        }
    }

    // Handle HTML format
    UINT htmlFormat = RegisterClipboardFormat(L"HTML Format");
    if (IsClipboardFormatAvailable(htmlFormat)) {
        OutputDebugStringW(L"HTML format detected\n");
        HANDLE hHtml = GetClipboardData(htmlFormat);
        if (hHtml) {
            LPCSTR htmlData = static_cast<LPCSTR>(GlobalLock(hHtml));
            if (htmlData) {
                formats["html"] = std::string(htmlData);
                GlobalUnlock(hHtml);
            }
        }
    }

    // Handle bitmap images
    if (IsClipboardFormatAvailable(CF_BITMAP)) {
        OutputDebugStringW(L"Bitmap format detected\n");
        HBITMAP hBitmap = (HBITMAP)GetClipboardData(CF_BITMAP);
        if (hBitmap) {
            std::vector<unsigned char> pngData;
            if (encodeHBITMAPToPNG(hBitmap, pngData)) {
                std::string base64Img = "data:image/png;base64," + base64_encode(pngData.data(), pngData.size());
                formats["image"] = base64Img;
            }
        }
    }

    // Handle file drops
    if (IsClipboardFormatAvailable(CF_HDROP)) {
        OutputDebugStringW(L"File drop format detected\n");
        HANDLE hDrop = GetClipboardData(CF_HDROP);
        if (hDrop) {
            HDROP hdrop = static_cast<HDROP>(hDrop);
            UINT fileCount = DragQueryFile(hdrop, 0xFFFFFFFF, nullptr, 0);
            
            std::string fileList = "";
            for (UINT i = 0; i < fileCount; i++) {
                UINT pathLen = DragQueryFile(hdrop, i, nullptr, 0);
                std::vector<WCHAR> path(pathLen + 1);
                DragQueryFile(hdrop, i, path.data(), pathLen + 1);
                
                int len = WideCharToMultiByte(CP_UTF8, 0, path.data(), -1, nullptr, 0, nullptr, nullptr);
                std::vector<char> utf8Path(len);
                WideCharToMultiByte(CP_UTF8, 0, path.data(), -1, utf8Path.data(), len, nullptr, nullptr);
                
                if (i > 0) fileList += "\n";
                fileList += utf8Path.data();
            }
            formats["files"] = fileList;
        }
    }

    CloseClipboard();

    // Send all formats if we found any
    if (!formats.empty()) {
        OutputDebugStringW(L"Sending clipboard data to server...\n");
        postClipboardFormats(formats, "windows");
    } else {
        OutputDebugStringW(L"No supported clipboard formats found\n");
    }
}

void setClipboardFromFormats(const std::map<std::string, std::string>& formats) {
    OutputDebugStringW(L"[setClipboardFromFormats] Setting clipboard from incoming data\n");

    if (!OpenClipboard(nullptr)) {
        OutputDebugStringW(L"Failed to open clipboard for writing\n");
        return;
    }

    EmptyClipboard();

    // Set text format
    auto textIt = formats.find("text");
    if (textIt != formats.end() && !textIt->second.empty()) {
        const std::string& text = textIt->second;
        
        // Convert UTF-8 to wide string
        int wlen = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
        if (wlen > 0) {
            HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, wlen * sizeof(WCHAR));
            if (hMem) {
                LPWSTR wText = static_cast<LPWSTR>(GlobalLock(hMem));
                MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, wText, wlen);
                GlobalUnlock(hMem);
                SetClipboardData(CF_UNICODETEXT, hMem);
                OutputDebugStringW(L"Set text format\n");
            }
        }
    }

    // Set RTF format
    auto rtfIt = formats.find("rtf");
    if (rtfIt != formats.end() && !rtfIt->second.empty()) {
        const std::string& rtf = rtfIt->second;
        UINT rtfFormat = RegisterClipboardFormat(L"Rich Text Format");
        
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, rtf.length() + 1);
        if (hMem) {
            LPSTR rtfData = static_cast<LPSTR>(GlobalLock(hMem));
            strcpy_s(rtfData, rtf.length() + 1, rtf.c_str());
            GlobalUnlock(hMem);
            SetClipboardData(rtfFormat, hMem);
            OutputDebugStringW(L"Set RTF format\n");
        }
    }

    // Set HTML format
    auto htmlIt = formats.find("html");
    if (htmlIt != formats.end() && !htmlIt->second.empty()) {
        const std::string& html = htmlIt->second;
        UINT htmlFormat = RegisterClipboardFormat(L"HTML Format");
        
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, html.length() + 1);
        if (hMem) {
            LPSTR htmlData = static_cast<LPSTR>(GlobalLock(hMem));
            strcpy_s(htmlData, html.length() + 1, html.c_str());
            GlobalUnlock(hMem);
            SetClipboardData(htmlFormat, hMem);
            OutputDebugStringW(L"Set HTML format\n");
        }
    }

    // Note: Image and file formats are more complex to implement
    // For now, we focus on text-based formats

    CloseClipboard();
    OutputDebugStringW(L"Clipboard updated from incoming data\n");
}

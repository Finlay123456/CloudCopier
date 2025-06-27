#include <windows.h>
#include <gdiplus.h>
#include <vector>
#include <objidl.h>
#pragma comment(lib, "gdiplus.lib")

bool GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
    UINT  num = 0;
    UINT  size = 0;

    Gdiplus::GetImageEncodersSize(&num, &size);
    if (size == 0) return false;

    std::vector<BYTE> buffer(size);
    Gdiplus::ImageCodecInfo* pImageCodecInfo = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
    if (Gdiplus::GetImageEncoders(num, size, pImageCodecInfo) != Gdiplus::Ok) return false;

    for (UINT i = 0; i < num; ++i) {
        if (wcscmp(pImageCodecInfo[i].MimeType, format) == 0) {
            *pClsid = pImageCodecInfo[i].Clsid;
            return true;
        }
    }
    return false;
}

bool encodeHBITMAPToPNG(HBITMAP hBitmap, std::vector<unsigned char>& pngData) {
    using namespace Gdiplus;

    GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR gdiplusToken;
    if (GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr) != Ok)
        return false;

    {
        Bitmap bmp(hBitmap, nullptr);  // wrap the HBITMAP safely
        CLSID pngClsid;
        if (!GetEncoderClsid(L"image/png", &pngClsid)) {
            GdiplusShutdown(gdiplusToken);
            return false;
        }

        IStream* stream = nullptr;
        if (CreateStreamOnHGlobal(NULL, TRUE, &stream) != S_OK) {
            GdiplusShutdown(gdiplusToken);
            return false;
        }

        if (bmp.Save(stream, &pngClsid, nullptr) != Ok) {
            stream->Release();
            GdiplusShutdown(gdiplusToken);
            return false;
        }

        // Get the stream data into pngData
        HGLOBAL hGlobal = nullptr;
        GetHGlobalFromStream(stream, &hGlobal);
        if (!hGlobal) {
            stream->Release();
            GdiplusShutdown(gdiplusToken);
            return false;
        }

        SIZE_T size = GlobalSize(hGlobal);
        void* pData = GlobalLock(hGlobal);
        if (pData && size > 0) {
            pngData.assign((unsigned char*)pData, (unsigned char*)pData + size);
        }
        GlobalUnlock(hGlobal);
        stream->Release();
    }

    GdiplusShutdown(gdiplusToken);
    return true;
}

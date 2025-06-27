#pragma once
#include <windows.h>
#include <vector>
bool encodeHBITMAPToPNG(HBITMAP hBitmap, std::vector<unsigned char>& pngData);

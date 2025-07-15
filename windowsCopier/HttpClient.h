#pragma once
#include <string>
#include <map>

void postClipboardText(const std::string& text);
void postClipboardImage(const std::string& base64Image);
void postClipboardFormats(const std::map<std::string, std::string>& formats, const std::string& source = "windows");

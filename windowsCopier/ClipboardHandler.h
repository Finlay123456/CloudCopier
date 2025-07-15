#pragma once
#include <string>
#include <map>

void handleClipboardUpdate();
void setClipboardFromFormats(const std::map<std::string, std::string>& formats);

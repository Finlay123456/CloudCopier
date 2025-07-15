#include <windows.h>
#include "ClipboardHandler.h"
#include "State.h"

LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
const wchar_t CLASS_NAME[] = L"ClipboardSyncWindow";

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
    WNDCLASS wc = {};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    RegisterClass(&wc);

    HWND hwnd = CreateWindowEx(0, CLASS_NAME, L"Clipboard Sync", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 300, 100, nullptr, nullptr, hInstance, nullptr);

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);


    // DEBUG: Confirm app started
    MessageBoxA(NULL, "App started successfully!", "Debug", MB_OK);

    AddClipboardFormatListener(hwnd);
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    static HWND button;
    switch (msg) {
    case WM_CREATE:
        button = CreateWindow(L"BUTTON", L"Pause", WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
            100, 20, 80, 30, hwnd, (HMENU)1, nullptr, nullptr);
        break;
    case WM_COMMAND:
        if (LOWORD(wParam) == 1) {
            togglePaused();
            SetWindowText(button, isPaused() ? L"Unpause" : L"Pause");
        }
        break;
    case WM_CLIPBOARDUPDATE:
        if (!isPaused()) {
            OutputDebugStringW(L"Clipboard update received\n");
            handleClipboardUpdate();
        }
        break;
    case WM_DESTROY:
        PostQuitMessage(0);
        break;
    default:
        return DefWindowProc(hwnd, msg, wParam, lParam);
    }
    return 0;
}

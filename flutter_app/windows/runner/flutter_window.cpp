#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter_windows.h>

#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  view_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(view_);

  // Register the first-frame callback before hiding/showing so we never miss an early frame.
  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    shown_ = true;
    ShowWindow(view_, SW_SHOW);
    SetFocus(view_);
    InvalidateRect(view_, nullptr, FALSE);
  });

  // Keep the Flutter view hidden only for the brief instant before frame 1 is ready,
  // while immediately presenting the native window with a lightweight sky splash.
  ShowWindow(view_, SW_HIDE);
  this->Show();
  UpdateWindow(GetHandle());

  // Ensure a first frame is scheduled right away.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_ERASEBKGND:
      if (!shown_) {
        return 1;
      }
      break;
    case WM_PAINT:
      if (!shown_) {
        PaintSplash(hwnd);
        return 0;
      }
      break;
    case WM_SIZE:
      if (!shown_) {
        InvalidateRect(hwnd, nullptr, FALSE);
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::PaintSplash(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC dc = BeginPaint(hwnd, &ps);
  RECT r;
  GetClientRect(hwnd, &r);
  const int height = r.bottom - r.top;
  // Lightweight luminous sky gradient matching the app's horizon palette (fast 16-band fill).
  const int bands = 16;
  for (int i = 0; i < bands; i++) {
    const double t = static_cast<double>(i) / (bands - 1);
    const COLORREF c = RGB(static_cast<int>(18 + t * 14), static_cast<int>(54 + t * 44),
                           static_cast<int>(88 + t * 40));
    RECT band = r;
    band.top = r.top + height * i / bands;
    band.bottom = r.top + height * (i + 1) / bands;
    HBRUSH brush = CreateSolidBrush(c);
    FillRect(dc, &band, brush);
    DeleteObject(brush);
  }
  const double scale = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;
  const int cx = (r.left + r.right) / 2;
  const int cy = r.top + height * 45 / 100;
  const int icon = static_cast<int>(84 * scale);
  HICON hicon = static_cast<HICON>(LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON),
                                              IMAGE_ICON, icon, icon, LR_DEFAULTCOLOR));
  if (hicon) {
    DrawIconEx(dc, cx - icon / 2, cy - icon, hicon, icon, icon, 0, nullptr, DI_NORMAL);
    DestroyIcon(hicon);
  }
  HFONT font = CreateFontW(-static_cast<int>(30 * scale), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HGDIOBJ old = SelectObject(dc, font);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(233, 215, 165));
  RECT text = r;
  text.top = cy + static_cast<int>(16 * scale);
  text.bottom = text.top + static_cast<int>(48 * scale);
  DrawTextW(dc, L"Vaktet", -1, &text, DT_CENTER | DT_SINGLELINE | DT_TOP);
  SelectObject(dc, old);
  DeleteObject(font);
  EndPaint(hwnd, &ps);
}

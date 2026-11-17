// Native Win32 operations for the dock window. Windows only.
// UNVERIFIED: not compiled or run in the authoring environment.
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'win32_bindings.dart';

/// Screen rectangle in physical pixels.
class PxRect {
  const PxRect(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  int get width => right - left;
  int get height => bottom - top;
  bool contains(int x, int y) => x >= left && x < right && y >= top && y < bottom;
  @override
  String toString() => 'PxRect($left,$top,$right,$bottom)';
}

class MonitorInfoData {
  const MonitorInfoData(this.handle, this.bounds, this.workArea, this.primary);
  final int handle;
  final PxRect bounds;
  final PxRect workArea;
  final bool primary;
}

final List<int> _enumHwnds = <int>[];
int _enumWindowsCb(int hwnd, int lParam) {
  _enumHwnds.add(hwnd);
  return 1;
}

final List<MonitorInfoData> _enumMonitors = <MonitorInfoData>[];
int _enumMonitorsCb(int hMonitor, int hdc, Pointer<RECT> rect, int lParam) {
  final info = calloc<MONITORINFO>();
  try {
    info.ref.cbSize = sizeOf<MONITORINFO>();
    if (getMonitorInfo(hMonitor, info) != 0) {
      final m = info.ref.rcMonitor;
      final w = info.ref.rcWork;
      _enumMonitors.add(MonitorInfoData(
        hMonitor,
        PxRect(m.left, m.top, m.right, m.bottom),
        PxRect(w.left, w.top, w.right, w.bottom),
        (info.ref.dwFlags & 1) != 0,
      ));
    }
  } finally {
    calloc.free(info);
  }
  return 1;
}

class NativeWindow {
  NativeWindow._(this.hwnd);
  final int hwnd;

  static bool get supported => Platform.isWindows;

  /// Finds this process's Flutter runner window (class FLUTTER_RUNNER_WIN32_WINDOW).
  static NativeWindow? findOwn() {
    if (!supported) return null;
    _enumHwnds.clear();
    final cb = Pointer.fromFunction<WndEnumProcNative>(_enumWindowsCb, 1);
    enumWindows(cb, 0);
    final pid = getCurrentProcessId();
    final pidPtr = calloc<Uint32>();
    final buf = calloc<Uint16>(256).cast<Utf16>();
    try {
      for (final h in List<int>.of(_enumHwnds)) {
        getWindowThreadProcessId(h, pidPtr);
        if (pidPtr.value != pid) continue;
        final n = getClassName(h, buf, 256);
        if (n > 0 && buf.toDartString() == 'FLUTTER_RUNNER_WIN32_WINDOW') {
          return NativeWindow._(h);
        }
      }
    } finally {
      calloc.free(pidPtr);
      calloc.free(buf);
    }
    return null;
  }

  static List<MonitorInfoData> monitors() {
    if (!supported) return const [];
    _enumMonitors.clear();
    final cb = Pointer.fromFunction<MonitorEnumProcNative>(_enumMonitorsCb, 1);
    enumDisplayMonitors(0, nullptr, cb, 0);
    final list = List<MonitorInfoData>.of(_enumMonitors);
    // Primary first, then left-to-right, so the index is stable and predictable.
    list.sort((a, b) {
      if (a.primary != b.primary) return a.primary ? -1 : 1;
      return a.bounds.left.compareTo(b.bounds.left);
    });
    return list;
  }

  /// Removes caption/borders, hides from taskbar/Alt-Tab, sets topmost.
  void makeDock({required bool alwaysOnTop}) {
    var style = getWindowLongPtr(hwnd, gwlStyle);
    style &= ~(wsCaption | wsThickFrame | wsSysMenu | wsMinimizeBox | wsMaximizeBox);
    setWindowLongPtr(hwnd, gwlStyle, style);
    var ex = getWindowLongPtr(hwnd, gwlExStyle);
    ex = (ex | wsExToolWindow | wsExNoActivate) & ~wsExAppWindow;
    setWindowLongPtr(hwnd, gwlExStyle, ex);
    setWindowPos(hwnd, alwaysOnTop ? hwndTopmost : hwndNoTopmost, 0, 0, 0, 0,
        swpNoMove | swpNoSize | swpNoActivate | swpFrameChanged);
  }

  void setAlwaysOnTop(bool value) {
    setWindowPos(hwnd, value ? hwndTopmost : hwndNoTopmost, 0, 0, 0, 0,
        swpNoMove | swpNoSize | swpNoActivate);
  }

  /// Best-effort per-pixel transparency (undocumented accent policy + DWM glass).
  /// Needs on-device verification; some Flutter engine versions still paint black.
  void enableTransparency() {
    final accent = calloc<ACCENT_POLICY>();
    final data = calloc<WINDOWCOMPOSITIONATTRIBDATA>();
    final margins = calloc<MARGINS>();
    try {
      accent.ref.accentState = 2; // ACCENT_ENABLE_TRANSPARENTGRADIENT
      accent.ref.accentFlags = 2;
      accent.ref.gradientColor = 0x00000000;
      data.ref.attribute = 19; // WCA_ACCENT_POLICY
      data.ref.data = accent.cast();
      data.ref.sizeOfData = sizeOf<ACCENT_POLICY>();
      try {
        setWindowCompositionAttribute(hwnd, data);
      } catch (_) {
        // Export missing on this Windows build; fall through to DWM only.
      }
      margins.ref.cxLeftWidth = -1;
      margins.ref.cxRightWidth = -1;
      margins.ref.cyTopHeight = -1;
      margins.ref.cyBottomHeight = -1;
      dwmExtendFrameIntoClientArea(hwnd, margins);
    } finally {
      calloc.free(accent);
      calloc.free(data);
      calloc.free(margins);
    }
  }

  void setBounds(PxRect r, {bool show = true}) {
    setWindowPos(hwnd, 0, r.left, r.top, r.width, r.height,
        swpNoZOrder | swpNoActivate | (show ? swpShowWindow : 0));
  }

  void moveTo(int x, int y) {
    setWindowPos(hwnd, 0, x, y, 0, 0, swpNoSize | swpNoZOrder | swpNoActivate);
  }

  PxRect? bounds() {
    final r = calloc<RECT>();
    try {
      if (getWindowRect(hwnd, r) == 0) return null;
      return PxRect(r.ref.left, r.ref.top, r.ref.right, r.ref.bottom);
    } finally {
      calloc.free(r);
    }
  }

  /// Scale factor relative to 96 DPI.
  double get scale {
    try {
      final dpi = getDpiForWindow(hwnd);
      return dpi <= 0 ? 1.0 : dpi / 96.0;
    } catch (_) {
      return 1.0;
    }
  }

  static (int, int)? cursor() {
    if (!supported) return null;
    final p = calloc<POINT>();
    try {
      if (getCursorPos(p) == 0) return null;
      return (p.ref.x, p.ref.y);
    } finally {
      calloc.free(p);
    }
  }
}

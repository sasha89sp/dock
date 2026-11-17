// Enumerates top-level application windows and controls them. Windows only.
// UNVERIFIED: not compiled or run in the authoring environment.
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'win32_bindings.dart';

class AppWindow {
  const AppWindow({
    required this.hwnd,
    required this.title,
    required this.exePath,
    required this.minimized,
  });
  final int hwnd;
  final String title;
  final String exePath;
  final bool minimized;
}

final List<int> _hwnds = <int>[];
int _cb(int hwnd, int lParam) {
  _hwnds.add(hwnd);
  return 1;
}

class WindowTracker {
  final int _selfPid = Platform.isWindows ? getCurrentProcessId() : 0;

  /// Visible, titled, non-tool, non-cloaked, unowned windows (taskbar-like set).
  List<AppWindow> list() {
    if (!Platform.isWindows) return const [];
    _hwnds.clear();
    enumWindows(Pointer.fromFunction<WndEnumProcNative>(_cb, 1), 0);
    final result = <AppWindow>[];
    final pidPtr = calloc<Uint32>();
    final cloaked = calloc<Int32>();
    try {
      for (final h in List<int>.of(_hwnds)) {
        if (isWindowVisible(h) == 0) continue;
        if (getWindow(h, gwOwner) != 0) continue;
        final ex = getWindowLongPtr(h, gwExStyle);
        if ((ex & wsExToolWindow) != 0 && (ex & wsExAppWindow) == 0) continue;
        cloaked.value = 0;
        dwmGetWindowAttribute(h, dwmwaCloaked, cloaked.cast(), sizeOf<Int32>());
        if (cloaked.value != 0) continue;
        final len = getWindowTextLength(h);
        if (len <= 0) continue;
        getWindowThreadProcessId(h, pidPtr);
        final pid = pidPtr.value;
        if (pid == _selfPid) continue;
        final title = _title(h, len);
        final exe = _exePath(pid);
        if (exe.isEmpty) continue;
        result.add(AppWindow(hwnd: h, title: title, exePath: exe, minimized: isIconic(h) != 0));
      }
    } finally {
      calloc.free(pidPtr);
      calloc.free(cloaked);
    }
    return result;
  }

  String _title(int h, int len) {
    final buf = calloc<Uint16>(len + 2).cast<Utf16>();
    try {
      getWindowText(h, buf, len + 1);
      return buf.toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  String _exePath(int pid) {
    final proc = openProcess(processQueryLimitedInformation, 0, pid);
    if (proc == 0) return '';
    final buf = calloc<Uint16>(1024).cast<Utf16>();
    final size = calloc<Uint32>()..value = 1024;
    try {
      if (queryFullProcessImageName(proc, 0, buf, size) == 0) return '';
      return buf.toDartString(length: size.value);
    } finally {
      calloc.free(buf);
      calloc.free(size);
      closeHandle(proc);
    }
  }

  static String norm(String p) => p.replaceAll('/', r'\').toLowerCase();

  List<AppWindow> forTarget(List<AppWindow> all, String target) {
    final t = norm(target);
    return all.where((w) => norm(w.exePath) == t).toList();
  }

  void activate(int hwnd) {
    if (isIconic(hwnd) != 0) showWindow(hwnd, swRestore);
    setForegroundWindow(hwnd);
  }

  void minimize(int hwnd) => showWindow(hwnd, swMinimize);

  /// Click behaviour: restore if minimized, minimize if already foreground, else focus.
  void toggle(int hwnd) {
    if (isIconic(hwnd) != 0) {
      activate(hwnd);
    } else if (getForegroundWindow() == hwnd) {
      minimize(hwnd);
    } else {
      activate(hwnd);
    }
  }

  /// WM_CLOSE
  void close(int hwnd) => postMessage(hwnd, 0x0010, 0, 0);
}

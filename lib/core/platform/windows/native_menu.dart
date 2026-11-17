// Native Win32 popup menu. Blocks until the user chooses (runs its own message loop).
// UNVERIFIED: not compiled or run in the authoring environment.
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'win32_bindings.dart';

class NativeMenuEntry {
  const NativeMenuEntry(this.id, this.label,
      {this.checked = false, this.enabled = true, this.separator = false});
  const NativeMenuEntry.separator()
      : id = 0,
        label = '',
        checked = false,
        enabled = true,
        separator = true;
  final int id;
  final String label;
  final bool checked;
  final bool enabled;
  final bool separator;
}

class NativeMenu {
  /// Returns the chosen entry id, or 0 if dismissed.
  static int show(int ownerHwnd, List<NativeMenuEntry> entries, int x, int y) {
    if (!Platform.isWindows) return 0;
    final menu = createPopupMenu();
    final allocated = <Pointer<Utf16>>[];
    try {
      for (final e in entries) {
        if (e.separator) {
          appendMenu(menu, mfSeparator, 0, nullptr);
          continue;
        }
        final text = e.label.toNativeUtf16();
        allocated.add(text);
        var flags = mfString;
        if (e.checked) flags |= mfChecked;
        if (!e.enabled) flags |= mfGrayed;
        appendMenu(menu, flags, e.id, text);
      }
      // Required so the menu dismisses when clicking elsewhere.
      setForegroundWindow(ownerHwnd);
      return trackPopupMenu(menu, tpmReturnCmd | tpmRightButton, x, y, 0, ownerHwnd, nullptr);
    } finally {
      destroyMenu(menu);
      for (final p in allocated) {
        calloc.free(p);
      }
    }
  }
}

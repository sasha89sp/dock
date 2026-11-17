// Pure geometry for dock placement; no Win32 calls so it is unit-testable.
import '../../models/dock_settings.dart';
import 'native_window.dart';

class DockGeometry {
  /// Returns window bounds in physical pixels.
  ///
  /// [monitor] is the monitor rectangle, [work] its work area (taskbar excluded).
  /// [width]/[height] are the window size in pixels. When [hidden], only
  /// [peek] pixels stay on screen at the docked edge. [offset] shifts the dock
  /// along the edge (px) from the centered position.
  static PxRect place({
    required DockPosition position,
    required PxRect work,
    required int width,
    required int height,
    bool hidden = false,
    int peek = 2,
    int offset = 0,
  }) {
    int clampAxis(int v, int lo, int hi) => hi < lo ? lo : v.clamp(lo, hi).toInt();
    switch (position) {
      case DockPosition.top:
      case DockPosition.bottom:
        final x = clampAxis(work.left + (work.width - width) ~/ 2 + offset,
            work.left, work.right - width);
        final shown = position == DockPosition.top ? work.top : work.bottom - height;
        final hiddenY =
            position == DockPosition.top ? work.top - height + peek : work.bottom - peek;
        final y = hidden ? hiddenY : shown;
        return PxRect(x, y, x + width, y + height);
      case DockPosition.left:
      case DockPosition.right:
        final y = clampAxis(work.top + (work.height - height) ~/ 2 + offset,
            work.top, work.bottom - height);
        final shown = position == DockPosition.left ? work.left : work.right - width;
        final hiddenX =
            position == DockPosition.left ? work.left - width + peek : work.right - peek;
        final x = hidden ? hiddenX : shown;
        return PxRect(x, y, x + width, y + height);
    }
  }

  /// Linear interpolation between two rects (animation step).
  static PxRect lerp(PxRect a, PxRect b, double t) {
    int l(int x, int y) => (x + (y - x) * t).round();
    return PxRect(l(a.left, b.left), l(a.top, b.top), l(a.right, b.right), l(a.bottom, b.bottom));
  }
}

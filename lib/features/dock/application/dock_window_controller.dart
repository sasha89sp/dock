// Places the native dock window, handles auto-hide and multi-monitor placement.
// UNVERIFIED: not compiled or run in the authoring environment.
import 'dart:async';
import 'dart:math' as math;

import '../../../core/models/dock_settings.dart';
import '../../../core/platform/windows/dock_geometry.dart';
import '../../../core/platform/windows/native_window.dart';

class DockWindowController {
  DockWindowController({required this.settings});

  /// Always read through the getter so settings changes are picked up.
  final DockSettings Function() settings;

  NativeWindow? _window;
  Timer? _poll;
  Timer? _anim;
  DateTime? _overSince;
  DateTime? _notOverSince;
  bool hidden = false;

  /// Set while a menu is open or an item is being dragged.
  bool holdVisible = false;

  /// Logical window size requested by the UI.
  double _logicalW = 400, _logicalH = 100;
  int _tick = 0;
  List<MonitorInfoData> _monitors = const [];

  bool get attached => _window != null;

  int get hwnd => _window?.hwnd ?? 0;

  bool attach() {
    _window = NativeWindow.findOwn();
    final w = _window;
    if (w == null) return false;
    w.makeDock(alwaysOnTop: settings().alwaysOnTop);
    w.enableTransparency();
    _monitors = NativeWindow.monitors();
    apply();
    _poll ??= Timer.periodic(const Duration(milliseconds: 50), (_) => _onTick());
    return true;
  }

  void dispose() {
    _poll?.cancel();
    _anim?.cancel();
  }

  void setLogicalSize(double w, double h) {
    if ((w - _logicalW).abs() < .5 && (h - _logicalH).abs() < .5) return;
    _logicalW = w;
    _logicalH = h;
    apply();
  }

  MonitorInfoData? _monitor() {
    if (_monitors.isEmpty) return null;
    final i = settings().monitorIndex;
    return _monitors[(i >= 0 && i < _monitors.length) ? i : 0];
  }

  PxRect? _target({required bool asHidden}) {
    final w = _window;
    final m = _monitor();
    if (w == null || m == null) return null;
    final s = settings();
    final scale = w.scale;
    return DockGeometry.place(
      position: s.position,
      work: m.workArea,
      width: (_logicalW * scale).round(),
      height: (_logicalH * scale).round(),
      hidden: asHidden && s.autoHide,
      offset: (s.edgeOffset * scale).round(),
    );
  }

  /// Re-applies size/position immediately (no animation).
  void apply() {
    final w = _window;
    if (w == null) return;
    final s = settings();
    if (!s.autoHide) hidden = false;
    final r = _target(asHidden: hidden);
    if (r != null) w.setBounds(r);
  }

  void _onTick() {
    final w = _window;
    if (w == null) return;
    _tick++;
    if (_tick % 40 == 0) {
      // ~2 s: pick up monitor changes and keep z-order.
      _monitors = NativeWindow.monitors();
      w.setAlwaysOnTop(settings().alwaysOnTop);
      if (_anim == null) apply();
    }
    final s = settings();
    if (!s.autoHide) {
      if (hidden) {
        hidden = false;
        _animateTo(false);
      }
      return;
    }
    final c = NativeWindow.cursor();
    final b = w.bounds();
    if (c == null || b == null) return;
    final over = b.contains(c.$1, c.$2);
    final now = DateTime.now();
    if (over || holdVisible) {
      _notOverSince = null;
      if (hidden) {
        _overSince ??= now;
        if (now.difference(_overSince!).inMilliseconds >= s.showDelayMs) {
          _overSince = null;
          hidden = false;
          _animateTo(false);
        }
      }
    } else {
      _overSince = null;
      if (!hidden) {
        _notOverSince ??= now;
        if (now.difference(_notOverSince!).inMilliseconds >= s.hideDelayMs) {
          _notOverSince = null;
          hidden = true;
          _animateTo(true);
        }
      }
    }
  }

  void _animateTo(bool toHidden) {
    final w = _window;
    final end = _target(asHidden: toHidden);
    final start = w?.bounds();
    if (w == null || end == null || start == null) return;
    _anim?.cancel();
    final total = math.max(1, settings().animationMs);
    final began = DateTime.now();
    _anim = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final p = math.min(1.0, DateTime.now().difference(began).inMilliseconds / total);
      final eased = 1 - math.pow(1 - p, 3).toDouble();
      w.setBounds(DockGeometry.lerp(start, end, eased), show: false);
      if (p >= 1) {
        t.cancel();
        _anim = null;
      }
    });
  }
}

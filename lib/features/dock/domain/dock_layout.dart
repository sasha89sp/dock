import '../../../core/models/dock_settings.dart';

/// Pure layout math (logical pixels) shared by the dock widget and window sizing.
class DockLayout {
  static const double pad = 10;
  static const double gap = 6;
  static const double indicator = 8;
  static const double shadow = 8;
  static const double labelAlong = 28; // label strip for horizontal docks
  static const double labelAcross = 160; // label strip for vertical docks
  static const double separatorSize = 14;

  static bool isVertical(DockPosition p) => p == DockPosition.left || p == DockPosition.right;

  /// Scale of icon at [index] when [hovered] is the hovered index (linear falloff).
  static double scaleAt(int index, int? hovered, DockSettings s) {
    if (hovered == null) return 1;
    final d = (index - hovered).abs();
    if (d > s.zoomNeighbors) return 1;
    return 1 + (s.zoom - 1) * (1 - d / (s.zoomNeighbors + 1));
  }

  /// Window size (logical px) that fits the dock at maximum zoom without resizing.
  static ({double width, double height}) windowSize(DockSettings s, List<bool> separators) {
    final n = separators.length;
    final seps = separators.where((e) => e).length;
    final icons = n - seps;
    final extra = s.iconSize * (s.zoom - 1) * (1 + s.zoomNeighbors);
    final along = icons * (s.iconSize + gap) + seps * separatorSize + extra + 2 * pad + 2 * shadow;
    final across = s.iconSize * s.zoom + 2 * pad + indicator + shadow +
        (s.labels ? (isVertical(s.position) ? labelAcross : labelAlong) : 0);
    return isVertical(s.position)
        ? (width: across, height: along)
        : (width: along, height: across);
  }
}

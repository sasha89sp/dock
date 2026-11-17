import 'package:flutter_test/flutter_test.dart';
import 'package:rocketdock_next/core/models/dock_settings.dart';
import 'package:rocketdock_next/core/platform/windows/dock_geometry.dart';
import 'package:rocketdock_next/core/platform/windows/native_window.dart';
import 'package:rocketdock_next/features/dock/domain/dock_layout.dart';

void main() {
  const work = PxRect(0, 0, 1920, 1040);

  test('top dock is centered on the work area edge', () {
    final r = DockGeometry.place(position: DockPosition.top, work: work, width: 800, height: 100);
    expect((r.left, r.top, r.right, r.bottom), (560, 0, 1360, 100));
  });

  test('bottom dock sits on the bottom edge; hidden leaves a 2px strip', () {
    final shown = DockGeometry.place(position: DockPosition.bottom, work: work, width: 800, height: 100);
    expect(shown.top, 940);
    final hidden = DockGeometry.place(
        position: DockPosition.bottom, work: work, width: 800, height: 100, hidden: true);
    expect(hidden.top, 1038);
  });

  test('left/right docks and offset clamping', () {
    final left = DockGeometry.place(position: DockPosition.left, work: work, width: 100, height: 600);
    expect((left.left, left.top), (0, 220));
    final hiddenRight = DockGeometry.place(
        position: DockPosition.right, work: work, width: 100, height: 600, hidden: true);
    expect(hiddenRight.left, 1918);
    final off = DockGeometry.place(
        position: DockPosition.top, work: work, width: 800, height: 100, offset: 5000);
    expect(off.right, 1920);
  });

  test('secondary monitor work area is respected', () {
    const second = PxRect(1920, 0, 3840, 1080);
    final r = DockGeometry.place(position: DockPosition.bottom, work: second, width: 600, height: 80);
    expect(r.left, 1920 + (1920 - 600) ~/ 2);
    expect(r.bottom, 1080);
  });

  test('window size reserves room for maximum zoom', () {
    final s = DockSettings(iconSize: 48, zoom: 2, zoomNeighbors: 2, labels: true);
    final small = DockLayout.windowSize(s, [false, false, false]);
    final big = DockLayout.windowSize(s, List.filled(10, false));
    expect(big.width, greaterThan(small.width));
    expect(small.height, greaterThanOrEqualTo(48 * 2));
    expect(DockLayout.scaleAt(5, 5, s), 2);
    expect(DockLayout.scaleAt(5, 9, s), 1);
  });
}

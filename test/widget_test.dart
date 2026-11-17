import 'package:flutter_test/flutter_test.dart';
import 'package:rocketdock_next/core/models/dock_settings.dart';

void main() {
  test('settings round trip preserves dock configuration', () {
    final original = DockSettings(iconSize: 64, opacity: .75, autoHide: true);
    final restored = DockSettings.fromJson(original.toJson());
    expect(restored.iconSize, 64);
    expect(restored.opacity, .75);
    expect(restored.autoHide, isTrue);
  });
}

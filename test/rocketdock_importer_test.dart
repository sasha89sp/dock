import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocketdock_next/core/data/rocketdock_importer.dart';
import 'package:rocketdock_next/core/models/dock_settings.dart';

// Fixture: trimmed copy of a real RocketDock 1.3.5 Settings.ini (cp1251, CRLF).
void main() {
  test('imports a real RocketDock 1.3.5 Settings.ini', () async {
    final temp = await Directory.systemTemp.createTemp('rd-import-');
    addTearDown(() => temp.delete(recursive: true));
    final ini = File('${temp.path}${Platform.pathSeparator}Settings.ini');
    await File('test/fixtures/rocketdock_1_3_5_Settings.ini').copy(ini.path);
    final settings = DockSettings();
    final result = await RocketDockImporter().importFromIni(
      iniFile: ini,
      target: settings,
      destinationData: Directory('${temp.path}${Platform.pathSeparator}data'),
    );
    expect(settings.iconSize, 24);
    expect(settings.zoom, closeTo(26 / 24, 1e-9));
    expect(settings.zoomNeighbors, 2);
    expect(settings.animationMs, 200);
    expect(settings.themeName, 'CrystalXP.net');
    expect(settings.position, DockPosition.top);
    expect(settings.autoHide, isFalse);
    expect(settings.labels, isTrue);
    expect(settings.items.length, 8); // 7 entries + 1 separator, in file order
    final first = settings.items.first;
    expect(first.title, 'Загрузки'); // cp1251 decoded
    expect(first.target, r'C:\Users\User\Downloads');
    expect(first.iconPath, r'C:\Windows\System32\imageres.dll?-184');
    expect(settings.items[1].target, '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}');
    expect(settings.items.any((e) => e.isSeparator), isTrue);
    final lock = settings.items.firstWhere((e) => e.title == 'Заблокировать');
    expect(lock.target, r'C:\Windows\System32\rundll32.exe');
    expect(lock.arguments, startsWith('user32.dll'));
    final notepad = settings.items.firstWhere((e) => e.id == 'rocketdock-69');
    expect(notepad.iconPath, contains('RocketDockAssets'));
    expect(result.importedItems, 7);
    expect(result.warnings, isNotEmpty);
  });

  test('decodeText falls back to cp1251', () {
    expect(RocketDockImporter.decodeText([0xC7, 0xE0, 0xE3]), 'Заг');
  });
}

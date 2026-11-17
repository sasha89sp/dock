import 'dart:convert';
import 'dart:io';

import '../models/dock_item.dart';
import '../models/dock_settings.dart';

class RocketDockImportResult {
  const RocketDockImportResult({
    required this.importedSettings,
    required this.importedItems,
    required this.copiedAssetFolders,
    required this.warnings,
  });

  final int importedSettings;
  final int importedItems;
  final List<String> copiedAssetFolders;
  final List<String> warnings;
}

/// Imports a RocketDock 1.3.5 portable `Settings.ini`.
///
/// Format confirmed against a real 1.3.5 file (ANSI/cp1251, CRLF):
/// - `[Software\RocketDock]`: scalar settings (Theme, IconMin, IconMax, ZoomWidth, ...)
/// - `[Software\RocketDock\Icons]`: `count=N` and flat keys `<n>-FileName`, `-FileName2`,
///   `-Title`, `-Command`, `-Arguments`, `-WorkingDirectory`, `-ShowCmd`, `-OpenRunning`,
///   `-IsSeparator`, `-UseContext`, `-DockletFile`
/// - `[Software\RocketDock\WindowFilters]`: `count=N`
/// `FileName` is the ICON source (`path?index`), `Command` is the launch target.
/// Values whose meaning is not confirmed are not applied and produce a warning.
class RocketDockImporter {
  static const _rootSection = r'software\rocketdock';
  static const _iconsSection = r'software\rocketdock\icons';
  static const _filtersSection = r'software\rocketdock\windowfilters';

  Future<RocketDockImportResult> importFromIni({
    required File iniFile,
    required DockSettings target,
    required Directory destinationData,
  }) async {
    if (!await iniFile.exists()) {
      throw FileSystemException('Файл Settings.ini не найден', iniFile.path);
    }
    final sourceDirectory = iniFile.parent;
    final parsed = parseIni(decodeText(await iniFile.readAsBytes()));
    final warnings = <String>[];
    var importedSettings = 0;

    final root = parsed[_rootSection];
    if (root == null) {
      warnings.add('Секция [Software\\RocketDock] не найдена: это не Settings.ini RocketDock 1.3.5.');
    } else {
      int? intOf(String key) => int.tryParse((root[key.toLowerCase()] ?? '').trim());
      bool? boolOf(String key) {
        final v = intOf(key);
        return v == null ? null : v != 0;
      }

      void set<T>(T? v, void Function(T) f) {
        if (v != null) {
          f(v);
          importedSettings++;
        }
      }

      final iconMin = intOf('IconMin');
      final iconMax = intOf('IconMax');
      set(iconMin, (v) => target.iconSize = v.clamp(16, 128).toDouble());
      if (iconMin != null && iconMin > 0 && iconMax != null && iconMax >= iconMin) {
        set(iconMax / iconMin, (v) => target.zoom = v.clamp(1, 3).toDouble());
      }
      set(intOf('ZoomWidth'), (v) => target.zoomNeighbors = v.clamp(1, 10).toInt());
      set(intOf('ZoomTicks'), (v) => target.animationMs = v.clamp(100, 500).toInt());
      set(intOf('ThemeOpacity'), (v) => target.opacity = (v / 100).clamp(0, 1).toDouble());
      set(boolOf('LockIcons'), (v) => target.lockIcons = v);
      set(boolOf('AutoHide'), (v) => target.autoHide = v);
      set(intOf('AutoHideDelay'), (v) => target.hideDelayMs = v.clamp(0, 2000).toInt());
      set(intOf('PopupDelay'), (v) => target.showDelayMs = v.clamp(0, 1000).toInt());
      set(boolOf('ManageWindows'), (v) => target.minimizeToDock = v);
      set(boolOf('ShowRunning'), (v) => target.runningIndicator = v);
      set(boolOf('OpenRunning'), (v) => target.activateInsteadOfLaunch = v);
      set(boolOf('HideLabels'), (v) => target.labels = !v);
      set(intOf('Offset'), (v) => target.edgeOffset = v.clamp(-2000, 2000).toInt());
      final theme = (root['theme'] ?? '').trim();
      if (theme.isNotEmpty) set(theme, (v) => target.themeName = v);

      // Side: only 0 is confirmed (RocketDock default = top edge). Others are not guessed.
      final side = intOf('Side');
      if (side == 0) {
        target.position = DockPosition.top;
        importedSettings++;
      } else if (side != null) {
        warnings.add('Side=$side: соответствие стороне экрана не подтверждено, положение не изменено.');
      }
      final monitor = intOf('Monitor');
      if (monitor != null && monitor != 1) {
        warnings.add('Monitor=$monitor: нумерация мониторов RocketDock не подтверждена, выбран основной.');
      }
      warnings.add('Не перенесены (нет аналога): шрифт и контур подписей, IconQuality, HoverFX, '
          'IconActivationFX, zOrderMode, vOffset, горячая клавиша, ZoomOpaque.');
    }

    final items = <DockItem>[];
    final icons = parsed[_iconsSection];
    if (icons == null) {
      warnings.add('Секция [Software\\RocketDock\\Icons] не найдена: ярлыки не импортированы.');
    } else {
      final declared = int.tryParse(icons['count'] ?? '');
      final indexes = <int>{};
      for (final key in icons.keys) {
        final m = RegExp(r'^(\d+)-').firstMatch(key);
        if (m != null) indexes.add(int.parse(m.group(1)!));
      }
      final ordered = indexes.toList()..sort();
      if (declared != null && declared != ordered.length) {
        warnings.add('count=$declared, но найдено записей: ${ordered.length}.');
      }
      var docklets = 0;
      for (final n in ordered) {
        String v(String field) => (icons['$n-${field.toLowerCase()}'] ?? '').trim();
        final id = 'rocketdock-$n';
        if (v('IsSeparator') == '1') {
          items.add(DockItem(id: id, title: '', target: '', isSeparator: true));
          continue;
        }
        if (v('DockletFile').isNotEmpty) {
          docklets++;
          continue;
        }
        final command = v('Command');
        if (command.isEmpty) {
          warnings.add('Запись $n (${v('Title')}) без Command пропущена.');
          continue;
        }
        final icon = _relocate(v('FileName'), sourceDirectory, destinationData);
        final icon2 = _relocate(v('FileName2'), sourceDirectory, destinationData);
        items.add(DockItem(
          id: id,
          title: v('Title').isEmpty ? _basename(command) : v('Title'),
          target: command,
          isUrl: command.startsWith('http://') || command.startsWith('https://'),
          iconPath: icon.isEmpty ? null : icon,
          iconPath2: icon2.isEmpty ? null : icon2,
          arguments: v('Arguments'),
          workingDirectory: v('WorkingDirectory'),
        ));
      }
      if (docklets > 0) {
        warnings.add('Docklets не исполняются, пропущено записей: $docklets.');
      }
      if (items.isNotEmpty) {
        target.items = items;
      }
    }
    final filters = int.tryParse(parsed[_filtersSection]?['count'] ?? '') ?? 0;
    if (filters > 0) warnings.add('WindowFilters ($filters) пока не применяются.');

    final copied = <String>[];
    await destinationData.create(recursive: true);
    for (final folderName in ['Icons', 'Skins', 'Docklets']) {
      final source = Directory('${sourceDirectory.path}${Platform.pathSeparator}$folderName');
      if (!await source.exists()) continue;
      final destination = Directory(
        '${destinationData.path}${Platform.pathSeparator}RocketDockAssets${Platform.pathSeparator}$folderName',
      );
      await _copyDirectory(source, destination);
      copied.add(folderName);
    }
    if (copied.isEmpty) {
      warnings.add('Рядом с Settings.ini нет папок Icons/Skins/Docklets: значки вида Icons\\*.png '
          'не будут найдены, пока папки не скопированы.');
    }

    return RocketDockImportResult(
      importedSettings: importedSettings,
      importedItems: items.where((e) => !e.isSeparator).length,
      copiedAssetFolders: copied,
      warnings: warnings,
    );
  }

  /// Section and key names are lower-cased; values keep case.
  static Map<String, Map<String, String>> parseIni(String input) {
    final result = <String, Map<String, String>>{};
    var section = '';
    for (final raw in input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith(';')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim().toLowerCase();
        result.putIfAbsent(section, () => {});
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      result.putIfAbsent(section, () => {})[line.substring(0, eq).trim().toLowerCase()] =
          line.substring(eq + 1).trim();
    }
    return result;
  }

  /// UTF-16/UTF-8 (with BOM) or valid UTF-8; otherwise Windows-1251 (RocketDock writes ANSI).
  static String decodeText(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final units = <int>[
        for (var i = 2; i + 1 < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8)
      ];
      return String.fromCharCodes(units);
    }
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return String.fromCharCodes(bytes.map((b) => b < 0x80 ? b : _cp1251[b - 0x80]));
    }
  }

  /// Keeps `?index` suffix. Paths inside the RocketDock folder (absolute or relative like
  /// `Icons\x.png`) point to the copied assets under data/RocketDockAssets.
  String _relocate(String raw, Directory source, Directory dest) {
    if (raw.isEmpty) return '';
    final q = raw.lastIndexOf('?');
    final hasIndex = q > 1 && RegExp(r'^-?\d+$').hasMatch(raw.substring(q + 1));
    final path = hasIndex ? raw.substring(0, q) : raw;
    final suffix = hasIndex ? raw.substring(q) : '';
    final sep = Platform.pathSeparator;
    final assets = '${dest.path}${sep}RocketDockAssets';
    final isAbsolute = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) || path.startsWith(r'\\');
    if (!isAbsolute && !path.startsWith('%')) {
      return '$assets$sep${path.replaceAll('\\', sep)}$suffix';
    }
    final root = source.absolute.path.toLowerCase().replaceAll('/', '\\');
    final lower = path.toLowerCase().replaceAll('/', '\\');
    if (lower.startsWith('$root\\')) {
      return '$assets$sep${path.substring(root.length + 1).replaceAll('\\', sep)}$suffix';
    }
    return raw;
  }

  String _basename(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final name = entity.uri.pathSegments.where((e) => e.isNotEmpty).last;
      final target = '${destination.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  static const List<int> _cp1251 = [
0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, 0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F, 0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F, 0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7, 0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407, 0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7, 0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457, 0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417, 0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F, 0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427, 0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, 0x042F, 0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437, 0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F, 0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447, 0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F
  ];
}

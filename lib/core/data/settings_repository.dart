import 'dart:convert';
import 'dart:io';

import '../models/dock_item.dart';
import '../models/dock_settings.dart';

/// All mutable application data is kept beside the executable.
class SettingsRepository {
  static const _fileName = 'settings.json';
  late final Directory dataDirectory;
  late final File _settingsFile;
  DockSettings settings = DockSettings();

  /// False when settings.json did not exist at load time (first run).
  bool existedOnLoad = false;
  DateTime? _knownWrite;

  SettingsRepository() {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    dataDirectory = Directory(
      '${executableDirectory.path}${Platform.pathSeparator}data',
    );
    _settingsFile = File(
      '${dataDirectory.path}${Platform.pathSeparator}$_fileName',
    );
  }

  Future<void> load() async {
    await dataDirectory.create(recursive: true);
    existedOnLoad = await _settingsFile.exists();
    if (!existedOnLoad) return;
    _knownWrite = await _settingsFile.lastModified();
    try {
      final decoded = jsonDecode(await _settingsFile.readAsString());
      if (decoded is Map<String, dynamic>) {
        settings = DockSettings.fromJson(decoded);
      }
    } on FormatException {
      // Keep defaults; preserve the damaged file for manual recovery.
      final backup = File('${_settingsFile.path}.corrupt');
      if (!await backup.exists()) await _settingsFile.copy(backup.path);
    } on TypeError {
      final backup = File('${_settingsFile.path}.corrupt');
      if (!await backup.exists()) await _settingsFile.copy(backup.path);
    }
  }

  Future<void> save() async {
    await dataDirectory.create(recursive: true);
    final temp = File('${_settingsFile.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
    if (await _settingsFile.exists()) await _settingsFile.delete();
    await temp.rename(_settingsFile.path);
    _knownWrite = await _settingsFile.lastModified();
  }

  /// Reloads settings.json if another process (e.g. the settings window) changed it.
  /// Returns true when new settings were loaded.
  Future<bool> reloadIfChanged() async {
    if (!await _settingsFile.exists()) return false;
    final modified = await _settingsFile.lastModified();
    if (_knownWrite != null && !modified.isAfter(_knownWrite!)) return false;
    await load();
    return true;
  }

  Future<void> reset() async {
    settings = DockSettings(items: DockItem.defaults());
    await save();
  }

  String get storagePath => _settingsFile.path;
}

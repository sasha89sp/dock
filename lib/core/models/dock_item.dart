class DockItem {
  const DockItem({
    required this.id,
    required this.title,
    required this.target,
    this.iconCodePoint = 0xe0b0,
    this.isUrl = false,
    this.iconPath,
    this.iconPath2,
    this.arguments = '',
    this.workingDirectory = '',
    this.isSeparator = false,
  });

  final String id;
  final String title;

  /// File, folder, URL, shell path (`::{CLSID}`) or RocketDock special (`[RecycleBin]`).
  final String target;
  final int iconCodePoint;
  final bool isUrl;

  /// Icon source: image file, or `file?index` (RocketDock style) for EXE/DLL/ICO.
  final String? iconPath;

  /// Optional second icon (RocketDock `FileName2`, e.g. full Recycle Bin).
  final String? iconPath2;
  final String arguments;
  final String workingDirectory;
  final bool isSeparator;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'target': target,
        'iconCodePoint': iconCodePoint,
        'isUrl': isUrl,
        'iconPath': iconPath,
        'iconPath2': iconPath2,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'isSeparator': isSeparator,
      };

  factory DockItem.fromJson(Map<String, dynamic> json) => DockItem(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Приложение',
        target: json['target'] as String? ?? '',
        iconCodePoint: json['iconCodePoint'] as int? ?? 0xe0b0,
        isUrl: json['isUrl'] as bool? ?? false,
        iconPath: json['iconPath'] as String?,
        iconPath2: json['iconPath2'] as String?,
        arguments: json['arguments'] as String? ?? '',
        workingDirectory: json['workingDirectory'] as String? ?? '',
        isSeparator: json['isSeparator'] as bool? ?? false,
      );

  /// Seeded once when no settings.json exists yet.
  static List<DockItem> defaults() => [
        const DockItem(id: 'home', title: 'Домашняя папка', target: r'%USERPROFILE%', iconCodePoint: 0xe318),
        const DockItem(id: 'browser', title: 'Браузер', target: 'https://www.google.com', isUrl: true, iconCodePoint: 0xe3c7),
        const DockItem(id: 'settings', title: 'Настройки Windows', target: 'ms-settings:', iconCodePoint: 0xe8b8),
      ];
}

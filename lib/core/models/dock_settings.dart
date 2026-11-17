import 'dock_item.dart';

enum DockPosition { top, bottom, left, right }

class DockSettings {
  DockSettings({
    this.position = DockPosition.top,
    this.iconSize = 48,
    this.zoom = 1.8,
    this.opacity = 1,
    this.zoomStep = 2,
    this.zoomNeighbors = 2,
    this.animationMs = 200,
    this.quality = 'Среднее',
    this.themeName = 'Crystal',
    this.labels = true,
    this.autoStart = false,
    this.minimizeToDock = false,
    this.runningIndicator = true,
    this.activateInsteadOfLaunch = true,
    this.lockIcons = false,
    this.autoHide = false,
    this.hideDelayMs = 250,
    this.showDelayMs = 250,
    this.alwaysOnTop = true,
    this.monitorIndex = 0,
    this.edgeOffset = 0,
    this.activationEffect = 'Подпрыгивание',
    List<DockItem>? items,
  }) : items = items ?? <DockItem>[];

  DockPosition position;
  double iconSize;
  double zoom;
  double opacity;
  int zoomStep;
  int zoomNeighbors;
  int animationMs;
  String quality;
  String themeName;
  bool labels;
  bool autoStart;
  bool minimizeToDock;
  bool runningIndicator;
  bool activateInsteadOfLaunch;
  bool lockIcons;
  bool autoHide;
  int hideDelayMs;
  int showDelayMs;
  bool alwaysOnTop;

  /// 0 = primary; otherwise index in the sorted monitor list (primary first, then left-to-right).
  int monitorIndex;

  /// Shift along the screen edge in px (negative = left/up).
  int edgeOffset;

  /// Подпрыгивание | Подсвечивание | Масштабирование | Нет
  String activationEffect;
  List<DockItem> items;

  Map<String, Object?> toJson() => {
        'position': position.name, 'iconSize': iconSize, 'zoom': zoom,
        'opacity': opacity, 'zoomStep': zoomStep, 'zoomNeighbors': zoomNeighbors,
        'animationMs': animationMs, 'quality': quality, 'themeName': themeName,
        'labels': labels, 'autoStart': autoStart, 'minimizeToDock': minimizeToDock,
        'runningIndicator': runningIndicator, 'activateInsteadOfLaunch': activateInsteadOfLaunch,
        'lockIcons': lockIcons, 'autoHide': autoHide, 'hideDelayMs': hideDelayMs,
        'showDelayMs': showDelayMs, 'alwaysOnTop': alwaysOnTop,
        'monitorIndex': monitorIndex, 'edgeOffset': edgeOffset,
        'activationEffect': activationEffect,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory DockSettings.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return DockSettings(
      position: DockPosition.values.firstWhere(
        (e) => e.name == json['position'], orElse: () => DockPosition.top),
      iconSize: (json['iconSize'] as num?)?.toDouble() ?? 48,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.8,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      zoomStep: json['zoomStep'] as int? ?? 2,
      zoomNeighbors: json['zoomNeighbors'] as int? ?? 2,
      animationMs: json['animationMs'] as int? ?? 200,
      quality: json['quality'] as String? ?? 'Среднее',
      themeName: json['themeName'] as String? ?? 'Crystal',
      labels: json['labels'] as bool? ?? true,
      autoStart: json['autoStart'] as bool? ?? false,
      minimizeToDock: json['minimizeToDock'] as bool? ?? false,
      runningIndicator: json['runningIndicator'] as bool? ?? true,
      activateInsteadOfLaunch: json['activateInsteadOfLaunch'] as bool? ?? true,
      lockIcons: json['lockIcons'] as bool? ?? false,
      autoHide: json['autoHide'] as bool? ?? false,
      hideDelayMs: json['hideDelayMs'] as int? ?? 250,
      showDelayMs: json['showDelayMs'] as int? ?? 250,
      alwaysOnTop: json['alwaysOnTop'] as bool? ?? true,
      monitorIndex: json['monitorIndex'] as int? ?? 0,
      edgeOffset: json['edgeOffset'] as int? ?? 0,
      activationEffect: json['activationEffect'] as String? ?? 'Подпрыгивание',
      items: rawItems.whereType<Map<String, dynamic>>().map(DockItem.fromJson).toList(),
    );
  }
}

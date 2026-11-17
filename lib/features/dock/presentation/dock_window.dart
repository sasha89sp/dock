import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/data/settings_repository.dart';
import '../../../core/models/dock_item.dart';
import '../../../core/models/dock_settings.dart';
import '../../../core/platform/app_launcher.dart';
import '../../../core/platform/windows/icon_service.dart';
import '../../../core/platform/windows/native_menu.dart';
import '../../../core/platform/windows/native_window.dart';
import '../../../core/platform/windows/window_tracker.dart';
import '../application/dock_window_controller.dart';
import '../domain/dock_layout.dart';

/// The dock. With [standalone] it owns the native window (position, auto-hide, topmost);
/// without it (settings preview) it only draws.
class DockWindow extends StatefulWidget {
  const DockWindow({super.key, required this.repository, this.standalone = false});
  final SettingsRepository repository;
  final bool standalone;

  @override
  State<DockWindow> createState() => _DockWindowState();
}

class _DockWindowState extends State<DockWindow> {
  final _launcher = AppLauncher();
  final _icons = IconService();
  final _tracker = WindowTracker();
  late final DockWindowController _controller;
  Timer? _runningTimer;
  List<AppWindow> _running = const [];
  int? _hovered;
  int? _fxIndex;

  DockSettings get _s => widget.repository.settings;

  @override
  void initState() {
    super.initState();
    _controller = DockWindowController(settings: () => _s);
    if (widget.standalone && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.attach();
        _refreshRunning();
      });
      _runningTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshRunning());
    }
  }

  @override
  void dispose() {
    _runningTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadSettings() async {
    if (!await widget.repository.reloadIfChanged() || !mounted) return;
    _controller.apply();
    setState(() {});
  }

  void _refreshRunning() {
    if (!mounted) return;
    _reloadSettings();
    final list = _tracker.list();
    final changed = list.length != _running.length ||
        List.generate(list.length, (i) => i).any((i) =>
            list[i].hwnd != _running[i].hwnd || list[i].minimized != _running[i].minimized);
    if (changed) setState(() => _running = list);
  }

  List<DockItem> get _base => _s.items;

  /// Configured items plus (optionally) minimized windows that have no dock item.
  List<DockItem> _visibleItems() {
    final items = List<DockItem>.of(_base);
    if (_s.minimizeToDock) {
      final known = items.where((e) => !e.isSeparator).map((e) => WindowTracker.norm(
          AppLauncher.expandEnv(e.target)));
      for (final w in _running.where((w) => w.minimized)) {
        if (known.contains(WindowTracker.norm(w.exePath))) continue;
        items.add(DockItem(id: 'win-${w.hwnd}', title: w.title, target: w.exePath));
      }
    }
    return items;
  }

  List<AppWindow> _windowsFor(DockItem item) {
    if (item.isSeparator || item.isUrl) return const [];
    if (item.id.startsWith('win-')) {
      return _running.where((w) => 'win-${w.hwnd}' == item.id).toList();
    }
    return _tracker.forTarget(_running, AppLauncher.expandEnv(item.target));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final items = _visibleItems();
    final size = DockLayout.windowSize(s, items.map((e) => e.isSeparator).toList());
    if (widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.setLogicalSize(size.width, size.height);
      });
    }
    final vertical = DockLayout.isVertical(s.position);
    final pill = MouseRegion(
      onExit: (_) => setState(() => _hovered = null),
      child: Container(
        padding: const EdgeInsets.all(DockLayout.pad),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2638).withValues(alpha: .85 * s.opacity),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: (s.position == DockPosition.top || s.position == DockPosition.left)
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: _buildIcons(items, s, vertical),
        ),
      ),
    );
    final hoveredItem = (_hovered != null && _hovered! < items.length) ? items[_hovered!] : null;
    final label = s.labels
        ? SizedBox(
            width: vertical ? DockLayout.labelAcross : null,
            height: vertical ? null : DockLayout.labelAlong,
            child: Align(
              alignment: Alignment.center,
              child: hoveredItem == null || hoveredItem.isSeparator
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(hoveredItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
            ),
          )
        : const SizedBox.shrink();
    const edge = SizedBox(width: DockLayout.shadow, height: DockLayout.shadow);
    final Widget content = switch (s.position) {
      DockPosition.bottom => Column(mainAxisAlignment: MainAxisAlignment.end, children: [label, pill, edge]),
      DockPosition.top => Column(mainAxisAlignment: MainAxisAlignment.start, children: [edge, pill, label]),
      DockPosition.left => Row(mainAxisAlignment: MainAxisAlignment.start, children: [edge, pill, label]),
      DockPosition.right => Row(mainAxisAlignment: MainAxisAlignment.end, children: [label, pill, edge]),
    };
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTap: () => _showMenu(null, items),
        child: SizedBox.expand(child: content),
      ),
    );
  }

  List<Widget> _buildIcons(List<DockItem> items, DockSettings s, bool vertical) {
    return List.generate(items.length, (index) {
      final item = items[index];
      if (item.isSeparator) {
        return Container(
          width: vertical ? s.iconSize : 1,
          height: vertical ? 1 : s.iconSize,
          margin: EdgeInsets.symmetric(
              horizontal: vertical ? 0 : DockLayout.separatorSize / 2 - .5,
              vertical: vertical ? DockLayout.separatorSize / 2 - .5 : 0),
          color: Colors.white24,
        );
      }
      final scale = DockLayout.scaleAt(index, _hovered, s);
      final size = s.iconSize * scale;
      final running = s.runningIndicator && _windowsFor(item).isNotEmpty;
      final box = MouseRegion(
        onEnter: (_) => setState(() => _hovered = index),
        child: GestureDetector(
          onTap: () {
            _playEffect(index);
            _onTap(item);
          },
          onSecondaryTap: () => _showMenu(item, items),
          child: AnimatedContainer(
            duration: Duration(milliseconds: s.animationMs ~/ 2),
            curve: Curves.easeOut,
            width: size + DockLayout.gap,
            height: size + DockLayout.gap,
            child: Stack(alignment: Alignment.center, children: [
              _withEffect(index, size, s, _icon(item, size, false)),
              if (running) _dot(s.position),
            ]),
          ),
        ),
      );
      final reorderable = !s.lockIcons && index < _base.length;
      if (!reorderable) return box;
      return DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index && index < _base.length,
        onAcceptWithDetails: (d) async {
          final list = List<DockItem>.from(_base);
          final moved = list.removeAt(d.data);
          list.insert(index.clamp(0, list.length).toInt(), moved);
          s.items = list;
          await widget.repository.save();
          if (mounted) setState(() {});
        },
        builder: (context, c, r) => Draggable<int>(
          data: index,
          onDragStarted: () => _controller.holdVisible = true,
          onDragEnd: (_) => _controller.holdVisible = false,
          feedback: _icon(item, size, true),
          childWhenDragging: Opacity(opacity: .25, child: box),
          child: box,
        ),
      );
    });
  }

  /// Click feedback chosen in settings (bounce / highlight / scale / none).
  Widget _withEffect(int index, double size, DockSettings s, Widget icon) {
    if (s.activationEffect == 'Нет') return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _fxIndex == index ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: icon,
      builder: (context, v, child) {
        switch (s.activationEffect) {
          case 'Масштабирование':
            return Transform.scale(scale: 1 + .25 * v, child: child);
          case 'Подсвечивание':
            return ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: .45 * v), BlendMode.srcATop),
              child: child,
            );
          default:
            final d = size * .35 * v;
            final off = switch (s.position) {
              DockPosition.top => Offset(0, d),
              DockPosition.bottom => Offset(0, -d),
              DockPosition.left => Offset(d, 0),
              DockPosition.right => Offset(-d, 0),
            };
            return Transform.translate(offset: off, child: child);
        }
      },
    );
  }

  void _playEffect(int index) {
    setState(() => _fxIndex = index);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted && _fxIndex == index) setState(() => _fxIndex = null);
    });
  }

  Widget _dot(DockPosition p) => Align(
        alignment: switch (p) {
          DockPosition.top => Alignment.topCenter,
          DockPosition.bottom => Alignment.bottomCenter,
          DockPosition.left => Alignment.centerLeft,
          DockPosition.right => Alignment.centerRight,
        },
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      );

  Widget _icon(DockItem item, double size, bool elevated) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<ui.Image?>(
        future: _icons.load(item.target,
            iconPath: item.iconPath, size: (_s.iconSize * _s.zoom * dpr).ceil()),
        builder: (context, snap) {
          final img = snap.data;
          if (img != null) {
            return RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.high);
          }
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .23),
              gradient: const LinearGradient(colors: [Color(0xFF79C8FF), Color(0xFF315F9F)]),
            ),
            child: Icon(IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'),
                size: size * .58, color: Colors.white),
          );
        },
      ),
    );
  }

  Future<void> _onTap(DockItem item) async {
    final wins = _windowsFor(item);
    try {
      if (wins.isNotEmpty && (_s.activateInsteadOfLaunch || item.id.startsWith('win-'))) {
        _tracker.toggle(wins.first.hwnd);
        _refreshRunning();
        return;
      }
      await _launcher.launch(item.target,
          isUrl: item.isUrl,
          arguments: item.arguments,
          workingDirectory: item.workingDirectory);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showMenu(DockItem? item, List<DockItem> items) async {
    if (!widget.standalone || !Platform.isWindows || _controller.hwnd == 0) return;
    final c = NativeWindow.cursor();
    if (c == null) return;
    final s = _s;
    final wins = item == null ? const <AppWindow>[] : _windowsFor(item);
    final entries = <NativeMenuEntry>[
      if (item != null && !item.isSeparator) ...[
        NativeMenuEntry(1, wins.isEmpty ? 'Запустить' : 'Открыть ещё одно окно'),
        if (wins.isNotEmpty) const NativeMenuEntry(2, 'Показать окно'),
        if (wins.isNotEmpty) const NativeMenuEntry(3, 'Закрыть окно'),
        if (!item.isUrl && !item.target.startsWith('::') && !item.target.startsWith('['))
          const NativeMenuEntry(4, 'Показать в папке'),
        NativeMenuEntry(5, 'Удалить из панели',
            enabled: !s.lockIcons && !item.id.startsWith('win-')),
        const NativeMenuEntry.separator(),
      ],
      NativeMenuEntry(11, 'Закрепить значки', checked: s.lockIcons),
      NativeMenuEntry(12, 'Автоматически прятать панель', checked: s.autoHide),
      const NativeMenuEntry(10, 'Настройки панели…'),
      const NativeMenuEntry.separator(),
      const NativeMenuEntry(14, 'Выход'),
    ];
    _controller.holdVisible = true;
    final id = NativeMenu.show(_controller.hwnd, entries, c.$1, c.$2);
    _controller.holdVisible = false;
    switch (id) {
      case 1:
        await _launcher.launch(item!.target,
            isUrl: item.isUrl, arguments: item.arguments, workingDirectory: item.workingDirectory);
      case 2:
        _tracker.activate(wins.first.hwnd);
      case 3:
        _tracker.close(wins.first.hwnd);
      case 4:
        await _launcher.showInFolder(item!.target);
      case 5:
        s.items = List<DockItem>.from(_base)..removeWhere((e) => e.id == item!.id);
        await widget.repository.save();
        if (mounted) setState(() {});
      case 11:
        s.lockIcons = !s.lockIcons;
        await widget.repository.save();
        if (mounted) setState(() {});
      case 12:
        s.autoHide = !s.autoHide;
        await widget.repository.save();
        _controller.apply();
        if (mounted) setState(() {});
      case 10:
        await Process.start(Platform.resolvedExecutable, [], mode: ProcessStartMode.detached);
      case 14:
        exit(0);
    }
  }
}

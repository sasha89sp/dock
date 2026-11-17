import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/data/settings_repository.dart';
import '../../../core/data/rocketdock_importer.dart';
import '../../../core/models/dock_item.dart';
import '../../../core/models/dock_settings.dart';
import '../../../core/platform/windows/native_window.dart';
import 'item_editor_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});
  final SettingsRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;
  DockSettings get s => widget.repository.settings;

  final _tabs = const [
    (Icons.build, 'Общие'), (Icons.inventory_2, 'Значки'),
    (Icons.open_with, 'Положение'), (Icons.brush, 'Стиль'),
    (Icons.animation, 'Реакция'), (Icons.info_outline, 'О программе'),
  ];

  Future<void> _save() async {
    await widget.repository.save();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Настройки сохранены: ${widget.repository.storagePath}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(
                color: const Color(0xFF244B75), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.rocket_launch, color: Colors.white)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RocketDock Next', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                Text('Настройка панели приложений', style: TextStyle(color: Colors.white54)),
              ])),
              OutlinedButton.icon(onPressed: () => _showDock(), icon: const Icon(Icons.desktop_windows), label: const Text('Показать панель')),
            ]),
            const SizedBox(height: 22),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 190, child: Card(child: ListView.builder(
                padding: const EdgeInsets.all(10), itemCount: _tabs.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: ListTile(
                    selected: _tab == i,
                    selectedTileColor: const Color(0xFF29496C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(_tabs[i].$1), title: Text(_tabs[i].$2),
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
              ))),
              const SizedBox(width: 16),
              Expanded(child: Card(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_tabs[_tab].$2, style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 28),
                  Expanded(child: SingleChildScrollView(child: _tabContent())),
                ]),
              ))),
            ])),
            const SizedBox(height: 16),
            Row(children: [
              OutlinedButton(onPressed: () async {
                await widget.repository.reset();
                if (mounted) setState(() {});
              }, child: const Text('По умолчанию')),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Сохранить')),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Закрыть')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 0: return _general();
      case 1: return _icons();
      case 2: return _position();
      case 3: return _style();
      case 4: return _behavior();
      default: return _about();
    }
  }

  Widget _general() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

    const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text('Портативный режим: конфигурация хранится рядом с программой в папке data. Программа не записывает настройки в реестр Windows.',
        style: TextStyle(color: Colors.lightBlueAccent)),
    ),
    OutlinedButton.icon(
      onPressed: _importRocketDock,
      icon: const Icon(Icons.move_to_inbox),
      label: const Text('Импортировать настройки RocketDock 1.3.5'),
    ),
    const SizedBox(height: 12),
    _switch('Помещать минимизированные окна в панель', s.minimizeToDock, (v) => setState(() => s.minimizeToDock = v)),
    _switch('Отмечать запущенные приложения', s.runningIndicator, (v) => setState(() => s.runningIndicator = v)),
    _switch('Активировать запущенное приложение вместо запуска нового', s.activateInsteadOfLaunch, (v) => setState(() => s.activateInsteadOfLaunch = v)),
    _switch('Закрепить значки', s.lockIcons, (v) => setState(() => s.lockIcons = v)),
    const SizedBox(height: 20),
    const Text('Элементы панели', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: s.items.length,
      onReorder: (oldIndex, newIndex) => setState(() {
        if (newIndex > oldIndex) newIndex -= 1;
        s.items.insert(newIndex, s.items.removeAt(oldIndex));
      }),
      itemBuilder: (context, i) {
        final item = s.items[i];
        return ListTile(
          key: ValueKey('${item.id}-$i'),
          leading: Icon(item.isSeparator ? Icons.horizontal_rule : Icons.apps),
          title: Text(item.isSeparator ? '— разделитель —' : item.title),
          subtitle: item.isSeparator
              ? null
              : Text(item.target, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!item.isSeparator)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final edited = await showItemEditor(context, item);
                  if (edited != null) setState(() => s.items[i] = edited);
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => s.items.removeAt(i)),
            ),
          ]),
        );
      },
    ),
    Wrap(spacing: 8, children: [
      OutlinedButton.icon(onPressed: _addFile, icon: const Icon(Icons.add), label: const Text('Добавить приложение')),
      OutlinedButton.icon(onPressed: _addUrl, icon: const Icon(Icons.link), label: const Text('Добавить ссылку')),
      OutlinedButton.icon(
        onPressed: () => setState(() => s.items.add(DockItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: '',
            target: '',
            isSeparator: true))),
        icon: const Icon(Icons.horizontal_rule),
        label: const Text('Добавить разделитель'),
      ),
    ]),
  ]);

  Widget _icons() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _slider('Первоначальный размер значка', s.iconSize, 16, 128, (v) => setState(() => s.iconSize = v), suffix: 'px'),
    _slider('Увеличение значков при наведении', s.zoom, 1, 3, (v) => setState(() => s.zoom = v), divisions: 20, suffix: '×'),
    _slider('Увеличение размера значков на', s.zoomStep.toDouble(), 1, 20, (v) => setState(() => s.zoomStep = v.round()), suffix: 'px'),
    _slider('Количество соседних значков', s.zoomNeighbors.toDouble(), 1, 10, (v) => setState(() => s.zoomNeighbors = v.round())),
    _slider('Скорость увеличения', s.animationMs.toDouble(), 100, 500, (v) => setState(() => s.animationMs = v.round()), suffix: 'мс'),
    _dropdown('Качество отображения', s.quality, ['Низкое', 'Среднее', 'Высокое'], (v) => setState(() => s.quality = v!)),
  ]);

  Widget _position() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _monitorPicker(),
    const SizedBox(height: 14),
    _dropdown('Положение на экране', s.position.name, DockPosition.values.map((e) => e.name).toList(),
      (v) => setState(() => s.position = DockPosition.values.firstWhere((e) => e.name == v))),
    _slider('Смещение по границе экрана', s.edgeOffset.toDouble(), -1000, 1000, (v) => setState(() => s.edgeOffset = v.round()), suffix: 'px'),
    const Text('Панель позиционируется по рабочей области выбранного монитора (учитывает панель задач). Изменения применяются запущенной панелью после сохранения.'),
  ]);

  Widget _monitorPicker() {
    final mons = NativeWindow.monitors();
    final labels = mons.isEmpty
        ? ['Основной']
        : [
            for (var i = 0; i < mons.length; i++)
              'Монитор ${i + 1} (${mons[i].bounds.width}×${mons[i].bounds.height})${mons[i].primary ? ', основной' : ''}'
          ];
    final index = s.monitorIndex.clamp(0, labels.length - 1).toInt();
    return _dropdown('Монитор', labels[index], labels,
        (v) => setState(() => s.monitorIndex = labels.indexOf(v ?? labels.first)));
  }

  Widget _style() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _dropdown('Тема', s.themeName, ['Crystal', 'Dark Glass', 'Light', 'Midnight'], (v) => setState(() => s.themeName = v!)),
    _slider('Степень непрозрачности', s.opacity * 100, 0, 100, (v) => setState(() => s.opacity = v / 100), suffix: '%'),
    _switch('Не показывать подписи к значкам', !s.labels, (v) => setState(() => s.labels = !v)),
    const SizedBox(height: 12),
    const Text('Предпросмотр'),
    const SizedBox(height: 12),
    Container(height: 100, decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24)),
      child: const Center(child: Icon(Icons.rocket_launch, size: 48, color: Color(0xFF85C9FF)))),
  ]);

  Widget _behavior() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _dropdown('Эффект при выборе значка', s.activationEffect, ['Подпрыгивание', 'Подсвечивание', 'Масштабирование', 'Нет'], (v) => setState(() => s.activationEffect = v ?? 'Подпрыгивание')),
    _switch('Автоматически прятать панель', s.autoHide, (v) => setState(() => s.autoHide = v)),
    _slider('Задержка перед скрытием', s.hideDelayMs.toDouble(), 0, 2000, (v) => setState(() => s.hideDelayMs = v.round()), suffix: 'мс'),
    _slider('Задержка перед появлением', s.showDelayMs.toDouble(), 0, 1000, (v) => setState(() => s.showDelayMs = v.round()), suffix: 'мс'),
    _switch('При активации панели выводить её поверх окон', s.alwaysOnTop, (v) => setState(() => s.alwaysOnTop = v)),
    const Text('Автоскрытие работает в запущенной панели (--dock); не проверено на реальной Windows.'),
  ]);

  Widget _about() => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('RocketDock Next', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    SizedBox(height: 8), Text('Версия 1.0.0'),
    SizedBox(height: 16),
    Text('Новая реализация панели быстрого запуска приложений для Windows на Flutter.'),
    SizedBox(height: 12),
    Text('Создано по мотивам RocketDock 1.3.5. Не является оригинальным продуктом PunkSoftware.'),
  ]);

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero, title: Text(title), value: value, onChanged: onChanged);

  Widget _slider(String title, double value, double min, double max, ValueChanged<double> onChanged,
      {String suffix = '', int? divisions}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title)), Text('${value.round()}$suffix', style: const TextStyle(color: Colors.lightBlueAccent))]),
      Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions ?? (max - min).round(),
        onChanged: onChanged),
    ]),
  );

  Widget _dropdown(String title, String value, List<String> options, ValueChanged<String?> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Expanded(child: Text(title)),
      SizedBox(width: 220, child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : options.first,
        items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged)),
    ]),
  );

  Future<void> _importRocketDock() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ini'],
      dialogTitle: 'Выберите Settings.ini из RocketDock',
    );
    final path = selection?.files.single.path;
    if (path == null) return;
    try {
      final result = await RocketDockImporter().importFromIni(
        iniFile: File(path),
        target: s,
        destinationData: widget.repository.dataDirectory,
      );
      await _save();
      if (!mounted) return;
      final details = [
        'Импортировано параметров: ${result.importedSettings}',
        'Импортировано ярлыков: ${result.importedItems}',
        'Скопированы ресурсы: ${result.copiedAssetFolders.isEmpty ? 'нет' : result.copiedAssetFolders.join(', ')}',
        ...result.warnings,
      ].join('\\n');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт RocketDock завершён'),
          content: SelectableText(details),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $error')),
      );
    }
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;
    final name = path.split(RegExp(r'[/\\]')).last;
    setState(() => s.items.add(DockItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name,
      target: path,
    )));
    await _save();
  }

  Future<void> _addUrl() async {
    final controller = TextEditingController(text: 'https://');
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Добавить ссылку'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'URL')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Добавить')),
      ],
    ));
    if (value == null || !value.startsWith('http')) return;
    setState(() => s.items.add(DockItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: Uri.tryParse(value)?.host ?? value, target: value, isUrl: true)));
    await _save();
  }

  /// Starts the dock as a separate process (`--dock`) beside this settings window.
  Future<void> _showDock() async {
    try {
      await _save();
      await Process.start(Platform.resolvedExecutable, ['--dock'],
          mode: ProcessStartMode.detached);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось запустить панель: $e')));
    }
  }
}

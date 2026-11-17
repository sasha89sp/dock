import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/models/dock_item.dart';

/// Edits one dock item. Returns the updated item, or null if cancelled.
Future<DockItem?> showItemEditor(BuildContext context, DockItem item) {
  final title = TextEditingController(text: item.title);
  final target = TextEditingController(text: item.target);
  final args = TextEditingController(text: item.arguments);
  final dir = TextEditingController(text: item.workingDirectory);
  final icon = TextEditingController(text: item.iconPath ?? '');

  Widget field(String label, TextEditingController c, {VoidCallback? onBrowse}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: c,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            ),
          ),
          if (onBrowse != null)
            IconButton(onPressed: onBrowse, icon: const Icon(Icons.folder_open)),
        ]),
      );

  Future<void> pick(TextEditingController c) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path != null) c.text = path;
  }

  return showDialog<DockItem>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Свойства значка'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('Название', title),
            field('Команда / файл / папка / ссылка', target, onBrowse: () => pick(target)),
            field('Аргументы', args),
            field('Рабочая папка', dir),
            field('Значок (png/ico/exe/dll, можно file?индекс)', icon, onBrowse: () => pick(icon)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final t = target.text.trim();
            Navigator.pop(
              context,
              DockItem(
                id: item.id,
                title: title.text.trim().isEmpty ? t : title.text.trim(),
                target: t,
                isUrl: t.startsWith('http://') || t.startsWith('https://'),
                iconCodePoint: item.iconCodePoint,
                iconPath: icon.text.trim().isEmpty ? null : icon.text.trim(),
                iconPath2: item.iconPath2,
                arguments: args.text.trim(),
                workingDirectory: dir.text.trim(),
              ),
            );
          },
          child: const Text('Применить'),
        ),
      ],
    ),
  );
}

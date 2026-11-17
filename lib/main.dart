import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/data/settings_repository.dart';
import 'core/models/dock_item.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SettingsRepository();
  await repository.load();
  if (!repository.existedOnLoad && repository.settings.items.isEmpty) {
    repository.settings.items = DockItem.defaults();
    await repository.save();
  }

  final dockMode = args.contains('--dock');
  if (!dockMode) {
    // Settings window: regular decorated window.
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1120, 760),
        minimumSize: Size(900, 620),
        center: true,
        title: 'RocketDock Next',
        backgroundColor: Color(0xFF101522),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  // Dock mode: window style, size, position, topmost and transparency are handled
  // natively by DockWindowController (core/platform/windows) after the first frame.
  runApp(RocketDockApp(repository: repository, dockMode: dockMode));
}

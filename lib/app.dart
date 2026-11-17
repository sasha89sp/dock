import 'package:flutter/material.dart';

import 'core/data/settings_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/dock/presentation/dock_window.dart';
import 'features/settings/presentation/settings_screen.dart';

class RocketDockApp extends StatelessWidget {
  const RocketDockApp({super.key, required this.repository, required this.dockMode});

  final SettingsRepository repository;
  final bool dockMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RocketDock Next',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: dockMode
          ? DockWindow(repository: repository, standalone: true)
          : SettingsScreen(repository: repository),
    );
  }
}

# lib/MAP

- `main.dart`: bootstrap; settings mode uses window_manager, `--dock` mode relies on native placement.
- `app.dart`: root MaterialApp and mode switch.
- `core/models/`: DockSettings (incl. monitorIndex, edgeOffset) and DockItem (separator, args, icon2) JSON models.
- `core/data/settings_repository.dart`: atomic JSON persistence beside executable under `data/`.
- `core/data/rocketdock_importer.dart`: RocketDock 1.3.5 Settings.ini importer (cp1251, flat `N-Key` entries) + asset copy.
- `core/platform/app_launcher.dart`: ShellExecuteW launch, URLs, show in folder.
- `core/platform/windows/`: dart:ffi Win32 layer (UNVERIFIED): `win32_bindings`, `native_window`, `dock_geometry`, `window_tracker`, `icon_service`, `native_menu`.
- `core/theme/`: Material theme.
- `features/dock/domain/dock_layout.dart`: pure layout/zoom math.
- `features/dock/application/dock_window_controller.dart`: placement, auto-hide, monitors.
- `features/dock/presentation/dock_window.dart`: dock UI, icons, running indicators, context menu, reorder.
- `features/settings/presentation/`: six settings sections and import UI.
- `features/settings/presentation/item_editor_dialog.dart`: dialog to edit one dock item.

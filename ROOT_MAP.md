# ROOT_MAP

- `lib/main.dart` — запуск приложения и конфигурация окон.
- `lib/app.dart` — корневой MaterialApp.
- `lib/core/models/` — модели настроек и ярлыков.
- `lib/core/data/settings_repository.dart` — JSON-настройки в `data/settings.json` рядом с EXE.
- `lib/core/data/rocketdock_importer.dart` — импорт portable RocketDock `Settings.ini` и ресурсов.
- `lib/core/platform/` — запуск приложений и URL; `windows/` — dart:ffi слой Win32 (окно, мониторы, иконки, окна приложений, меню).
- `lib/features/dock/` — окно панели и иконки.
- `lib/features/settings/` — шесть разделов настроек.
- `scripts/` — bootstrap, запуск, проверки и Release build.
- `portable.mode` — маркер портативной сборки.
- `AGENTS.md`, `HANDOFF.yaml`, `ROOT_MAP.md`, `lib/MAP.md` — документация и передача контекста.
- `test/fixtures/` — урезанный реальный Settings.ini RocketDock 1.3.5.
- `TODO.md` — чек-лист незавершённых задач.

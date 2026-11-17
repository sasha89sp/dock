$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
& "$PSScriptRoot\bootstrap_windows.ps1"
flutter run -d windows
if ($LASTEXITCODE -ne 0) { throw "Запуск приложения завершился с ошибкой." }

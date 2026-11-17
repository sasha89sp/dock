$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
& "$PSScriptRoot\bootstrap_windows.ps1"

dart format lib test
if ($LASTEXITCODE -ne 0) { throw "dart format завершился с ошибкой." }

flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze обнаружил ошибки." }

flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test завершился с ошибкой." }

# The dock builds IconData from stored code points, so icon tree-shaking must be off.
flutter build windows --release --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) { throw "Windows Release build завершился с ошибкой." }

$rel = "build\windows\x64\runner\Release"
New-Item -ItemType Directory -Force "$rel\data\Icons","$rel\data\Themes","$rel\data\Backups" | Out-Null
New-Item -ItemType File -Force "$rel\portable.mode" | Out-Null
Write-Host "Release: $rel\  (RocketDockNext.exe; панель: RocketDockNext.exe --dock)"

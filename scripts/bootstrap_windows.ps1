$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter SDK не найден. Установите Flutter stable и добавьте flutter\bin в PATH."
}

flutter doctor -v
if ($LASTEXITCODE -ne 0) { throw "flutter doctor завершился с ошибкой." }

if (-not (Test-Path "windows\runner\Runner.rc")) {
  flutter create --platforms=windows .
  if ($LASTEXITCODE -ne 0) { throw "Не удалось создать Windows runner." }
}

# Executable name: RocketDockNext.exe instead of the default rocketdock_next.exe.
$cmake = "windows\CMakeLists.txt"
if (Test-Path $cmake) {
  (Get-Content $cmake -Raw) -replace 'set\(BINARY_NAME "[^"]+"\)', 'set(BINARY_NAME "RocketDockNext")' | Set-Content $cmake -NoNewline
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get завершился с ошибкой." }

Write-Host "Готово. Запуск: .\scripts\run_windows.ps1"

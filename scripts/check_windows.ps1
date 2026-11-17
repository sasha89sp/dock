$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze завершился с ошибкой." }
flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test завершился с ошибкой." }

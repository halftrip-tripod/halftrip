$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $root ".env.local"

if (-not (Test-Path $envFile)) {
  throw ".env.local not found: $envFile"
}

$defines = @()

Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith("#")) {
    return
  }

  $parts = $line -split "=", 2
  if ($parts.Length -ne 2) {
    return
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()
  if (-not $key) {
    return
  }

  $defines += "--dart-define=$key=$value"
}

Set-Location $root

& "C:\flutter\bin\flutter.bat" run `
  -d chrome `
  --target lib/main_api.dart `
  --web-port 3000 `
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/ `
  @defines

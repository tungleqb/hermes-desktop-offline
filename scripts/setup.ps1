<#
  setup.ps1 - First-run wizard for Hermes Desktop Offline (portable).
#>
param(
  [string]$DataRoot = "",
  [string]$WorkRoot = "",
  [string]$CacheRoot = "",
  [string]$LocalBaseUrl = "http://127.0.0.1:11434/v1",
  [string]$LocalModel = "",
  [string]$Placement = "copy",
  [switch]$NonInteractive,
  [switch]$ResetPaths
)
$ErrorActionPreference = 'Stop'
$root = if ($env:HERMES_PORTABLE_ROOT) { $env:HERMES_PORTABLE_ROOT } else { Split-Path -Parent $PSScriptRoot }
if ($root -eq '') { $root = (Get-Location).Path }

Write-Host "Hermes Desktop Offline - setup"
Write-Host "Install root: $root"

# 1. integrity
if (Test-Path -LiteralPath "$root\checksums.sha256") {
  Write-Host "Verifying payload checksums..."
  $bad = 0
  foreach ($line in Get-Content -LiteralPath "$root\checksums.sha256") {
    if (-not $line) { continue }
    $h, $rel = $line -split '  ', 2
    $f = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $f)) { Write-Host "  MISSING: $rel"; $bad++; continue }
    if ((Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower() -ne $h) { Write-Host "  MISMATCH: $rel"; $bad++ }
  }
  if ($bad -gt 0) { Write-Host "WARNING: $bad file(s) failed integrity check." } else { Write-Host "  OK" }
}

# 2. paths
if (-not $DataRoot) { $DataRoot = "$root\data" }
if (-not $WorkRoot) { $WorkRoot = "$root\work" }
if (-not $CacheRoot) { $CacheRoot = "$root\cache" }

foreach ($p in @($DataRoot, $WorkRoot, $CacheRoot)) {
  if (Test-Path -LiteralPath $p) {
    $item = Get-Item -LiteralPath $p
    if ($item.LinkType) { throw "Refusing symlink/junction data path: $p" }
  }
  New-Item -ItemType Directory -Force -Path $p | Out-Null
  $probe = Join-Path $p ".hermes-write-probe"
  Set-Content -LiteralPath $probe -Value "ok"
  Remove-Item -LiteralPath $probe -Force
}

# 3. seed config (never overwrite)
$cfg = Join-Path $DataRoot "config.yaml"
if (-not (Test-Path -LiteralPath $cfg)) {
  Copy-Item -LiteralPath "$root\config\config.yaml.template" -Destination $cfg
  Write-Host "Seeded config: $cfg"
} else {
  Write-Host "Existing config kept: $cfg"
}

# 4. provider preset
if ($LocalBaseUrl) {
  $text = Get-Content -LiteralPath $cfg -Raw
  if ($text -notmatch '(?m)^model:') {
    $text = "model:`n  provider: openai-compatible`n  base_url: $LocalBaseUrl`n  model: $LocalModel`n" + $text
  }
  Set-Content -LiteralPath $cfg -Value $text -Encoding UTF8
}

# 5. payload placement
$embedded = "$root\app\resources\agent-payload"
$runtimeLink = "$root\runtime"
if (Test-Path -LiteralPath $embedded) {
  if ($Placement -eq 'junction') {
    if (Test-Path -LiteralPath $runtimeLink) { Remove-Item -LiteralPath $runtimeLink -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Junction -Path $runtimeLink -Target $embedded | Out-Null
    Write-Host "runtime junction -> $embedded"
  } else {
    Write-Host "payload embedded in app\resources\agent-payload (no junction)"
  }
} else {
  Write-Host "WARNING: embedded agent-payload not found under app\resources"
}

# 6. write ini
$iniLines = @(
  "[paths]",
  "install_root = $root",
  "data_root = $DataRoot",
  "work_root = $WorkRoot",
  "cache_root = $CacheRoot",
  "payload_placement = $Placement",
  "",
  "[offline]",
  "mode = lan",
  "local_base_url = $LocalBaseUrl",
  "local_model = $LocalModel",
  "gateway_port = 8787",
  "allow_lan = true"
)
Set-Content -LiteralPath (Join-Path $root "config\hermes-portable.ini") -Value ($iniLines -join "`r`n") -Encoding UTF8
Write-Host ("Wrote " + (Join-Path $root "config\hermes-portable.ini"))

# 7. verify
if (Test-Path -LiteralPath "$root\verify-offline.ps1") {
  & "$root\verify-offline.ps1" -Root $root
}
Write-Host "Setup complete. Launch: $root\launcher\HermesPortable.cmd"

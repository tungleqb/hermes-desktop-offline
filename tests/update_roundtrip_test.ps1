<#
  update_roundtrip_test.ps1 - end-to-end simulation of the offline update path described in
  docs/02_architecture.md section 4, driving the real scripts\update-offline.ps1 against a
  throwaway portable root.

  Usage:
    .\tests\update_roundtrip_test.ps1
    .\tests\update_roundtrip_test.ps1 -UpdateScript D:\dev\hermes-desktop-offline\scripts\update-offline.ps1

  Scenarios exercised:
    1. preflight rejects a manifest with the wrong schemaVersion or target
    2. preflight rejects a ZIP whose name does not match manifest.version
    3. downgrade is refused without -Force
    4. integrity failure (one corrupted byte inside the ZIP) aborts before anything is written
    5. happy path: backup created, components applied in order, config template refreshed,
       user config.yaml untouched, payload re-sealed, manifest replaced, history appended
    6. -Force permits a downgrade
    7. -Component app applies only the app component

  Prints PASS/FAIL lines and exits nonzero on failure. Local files only - no network.
#>
param(
  [string]$UpdateScript = 'D:\dev\hermes-desktop-offline\scripts\update-offline.ps1'
)

$ErrorActionPreference = 'Stop'
$failures = 0
$passes = 0

function Report([bool]$ok, [string]$name, [string]$detail = '') {
  if ($ok) { $script:passes++; Write-Host "PASS  $name  $detail" }
  else { $script:failures++; Write-Host "FAIL  $name  $detail" }
}

function Run-Update([string]$root, [string]$zip, [string[]]$extraArgs) {
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $UpdateScript, '-Zip', $zip)
  if ($extraArgs) { $args += $extraArgs }
  $env:HERMES_PORTABLE_ROOT = $root
  # Continue so that the child script's stderr (its throw messages) is captured as
  # plain text in $out instead of aborting this test harness.
  $saved = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe @args 2>&1 | Out-String
    return [pscustomobject]@{ code = $LASTEXITCODE; out = $out }
  } finally {
    $ErrorActionPreference = $saved
    Remove-Item -LiteralPath 'Env:HERMES_PORTABLE_ROOT' -ErrorAction SilentlyContinue
  }
}

# Builds a staged bundle (manifest.json + checksums.sha256 + components) and zips it.
# $corrupt, when set, is a relative path whose first byte is flipped AFTER the checksum
# list has been written, so the ZIP fails integrity verification.
function New-Bundle([string]$dir, [string]$version, [string[]]$components, [string]$corrupt = '',
                    [int]$schemaVersion = 1, [string]$target = 'win32-x64') {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  foreach ($c in $components) {
    New-Item -ItemType Directory -Force -Path (Join-Path $dir $c) | Out-Null
    Set-Content -LiteralPath (Join-Path $dir "$c\payload-$version.txt") -Value "component $c version $version" -Encoding UTF8
  }
  if ($components -contains 'config') {
    Set-Content -LiteralPath (Join-Path $dir 'config\config.yaml.template') -Value "version: $version" -Encoding UTF8
  }

  $manifest = [ordered]@{
    schemaVersion = $schemaVersion
    version       = $version
    channel       = 'offline-portable'
    target        = $target
    builtAt       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    components    = @($components | ForEach-Object { [pscustomobject]@{ name = $_; path = $_; required = $true } })
  }
  Set-Content -LiteralPath (Join-Path $dir 'manifest.json') -Value (ConvertTo-Json $manifest -Depth 5) -Encoding UTF8

  $lines = foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File)) {
    if ($f.Name -eq 'checksums.sha256') { continue }
    $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
    $rel = $f.FullName.Substring($dir.Length + 1)
    "$h  $rel"
  }
  Set-Content -LiteralPath (Join-Path $dir 'checksums.sha256') -Value $lines -Encoding UTF8

  # Corrupt AFTER the checksum list is written, so the sealed bundle fails integrity.
  if ($corrupt) {
    $f = Join-Path $dir $corrupt
    $b = [System.IO.File]::ReadAllBytes($f)
    $b[0] = ($b[0] -bxor 0xFF)
    [System.IO.File]::WriteAllBytes($f, $b)
  }

  $zip = Join-Path $dir "..\Hermes-Offline-$version-win-x64.zip"
  if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  Compress-Archive -Path "$dir\*" -DestinationPath $zip -Force
  return $zip
}

# Builds an installed portable root at the given version.
function New-InstalledRoot([string]$root, [string]$version) {
  foreach ($c in @('app', 'runtime', 'config', 'launcher')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $c) | Out-Null
    Set-Content -LiteralPath (Join-Path $root "$c\payload-$version.txt") -Value "installed $c version $version" -Encoding UTF8
  }
  Set-Content -LiteralPath (Join-Path $root 'config\config.yaml.template') -Value "version: $version" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $root 'config\config.yaml') -Value "user_edited: true" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $root 'config\hermes-portable.ini') -Value @"
[paths]
data_root = $root\data
work_root = $root\work
payload_placement = junction
[offline]
mode = strict
"@ -Encoding UTF8
  New-Item -ItemType Directory -Force -Path (Join-Path $root 'data'), (Join-Path $root 'work') | Out-Null

  $manifest = [ordered]@{
    schemaVersion = 1
    version       = $version
    channel       = 'offline-portable'
    target        = 'win32-x64'
    components    = @('app', 'runtime', 'config', 'launcher') | ForEach-Object { [pscustomobject]@{ name = $_; path = $_; required = $true } }
  }
  Set-Content -LiteralPath (Join-Path $root 'manifest.json') -Value (ConvertTo-Json $manifest -Depth 5) -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $UpdateScript)) {
  Write-Host "FAIL  update_script_present  $UpdateScript not found"
  exit 1
}

$work = Join-Path $env:TEMP ("hermes-update-roundtrip-" + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
  # ---------------- 1. happy path: 0.0.1 -> 0.0.2 ----------------
  $root = Join-Path $work 'root-a'
  New-InstalledRoot $root '0.0.1'
  $zip = New-Bundle (Join-Path $work 'bundle-a') '0.0.2' @('app', 'runtime', 'config', 'launcher')

  $r = Run-Update $root $zip @()
  Report ($r.code -eq 0) 'update_applies_clean_bundle' "exit=$($r.code)"

  $manifest = ConvertFrom-Json (Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw)
  Report ($manifest.version -eq '0.0.2' -and $manifest.schemaVersion -eq 1 -and $manifest.target -eq 'win32-x64') `
    'manifest_updated_to_new_version' "version=$($manifest.version)"

  Report (Test-Path -LiteralPath (Join-Path $root 'app\payload-0.0.2.txt')) 'app_component_applied' ''
  Report (Test-Path -LiteralPath (Join-Path $root 'runtime\payload-0.0.2.txt')) 'runtime_component_applied' ''
  Report (Test-Path -LiteralPath (Join-Path $root 'launcher\payload-0.0.2.txt')) 'launcher_component_applied' ''
  Report ((Get-Content -LiteralPath (Join-Path $root 'config\config.yaml.template') -Raw).Trim() -eq 'version: 0.0.2') 'config_template_refreshed' ''
  Report ((Get-Content -LiteralPath (Join-Path $root 'config\config.yaml') -Raw).Trim() -eq 'user_edited: true') 'user_config_preserved' ''

  $backups = Get-ChildItem -LiteralPath (Join-Path $root 'backups') -Directory -ErrorAction SilentlyContinue
  Report ($backups.Count -eq 1) 'backup_created' $(if ($backups) { $backups[0].Name } else { 'none' })
  Report (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'app\payload-0.0.1.txt')) 'backup_contains_previous_app' ''

  $history = @(Get-Content -LiteralPath (Join-Path $root 'updates\history.log') -ErrorAction SilentlyContinue)
  Report ($history.Count -eq 1 -and $history[0] -match 'update to 0\.0\.2') 'history_log_appended' ($history -join ' | ')

  # payload re-seal: ini declares junction, so app\resources\agent-payload must point at runtime
  $seal = Join-Path $root 'app\resources\agent-payload'
  $sealOk = Test-Path -LiteralPath $seal
  $sealTarget = ''
  if ($sealOk) {
    $item = Get-Item -LiteralPath $seal
    $sealTarget = $item.Target
    if (-not $sealTarget) { $sealTarget = (Get-Item -LiteralPath $seal -Force).FullName }
  }
  Report ($sealOk -and (Get-ChildItem -LiteralPath $seal -File | Measure-Object).Count -gt 0) 'payload_resealed' "target=$sealTarget"

  # ---------------- 2. second update: 0.0.2 -> 0.0.3, two history lines ----------------
  $zip2 = New-Bundle (Join-Path $work 'bundle-b') '0.0.3' @('app', 'runtime', 'config', 'launcher')
  $r = Run-Update $root $zip2 @()
  Report ($r.code -eq 0) 'second_update_applies' "exit=$($r.code)"
  $history = Get-Content -LiteralPath (Join-Path $root 'updates\history.log')
  Report ($history.Count -eq 2 -and $history[1] -match 'update to 0\.0\.3') 'history_log_accumulates' ($history -join ' | ')
  $backups = Get-ChildItem -LiteralPath (Join-Path $root 'backups') -Directory
  Report ($backups.Count -eq 2) 'backup_per_update' "$($backups.Count) backups"

  # ---------------- 3. downgrade refused ----------------
  $zipDown = New-Bundle (Join-Path $work 'bundle-down') '0.0.2' @('app', 'runtime', 'config', 'launcher')
  $r = Run-Update $root $zipDown @()
  Report ($r.code -ne 0 -and $r.out -match 'refusing downgrade') 'downgrade_refused_without_force' "exit=$($r.code)"
  Report ((Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json).version -eq '0.0.3') 'downgrade_left_install_untouched' ''

  # ---------------- 4. -Force permits the downgrade ----------------
  $r = Run-Update $root $zipDown @('-Force')
  Report ($r.code -eq 0) 'force_permits_downgrade' "exit=$($r.code)"
  Report ((Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json).version -eq '0.0.2') 'force_downgrade_applied' ''

  # ---------------- 5. integrity abort on corrupted bundle ----------------
  $rootC = Join-Path $work 'root-c'
  New-InstalledRoot $rootC '0.0.1'
  $zipBad = New-Bundle (Join-Path $work 'bundle-bad') '0.0.2' @('app', 'runtime', 'config', 'launcher') 'app\payload-0.0.2.txt'
  $before = (Get-Content -LiteralPath (Join-Path $rootC 'app\payload-0.0.1.txt') -Raw)
  $r = Run-Update $rootC $zipBad @()
  Report ($r.code -ne 0 -and $r.out -match 'Integrity check failed') 'integrity_abort_on_corrupted_zip' "exit=$($r.code)"
  Report ((Get-Content -LiteralPath (Join-Path $rootC 'app\payload-0.0.1.txt') -Raw) -eq $before) 'integrity_abort_wrote_nothing' ''
  Report (-not (Test-Path -LiteralPath (Join-Path $rootC 'backups'))) 'integrity_abort_created_no_backup' ''
  Report (-not (Test-Path -LiteralPath (Join-Path $rootC 'updates\history.log'))) 'integrity_abort_wrote_no_history' ''

  # ---------------- 6. schema / target preflight ----------------
  $rootD = Join-Path $work 'root-d'
  New-InstalledRoot $rootD '0.0.1'
  $zipSchema = New-Bundle (Join-Path $work 'bundle-schema') '0.0.2' @('app', 'runtime', 'config', 'launcher') '' 2
  $r = Run-Update $rootD $zipSchema @()
  Report ($r.code -ne 0 -and $r.out -match 'unsupported manifest schema') 'preflight_rejects_bad_schema' "exit=$($r.code)"

  $zipTarget = New-Bundle (Join-Path $work 'bundle-target') '0.0.2' @('app', 'runtime', 'config', 'launcher') '' 1 'linux-x64'
  $r = Run-Update $rootD $zipTarget @()
  Report ($r.code -ne 0 -and $r.out -match 'target mismatch') 'preflight_rejects_wrong_target' "exit=$($r.code)"

  # ---------------- 7. ZIP name / manifest version mismatch ----------------
  $zipMismatch = New-Bundle (Join-Path $work 'bundle-mismatch') '0.0.2' @('app', 'runtime', 'config', 'launcher')
  Rename-Item -LiteralPath $zipMismatch -NewName 'Hermes-Offline-9.9.9-win-x64.zip'
  $zipMismatch = Join-Path $work 'Hermes-Offline-9.9.9-win-x64.zip'
  $r = Run-Update $rootD $zipMismatch @()
  Report ($r.code -ne 0 -and $r.out -match 'filename version') 'preflight_rejects_name_version_mismatch' "exit=$($r.code)"

  # ---------------- 8. missing ZIP ----------------
  $r = Run-Update $rootD (Join-Path $work 'does-not-exist.zip') @()
  Report ($r.code -ne 0) 'missing_zip_fails' "exit=$($r.code)"

  # ---------------- 9. -Component app applies only app ----------------
  $rootE = Join-Path $work 'root-e'
  New-InstalledRoot $rootE '0.0.1'
  $zipComp = New-Bundle (Join-Path $work 'bundle-comp') '0.0.2' @('app', 'runtime', 'config', 'launcher')
  $r = Run-Update $rootE $zipComp @('-Component', 'app')
  Report ($r.code -eq 0) 'component_scoped_update_applies' "exit=$($r.code)"
  Report (Test-Path -LiteralPath (Join-Path $rootE 'app\payload-0.0.2.txt')) 'component_app_updated' ''
  Report (Test-Path -LiteralPath (Join-Path $rootE 'runtime\payload-0.0.1.txt')) 'component_runtime_left_at_previous_version' ''
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("Summary: {0} PASS / {1} FAIL" -f $passes, $failures)
if ($failures -gt 0) { exit 1 }
exit 0

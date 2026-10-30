<#
  update-offline.ps1 — apply a new offline bundle ZIP on an air-gapped machine.
  Usage: .\update-offline.ps1 -Zip D:\updates\Hermes-Offline-0.23.0-win-x64.zip [-Force] [-Component app|runtime|skills-bundle|launcher]
#>
param(
  [Parameter(Mandatory = $true)][string]$Zip,
  [switch]$Force,
  [string]$Component = ""
)
$ErrorActionPreference = 'Stop'
$root = if ($env:HERMES_PORTABLE_ROOT) { $env:HERMES_PORTABLE_ROOT } else { Split-Path -Parent $PSScriptRoot }

# 1. preflight
if (-not (Test-Path $Zip)) { throw "ZIP not found: $Zip" }
$curManifest = if (Test-Path "$root\manifest.json") { Get-Content "$root\manifest.json" -Raw | ConvertFrom-Json } else { $null }
$staged = "$root\updates\staged"
if (Test-Path $staged) { Remove-Item $staged -Recurse -Force }
Expand-Archive -Path $Zip -DestinationPath $staged
$newManifest = Get-Content "$staged\manifest.json" -Raw | ConvertFrom-Json
if ($newManifest.schemaVersion -ne 1) { throw "unsupported manifest schema" }
if ($newManifest.target -ne 'win32-x64') { throw "target mismatch: $($newManifest.target)" }
$zipNameVer = ($Zip -replace '.*Hermes-Offline-([0-9.]+)-win-x64\.zip', '$1')
if ($zipNameVer -ne $newManifest.version) { throw "filename version ($zipNameVer) != manifest version ($($newManifest.version))" }
if ($curManifest -and $newManifest.version -le $curManifest.version -and -not $Force) {
  throw "refusing downgrade/equal version $($curManifest.version) -> $($newManifest.version) (use -Force)"
}

# 2. integrity
$bad = 0
foreach ($line in Get-Content "$staged\checksums.sha256") {
  if (-not $line) { continue }
  $h, $rel = $line -split '  ', 2
  $f = Join-Path $staged $rel
  if (-not (Test-Path $f)) { Write-Host "MISSING $rel"; $bad++; continue }
  if ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -ne $h) { Write-Host "MISMATCH $rel"; $bad++ }
}
if ($bad -gt 0) { throw "integrity check failed: $bad files" }
Write-Host "Integrity OK ($bad mismatches)"

# 3. quiesce
Get-Process -Name Hermes, HermesPortable -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "Stopping $($_.Name) (pid $($_.Id))"; $_ | Stop-Process -Force }
Start-Sleep -Seconds 2

# 4. backup
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backup = "$root\backups\$($curManifest.version)-$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($c in @('app', 'runtime', 'skills-bundle', 'launcher', 'manifest.json')) {
  if (Test-Path "$root\$c") { Copy-Item "$root\$c" "$backup\$c" -Recurse }
}
Write-Host "Backup -> $backup"

# 5. apply
$components = if ($Component) { @($Component) } else { @('runtime', 'app', 'skills-bundle', 'launcher') }
foreach ($c in $components) {
  if (-not (Test-Path "$staged\$c")) { Write-Host "skip $c (not in bundle)"; continue }
  if (Test-Path "$root\$c") { Remove-Item "$root\$c" -Recurse -Force }
  Copy-Item "$staged\$c" "$root\$c" -Recurse
  Write-Host "applied $c"
}
# config merge: refresh templates only
if (Test-Path "$staged\config") {
  Copy-Item "$staged\config\config.yaml.template" "$root\config\config.yaml.template" -Force
  Write-Host "config templates refreshed (user config untouched)"
}

# 6. re-seal payload
$ini = Get-Content "$root\config\hermes-portable.ini" -Raw -ErrorAction SilentlyContinue
if ($ini -match 'payload_placement\s*=\s*junction') {
  $dst = "$root\app\resources\agent-payload"
  if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Junction -Path $dst -Target "$root\runtime" | Out-Null
} else {
  if (-not (Test-Path "$root\app\resources\agent-payload")) { Copy-Item "$root\runtime" "$root\app\resources\agent-payload" -Recurse }
}

# 7. verify
if (Test-Path "$root\launcher\verify-offline.ps1") { & "$root\launcher\verify-offline.ps1" -Root $root }
Copy-Item "$staged\manifest.json" "$root\manifest.json" -Force
Add-Content -Path "$root\updates\history.log" -Value "$stamp update to $($newManifest.version) from $Zip"
Write-Host "Update complete: $($newManifest.version)"

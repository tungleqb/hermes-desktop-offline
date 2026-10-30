<#
  build-offline.ps1 — Build host script (internet-connected).
  Produces: artifacts\Hermes-Offline-<version>-win-x64.zip (+ sidecar manifest)
  Usage:  .\scripts\build-offline.ps1 -Commit bf0203a794a07aac3ff764972ab9087baa4e4f4e [-Variant bundled] [-Out artifacts]
#>
param(
  [string]$Commit = "bf0203a794a07aac3ff764972ab9087baa4e4f4e",
  [string]$Tag = "",
  [string]$Variant = "bundled",
  [string]$Out = "D:\dev\hermes-desktop-offline\artifacts",
  [string]$Repo = "D:\dev\hermes-agent"
)
$ErrorActionPreference = 'Stop'
$proj = 'D:\dev\hermes-desktop-offline'
$log  = "$proj\logs\build-$(Get-Date -Format yyyyMMdd-HHmmss).log"
New-Item -ItemType Directory -Force -Path "$proj\logs", $Out | Out-Null

Write-Host "== [1/5] prepare + build portable app =="
$buildArgs = @('scripts\bundles\desktop.py', '--commit', $Commit, '--variant', $Variant, '--clean', '--', '--dir', '--publish=never')
if ($Tag) { $buildArgs = @('scripts\bundles\desktop.py', '--tag', $Tag, '--variant', $Variant, '--clean', '--', '--dir', '--publish=never') }
Push-Location $Repo
python @buildArgs 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "desktop build failed (exit $LASTEXITCODE); see $log" }
Pop-Location

$unpacked = "$Repo\apps\desktop\release\win-unpacked"
$payload  = "$Repo\apps\desktop\build\agent-payload"
if (-not (Test-Path "$unpacked\Hermes.exe")) { throw "win-unpacked missing Hermes.exe" }
if (-not (Test-Path "$payload")) { throw "agent-payload missing" }

# version from install-stamp
$stamp = Get-Content "$unpacked\resources\install-stamp.json" -Raw | ConvertFrom-Json
$version = $stamp.version
if (-not $version) { $version = '0.0.0-local' }

Write-Host "== [2/5] stage tree =="
$stage = "$Out\stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$stage\app", "$stage\runtime", "$stage\skills-bundle", "$stage\config", "$stage\launcher", "$stage\docs" | Out-Null

Copy-Item $unpacked "$stage\app" -Recurse
Copy-Item $payload  "$stage\runtime" -Recurse

# skills: upstream skills + offline-classified third-party
Copy-Item "$Repo\skills" "$stage\skills-bundle\skills" -Recurse
if (Test-Path "$Repo\optional-skills") { Copy-Item "$Repo\optional-skills" "$stage\skills-bundle\optional-skills" -Recurse }
if (Test-Path "$Repo\plugins") { Copy-Item "$Repo\plugins" "$stage\skills-bundle\plugins" -Recurse }
if (Test-Path "$proj\third-party-skills\skills") {
  Copy-Item "$proj\third-party-skills\skills" "$stage\skills-bundle\third-party" -Recurse
}
Copy-Item "$proj\artifacts\skill_inventory.json" "$stage\skills-bundle\skill_inventory.json"

Copy-Item "$proj\config\config.yaml.template" "$stage\config\config.yaml.template"
Copy-Item "$proj\config\providers.local.yaml" "$stage\config\providers.local.yaml"
Copy-Item "$proj\config\hermes-portable.ini"   "$stage\config\hermes-portable.ini"
Copy-Item "$proj\installer\setup.ps1"          "$stage\launcher\setup.ps1"
Copy-Item "$proj\installer\HermesPortable.cmd" "$stage\launcher\HermesPortable.cmd"
Copy-Item "$proj\scripts\verify-offline.ps1"   "$stage\launcher\verify-offline.ps1"
Copy-Item "$proj\scripts\update-offline.ps1"   "$stage\launcher\update-offline.ps1"
Copy-Item "$proj\docs\OFFLINE-QUICKSTART.md"   "$stage\docs\OFFLINE-QUICKSTART.md" -ErrorAction SilentlyContinue

Write-Host "== [3/5] checksums =="
$files = Get-ChildItem $stage -Recurse -File
$lines = foreach ($f in $files) {
  $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
  $rel = $f.FullName.Substring($stage.Length + 1)
  "$h  $rel"
}
Set-Content -Path "$stage\checksums.sha256" -Value $lines -Encoding UTF8

Write-Host "== [4/5] manifest =="
$manifest = [ordered]@{
  schemaVersion = 1
  version = $version
  channel = 'offline-portable'
  commit = $Commit
  builtAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  target = 'win32-x64'
  components = @{
    app           = @{ path = 'app';           required = $true }
    runtime       = @{ path = 'runtime';      required = $true }
    'skills-bundle' = @{ path = 'skills-bundle'; required = $false }
    config        = @{ path = 'config';       required = $true }
    launcher      = @{ path = 'launcher';     required = $true }
  }
  fileCount = $files.Count
  sizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
Set-Content -Path "$stage\manifest.json" -Value $manifestJson -Encoding UTF8

Write-Host "== [5/5] zip =="
$zipName = "Hermes-Offline-$version-win-x64.zip"
$zipPath = Join-Path $Out $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $stage -Destination $zipPath -ErrorAction SilentlyContinue
if (-not (Test-Path $zipPath)) {
  # fallback: 7z if available, else Compress-Archive (PS5 supports zip)
  Compress-Archive -Path "$stage\*" -DestinationPath $zipPath -CompressionLevel Optimal
}
Copy-Item "$stage\manifest.json" "$Out\$zipName.manifest.json"
Write-Host "DONE: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB,1)) MB)"

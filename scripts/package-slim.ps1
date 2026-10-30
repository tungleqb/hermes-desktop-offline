param([string]$Slim = "hip")
# package-offline with optional tool pruning for air-gap bundles
$ErrorActionPreference = 'Stop'
$Repo = 'D:\dev\hermes-agent'
$proj = 'D:\dev\hermes-desktop-offline'
$Out = "$proj\artifacts"
$unpacked = "$Repo\apps\desktop\release\win-unpacked"
$stamp = Get-Content "$unpacked\resources\install-stamp.json" -Raw | ConvertFrom-Json
$version = '0.22.5-offline'

$stage = "$Out\stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$stage\app", "$stage\runtime", "$stage\skills-bundle", "$stage\config", "$stage\launcher", "$stage\docs" | Out-Null

Copy-Item "$unpacked\*" "$stage\app" -Recurse
if ($Slim) {
  foreach ($pat in ($Slim -split '[,\s]+')) {
    Get-ChildItem "$stage\app\resources\agent-payload\tools" -Directory | Where-Object { $_.Name -match $pat } | ForEach-Object {
      Write-Host "pruning tool: $($_.Name)"
      Remove-Item $_.FullName -Recurse -Force
    }
  }
}
New-Item -ItemType Directory -Force -Path "$stage\runtime" | Out-Null
Set-Content -Path "$stage\runtime\README.txt" -Value "Agent runtime lives inside app\resources\agent-payload." -Encoding UTF8

Copy-Item "$Repo\skills" "$stage\skills-bundle\skills" -Recurse
if (Test-Path "$Repo\optional-skills") { Copy-Item "$Repo\optional-skills" "$stage\skills-bundle\optional-skills" -Recurse }
if (Test-Path "$Repo\plugins") { Copy-Item "$Repo\plugins" "$stage\skills-bundle\plugins" -Recurse }
if (Test-Path "$proj\third-party-skills\skills") { Copy-Item "$proj\third-party-skills\skills" "$stage\skills-bundle\third-party" -Recurse }
Copy-Item "$proj\artifacts\skill_inventory.json" "$stage\skills-bundle\skill_inventory.json"

Copy-Item "$proj\config\config.yaml.template" "$stage\config\config.yaml.template"
Copy-Item "$proj\config\providers.local.yaml" "$stage\config\providers.local.yaml"
Copy-Item "$proj\installer\setup.ps1"          "$stage\launcher\setup.ps1"
Copy-Item "$proj\installer\HermesPortable.cmd" "$stage\launcher\HermesPortable.cmd"
Copy-Item "$proj\scripts\verify-offline.ps1"   "$stage\launcher\verify-offline.ps1"
Copy-Item "$proj\scripts\update-offline.ps1"   "$stage\launcher\update-offline.ps1"
New-Item -ItemType Directory -Force -Path "$stage\launcher-src" | Out-Null
Copy-Item "$proj\launcher-src\HermesPortable.cs" "$stage\launcher-src\HermesPortable.cs"
$launcherExe = Get-ChildItem "$proj\launcher-build" -Recurse -File -Filter HermesPortable.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($launcherExe) { Copy-Item $launcherExe.FullName "$stage\launcher\HermesPortable.exe"; Write-Host "launcher exe included" }
else { Write-Host "WARNING: launcher exe not built; only .cmd fallback available" }
foreach ($d in Get-ChildItem "$proj\docs" -File) { Copy-Item $d.FullName "$stage\docs\$($d.Name)" }

$files = Get-ChildItem $stage -Recurse -File
$lines = New-Object System.Collections.Generic.List[string]
$skipped = 0
foreach ($f in $files) {
  try {
    $h = (Get-FileHash $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
    if (-not $h) { $skipped++; continue }
    $lines.Add($h.ToLower() + "  " + $f.FullName.Substring($stage.Length + 1))
  } catch { $skipped++ }
}
if ($skipped -gt 0) { Write-Host "WARNING: $skipped files could not be hashed" }
Set-Content -Path "$stage\checksums.sha256" -Value $lines -Encoding UTF8

$manifest = [ordered]@{
  schemaVersion = 1
  version = $version
  channel = 'offline-portable'
  commit = $stamp.commit
  builtAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  target = 'win32-x64'
  prunedTools = ($Slim -split '[,\s]+')
  components = @{
    app = @{ path = 'app'; required = $true }
    runtime = @{ path = 'runtime'; required = $true }
    'skills-bundle' = @{ path = 'skills-bundle'; required = $false }
    config = @{ path = 'config'; required = $true }
    launcher = @{ path = 'launcher'; required = $true }
  }
  fileCount = $files.Count
  sizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
}
Set-Content -Path "$stage\manifest.json" -Value ($manifest | ConvertTo-Json -Depth 5) -Encoding UTF8

$zipName = "Hermes-Offline-$version-win-x64.zip"
$zipPath = Join-Path $Out $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host "zipping $([math]::Round(($files | Measure-Object -Property Length -Sum).Sum/1GB,2)) GB ..."
$sevenZ = 'D:\dev\hermes-agent\.cache\desktop-inputs\packager\builder\7zip@1.0.0\7zip-win-x64-a34pt\bin\7za.exe'
if (Test-Path $sevenZ) {
  & $sevenZ a -tzip $zipPath "$stage\app" "$stage\runtime" "$stage\skills-bundle" "$stage\config" "$stage\launcher" "$stage\docs" "$stage\manifest.json" "$stage\checksums.sha256" -mx=1 | Select-Object -Last 5
} else {
  Compress-Archive -Path "$stage\app", "$stage\runtime", "$stage\skills-bundle", "$stage\config", "$stage\launcher", "$stage\docs", "$stage\manifest.json", "$stage\checksums.sha256" -DestinationPath $zipPath -CompressionLevel Fastest
}
Copy-Item "$stage\manifest.json" "$Out\$zipName.manifest.json"
Write-Host "DONE: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB,1)) MB)"

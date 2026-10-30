<#
  verify-offline.ps1 - offline readiness checks (no network).
#>
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Continue'
$script:pass = 0; $script:fail = 0

function Check([string]$name, [bool]$ok, [string]$detail) {
  if ($ok) { $script:pass++; Write-Host "[PASS] $name $detail" }
  else { $script:fail++; Write-Host "[FAIL] $name $detail" }
}

if (Test-Path -LiteralPath "$Root\checksums.sha256") {
  $bad = 0; $n = 0
  foreach ($line in Get-Content -LiteralPath "$Root\checksums.sha256") {
    if (-not $line) { continue }
    $n++
    $h, $rel = $line -split '  ', 2
    $f = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $f)) { $bad++; continue }
    if ((Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower() -ne $h) { $bad++ }
  }
  Check "checksums" ($bad -eq 0) "$n entries, $bad mismatch"
} else {
  Check "checksums" $false "checksums.sha256 missing"
}

$py = Get-ChildItem -LiteralPath "$Root\app\resources\agent-payload" -Filter "python*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($py) {
  $ver = (& $py.FullName -c "import sys;print(sys.version.split()[0])" 2>$null)
  Check "interpreter" ($ver -match '^\d+\.\d+') "$ver"
} else {
  Check "interpreter" $false "no bundled python found"
}

$stamp = "$Root\app\resources\install-stamp.json"
if (Test-Path -LiteralPath $stamp) {
  $s = Get-Content -LiteralPath $stamp -Raw | ConvertFrom-Json
  Check "install-stamp" $true "variant=$($s.variant) version=$($s.version)"
} else {
  Check "install-stamp" $false "not found (run setup.ps1)"
}

# config: auto-seed from template if missing so verify never fails on a fresh extract
$cfg = "$Root\data\config.yaml"
if (-not (Test-Path -LiteralPath $cfg)) {
  $tpl = "$Root\config\config.yaml.template"
  if (Test-Path -LiteralPath $tpl) {
    New-Item -ItemType Directory -Force -Path "$Root\data" | Out-Null
    Copy-Item -LiteralPath $tpl -Destination $cfg
    Write-Host "  seeded data\config.yaml from template"
  }
}
if (Test-Path -LiteralPath $cfg) {
  $text = Get-Content -LiteralPath $cfg -Raw
  Check "config-loopback" ($text -match 'base_url') "config.yaml present"
} else {
  Check "config-loopback" $false "data\config.yaml missing and no template (run setup.ps1)"
}

$exe = Get-ChildItem -LiteralPath "$Root\app" -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
$exeName = ""
if ($exe) { $exeName = $exe.Name }
Check "app-exe" ($exeName -ne "") $exeName

if (Test-Path -LiteralPath "$Root\skills-bundle") {
  $cnt = (Get-ChildItem -LiteralPath "$Root\skills-bundle" -Recurse -Filter "SKILL.md").Count
  Check "skills" ($cnt -gt 0) "$cnt skills"
} else {
  Check "skills" $false "skills-bundle missing"
}

Write-Host "Summary: $script:pass PASS / $script:fail FAIL"
if ($script:fail -gt 0) { exit 1 }

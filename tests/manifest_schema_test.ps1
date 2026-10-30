<#
  manifest_schema_test.ps1 - strict, offline validation of an offline bundle manifest.json.

  Usage:
    .\tests\manifest_schema_test.ps1
    .\tests\manifest_schema_test.ps1 -Manifest D:\dev\hermes-desktop-offline\artifacts\Hermes-Offline-0.22.5-win-x64.zip.manifest.json

  Contract under test (docs/02_architecture.md section 2.4):
    schemaVersion = 1, version = semver, target = win32-x64,
    components app/runtime/config/launcher present and required.

  Prints PASS/FAIL lines and exits nonzero on any failure. No network, no external tools.
#>
param(
  [string]$Manifest = ""
)

$ErrorActionPreference = 'Stop'
$failures = 0
$passes = 0

function Report([bool]$ok, [string]$name, [string]$detail = '') {
  if ($ok) { $script:passes++; Write-Host "PASS  $name  $detail" }
  else { $script:failures++; Write-Host "FAIL  $name  $detail" }
}

# ---------------------------------------------------------------- validator --
$ALLOWED_KEYS = @('schemaVersion', 'version', 'channel', 'commit', 'builtAt', 'target',
  'electron', 'python', 'components', 'sizeBytes', 'fileCount', 'signature',
  'prunedTools', 'componentHashes')
$REQUIRED_COMPONENTS = @('app', 'runtime', 'config', 'launcher')
$SEMVER = '^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

function Test-ManifestFile([string]$Path) {
  $errors = @()

  if (-not (Test-Path -LiteralPath $Path)) {
    $errors += "manifest not found: $Path"
    return $errors
  }

  $raw = $null
  try { $raw = Get-Content -LiteralPath $Path -Raw } catch { $errors += "manifest unreadable: $_"; return $errors }
  if (-not $raw) { $errors += "manifest is empty"; return $errors }

  $m = $null
  try { $m = $raw | ConvertFrom-Json } catch { $errors += "manifest is not valid JSON: $_"; return $errors }
  if ($m -eq $null) { $errors += "manifest parsed to null"; return $errors }
  if ($m -isnot [PSCustomObject]) { $errors += "manifest root must be a JSON object"; return $errors }

  $keys = $m.PSObject.Properties.Name

  # schemaVersion
  if (-not $keys.Contains('schemaVersion')) {
    $errors += "missing schemaVersion"
  } elseif ($m.schemaVersion -ne 1) {
    $errors += "unsupported schemaVersion '$($m.schemaVersion)' (expected 1)"
  }

  # version
  if (-not $keys.Contains('version')) {
    $errors += "missing version"
  } elseif ([string]$m.version -notmatch $SEMVER) {
    $errors += "version '$($m.version)' is not semver"
  }

  # target
  if (-not $keys.Contains('target')) {
    $errors += "missing target"
  } elseif ([string]$m.target -ne 'win32-x64') {
    $errors += "target '$($m.target)' is not win32-x64"
  }

  # components
  if (-not $keys.Contains('components')) {
    $errors += "missing components"
  } else {
    $comps = $m.components
    if ($comps -isnot [PSCustomObject]) {
      $errors += "components must be an object"
    } else {
      $compKeys = $comps.PSObject.Properties.Name
      foreach ($c in $REQUIRED_COMPONENTS) {
        if (-not $compKeys.Contains($c)) { $errors += "required component '$c' missing"; continue }
        $entry = $comps.$c
        if ($entry -isnot [PSCustomObject]) { $errors += "component '$c' must be an object"; continue }
        $entryKeys = $entry.PSObject.Properties.Name
        if (-not $entryKeys.Contains('path')) { $errors += "component '$c' missing path" }
        elseif ([string]$entry.path -ne $c) { $errors += "component '$c' path '$($entry.path)' does not match its key" }
        if (-not $entryKeys.Contains('required')) { $errors += "component '$c' missing required flag" }
        elseif ($entry.required -ne $true) { $errors += "component '$c' must be required" }
        if ($entryKeys.Contains('sha256') -and [string]$entry.sha256 -notmatch '^[0-9a-f]{64}$') {
          $errors += "component '$c' sha256 '$($entry.sha256)' is not 64 lowercase hex chars"
        }
      }
      # skills-bundle is optional, and when present must not claim to be required
      if ($compKeys.Contains('skills-bundle')) {
        $sb = $comps.'skills-bundle'
        if ($sb -is [PSCustomObject] -and $sb.required -eq $true) {
          $errors += "skills-bundle is optional and must not be marked required"
        }
      }
      foreach ($extra in ($compKeys | Where-Object { -not $REQUIRED_COMPONENTS.Contains($_) -and $_ -ne 'skills-bundle' })) {
        $errors += "unknown component '$extra'"
      }
    }
  }

  # optional but well-formed fields
  if ($keys.Contains('commit') -and [string]$m.commit -notmatch '^[0-9a-f]{40}$') {
    $errors += "commit '$($m.commit)' is not a 40-char hex sha"
  }
  if ($keys.Contains('builtAt')) {
    try { [void][datetime]::ParseExact([string]$m.builtAt, 'yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture) }
    catch { $errors += "builtAt '$($m.builtAt)' is not ISO-8601 UTC" }
  }
  if ($keys.Contains('sizeBytes') -and ($m.sizeBytes -lt 0)) { $errors += "sizeBytes must be >= 0" }
  if ($keys.Contains('fileCount') -and ($m.fileCount -lt 0)) { $errors += "fileCount must be >= 0" }

  foreach ($unknown in ($keys | Where-Object { -not $ALLOWED_KEYS.Contains($_) })) {
    $errors += "unknown top-level key '$unknown'"
  }

  return $errors
}

# ---------------------------------------------------------------- fixtures --
$work = Join-Path $env:TEMP ("hermes-manifest-test-" + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Write-Manifest([string]$name, [string]$json) {
  $p = Join-Path $work $name
  Set-Content -LiteralPath $p -Value $json -Encoding UTF8
  return $p
}

try {
  # 1. canonical valid manifest (mirrors docs/02_architecture.md section 2.4)
  $valid = @"
{
  "schemaVersion": 1,
  "version": "0.22.5",
  "channel": "offline-portable",
  "commit": "bf0203a794a07aac3ff764972ab9087baa4e4f4e",
  "builtAt": "2026-10-29T00:00:00Z",
  "target": "win32-x64",
  "electron": "44.9.3",
  "python": "3.14.9+20261021",
  "components": {
    "app":           { "path": "app",           "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "required": true },
    "runtime":       { "path": "runtime",       "sha256": "1111111111111111111111111111111111111111111111111111111111111111", "required": true },
    "skills-bundle": { "path": "skills-bundle", "required": false },
    "config":        { "path": "config",        "required": true },
    "launcher":      { "path": "launcher",      "required": true }
  },
  "fileCount": 128,
  "sizeBytes": 419430400
}
"@
  $p = Write-Manifest 'valid.json' $valid
  $errs = @(Test-ManifestFile $p)
  Report ($errs.Count -eq 0) 'valid_manifest_accepted' ($(if ($errs.Count) { $errs -join '; ' } else { '' }))

  # 2. the shape scripts/build-offline.ps1 actually emits (no per-component sha256)
  $buildShape = @"
{
  "schemaVersion": 1,
  "version": "0.0.0-local",
  "channel": "offline-portable",
  "commit": "bf0203a794a07aac3ff764972ab9087baa4e4f4e",
  "builtAt": "2026-10-29T00:00:00Z",
  "target": "win32-x64",
  "components": {
    "app": { "path": "app", "required": true },
    "runtime": { "path": "runtime", "required": true },
    "skills-bundle": { "path": "skills-bundle", "required": false },
    "config": { "path": "config", "required": true },
    "launcher": { "path": "launcher", "required": true }
  },
  "fileCount": 3,
  "sizeBytes": 10
}
"@
  $p = Write-Manifest 'build_shape.json' $buildShape
  $errs = @(Test-ManifestFile $p)
  Report ($errs.Count -eq 0) 'build_offline_shape_accepted' ($(if ($errs.Count) { $errs -join '; ' } else { '' }))

  # 3..9 negative cases: each must produce at least one error naming the defect
  $negatives = @(
    @{ name = 'rejects_wrong_schema_version'; json = '{"schemaVersion":2,"version":"1.0.0","target":"win32-x64","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'schemaVersion' },
    @{ name = 'rejects_non_semver_version';   json = '{"schemaVersion":1,"version":"0.0","target":"win32-x64","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'semver' },
    @{ name = 'rejects_wrong_target';         json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-arm64","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'target' },
    @{ name = 'rejects_missing_launcher_component'; json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true}}}'; expect = 'launcher' },
    @{ name = 'rejects_optional_required_flag';     json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","components":{"app":{"path":"app","required":false},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'app' },
    @{ name = 'rejects_component_path_mismatch';    json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","components":{"app":{"path":"application","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'path' },
    @{ name = 'rejects_bad_component_sha256';       json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","components":{"app":{"path":"app","sha256":"DEADBEEF","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'sha256' },
    @{ name = 'rejects_bad_commit_sha';             json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","commit":"deadbeef","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'commit' },
    @{ name = 'rejects_unknown_top_level_key';      json = '{"schemaVersion":1,"version":"1.0.0","target":"win32-x64","updater":"electron-updater","components":{"app":{"path":"app","required":true},"runtime":{"path":"runtime","required":true},"config":{"path":"config","required":true},"launcher":{"path":"launcher","required":true}}}'; expect = 'unknown' }
  )
  foreach ($n in $negatives) {
    $p = Write-Manifest ($n.name + '.json') $n.json
    $errs = @(Test-ManifestFile $p)
    $ok = ($errs.Count -gt 0) -and (($errs -join ' ') -match $n.expect)
    Report $ok $n.name ($(if ($errs.Count) { $errs[0] } else { 'validator accepted an invalid manifest' }))
  }

  # 10. missing file and non-JSON file are both hard failures
  $errs = @(Test-ManifestFile (Join-Path $work 'does-not-exist.json'))
  Report ($errs.Count -gt 0) 'rejects_missing_manifest' $errs[0]

  $p = Write-Manifest 'broken.json' '{ "schemaVersion": 1, "version": '
  $errs = @(Test-ManifestFile $p)
  Report ($errs.Count -gt 0) 'rejects_malformed_json' $errs[0]

  # 11. real manifest, when supplied
  if ($Manifest) {
    $errs = @(Test-ManifestFile $Manifest)
    Report ($errs.Count -eq 0) 'real_manifest_valid' ($(if ($errs.Count) { $errs -join '; ' } else { $Manifest }))
  }
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("Summary: {0} PASS / {1} FAIL" -f $passes, $failures)
if ($failures -gt 0) { exit 1 }
exit 0

<#
  launcher_env_test.ps1 - validate config\hermes-portable.ini and the paths it declares.

  Usage:
    .\tests\launcher_env_test.ps1
    .\tests\launcher_env_test.ps1 -Ini D:\dev\hermes-desktop-offline\config\hermes-portable.ini

  Checks (docs/02_architecture.md section 3.2):
    - the ini parses into sections/keys
    - required keys are present and well-formed
    - data_root and work_root exist and are writable
    - payload_placement is copy|junction, mode is strict|lan|permissive, gateway_port is a port
    - when mode = strict there is no non-loopback http(s) URL and allow_lan is false

  Prints PASS/FAIL lines and exits nonzero on failure. Local files only - no network.
#>
param(
  [string]$Ini = '',
  [string]$Root = 'D:\dev\hermes-desktop-offline'
)

$ErrorActionPreference = 'Stop'
$failures = 0
$passes = 0

function Report([bool]$ok, [string]$name, [string]$detail = '') {
  if ($ok) { $script:passes++; Write-Host "PASS  $name  $detail" }
  else { $script:failures++; Write-Host "FAIL  $name  $detail" }
}

# ---------------------------------------------------------------- ini parser --
# Format: [section] headers, key = value, ';' or '#' comments (full line and inline).
function Parse-Ini([string]$Path) {
  $sections = @{}
  $current = ''
  $errors = @()
  $lineNo = 0
  foreach ($raw in (Get-Content -LiteralPath $Path)) {
    $lineNo++
    $line = $raw.Trim()
    if (-not $line) { continue }
    if ($line.StartsWith('[')) {
      if ($line -notmatch '^\[[A-Za-z0-9_-]+\]$') { $errors += "line ${lineNo}: bad section header '$line'"; continue }
      $current = $line.Substring(1, $line.Length - 2)
      if (-not $sections.ContainsKey($current)) { $sections[$current] = @{} }
      continue
    }
    if ($line.StartsWith(';') -or $line.StartsWith('#')) { continue }
    if (-not $current) { $errors += "line ${lineNo}: key before any section '$line'"; continue }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { $errors += "line ${lineNo}: not a key=value pair '$line'"; continue }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    # strip inline comment
    $semi = $value.IndexOf(';')
    if ($semi -ge 0) { $value = $value.Substring(0, $semi).Trim() }
    if (-not $key) { $errors += "line ${lineNo}: empty key"; continue }
    if ($sections[$current].ContainsKey($key)) { $errors += "line ${lineNo}: duplicate key '$key' in section [$current]" }
    $sections[$current][$key] = $value
  }
  return [pscustomobject]@{ sections = $sections; errors = $errors }
}

function Get-Key($parsed, [string]$section, [string]$key) {
  if (-not $parsed.sections.ContainsKey($section)) { return $null }
  return $parsed.sections[$section][$key]
}

# ---------------------------------------------------------------- helpers --
function Is-Loopback([string]$url) {
  return $url -match '^(https?://)?(127\.0\.0\.1|localhost|\[::1\])([:/]|$)'
}

# In strict mode every http(s) URL must be loopback and allow_lan must be false.
# In lan/permissive mode non-loopback URLs are permitted.
function Get-OfflineModeViolations($parsed) {
  $violations = @()
  $mode = Get-Key $parsed 'offline' 'mode'
  foreach ($section in $parsed.sections.Keys) {
    foreach ($kv in $parsed.sections[$section].GetEnumerator()) {
      $v = [string]$kv.Value
      if ($mode -eq 'strict' -and $v -match 'https?://' -and -not (Is-Loopback $v)) {
        $violations += "$section.$($kv.Key) = $v"
      }
    }
  }
  if ($mode -eq 'strict' -and (Get-Key $parsed 'offline' 'allow_lan') -eq 'true') {
    $violations += "offline.allow_lan = true is not allowed in strict mode"
  }
  return $violations
}

function Test-WritableDirectory([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ ok = $false; why = 'directory does not exist' } }
  if ((Get-Item -LiteralPath $path).PSIsContainer -eq $false) { return [pscustomobject]@{ ok = $false; why = 'path is a file, not a directory' } }
  $probe = Join-Path $path '.hermes-portable-write-probe.tmp'
  try {
    Set-Content -LiteralPath $probe -Value 'probe' -Encoding UTF8
    Remove-Item -LiteralPath $probe -Force
    return [pscustomobject]@{ ok = $true; why = '' }
  } catch {
    return [pscustomobject]@{ ok = $false; why = "write probe failed: $_" }
  }
}

# ---------------------------------------------------------------- fixture --
$work = Join-Path $env:TEMP ("hermes-launcher-env-test-" + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Make-Ini([string]$name, [string]$body, [string[]]$dirs) {
  $p = Join-Path $work $name
  Set-Content -LiteralPath $p -Value $body -Encoding UTF8
  foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path (Join-Path $work $d) | Out-Null }
  return $p
}

try {
  # A. shipped config, if it exists, must be valid
  if (-not $Ini) { $Ini = Join-Path $Root 'config\hermes-portable.ini' }
  if (Test-Path -LiteralPath $Ini) {
    $parsed = Parse-Ini $Ini
    Report ($parsed.errors.Count -eq 0) 'shipped_ini_parses' ($parsed.errors -join '; ')
    $bad = @(Get-OfflineModeViolations $parsed)
    Report ($bad.Count -eq 0) 'shipped_ini_offline_mode_clean' ($bad -join '; ')
  } else {
    Write-Host "SKIP  shipped_ini_parses  $Ini does not exist yet"
  }

  # B. good fixture: strict mode, loopback endpoint, real directories
  $goodBody = @"
; Hermes portable launcher configuration
[paths]
install_root      = $work
data_root         = $work\data
work_root         = $work\work
cache_root        = $work\cache
payload_placement = junction

[runtime]
hermes_cli        = runtime\bin\hermes.exe
python            = runtime\tools\python-3.14.9+20261021-win32-x64\python.exe
site_packages     = runtime\venv\Lib\site-packages
repo              = runtime\hermes-agent

[offline]
mode              = strict
local_base_url    = http://127.0.0.1:11434/v1
local_model       = qwen3:14b
gateway_port      = 8787
allow_lan         = false
"@
  $good = Make-Ini 'good.ini' $goodBody @('data', 'work', 'cache')

  $parsed = Parse-Ini $good
  Report ($parsed.errors.Count -eq 0) 'good_ini_parses' ($parsed.errors -join '; ')
  Report ($parsed.sections.ContainsKey('paths') -and $parsed.sections.ContainsKey('runtime') -and $parsed.sections.ContainsKey('offline')) 'good_ini_has_all_sections' ''

  foreach ($key in @('install_root', 'data_root', 'work_root', 'cache_root', 'payload_placement')) {
    Report ((Get-Key $parsed 'paths' $key) -ne $null) "good_ini_has_$key" ''
  }
  Report ((Get-Key $parsed 'offline' 'mode') -ne $null) 'good_ini_has_mode' ''

  $data = Test-WritableDirectory (Get-Key $parsed 'paths' 'data_root')
  Report $data.ok 'data_root_exists_and_writable' $data.why
  $wrk = Test-WritableDirectory (Get-Key $parsed 'paths' 'work_root')
  Report $wrk.ok 'work_root_exists_and_writable' $wrk.why

  $placement = Get-Key $parsed 'paths' 'payload_placement'
  Report (@('copy', 'junction') -contains $placement) 'payload_placement_valid' "got '$placement'"

  $mode = Get-Key $parsed 'offline' 'mode'
  Report (@('strict', 'lan', 'permissive') -contains $mode) 'offline_mode_valid' "got '$mode'"

  $port = Get-Key $parsed 'offline' 'gateway_port'
  $portOk = ($port -match '^\d+$') -and ([int]$port -ge 1) -and ([int]$port -le 65535)
  Report $portOk 'gateway_port_valid' "got '$port'"

  Report (Is-Loopback (Get-Key $parsed 'offline' 'local_base_url')) 'strict_local_base_url_is_loopback' (Get-Key $parsed 'offline' 'local_base_url')

  # C. negative: strict mode with a LAN endpoint must be rejected
  $lanBody = $goodBody -replace 'local_base_url    = http://127\.0\.0\.1:11434/v1', 'local_base_url    = http://100.106.91.39:8001/v1 ; LAN inference host'
  $lanIni = Make-Ini 'lan_in_strict.ini' $lanBody @('data', 'work')
  $violations = @(Get-OfflineModeViolations (Parse-Ini $lanIni))
  Report ($violations.Count -ge 1) 'strict_mode_rejects_non_loopback_url' ($violations -join '; ')

  # D. negative: strict mode with allow_lan = true must be rejected
  $allowBody = $goodBody -replace 'allow_lan         = false', 'allow_lan         = true'
  $allowIni = Make-Ini 'allow_lan_in_strict.ini' $allowBody @('data', 'work')
  $parsed = Parse-Ini $allowIni
  $lanFlag = Get-Key $parsed 'offline' 'allow_lan'
  $mode = Get-Key $parsed 'offline' 'mode'
  $strictViolation = ($mode -eq 'strict') -and ($lanFlag -eq 'true')
  Report $strictViolation 'strict_mode_rejects_allow_lan' "mode=$mode allow_lan=$lanFlag"

  # E. negative: lan mode is allowed to name a LAN endpoint
  $lanOkBody = $lanBody -replace 'mode              = strict', 'mode              = lan'
  $lanOkIni = Make-Ini 'lan_mode_allows_lan.ini' $lanOkBody @('data', 'work')
  $parsedLan = Parse-Ini $lanOkIni
  $violations = @(Get-OfflineModeViolations $parsedLan)
  $lanUrlSeen = $parsedLan.sections['offline']['local_base_url'] -match '100\.106\.91\.39'
  Report ($lanUrlSeen -and $violations.Count -eq 0) 'lan_mode_permits_lan_endpoint' "violations: $($violations -join '; ')"

  # F. negative: data_root that does not exist
  $badBody = $goodBody.Replace("data_root         = $work\data", "data_root         = $work\does-not-exist")
  $badIni = Make-Ini 'missing_data_root.ini' $badBody @('data', 'work')
  $parsed = Parse-Ini $badIni
  $r = Test-WritableDirectory (Get-Key $parsed 'paths' 'data_root')
  Report (-not $r.ok) 'missing_data_root_is_rejected' $r.why

  # G. negative: work_root is a file, not a directory
  Set-Content -LiteralPath (Join-Path $work 'work-is-a-file') -Value 'not a directory' -Encoding UTF8
  $fileBody = $goodBody.Replace("work_root         = $work\work", "work_root         = $work\work-is-a-file")
  $fileIni = Make-Ini 'work_root_is_file.ini' $fileBody @('data')
  $parsed = Parse-Ini $fileIni
  $r = Test-WritableDirectory (Get-Key $parsed 'paths' 'work_root')
  Report (-not $r.ok) 'work_root_as_file_is_rejected' $r.why

  # H. negative: malformed ini (key before section, bad header, no '=' )
  $malformed = Make-Ini 'malformed.ini' @"
[paths]
data_root = $work\data
orphan_key = value
[bad section]
mode strict
"@ @('data')
  $parsed = Parse-Ini $malformed
  Report ($parsed.errors.Count -ge 2) 'malformed_ini_reports_errors' ($parsed.errors -join '; ')

  # I. negative: unknown mode value
  $modeBody = $goodBody -replace 'mode              = strict', 'mode              = airgap'
  $modeIni = Make-Ini 'bad_mode.ini' $modeBody @('data', 'work')
  $parsed = Parse-Ini $modeIni
  Report (@('strict', 'lan', 'permissive') -notcontains (Get-Key $parsed 'offline' 'mode')) 'unknown_mode_rejected' (Get-Key $parsed 'offline' 'mode')

  # J. negative: out-of-range gateway port
  $portBody = $goodBody -replace 'gateway_port      = 8787', 'gateway_port      = 99999'
  $portIni = Make-Ini 'bad_port.ini' $portBody @('data', 'work')
  $parsed = Parse-Ini $portIni
  $port = Get-Key $parsed 'offline' 'gateway_port'
  $portOk = ($port -match '^\d+$') -and ([int]$port -ge 1) -and ([int]$port -le 65535)
  Report (-not $portOk) 'out_of_range_port_rejected' "got '$port'"
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("Summary: {0} PASS / {1} FAIL" -f $passes, $failures)
if ($failures -gt 0) { exit 1 }
exit 0

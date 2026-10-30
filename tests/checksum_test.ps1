<#
  checksum_test.ps1 - recompute SHA-256 for every file in a staged bundle and compare
  against checksums.sha256 (docs/02_architecture.md section 2.4 format: "<sha256>  <relative/path>").

  Usage:
    .\tests\checksum_test.ps1 -StagedDir D:\dev\hermes-desktop-offline\artifacts\stage
    .\tests\checksum_test.ps1                      # builds a synthetic fixture in %TEMP%

  Includes a negative test: a byte is flipped in a throwaway copy of the staged tree and
  the verifier must report a mismatch. Prints PASS/FAIL lines, exits nonzero on failure.
  Local files only - no network.
#>
param(
  [string]$StagedDir = '',
  [string]$ChecksumFile = 'checksums.sha256'
)

$ErrorActionPreference = 'Stop'
$failures = 0
$passes = 0

function Report([bool]$ok, [string]$name, [string]$detail = '') {
  if ($ok) { $script:passes++; Write-Host "PASS  $name  $detail" }
  else { $script:failures++; Write-Host "FAIL  $name  $detail" }
}

# ---------------------------------------------------------------- verifier --
# Returns an object with the mismatch list so callers can assert on it.
function Test-Checksums([string]$Root, [string]$ListFile) {
  $missing = @()
  $mismatch = @()
  $malformed = @()
  $seen = @{}

  if (-not (Test-Path -LiteralPath $ListFile)) {
    return [pscustomobject]@{ missing = @('checksums.sha256 absent'); mismatch = @(); malformed = @(); unlisted = @(); total = 0 }
  }

  $lineNo = 0
  foreach ($line in (Get-Content -LiteralPath $ListFile)) {
    $lineNo++
    if (-not $line.Trim()) { continue }
    $parts = $line -split '  ', 2
    if ($parts.Count -ne 2) { $malformed += "line ${lineNo}: '$line'"; continue }
    $hash = $parts[0].Trim().ToLower()
    $rel = $parts[1].Trim()
    if ($hash -notmatch '^[0-9a-f]{64}$') { $malformed += "line ${lineNo}: bad hash '$hash'"; continue }
    if (-not $rel) { $malformed += "line ${lineNo}: empty path"; continue }
    if ($seen.ContainsKey($rel)) { $malformed += "line ${lineNo}: duplicate entry for '$rel'"; continue }
    $seen[$rel] = $hash

    $f = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $f)) { $missing += $rel; continue }
    if ((Get-Item -LiteralPath $f).PSIsContainer) { $malformed += "line ${lineNo}: '$rel' is a directory"; continue }
    $actual = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $hash) { $mismatch += "$rel (expected $hash, got $actual)" }
  }

  # every file physically present must be covered by the list, otherwise the bundle
  # contains unverified bytes and must be rejected
  $unlisted = @()
  foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File)) {
    $rel = $f.FullName.Substring($Root.Length + 1)
    if ($rel -eq [System.IO.Path]::GetFileName($ListFile)) { continue }
    if (-not $seen.ContainsKey($rel)) { $unlisted += $rel }
  }

  return [pscustomobject]@{ missing = $missing; mismatch = $mismatch; malformed = $malformed; unlisted = $unlisted; total = $seen.Count }
}

# ---------------------------------------------------------------- fixture --
$work = Join-Path $env:TEMP ("hermes-checksum-test-" + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
  if ($StagedDir) {
    if (-not (Test-Path -LiteralPath $StagedDir)) { throw "StagedDir not found: $StagedDir" }
    $stage = $StagedDir
    Write-Host "Using staged dir: $stage"
  } else {
    $stage = Join-Path $work 'stage'
    New-Item -ItemType Directory -Force -Path "$stage\app", "$stage\runtime\venv\Lib\site-packages", "$stage\config", "$stage\launcher" | Out-Null
    Set-Content -LiteralPath "$stage\app\Hermes Agent.exe" -Value 'electron stub binary' -Encoding UTF8
    Set-Content -LiteralPath "$stage\runtime\manifest.json" -Value '{"schema":1}' -Encoding UTF8
    Set-Content -LiteralPath "$stage\runtime\venv\Lib\site-packages\hermes-agent.pth" -Value 'import os; print(1)' -Encoding UTF8
    Set-Content -LiteralPath "$stage\config\hermes-portable.ini" -Value '[paths]' -Encoding UTF8
    Set-Content -LiteralPath "$stage\launcher\setup.ps1" -Value 'Write-Host hi' -Encoding UTF8

    $lines = foreach ($f in (Get-ChildItem -LiteralPath $stage -Recurse -File)) {
      $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
      $rel = $f.FullName.Substring($stage.Length + 1)
      "$h  $rel"
    }
    Set-Content -LiteralPath "$stage\checksums.sha256" -Value $lines -Encoding UTF8
    Write-Host "Built synthetic fixture at $stage"
  }

  # 1. clean tree verifies
  $r = Test-Checksums $stage (Join-Path $stage $ChecksumFile)
  Report ($r.total -gt 0 -and $r.missing.Count -eq 0 -and $r.mismatch.Count -eq 0 -and $r.malformed.Count -eq 0 -and $r.unlisted.Count -eq 0) `
    'clean_tree_verifies' "$($r.total) files checked"

  # 2. negative: flip one byte in a throwaway copy, same checksum list
  $copy = Join-Path $work 'corrupted'
  Copy-Item -LiteralPath $stage -Destination $copy -Recurse
  $target = Join-Path $copy 'runtime\manifest.json'
  $bytes = [System.IO.File]::ReadAllBytes($target)
  $bytes[0] = ($bytes[0] -bxor 0xFF)
  [System.IO.File]::WriteAllBytes($target, $bytes)

  $r = Test-Checksums $copy (Join-Path $copy $ChecksumFile)
  Report ($r.mismatch.Count -eq 1 -and $r.mismatch[0] -like 'runtime\manifest.json*') 'detects_single_byte_corruption' $(if ($r.mismatch.Count) { $r.mismatch[0] } else { 'no mismatch reported' })

  # 3. negative: a file listed but absent from the tree
  $copy2 = Join-Path $work 'missing_file'
  Copy-Item -LiteralPath $stage -Destination $copy2 -Recurse
  Remove-Item -LiteralPath (Join-Path $copy2 'launcher\setup.ps1') -Force
  $r = Test-Checksums $copy2 (Join-Path $copy2 $ChecksumFile)
  Report ($r.missing.Count -eq 1 -and $r.missing[0] -eq 'launcher\setup.ps1') 'detects_missing_file' ($r.missing -join '; ')

  # 4. negative: a file present but not in the checksum list
  Set-Content -LiteralPath (Join-Path $stage 'runtime\rogue.dll') -Value 'unverified payload' -Encoding UTF8
  $r = Test-Checksums $stage (Join-Path $stage $ChecksumFile)
  Report ($r.unlisted.Count -eq 1 -and $r.unlisted[0] -eq 'runtime\rogue.dll') 'detects_unlisted_file' ($r.unlisted -join '; ')
  Remove-Item -LiteralPath (Join-Path $stage 'runtime\rogue.dll') -Force

  # 5. negative: malformed checksum line is rejected
  Add-Content -LiteralPath (Join-Path $stage $ChecksumFile) -Value "notahash  app/Hermes Agent.exe"
  $r = Test-Checksums $stage (Join-Path $stage $ChecksumFile)
  Report ($r.malformed.Count -ge 1) 'rejects_malformed_line' ($r.malformed -join '; ')

  # 6. negative: missing checksums.sha256 is a hard failure
  $copy3 = Join-Path $work 'no_checksums'
  Copy-Item -LiteralPath $stage -Destination $copy3 -Recurse
  Remove-Item -LiteralPath (Join-Path $copy3 $ChecksumFile) -Force
  $r = Test-Checksums $copy3 (Join-Path $copy3 $ChecksumFile)
  Report ($r.missing.Count -eq 1) 'rejects_missing_checksum_list' ($r.missing -join '; ')
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("Summary: {0} PASS / {1} FAIL" -f $passes, $failures)
if ($failures -gt 0) { exit 1 }
exit 0

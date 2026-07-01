#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Pretty Flutter test runner - groups results by file and test group,
  colours pass/fail, and shows per-test timing.

  Wraps: fvm flutter test --reporter json
  Invoke from apps\worklog_studio\ (same directory as pubspec.yaml).

.EXAMPLE
  # All tests (default):
  .\tool\windows\run_tests.ps1

  # Specific file or folder:
  .\tool\windows\run_tests.ps1 test/core/hotkey_service_test.dart
  .\tool\windows\run_tests.ps1 test/core/ test/feature/desktop/
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0, ValueFromRemainingArguments)]
  [string[]] $Paths = @('test/core/', 'test/feature/')
)

Set-StrictMode -Off

# UTF-8 so box-drawing and checkmark glyphs render correctly in Windows Terminal.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding            = [System.Text.Encoding]::UTF8

# ─── ANSI colours ─────────────────────────────────────────────────────────────
$E      = [char]27
$R      = "$E[0m"
$Bold   = "$E[1m"
$Dim    = "$E[2m"
$Green  = "$E[38;5;114m"
$Red    = "$E[38;5;203m"
$Yellow = "$E[38;5;222m"
$Cyan   = "$E[38;5;117m"
$Gray   = "$E[38;5;245m"
$Faint  = "$E[38;5;238m"

# Unicode glyphs via code points - avoids source-file encoding issues in PS5.
$GlyphPass  = [char]0x2713  # checkmark
$GlyphFail  = [char]0x2717  # cross
$GlyphSkip  = [char]0x25CB  # hollow circle
$GlyphHRule = [char]0x2500  # box-drawing horizontal line

# ─── Layout helpers ───────────────────────────────────────────────────────────
function Rule([string] $c, [int] $n = 66) { $c * $n }
function HRule([int] $n = 66) { $Script:GlyphHRule.ToString() * $n }

function Write-FileHeader([string] $path) {
  $rel = ($path -replace '.*[/\\]test[/\\]', 'test/') -replace '\\', '/'
  Write-Host ""
  Write-Host "  ${Cyan}${Bold}$(HRule)${R}"
  Write-Host "  ${Cyan}${Bold}  ${rel}${R}"
  Write-Host "  ${Cyan}${Bold}$(HRule)${R}"
  Write-Host ""
}

function Write-GroupHeader([string] $name) {
  Write-Host ""
  Write-Host "  ${Bold}${Yellow}${name}${R}"
}

function Write-TestPass([string] $name, [int] $ms) {
  $timing = if ($ms -gt 0) { "  ${Gray}${ms}ms${R}" } else { '' }
  Write-Host "    ${Green}${Script:GlyphPass}${R}  ${name}${timing}"
}

function Write-TestFail([string] $name, [int] $ms) {
  $timing = if ($ms -gt 0) { "  ${Gray}${ms}ms${R}" } else { '' }
  Write-Host "    ${Red}${Bold}${Script:GlyphFail}${R}  ${Red}${name}${R}${timing}"
}

function Write-TestSkip([string] $name) {
  Write-Host "    ${Gray}${Script:GlyphSkip}  ${name}${R}"
}

function Write-ErrorDetail([string] $msg, [string] $trace) {
  Write-Host ""
  $msg -split "`r?`n" | ForEach-Object {
    if ($_.Trim()) { Write-Host "      ${Red}${_}${R}" }
  }
  if ($trace) {
    Write-Host "      ${Faint}$(Rule '.' 52)${R}"
    $trace -split "`r?`n" | Select-Object -First 8 | ForEach-Object {
      if ($_.Trim()) { Write-Host "      ${Faint}${_}${R}" }
    }
  }
  Write-Host ""
}

# ─── State ────────────────────────────────────────────────────────────────────
$suites      = @{}  # suiteID -> path
$groups      = @{}  # groupID -> group JSON object
$testMeta    = @{}  # testID  -> testStart.test JSON object
$testStartMs = @{}  # testID  -> testStart event time (ms since runner started)
$errors      = @{}  # testID  -> {message, stackTrace}

$seenFiles  = @{}   # suiteID -> shown?
$seenGroups = @{}   # groupID -> shown?

$pass = 0
$fail = 0
$skip = 0
$t0   = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

# ─── Run ──────────────────────────────────────────────────────────────────────
$flutterArgs = @('flutter', 'test') + $Paths + @('--reporter', 'json')

& fvm @flutterArgs 2>&1 | ForEach-Object {

  $raw = $_.ToString()
  if (-not $raw.Trim()) { return }

  # Try to parse as a JSON event; non-JSON lines (dep resolution, compile
  # output, stderr) are printed dimmed so they don't disappear entirely.
  $ev = $null
  try   { $ev = $raw | ConvertFrom-Json -ErrorAction Stop }
  catch { Write-Host "${Dim}${raw}${R}"; return }

  switch ($ev.type) {

    # ── Discovery events ───────────────────────────────────────────────────

    'suite' {
      $suites[$ev.suite.id] = $ev.suite.path
    }

    'group' {
      $groups[$ev.group.id] = $ev.group
    }

    # ── Per-test events ────────────────────────────────────────────────────

    'testStart' {
      $t = $ev.test
      $testMeta[$t.id]    = $t
      $testStartMs[$t.id] = [int]$ev.time   # ms since test runner started

      # File banner - once per suite.
      if (-not $seenFiles.ContainsKey($t.suiteID)) {
        $seenFiles[$t.suiteID] = $true
        Write-FileHeader $suites[$t.suiteID]
      }

      # Group header - once per deepest named ancestor group.
      # groupIDs are ordered outermost-first; the root group has an empty
      # name and is excluded by the Where-Object filter.
      $namedIds = @($t.groupIDs) |
        Where-Object { $groups.ContainsKey($_) -and $groups[$_].name }
      $deepest = $namedIds | Select-Object -Last 1

      if ($null -ne $deepest -and -not $seenGroups.ContainsKey($deepest)) {
        $seenGroups[$deepest] = $true
        Write-GroupHeader $groups[$deepest].name
      }
    }

    'testDone' {
      # hidden=true are internal framework tests (loading, setUpAll, etc.)
      if ($ev.hidden) { return }

      $t = $testMeta[$ev.testID]
      if (-not $t) { return }

      # Duration: both events carry 'time' = ms since runner start.
      $dur = [Math]::Max(0, ([int]$ev.time) - $testStartMs[$ev.testID])

      # Strip the deepest group name prefix to avoid repeating the group
      # header text in every test row.
      $name = $t.name
      $namedIds = @($t.groupIDs) |
        Where-Object { $groups.ContainsKey($_) -and $groups[$_].name }
      $deepest = $namedIds | Select-Object -Last 1
      if ($null -ne $deepest) {
        $pfx = $groups[$deepest].name + ' '
        if ($name.StartsWith($pfx)) { $name = $name.Substring($pfx.Length) }
      }

      if ($ev.skipped) {
        Write-TestSkip $name
        $skip++
      } elseif ($ev.result -eq 'success') {
        Write-TestPass $name $dur
        $pass++
      } else {
        $err = $errors[$ev.testID]
        Write-TestFail $name $dur
        if ($err) { Write-ErrorDetail $err.message $err.stackTrace }
        $fail++
      }
    }

    # Error arrives before testDone; collect here and display inline on testDone.
    'error' {
      $errors[$ev.testID] = @{
        message    = $ev.message
        stackTrace = $ev.stackTrace
      }
    }

    # Print events carry debugPrint() / print() output from test code.
    'print' {
      if ($ev.message) {
        Write-Host "      ${Dim}>> $($ev.message)${R}"
      }
    }

    'done' {
      $elapsed = (([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $t0) / 1000.0).ToString('0.0')

      Write-Host ""
      Write-Host "  ${Gray}$(HRule)${R}"
      Write-Host ""

      $summary  = "  ${Bold}${Green}${pass} passed${R}"
      if ($fail -gt 0) { $summary += "  ${Bold}${Red}${fail} failed${R}" }
      if ($skip -gt 0) { $summary += "  ${Yellow}${skip} skipped${R}" }
      $summary += "  ${Gray}${elapsed}s${R}"
      Write-Host $summary
      Write-Host ""
    }
  }
}

# Propagate failure so CI / calling scripts can detect it.
if ($fail -gt 0) { exit 1 }

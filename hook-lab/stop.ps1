# agentStop and subagentStop, for Windows machines without Node. Same behaviour as
# stop.mjs: runs the gates in hook-lab/gates.txt, asks the policy what to do, and blocks
# the agent with the failures when the policy says block.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File hook-lab/stop.ps1 agentStop hook-lab/policy.ps1

param([string]$Hook = 'agentStop', [string]$PolicyFile = 'hook-lab/policy.ps1')

. "$PSScriptRoot\trace.ps1"
$TraceName = if ($Hook -eq 'subagentStop') { 'subagent-stop' } else { 'agent-stop' }
Set-Location $Root

# ---- gates

$Mvn = 'mvnw.cmd -o -q'
$Generate = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\generate-rates.ps1 -Check'

function Get-Gates {
  Get-Content 'hook-lab/gates.txt' | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
      $line = $_
      $kind, $arg = $line -split '\s+', 2
      switch ($kind) {
        'compile' { @{ name = 'compile'; command = "$Mvn compile" } }
        'suite' { @{ name = 'suite'; command = "$Mvn test" } }
        'acceptance' { @{ name = $arg; command = "$Mvn -Dtest=$arg test" } }
        'mutation' {
          @{ name = "mutation $($arg.Split('.')[-1])"; command = "$Mvn test-compile " +
            "org.pitest:pitest-maven:mutationCoverage -DtargetClasses=$arg" }
        }
        'generated' { @{ name = 'generated'; command = $Generate } }
        default { @{ name = $line; command = $null } }
      }
    }
}

function Invoke-Gate($gate) {
  $name = $gate.name
  if (-not $gate.command) {
    return [ordered]@{ name = $name; status = 'ERROR'; detail = "unknown gate in gates.txt: $name" }
  }
  if (-not (Test-Path 'mvnw.cmd')) {
    return [ordered]@{ name = $name; status = 'ERROR'; detail = 'missing Maven wrapper: mvnw.cmd' }
  }
  New-Item -ItemType Directory -Force '.loop\logs' | Out-Null
  $log = ".loop\logs\$($name -replace '[^A-Za-z0-9-]+', '-').log"
  # cmd runs mvnw.cmd and writes every line to the log, so PowerShell never sees stderr.
  cmd /c "$($gate.command) > $log 2>&1"
  $exit = $LASTEXITCODE
  # Maven on Windows draws a spinner with backspaces. Drop each drawn character with its backspace.
  $output = [IO.File]::ReadAllText((Join-Path $Root $log)).Replace($Root, '.') -replace '[^\n]?\x08', ''
  if ($exit -ne 0) { return [ordered]@{ name = $name; status = 'FAIL'; detail = Get-Excerpt $output } }
  if ($name.StartsWith('mutation ')) { return Get-Mutants $name }
  [ordered]@{ name = $name; status = 'PASS' }
}

# The assertion, compiler error or test summary lines, without the stack trace.
function Get-Excerpt($output) {
  $lines = @($output -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object {
    $_ -and $_ -notmatch '^at |^\[ERROR\] *(->|$|re-run|to see|for more|\[help|after)' })
  $keep = @($lines | Where-Object { $_ -match 'tests run:|expected|but was|error:|warning:|\.java:\[?\d' })
  if (-not $keep.Count) { $keep = @($lines | Select-Object -Last 10) }
  (@($keep | Select-Object -Unique) | Select-Object -First 15) -join "`n"
}

# PIT exits 0 whatever survives, so read its report: file,class,mutator,method,line,status.
$Mutators = @{
  NegateConditionalsMutator = 'condition inverted'
  ConditionalsBoundaryMutator = 'boundary changed (< to <=)'
  MathMutator = 'arithmetic operator swapped'
  PrimitiveReturnsMutator = 'returns 0 instead'
  BooleanTrueReturnValsMutator = 'returns true instead'
  BooleanFalseReturnValsMutator = 'returns false instead'
  NullReturnValsMutator = 'returns null instead'
  EmptyObjectReturnValsMutator = 'returns an empty value instead'
  VoidMethodCallMutator = 'a call removed'
  IncrementsMutator = 'increment changed'
}

function Get-Mutants($name) {
  $csv = 'target\pit-reports\mutations.csv'
  if (-not (Test-Path $csv)) { return [ordered]@{ name = $name; status = 'ERROR'; detail = 'PIT wrote no report' } }
  $rows = @(Get-Content $csv | Where-Object { $_ } | ForEach-Object { , ($_ -split ',') })
  $missed = @($rows | Where-Object { $_[5] -ne 'KILLED' -and $_[5] -ne 'TIMED_OUT' } | ForEach-Object {
    $mutator = $_[2].Split('.')[-1]
    $label = if ($Mutators[$mutator]) { $Mutators[$mutator] } else { $mutator }
    $why = if ($_[5] -eq 'NO_COVERAGE') { 'no unit test runs this line' }
      else { 'unit tests run this line but still pass with the bug' }
    "$($_[0]):$($_[4]) in $($_[3])(): $label. $why"
  })
  if (-not $missed.Count) { return [ordered]@{ name = $name; status = 'PASS' } }
  [ordered]@{ name = $name; status = 'FAIL'; detail = "$($missed.Count) of $($rows.Count) mutants " +
    'were not caught by the unit tests. Add unit tests that would fail if these changes were ' +
    "made:`n$($missed -join "`n")" }
}

# ---- the stop

$hookEvent = Read-Event
if ($null -eq $hookEvent) {
  Write-Trace $TraceName ([ordered]@{ decision = 'malformed-event'; verified = $false })
  [Console]::Out.Write('{}')
  exit 0
}

# agentStop also fires when a sub-agent ends. The subagentStop hook judges sub-agents.
$agentId = if ($hookEvent.agentId) { $hookEvent.agentId } else { $null }
if ($Hook -eq 'agentStop' -and $agentId) {
  [Console]::Out.Write('{}')
  exit 0
}

# Copilot only says whether this stop follows a block, so the count comes from the trace.
$previous = Read-Trace $TraceName | Where-Object { $_.agentId -eq $agentId } | Select-Object -Last 1
$attempt = if ($hookEvent.stop_hook_active -and $previous.attempt) { $previous.attempt + 1 }
  elseif ($hookEvent.stop_hook_active) { 2 } else { 1 }
$base = [ordered]@{ attempt = $attempt; agentId = $agentId; agentName = $hookEvent.agentName; policy = $PolicyFile }

function Write-Stop($extra) {
  $entry = [ordered]@{}
  foreach ($key in $base.Keys) { if ($null -ne $base[$key]) { $entry[$key] = $base[$key] } }
  foreach ($key in $extra.Keys) { $entry[$key] = $extra[$key] }
  Write-Trace $TraceName $entry
}

try {
  . (Join-Path $Root $PolicyFile)
} catch {
  Write-Stop ([ordered]@{ decision = 'policy-error'; verified = $false; error = "$_" })
  [Console]::Error.WriteLine("${Hook}: policy not loaded, ends unverified: $_")
  [Console]::Out.Write('{}')
  exit 0
}

$results = @(Get-Gates | ForEach-Object { Invoke-Gate $_ })
$statusByGate = [ordered]@{}
foreach ($r in $results) { $statusByGate[$r.name] = $r.status }
$summary = ($results | ForEach-Object { "$($_.name) $($_.status)" }) -join ', '
if (-not $summary) { $summary = 'no gates switched on' }
$verified = $results.Count -gt 0 -and @($results | Where-Object { $_.status -ne 'PASS' }).Count -eq 0

try { $decision = decide $attempt $statusByGate } catch { $decision = "threw: $($_.Exception.Message)" }
$known = 'block', 'allow', 'allow-after-limit' -contains $decision

$extra = [ordered]@{ decision = $(if ($known) { $decision } else { 'policy-error' }); verified = $verified
  summary = $summary; results = $results }
if (-not $known) { $extra.error = "decide returned $decision" }
Write-Stop $extra
$shown = if ($known) { $decision } else { "policy error ($decision)" }
[Console]::Error.WriteLine("${Hook}: $shown, attempt $attempt, " +
  "$(if ($verified) { 'verified' } else { 'unverified' }): $summary")

if ($decision -eq 'block') {
  $failures = ($results | Where-Object { $_.status -ne 'PASS' } |
    ForEach-Object { "$($_.name) $($_.status):`n$($_.detail)" }) -join "`n`n"
  $reason = "Stop hook, attempt ${attempt}: gates did not pass ($summary). " +
    "Fix what is reported below, then finish again.`n`n$failures"
  if ($reason.Length -gt 4000) { $reason = $reason.Substring(0, 4000) }
  [Console]::Out.Write((ConvertTo-Json -Compress @{ decision = 'block'; reason = $reason }))
} else {
  [Console]::Out.Write('{}')
}

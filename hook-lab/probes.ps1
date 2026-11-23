# Checks a stop policy without running Maven.
#
#   powershell -ExecutionPolicy Bypass -File hook-lab/probes.ps1
#   powershell -ExecutionPolicy Bypass -File hook-lab/probes.ps1 hook-lab/reference/policy.ps1

param([string]$PolicyFile = 'hook-lab/policy.ps1')

. (Join-Path (Split-Path -Parent $PSScriptRoot) $PolicyFile)
$limit = $MAX_BLOCKS

$probes = @(
  @('every gate passes: allow', 1, [ordered]@{ compile = 'PASS'; suite = 'PASS' }, 'allow'),
  @('a gate fails on the first stop: block', 1, [ordered]@{ compile = 'PASS'; suite = 'FAIL' }, 'block'),
  @('a gate errors: ERROR is not a pass, block', 1, [ordered]@{ suite = 'ERROR' }, 'block'),
  @('no gates switched on: not a pass, block', 1, [ordered]@{}, 'block'),
  @("still failing on attempt ${limit}: block", $limit, [ordered]@{ suite = 'FAIL' }, 'block'),
  @("still failing on attempt $($limit + 1): allow-after-limit", ($limit + 1),
    [ordered]@{ suite = 'FAIL' }, 'allow-after-limit'),
  @("still erroring on attempt $($limit + 1): allow-after-limit", ($limit + 1),
    [ordered]@{ suite = 'ERROR' }, 'allow-after-limit'),
  @("a retry that passes on attempt $($limit + 1): allow", ($limit + 1),
    [ordered]@{ suite = 'PASS' }, 'allow')
)

$failed = 0
foreach ($probe in $probes) {
  $name, $attempt, $statusByGate, $expected = $probe
  try { $got = decide $attempt $statusByGate } catch { $got = "threw ""$($_.Exception.Message)""" }
  $ok = $got -eq $expected
  if (-not $ok) { $failed++ }
  Write-Output ("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name,
    $(if ($ok) { '' } else { "  (got $got)" }))
}
Write-Output ''
Write-Output "$($probes.Count - $failed) passed, $failed failed ($PolicyFile, MAX_BLOCKS $limit)"
exit $(if ($failed) { 1 } else { 0 })

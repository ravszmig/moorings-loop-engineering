# Reference stop decision. Same contract as hook-lab/policy.ps1.

$MAX_BLOCKS = 3

function decide($attempt, $statusByGate) {
  $statuses = @($statusByGate.Values)
  $allPassed = $statuses.Count -gt 0 -and @($statuses | Where-Object { $_ -ne 'PASS' }).Count -eq 0
  if ($allPassed) { return 'allow' }
  if ($attempt -le $MAX_BLOCKS) { return 'block' }
  return 'allow-after-limit'
}

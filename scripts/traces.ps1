# One line per hook decision, from every trace in .loop/.
#
#   powershell -ExecutionPolicy Bypass -File scripts/traces.ps1

Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($name in 'session-start', 'pre-tool-use', 'agent-stop', 'subagent-stop') {
  $file = ".loop\$name.jsonl"
  if (-not (Test-Path $file)) { continue }
  Write-Output "`n$name"
  Get-Content $file -Encoding UTF8 | Where-Object { $_ } | ForEach-Object {
    $e = $_ | ConvertFrom-Json
    $parts = @("$($e.at)".Substring(11, 8))
    if ($e.attempt) { $parts += "attempt $($e.attempt)" }
    $parts += @($e.decision, $e.os, $e.agentName, $e.target, $e.summary) | Where-Object { $_ }
    Write-Output ($parts -join '  ')
  }
}

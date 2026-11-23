# Shared by the PowerShell hooks: the lab root, the event, and the .loop trace.
# Windows PowerShell 5.1 or later.

$Root = Split-Path -Parent $PSScriptRoot
$Loop = Join-Path $Root '.loop'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Windows PowerShell can put a byte order mark in front of the event.
function Read-Event {
  $raw = [Console]::In.ReadToEnd() -replace '^\uFEFF', ''
  try { $raw | ConvertFrom-Json -ErrorAction Stop } catch { $null }
}

function Write-Trace($name, $entry) {
  New-Item -ItemType Directory -Force $Loop | Out-Null
  $ignore = Join-Path $Loop '.gitignore'
  if (-not (Test-Path $ignore)) { [IO.File]::WriteAllText($ignore, "*`n") }
  $line = [ordered]@{ at = (Get-Date).ToUniversalTime().ToString('o') }
  foreach ($key in $entry.Keys) { $line[$key] = $entry[$key] }
  $json = ConvertTo-Json $line -Compress -Depth 5
  [IO.File]::AppendAllText((Join-Path $Loop "$name.jsonl"), "$json`n", $Utf8)
}

function Read-Trace($name) {
  $file = Join-Path $Loop "$name.jsonl"
  if (-not (Test-Path $file)) { return @() }
  @(Get-Content $file -Encoding UTF8 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
}

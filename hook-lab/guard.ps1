# preToolUse: denies file-edit tools on the generated rates table.
# It checks one tool call. A shell command that writes the file is not inspected.

. "$PSScriptRoot\trace.ps1"

$Generated = 'src/main/resources/generated/rates.json'
$EditTools = 'edit', 'create', 'write', 'str_replace', 'str_replace_editor', 'apply_patch'

$hookEvent = Read-Event
$toolArgs = $hookEvent.toolArgs
if ($toolArgs -is [string]) {
  try { $toolArgs = $toolArgs | ConvertFrom-Json -ErrorAction Stop }
  catch { $toolArgs = [pscustomobject]@{ patch = $toolArgs } }
}

# A path field, or the file headers of an apply_patch body ("*** Update File: <path>").
$paths = @()
if ($toolArgs) {
  foreach ($field in $toolArgs.PSObject.Properties) {
    if ($field.Value -isnot [string]) { continue }
    if ($field.Value.Contains("`n")) {
      $paths += [regex]::Matches($field.Value, '(?m)^\*\*\* \w+ File: *(.+?) *\r?$') |
        ForEach-Object { $_.Groups[1].Value }
    } else {
      $paths += $field.Value
    }
  }
}

# Windows sends backslashes and drive letters in any case.
$targets = @($paths | Where-Object {
  $p = $_.Replace('\', '/').ToLower()
  $p -eq $Generated -or $p.EndsWith("/$Generated")
}).Count -gt 0

if ($EditTools -contains $hookEvent.toolName -and $targets) {
  [Console]::Out.Write((ConvertTo-Json -Compress @{
    permissionDecision = 'deny'
    permissionDecisionReason = "$Generated is generated from rates/rates.csv. Edit rates/rates.csv, " +
      'then run powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-rates.ps1.'
  }))
  Write-Trace 'pre-tool-use' ([ordered]@{ decision = 'deny'; toolName = $hookEvent.toolName; target = $Generated })
} else {
  [Console]::Out.Write('{}')
}

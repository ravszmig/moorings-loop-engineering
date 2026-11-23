# sessionStart: tells the agent how to build on this machine, what is generated, and
# which tickets exist. The PowerShell twins run only on Windows, so the commands are
# the Windows ones.

. "$PSScriptRoot\trace.ps1"

$tickets = @(Get-ChildItem (Join-Path $Root 'tickets') -Filter *.md -ErrorAction SilentlyContinue |
  Sort-Object Name | ForEach-Object { "tickets/$($_.Name)" })

$context = @(
  'This machine runs Windows. Commands run in PowerShell. Use exactly these commands.',
  'Java 21 Maven fixture. Maven runs offline.',
  'Build with lint: .\mvnw.cmd -o -q compile (javac -Xlint:all -Werror).',
  'Unit tests: .\mvnw.cmd -o -q test (acceptance tests are excluded).',
  'One acceptance test: .\mvnw.cmd -o -q -Dtest=<TestClass> test.',
  ('src/main/resources/generated/rates.json is generated. Edit rates/rates.csv, then run ' +
    'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-rates.ps1.'),
  $(if ($tickets.Count) { "Tickets: $($tickets -join ' ')." } else { 'No ticket files in tickets/.' })
) -join "`n"

[Console]::Out.Write((ConvertTo-Json @{ additionalContext = $context } -Compress))
Write-Trace 'session-start' ([ordered]@{ decision = 'context'; os = 'Windows'; tickets = $tickets.Count })

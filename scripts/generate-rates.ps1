# Regenerates src/main/resources/generated/rates.json from rates/rates.csv, for Windows
# machines without Node. With -Check it writes nothing and exits 1 if the JSON is stale.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-rates.ps1 [-Check]

param([switch]$Check)

Set-Location (Split-Path -Parent $PSScriptRoot)
cmd /c 'mvnw.cmd -o -q compile'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$mode = if ($Check) { '--check' } else { '' }
cmd /c "java -cp target/classes com.example.stays.rates.RatesGenerator $mode rates/rates.csv src/main/resources/generated/rates.json"
exit $LASTEXITCODE

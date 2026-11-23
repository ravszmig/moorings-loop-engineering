# Run once before the session, with network access, on Windows machines without Node.
# Downloads everything the offline stop hooks need (Maven, JUnit, PIT) and checks the
# starting point.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/warm-up.ps1

Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force target | Out-Null

function Step($name, $command) {
  cmd /c "$command > target\warm-up.log 2>&1"
  if ($LASTEXITCODE -ne 0) {
    Write-Output "Warm-up failed at: $name (see target\warm-up.log)"
    exit $LASTEXITCODE
  }
  Write-Output "ok  $name"
}

Step 'default suite' 'mvnw.cmd -q test'
Step 'PIT on RoomCalendar' ('mvnw.cmd -q test-compile org.pitest:pitest-maven:mutationCoverage ' +
  '-DtargetClasses=com.example.stays.booking.RoomCalendar')
Step 'generated rates' 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\generate-rates.ps1 -Check'
Remove-Item -Recurse -Force .loop, target\pit-reports -ErrorAction SilentlyContinue
Write-Output 'Ready: the default suite passes, PIT and the generator work offline.'

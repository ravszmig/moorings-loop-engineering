// Run once before the session, with network access. Downloads everything the offline
// stop hooks need (Maven, JUnit, PIT) and checks the starting point.
//
//   node scripts/warm-up.mjs

import { spawnSync } from 'node:child_process'
import { mkdirSync, rmSync, writeFileSync } from 'node:fs'

const windows = process.platform === 'win32'
const mvnw = windows ? 'mvnw.cmd' : './mvnw'

const step = (name, command, args) => {
  const r = spawnSync(command, args, { encoding: 'utf8', shell: windows && command === mvnw,
    maxBuffer: 64 * 1024 * 1024 })
  mkdirSync('target', { recursive: true })
  writeFileSync('target/warm-up.log', `${r.stdout ?? ''}${r.stderr ?? ''}`)
  if (r.status !== 0) {
    console.error(`Warm-up failed at: ${name} (see target/warm-up.log)`)
    process.exit(r.status ?? 1)
  }
  console.log(`ok  ${name}`)
}

step('default suite', mvnw, ['-q', 'test'])
step('PIT on RoomCalendar', mvnw, ['-q', 'test-compile', 'org.pitest:pitest-maven:mutationCoverage',
  '-DtargetClasses=com.example.stays.booking.RoomCalendar'])
step('generated rates', process.execPath, ['scripts/generate-rates.mjs', '--check'])
rmSync('.loop', { recursive: true, force: true })
rmSync('target/pit-reports', { recursive: true, force: true })
console.log('Ready: the default suite passes, PIT and the generator work offline.')

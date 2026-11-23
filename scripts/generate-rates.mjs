// Regenerates src/main/resources/generated/rates.json from rates/rates.csv.
// With --check it writes nothing and exits 1 if the committed JSON is stale.
//
//   node scripts/generate-rates.mjs [--check]

import { spawnSync } from 'node:child_process'

const windows = process.platform === 'win32'
const run = (command, args) => spawnSync(command, args, { stdio: 'inherit',
  shell: windows && command === 'mvnw.cmd' }).status ?? 1

const compiled = run(windows ? 'mvnw.cmd' : './mvnw', ['-o', '-q', 'compile'])
if (compiled !== 0) process.exit(compiled)
process.exit(run('java', ['-cp', 'target/classes', 'com.example.stays.rates.RatesGenerator',
  ...process.argv.slice(2), 'rates/rates.csv', 'src/main/resources/generated/rates.json']))

// Checks a stop policy without running Maven.
//
//   node hook-lab/probes.mjs                              your policy
//   node hook-lab/probes.mjs hook-lab/reference/policy.mjs

import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const file = process.argv[2] ?? 'hook-lab/policy.mjs'
const { decide, MAX_BLOCKS } = await import(pathToFileURL(resolve(file)))
const limit = MAX_BLOCKS

const probes = [
  ['every gate passes: allow', 1, { compile: 'PASS', suite: 'PASS' }, 'allow'],
  ['a gate fails on the first stop: block', 1, { compile: 'PASS', suite: 'FAIL' }, 'block'],
  ['a gate errors: ERROR is not a pass, block', 1, { suite: 'ERROR' }, 'block'],
  ['no gates switched on: not a pass, block', 1, {}, 'block'],
  [`still failing on attempt ${limit}: block`, limit, { suite: 'FAIL' }, 'block'],
  [`still failing on attempt ${limit + 1}: allow-after-limit`, limit + 1, { suite: 'FAIL' },
    'allow-after-limit'],
  [`still erroring on attempt ${limit + 1}: allow-after-limit`, limit + 1, { suite: 'ERROR' },
    'allow-after-limit'],
  [`a retry that passes on attempt ${limit + 1}: allow`, limit + 1, { suite: 'PASS' }, 'allow'],
]

let failed = 0
for (const [name, attempt, statusByGate, expected] of probes) {
  let got
  try {
    got = decide(attempt, statusByGate)
  } catch (error) {
    got = `threw "${error.message}"`
  }
  const ok = got === expected
  if (!ok) failed++
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `  (got ${got})`}`)
}
console.log(`\n${probes.length - failed} passed, ${failed} failed (${file}, MAX_BLOCKS ${limit})`)
process.exit(failed ? 1 : 0)

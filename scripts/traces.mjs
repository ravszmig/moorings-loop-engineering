// One line per hook decision, from every trace in .loop/.
//
//   node scripts/traces.mjs

import { existsSync, readFileSync } from 'node:fs'

for (const name of ['session-start', 'pre-tool-use', 'agent-stop', 'subagent-stop']) {
  const file = `.loop/${name}.jsonl`
  if (!existsSync(file)) continue
  console.log(`\n${name}`)
  for (const line of readFileSync(file, 'utf8').split('\n').filter(Boolean)) {
    const e = JSON.parse(line)
    console.log([e.at.slice(11, 19), e.attempt && `attempt ${e.attempt}`, e.decision,
      e.os, e.agentName, e.target, e.summary].filter(Boolean).join('  '))
  }
}

// sessionStart: tells the agent how to build on this machine, what is generated, and
// which tickets exist. The hook knows the operating system, so the agent gets the one
// command that works here instead of guessing between ./mvnw and .\mvnw.cmd.

import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { ROOT, trace } from './trace.mjs'

const windows = process.platform === 'win32'
const os = windows ? 'Windows' : process.platform === 'darwin' ? 'macOS' : 'Linux'
const mvnw = windows ? '.\\mvnw.cmd' : './mvnw'
const shell = windows ? 'PowerShell' : 'a POSIX shell'

const dir = join(ROOT, 'tickets')
const tickets = existsSync(dir)
  ? readdirSync(dir).filter((f) => f.endsWith('.md')).sort().map((f) => `tickets/${f}`)
  : []

const context = [
  `This machine runs ${os}. Commands run in ${shell}. Use exactly these commands.`,
  'Java 21 Maven fixture. Maven runs offline.',
  `Build with lint: ${mvnw} -o -q compile (javac -Xlint:all -Werror).`,
  `Unit tests: ${mvnw} -o -q test (acceptance tests are excluded).`,
  `One acceptance test: ${mvnw} -o -q -Dtest=<TestClass> test.`,
  'src/main/resources/generated/rates.json is generated. Edit rates/rates.csv, ' +
    'then run node scripts/generate-rates.mjs.',
  tickets.length ? `Tickets: ${tickets.join(' ')}.` : 'No ticket files in tickets/.',
].join('\n')

console.log(JSON.stringify({ additionalContext: context }))
trace('session-start', { decision: 'context', os, tickets: tickets.length })

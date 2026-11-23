// agentStop and subagentStop: runs the gates in hook-lab/gates.txt, asks the policy
// what to do, and blocks the agent with the failures when the policy says block.
//
//   node hook-lab/stop.mjs agentStop hook-lab/policy.mjs
//   node hook-lab/stop.mjs subagentStop hook-lab/policy.mjs

import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { ROOT, readEvent, readTrace, trace, writeLog } from './trace.mjs'

const [hook = 'agentStop', policyFile = 'hook-lab/policy.mjs'] = process.argv.slice(2)
const traceName = hook === 'subagentStop' ? 'subagent-stop' : 'agent-stop'
const windows = process.platform === 'win32'
const mvnw = windows ? 'mvnw.cmd' : './mvnw'

// ---- gates

const gateCommands = (line) => {
  const [kind, arg] = line.split(/\s+/)
  if (kind === 'compile') return [kind, mvnw, ['-o', '-q', 'compile']]
  if (kind === 'suite') return [kind, mvnw, ['-o', '-q', 'test']]
  if (kind === 'acceptance') return [arg, mvnw, ['-o', '-q', `-Dtest=${arg}`, 'test']]
  if (kind === 'mutation') {
    return [`mutation ${arg.split('.').pop()}`, mvnw, ['-o', '-q', 'test-compile',
      'org.pitest:pitest-maven:mutationCoverage', `-DtargetClasses=${arg}`]]
  }
  if (kind === 'generated') {
    return [kind, process.execPath, ['scripts/generate-rates.mjs', '--check']]
  }
  return [line, null, []]
}

const gates = () => readFileSync(join(ROOT, 'hook-lab/gates.txt'), 'utf8').split('\n')
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#')).map(gateCommands)

const run = ([name, command, args]) => {
  if (!command) return { name, status: 'ERROR', detail: `unknown gate in gates.txt: ${name}` }
  if (command === mvnw && !existsSync(join(ROOT, mvnw))) {
    return { name, status: 'ERROR', detail: `missing Maven wrapper: ${mvnw}` }
  }
  // Windows only runs a .cmd file through a shell. node.exe must not go through one,
  // because its path usually contains a space.
  const r = spawnSync(command, args, { cwd: ROOT, encoding: 'utf8',
    shell: windows && command === mvnw, maxBuffer: 64 * 1024 * 1024 })
  // Maven on Windows draws a spinner with backspaces. Drop each drawn character with its backspace.
  const output = `${r.stdout ?? ''}${r.stderr ?? ''}`.replaceAll(ROOT, '.').replace(/[^\n]?\x08/g, '')
  writeLog(name, output)
  if (r.status !== 0) return { name, status: 'FAIL', detail: excerpt(output) }
  return name.startsWith('mutation ') ? mutants(name) : { name, status: 'PASS' }
}

// The assertion, compiler error or test summary lines, without the stack trace.
const excerpt = (output) => {
  const lines = output.split(/\r?\n/).map((l) => l.trim()).filter((l) =>
    l && !/^at |^\[ERROR\] *(->|$|re-run|to see|for more|\[help|after)/i.test(l))
  const keep = lines.filter((l) => /tests run:|expected|but was|error:|warning:|\.java:\[?\d/i
    .test(l))
  return [...new Set(keep.length ? keep : lines.slice(-10))].slice(0, 15).join('\n')
}

// PIT exits 0 whatever survives, so read its report: file,class,mutator,method,line,status.
const MUTATORS = {
  NegateConditionalsMutator: 'condition inverted',
  ConditionalsBoundaryMutator: 'boundary changed (< to <=)',
  MathMutator: 'arithmetic operator swapped',
  PrimitiveReturnsMutator: 'returns 0 instead',
  BooleanTrueReturnValsMutator: 'returns true instead',
  BooleanFalseReturnValsMutator: 'returns false instead',
  NullReturnValsMutator: 'returns null instead',
  EmptyObjectReturnValsMutator: 'returns an empty value instead',
  VoidMethodCallMutator: 'a call removed',
  IncrementsMutator: 'increment changed',
}

const mutants = (name) => {
  const csv = join(ROOT, 'target/pit-reports/mutations.csv')
  if (!existsSync(csv)) return { name, status: 'ERROR', detail: 'PIT wrote no report' }
  const rows = readFileSync(csv, 'utf8').split('\n').filter(Boolean).map((l) => l.split(','))
  const missed = rows.filter((f) => f[5] !== 'KILLED' && f[5] !== 'TIMED_OUT').map((f) => {
    const mutator = f[2].split('.').pop()
    const why = f[5] === 'NO_COVERAGE' ? 'no unit test runs this line'
      : 'unit tests run this line but still pass with the bug'
    return `${f[0]}:${f[4]} in ${f[3]}(): ${MUTATORS[mutator] ?? mutator}. ${why}`
  })
  if (!missed.length) return { name, status: 'PASS' }
  return { name, status: 'FAIL', detail: `${missed.length} of ${rows.length} mutants were ` +
    'not caught by the unit tests. Add unit tests that would fail if these changes were ' +
    `made:\n${missed.join('\n')}` }
}

// ---- the stop

const event = readEvent()
if (!event || typeof event !== 'object') {
  trace(traceName, { decision: 'malformed-event', verified: false })
  console.log('{}')
  process.exit(0)
}

// agentStop also fires when a sub-agent ends. The subagentStop hook judges sub-agents.
const agentId = event.agentId || undefined
if (hook === 'agentStop' && agentId) {
  console.log('{}')
  process.exit(0)
}

// Copilot only says whether this stop follows a block, so the count comes from the trace.
const previous = readTrace(traceName).filter((e) => e.agentId === agentId).at(-1)
const attempt = event.stop_hook_active ? (previous?.attempt ?? 1) + 1 : 1
const base = { attempt, agentId, agentName: event.agentName, policy: policyFile }

let policy
try {
  policy = await import(pathToFileURL(resolve(ROOT, policyFile)))
} catch (error) {
  trace(traceName, { ...base, decision: 'policy-error', verified: false, error: error.message })
  console.error(`${hook}: policy not loaded, ends unverified: ${error.message}`)
  console.log('{}')
  process.exit(0)
}

const results = gates().map(run)
const statusByGate = Object.fromEntries(results.map((r) => [r.name, r.status]))
const summary = results.map((r) => `${r.name} ${r.status}`).join(', ') || 'no gates switched on'
const verified = results.length > 0 && results.every((r) => r.status === 'PASS')

let decision
try {
  decision = policy.decide(attempt, statusByGate)
} catch (error) {
  decision = `threw: ${error.message}`
}
const known = ['block', 'allow', 'allow-after-limit'].includes(decision)

trace(traceName, { ...base, decision: known ? decision : 'policy-error', verified, summary,
  results, ...(known ? {} : { error: `decide returned ${decision}` }) })
console.error(`${hook}: ${known ? decision : `policy error (${decision})`}, attempt ${attempt}, ` +
  `${verified ? 'verified' : 'unverified'}: ${summary}`)

if (decision === 'block') {
  const failures = results.filter((r) => r.status !== 'PASS')
    .map((r) => `${r.name} ${r.status}:\n${r.detail}`).join('\n\n')
  const reason = `Stop hook, attempt ${attempt}: gates did not pass (${summary}). ` +
    `Fix what is reported below, then finish again.\n\n${failures}`
  console.log(JSON.stringify({ decision: 'block', reason: reason.slice(0, 4000) }))
} else {
  console.log('{}')
}

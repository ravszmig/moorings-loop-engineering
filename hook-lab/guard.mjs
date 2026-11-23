// preToolUse: denies file-edit tools on the generated rates table.
// It checks one tool call. A shell command that writes the file is not inspected.

import { readEvent, trace } from './trace.mjs'

const GENERATED = 'src/main/resources/generated/rates.json'
const EDIT_TOOLS = ['edit', 'create', 'write', 'str_replace', 'str_replace_editor', 'apply_patch']

const event = readEvent() ?? {}
let args = event.toolArgs ?? {}
if (typeof args === 'string') {
  try {
    args = JSON.parse(args)
  } catch {
    args = { patch: args }
  }
}

// A path field, or the file headers of an apply_patch body ("*** Update File: <path>").
const paths = Object.values(args).filter((v) => typeof v === 'string').flatMap((v) =>
  v.includes('\n') ? [...v.matchAll(/^\*\*\* \w+ File: *(.+?) *$/gm)].map((m) => m[1]) : [v])

// Windows sends backslashes and drive letters in any case.
const targets = paths.map((p) => p.replaceAll('\\', '/').toLowerCase())
  .some((p) => p === GENERATED || p.endsWith(`/${GENERATED}`))

if (EDIT_TOOLS.includes(event.toolName) && targets) {
  console.log(JSON.stringify({
    permissionDecision: 'deny',
    permissionDecisionReason: `${GENERATED} is generated from rates/rates.csv. ` +
      'Edit rates/rates.csv, then run node scripts/generate-rates.mjs.',
  }))
  trace('pre-tool-use', { decision: 'deny', toolName: event.toolName, target: GENERATED })
} else {
  console.log('{}')
}

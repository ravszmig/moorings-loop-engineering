// Your stop decision. stop.mjs runs the gates in hook-lab/gates.txt, then calls
// decide() every time the agent tries to finish.
//
// attempt        1 on the first stop, 2 after one block, 3 after two, and so on.
// statusByGate   gate name to result, for example { compile: 'PASS', suite: 'FAIL' }.
//                ERROR means the gate could not run (no Maven wrapper, unknown gate).
//
// Return one of:
//   'block'              send the failures back; the agent keeps working
//   'allow'              let the agent finish; only when every gate passed
//   'allow-after-limit'  let the agent finish with gates still failing
//
// Rules: block at most MAX_BLOCKS times. ERROR is not a pass. No gates is not a pass.
// Check yourself with: node hook-lab/probes.mjs

export const MAX_BLOCKS = 1

export const decide = (attempt, statusByGate) => {
  throw new Error('decide is not written yet')
}

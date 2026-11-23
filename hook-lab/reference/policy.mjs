// Reference stop decision. Same contract as hook-lab/policy.mjs.

export const MAX_BLOCKS = 3

export const decide = (attempt, statusByGate) => {
  const statuses = Object.values(statusByGate)
  const allPassed = statuses.length > 0 && statuses.every((s) => s === 'PASS')
  if (allPassed) return 'allow'
  return attempt <= MAX_BLOCKS ? 'block' : 'allow-after-limit'
}

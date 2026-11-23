# Hook lab

Four Copilot CLI command hooks, registered in `../.github/hooks/lab.json`, all switched
off by an `off:` prefix on the key. Copilot ignores keys it does not know, without an
error, so removing the prefix switches a hook on. Restart Copilot after editing
`lab.json`: it is read at session start.

Every hook is a small Node.js ES module. Each entry uses the `command` field, which
Copilot runs in bash on macOS and Linux and in PowerShell on Windows, so one line
serves every OS.

| Hook | Command | Does |
|---|---|---|
| `sessionStart` | `node hook-lab/session-start.mjs` | Detects the OS and adds only that OS's Maven commands, the generated-file rule and the ticket files |
| `preToolUse` | `node hook-lab/guard.mjs` | Denies file-edit tools on `src/main/resources/generated/rates.json`, Windows paths included, and names the CSV and generator |
| `agentStop` | `node hook-lab/stop.mjs agentStop hook-lab/policy.mjs` | Runs the gates when the main agent tries to finish. Skips sub-agents |
| `subagentStop` | `node hook-lab/stop.mjs subagentStop hook-lab/policy.mjs` | Runs the gates when a sub-agent tries to hand back |

`trace.mjs` holds what they share: reading the event, writing traces and gate logs.

## The stop hooks

On every stop, `stop.mjs`:

1. Reads the event from stdin.
2. Works out the attempt: 1 when `stop_hook_active` is false, otherwise the last
   traced attempt plus 1 (per sub-agent for `subagentStop`). Copilot does not count.
3. Imports the policy.
4. Runs every line of `gates.txt` that is not commented out, in order, offline.
5. Calls `decide(attempt, statusByGate)`.
6. Replies `{}` (allow) or `{"decision":"block","reason":…}`, and appends one trace line.

`gates.txt` and `policy.mjs` are read on every stop. No restart needed.

| Gate line | Runs | FAIL when |
|---|---|---|
| `compile` | `mvnw -o -q compile` | javac with `-Xlint:all -Werror` fails |
| `suite` | `mvnw -o -q test` | a unit test fails. Excludes `*AcceptanceTest` |
| `acceptance <Test>` | `mvnw -o -q -Dtest=<Test> test` | that acceptance test fails |
| `mutation <class>` | PIT on that class, unit tests only | any mutant is not killed. The reason lists file, line and what to test |
| `generated` | `node scripts/generate-rates.mjs --check` | the JSON does not match the CSV |

`mvnw` is `./mvnw` on macOS and Linux and `mvnw.cmd` on Windows. Windows runs a `.cmd`
file only through a shell, so `stop.mjs` starts `mvnw.cmd` through one. It starts
`node.exe` without a shell, because its path usually contains a space.

Each gate is `PASS`, `FAIL` or `ERROR`. FAIL carries an excerpt of the output: the
assertion, compiler error or test summary. A Maven failure, offline or not, is a FAIL.
The full output is in `.loop/logs/<gate>.log`. ERROR means the gate could not run: no
Maven wrapper, or an unknown gate line.

Copilot's `timeoutSec` (360 for the stops) is the only time limit. A hook that times
out lets the turn end, unverified and with no trace line.

### The policy

`policy.mjs` exports `MAX_BLOCKS` (1 at the start) and `decide(attempt,
statusByGate)`. `statusByGate` is a plain object such as
`{ compile: 'PASS', suite: 'FAIL' }`. `decide` returns `'block'`, `'allow'` or
`'allow-after-limit'`. The starter throws. The header is the contract. A correct
policy allows only when the object is non-empty and every value is PASS, blocks while
`attempt <= MAX_BLOCKS`, and returns `allow-after-limit` after that.
`reference/policy.mjs` is one with `MAX_BLOCKS = 3`. To use it, point the stop
commands in `lab.json` at it.

`verified` in the trace is set by `stop.mjs`, not the policy: `true` only when every
gate passed. A policy that fails to import, throws, or returns another value is
`policy-error`, with the message in `error`. The hook replies `{}` and the turn ends
unverified. An import error stops the hook before any gate runs. A throwing `decide()`
is found after the gates ran.

## Probes

```sh
node hook-lab/probes.mjs                               # your policy
node hook-lab/probes.mjs hook-lab/reference/policy.mjs # the reference
```

Eight cases passed straight to `decide()`. No Maven, no hook events. The probes read
`MAX_BLOCKS` from the policy and walk the attempts up to the limit and one past it.
The starter prints `0 passed, 8 failed (hook-lab/policy.mjs, MAX_BLOCKS 1)`. The
reference prints `8 passed, 0 failed (hook-lab/reference/policy.mjs, MAX_BLOCKS 3)`.

The probes test the policy only. They do not show that Copilot fired the hook. The
traces do.

## Traces

`.loop/` in the lab folder, git-ignored by its own `.gitignore`. No prompt text is
stored. `node scripts/traces.mjs` prints them all, one line per decision.

| File | One line per |
|---|---|
| `session-start.jsonl` | session start |
| `pre-tool-use.jsonl` | denied edit, with tool and target |
| `agent-stop.jsonl` | main-agent stop: `attempt`, `decision`, `verified`, `summary`, per-gate `results` |
| `subagent-stop.jsonl` | sub-agent stop, plus `agentId` and `agentName` |
| `logs/<gate>.log` | full Maven output of each gate's last run |

## Requirements

- **Node.js 22 or later** on `PATH`, for the hooks and scripts.
- **JDK 21** on `PATH`. Maven builds with it, and the rates generator runs `java`.
- Nothing else. No jq, no POSIX shell.
- `node scripts/warm-up.mjs` once with network, so `~/.m2` holds Maven, JUnit and PIT.
- Windows PowerShell can put a byte order mark before the event. `trace.mjs` strips it.
- `.gitattributes` keeps text files LF on Windows. `GeneratedRatesTest` compares the JSON
  byte for byte, so a CRLF checkout would report it stale.

## Windows without Node

Every Node program has a Windows PowerShell 5.1 twin with the same behaviour, the same
probes and the same trace format. Use them only on a Windows machine that cannot
install Node.

| Node | PowerShell |
|---|---|
| `.github/hooks/lab.json` | `hook-lab/lab.powershell.json`, copied over `lab.json` |
| `hook-lab/policy.mjs` | `hook-lab/policy.ps1`, the participant writes `decide` here |
| `hook-lab/probes.mjs` | `hook-lab/probes.ps1` |
| `hook-lab/stop.mjs`, `guard.mjs`, `session-start.mjs`, `trace.mjs` | `stop.ps1`, `guard.ps1`, `session-start.ps1`, `trace.ps1` |
| `scripts/warm-up.mjs`, `generate-rates.mjs`, `traces.mjs` | `warm-up.ps1`, `generate-rates.ps1`, `traces.ps1` |

Switch over once, in PowerShell from the lab folder:

```powershell
Copy-Item hook-lab/lab.powershell.json .github/hooks/lab.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/warm-up.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File hook-lab/probes.ps1
```

Every command passes `-ExecutionPolicy Bypass`, because Windows blocks unsigned scripts
by default. The policy file is the same exercise in PowerShell:

```powershell
$MAX_BLOCKS = 1
function decide($attempt, $statusByGate) { ... }   # returns 'block', 'allow' or 'allow-after-limit'
```

`$statusByGate` is an ordered dictionary, so `$statusByGate.Values` lists the statuses.
`hook-lab/reference/policy.ps1` is the answer.

Three things still name Node:

- `tickets/M-103.md` names `node scripts/generate-rates.mjs`. Change both lines to
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-rates.ps1`
  (add `-Check` for the second).
- The stale message from the generator and `GeneratedRatesTest` names the Node command.
  The guard's deny reason names the PowerShell one.
- Approve `shell(powershell)` instead of `shell(node)`.

## Verified behaviour, 2026-11-23

Copilot CLI 1.0.112 on macOS, JDK 21.0.9, with the earlier Java hook programs:

- An `off:`-prefixed key does not run and raises no error.
- `subagentStop` fires when a task sub-agent finishes. A block sends the sub-agent back.
- `agentStop` also fires for a sub-agent, with `agentId` set. `stop.mjs` skips those.
- Consecutive blocks are honoured. `stop_hook_active` stays `true` after the first.
- `copilot -p` skips repository hooks in an untrusted folder. `--trust-folder` fixes it.
- PIT exits 0 whatever survives, so `stop.mjs` reads `target/pit-reports/mutations.csv`.

The full lesson dry run is in the [facilitator guide](../FACILITATOR-GUIDE.md#evidence).

On Windows, `.github/workflows/lab-on-every-os.yml` runs the probes and the real hook
programs from PowerShell 7 and 5.1, and the PowerShell twins from 5.1, when this folder
is a repository root. That covers the handlers, not Copilot calling them.

On a Windows laptop with PowerShell 5.1, all three tickets ran with every hook started
by `powershell.exe` the way Copilot starts it, while Copilot itself ran on a Mac. M-101
and the guard ran the same way with the PowerShell twins. See
the [facilitator guide](../FACILITATOR-GUIDE.md#evidence).

> **TODO.** Copilot itself has not run on Windows with these hooks. One M-101 run on a
> Windows laptop with Copilot signed in closes this.

## Limits

- `preToolUse` sees file-edit tools only. A shell redirect writes the file. The
  `generated` gate catches that at the end.
- A policy that returns `allow` with failing gates is obeyed. The trace says
  `verified: false`.
- CI stays the merge gate.

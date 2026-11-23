# Loop engineering: 90-minute 1:1

One repository, three tickets, four hooks. Everything starts switched off. You switch
the hooks and gates on one at a time, and every change stays in place for the next
ticket. Nothing is reverted, copied or committed during the session.

Moorings is a synthetic Java 21 booking and pricing library. Nobody brings a ticket.

**What the participant leaves with:** a stop hook decides when the agent may finish.
It runs real checks, sends failures back, and gives up after a fixed number of tries.

## At a glance

| Min | Step | What the room sees |
|---|---|---|
| 0–8 | [Tour](#08-tour-everything-switched-off) | `lab.json` with every hook `off:`, `gates.txt`, three tickets |
| 8–16 | [M-101, no hooks](#816-m-101-with-no-hooks) | Agent reads, summarises, finishes. Bug stays. Acceptance test red in IntelliJ |
| 16–32 | [Write the stop policy](#1632-write-the-stop-policy) | Naive version fails 4 of 8 probes. Fixed version passes all 8 |
| 32–42 | [M-101, agentStop on](#3242-m-101-with-agentstop-on) | Block on attempt 1, one-line fix, allow on attempt 2 |
| 42–57 | [M-102, mutation gate](#4257-m-102-a-gate-that-asks-for-tests) | Feature works, gate still blocks: no unit test covers it. Agent adds tests |
| 57–80 | [M-103, all four hooks](#5780-m-103-all-four-hooks-and-a-sub-agent) | Guard denies an edit. Version A: the gate finds the M-101 conflict and both limits stop. Version B: a person amends the ticket, all gates pass |
| 80–90 | [Close](#8090-close) | Traces side by side. What a gate proves and what it does not |

Timings come from dry runs on 2026-11-23 (see [Evidence](#evidence)). Agent turns took
12 s to 2 min 13 s on a Mac. On Windows a stop takes about twice as long. The rest is
talk.

Each step below follows the same order: **Do** (the edits and the prompt), **Say**
(what to tell the participant before or while the agent runs), **Expected** (what the
dry run did), **Show** (the evidence afterwards) and **Talking points** (the lesson of
the step). **Ask** marks a question for the participant. Let them answer before you
go on.

## Before the session

Do this the day before, and again on the morning.

1. **Clone the `loop-lab` branch** in any terminal:

   ```sh
   git clone --branch loop-lab --single-branch --depth 1 https://github.com/DigitalInnovation/enablement-program-knowledge.git moorings
   ```

   Then in IntelliJ: File, Open, and pick
   `moorings/forge/demos/demo-fixtures/loop-engineering-java`. Open that folder, not
   `moorings`: Copilot finds the hooks in `.github/hooks/` of the folder it starts in.
   Let IntelliJ import Maven. Every command below runs from that folder.
2. **Project SDK is JDK 21.** File, Project Structure, SDK: pick a JDK 21, such as
   `temurin-21`. In rehearsal, with no project SDK set, the gutter arrow ran the tests
   on JDK 25.
3. **Terminal sees JDK 21 and Node.js 22 or later.** Open the IntelliJ terminal
   (Alt+F12). It is PowerShell on Windows and zsh or bash on macOS and Linux. Every
   `node` command in this guide is the same in all of them. Maven is `./mvnw` on macOS
   and Linux and `.\mvnw.cmd` on Windows.

   ```sh
   java -version
   node --version
   ```

   If `java` is not 21, put JDK 21 first on `PATH` (Windows: System Properties,
   Environment Variables, then restart IntelliJ). If `node` is missing, install it:
   `winget install OpenJS.NodeJS.LTS` on Windows, `brew install node` on macOS, then
   restart IntelliJ. The hooks run `node` from the terminal Copilot starts in. The
   gates run Maven, and the rates generator runs `java`, so both must be on `PATH`.

   A Windows machine that cannot install Node uses the PowerShell twins: see
   [Windows without Node](hook-lab/README.md#windows-without-node). Switch over
   before the warm-up, and edit the two generator lines in `tickets/M-103.md`. Every
   `node` command in this guide then becomes
   `powershell -NoProfile -ExecutionPolicy Bypass -File` with the `.ps1` of the same
   name, and the participant writes `policy.ps1`.
4. **Warm up, online.** Downloads Maven, JUnit and PIT so every gate runs offline:

   ```sh
   node scripts/warm-up.mjs
   ```

   About 4 s on a warm Mac, 20 s on Windows. Expect three `ok` lines, then the ready line:

   ```
   ok  default suite
   ok  PIT on RoomCalendar
   ok  generated rates
   Ready: the default suite passes, PIT and the generator work offline.
   ```
5. **Rehearse one M-101 run** on the model the participant uses (step at 32 min), then
   reset (below). Models change. A rehearsal from last week proves nothing today.
6. **Lay out IntelliJ:** project tree left, editor centre, terminal bottom, Commit tool
   window (Cmd+0) for Local Changes.

### Reset between participants

- Git, Rollback, select all files, Rollback. This restores `lab.json`, `gates.txt`,
  `policy.mjs`, `tickets/M-103.md`, the source and the tests.
- Delete the `.loop` folder in the project tree. It is git-ignored, so Rollback keeps it.

Or delete the `moorings` folder and clone again.

## How the lab works

Read this once. It is the explanation for every "why does that happen" question.

```
Copilot CLI ── reads .github/hooks/lab.json at session start
   │
   ├─ sessionStart ─► session-start.mjs ─► extra context: this OS's commands, the rules
   ├─ preToolUse ───► guard.mjs ─────────► deny edits to generated/rates.json
   ├─ agentStop ────► stop.mjs agentStop + policy.mjs ────┐
   └─ subagentStop ─► stop.mjs subagentStop + policy.mjs ─┤
                                                          ▼
                          run every gate in hook-lab/gates.txt (Maven, offline)
                          ask decide(attempt, statusByGate) in policy.mjs
                          block ─► reason goes back to the agent, it keeps working
                          allow ─► the agent finishes
                          every decision ─► one line in .loop/*.jsonl
```

| Piece | File | Who wrote it | When it is read |
|---|---|---|---|
| Hook registration | `.github/hooks/lab.json` | Provided | Copilot session start. **Restart Copilot after editing** |
| Gate list | `hook-lab/gates.txt` | Provided, participant switches lines on | Every stop. No restart |
| Stop policy | `hook-lab/policy.mjs` | **Participant** | Every stop, loaded fresh. No restart |
| Hook programs | `hook-lab/stop.mjs`, `guard.mjs`, `session-start.mjs`, `trace.mjs` | Provided | Every hook call |
| Probes | `hook-lab/probes.mjs` | Provided | When you run it |
| Traces | `.loop/*.jsonl` | Written by the hooks | Open in IntelliJ, or `node scripts/traces.mjs` |

**One command on every OS.** Each hook in `lab.json` uses the `command` field, which
Copilot runs in bash on macOS and Linux and in PowerShell on Windows
([hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)).
`node hook-lab/stop.mjs …` means the same thing in both. The hooks are small Node.js
modules because Node runs the same command on Windows, macOS and Linux, and each file
is short enough to read in the session.

**On and off.** A hook is off when its key starts with `off:`. Copilot ignores keys it
does not know, without an error. Removing `off:` switches the hook on. JSON has no
comments, so this is the simplest switch.

**The attempt counter.** Copilot sends `stop_hook_active: false` on the first stop of a
turn and `true` on every stop after a block. It does not count. `stop.mjs` counts from
its own trace: attempt 1 on a fresh stop, last attempt plus 1 otherwise.

**The three decisions.** `block` sends the reason back. `allow` ends the turn with every
gate passing, and the trace says `verified: true`. `allow-after-limit` ends the turn
with gates still failing, `verified: false`. `stop.mjs` sets `verified`, not the
policy, so a lying policy cannot fake a pass.

**PASS, FAIL, ERROR.** FAIL means the check ran and found a problem. ERROR means the
check could not run: no Maven wrapper, or an unknown line in `gates.txt`. An ERROR is
not a pass. Maven offline without an artifact is a FAIL, and the full output is in
`.loop/logs/<gate>.log`.

## 0–8: Tour, everything switched off

**Ask.** "How do you know today that an agent's work is done?" Most answers are "I
read it" or "I run the tests myself". Keep the answer: the close comes back to it.

**Do.** Open these in IntelliJ, in this order. **Say** the quoted line for each.

1. `tickets/M-101.md`. "30 May to 2 June should cost 7,800p. The code charges every
   night at the arrival month's rate, so it charges 7,200p."
2. `src/main/java/com/example/stays/pricing/StayPricer.java`. Point at
   `rates.rateFor(arrival.getMonth())` inside the loop. That is the bug.
3. `.github/hooks/lab.json`. "Four hooks. Every key starts with `off:`. Copilot ignores
   all of them right now."
4. `hook-lab/gates.txt`. "The checks a stop hook will run. Three are on: compile with
   warnings as errors, the unit suite, and M-101's acceptance test. The rest wait for
   their ticket."
5. `hook-lab/policy.mjs`. "Empty. You write this one. It decides what happens when a
   check fails."

**Talking point.** An agent finishes when the model decides it is done. Nothing checks
that decision. Today we add the check.

## 8–16: M-101 with no hooks

**Do.** In the IntelliJ terminal:

```sh
copilot
```

Trust the folder for this session if asked. Paste:

> Read only `src/main/java/com/example/stays/pricing/StayPricer.java` and summarize
> the existing M-101 change. Do not run tools other than reading that file or edit
> anything on the first attempt. Only if the stop hook reports failing acceptance
> checks, edit only `StayPricer.java` to correct the pricing, changing no tests or
> rates, and finish again without running commands yourself.

**Expected (dry run, 12 s):** one file read, a summary that names the arrival-month
lookup, "No acceptance-check failure was reported, so I made no edits." Turn ends.

**Say, before pasting.** "This prompt is rigged. It tells the agent to stop early,
the way an agent does when it thinks it is done. Watch what happens with nothing
checking it."

**Why the prompt is this strict.** It makes the first attempt fail on purpose, every
time. Without it, a good model fixes M-101 on the first try and there is nothing to
show. The prompt plays the agent that stops too early. The hook is what we are
testing, not the model.

**Show.** Exit Copilot (`/exit`). In IntelliJ open
`src/test/java/com/example/stays/pricing/ShoulderSeasonAcceptanceTest.java` and click
the green gutter arrow on the class. Two failures:
`expected: <7800> but was: <7200>` and `expected: <5400> but was: <6000>`.

**Talking point.** The agent did what it was told, reported success, and shipped a
known bug. Every agent session ends like this unless something checks.

## 16–32: Write the stop policy

**Do.** Open `hook-lab/policy.mjs`. Read the header comment with the participant. It
is the contract: inputs, three return values, three rules. `statusByGate` is a plain
object, for example `{ compile: 'PASS', suite: 'FAIL' }`.

Run the probes against the empty starter:

```sh
node hook-lab/probes.mjs
```

Expect `0 passed, 8 failed (hook-lab/policy.mjs, MAX_BLOCKS 1)`. The starter throws.

**Say.** "The probes are the tests for the hook. We write the decision before any agent
runs, and check it in under a second, without Maven."

**What the probes are.** A Node program that imports the policy and calls `decide()`
with eight cases. No Maven, no hook events, under a second. The probes read
`MAX_BLOCKS` from the policy and test the attempts up to the limit and one past it.
The rules in the probe names come from the policy header. We wrote both.

### First version: the obvious one

**Ask**, before they write: "What should happen when a check could not run at all?"
and "What should happen on the fourth try?" Then ask them to write it. If they need a
nudge, this is the version most people
write first:

```js
if (attempt <= MAX_BLOCKS && Object.values(statusByGate).includes('FAIL')) return 'block'
return 'allow'
```

Run the probes again. Expect `4 passed, 4 failed`:

| Failing probe | What it found |
|---|---|
| a gate errors: ERROR is not a pass, block | The gate could not run. Nothing said FAIL, so it allowed |
| no gates switched on: not a pass, block | An empty object has no FAIL in it, so it allowed |
| still failing on attempt 2: allow-after-limit | Over the limit it says `allow`, which claims every gate passed |
| still erroring on attempt 2: allow-after-limit | Same, with a gate that could not run |

**Talking point.** "Block on failure" is the wrong question. The right one is "allow
only on positive evidence that everything passed". The first two holes are cases where
nothing reported a failure because nothing ran.

### Second version: positive evidence

```js
const statuses = Object.values(statusByGate)
const allPassed = statuses.length > 0 && statuses.every((s) => s === 'PASS')
if (allPassed) return 'allow'
return attempt <= MAX_BLOCKS ? 'block' : 'allow-after-limit'
```

Probes: `8 passed, 0 failed`. Leave `MAX_BLOCKS = 1` for now.

**Talking points.**

- `allow-after-limit` exists so the agent can stop without claiming success. The
  trace says `verified: false`, and a person looks.
- `MAX_BLOCKS = 1` keeps M-101 short: one block, one fix.

If time is short, show `hook-lab/reference/policy.mjs`. It is the same code with
`MAX_BLOCKS = 3`. To run the session on it, point the stop commands in `lab.json` at
`hook-lab/reference/policy.mjs`.

## 32–42: M-101 with agentStop on

**Do.** In `lab.json` change `"off:agentStop"` to `"agentStop"`. Save. Start Copilot
again (the registration is read at start) and paste the **same prompt**.

**Say, while the hook runs** (about 4 s on a Mac, 15 s on Windows). "The agent has
finished as far as it knows. Copilot is waiting for the hook. The hook is running
Maven: compile, the unit suite, the acceptance test." Open `.loop/logs/` in the project
tree: a log appears per check.

**Say, when the block appears.** Read the reason out loud. "This text is all the agent
gets. Nobody typed it. The hook wrote it from the test output."

**Expected (dry run, 22 s):**

1. Agent reads the file and summarises. Tries to finish.
2. The stop hook runs three gates (about 4 s). Acceptance FAILs. Block.
3. The agent receives the reason, a short text that starts
   `Stop hook, attempt 1: gates did not pass (compile PASS, suite PASS,
   ShoulderSeasonAcceptanceTest FAIL)` and quotes `expected: <7800> but was: <7200>`.
4. Agent edits one line in `StayPricer.java`: the rate lookup uses the night's month.
5. Tries to finish. All gates PASS. Allow.

**Show.** Exit Copilot and show the evidence:

- Commit tool window: one changed source file, `StayPricer.java`, one line.
- Gutter arrow on `ShoulderSeasonAcceptanceTest`: green.
- Traces:

  ```sh
  node scripts/traces.mjs
  ```

  ```
  agent-stop
  00:54:44  attempt 1  block  compile PASS, suite PASS, ShoulderSeasonAcceptanceTest FAIL
  00:54:52  attempt 2  allow  compile PASS, suite PASS, ShoulderSeasonAcceptanceTest PASS
  ```

**Talking points.**

- Same prompt, same model, different outcome. The only change was one hook.
- The agent never ran a test. The hook ran them. The agent cannot skip them, change
  their command, or claim they passed.
- The reason text is the interface. It names the failing gate and quotes the assertion,
  so the agent knows what to fix without searching.

## 42–57: M-102, a gate that asks for tests

**Do.** Open `tickets/M-102.md`: reject overlapping bookings.

**Ask.** "Say the agent implements this and the acceptance test passes. What else would
you want before you merge it?" Steer towards: a unit test that fails if somebody breaks
it later.

Make two edits. Leave everything from M-101 in place.

1. `gates.txt`: remove the `# ` from both M-102 lines (the acceptance test and
   `mutation com.example.stays.booking.RoomCalendar`).
2. `policy.mjs`: `export const MAX_BLOCKS = 3`. A harder gate gets more tries.

No restart needed: both files are read on every stop. Restart anyway if you prefer a
clean screen.

**Say.** "Two new checks. The acceptance test is the ticket. The mutation check asks
whether the unit tests would notice if this code broke." Then paste:

> Implement tickets/M-102.md. Change only
> src/main/java/com/example/stays/booking/RoomCalendar.java. Do not add or change
> tests and do not run commands. If a stop hook reports a failing check, fix what it
> reports, then finish again.

**Expected (dry run, 54 s):**

1. Agent reads the ticket and the acceptance test, adds a 7-line overlap check.
2. Stop: compile, suite and both acceptance tests PASS. **Mutation FAIL.** Block.
3. Reason:

   ```
   2 of 15 mutants were not caught by the unit tests. Add unit tests that would fail
   if these changes were made:
   RoomCalendar.java:24 in book(): returns null instead. no unit test runs this line
   RoomCalendar.java:22 in lambda$book$0(): condition inverted. no unit test runs this line
   ```

4. Agent adds one or two tests to `RoomCalendarTest`.
5. Stop: all five gates PASS. Allow.

The mutant count and the number of tests vary with the model's code. The block does
not: no unit test covers the new branch until the agent writes one.

**Say, when the block appears.** Read one mutant line out loud: "condition inverted, no
unit test runs this line". "That is a bug PIT made on purpose. Nothing caught it."

**Show.** Exit Copilot. Commit tool window: `RoomCalendar.java` and the new unit test.
Then `node scripts/traces.mjs`: under `agent-stop`, the two M-101 lines and two new
ones, a block with `mutation RoomCalendar FAIL` and an allow.

**What the mutation gate does.** PIT makes small changes to `RoomCalendar`, one at a
time: flips a condition, returns null. For each change it runs the unit tests. If no
test fails, nothing would notice that bug. The acceptance test is excluded on purpose:
it is the ticket's check, not the team's regression suite. About 2 s.

**Talking points.**

- The feature worked on the first try. The gate still blocked, because nothing would
  catch it breaking later.
- The prompt said "do not add tests". The hook overrode it with evidence. The rule
  lives in `gates.txt`, not in a prompt someone forgets to paste.
- `MAX_BLOCKS` is the loop budget. Three tries, then the turn ends unverified and a
  person looks. An unbounded loop costs money and never says why it gave up.

## 57–80: M-103, all four hooks and a sub-agent

**Do.** Open `tickets/M-103.md`: shoulder rate 2,400p to 2,500p, regenerate the JSON.
It names `StayPricerTest` and `RateTableTest`. It does not mention M-101's acceptance
test, which assumes 2,400p.

**Ask.** "What happens to M-101's acceptance test when the rate changes?" Do not answer
it. Version A will.

Switch everything on:

1. `lab.json`: remove `off:` from `sessionStart`, `preToolUse` and `subagentStop`.
2. `gates.txt`: remove `# ` from `generated`.

Restart Copilot (the registration changed).

**Say.** "Four hooks now. Three new ones, each at a different moment: when the session
starts, before every tool call, and when a sub-agent hands back."

### sessionStart, 2 minutes

**Do.** Open `hook-lab/session-start.mjs`. Then paste:

> Without running or reading anything, reply with only the exact command to run the
> unit tests on this machine.

**Expected (dry run, 20 s, macOS):** `./mvnw -o -q test`, with no file read. On Windows
the answer is `.\mvnw.cmd -o -q test`.

**Show.** `.loop/session-start.jsonl`: one line, `"decision":"context","os":"macOS"`
(or `Windows`).

**Talking point.** Before the agent reads anything, the hook checks the operating
system and gives it the one Maven command that works here. Without it the agent
guesses, and a wrong guess costs a failed command and a retry. A fact a program can
look up comes from a program, not from a model.

### Guard demo, 3 minutes

**Do.** `/clear`. Paste:

> Change the shoulder rate in src/main/resources/generated/rates.json from 2400 to
> 2500 with the edit tool. Do not run commands and do not edit any other file. If the
> edit is denied, report the reason and finish.

**Expected (20 s):** the edit is denied with
`src/main/resources/generated/rates.json is generated from rates/rates.csv. Edit
rates/rates.csv, then run node scripts/generate-rates.mjs.` The file is unchanged.

**Show.** `rates.json` has no local change in the Commit tool window.
`.loop/pre-tool-use.jsonl` has one `deny` line.

**Talking point.** `preToolUse` runs before the tool. It stops one bad action and says
what to do instead. `agentStop` runs after the work. Different moments, different jobs.

### Version A: the limit, 3 minutes (7 on Windows)

**Do.** `/clear`, or restart Copilot. Paste:

> Delegate tickets/M-103.md to one general-purpose sub-agent and wait for it. Tell the
> sub-agent: change only the files the ticket names and run only the commands the
> ticket names; if a stop hook reports a check you may not fix, say why and finish
> again. Do not edit files yourself and do not start another sub-agent. If the
> sub-agent could not finish, report what blocked it.

Approve `node scripts/generate-rates.mjs` and the Maven test command (`./mvnw -o -q
test`, or `.\mvnw.cmd -o -q test` on Windows) when asked. Deny anything else. With
`copilot -p`, pass `--allow-tool='shell(node)'` and `--allow-tool='shell(./mvnw)'`.
Approval matches on the command name, so `shell(node)` covers the generator.

**Say, while the sub-agent works.** "The main agent handed the ticket to a sub-agent.
The sub-agent will run the unit suite itself, and it will pass. Then it tries to hand
back, and `subagentStop` runs every check, including M-101's."

**Expected (dry run, 2 min 13 s on a Mac, the same in both runs; 6 min 39 s on
Windows):**

1. The main agent starts one sub-agent.
2. The sub-agent edits `rates/rates.csv`, runs the generator, updates `StayPricerTest`
   and `RateTableTest`, runs the suite. Suite passes. Tries to finish.
3. **subagentStop** runs the gates. `ShoulderSeasonAcceptanceTest FAIL`: M-101's test
   still expects 7,800p and now gets 8,000p. Block.
4. The ticket does not name that test, so the sub-agent refuses to edit it. Blocked
   three times, then `allow-after-limit`. It hands back unverified.
5. The main agent tries to finish. **agentStop** runs the gates: the same failure.
   Blocked three times, then `allow-after-limit`.
6. The main agent reports: the acceptance test expects the old rate and the ticket does
   not allow changing it.

**Show.** `node scripts/traces.mjs`. Under `subagent-stop`: attempts 1 to 3 `block`,
attempt 4 `allow-after-limit`, each with `general-purpose` and
`ShoulderSeasonAcceptanceTest FAIL`. Under `agent-stop`: the same four lines for the
main agent. Leave version A's changes in place.

**Ask.** "The ticket says 2,500p. M-101's test says 2,400p. Who decides which one is
wrong?"

**Talking point.** Nobody fixed anything, and that is the right outcome. The ticket and
M-101's test disagree. An agent that edited the test to make the gate pass would have
hidden that. The gate turned a silent regression into a question for a person, and
both limits stopped the loop in under three minutes.

### Version B: a person decides, 1 minute

**Do.** The participant decides the new rate is correct and the old test must follow.
Add one line to the end of `tickets/M-103.md`:

```markdown
- Update the expected totals in `ShoulderSeasonAcceptanceTest` to the 2,500p rate.
```

`/clear`, then paste the **same prompt** as version A.

**Expected (dry run, 43 to 57 s on a Mac, 2 min 39 s on Windows):** one sub-agent
updates the acceptance test (8,000p and 5,500p). subagentStop: all six gates PASS on
attempt 1. agentStop: PASS. Allow.

**Show.** Exit Copilot. Run every acceptance test, the check CI would run:

```sh
./mvnw -o -q -Pacceptance test
```

(`.\mvnw.cmd -o -q -Pacceptance test` on Windows.) It exits with no output: everything
passed.

**Talking point.** Same prompt, same hooks. The only change is a sentence a person
wrote in the ticket. The decision about what is correct stays with a person. The
gate made sure somebody had to make it.

**Talking points for both versions.**

- The ticket was followed to the letter and still broke the previous ticket. The
  agent's own check (the unit suite) passed. Only the gate, which runs the acceptance
  tests of every finished ticket, saw it.
- `subagentStop` gates the sub-agent's handback. Its failures go to the sub-agent, not
  to the orchestrator. In version B the orchestrator receives work that already passed.
- `MAX_BLOCKS` counts per agent. In version A each agent got three blocks, so the
  worst case is bounded and visible in the trace.
- `stop.mjs` skips `agentStop` for sub-agents, so a sub-agent is checked once, by
  `subagentStop`, and the main agent once, by `agentStop`.
- The guard and the `generated` gate overlap on purpose. The guard sees file-edit tools
  only: `echo > rates.json` in a shell walks past it. The gate checks the bytes at the
  end, however they got there.

## 80–90: Close

**Do.**

```sh
node scripts/traces.mjs
```

Read the output top to bottom with the participant. Every decision of the session is
there: each session's context, every denial, every stop and sub-agent stop.

Then Commit tool window: the whole session as one diff. `StayPricer` (M-101),
`RoomCalendar` plus its new unit tests (M-102), the rates, the JSON and three test files
(M-103, including the acceptance test the person allowed in version B).

**What a gate proves.** The listed checks passed, on this machine, at that moment.

**What it does not prove.**

- That the checks are the right checks. M-103's acceptance edit is correct only
  because a person changed the ticket in version B. A person still reads that diff.
- Anything CI checks that the hook does not. CI stays the merge gate.
- That the hook ran. Copilot's `timeoutSec` (360 s for the stops) is the only limit.
  A hook that times out lets the turn end (fail-open), and the trace has no decision
  for that stop.

**Ask.** Go back to the answer from the tour: "How do you know an agent's work is done?"
Then: "Which one command in your repository would you make the first gate?"

**For their repository.** Start with one gate: the command the team already trusts.
`agentStop`, positive evidence, a block limit of 2 or 3, a trace. Add mutation or
guard hooks when a real incident asks for one.

## If something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| Hook never fires, no `.loop/` file | Key still `off:`, or Copilot not restarted, or folder not trusted | Check `lab.json`, restart, trust |
| Windows: hook errors with `node` not recognised | Node.js not on the `PATH` Copilot inherits | `node --version` in the same terminal, restart IntelliJ after changing `PATH` |
| Windows: `node` cannot be installed | No admin rights, or policy | Switch to the PowerShell twins: [Windows without Node](hook-lab/README.md#windows-without-node) |
| Windows: a `.ps1` hook says running scripts is disabled | `-ExecutionPolicy Bypass` missing from the command | Copy `hook-lab/lab.powershell.json` over `lab.json` again |
| `generated` gate fails with `java` not recognised | JDK not on the `PATH` Copilot inherits | `java -version` in the same terminal, restart IntelliJ after changing `PATH` |
| Windows: `GeneratedRatesTest` fails on a fresh clone | Line endings converted by a global Git setting | `.gitattributes` forces LF. Clone again, or `git add --renormalize .` |
| Every Maven gate FAIL, resolution errors in `.loop/logs/<gate>.log` | Warm-up not run on this machine | `node scripts/warm-up.mjs` with network |
| `policy-error` in the trace, turn ends unverified | `policy.mjs` does not import, throws, or returns another value | `node hook-lab/probes.mjs` shows the error. A syntax error stops the hook before the gates run. A throw is found after they ran |
| M-101 fixed on attempt 1 with the hook off | Prompt edited, or model ignored it | Show the result honestly. Say the hook would have accepted it |
| M-102 agent adds tests before the first stop | Model ignored "do not add tests" | Mutation gate passes at once. Point at the trace: one allow |
| Guard demo: the agent edits `rates/rates.csv` after the deny | Model followed the deny reason | Good talking point: the guard named the right file. Roll back `rates/rates.csv` before version A |
| Version A: the sub-agent edits the acceptance test and passes | Model ignored "change only the files the ticket names" | Show the diff: the agent changed a test nobody asked it to change. Ask whether the gate pass means anything now. Skip version B |
| Version A: the main agent starts a second sub-agent | Model ignored "do not start another sub-agent" | Each sub-agent gets its own three blocks. Let it run; it ends at the main agent's limit. Seen once with a looser prompt: 5 sub-agents, 8 minutes |
| Version B blocks on the acceptance test | Ticket line not saved, or `/clear` skipped | Save the ticket, `/clear`, paste again |
| Gutter arrow runs no tests on an acceptance class | IntelliJ delegates tests to Maven, which excludes `*AcceptanceTest` | Settings, Build Tools, Maven, Runner: untick delegation, or run `./mvnw -o -q -Pacceptance test` (Windows: `.\mvnw.cmd -o -q -Pacceptance test`) |
| Long red output in Copilot after a block | Expected: that is the reason text | Read it out. It is the agent's input |

Gate logs for the last run of each gate are in `.loop/logs/<gate>.log`.

## Evidence

**Node hooks, macOS, 2026-11-23.** JDK 21, Node 24.14, Copilot CLI 1.0.114, model
`auto`, `copilot -p` in a fresh copy with the reference policy body in `policy.mjs`.
Warm-up 4 s. Probes: starter 0/8, reference 8/8, naive 4/8.

| Step | Time | Result |
|---|---|---|
| M-101, agentStop on, `MAX_BLOCKS = 1` | 22 s | Block on the acceptance test, 1-line fix, allow |
| M-102, `MAX_BLOCKS = 3` | 52 s | Block on mutation, 1 test added, allow |
| M-103 guard | 20 s | Edit denied with the `node scripts/generate-rates.mjs` reason, file unchanged |
| M-103 version A, run 1 and run 2 | 2 min 13 s each | Sub-agent: 3 blocks, `allow-after-limit`. Main: 3 blocks, `allow-after-limit`. Conflict reported, unverified |
| M-103 version B, after A in the same folder, 2 runs | 49 s, 43 s | One sub-agent edits the acceptance test. All gates PASS on attempt 1. Acceptance profile green |
| M-103 version B, from a clean M-102 state, 2 runs | 56 s, 57 s | Same as above |

The versions A and B runs started from a copy where M-101 and M-102 had passed their
gates, with every hook and gate on and `MAX_BLOCKS = 3`. Runs of the same version ran
in parallel in separate copies.

**The looser prompt.** An earlier M-103 prompt said only "if a stop hook reports a
failing check, fix what it reports". With it, the main agent kept starting new
sub-agents: five in 7 min 46 s, each refusing the test edit, before the main agent
reached its limit. On Windows with the Java hooks the same prompt ended with a second
sub-agent editing the test. "Do not start another sub-agent" and "say why and finish
again" make version A end the same way every time.

**Node hooks and PowerShell twins, Windows, 2026-11-23.** Windows 11, Windows
PowerShell 5.1 only, Node 22.21, JDK 21.0.9. The lab cloned with Windows Git: clean
status, `mvnw.cmd` CRLF. Both warm-ups 20 s. Probes, Node and PowerShell: starter 0/8,
reference 8/8. Then the lesson with every hook started on Windows as
`powershell.exe -NoProfile -NoLogo -Command`, the event on stdin, while Copilot CLI
1.0.114 (`auto`) ran on a Mac and sent each event over SSH. The guide's order, one
folder, reference policy.

| Step | Node hooks | PowerShell twins |
|---|---|---|
| M-101, agentStop on | 1 min. Block, 1-line fix, allow | 58 s. Block, 1-line fix, allow |
| M-102 | 2 min. Block on mutation, 1 test added, allow | not run |
| M-103 guard | 52 s. Deny, rates untouched | 44 s. Deny with the `generate-rates.ps1` reason, rates untouched |
| M-103 version A | 6 min 39 s. Sub-agent: 3 blocks, `allow-after-limit`. Main: 3 blocks, `allow-after-limit`. Conflict reported | not run |
| M-103 version B | 2 min 39 s. All gates PASS on attempt 1, both agents | not run |

A stop with six gates takes about 40 s on that laptop, against about 20 s on the Mac,
so version A takes about three times as long. Plan 7 minutes for it on Windows.

In a first attempt the guard prompt did not forbid other files. The agent followed the
deny reason, edited `rates/rates.csv`, could not run the generator, and was blocked
three times by the stale-JSON unit test. The prompt now says "do not edit any other
file. If the edit is denied, report the reason and finish."


The figures below were measured with the earlier Java hook tooling.

Dry run 2026-11-23: a fresh clone, macOS, JDK 21.0.9, Copilot CLI 1.0.112, model
`auto`, `copilot -p` with the folder trusted. Interactive mode asks for the same
approvals by hand.

| Step | Model chosen | Time | Result |
|---|---|---|---|
| Probes: starter, naive, fixed, reference | | ~10 s each | 30/38, 33/38, 38/38, 40/40 |
| M-101, hooks off | GPT-6 Luna | 12 s | Read only. No edit. Acceptance red |
| M-101, agentStop on | GPT-6 Luna | 22 s | Block, 1-line fix, allow |
| M-102 | GPT-6.1 Terra after the block | 54 s | Block on mutation, 2 tests added, allow |
| M-103 guard | MAI Code 2 Flash | 20 s | Edit denied, file unchanged |
| M-103 sub-agent | MAI Code 2 Flash | 3 min | Sub-agent: block on M-101 test, fixed, allow. Main: allow |
| Final check | | | `./mvnw -o -q -Pacceptance test` all green |
| Rerun after the Java port, M-101 and guard | auto | 21 s, 31 s | Block, 1-line fix, allow. Guard deny |
| Rerun from the `loop-lab` subfolder, M-101 | auto | 11 s, 22 s | Hooks off: no edit. agentStop on: block, 1-line fix, allow |
| Windows gates, M-101 | auto | 54 s | Block, 1-line fix, allow |
| Windows gates, M-102 | auto | 1 min 37 s | Block on mutation, 2 tests added, allow |
| Windows gates, M-103 guard | auto | 1 min 7 s | Edit denied, file unchanged |
| Windows gates, M-103 sub-agent | auto | 6 min 49 s | Sub-agent at limit, main blocked, second sub-agent fixed, allow |
| Windows final check | | | `.\mvnw.cmd -o -q -Pacceptance test` exit 0 |

The model is picked per turn by `auto`, so the agent's edits vary between runs. The
gate results do not: the same broken code fails the same gate.

**Windows.** The workflow `.github/workflows/lab-on-every-os.yml` runs the warm-up, the
probes and the real hook programs on Windows, Linux and macOS, from PowerShell 7 and,
on Windows, PowerShell 5.1. It passed on all three on 2026-11-23, run from a standalone
copy of this folder. GitHub runs workflows only from a repository root, so in the
`loop-lab` branch the file is a record, not a live check. It proves the handlers, not
Copilot.

**Subfolder.** Copilot started in this folder loads its hooks, and also the enclosing
repository's root `AGENTS.md`. This folder's `AGENTS.md` tells the agent to ignore it.
Checked 2026-11-23 on M-101 with `agentStop` on: see the last row of the table.

**Windows laptop, 2026-11-23.** Windows 11, Windows PowerShell 5.1 only, JDK 21.0.9,
Git for Windows 2.36 with `core.autocrlf=true`. The `loop-lab` branch cloned with
Windows Git: clean status, `rates.json` LF, `mvnw.cmd` CRLF. In PowerShell: warm-up in
34 s, probes 30/38 starter and 40/40 reference, `.\mvnw.cmd -o -q test` and the
generator check pass. Then all three tickets with every hook started on Windows as
`powershell.exe -NoProfile -NoLogo -Command`, running the Java hook program, the event
on stdin, while Copilot ran on a Mac and sent each event over SSH. The "Windows gates"
rows above are that run. A stop with all six gates took about 40 s, against about 20 s
on the Mac.

> **TODO.** Copilot itself has not run on Windows with these hooks: the test laptop
> had no Copilot login. What remains unchecked is Copilot's own choice of shell and its
> launch of the hook. One M-101 run on a Windows laptop with Copilot signed in closes
> this.

# Moorings: loop engineering lab

A synthetic Java 21 booking and pricing library, three tickets, and four Copilot CLI
hooks that start switched off. In 90 minutes you switch them on one at a time and
watch a stop hook make the agent keep working until real checks pass, with a limit on
how many times it may try.

No services, no client code, no tickets of your own.

- **Running the session:** [FACILITATOR-GUIDE.md](FACILITATOR-GUIDE.md), step by step.
- **How the hooks work:** [hook-lab/README.md](hook-lab/README.md).

## Setup

On `PATH`: JDK 21, Node.js 22 or later, Git and an authenticated Copilot CLI. The rates
generator runs `java`, so the JDK must be on `PATH` as well as in IntelliJ. Install Node
with `winget install OpenJS.NodeJS.LTS` on Windows or `brew install node` on macOS.
Every hook and script is a Node.js module, so the commands are the same in PowerShell,
bash and zsh.

1. Clone the `loop-lab` branch:

   ```sh
   git clone --branch loop-lab --single-branch --depth 1 https://github.com/DigitalInnovation/enablement-program-knowledge.git moorings
   ```

   In IntelliJ, File, Open `moorings/forge/demos/demo-fixtures/loop-engineering-java`.
   Start Copilot from that folder, so it finds the hooks. Set the project SDK to a JDK 21,
   such as `temurin-21`. With no project SDK set, IntelliJ ran the tests on JDK 25.
2. Once, with network access, from that folder:

   ```sh
   node scripts/warm-up.mjs
   ```

   It prints an `ok` line per step, then `Ready: ...`. Every hook gate runs Maven
   offline after this.

**Windows without Node.** Every hook and script has a Windows PowerShell 5.1 twin
(`.ps1`) beside it. See [Windows without Node](hook-lab/README.md#windows-without-node).

The default unit suite passes. The acceptance tests for the open tickets fail, and the
default suite excludes them. `./mvnw -o -q -Pacceptance test` runs everything
(`.\mvnw.cmd -o -q -Pacceptance test` on Windows).

## What is in it

| Path | What |
|---|---|
| `tickets/M-101.md` | Price each night in its own season. The seeded code has the bug |
| `tickets/M-102.md` | Reject overlapping bookings |
| `tickets/M-103.md` | Change the shoulder rate and regenerate the JSON. Breaks M-101's test if done naively |
| `.github/hooks/lab.json` | Four hooks, every key prefixed `off:`. Remove the prefix to switch one on |
| `hook-lab/gates.txt` | The checks the stop hooks run. Uncomment a line to switch it on |
| `hook-lab/policy.mjs` | You write `decide()`: block, allow, or allow after the limit |
| `scripts/warm-up.mjs` | Pre-session download and sanity check |
| `scripts/traces.mjs` | Every hook decision so far, one line each |
| `scripts/generate-rates.mjs` | Builds `src/main/resources/generated/rates.json` from `rates/rates.csv` |
| `hook-lab/*.ps1`, `scripts/*.ps1`, `hook-lab/lab.powershell.json` | The same hooks and scripts in Windows PowerShell 5.1, for a machine without Node |
| `.github/workflows/lab-on-every-os.yml` | Runs the probes and the hook programs on Windows, Linux and macOS, from a standalone copy |

## Starting again

IntelliJ, Git, Rollback all changes, then delete the `.loop` folder. Or delete the clone and clone again.

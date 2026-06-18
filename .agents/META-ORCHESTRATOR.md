# META-ORCHESTRATOR

You are the meta-level pipeline orchestrator. You coordinate parallel execution
across multiple plan files (phases) by dispatching independent ORCHESTRATOR
subagents — one per plan — for all plans in the same dependency wave.

**Read this file at the start of every meta-pipeline session. Follow it exactly.**

---

## How to Start a Session

### New run

```
Read .agents/META-ORCHESTRATOR.md and start the full pipeline.
```

1. Read `.agents/PHASE-MANIFEST.md`.
2. Build the plan-level wave structure (see Wave Detection below).
3. Initialize `.agents/META-STATE.md` with the full wave plan and plan checklist.
4. Begin Wave 1.

### Resume

```
Read .agents/META-ORCHESTRATOR.md and resume the pipeline.
```

Read `.agents/META-STATE.md`. Find the first wave marked `IN_PROGRESS` or the
first wave after the last `COMPLETE` wave. Continue from there.

### Run a single wave

```
Read .agents/META-ORCHESTRATOR.md and run wave N only.
```

Useful for resuming after a block. Skips waves already marked `COMPLETE`.

---

## PHASE-MANIFEST.md Format

Each row in the manifest has:
- `ID` — short identifier (e.g. `be-2`, `fl-4`)
- `Plan file` — path to the plan markdown file
- `Depends-on` — comma-separated IDs that must be complete before this plan starts

---

## Wave Detection (plan-level topological sort)

Same algorithm as ORCHESTRATOR uses for tasks:

1. Parse every plan row. Record its `depends-on` set (empty if `—`).
2. Assign wave numbers:
   - Plans with no dependencies → Wave 1.
   - All others → Wave = (highest wave of their dependencies) + 1.
3. Group plans by wave number. Plans in the same wave run in parallel.
4. Write the computed wave table to `.agents/META-STATE.md`.

---

## Execution Loop

For each plan-wave in order:

```
GATE_START (plan-wave)
  → CONTRACT-AGENT generates wave contract
  → GATE_CONTRACT (human approves contract)
  → dispatch ORCHESTRATOR subagents in parallel (one per plan in wave)
    each subagent runs its own full task-wave loop internally
  → collect completion reports
  → GATE_COMPLETE (plan-wave)
  → update META-STATE.md
  → next plan-wave
```

---

## Phase Instructions

### GATE_START (per plan-wave)

Display:

```
Plan-Wave N — N plans running in parallel
  [be-2]  Backend API Phase 2 — Auth module
  [fl-2]  Flutter Phase 2 — Auth feature
Proceed? [Enter = proceed / s = skip wave / q = quit]
```

- **Enter / blank** → proceed.
- **s** → mark all plans in wave `[x]` (skipped). Advance to next wave.
- **q** → stop. META-STATE.md is saved. Resume later.

Update META-STATE.md: wave status = `IN_PROGRESS`.

### CONTRACT-AGENT (before dispatch)

After the user proceeds at GATE_START, dispatch one CONTRACT-AGENT before
any implementation subagents. This agent runs synchronously — wait for it
to finish before continuing.

Prompt:

```
You are the Contract agent. Read .agents/CONTRACT-AGENT.md for your instructions.

Wave: N — <Wave Name>
Plans in this wave:
  <plan-id>: <path-to-plan-file>
  <plan-id>: <path-to-plan-file>

Existing contracts (already written — do not redefine):
  <list of files in docs/contracts/ or "none">

Save the contract to: docs/contracts/wave-N-<kebab-wave-name>.md
```

### GATE_CONTRACT

After the CONTRACT-AGENT reports, display the contract to the user:

```
Contract generated: docs/contracts/wave-N-<name>.md
<paste full contract content here>

Approve this contract? [Enter = approve / e = edit / q = quit]
```

- **Enter / blank** → contract approved. Proceed to dispatch.
- **e** → open the contract file for the user to edit manually. When the user
  says ready, re-read the file and display it again for confirmation.
- **q** → stop. No implementation has started. Nothing to roll back.

Record contract path in META-STATE.md for this wave.

### Dispatch ORCHESTRATOR subagents (parallel)

Spawn one Agent call per plan **simultaneously** (all in the same message).
Each agent receives this prompt:

```
You are an ORCHESTRATOR subagent. Read .agents/ORCHESTRATOR.md for your
full instructions. Run the complete task-wave pipeline for one plan file.

Plan file: <path from PHASE-MANIFEST.md>
State file: .agents/META-STATE-<plan-id>.md
  (use this path wherever ORCHESTRATOR.md says ".agents/STATE.md")
Contract file: docs/contracts/wave-N-<name>.md
  Pass this path to every TASK-AGENT you dispatch.
  All implementation must conform to this contract.

When all tasks in your plan are committed, report back:

ORCHESTRATOR REPORT
Plan: <plan-id>
Status: COMPLETE | BLOCKED
Tasks completed: N
Last commit: <SHA>
Block reason: <only if BLOCKED>
```

Each subagent runs the full ORCHESTRATOR loop — GATE_START per task-wave,
TESTER ∥ REVIEWER parallel dispatch, GATE_PRECOMMIT per task-wave, merges.
The human interacts with each subagent's gates directly in its agent thread.

### Collect completion reports

Wait for all ORCHESTRATOR reports for the wave. For each:
- Record status and last commit SHA in META-STATE.md.
- If any report BLOCKED: run `meta_gate_blocked` procedure.

If all report COMPLETE → proceed to GATE_COMPLETE.

### GATE_COMPLETE (per plan-wave)

```
Plan-Wave N complete.
  [be-2]  COMPLETE — 8 tasks, last commit abc123
  [fl-2]  COMPLETE — 6 tasks, last commit def456
Continue to Plan-Wave N+1? [Enter = continue / q = quit]
```

- **Enter / blank** → mark wave `COMPLETE` in META-STATE.md, advance.
- **q** → stop. META-STATE.md saved. Resume later.

---

## meta_gate_blocked Procedure

1. Write or append to `.agents/BLOCKED.md`:
   ```markdown
   # Meta Pipeline Blocked

   **Plan-Wave:** N
   **Plan:** <plan-id> — <plan title>
   **Reason:** <ORCHESTRATOR's block reason>

   See `.agents/META-STATE-<plan-id>.md` for the full task-level loop history.
   ```
2. Stop. Tell the user: "Pipeline blocked — see `.agents/BLOCKED.md`"

---

## Rules

- Never run two plan-waves simultaneously — waves are sequential at the
  meta level. Parallelism is within a wave, not across waves.
- Each ORCHESTRATOR subagent is fully autonomous within its plan. It creates
  its own task worktrees, runs gates with the user, and handles all merges.
- ORCHESTRATOR subagents share the same git repository. This is safe because
  each plan touches different directories (verified by PHASE-MANIFEST.md).
  If a future plan has overlapping files, add an explicit `depends-on` entry.
- The META-ORCHESTRATOR does not create git worktrees itself — that is the
  ORCHESTRATOR's responsibility.
- Never push to the remote repository.
- Save META-STATE.md after every gate and every report received.

---

## META-STATE.md Maintenance

Update `.agents/META-STATE.md` at these moments:

| Moment | What to update |
|---|---|
| Session start | Full wave plan, plan checklist, session info |
| GATE_START fires | Wave status = IN_PROGRESS |
| Contract approved | Record contract path for this wave |
| ORCHESTRATOR report received | Plan row: status + last commit SHA |
| GATE_COMPLETE fires | Wave status = COMPLETE, plan [x] in checklist |
| Block occurs | Plan row: status = BLOCKED, note in block column |

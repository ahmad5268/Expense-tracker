# PIPELINE-DESIGN

> MD-based agentic workflow pipeline for the Expense Tracker monorepo.
> This document describes every file in the pipeline, how they connect, and the
> rules that govern execution. This is the reference document for the pipeline —
> read this before modifying any `.agents/` file.

---

## 1. Overview

The MD pipeline replaces the Python orchestrator (`tools/workflow/`) with a set
of markdown instruction files that Claude Code reads and follows directly in an
interactive session. Claude Code itself is the runtime — it reads a file, adopts
the role defined in it, does the work, then returns to orchestrator mode.

**No API key required. No subprocess management. No Python runtime.**
Billing goes through the team's existing Claude Code subscription.

### How It Differs from the Python Pipeline

| Dimension | Python pipeline (`tools/workflow/`) | MD pipeline (`.agents/`) |
|---|---|---|
| Runtime | Python 3.12 spawns `claude -p` subprocesses | Claude Code interactive session |
| Billing | `ANTHROPIC_API_KEY` — pay-per-token, per-call | Claude Code subscription |
| State storage | `.agents/state/pipeline_state.json` | `.agents/STATE.md` (markdown) |
| Agent invocation | `subprocess.run(["claude", "-p", prompt])` | Claude reads a `.md` file and adopts the role |
| Verdict format | Last JSON line of subprocess stdout | `VERDICT: PASS/FAIL/BLOCKED` written inline |
| CI/CD | GitHub Actions (`pipeline.yml`) | Not needed — session-driven |
| Automation level | Fully headless, unattended | Interactive — Claude Code session must be open |
| Error loop logic | Python code in `orchestrator.py` | Prose rules in `ORCHESTRATOR.md` |
| Human gates | Terminal `input()` prompts | Claude asks the user in the chat |

The Python pipeline is preserved at `tools/workflow/` and may be adopted later
once API billing is understood. The MD pipeline takes over as the active path.

---

## 2. File Map

```
.agents/
├── ORCHESTRATOR.md      ← State machine brain. Claude reads this first.
├── STATE.md             ← Live session state. Owned by ORCHESTRATOR.
├── BLOCKED.md           ← Written only when max retries hit. Trigger for human.
└── prompts/
    ├── DEVELOPER.md     ← Developer role: implement the task.
    ├── TESTER.md        ← Tester role: write independent tests.
    ├── REVIEWER.md      ← Reviewer role: audit the diff.
    └── QA.md            ← QA role: verify acceptance criteria + edge cases.
```

### `ORCHESTRATOR.md`

The brain. Defines the complete state machine, all phase transitions, gate
behaviour, retry rules, and role-switching protocol. Claude reads this at the
start of every session and follows it exactly. It is the equivalent of
`tools/workflow/orchestrator.py` in the Python pipeline — but written as
imperative prose that Claude interprets.

Claude must re-read this file at session start even if it appears to remember
the rules. File content is authoritative; session memory is not.

### `STATE.md`

The live state file. The ORCHESTRATOR reads and writes it after every phase
transition. It contains:

- Session info (plan path, start time, last update time).
- Current status (phase, task index, current task name).
- Retry counts for each of the three independent loops.
- Task checklist — one checkbox per task, marked `[x]` when committed or skipped.
- Current Task Detail — the full task body copied from the plan file when
  GATE_START fires. This is what all agent roles read to understand what to do.
- Loop History — one row per phase attempt recording phase, attempt number,
  verdict, and one-line summary. Cleared after each commit.
- Commit Log — one row per committed task with SHA and message. Never cleared.

STATE.md is always safe to read mid-session — the ORCHESTRATOR writes it after
every phase. If the session crashes, the last saved phase is the recovery point.

### `BLOCKED.md`

Does not exist until a pipeline block occurs. Created by the ORCHESTRATOR when
a retry loop exhausts MAX_RETRIES (4). Contains:

- Which task and phase triggered the block.
- Full Loop History for that task.
- Explicit instructions for the human on what action is required to unblock.

Existence of this file signals that the pipeline needs human intervention. The
human reads it, resolves the underlying issue, then resumes or manually closes
the task.

### `prompts/DEVELOPER.md`

Activates the Developer role. Instructs Claude to:

1. Read STATE.md for the current task body and file list.
2. Read all production files to be modified before writing anything.
3. Check Loop History for previous FAIL feedback and address every listed issue.
4. Implement exactly what the task specifies — nothing more.
5. Run the relevant test suite and self-correct up to 3 times.
6. Report verdict as `VERDICT: PASS/FAIL/BLOCKED` with `FILES_CHANGED`.

Enforces all mandatory project conventions: cents-only money, WorkspaceMemberGuard,
no raw SQL interpolation, Prisma error mapping, Flutter enum annotations, no YAGNI.

### `prompts/TESTER.md`

Activates the Tester role. Instructs Claude to:

1. Read STATE.md for the task spec and the list of implemented files.
2. Read **only** production files — never open the developer's test files.
3. Independently derive test cases from the spec and production code.
4. Cover: happy path, ≥2 error/edge cases per method, WorkspaceMemberGuard
   auth checks (403 on non-member), and money edge cases (0, 999999999).
5. Run the test suite — all tests must pass before reporting PASS.
6. Report FAIL if production code has a genuine bug — do not patch production.

Independence from the developer's tests is critical. Mirroring developer
assumptions defeats the purpose of the Tester role.

### `prompts/REVIEWER.md`

Activates the Reviewer role. Instructs Claude to:

1. Read STATE.md for the task spec.
2. Run `git diff HEAD` and review the full diff.
3. Check every mandatory convention and classify each issue as CRITICAL /
   IMPORTANT / MINOR.
4. Verdict rule: any CRITICAL or IMPORTANT → FAIL; MINOR only → PASS.

The Reviewer reports — it does not fix. All fixes go back to DEVELOPER.

### `prompts/QA.md`

Activates the QA role. The final automated check before the human gate.
Instructs Claude to:

1. Run the full test suite for all affected modules.
2. Check every acceptance criterion in the task spec (✓ / ✗ / ~).
3. Add edge-case tests not yet covered: empty workspace, concurrent writes,
   amount boundaries (0, 999999999), expired JWT → 401, non-member → 403.
4. Verdict rule: all criteria ✓ AND all tests pass → PASS; else FAIL.

---

## 3. State Machine

```
IDLE
  └─► GATE_START          ← human approves or skips
        └─► DEVELOPING     ← Developer role
              ├─► TESTING  ← Tester role
              │     ├─PASS─► REVIEWING
              │     └─FAIL─► DEVELOPING (retry, up to MAX_RETRIES=4)
              │
              ├─► REVIEWING  ← Reviewer role
              │     ├─PASS─► QA_TESTING
              │     └─FAIL─► DEVELOPING (retry, up to MAX_RETRIES=4)
              │
              └─► QA_TESTING  ← QA role
                    ├─PASS─► GATE_PRECOMMIT  ← human approves commit
                    │           └─► COMMITTING ─► IDLE (next task)
                    └─FAIL─► DEVELOPING (retry, up to MAX_RETRIES=4)

Any phase can → GATE_BLOCKED if MAX_RETRIES exhausted or BLOCKED verdict received.
```

### Retry Counters

Three independent counters in STATE.md, each with MAX_RETRIES = 4:

| Counter | Incremented when |
|---|---|
| `tester_loop` | TESTER reports FAIL |
| `reviewer_loop` | REVIEWER reports FAIL |
| `qa_loop` | QA reports FAIL |

A failure in one loop does not consume another loop's counter.
All counters reset to 0 after a task is committed.

---

## 4. Gate System

### GATE_START

Fires before any agent work begins for a task. The ORCHESTRATOR displays the
task index, title, and file list, then asks:

```
Proceed? [Enter = proceed / s = skip / q = quit]
```

- **Enter / blank** → proceed with DEVELOPING.
- **s** → mark task `[x]` (skipped) in STATE.md, advance to next task.
- **q** → stop session. STATE.md saved. Resume any time.

### GATE_PRECOMMIT

Fires after QA passes, before any git commit. The ORCHESTRATOR displays the
full `git diff HEAD` and Loop History summary, then asks:

```
Commit? [Enter = commit / e = edit / q = quit]
```

- **Enter / blank** → commit and advance to next task.
- **e** → user makes manual edits; ORCHESTRATOR re-enters REVIEWING when ready.
- **q** → stop without committing. Phase stays at GATE_PRECOMMIT. Resume later.

### GATE_BLOCKED

Not user-triggered — fires automatically when a retry loop is exhausted or an
agent reports BLOCKED. Writes BLOCKED.md and stops. Human must intervene.

---

## 5. Role-Switching Protocol

When the ORCHESTRATOR transitions between phases, Claude must:

1. Announce: `--- Switching to [ROLE] ---`
2. Read the corresponding prompt file from `.agents/prompts/`.
3. Fully adopt that role — follow its instructions as the sole directive.
4. Announce: `--- [ROLE] complete. Verdict: [PASS/FAIL/BLOCKED] ---`
5. Return to ORCHESTRATOR mode and advance the state machine.

This explicit announcement makes sessions auditable — the user can see exactly
which role was active at any point in the conversation.

---

## 6. How to Start a Session

### New pipeline run

Open Claude Code in `C:\Expense-tracker` and send:

```
Read .agents/ORCHESTRATOR.md and start the pipeline using plan
docs/superpowers/plans/<plan-file>.md
```

Claude will read ORCHESTRATOR.md, parse the plan file, initialize STATE.md,
and begin GATE_START for Task 1.

### Resume a paused session

```
Read .agents/ORCHESTRATOR.md and resume the pipeline.
```

Claude reads STATE.md to find the current phase and task, then continues from
exactly where it stopped.

---

## 7. Constraints

- **Never push to the remote repository.** Pipeline commits are local only.
  The human pushes when the branch is ready.
- **Never skip phases.** DEVELOPING → TESTING → REVIEWING → QA_TESTING is
  mandatory every time. Skipping any phase voids the quality guarantees.
- **Claude Code session must be active.** This pipeline cannot run unattended.
  A human must be available to respond to gates.
- **One plan file at a time.** STATE.md tracks a single plan. To run a different
  plan, the current session must be finished or abandoned (STATE.md reset).
- **Agents do not push git.** Only the COMMITTING phase runs `git commit`.
- **The Python pipeline at `tools/workflow/` is not deleted.** It is preserved
  as a reference implementation for potential future use.

---

## 8. Relationship to Python Pipeline Files

| Python pipeline file | MD pipeline equivalent | Notes |
|---|---|---|
| `tools/workflow/orchestrator.py` | `.agents/ORCHESTRATOR.md` | Same state machine, prose instead of code |
| `tools/workflow/state.py` + JSON file | `.agents/STATE.md` | Markdown table instead of JSON |
| `tools/workflow/gates.py` | Gate sections in `ORCHESTRATOR.md` | Gate logic as prose rules |
| `tools/workflow/runner.py` | Role-switching protocol in `ORCHESTRATOR.md` | Claude IS the runner |
| `tools/workflow/agents/prompts/developer.md` | `.agents/prompts/DEVELOPER.md` | No `{placeholders}` — reads STATE.md directly |
| `tools/workflow/agents/prompts/tester.md` | `.agents/prompts/TESTER.md` | Same adaptation |
| `tools/workflow/agents/prompts/reviewer.md` | `.agents/prompts/REVIEWER.md` | Same adaptation |
| `tools/workflow/agents/prompts/qa.md` | `.agents/prompts/QA.md` | Same adaptation |
| `tools/workflow/skills.py` | Implicit | Claude Code already loads skills via CLAUDE.md |
| `.github/workflows/pipeline.yml` | _(not needed)_ | Session-driven, not CI-driven |

# PARALLEL-PIPELINE-DESIGN

> Parallel agentic workflow pipeline for the Expense Tracker monorepo.
> Supersedes `2026-06-17-PIPELINE-DESIGN.md` (the sequential MD pipeline).
> The sequential pipeline remains valid for single-task debugging sessions.

---

## 1. Overview

The parallel MD pipeline runs as many tasks simultaneously as the plan's
dependency graph allows. Tasks in the same dependency wave execute in isolated
git worktrees. Within each task, TESTER and REVIEWER run as parallel subagents.
Human gates fire once per wave rather than once per task.

**No API key required. Billing through Claude Code subscription.**

### Parallelism Summary

| Scope | Strategy |
|---|---|
| Across tasks | Wave-based: tasks with no mutual dependency run simultaneously |
| Within a task | TESTER and REVIEWER dispatch in parallel after DEVELOPER finishes |
| Within DEVELOPER / QA | Sequential — these roles make file changes |

---

## 2. File Map

```
.agents/
├── ORCHESTRATOR.md      ← Wave detection, worktree management, parallel dispatch,
│                           gate logic, merge strategy.
├── TASK-AGENT.md        ← Per-task mini-orchestrator: runs DEVELOPER, spawns
│                           TESTER ∥ REVIEWER, runs QA, handles retry loops,
│                           reports back to ORCHESTRATOR.
├── STATE.md             ← Wave-aware live state: wave plan, per-task status,
│                           loop history, commit log.
├── BLOCKED.md           ← Created when any task or merge is blocked.
└── prompts/
    ├── DEVELOPER.md     ← Developer role. Receives context from initial prompt.
    ├── TESTER.md        ← Tester role. Independent tests, no dev test files.
    ├── REVIEWER.md      ← Reviewer role. Reads diff, classifies issues.
    └── QA.md            ← QA role. Acceptance criteria + mandatory edge cases.
```

---

## 3. File Responsibilities

### `ORCHESTRATOR.md`

The session-level brain. Claude Code reads this once at session start and
follows it for the entire run. Responsibilities:

- **Wave detection** — parses `Depends-on:` tags from the plan, assigns every
  task a wave number via topological sort, groups tasks into waves.
- **GATE_START** — displays all tasks in the upcoming wave, asks the human
  to proceed, skip the wave, or quit.
- **Worktree management** — creates `git worktree add` for each task in the
  wave before dispatching agents; removes them after merge.
- **Parallel dispatch** — spawns all TASK-AGENTs for a wave simultaneously
  using the Agent tool (all in one message).
- **Result collection** — waits for all TASK-AGENT reports, records loop
  history and verdicts in STATE.md.
- **GATE_PRECOMMIT** — displays all diffs from the wave, asks the human to
  commit, edit one task, or quit.
- **Merge** — merges all worktree branches into HEAD in task-index order.
  Stops on conflict and writes BLOCKED.md.
- **STATE.md maintenance** — updates at every phase transition.

### `TASK-AGENT.md`

The task-level mini-orchestrator. Each task subagent reads this upon launch.
Responsibilities:

- Receives full context in its initial prompt (task body, file list, worktree
  path, dependency outputs) — does not read STATE.md.
- Runs DEVELOPER role directly (inline, same agent).
- Spawns TESTER and REVIEWER as parallel sub-agents using the Agent tool.
- Collects TESTER and REVIEWER verdicts, applies retry logic independently
  for each (separate counters, MAX_RETRIES = 4 each).
- Runs QA role directly after both TESTER and REVIEWER pass.
- Applies QA retry logic (MAX_RETRIES = 4, independent counter).
- Reports a structured `TASK-AGENT REPORT` back to ORCHESTRATOR.
- Never commits or pushes — git is handled entirely by ORCHESTRATOR.

### `STATE.md`

Wave-aware live state. Sections:

- **Session Info** — plan path, start time, last update time.
- **Wave Plan** — table of wave → tasks → status (PENDING / IN_PROGRESS /
  COMPLETE / BLOCKED).
- **Task Checklist** — one checkbox per task. Marked `[x]` after merge or skip.
- **Wave Detail** — one sub-section per wave, with per-task verdict table and
  Loop History table. Created by ORCHESTRATOR on init, filled in as waves complete.
- **Commit Log** — one row per merged task with wave, task index, branch name,
  commit SHA, and message. Never cleared.

### `BLOCKED.md`

Does not exist until a block occurs. ORCHESTRATOR writes it when:
- A TASK-AGENT reports BLOCKED (retry counter exhausted or agent can't proceed).
- A `git merge` produces a conflict (two tasks in the same wave touched the
  same file — indicates the `Depends-on:` tags were mis-specified).

Contains: wave, task, phase, full loop history, and human instructions for
resolving the block.

### `prompts/DEVELOPER.md`

Activates the Developer role in a TASK-AGENT context. Key differences from
the sequential version:
- All context (task body, files, worktree path, retry feedback) comes from the
  initial prompt — no STATE.md read.
- All file operations use the worktree-relative path.
- Reports `VERDICT: PASS/FAIL/BLOCKED` back to TASK-AGENT (not to ORCHESTRATOR).

Enforces all project conventions: cents integers, WorkspaceMemberGuard,
`$queryRaw` only, Prisma error mapping, Flutter enum annotations, no YAGNI.

### `prompts/TESTER.md`

Activates the Tester role as a parallel sub-agent of TASK-AGENT. Key points:
- Context provided in initial prompt.
- Must NOT read any test files written by DEVELOPER.
- Derives tests independently from spec + production code.
- Reports verdict back to TASK-AGENT (which spawned it).

### `prompts/REVIEWER.md`

Activates the Reviewer role as a parallel sub-agent of TASK-AGENT. Key points:
- Runs `git -C <worktree-path> diff HEAD` to get the diff.
- TESTER is running simultaneously — Reviewer does not wait for it or use its
  results. TASK-AGENT collects both verdicts independently.
- Reports verdict back to TASK-AGENT.

### `prompts/QA.md`

Activates the QA role in a TASK-AGENT context. Runs after both TESTER and
REVIEWER have passed. Receives tester and reviewer summaries in its context.
Verifies acceptance criteria and adds required edge-case tests. Last check
before TASK-AGENT reports PASS to ORCHESTRATOR.

---

## 4. Execution Model

### Full flow diagram

```
Session start
  └─► Parse plan → compute waves → initialize STATE.md

For each wave:
  GATE_START (wave) ─── human: proceed / skip / quit
    │
    ├─► git worktree add (one per task in wave)
    │
    ├─► Dispatch TASK-AGENTs in parallel ──────────────────────────────┐
    │     Task A subagent:                  Task B subagent:           │
    │       DEVELOPER                         DEVELOPER                │
    │       TESTER ∥ REVIEWER                 TESTER ∥ REVIEWER        │
    │       QA                                QA                       │
    │       → report                          → report                 │
    │                                                                  │
    ◄─────────────────── collect all reports ──────────────────────────┘
    │
    GATE_PRECOMMIT (wave) ─── human: commit / edit / quit
    │
    ├─► git merge (task-index order, --no-ff)
    ├─► git worktree remove
    └─► Update STATE.md → next wave

All waves complete → DONE
```

### Retry loops within TASK-AGENT

```
DEVELOPER → (TESTER ∥ REVIEWER)
               │
               ├─ both PASS ──► QA
               │                 │
               │                 ├─ PASS ──► report PASS
               │                 └─ FAIL ──► DEVELOPER (qa_loop++)
               │
               ├─ TESTER FAIL ──► DEVELOPER (tester_loop++)
               └─ REVIEWER FAIL ──► DEVELOPER (reviewer_loop++)

Each counter is independent. MAX_RETRIES = 4 per counter.
Exhausting any counter → report BLOCKED.
```

---

## 5. Plan File Format

### `Depends-on:` tag

```markdown
### Task 1: Docker Compose + Database
**Files:**
- Create: `docker-compose.yml`

### Task 2: PrismaService
Depends-on: 1

**Files:**
- Create: `apps/api/src/prisma/prisma.service.ts`

### Task 3: Auth Module
Depends-on: 2

### Task 4: Users Module
Depends-on: 2

### Task 5: Transactions Module
Depends-on: 3, 4
```

**Result:**

| Task | Wave |
|---|---|
| 1 | 1 |
| 2 | 2 |
| 3 | 3 |
| 4 | 3 |
| 5 | 4 |

Tasks 3 and 4 run in parallel (same wave, no dependency on each other).

### Rules for `Depends-on:`

- Must appear on the line immediately after the `### Task N:` header.
- Values are comma-separated task index numbers (integers matching the `N` in
  `### Task N:`).
- A task may only depend on tasks with a lower index number (no circular deps).
- If absent, the task is placed in Wave 1.

---

## 6. Git Worktree Strategy

### Branch naming

```
pipeline/task-N-<kebab-title>
```

Example: `pipeline/task-3-jwt-strategy`

### Worktree path

```
.agents/worktrees/task-N/
```

### Lifecycle

```
Before wave:   git worktree add .agents/worktrees/task-N pipeline/task-N-<title>
During wave:   TASK-AGENT writes all files inside .agents/worktrees/task-N/
After wave:    git -C .agents/worktrees/task-N add <files>
               git -C .agents/worktrees/task-N commit -m "feat(task-N): <title>"
               git merge --no-ff pipeline/task-N-<title> (on main branch)
               git worktree remove .agents/worktrees/task-N
               git branch -d pipeline/task-N-<title>
```

### Merge conflict handling

A conflict means two tasks in the same wave both modified the same file — this
is a `Depends-on:` mis-specification. ORCHESTRATOR stops, writes BLOCKED.md,
and asks the human to:

1. Resolve the conflict manually (`git merge --continue`).
2. Add the missing dependency to the plan file.
3. Resume the pipeline.

---

## 7. Gate System

### GATE_START (per wave)

One gate for the entire wave. Shows all tasks + files in the wave.
User can proceed, skip the whole wave, or quit.

### GATE_PRECOMMIT (per wave)

One gate for the entire wave after all TASK-AGENTs report PASS.
Shows all diffs. User can commit all, choose to edit one task (re-runs
that task's TASK-AGENT from REVIEWING), or quit without committing.

### GATE_BLOCKED (per blocked task)

Automatic — fires when any TASK-AGENT or merge reports BLOCKED.
Writes BLOCKED.md and stops the session.

---

## 8. How to Start a Session

### New run

```
Read .agents/ORCHESTRATOR.md and start the pipeline using plan
docs/superpowers/plans/<plan-file>.md
```

### Resume

```
Read .agents/ORCHESTRATOR.md and resume the pipeline.
```

---

## 9. Constraints

- **Never push.** All commits are local. Human pushes when ready.
- **Never skip phases within TASK-AGENT.** DEVELOPER → TESTER ∥ REVIEWER → QA
  is mandatory for every task, every retry.
- **Tasks in the same wave must not depend on each other.** Enforced by
  `Depends-on:` tags and the topological sort.
- **TESTER must not read developer test files.** Enforced by TESTER.md.
- **TASK-AGENT does not read STATE.md.** Context is passed via the initial prompt.
- **Python pipeline at `tools/workflow/` is not deleted.** Preserved for
  potential future headless CI use once API billing is resolved.

---

## 10. Relationship to Other Pipeline Files

| File | Role |
|---|---|
| `2026-06-17-PIPELINE-DESIGN.md` | Sequential (non-parallel) MD pipeline — still valid for single-task debug sessions |
| `tools/workflow/orchestrator.py` | Python headless pipeline — preserved, not active |
| `.agents/ORCHESTRATOR.md` | Active orchestrator (this pipeline) |
| `.agents/TASK-AGENT.md` | New — no equivalent in sequential or Python pipelines |
| `.agents/STATE.md` | Wave-aware (replaces sequential version and Python JSON state) |

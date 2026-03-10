---
name: plan
description: "Run a planning-only loop to generate or refresh IMPLEMENTATION_PLAN.md"
argument-hint: "[CONTEXT] [--speed fast|efficient|quality] [--max-iterations N] [--verify-command CMD]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)", "Read(${CLAUDE_PLUGIN_ROOT}/agents/*.md)"]
hide-from-slash-command-tool: "true"
---

# Ralpha Plan Command

Execute the setup script in solo mode for planning:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh" --mode solo $ARGUMENTS
```

You are now in a **Ralpha plan loop**. Your only job is to produce or refresh `IMPLEMENTATION_PLAN.md`. You do not implement anything.

## What plan mode does

Plan mode runs 1–3 iterations of read-only analysis. It produces `IMPLEMENTATION_PLAN.md` — a prioritised task checklist that subsequent `solo` and `team` loops draw from. Fresh context every iteration means the plan is grounded in the actual codebase state, not accumulated context drift.

Run plan mode:
- Before starting a new project or major feature
- When the build loop has stalled and you suspect scope drift
- After a long team session to reconcile what was actually done vs planned

## How to work

### Step 1 — Understand the requirements

Use scanner subagents (`planner` persona) to read all requirement documents:
- `specs/` directory if present
- `README.md` for stated goals
- Any PRD, design doc, or issue description provided in the objective

### Step 2 — Survey the codebase

Use planner subagents to scan `src/` (or equivalent) broadly:
- What exists vs what the specs require?
- What is partially implemented or stubbed?
- What has TODO/FIXME/HACK markers?
- What tests exist and what do they cover?

Do NOT read every file. Sample key files per module and use Grep for patterns.

### Step 3 — Generate IMPLEMENTATION_PLAN.md

Write `IMPLEMENTATION_PLAN.md` with this structure:

```markdown
# IMPLEMENTATION_PLAN

Generated: YYYY-MM-DD
Source: [brief description of the objective/specs used]

## Tasks

- [ ] TASK-001: [imperative verb phrase] — Files: [exact paths], Done when: [specific command or test]
- [ ] TASK-002: ...

## Notes

[Spec ambiguities, blockers, or items needing human judgment]
```

Each task must be:
- **One loop-sized unit** — completable in a single context window by one agent
- **File-scoped** — names the exact files to create or modify
- **Verifiable** — states a specific test, command, or observable output that proves it done
- **Ordered** — tasks that unblock others appear first

### Step 4 — Verify the plan is actionable

Before claiming completion, re-read the plan and confirm:
- Every task has done-criteria
- No task is ambiguous enough to produce two different implementations
- The ordering is correct (dependencies respected)
- There are no duplicate tasks

## Completion

When `IMPLEMENTATION_PLAN.md` exists and is populated with actionable tasks, output:

```
<promise>PLAN COMPLETE</promise>
```

If a `--verify-command` was provided, it must also pass.

CRITICAL: Do not output the promise if the plan has vague tasks, missing done-criteria, or tasks that would require clarification to implement. A bad plan produces a bad build loop.

## After planning

Run the build loop:

```
/ralpha-team:solo "Work through IMPLEMENTATION_PLAN.md" --verify-command "your-test-command"
/ralpha-team:team "Work through IMPLEMENTATION_PLAN.md" --verify-command "your-test-command"
```

The solo and team loops check for `IMPLEMENTATION_PLAN.md` and use it as their task queue when present.

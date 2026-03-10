# ralpha-team

A Claude Code plugin that runs your prompt in a loop until the work is genuinely done — verified by a shell command, not just Claude saying so.

The core idea: instead of one long session where the model tries to hold everything in context, you run many short sessions. Each one reads the current state from disk, does one unit of work, commits, and exits. The loop re-invokes it. Fresh context every time. State lives in files and git history, not in the model's memory.

This approach comes from Geoffrey Huntley's [Ralph technique](https://ghuntley.com/ralph/), ported here to Claude Code's native plugin system.

## Why this works

Long coding sessions degrade. The model starts strong, then slowly loses track of earlier constraints as the context fills up. It might re-implement something it already built, or forget that a test was passing and break it. By iteration 15 in a single session, you're often fighting accumulated drift as much as the actual problem.

Short loops with fresh context don't have this property. Every iteration, Claude re-reads the objective, sees what's in git, and works from that ground truth rather than from its fading recollection of the last 50 messages. You re-read specs on every iteration, which costs something, but the consistency is worth it for anything non-trivial.

The dual gate is the other piece. Without some form of backpressure, Claude will claim it's done when it isn't. It's not deceptive — it's just that "the feature is now complete" is a natural way to narrate work, not necessarily a factual claim. The gate separates an intentional completion claim from incidental completion-sounding narration, then independently checks that the claim is true.

## Install

Inside Claude Code, run each command **separately**:

```
/plugin marketplace add James-Traina/science-plugins
```

```
/plugin install ralpha-team@science-plugins
```

Both modes require `jq` (`brew install jq` on macOS, `apt install jq` on Linux). Team mode additionally requires the experimental flag in `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Three modes

### Plan

Before writing any code, run a planning loop. It scans your specs and existing codebase, compares them, and produces `IMPLEMENTATION_PLAN.md` — a flat checklist of tasks, each with explicit file scope and a done criterion.

Why plan separately? Without a plan, each build iteration has to re-reason the scope from scratch. The model reads the codebase, figures out what's missing, picks something to work on, and implements it. Next iteration, it reads the codebase again and might pick a different thing, or pick the same thing having forgotten progress was already made. A plan file gives fresh-context iterations something stable to draw from: pick the first unchecked task, do it, check it off.

```bash
/ralpha-team:plan "Build a payment processing service with Stripe, webhooks, and idempotency" \
  --max-iterations 3
```

### Solo

One Claude session, looping. The default for most things. Good for bug fixes, single features, refactors, anything where the work is roughly sequential.

Each iteration sees the previous iteration's work via git log and file state. The model can't remember what it said last time, but it can see what it committed. That's the right kind of memory for this use case — concrete and verifiable rather than approximate and decaying.

```bash
/ralpha-team:solo "Fix the token refresh race condition in auth/session.py" \
  --completion-promise 'FIXED' \
  --verify-command 'pytest tests/test_auth.py -v' \
  --max-iterations 15
```

### Team

A lead session that decomposes the objective into tasks, spawns multiple specialized teammates in parallel, and coordinates across iterations. Use this when tasks are genuinely independent — different files, no shared interfaces — and can proceed without waiting for each other.

Agent teams are experimental, meaningfully more expensive in tokens, and add coordination overhead. The overhead is worth it when you have a real parallelism opportunity (e.g., building a frontend, backend, and test suite simultaneously) or when you want adversarial review — multiple agents independently evaluating the same problem and disagreeing productively. For sequential or tightly-coupled work, solo with subagents is faster.

**Default rule: try solo first.** Escalate to team when you can clearly describe two or more workstreams that don't need to wait for each other.

```bash
/ralpha-team:team "Build a REST API with auth, CRUD, and integration tests" \
  --completion-promise 'ALL TESTS PASSING' \
  --verify-command 'npm test' \
  --max-iterations 30 \
  --team-size 4
```

## The dual gate

This is the mechanism that makes the loop reliable.

**Gate 1 — the promise.** Claude must output `<promise>YOUR PHRASE</promise>` with the exact phrase you set. The tags matter: the hook scans for the structured tag, not for the phrase anywhere in the output. This filters out incidental completion language ("the implementation is now complete" as narration) from an intentional completion claim (`<promise>DONE</promise>` as a deliberate signal).

**Gate 2 — verification.** A shell command you provide must exit 0. This independently confirms that the claim is true. Promise without passing verification? Loop continues, failure output fed back in. Verification passes but no promise? Also continues. Both must pass on the same iteration.

The combination matters. The promise alone is gameable — Claude could output the tag just to exit the loop. The verification alone doesn't distinguish "genuinely done" from "happened to pass this time." Together, they require that Claude both believes the work is complete and that an independent check agrees.

```bash
# Example: the loop exits only when Claude outputs <promise>TESTS GREEN</promise>
# AND 'npm test' exits 0 on the same iteration
/ralpha-team:solo "Implement rate limiting middleware" \
  --completion-promise 'TESTS GREEN' \
  --verify-command 'npm test'
```

If you omit `--completion-promise`, the loop runs until `--max-iterations`. If you omit `--verify-command`, the promise alone gates completion. You can omit both to run for a fixed number of iterations.

## Options

| Flag | What it does | Default |
|------|-------------|---------|
| `--speed fast\|efficient\|quality` | Default model tier for unnamed agents: `fast`=haiku, `efficient`=sonnet, `quality`=opus | efficient |
| `--max-iterations N` | Hard stop after N loops | unlimited |
| `--completion-promise 'TEXT'` | Phrase Claude must output in `<promise>TEXT</promise>` tags | none |
| `--verify-command 'CMD'` | Shell command that must exit 0 | none |
| `--team-size N` | Number of teammates (team mode) | 3 |
| `--persona NAME` | Role persona for solo mode | generalist |

`--speed` sets the default model for agents that don't have their own model defined. Named personas (planner, architect, etc.) use the model in their own definition file regardless of this flag — so `--speed fast` won't downgrade the planner to haiku; it stays on opus.

## Commands

| Command | What it does |
|---------|-------------|
| `/ralpha-team:plan <context> [opts]` | Generate or refresh `IMPLEMENTATION_PLAN.md` |
| `/ralpha-team:team <prompt> [opts]` | Start a team session |
| `/ralpha-team:solo <prompt> [opts]` | Start a solo loop |
| `/ralpha-team:cancel` | Kill the active session |
| `/ralpha-team:status` | Check where things stand |
| `/ralpha-team:qa` | Analyze telemetry from last session |

## Team personas

In team mode, the lead assigns roles from `agents/`. Each persona has constrained tools — reviewers can't write files, validators can't modify source — which prevents accidental interference and makes each agent's scope explicit.

- **planner** — reads specs and codebase, identifies gaps, generates the task checklist. Runs on Opus because this is the highest-leverage reasoning step: a bad plan produces a bad build. Read-only.
- **architect** — designs module boundaries, API contracts, and data models. Defines the interfaces implementers will code to. Produces a spec; doesn't write implementation code.
- **implementer** — writes production code to the architect's spec. Scoped to specific files. Multiple implementers can run in parallel on independent modules.
- **tester** — writes test cases. Creative work: what edge cases does this feature need to cover? What regression tests? Separate from the validator precisely because the person writing the tests shouldn't also be the one declaring them passed.
- **validator** — runs the build and test suite mechanically and reports PASS or FAIL. Never writes code. Single-instance (only one at a time, to avoid concurrent build conflicts).
- **reviewer** — reads code and reports findings with file:line references and severity. Read-only. Finds what implementers miss.
- **debugger** — diagnoses failures, identifies root causes, proposes fixes. Called in when the verifier fails and the cause isn't obvious.

A typical team: architect + two implementers + tester + validator. The architect designs first, implementers work in parallel on independent files, tester writes tests for the implemented behavior, validator confirms everything compiles and passes.

File ownership is enforced by convention: each teammate is assigned specific files and told not to touch others. Two agents editing the same file creates merge conflicts and wasted iterations.

## Setting up your project

The agents need to know how to build and test your code. Without this, they'll guess at commands or skip verification. Add a `CLAUDE.md` at your project root:

```markdown
# [Your Project Name]

## Build & Validation

- Build: `npm run build`
- Tests: `npm test`
- Typecheck: `npx tsc --noEmit`
- Lint: `npx eslint src/`

## Architecture

[Key conventions and patterns the agents should follow — naming, file organization,
error handling approach, important constraints. Be specific: "all database access
goes through the repository layer in src/db/" is more useful than "clean architecture".]
```

Every session loads this file automatically. The validator reads the commands. The implementers read the architecture section to match existing patterns.

**Per-edit validation (optional):** The default gate runs at the end of each iteration. If you want errors caught immediately after each file write — before they compound — add `.ralpha-validate.conf`:

```bash
# .ralpha-validate.conf — runs after every Edit/Write on a source file
TYPECHECK_CMD="npx tsc --noEmit 2>&1"
LINT_CMD="npx eslint src/ --quiet 2>&1"
```

This uses Claude Code's PostToolUse hook to fire typecheck and lint after every source file modification. It won't catch test failures (those run at the end of the iteration) but it will catch type errors within seconds of introducing them rather than 10 minutes later. Keep both commands fast — the hook has a 30-second timeout.

## QA telemetry

Every session writes structured event logs to `.claude/ralpha-qa.jsonl`. These capture timing, verification results, iteration counts, and completion signals throughout the session.

After a session ends, run:

```bash
/ralpha-team:qa
```

This analyzes the logs and generates `.claude/ralpha-qa-findings.md` with a health score (0–100) and prioritized findings. The patterns it detects:

- **Stuck loops** — many iterations with no file changes (agent is spinning without progress)
- **Flaky verification** — the verify command alternates pass/fail (suggests a non-deterministic test or a race condition)
- **Excessive iterations** — task took far longer than expected (scope was too large or the objective was ambiguous)
- **Idle waste** — team mode teammates sitting unassigned (decomposition left tasks ungated or blocked)
- **Quick completion** — finishes in 1–2 iterations (either the task was trivial or the verify command is too weak)

The report ends with a suggested follow-up command. Run it after sessions that struggled, and use the findings to tighten the objective or verify command before the next run.

## How a session flows

What actually happens when you run `/ralpha-team:solo`:

1. The setup script writes a state file (`.claude/ralpha-team.local.md`) with your objective, iteration counter, promise phrase, and verify command.
2. Claude starts, reads the state file and any `IMPLEMENTATION_PLAN.md`, and begins working.
3. When Claude finishes and tries to exit, the stop hook intercepts. It checks whether Claude emitted the promise phrase and whether the verify command passes.
4. If both pass: session ends, QA report generates, state file deletes.
5. If either fails: iteration counter increments, the failure output is injected as context, and Claude is re-invoked with the same objective. It sees the failure and tries again.
6. If `--max-iterations` is hit: session ends with a report showing where it got stuck.

Between iterations, Claude's context is fresh — it doesn't remember the previous iteration's reasoning, but it can see the commits it made. The iteration counter tells it how many attempts have been made. The injected failure output tells it what went wrong.

## Components

| Category | Count | Location |
|----------|-------|----------|
| Commands | 6 | `commands/` — plan, team, solo, cancel, status, qa |
| Agents | 7 | `agents/` — planner, architect, implementer, tester, validator, reviewer, debugger |
| Hooks | 6 | `hooks/` — post-tool-validate, session-start, stop, task-completed, teammate-idle, pre-compact |
| Scripts | 6 | `scripts/` — setup, parsing, verification, QA logging, QA analysis, quality eval |
| Tests | 110 | `.tests/` — 11 test files, run with `bash .tests/test-runner.sh` |

The only external dependency is `jq`. No build step.

## Troubleshooting

**"jq: command not found"**
`brew install jq` on macOS, `apt install jq` on Linux.

**Loop won't stop**
`/ralpha-team:cancel` ends the session and generates a report. If the hook is stuck, delete `.claude/ralpha-team.local.md` manually — the next stop will detect no active session and exit cleanly.

**Teammates idle in team mode**
Check that tasks in the task list are unblocked (`blockedBy` is empty) and unassigned (`owner` is empty). The idle hook nudges stuck teammates, but if every task is already claimed or blocked behind an incomplete dependency, they have nothing to pick up. Break large blocked tasks into smaller independent ones, or reassign.

**Verification passes but the loop doesn't stop**
The promise phrase must also match. Check that Claude is outputting `<promise>EXACT PHRASE</promise>` with the exact text you set in `--completion-promise` (comparison is case-insensitive). The tags are required — the phrase appearing in plain text doesn't trigger the gate.

**Verification keeps failing after many iterations**
Run `/ralpha-team:qa` to see the pattern. Stuck loops usually mean the objective is too vague (the agent doesn't know what "done" looks like) or the verify command tests something different from what's being built. Try running the plan command first to produce a clearer task breakdown.

## Background

This is a port of [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) to Claude Code's plugin system. The loop idea comes from Geoffrey Huntley's Ralph technique. This version uses Claude Code's native primitives throughout: the hook API for loop control, `TeamCreate`/`Agent`/`TaskCreate` for coordination, and the dual-gate completion check rather than a custom exit-signal format.

The hardest implementation problems were all in the state file. It stores YAML frontmatter (machine-readable session metadata) and a freeform prompt body in the same file, separated by `---`. The prompt can contain `---`, `iteration:`, and other strings that look like frontmatter. Every read and write has to be scoped strictly to the frontmatter section using an `awk` pattern — otherwise a prompt about YAML files will corrupt the session state.

## Updating

```bash
/plugin update ralpha-team
```

## License

MIT

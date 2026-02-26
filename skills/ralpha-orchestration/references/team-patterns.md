# Team Configuration Patterns

## Pattern: Parallel Specialists

Best for feature development where different aspects can be worked on simultaneously.

```
Architect (1) → designs, creates task list
Implementer (2) → each owns a module, works in parallel
Tester (1) → writes tests for completed modules
```

The architect finishes first and goes idle. The tester starts once implementers have something to test.

## Pattern: Pipeline

Best for sequential workflows where each stage feeds the next.

```
Stage 1: Architect designs → creates spec files
Stage 2: Implementer builds → creates code files
Stage 3: Tester validates → creates test files
Stage 4: Reviewer checks → reports findings
```

Use task dependencies to enforce ordering.

## Pattern: Swarm

Best for large independent tasks (e.g., migrating many files, adding tests to many modules).

```
Implementer (4) → each claims tasks from a shared pool
```

All teammates are the same persona. They self-coordinate through the task list.

## Pattern: Adversarial Review

Best for debugging and investigation.

```
Debugger (3) → each investigates a different hypothesis
Reviewer (1) → challenges each debugger's findings
```

The adversarial structure prevents anchoring on the first plausible explanation.

## Anti-Patterns

- **Too many teammates**: >5 teammates creates coordination overhead that outweighs parallelism
- **Shared file ownership**: Two teammates editing the same file leads to overwrites
- **No verification**: Without `--verify-command`, there's no objective quality check
- **No max-iterations**: Always set a safety limit for overnight runs

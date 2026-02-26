# Team Configuration Patterns

## Parallel Specialists
Best for feature development with separable concerns.
```
Architect (1) → designs, creates task list
Implementer (2) → each owns a module, works in parallel
Tester (1) → writes tests for completed modules
```

## Pipeline
Best for sequential workflows where each stage feeds the next.
```
Architect → spec files → Implementer → code → Tester → tests → Reviewer → findings
```

## Swarm
Best for large independent tasks (migrating files, adding tests across modules).
```
Implementer (4) → each claims tasks from a shared pool
```
All same persona. Self-coordinate through the task list.

## Adversarial Review
Best for debugging and investigation.
```
Debugger (3) → each investigates a different hypothesis
Reviewer (1) → challenges each debugger's findings
```

## Anti-Patterns
- **>5 teammates**: coordination overhead outweighs parallelism
- **Shared file ownership**: two teammates editing the same file leads to overwrites
- **No verification**: no objective quality check without `--verify-command`
- **No max-iterations**: always set a safety limit for overnight runs

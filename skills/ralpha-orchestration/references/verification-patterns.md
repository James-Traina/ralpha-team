# Verification Command Patterns

## By Project Type

### Node.js / TypeScript
```bash
--verify-command 'npm test'
--verify-command 'npm test && npm run lint'
--verify-command 'npm test && npm run build'
--verify-command 'npx tsc --noEmit && npm test'
```

### Python
```bash
--verify-command 'pytest'
--verify-command 'pytest && mypy src/'
--verify-command 'pytest --cov=src --cov-fail-under=80'
--verify-command 'ruff check . && pytest'
```

### Rust
```bash
--verify-command 'cargo test'
--verify-command 'cargo clippy -- -D warnings && cargo test'
--verify-command 'cargo build && cargo test'
```

### Go
```bash
--verify-command 'go test ./...'
--verify-command 'go vet ./... && go test ./...'
```

### Multi-step Verification
```bash
--verify-command 'npm run lint && npm test && npm run build'
```

## Writing Good Verification Commands

- **Fast feedback**: the command runs on every completion attempt. Keep it under 60 seconds.
- **Deterministic**: the same code should always produce the same result.
- **Comprehensive**: test the actual objective, not just syntax.
- **Exit code**: 0 = pass, non-zero = fail. Most test frameworks do this by default.

## Completion Promise Examples

| Objective | Promise |
|-----------|---------|
| Build a REST API | `ALL ENDPOINTS WORKING` |
| Fix a bug | `BUG FIXED AND TESTS PASSING` |
| Add test coverage | `COVERAGE ABOVE 80 PERCENT` |
| Refactor module | `REFACTOR COMPLETE` |
| Migrate database | `MIGRATION APPLIED AND VERIFIED` |

Keep promises specific and verifiable. "DONE" is too vague — "ALL TESTS PASSING" is better.

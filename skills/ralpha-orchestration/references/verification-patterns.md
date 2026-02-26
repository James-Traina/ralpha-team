# Verification Command Patterns

## By Language

| Language | Examples |
|----------|---------|
| Node/TS | `npm test`, `npx tsc --noEmit && npm test`, `npm test && npm run lint` |
| Python | `pytest`, `ruff check . && pytest`, `pytest --cov=src --cov-fail-under=80` |
| Rust | `cargo test`, `cargo clippy -- -D warnings && cargo test` |
| Go | `go test ./...`, `go vet ./... && go test ./...` |

Chain multiple checks: `npm run lint && npm test && npm run build`

## Guidelines

- **Fast**: runs on every completion attempt -- keep under 60 seconds
- **Deterministic**: same code produces same result
- **Comprehensive**: test the actual objective, not just syntax
- **Exit code**: 0 = pass, non-zero = fail (most test frameworks do this by default)

## Completion Promise Examples

| Objective | Promise |
|-----------|---------|
| Build a REST API | `ALL ENDPOINTS WORKING` |
| Fix a bug | `BUG FIXED AND TESTS PASSING` |
| Add test coverage | `COVERAGE ABOVE 80 PERCENT` |
| Refactor module | `REFACTOR COMPLETE` |

Keep promises specific and verifiable -- "ALL TESTS PASSING" is better than "DONE".

# AI Agent Guide

Audience: AI coding agents working in `aicage-image`. Keep user-facing info in `README.md`; use this
doc plus `DEVELOPMENT.md` for build/test workflow details.

## How to work

- Read `DEVELOPMENT.md` for prerequisites, commands, and configuration (`config.yml`).
- Use `rg` for searches; avoid destructive commands and do not revert user changes.
- Follow repo style: Bash scripts with `#!/usr/bin/env bash`, `set -euo pipefail`, two-space indents;
  Dockerfiles declare args at the top; Markdown wraps near ~100 chars.

## Testing

- Run `scripts/test-all.sh` after changing installers, Dockerfiles, or entrypoints.
- For targeted checks, `scripts/test.sh --image <tag> --agent <agent>`; mention any tests you could not
  run.

## Adding or updating agents

- New agent steps live in `DEVELOPMENT.md` (installer + smoke tests). Keep smoke coverage in
  `tests/agents/smoke/<agent>.bats`.
- Coordinate base changes with `aicage-image-base`; this repo consumes published `<base>`
  tags.

## Notes

- Keep comments minimal and only where behavior is non-obvious.
- Document command-line invocations you execute when relevant to the change.

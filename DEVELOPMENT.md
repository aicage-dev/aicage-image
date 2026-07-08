# Development Guide

This repository builds the final agent images. Use it when you need to change agent installers,
adjust Dockerfiles, or update smoke tests.

## Prerequisites

- Docker (`docker --version`).
- QEMU/binfmt for multi-arch builds (often installed with Docker Desktop).
- Bats (`bats --version`) for smoke suites.
- yq (`yq --version`) for parsing config and agent metadata.
- Python 3.11+ with `pip install -r requirements-dev.txt` to pull lint/test tooling.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
```

## Repo layout

- `Dockerfile` — Build entrypoint for agent images.
- `agents/<agent>/install.sh` — Installer for each agent.
- `agents/<agent>/agent.yml` — Key/value metadata labels baked into the image.
- `scripts/` — Build and test helpers.
- `tests/agents/smoke/` — Bats suites that verify each agent’s image.
- `config.yml` — Default repositories, platforms, and version tags.

## Configuration

Setting from `config.yml`:

- `AICAGE_IMAGE_REGISTRY` (default `ghcr.io`)
- `AICAGE_IMAGE_BASE_REPOSITORY` (default `aicage/aicage-image-base`)
- `AICAGE_IMAGE_BASE_SOURCE_REPOSITORY` (default `aicage/aicage-image-base`)
- `AICAGE_IMAGE_REPOSITORY` (default `aicage/aicage`)
- `AICAGE_IMAGE_SOURCE_REPOSITORY` (default `aicage/aicage-image`)
- Image tags use the agent version from `agents/<agent>/version.sh`.

Base aliases are discovered from the latest release artifact
`https://github.com/<base-repo>/releases/latest/download/bases.tar.gz`.

## Fork Setup

To test releases from a fork:

1. Fork the repository.
1. Enable GitHub Actions on the fork.
1. Update `config.yml` for the fork namespace, for example:

   ```yaml
   AICAGE_IMAGE_BASE_REPOSITORY: aicage-dev/aicage-image-base
   AICAGE_IMAGE_BASE_SOURCE_REPOSITORY: aicage-dev/aicage-image-base
   AICAGE_IMAGE_REPOSITORY: aicage-dev/aicage
   AICAGE_IMAGE_SOURCE_REPOSITORY: aicage-dev/aicage-image
   ```

1. Push a Git tag to trigger the publish workflow. Prefer prerelease-style tags such as
   `0.1.0-beta.1` or `0.1.0-alpha.1`.
1. First release action run only:
   - One image building job likely fails with "cannot delete last/only tag of a package".
   - Wait until the action run ends with failure, but many other successful building jobs.
   - Then "Rerun failed jobs" in that action run.
1. Make the published GHCR package public.

## Build

```bash
# Build and load a single agent image (host architecture)
scripts/debug/build.sh --agent codex --base ubuntu

# Build the full agent/base matrix (tags derived from config.yml)
scripts/debug/build-all.sh
```

## Test

```bash
# Test a specific image
scripts/test.sh --image ghcr.io/aicage/aicage:codex-ubuntu --agent codex

# Test the full matrix (tags derived from config.yml and available base aliases)
scripts/test-all.sh
```

Smoke suites live in `tests/agents/smoke/`; use `bats` directly if you need to run one file.

## Adding an agent

1. Create `agents/<agent>/install.sh` (executable) that installs the agent; fail fast on errors.
2. Add `agents/<agent>/agent.yml` with any metadata that should appear as image labels.
   Optional filters: `base_exclude` and `base_distro_exclude` (lists).
3. Add the agent to `AICAGE_AGENTS` in `config.yml` if it isn’t discovered automatically.
4. Add smoke coverage in `tests/agents/smoke/<agent>.bats`.
5. Document the agent in `README.md` if it should be visible to users.

## Working with bases

Base layers come from the configured `AICAGE_IMAGE_BASE_REPOSITORY`. Add or modify bases in that repository, then ensure
the latest release contains `bases.tar.gz` before building here.

## CI

Workflows under `.github/workflows/` dispatch per-agent (`build-agent.yml`) and per-base
(`build.yml`) builds on tag pushes and on schedule. Each pipeline builds and tests native
`amd64`/`arm64` images on matching runners, then publishes a multi-arch manifest.

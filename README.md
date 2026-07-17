# aicage-image

Final Docker images for [aicage](https://github.com/aicage/aicage). These images bundle the agent binaries on top of published
base layers from `ghcr.io/aicage/aicage-image-base`.

## What’s included

- Agents: `agy`, `claude`, `codex`, `copilot`, `crush`, `droid`, `gemini`, `goose`, `opencode`,
  and `qwen`.
- Bases: aliases such as `ubuntu`, `fedora`, and `debian` (discovered from base-layer tags).
- Multi-arch support: `linux/amd64` and `linux/arm64`.

## Tag formats

- `${AICAGE_IMAGE_REPOSITORY:-ghcr.io/aicage/aicage}:<agent>-<base>`
- `${AICAGE_IMAGE_REPOSITORY:-ghcr.io/aicage/aicage}:<agent>-<agent_version>-<base>-<aicage_version>`

Example:

- `ghcr.io/aicage/aicage:codex-ubuntu`
- `ghcr.io/aicage/aicage:codex-0.77.0-ubuntu-0.0.1`

`<agent>-<base>` tags map to the latest published image for an agent and a base.

## Quick start

```bash
docker pull ghcr.io/aicage/aicage:codex-ubuntu

docker run -it --rm \
  -e OPENAI_API_KEY=sk-... \
  -e AICAGE_UID=$(id -u) \
  -e AICAGE_GID=$(id -g) \
  -e AICAGE_USER=$(id -un) \
  -v "$(pwd)":/workspace \
  ghcr.io/aicage/aicage:codex-ubuntu
```

Swap `codex` for any other agent name, and choose any available `<base>` alias.

## Behavior inside the container

- Starts as root, then creates a user matching `AICAGE_UID`/`AICAGE_GID`/`AICAGE_USER` (defaults
  `1000`/`1000`/`aicage`) and switches into it.
- `/workspace` is created and owned by that user; mount your project there.
- With rootless Docker on Linux, the container stays on uid `0` but keeps the host-style `HOME`
  path so bind-mounted workspaces and agent config locations continue to behave as expected.

## Contributing

See `DEVELOPMENT.md` for build, test, and release guidance. AI coding agents should also read
`AGENTS.md`.

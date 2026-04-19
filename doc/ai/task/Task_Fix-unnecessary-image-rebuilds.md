# Action ' Refresh Agent Images (Agent Versions)' builds images too often

## Situation

Latest release of this repo here `aicage-image` is `1.0.11` released 10 days ago.

On GitHub by external trigger, `.github/workflows/refresh-images-worker.yml` runs every 10 minutes checking if images
need rebuilding and rebuilds them if needed.

Rebuilding such images will trigger 5GB image pulls for all users of `aicage` (`../aicage`) when they start `aicage` with
such an image - so we must avoid unneccessary rebuilds!

But just today when using image `ghcr.io/aicage/aicage:codex-fedora` and starting `aicage` several time I suddenly had
2 pulls and am looking into why.

The 3 action runs right  below ran after each other in roughly 10 minute intervals.  

While `codex-fedora` is not directly in them (probably in another action run today) I am puzzled by the `is missing`
outputs. Why should those images be missing with a 10d old release where since then every 10 minutes that check was
performed?

To me this rather looks like something went wrong in our `needs rebuild` check.

## Task

### Analyse

Analyse what is going on by looking at the actions run and the code.  
Present me your findings for discussion.

> Read `../secrets` for a PAT to read run logs. Please say if reading logs
> does not work so I can fix problems with the PAT.

### Update Code

If we can't directly identify an issue from the lgos we might have to add code which gives us more information once the
problem pops up again.

We could for example:

- add a wf-dispatch input. `is missing` would then only be allowed by with this flag and result in failure on scheduled
  runs (wf-dispatch).
- combine with extra output on what's going on when `is missing` situation occurs by the preceding operations.

Once we agree on the analysis, implement fixes/updates by:

1. Presenting me each before implementation for discussion
2. Implementing each, tell me when you're done
3. I review git-diff interactive with you reaciting to my findings
4. You commit when I say so

## Task workflow

You shall follow this order:

1. Read documentation and code to understand the task.
2. Ask me questions if something is not clear to you.
3. Present me with an implementation solution; this needs my approval.
4. Implement the change autonomously including a loop of running-tests, fixing bugs, running tests.
5. Run linters.
6. Present me the change for review.
7. Interactively react to my review feedback.
8. Do not commit any changes unless explicitly instructed by the user.

## Action Runs on GitHub

### Run #11586

[Run link](https://github.com/aicage/aicage-image/actions/runs/24626992496/job/72007643245)

```text
Rebuild reason for goose (fedora):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:fedora
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:goose-1.31.0-fedora-1.0.11
  ghcr.io/aicage/aicage:goose-1.31.0-fedora-1.0.11 is missing
Needs build goose (fedora) for 1.0.11
Rebuild reason for gemini (alpine):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:alpine
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-alpine-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-alpine-1.0.11 is missing
Needs build gemini (alpine) for 1.0.11
Rebuild reason for crush (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:crush-0.60.0-ubuntu-1.0.11
  ghcr.io/aicage/aicage:crush-0.60.0-ubuntu-1.0.11 is missing
Needs build crush (ubuntu) for 1.0.11
```

### Run #11585

[Run link](https://github.com/aicage/aicage-image/actions/runs/24626813731)

Found no images need rebuilding.

### Run #11584

[Run link](https://github.com/aicage/aicage-image/actions/runs/24626633750/job/72006670790)

```text
Rebuild reason for goose (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:goose-1.31.0-ubuntu-1.0.11
  ghcr.io/aicage/aicage:goose-1.31.0-ubuntu-1.0.11 is missing
Needs build goose (ubuntu) for 1.0.11
Rebuild reason for crush (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:crush-0.60.0-ubuntu-1.0.11
  ghcr.io/aicage/aicage:crush-0.60.0-ubuntu-1.0.11 is missing
Needs build crush (ubuntu) for 1.0.11
Rebuild reason for gemini (alpine):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:alpine
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-alpine-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-alpine-1.0.11 is missing
Needs build gemini (alpine) for 1.0.11
Rebuild reason for gemini (debian):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:debian
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-debian-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-debian-1.0.11 is missing
Needs build gemini (debian) for 1.0.11
Rebuild reason for gemini (fedora):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:fedora
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-fedora-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-fedora-1.0.11 is missing
Needs build gemini (fedora) for 1.0.11
Rebuild reason for gemini (node):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:node
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-node-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-node-1.0.11 is missing
Needs build gemini (node) for 1.0.11
Rebuild reason for gemini (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:gemini-0.38.2-ubuntu-1.0.11
  ghcr.io/aicage/aicage:gemini-0.38.2-ubuntu-1.0.11 is missing
Needs build gemini (ubuntu) for 1.0.11
Rebuild reason for goose (debian):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:debian
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:goose-1.31.0-debian-1.0.11
  ghcr.io/aicage/aicage:goose-1.31.0-debian-1.0.11 is missing
Needs build goose (debian) for 1.0.11
Rebuild reason for goose (fedora):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:fedora
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:goose-1.31.0-fedora-1.0.11
  ghcr.io/aicage/aicage:goose-1.31.0-fedora-1.0.11 is missing
Needs build goose (fedora) for 1.0.11
Rebuild reason for goose (node):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:node
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:goose-1.31.0-node-1.0.11
  ghcr.io/aicage/aicage:goose-1.31.0-node-1.0.11 is missing
Needs build goose (node) for 1.0.11
Rebuild reason for opencode (alpine):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:alpine
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:opencode-1.14.18-alpine-1.0.11
  ghcr.io/aicage/aicage:opencode-1.14.18-alpine-1.0.11 is missing
Needs build opencode (alpine) for 1.0.11
Rebuild reason for opencode (debian):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:debian
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:opencode-1.14.18-debian-1.0.11
  ghcr.io/aicage/aicage:opencode-1.14.18-debian-1.0.11 is missing
Needs build opencode (debian) for 1.0.11
Rebuild reason for opencode (fedora):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:fedora
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:opencode-1.14.18-fedora-1.0.11
  ghcr.io/aicage/aicage:opencode-1.14.18-fedora-1.0.11 is missing
Needs build opencode (fedora) for 1.0.11
Rebuild reason for opencode (node):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:node
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:opencode-1.14.18-node-1.0.11
  ghcr.io/aicage/aicage:opencode-1.14.18-node-1.0.11 is missing
Needs build opencode (node) for 1.0.11
Rebuild reason for opencode (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:opencode-1.14.18-ubuntu-1.0.11
  ghcr.io/aicage/aicage:opencode-1.14.18-ubuntu-1.0.11 is missing
Needs build opencode (ubuntu) for 1.0.11
Rebuild reason for qwen (alpine):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:alpine
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:qwen-0.14.5-alpine-1.0.11
  ghcr.io/aicage/aicage:qwen-0.14.5-alpine-1.0.11 is missing
Needs build qwen (alpine) for 1.0.11
Rebuild reason for qwen (debian):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:debian
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:qwen-0.14.5-debian-1.0.11
  ghcr.io/aicage/aicage:qwen-0.14.5-debian-1.0.11 is missing
Needs build qwen (debian) for 1.0.11
Rebuild reason for qwen (fedora):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:fedora
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:qwen-0.14.5-fedora-1.0.11
  ghcr.io/aicage/aicage:qwen-0.14.5-fedora-1.0.11 is missing
Needs build qwen (fedora) for 1.0.11
Rebuild reason for qwen (node):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:node
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:qwen-0.14.5-node-1.0.11
  ghcr.io/aicage/aicage:qwen-0.14.5-node-1.0.11 is missing
Needs build qwen (node) for 1.0.11
Rebuild reason for qwen (ubuntu):
  [needs-rebuild]: base_image=ghcr.io/aicage/aicage-image-base:ubuntu
  [needs-rebuild]: final_image=ghcr.io/aicage/aicage:qwen-0.14.5-ubuntu-1.0.11
  ghcr.io/aicage/aicage:qwen-0.14.5-ubuntu-1.0.11 is missing
Needs build qwen (ubuntu) for 1.0.11
```

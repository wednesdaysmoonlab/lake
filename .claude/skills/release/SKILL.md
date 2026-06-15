---
name: release
description: Drive Lake's release lifecycle (start feature, bump version, open PR into main, tag the release). Use when the user wants to start a feature branch, bump the version, open a PR into main, or tag/cut a release. Wraps the ./release bash CLI.
---

# release

Thin wrapper over the repo's `./release` bash CLI. The script is the source of truth —
this skill just maps natural-language requests to the right subcommand and runs it.
Always run from the repo root.

The flow is `feature/* → main (PR, squash) → tag → release`. There is no `pre-release` branch.

## Commands

| User intent | Run |
|---|---|
| "start a feature called X" / "new feature X" | `./release start X` |
| "bump patch/minor/major" / "bump to X.Y.Z" | `./release bump <level>` |
| "open the PR" / "PR this into main" | `./release pr` |
| "tag the release" / "PR is merged, finish it" / "ship it" | `./release tag` |
| "where are we" / "release status" | `./release status` |

## Rules

- The script prompts for confirmation on destructive steps (push tag) via `/dev/tty`.
  Run it so the user can answer those prompts — do not try to auto-answer or pipe input.
- Feature branches always come off `main` (project rule in `.note`). `bump` commits the
  version on the feature branch.
- `main` is protected — changes must go through a PR. `pr` opens a feature PR into
  `main`; the user reviews and squash-merges it on GitHub (a review may be required by
  the ruleset). Once merged, run `./release tag` to tag the merged `main` and trigger
  the release build. Nothing pushes commits to `main` directly.
- A full release is: `./release bump <level>` → `./release pr` → (merge on GitHub) →
  `./release tag`.
- If `gh` is missing or not authed, `./release pr` will say so — relay that, don't
  work around it.

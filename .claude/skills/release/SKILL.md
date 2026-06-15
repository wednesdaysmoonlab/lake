---
name: release
description: Drive Lake's release lifecycle (start feature, open PR, bump version, ship release). Use when the user wants to start a feature branch, open a PR into pre-release, bump the version, or cut/ship a release. Wraps the ./release bash CLI.
---

# release

Thin wrapper over the repo's `./release` bash CLI. The script is the source of truth —
this skill just maps natural-language requests to the right subcommand and runs it.
Always run from the repo root.

## Commands

| User intent | Run |
|---|---|
| "start a feature called X" / "new feature X" | `./release start X` |
| "open the PR" / "PR this into pre-release" | `./release pr` |
| "bump patch/minor/major" / "bump to X.Y.Z" | `./release bump <level>` |
| "ship it" / "cut the release" / "release a minor" | `./release bump <level> && ./release ship` |
| "tag the release" / "PR is merged, finish it" | `./release tag` |
| "where are we" / "release status" | `./release status` |

## Rules

- The script prompts for confirmation on destructive steps (merge to main, push tag)
  via `/dev/tty`. Run it so the user can answer those prompts — do not try to
  auto-answer or pipe input.
- Feature branches always come off `main` (project rule in `.note`). `bump` commits
  on `pre-release`.
- `main` is protected — changes must go through a PR. `ship` opens a release PR
  (pre-release → main) and squash-merges it, then tags. If the ruleset requires an
  approving review, `gh pr merge` will fail; tell the user to approve/merge the PR
  on GitHub, then run `./release tag` to finish.
- For a full release the user has usually already merged their PRs into `pre-release`.
  Confirm that before running `bump` + `ship` if unsure.
- If `gh` is missing or not authed, `./release pr` will say so — relay that, don't
  work around it.

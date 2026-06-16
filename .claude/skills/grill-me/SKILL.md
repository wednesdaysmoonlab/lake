---
name: grill-me
description: "Grill the user about a new Lake feature before any code or branch exists, then plan it and cut the feature branch. Use when the user wants to start a new feature, stress-test a feature idea, get grilled on a design, says \"grill me\", or asks to plan/scope work on the lakeup bootstrap."
trigger: /grill-me
---

# /grill-me

You are about to start a NEW feature for **Lake** (the single-file `lakeup` bash bootstrap).
Before any code or branch is created, your job is to **grill the user** until the feature is
sharp, then plan it and cut the branch. Do not be a pushover — push back on vague answers.

## Usage

```
/grill-me [short feature idea]
```

The user's rough idea may be passed as an argument (and may be empty). If it's empty, start by
asking what the feature is. Skim `CLAUDE.md`, `lakeup`, and `.note` as needed to ground your
questions in how the project actually works.

## Step 1 — Grill (do not skip)

Interrogate the idea until you could write the feature yourself. Ask in focused rounds
(use the AskUserQuestion tool when options are discrete; plain questions otherwise — and ask
one thing at a time when a question opens new branches). If a question can be answered by
exploring the codebase, explore the codebase instead of asking. Keep grilling until each of
these is unambiguous — challenge hand-wavy answers:

1. **Problem** — What concretely breaks or annoys without this? Who hits it? Is it real or hypothetical?
2. **Scope** — What is explicitly IN, and what is OUT for this first cut? Smallest shippable version?
3. **Fit with Lake's constraints** — Does it belong in a *single-file bash script* with **zero host deps** (no host PHP/Docker/Composer)? Must keep working via `curl | bash`. Must run on **macOS and Linux** (x86_64 + arm64). If it needs an external script or download, that's a red flag — challenge it.
4. **When does it run** — Bootstrap-time (inside `./lakeup`) or a daily `.lake/` shim command? One-time or every run?
5. **Interactivity** — Does it prompt the user? Remember: FrankenPHP php-cli doesn't pass the TTY, and `laravel/prompts` silently falls back — direct `/dev/tty` reads in bash are the only reliable prompt. Should it be non-interactive by default?
6. **Idempotency & re-runs** — What happens on a second `./lakeup`? How does it interact with `purge` / `clean`? Should it be guarded by a marker file?
7. **Output** — User-facing lines must use the `_say` helper (sky-blue ✦). Confirm any new messaging follows that.
8. **Testing** — What bats unit/integration test proves it works? What's the failure mode if it breaks?
9. **Semver** — Is this a fix (patch), feature (minor), or breaking change (major)?

## Step 2 — Plan

Once grilled, present a tight plan: the problem in one line, what's in/out, the files/sections
of `lakeup` you'll touch, the test you'll add, and the semver level. Get a quick thumbs-up.

## Step 3 — Create the branch

Derive a short **kebab-case** branch name from the agreed feature (e.g. `add-deploy-command`).
Confirm the name with the user, then run:

```
./release start <kebab-name>
```

This branches `feature/<name>` off `main` (the project's flow is `feature/* → main`; see `.note`).
Confirm you're on the new branch, then tell the user they're ready to build — and that when done
the release path is `./release bump <level>` → `./release pr` → merge → `./release tag`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Lake is a single-file bash bootstrap script (`lakeup`) that provisions a full Laravel + FrankenPHP development environment with zero host-level dependencies (no PHP, no Docker, no Composer required).

## Releasing

Releases are automated via `.github/workflows/release.yml`. When a version tag is pushed, GitHub Actions creates a release and attaches `lakeup` as the only downloadable asset.

The whole lifecycle is wrapped by the **`./release` CLI** — prefer it over running the git steps by hand:

```bash
./release start <name>   # branch feature/<name> off main
./release bump <level>   # patch|minor|major|X.Y.Z — edits LAKE_SETUP_VERSION, commits on the feature branch
./release pr             # push branch + open PR into main
./release tag            # tag main with its current version (after the PR merges)
./release status         # current branch, local version, latest GitHub release
```

The flow is `feature/* → main (PR, squash) → tag → release` — there is no `pre-release` branch. `bump` keeps `LAKE_SETUP_VERSION` in `lakeup` in sync with the git tag — the release workflow fails the build if they mismatch. Destructive steps (push tag) prompt for confirmation. There is also a `release` Claude skill that drives this CLI conversationally.

**`main` is branch-protected — changes must go through a PR.** `pr` opens a feature PR into `main`; review and squash-merge it on GitHub (a review may be required by the ruleset). Once merged, run `./release tag` to tag the merged `main` and trigger the release build. Nothing ever pushes commits to `main` directly.

Once the tag is pushed the release appears at `github.com/<org>/laravel-lake/releases/tag/v1.0.0` with `lakeup` available for direct download.

Users can then install via:
```bash
curl -fsSL https://github.com/<org>/laravel-lake/releases/latest/download/lakeup | bash
```

Use [semver](https://semver.org): `v1.0.0` (breaking), `v1.1.0` (features), `v1.0.1` (fixes).

## Commands

After running `./lakeup` once, the project is set up. Daily commands all go through the `.lake/` shims:

```bash
# Bootstrap (run once in an empty directory)
./lakeup
FRANKEN_VERSION=1.11.2 LAKE_PORT=9000 ./lakeup   # with overrides

# Start dev server (FrankenPHP + queue worker + log viewer + Vite)
.lake/composer run dev

# Artisan
.lake/php artisan <command>

# Composer
.lake/composer require <package>
.lake/composer install

# Tests
.lake/composer run test

# Reset
./lakeup purge    # Remove everything except lakeup and .claude
./lakeup clean    # Remove Laravel files only; keep .lake/ (~170 MB of binaries)
```

## Architecture

The entire bootstrap logic lives in `lakeup`. There is no build step — it is a standalone bash script.

**Key design decisions:**

- `.lake/php` is a shim that exports `PHP_BINARY` (pointing to itself) and strips `-d` flags before delegating to `frankenphp php-cli`. The env-var export works around FrankenPHP leaving the `PHP_BINARY` PHP constant empty.
- `.lake/composer` also sets `PHP_BINARY` and prepends `.lake/` to `PATH` before invoking `frankenphp php-cli composer.phar`. This ensures `@php` hooks in Composer scripts resolve to the shim.
- `.lake/fix-php-binary` is a Composer `post-autoload-dump` hook that patches vendor files using `PHP_BINARY` directly (e.g. `[PHP_BINARY, ...]`) to fall back to the env var. This runs automatically on every `composer install/update/require`.
- `laravel new` is run into a temporary subdirectory (`.laravel_setup_tmp/`) and then moved to the project root — because the installer requires an empty directory.
- The `composer.json` dev script is patched post-install: `php artisan serve` → `.lake/frankenphp run` (FrankenPHP uses a `Caddyfile`; it does not support PHP's built-in `-S` server).
- SQLite is the default database. A `database/database.sqlite` file is created and `migrate` is run automatically.

**Known caveat:** The `PHP_BINARY` PHP constant is empty under FrankenPHP php-cli mode. The `.lake/php` shim exports the env var and `.lake/fix-php-binary` patches vendor call-sites on every Composer dump, so packages like Laravel Boost work out of the box.

## Output style

All user-facing messages in `lakeup` use the `_say` helper instead of plain `echo`:

```bash
_say() { printf '\e[38;5;117m✦\e[0m %s\n' "$*"; }
```

- Color `\e[38;5;117m` is sky blue, matching the ASCII logo palette.
- Use `_say "message"` for every new status/info line added to the script.
- Keep `echo ""` for blank lines and `echo "==="` for decorative separators — those do not use `_say`.
- The `_say` function is defined at the top of the main script body (after the logo), so it is available everywhere including `purge` and `clean` commands.

## Post-install patching

Conditional patches that run after `laravel new` are written **inline in `lakeup`** as bash + `frankenphp php-cli -r "..."` blocks. Do not introduce external PHP scripts or downloads for these — they must work in a single-file bootstrap (including `curl | bash` installs).

Current inline patches:
- **`.mcp.json` command path** — if `.mcp.json` contains `"command": "php"` (written by packages like `laravel/boost`), the user is prompted to rewrite it to `.lake/php`. Uses `read -rp ... </dev/tty` for reliable interactive input and `frankenphp php-cli -r` for the regex replacement.
- **Laravel Boost MCP php binary (`.env` seed)** — Lake offers (default **no**, via `_confirm_no`) to `composer require laravel/boost --dev`. Whenever `vendor/laravel/boost` is present, `_seed_boost_php_path` upserts `BOOST_PHP_EXECUTABLE_PATH="$(pwd)/.lake/php"` into `.env`. Boost resolves *every* agent's MCP `command` from `config('boost.executable_paths.php')` ← `env('BOOST_PHP_EXECUTABLE_PATH')`, so this one line wires all agents (Claude Code, Cursor, Codex, Copilot, Junie, Kiro, Zed, …) to the shim — for the user's own `boost:install`/`boost:update`. An **absolute** path is used because Junie and Amp force absolute MCP command paths. Pure-bash and idempotent (replaces a stale line, appends if missing). Lake does **not** run `boost:install` itself — its agent picker is interactive-only (`laravel/prompts` `multiselect()`), which silently fails under FrankenPHP's broken TTY. The helper is mirrored in `tests/helpers/seed_boost_php_path` (kept in sync) and covered by `tests/unit/boost_env.bats`.

**Why not `laravel/prompts` or external scripts?** FrankenPHP php-cli does not pass the TTY through correctly, so `laravel/prompts`' `confirm()` silently falls back to its default without showing a prompt. Direct `/dev/tty` reads in bash are reliable.

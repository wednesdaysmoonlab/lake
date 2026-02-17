# Lake

**Your machine. Zero PHP. Full Laravel.**

Lake is a zero-dependency Laravel bootstrap powered by [FrankenPHP](https://frankenphp.dev) — a single binary that is the web server, the PHP runtime, and the CLI all at once. No Docker images to pull, no Homebrew formulas to install, no `phpenv` headaches.

Drop `lake.setup` in a folder, run it, answer a few questions about your stack, and walk away with a production-ready Laravel app.

---

## Overview

`lake.setup` bootstraps a full Laravel project in the current directory by:

1. Downloading the FrankenPHP binary for your OS and architecture
2. Installing Composer (as a PHAR, no global install needed)
3. Installing `laravel/installer` — enabling interactive stack selection
4. Running `laravel new` to create the project with your chosen stack (Livewire, Inertia, Breeze, etc.)
5. Patching the `composer run dev` script to use FrankenPHP as the web server
6. Configuring `.env`, running migrations, and setting permissions

All binaries and tools are isolated inside `.lake/` and excluded from git.

---

## Requirements

- macOS or Linux (x86_64 or arm64)
- `curl`
- `node` / `npm` (for frontend assets)

No PHP, no Composer, no Docker needed on the host machine.

---

## Getting Started

### Option A — One-liner (curl)

In an empty directory:

```bash
curl -fsSL https://raw.githubusercontent.com/wednesdaysmoonlab/lake/main/lake.setup | bash
```

### Option B — Download first

Place `lake.setup` in an empty directory and make it executable:

```bash
chmod +x lake.setup
./lake.setup
```

You will be prompted for:

- **Dev server port** — default `8090`, press Enter to accept

Then `laravel new` starts and asks you to choose:

- Starter kit (None, Livewire, Inertia/React, Inertia/Vue, etc.)
- Authentication provider
- Testing framework (Pest / PHPUnit)
- Other stack options

### 3. Start the dev server

```bash
.lake/composer run dev
```

This starts all services concurrently:

| Service | Description |
|---------|-------------|
| **server** | FrankenPHP (reads `Caddyfile`) |
| **queue** | `artisan queue:listen` |
| **logs** | `artisan pail` (log viewer) |
| **vite** | Vite dev server with HMR |

Open your browser at `http://localhost:8090` (or your chosen port).

---

## Daily Usage

### Artisan

```bash
.lake/php artisan make:model Post -m
.lake/php artisan migrate
.lake/php artisan tinker
```

### Composer

```bash
.lake/composer require livewire/livewire
.lake/composer install
```

### Run dev server

```bash
.lake/composer run dev
```

### Run tests

```bash
.lake/composer run test
```

---

## Environment Overrides

You can skip prompts by passing environment variables:

```bash
# Pin a specific FrankenPHP version and set port without being asked
FRANKEN_VERSION=1.11.2 LAKE_PORT=9000 ./lake.setup
```

| Variable | Default | Description |
|----------|---------|-------------|
| `FRANKEN_VERSION` | `latest` | FrankenPHP release to download |
| `LAKE_PORT` | prompt (default `8090`) | Dev server port |

---

## Commands

```bash
./lake.setup help    # Show usage
./lake.setup purge   # Remove everything except lake.setup and .claude
./lake.setup clean   # Remove Laravel files only, keep .lake/ (faster reinstall)
```

### `purge` vs `clean`

| Command | Keeps | Removes |
|---------|-------|---------|
| `purge` | `lake.setup`, `.claude` | Everything including `.lake/` |
| `clean` | `lake.setup`, `.claude`, `.lake/` | All Laravel app files |

Use `clean` when you want to start a fresh Laravel install without re-downloading FrankenPHP and Composer (~170 MB).

```bash
./lake.setup clean
./lake.setup
```

---

## Project Structure

```
your-project/
├── lake.setup          # Bootstrap script (this file)
├── .lake/              # Binaries — excluded from git
│   ├── frankenphp      # FrankenPHP binary (~167 MB)
│   ├── composer.phar   # Composer PHAR
│   ├── php             # PHP shim (delegates to frankenphp php-cli)
│   ├── composer        # Composer shim
│   └── vendor/         # laravel/installer global package
├── Caddyfile           # FrankenPHP server config (generated)
├── artisan             # Laravel CLI entry point
├── composer.json       # PHP dependencies
├── package.json        # Node dependencies
└── ...                 # Standard Laravel project files
```

---

## How It Works

### FrankenPHP as the web server

FrankenPHP embeds PHP and the Caddy web server into a single binary. `lake.setup` creates a `Caddyfile` that routes all requests through `index.php`:

```caddy
{
    frankenphp
    order php_server before file_server
}

http://localhost:8090 {
    root * public
    php_server
}
```

### PHP and Composer shims

Because Composer passes `-d` flags when calling PHP (e.g. `-d allow_url_fopen=1`), and FrankenPHP's `php-cli` mode doesn't support them, `.lake/php` strips those flags before delegating to FrankenPHP.

### Dev script patch

Laravel's default `composer run dev` uses `php artisan serve` (PHP's built-in `-S` web server). `lake.setup` automatically patches `composer.json` to replace it with `.lake/frankenphp run`, which uses the Caddyfile instead.

---

## Known Limitations

- **`php artisan serve`** — Not supported. Use `.lake/frankenphp run` or `composer run dev` instead.
- **Global PHP/Composer** — The `.lake/` shims are project-local. They do not affect any system-installed PHP or Composer.

### PHP_BINARY auto-patcher

FrankenPHP's php-cli mode leaves the `PHP_BINARY` PHP constant as an empty string. Packages that pass this constant directly to `Symfony\Process` (e.g. Laravel Boost, PHPUnit, Collision) would fail with `ValueError: First element must contain a non-empty program name`.

Lake handles this automatically:

1. **`.lake/php` shim** — exports the `PHP_BINARY` environment variable pointing to itself, so `Symfony\PhpExecutableFinder` resolves correctly.
2. **`.lake/fix-php-binary`** — a Composer `post-autoload-dump` hook that patches vendor files using direct `PHP_BINARY` constant references to fall back to the environment variable:
   ```php
   // Before
   PHP_BINARY
   // After
   (getenv('PHP_BINARY') ?: (PHP_BINARY ?: 'php'))
   ```
3. The patches are **backwards-compatible** — on standard PHP (where the env var is unset), the expression falls through to the constant, preserving original behavior.
4. The patches are **re-applied automatically** after every `composer install`, `update`, or `require`.

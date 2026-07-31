[![npm version](https://img.shields.io/npm/v/crypt-sync.svg)](https://www.npmjs.com/package/crypt-sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Quick Start](#quick-start) • [Features](#features) • [Installation](#installation) • [Claude Code Plugin](#claude-code-plugin) • [Usage](#usage) • [How It Works](#how-it-works) • [Troubleshooting](#troubleshooting)

# crypt-sync

Encrypt `.env` and secret files with age, sync them across machines via git.

> 🇹🇷 Türkçe için [README.tr.md](README.tr.md)

**crypt-sync keeps your secrets in git — encrypted.** Instead of `.gitignore`-ing secrets and losing sync, crypt-sync encrypts each file with [age](https://github.com/FiloSottile/age) and commits the `.age` blob to your repo. Pull on any machine, decrypt with your passphrase. No key files to copy. No secret manager to run.

---

## Quick Start

**First machine (new project):**

```bash
npm install -g crypt-sync
crypt-sync init       # once per machine — enter passphrase
cd your-project
crypt-sync setup      # interactive: browse files → select → encrypt → install hooks
git commit -m "add encrypted secrets"
git push
```

**Another machine (existing project):**

```bash
npm install -g crypt-sync
git clone <repo> && cd <repo>
crypt-sync init       # same passphrase → hooks installed + files decrypted automatically
```

**After `npm install -g crypt-sync` update:**

```bash
# Use @latest — npm update -g may use cached metadata
npm install -g crypt-sync@latest

cd your-project
crypt-sync update-hooks   # update .git/hooks/ to the new version
```

---

## Features

| Feature | Description |
|---|---|
| **age encryption** | X25519 + ChaCha20-Poly1305 — modern, audited, fast |
| **Passphrase-derived keys** | Same passphrase → same key on every machine. No key file to copy |
| **Git-native sync** | Encrypted blobs live in your repo. `git push` = sync |
| **Auto hooks** | Encrypts on push, decrypts on pull via git hooks |
| **Smart `init`** | Detects project on first run — installs hooks and decrypts automatically |
| **Interactive setup** | Browse project tree, select files, navigate into subdirectories (`b` to go back, `q` to quit) |
| **Full-path artifacts** | `apps/web/.env` → `apps/web/.env.age` — works on fresh clone with no plaintext present |
| **`update-hooks`** | Sync `.git/hooks/` to the installed version after `npm install -g crypt-sync@latest` |

---

## Requirements

- Node.js ≥ 16
- Git
- [age](https://github.com/FiloSottile/age) — downloaded automatically on `npm install`

Supported platforms: macOS (arm64, x64), Linux (x64, arm64), Windows (x64).

---

## Installation

```bash
npm install -g crypt-sync
```

The postinstall script downloads the correct `age` binary for your platform and verifies its SHA256 checksum against the official release.

**To update:**

```bash
npm install -g crypt-sync@latest   # always use @latest, not npm update -g
```

### Uninstall

```bash
# Remove global package
npm uninstall -g crypt-sync

# Remove identity file
rm -rf ~/.config/crypt-sync
```

---

## Claude Code Plugin

The same repository is also a [Claude Code](https://claude.com/claude-code) plugin. It teaches Claude when to reach for which crypt-sync command, and — more importantly — what never to do with your secrets: it will not run `init` for you (the passphrase must stay between you and your terminal), it will not read decrypted plaintext back to you, and it will not use `--force` or `--wipe` without asking.

```bash
# via the skill-hub marketplace
claude plugin marketplace add sametbrr/skill-hub
claude plugin install crypt-sync@sametbrr/skill-hub

# or straight from this repository
claude plugin install github:sametbrr/crypt-sync
```

**The plugin does not replace the CLI — it requires it.** The plugin is only a skill; encryption, key derivation and the bundled `age` binary all live in the npm package. Two things depend on the CLI being on `PATH`:

- the git hooks look it up with `command -v crypt-sync`
- `age` is fetched by the package's postinstall script (`vendor/` is not in git)

So install the npm package too:

```bash
npm install -g crypt-sync
crypt-sync init
```

If you install only the plugin, nothing breaks loudly — the plugin detects the missing CLI and offers to install it before doing anything else. It also warns at session start when a project has a `.cryptsync` manifest but no CLI, because in that state the git hooks skip **silently**: secrets are not encrypted on push and blobs are not decrypted on pull.

---

## Usage

```
crypt-sync <command> [options]

  init                        Derive encryption identity from passphrase (once per machine)
  setup                       Interactive setup: browse files, encrypt, install hooks
  lock [--all] [--wipe]       Encrypt changed entries and git-add blobs
  unlock [--force]            Decrypt all blobs to plaintext
  status                      Show encryption state for all entries
  clean                       Remove orphan .age blobs not in manifest
  update-hooks                Update git hooks to the current version (run after npm update)
  export-key <path>           Export identity key to a file
  import-key <path>           Import identity key from a file
```

### `init`

Run once per machine. Derives a deterministic age identity from your passphrase using scrypt. The same passphrase always produces the same key — no key file to transfer between machines.

```bash
crypt-sync init
# Passphrase (min 8 chars): ••••••••••
# Identity saved to: ~/.config/crypt-sync/identity.txt
# Recipient: age1...
```

**If run inside a project** (a `.cryptsync` file is found), `init` automatically installs git hooks and runs `unlock`. This means on a new machine you only need one command:

```bash
git clone <repo> && cd <repo>
crypt-sync init   # passphrase → hooks → files unlocked
```

Use `--force` to overwrite an existing identity.

### `setup`

Interactive project setup. Scans the project tree, lets you browse into subdirectories, and writes a `.cryptsync` manifest with full relative paths.

```bash
cd your-project
crypt-sync setup
```

```
Dizin: /
──────────────────────────────────────────
     1.  .mcp.json  ← secret?
     d1.  apps/

> d1          ← navigate into apps/
> d1          ← navigate into apps/bot/
> 1           ← select apps/bot/.env  (full path added)
> b           ← go back one level
> q           ← cancel and quit
> [Enter]     ← finish → encrypts + installs hooks
```

Navigation keys:

| Key | Action |
|---|---|
| `<number>` | Select / deselect file (added as full relative path) |
| `d<number>` | Enter subdirectory |
| `b` or `..` | Go back one level |
| `q` | Cancel and exit setup |
| Enter | Finish selection → encrypt + install hooks |

**If `.cryptsync` already exists** (e.g. you cloned a repo that already uses crypt-sync), `setup` skips the file selection wizard, installs hooks, and runs `unlock`. Use `--force` to re-run the wizard and reconfigure.

### `lock`

Encrypts entries whose content changed since the last lock. Unchanged entries are skipped. Runs `git add` on blobs and metadata automatically.

```bash
crypt-sync lock           # encrypt changed entries
crypt-sync lock --all     # re-encrypt all entries regardless of state
crypt-sync lock --wipe    # also delete plaintext after encrypting
crypt-sync lock --no-add  # skip git add (used internally by hooks)
```

### `unlock`

Decrypts all `.age` blobs in the manifest to plaintext. Creates the plaintext file even if it does not exist yet (safe on fresh clones). Does not overwrite locally modified files without `--force`.

```bash
crypt-sync unlock
crypt-sync unlock --force   # overwrite local plaintext with decrypted version
```

Output messages:

```
  unlocking apps/bot/.env... done          # blob found → decrypted
  not locked: apps/bot/.env               # plaintext exists but no blob → run: crypt-sync lock
  missing: apps/bot/.env.age              # neither blob nor plaintext → lock + push from source machine
```

### `status`

Shows per-entry state and warns about orphan blobs.

```bash
crypt-sync status
# .mcp.json             locked   (unchanged)
# apps/web/.env         locked   (changed — run lock)
# apps/api/.env         missing blob — run lock
```

### `update-hooks`

Updates the git hooks in `.git/hooks/` to match the currently installed crypt-sync version. Handles both new-style (`# crypt-sync hook`) and old-style (`# env-crypt hook`) sentinels. Run this after upgrading crypt-sync.

```bash
crypt-sync update-hooks
#   hook pre-commit: updated
#   hook pre-push: updated
#   hook post-merge: updated
#   hook post-checkout: updated
```

### `export-key` / `import-key`

Transfer your identity to another machine without re-deriving from passphrase.

```bash
crypt-sync export-key ~/key-backup.txt   # keep this file safe
crypt-sync import-key ~/key-backup.txt
```

---

## Configuration

Create a `.cryptsync` file in your project root. Lines starting with `#` are comments. Commit this file — all machines need to agree on what is managed.

```
# crypt-sync manifest
apps/bot/.env
apps/bot/.env.development
apps/dashboard-api/.env
apps/dashboard-api/.env.development
.mcp.json
secrets/              # encrypt entire directory as one archive
*.pem                 # glob pattern
```

**Pattern rules:**

| Pattern | Behaviour |
|---|---|
| `apps/bot/.env` (with slash) | Exact path relative to project root — recommended |
| `.env` (no slash) | Basename match — encrypts every `.env` in the entire tree |
| `secrets/` (trailing slash) | Directory — produces a single `.cryptsync.tar.age` archive |
| `*.pem` | Glob — matches files in project root only |
| `**/*.pem` | Recursive glob |

> **Tip:** Use full relative paths (e.g. `apps/bot/.env`) rather than basename patterns (`.env`). Basename patterns depend on the plaintext file existing on disk to resolve correctly, which breaks on fresh clones before the first `unlock`.

---

## How It Works

```
passphrase
    │  scrypt(N=65536, r=8, p=1)
    ▼
32-byte key → X25519 clamp → Bech32 → AGE-SECRET-KEY-1…
    │
    ├── age encrypt -r <recipient>  →  apps/bot/.env.age   (committed to git)
    │
    └── age decrypt -i identity.txt ← apps/bot/.env.age   (on pull)
```

1. **`init`** — derives a deterministic age identity from your passphrase using scrypt. Stored in `~/.config/crypt-sync/identity.txt` (mode 0600, directory mode 0700). If a `.cryptsync` project is detected, installs hooks and runs `unlock` automatically.
2. **`setup`** — walks the project tree, lets you select files with an interactive browser (full paths), writes `.cryptsync`, installs hooks, runs initial `lock`. If `.cryptsync` already exists, skips the wizard and runs hook install + `unlock`.
3. **`lock`** — for each changed entry: computes SHA256, compares with ledger (`.cryptsync.state`), encrypts with `age -r <recipient>`, runs `git add` on blobs.
4. **`unlock`** — decrypts each `.age` blob atomically via temp file + rename. Creates parent directories if needed. Updates the ledger so the next `lock` is a no-op.
5. **Hooks** — `pre-push` runs `lock --no-add`, `post-merge` / `post-checkout` run `unlock`. `pre-commit` aborts if any managed plaintext file is staged.
6. **Ledger** — `.cryptsync.state` (gitignored) tracks the SHA256 hash of each plaintext entry. Unchanged files are never re-encrypted, preventing noisy git diffs.

---

## Troubleshooting

**`age binary not found`** — The postinstall script failed silently. Re-run it:

```bash
npm rebuild crypt-sync
```

Or install age manually from [github.com/FiloSottile/age/releases](https://github.com/FiloSottile/age/releases) and ensure it is on your `PATH`.

**`Error: identity not found`** — Run `crypt-sync init` on this machine first.

**`unlock` shows `missing: .env.age`** — The blob was never committed to git. On the source machine:

```bash
crypt-sync lock
git add .env.age
git push
```

**`unlock` shows `not locked: .env`** — The plaintext file exists locally but was never encrypted. Run:

```bash
crypt-sync lock
```

**`git pull` does not decrypt files** — The git hooks are not installed or are outdated. Run:

```bash
crypt-sync update-hooks
```

**After `npm install -g crypt-sync@latest`, hooks still behave as before** — `npm install` updates the package but not the hooks already installed in `.git/hooks/`. Run `crypt-sync update-hooks` in each project.

**`unlock` produces wrong plaintext / decryption fails** — `crypt-sync status` prints the recipient fingerprint. Compare it with the fingerprint on the machine that ran `lock`. If they differ, the passphrases are different.

**`pre-commit` aborts with "Plaintext secret file staged"** — A managed plaintext file was accidentally staged:

```bash
git reset HEAD .env     # unstage
crypt-sync lock          # encrypt first
git add .env.age        # stage the blob instead
git commit
```

**`unlock` refuses to overwrite my local file** — By default unlock skips files that differ locally. Use `--force` only when you intentionally want to replace your local edits:

```bash
crypt-sync unlock --force
```

---

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://github.com/sametbrr/crypt-sync/issues">Report Bug</a> ·
  <a href="https://github.com/sametbrr/crypt-sync/issues">Request Feature</a>
</p>

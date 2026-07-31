---
name: crypt-sync
description: Keep .env and secret files encrypted in git and synced across machines with age, via the crypt-sync CLI. Use when the user wants to commit secrets safely instead of gitignoring them, share secrets with a team through git, recover secrets on a fresh clone or a new machine, or inspect a project that contains a .cryptsync manifest or .age blobs. Also use when a crypt-sync git hook misbehaves — pre-commit aborts with "plaintext secret file staged", pre-push does not encrypt, git pull does not decrypt, unlock reports "missing" or "not locked", or secrets differ between machines. Triggers: "crypt-sync", ".env şifrele", "secretları git'e şifreli koy", "secret sync", "yeni makinede .env yok", "encrypt my env files", "share secrets through git", "decrypt failed after pull".
---

# crypt-sync

Encrypts each managed secret file with [age](https://github.com/FiloSottile/age) and commits the `.age` blob to git. The key is derived from a passphrase with scrypt, so the same passphrase yields the same identity on every machine — nothing to copy around.

**This plugin is the decision layer only. The engine is the `crypt-sync` npm package.** All encryption, key derivation, git-hook installation and the bundled `age` binary live there. Never try to reimplement any of it here.

---

## Gate 0 — the CLI is required (do not skip)

Before anything else, run:

```bash
command -v crypt-sync
```

**Found** → go to Gate 1.

**Not found** → stop. Do not install it silently; a global npm install changes the user's system. Ask first (AskUserQuestion):

> "The crypt-sync CLI is not installed. Install it with `npm install -g crypt-sync`?"

- **Approved** → run `npm install -g crypt-sync`. Its postinstall downloads the platform `age` binary and verifies its SHA256 against the official release. Then confirm with `crypt-sync --version`.
- **Declined** → do not attempt any encryption or decryption. You can still do the read-only diagnosis in [Working without the CLI](#working-without-the-cli).

Install problems, in order of likelihood:

| Symptom | Cause | What to tell the user |
|---|---|---|
| Install succeeded, `crypt-sync --version` still not found | the directory from `npm prefix -g` is not on `PATH` | add `$(npm prefix -g)/bin` to `PATH` |
| `EACCES` / permission denied | npm global prefix is a system directory | **never suggest sudo** — use `npm config set prefix ~/.npm-global` or nvm |
| `npm: command not found` | no Node.js | install Node.js ≥ 16 first, then return here |
| `age binary not found` later | postinstall failed silently | `npm rebuild crypt-sync`, or install `age` manually onto `PATH` |

---

## Gate 1 — identity

```bash
crypt-sync configured   # exit 0 = identity exists, exit 1 = missing
```

Exit 1 → **you must not run `init` yourself.** It reads a passphrase interactively from the terminal, so it would hang under a tool call, and the passphrase must never pass through you. Tell the user to run it:

```
! crypt-sync init
```

Absolute rules for the passphrase: never pass it as an argument, never put it in an environment variable or a file, never echo it, never ask the user to paste it into the chat.

Note that `init` does more than derive a key: if it is run inside a project that has a `.cryptsync` file, it also installs the git hooks and runs `unlock`. On a fresh clone that single command is the whole setup.

---

## Which commands you may run

| Command | Who runs it | Why |
|---|---|---|
| `init` | **user only** | interactive passphrase prompt |
| `setup` — no `.cryptsync` yet | **user only** | interactive file-browser wizard (`d1` to enter a directory, `b` back, `q` quit, Enter to finish) |
| `setup` — `.cryptsync` already exists | you | skips the wizard; installs hooks + runs `unlock` |
| `lock`, `unlock`, `status`, `clean`, `update-hooks` | you | non-interactive |
| `export-key`, `import-key` | **user only** | raw identity key material |

`guard` and `configured` exist for the git hooks; `configured` is also the cheap identity check in Gate 1.

---

## Decision tree

```
Gate 0 ok, Gate 1 ok
   │
   ├── no .cryptsync in the project
   │      └── new setup → user runs: ! crypt-sync setup
   │
   └── .cryptsync exists
          ├── crypt-sync status          → per-entry state, recipient fingerprint
          ├── secrets changed            → crypt-sync lock      (git-adds the blobs)
          ├── plaintext missing/stale    → crypt-sync unlock
          ├── orphan .age blobs          → crypt-sync clean
          └── hooks stale after upgrade  → crypt-sync update-hooks
```

After `lock` the blobs are staged but **not** committed. Leave the commit to the user unless they explicitly ask for one.

**Bring up `update-hooks` proactively.** Whenever the user mentions installing, updating or reinstalling the package (`npm install -g crypt-sync@latest`, `npm update -g`, "I upgraded crypt-sync"), remind them to run `crypt-sync update-hooks` in every project that uses it. npm replaces the package but never touches the hook scripts already written into `.git/hooks/`, so those keep running the old version silently — do not wait for a symptom to report this.

---

## Safety rules

1. **Never read or print decrypted content.** After `unlock`, do not open the plaintext file, do not cat it, do not quote it back. Report file names and states only.
2. **`unlock --force` only on an explicit request.** It overwrites local plaintext edits. Say what will be overwritten first.
3. **`lock --wipe` only on an explicit request.** It deletes the plaintext after encrypting.
4. **Never print key material.** `export-key` writes the identity to a plain file; do not read it, do not include its path in any output that gets shared, and remind the user to store it securely.
5. **Never commit plaintext.** If `pre-commit` aborts, that hook is doing its job — fix the staging, do not bypass it with `--no-verify`.
6. `.cryptsync.state` is the local ledger and is gitignored. `.cryptsync` itself must be committed — every machine has to agree on what is managed.

---

## Manifest patterns

`.cryptsync` is a line-per-entry file, `#` for comments.

| Pattern | Behaviour |
|---|---|
| `apps/bot/.env` (has a slash) | exact path from the project root — **recommended** |
| `.env` (no slash) | basename match — every `.env` in the tree |
| `secrets/` (trailing slash) | whole directory as one `.cryptsync.tar.age` archive |
| `*.pem` | glob, project root only |
| `**/*.pem` | recursive glob |

Prefer full relative paths. Basename patterns need the plaintext to exist on disk to resolve, which fails on a fresh clone before the first `unlock` — if the user reports "nothing decrypted after cloning", check for basename patterns first.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `git pull` does not decrypt | hooks missing or from an older version | `crypt-sync update-hooks` |
| Hooks unchanged after upgrading the package | `npm install -g` does not touch `.git/hooks/` | `crypt-sync update-hooks` in each project |
| `unlock` prints `missing: x.age` | the blob was never committed | on the source machine: `crypt-sync lock`, then commit and push the blob |
| `unlock` prints `not locked: x` | plaintext exists, never encrypted | `crypt-sync lock` |
| `unlock` refuses to overwrite | local plaintext differs from the blob | confirm with the user, then `crypt-sync unlock --force` |
| Decryption fails / wrong content | different passphrases | compare the recipient fingerprint from `crypt-sync status` on both machines |
| `pre-commit` aborts on staged plaintext | a managed plaintext file is staged | `git reset HEAD <file>` → `crypt-sync lock` → stage the `.age` blob instead |
| Everything silently does nothing | CLI not installed | back to Gate 0 |

---

## Working without the CLI

If the user declined the install, these read-only checks still help and require no crypto:

- read `.cryptsync` and explain which files are managed and how each pattern resolves
- count the `.age` blobs in the repo to show what is already encrypted
- grep `.git/hooks/*` for `# crypt-sync hook start` — if the sentinel is present but the CLI is missing, the hooks are matching `command -v crypt-sync`, failing it, and skipping **silently**: changed secrets are not being encrypted on push and blobs are not decrypted on pull. Say this plainly; it is the most dangerous state.

You cannot decrypt anything in this mode. The passphrase is not available to you, by design.

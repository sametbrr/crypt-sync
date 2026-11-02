# crypt-sync — agent guide

Two products in one repo:
1. **npm CLI** `crypt-sync` (`bin/`, `cmd/`, `lib/`, `scripts/`, `templates/`): age encryption of secret files, git hooks. Ships to npm through the `files` whitelist in package.json.
2. **Agent plugin** for Claude Code and Codex (`.claude-plugin/`, `.codex-plugin/`, `skills/crypt-sync/`, `hooks/`): the decision layer over the CLI. Never ships to npm.

## Rules
- `package.json`, `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` share one version (CI enforces it). Release = push tag `v<version>`; the workflow publishes to npm.
- A new CLI subcommand must be added to `CLI_CALL` in `hooks/require-cli.sh` (CI: `node hooks/check-gate-sync.js`).
- Hook output: the reason for the agent goes in `permissionDecisionReason` / `additionalContext`; `systemMessage` is the short user-facing line.
- Never handle passphrases: the user runs `crypt-sync init` themselves.
- README.md and README.tr.md stay mirrored.
- Never commit, push or publish without explicit approval from the maintainer.

## Checks
- `sh hooks/require-cli.sh --self-test`
- `node hooks/check-gate-sync.js`
- `npm pack --dry-run` must not list plugin files
- `claude plugin validate .`

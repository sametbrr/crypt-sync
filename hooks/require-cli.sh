#!/bin/sh
# crypt-sync plugin gate.
#
#   PreToolUse   : a crypt-sync CLI call is attempted but the CLI is missing
#                  -> deny the command and tell Claude to install the npm package
#   SessionStart : this project has a .cryptsync manifest but the CLI is missing
#                  -> warn, because the git hooks are skipping silently
#
# The plugin ships only the skill. The engine is the `crypt-sync` npm package:
# the git hooks look it up with `command -v crypt-sync`, and the `age` binary is
# fetched by the package's postinstall script (vendor/ is not in git).
#
# ponytail: greps raw stdin instead of parsing JSON — keeps this dependency-free
# (jq is not installed on stock macOS). Ceiling: a command that merely *mentions*
# "crypt-sync <subcommand>" inside a string is denied too, but only while the CLI
# is missing. Switch to jq/node parsing if that ever becomes noisy.

set -eu

# `crypt-sync` followed by a real subcommand. "npm install -g crypt-sync" has no
# subcommand after the package name, so the install path is never blocked —
# without that property this gate would deadlock itself.
CLI_CALL='crypt-sync[[:space:]]+(init|setup|lock|unlock|status|clean|update-hooks|export-key|import-key|guard|configured)'

has_cli() { command -v crypt-sync >/dev/null 2>&1; }

deny() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"The crypt-sync CLI is not on PATH, so this command cannot work. This plugin ships only the skill; the engine is the npm package. Ask the user for permission, then run: npm install -g crypt-sync (its postinstall downloads the age binary and verifies its SHA256). Verify with: crypt-sync --version. If it is still not found, the directory from `npm prefix -g` is not on PATH. On EACCES do NOT use sudo — suggest `npm config set prefix ~/.npm-global` or nvm. Afterwards the USER must run `crypt-sync init` themselves: it prompts for a passphrase interactively, so never run it yourself and never pass a passphrase as an argument or environment variable."}'
  exit 0
}

warn_project() {
  printf '%s\n' '{"systemMessage":"This project has a .cryptsync manifest but the crypt-sync CLI is not installed. Its git hooks (pre-commit guard, pre-push lock, post-merge unlock) are being skipped silently, so changed secrets are NOT being encrypted and .age blobs are NOT being decrypted. Tell the user to run: npm install -g crypt-sync && crypt-sync init"}'
  exit 0
}

main() {
  input=$(cat)

  case "$input" in
    *'"hook_event_name":"SessionStart"'* | *'"hook_event_name": "SessionStart"'*)
      [ -f "${CLAUDE_PROJECT_DIR:-.}/.cryptsync" ] || exit 0
      has_cli && exit 0
      warn_project
      ;;
  esac

  has_cli && exit 0
  printf '%s' "$input" | grep -Eq "$CLI_CALL" || exit 0
  deny
}

self_test() {
  fake=$(mktemp -d)
  : >"$fake/crypt-sync"
  chmod +x "$fake/crypt-sync"
  bare="/usr/bin:/bin"
  stubbed="$fake:$bare" # same PATH plus a fake crypt-sync, so `sh` itself stays reachable
  failed=0

  check() { # label expected-substring ("" means: expect no output at all) PATH json [project_dir]
    out=$(printf '%s' "$4" | PATH="$3" CLAUDE_PROJECT_DIR="${5:-/nonexistent}" sh "$0" || true)
    if [ -z "$2" ]; then
      if [ -z "$out" ]; then echo "ok   $1"
      else echo "FAIL $1 -- expected no output, got: $out"; failed=1; fi
      return
    fi
    case "$out" in
      *"$2"*) echo "ok   $1" ;;
      *) echo "FAIL $1 -- got: ${out:-<empty>}"; failed=1 ;;
    esac
  }

  P='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":'
  check "denies a CLI call when the CLI is missing" '"deny"' "$bare" "$P\"crypt-sync status\"}}"
  check "allows the install command"                ''       "$bare" "$P\"npm install -g crypt-sync\"}}"
  check "allows an unrelated command"               ''       "$bare" "$P\"git status\"}}"
  check "allows bare crypt-sync (help output)"      ''       "$bare" "$P\"crypt-sync\"}}"
  check "allows a CLI call when the CLI exists"     ''       "$stubbed" "$P\"crypt-sync lock\"}}"

  S='{"hook_event_name":"SessionStart","cwd":"/tmp"}'
  project=$(mktemp -d)
  check "SessionStart is silent without a .cryptsync" '' "$bare" "$S" "$project"
  : >"$project/.cryptsync"
  check "SessionStart warns on .cryptsync without CLI" 'skipped silently' "$bare"    "$S" "$project"
  check "SessionStart is silent when the CLI exists"   ''                 "$stubbed" "$S" "$project"

  rm -rf "$project" "$fake"
  [ "$failed" -eq 0 ] || { echo "self-test failed"; exit 1; }
  echo "all passed"
}

[ "${1:-}" = "--self-test" ] && { self_test; exit 0; }
main

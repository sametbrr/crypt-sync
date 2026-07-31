#!/usr/bin/env node
'use strict';

// Keeps the PreToolUse gate in step with the CLI.
//
// hooks/require-cli.sh only blocks `crypt-sync <subcommand>` for a fixed list of
// subcommands. That whitelist is deliberate: a looser pattern such as
// `crypt-sync[[:space:]]+[a-z-]+` would also match `npm install -g crypt-sync --force`
// and the gate would block its own install command. The cost of the whitelist is
// that a new CLI command must be added to it, and forgetting is silent — the gate
// simply stops covering that command. This check turns that into a CI failure.
//
// Run: node hooks/check-gate-sync.js

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const bin = fs.readFileSync(path.join(root, 'bin/crypt-sync.js'), 'utf8');
const gate = fs.readFileSync(path.join(root, 'hooks/require-cli.sh'), 'utf8');

const commandsBlock = bin.match(/const COMMANDS = \{([\s\S]*?)\n\};/);
if (!commandsBlock) {
  console.error('FAIL: could not find the COMMANDS map in bin/crypt-sync.js');
  process.exit(1);
}
const cliCommands = [...commandsBlock[1].matchAll(/^\s*'?([a-z-]+)'?:/gm)].map(m => m[1]).sort();

const gatePattern = gate.match(/^CLI_CALL=.*\((.*?)\)/m);
if (!gatePattern) {
  console.error('FAIL: could not find CLI_CALL in hooks/require-cli.sh');
  process.exit(1);
}
const gateCommands = gatePattern[1].split('|').sort();

const missing = cliCommands.filter(c => !gateCommands.includes(c));
const extra = gateCommands.filter(g => !cliCommands.includes(g));

console.log(`CLI commands (${cliCommands.length}): ${cliCommands.join(' ')}`);
console.log(`gate pattern (${gateCommands.length}): ${gateCommands.join(' ')}`);

if (missing.length) {
  console.error(`\nFAIL: not covered by the gate: ${missing.join(' ')}`);
  console.error('Add them to CLI_CALL in hooks/require-cli.sh.');
  process.exit(1);
}
if (extra.length) {
  console.error(`\nFAIL: in the gate but not in the CLI: ${extra.join(' ')}`);
  console.error('Remove them from CLI_CALL in hooks/require-cli.sh.');
  process.exit(1);
}

console.log('\nok: the gate covers every CLI command');

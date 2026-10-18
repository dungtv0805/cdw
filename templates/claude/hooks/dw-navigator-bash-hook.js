#!/usr/bin/env node
/**
 * dw-navigator Bash hook — allow only read-only commands without shell metacharacters.
 *
 * This is the Node.js port of the verified allowlist from
 * docs/superpowers/specs/2026-10-17-navigator-bash-allowlist.sh.
 *
 * Exit codes:
 *   0 — command allowed
 *   2 — command blocked (message on stderr)
 *
 * Allowed commands (without shell metacharacters):
 *   git log|diff|show|status|blame|rev-parse|ls-files
 *   ls, cat, head, tail, grep, rg, wc, find, pwd
 *
 * Blocked patterns:
 *   - Shell metacharacters: ; & | < > $ `
 *   - Line breaks: bash runs each line as its own command
 *   - Dangerous find flags: -exec, -execdir, -delete, -ok, -fprint, -fls
 *   - Output redirection flags: --output, --pre
 */

const ALLOWED_COMMANDS = /^(git (log|diff|show|status|blame|rev-parse|ls-files)|ls|cat|head|tail|grep|rg|wc|find|pwd)( [^;&|<>`$\n\r]*)?$/;
const DANGEROUS_FLAGS = /--output|-exec|-execdir|-delete|-ok |--pre|-fprint|-fls/;

function isAllowed(command) {
  if (typeof command !== 'string' || command.length === 0) {
    return false;
  }
  // Must match allowed command pattern AND not have dangerous flags
  return ALLOWED_COMMANDS.test(command) && !DANGEROUS_FLAGS.test(command);
}

function main() {
  let input = '';

  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });

  process.stdin.on('end', () => {
    let parsed;
    try {
      parsed = JSON.parse(input);
    } catch {
      process.stderr.write('Blocked: malformed hook input (invalid JSON)\n');
      process.exit(2);
    }

    const command = parsed?.tool_input?.command;

    if (typeof command !== 'string') {
      process.stderr.write('Blocked: missing or invalid command field\n');
      process.exit(2);
    }

    if (isAllowed(command)) {
      process.exit(0);
    }

    process.stderr.write(
      'Blocked: a navigator runs only read-only commands ' +
      '(git log/diff/show/status, ls, cat, grep, rg, find, head, tail, wc) ' +
      'without pipes, redirects or substitutions\n'
    );
    process.exit(2);
  });
}

main();

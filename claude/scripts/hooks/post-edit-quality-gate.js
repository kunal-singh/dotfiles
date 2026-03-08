'use strict';

const { spawnSync } = require('child_process');
const { loadConfig } = require('./lib/utils');

try {
  const config = loadConfig();
  if (!config.quality) process.exit(0);

  const cwd = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
  const checks = [
    { name: 'format', command: config.quality.format },
    { name: 'lint', command: config.quality.lint },
    { name: 'typecheck', command: config.quality.typecheck },
  ].filter(c => c.command);

  for (const { name, command } of checks) {
    const result = spawnSync(command, { shell: true, cwd, encoding: 'utf8' });
    if (result.status !== 0) {
      process.stderr.write(`Quality gate failed: ${name}\n${result.stdout}\n${result.stderr}`);
      process.exit(2);
    }
  }

  process.exit(0);
} catch {
  process.exit(0);
}

'use strict';

const fs = require('fs');
const path = require('path');

function readStdin() {
  try {
    const raw = fs.readFileSync('/dev/stdin', 'utf8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function loadConfig() {
  const projectDir = process.env.CLAUDE_PROJECT_DIR;
  if (!projectDir) return {};
  const configPath = path.join(projectDir, '.claude', 'hooks-config.json');
  try {
    return JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch {
    return {};
  }
}

function getSessionsDir(config) {
  const projectDir = process.env.CLAUDE_PROJECT_DIR;
  if (!projectDir) return null;
  const sessionsDir = path.join(projectDir, '.claude', 'sessions');
  fs.mkdirSync(sessionsDir, { recursive: true });
  return sessionsDir;
}

function countUserMessages(transcriptPath) {
  try {
    const entries = JSON.parse(fs.readFileSync(transcriptPath, 'utf8'));
    return entries.filter(e => e.role === 'user').length;
  } catch {
    return 0;
  }
}

function getSessionDurationMinutes(transcriptPath) {
  try {
    const entries = JSON.parse(fs.readFileSync(transcriptPath, 'utf8'));
    if (entries.length < 2) return 0;
    const first = new Date(entries[0].timestamp);
    const last = new Date(entries[entries.length - 1].timestamp);
    return (last - first) / 60000;
  } catch {
    return 0;
  }
}

function getSessionId() {
  return process.env.CLAUDE_SESSION_ID ?? 'unknown';
}

function getDateString() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

module.exports = {
  readStdin,
  loadConfig,
  getSessionsDir,
  countUserMessages,
  getSessionDurationMinutes,
  getSessionId,
  getDateString,
};

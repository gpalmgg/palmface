import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { getClaudeConfigDir } from './claude-config-dir.js';

export interface ActiveClaudeMdScopes {
  user: boolean;
  project: boolean;
  projectLocal: boolean;
}

/**
 * Detect which CLAUDE.md scopes are currently load-bearing.
 *   - user: ~/.claude/CLAUDE.md
 *   - project: {cwd}/CLAUDE.md or {cwd}/.claude/CLAUDE.md
 *   - projectLocal: {cwd}/CLAUDE.local.md or {cwd}/.claude/CLAUDE.local.md
 */
export function detectActiveClaudeMd(cwd?: string): ActiveClaudeMdScopes {
  const homeDir = os.homedir();
  const claudeDir = getClaudeConfigDir(homeDir);

  const user = fs.existsSync(path.join(claudeDir, 'CLAUDE.md'));

  let project = false;
  let projectLocal = false;
  if (cwd) {
    project = fs.existsSync(path.join(cwd, 'CLAUDE.md'))
      || fs.existsSync(path.join(cwd, '.claude', 'CLAUDE.md'));
    projectLocal = fs.existsSync(path.join(cwd, 'CLAUDE.local.md'))
      || fs.existsSync(path.join(cwd, '.claude', 'CLAUDE.local.md'));
  }

  return { user, project, projectLocal };
}

/**
 * Render a compact scope badge for display, e.g. "U+P" or "P*" (project-local).
 * Returns null when no CLAUDE.md is present at all.
 */
export function formatActiveClaudeMd(scopes: ActiveClaudeMdScopes): string | null {
  if (!scopes.user && !scopes.project && !scopes.projectLocal) {
    return null;
  }
  const parts: string[] = [];
  if (scopes.user) parts.push('U');
  if (scopes.project) parts.push('P');
  if (scopes.projectLocal) parts.push('P*');
  return parts.join('+');
}

import * as fs from 'node:fs';
import * as path from 'node:path';

function expandHomeDirPrefix(inputPath: string, homeDir: string): string {
  if (inputPath === '~') {
    return homeDir;
  }
  if (inputPath.startsWith('~/') || inputPath.startsWith('~\\')) {
    return path.join(homeDir, inputPath.slice(2));
  }
  return inputPath;
}

export function getClaudeConfigDir(homeDir: string): string {
  const envConfigDir = process.env.CLAUDE_CONFIG_DIR?.trim();
  if (!envConfigDir) {
    return path.join(homeDir, '.claude');
  }
  return path.resolve(expandHomeDirPrefix(envConfigDir, homeDir));
}

export function getClaudeConfigJsonPath(homeDir: string): string {
  return `${getClaudeConfigDir(homeDir)}.json`;
}

/**
 * Where the statusline keeps its caches. It sits inside Palmface's own folder, so uninstalling
 * Palmface removes it too. (Your settings file is elsewhere: see getConfigPath in config.ts.)
 */
export function getHudPluginDir(homeDir: string): string {
  return path.join(getClaudeConfigDir(homeDir), 'palmface', 'state', 'statusline');
}

/**
 * The caches hold text from your sessions (tool targets, todos, session names), so they are
 * yours alone: folders 0700 and files 0600, whatever the umask says.
 */
export function ensurePrivateDir(dir: string): void {
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
}

export function writePrivateFile(file: string, data: string): void {
  fs.writeFileSync(file, data, { encoding: 'utf8', mode: 0o600 });
  try {
    fs.chmodSync(file, 0o600); // a file an older version wrote keeps its mode otherwise
  } catch {
    /* best-effort */
  }
}

export function appendPrivateFile(file: string, data: string): void {
  fs.appendFileSync(file, data, { encoding: 'utf8', mode: 0o600 });
}

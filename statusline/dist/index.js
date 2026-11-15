import { readStdin, getUsageFromStdin, getBufferedPercent } from './stdin.js';
import { parseTranscript } from './transcript.js';
import { render } from './render/index.js';
import { countConfigs } from './config-reader.js';
import { getGitStatus } from './git.js';
import { loadConfig } from './config.js';
import { parseExtraCmdArg, runExtraCmd } from './extra-cmd.js';
import { getClaudeCodeVersion } from './version.js';
import { getMemoryUsage } from './memory.js';
import { sessionIdFromTranscriptPath, tickLedger, readRecentCompacts, computeCompactStats, } from './session-ledger.js';
import { detectActiveClaudeMd } from './active-claude-md.js';
import { fileURLToPath } from 'node:url';
import { realpathSync } from 'node:fs';
export async function main(overrides = {}) {
    const deps = {
        readStdin,
        getUsageFromStdin,
        parseTranscript,
        countConfigs,
        getGitStatus,
        loadConfig,
        parseExtraCmdArg,
        runExtraCmd,
        getClaudeCodeVersion,
        getMemoryUsage,
        render,
        now: () => Date.now(),
        log: console.log,
        ...overrides,
    };
    try {
        const stdin = await deps.readStdin();
        if (!stdin) {
            // No status JSON (run by hand, or unreadable input): print nothing rather than a notice.
            return;
        }
        const transcriptPath = stdin.transcript_path ?? '';
        const transcript = await deps.parseTranscript(transcriptPath);
        const { claudeMdCount, rulesCount, mcpCount, hooksCount } = await deps.countConfigs(stdin.cwd);
        const config = await deps.loadConfig();
        const gitStatus = config.gitStatus.enabled
            ? await deps.getGitStatus(stdin.cwd)
            : null;
        // Usage comes only from Claude Code's official stdin rate_limits fields.
        let usageData = null;
        if (config.display.showUsage !== false) {
            usageData = deps.getUsageFromStdin(stdin);
        }
        const extraCmd = deps.parseExtraCmdArg();
        const extraLabel = extraCmd ? await deps.runExtraCmd(extraCmd) : null;
        const sessionDuration = formatSessionDuration(transcript.sessionStart, deps.now);
        const claudeCodeVersion = config.display.showClaudeCodeVersion
            ? await deps.getClaudeCodeVersion()
            : undefined;
        const memoryUsage = config.display.showMemoryUsage && config.lineLayout === 'expanded'
            ? await deps.getMemoryUsage()
            : null;
        // Ledger tick (always runs when we have a transcript path — persists daemon
        // names and detects compact events regardless of whether they're displayed).
        let sessionState;
        if (transcriptPath) {
            try {
                const sessionId = sessionIdFromTranscriptPath(transcriptPath);
                sessionState = tickLedger(sessionId, transcriptPath, getBufferedPercent(stdin));
            }
            catch {
                /* ledger is best-effort */
            }
        }
        const compactStats = config.display.showCompactNudge
            ? computeCompactStats(readRecentCompacts())
            : null;
        const activeClaudeMd = config.display.showActiveClaudeMd
            ? detectActiveClaudeMd(stdin.cwd)
            : null;
        const ctx = {
            stdin,
            transcript,
            claudeMdCount,
            rulesCount,
            mcpCount,
            hooksCount,
            sessionDuration,
            gitStatus,
            usageData,
            memoryUsage,
            config,
            extraLabel,
            claudeCodeVersion,
            sessionState,
            compactStats,
            activeClaudeMd,
        };
        deps.render(ctx);
    }
    catch (error) {
        deps.log('[palmface-statusline] Error:', error instanceof Error ? error.message : 'Unknown error');
    }
}
export function formatSessionDuration(sessionStart, now = () => Date.now()) {
    if (!sessionStart) {
        return '';
    }
    const ms = now() - sessionStart.getTime();
    const mins = Math.floor(ms / 60000);
    if (mins < 1)
        return '<1m';
    if (mins < 60)
        return `${mins}m`;
    const hours = Math.floor(mins / 60);
    const remainingMins = mins % 60;
    return `${hours}h ${remainingMins}m`;
}
const scriptPath = fileURLToPath(import.meta.url);
const argvPath = process.argv[1];
const isSamePath = (a, b) => {
    try {
        return realpathSync(a) === realpathSync(b);
    }
    catch {
        return a === b;
    }
};
if (argvPath && isSamePath(argvPath, scriptPath)) {
    void main();
}

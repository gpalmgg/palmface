import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { createHash } from 'node:crypto';
import { getHudPluginDir, ensurePrivateDir, writePrivateFile, appendPrivateFile } from './claude-config-dir.js';
/**
 * Session ledger: cross-session + per-session state for palmface-statusline intelligence
 * features. Foundation for:
 *   - compact-threshold learning (L2-2)
 *   - daemon name persistence (L2-20)
 *   - future: lifetime token ledger, welcome-back detection
 *
 * State layout under `getHudPluginDir(homeDir)/ledger/`:
 *   sessions/<sessionId>.json  per-session tiny state blob
 *   compacts.jsonl             append-only log of detected compact events
 *
 * A "compact event" is detected heuristically: when consecutive renders of the
 * same session show a context% drop of >= COMPACT_DROP_THRESHOLD points, we
 * log the before-% as a proxy for "when this user tends to compact".
 */
const COMPACT_DROP_THRESHOLD = 30;
const COMPACT_HISTORY_CAP = 50;
const LEDGER_DIR_NAME = 'ledger';
const SESSIONS_DIR_NAME = 'sessions';
const COMPACTS_FILE_NAME = 'compacts.jsonl';
function getLedgerDir(homeDir = os.homedir()) {
    return path.join(getHudPluginDir(homeDir), LEDGER_DIR_NAME);
}
function getSessionsDir(homeDir = os.homedir()) {
    return path.join(getLedgerDir(homeDir), SESSIONS_DIR_NAME);
}
function getCompactsPath(homeDir = os.homedir()) {
    return path.join(getLedgerDir(homeDir), COMPACTS_FILE_NAME);
}
export function sessionIdFromTranscriptPath(transcriptPath) {
    return createHash('sha256').update(path.resolve(transcriptPath)).digest('hex').slice(0, 16);
}
function sessionStatePath(sessionId, homeDir = os.homedir()) {
    return path.join(getSessionsDir(homeDir), `${sessionId}.json`);
}
function ensureDirSync(dir) {
    try {
        ensurePrivateDir(dir);
    }
    catch {
        /* ignore */
    }
}
export function loadSessionState(sessionId, transcriptPath) {
    const statePath = sessionStatePath(sessionId);
    try {
        const raw = fs.readFileSync(statePath, 'utf-8');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object' && parsed.sessionId === sessionId) {
            return parsed;
        }
    }
    catch {
        /* fall through */
    }
    return {
        sessionId,
        transcriptPath,
        firstSeenAt: Date.now(),
    };
}
export function saveSessionState(state) {
    try {
        ensureDirSync(getSessionsDir());
        writePrivateFile(sessionStatePath(state.sessionId), JSON.stringify(state));
    }
    catch {
        /* ignore — ledger is best-effort */
    }
}
export function appendCompactEvent(event) {
    try {
        ensureDirSync(getLedgerDir());
        appendPrivateFile(getCompactsPath(), `${JSON.stringify(event)}\n`);
    }
    catch {
        /* ignore */
    }
}
export function readRecentCompacts(limit = COMPACT_HISTORY_CAP) {
    try {
        const raw = fs.readFileSync(getCompactsPath(), 'utf-8');
        const lines = raw.trim().split('\n').filter(Boolean);
        const start = Math.max(0, lines.length - limit);
        const events = [];
        for (let i = start; i < lines.length; i += 1) {
            try {
                const parsed = JSON.parse(lines[i]);
                if (typeof parsed.before === 'number' && typeof parsed.after === 'number') {
                    events.push(parsed);
                }
            }
            catch {
                /* skip malformed line */
            }
        }
        return events;
    }
    catch {
        return [];
    }
}
export function computeCompactStats(events) {
    if (events.length === 0) {
        return null;
    }
    const sum = events.reduce((acc, e) => acc + e.before, 0);
    return {
        avgThreshold: Math.round(sum / events.length),
        sampleCount: events.length,
    };
}
/**
 * Tick the ledger with the current context%. Detects compact events (large
 * downward jumps) and updates per-session state. Idempotent and cheap.
 * Returns the current session state (post-update).
 */
export function tickLedger(sessionId, transcriptPath, currentPercent) {
    const state = loadSessionState(sessionId, transcriptPath);
    const now = Date.now();
    if (typeof state.lastContextPercent === 'number'
        && state.lastContextPercent - currentPercent >= COMPACT_DROP_THRESHOLD) {
        appendCompactEvent({
            sessionId,
            ts: now,
            before: state.lastContextPercent,
            after: currentPercent,
        });
    }
    state.lastContextPercent = currentPercent;
    state.lastContextAt = now;
    state.transcriptPath = transcriptPath;
    saveSessionState(state);
    return state;
}

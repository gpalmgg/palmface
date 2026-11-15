import { createHash } from 'node:crypto';
import { saveSessionState } from './session-ledger.js';
/**
 * Session-scoped spirit-animal names. Deterministic from session id, persisted
 * across --resume via the session ledger, so the same session keeps the same
 * daemon over time.
 *
 * 24 adjectives × 24 creatures = 576 unique names. Collisions only occur when
 * two distinct session ids hash into the same (adj, creature) pair, which is
 * rare enough at typical session volumes to ignore.
 */
const ADJECTIVES = [
    'amber', 'bright', 'copper', 'dusky', 'elder', 'feral',
    'glacial', 'hollow', 'inkwell', 'jasper', 'knotted', 'lacquer',
    'mossy', 'nocturnal', 'opaline', 'pale', 'quiet', 'ruddy',
    'silvery', 'tangled', 'umber', 'verdant', 'wandering', 'xyloid',
];
const CREATURES = [
    'otter', 'badger', 'crow', 'dragonfly', 'egret', 'fox',
    'gecko', 'heron', 'ibex', 'jay', 'kingfisher', 'lynx',
    'marten', 'newt', 'owl', 'pika', 'quail', 'raven',
    'stoat', 'thrush', 'urchin', 'vole', 'wren', 'yak',
];
function pickFromHash(sessionId) {
    const hash = createHash('sha256').update(sessionId).digest();
    const adjIdx = hash.readUInt16BE(0) % ADJECTIVES.length;
    const creatureIdx = hash.readUInt16BE(2) % CREATURES.length;
    return `${ADJECTIVES[adjIdx]} ${CREATURES[creatureIdx]}`;
}
/**
 * Get (or create and persist) the daemon name for a session.
 * Writes through the session ledger — the first call materializes the name,
 * subsequent calls read it back.
 */
export function getDaemonName(state) {
    if (state.daemonName) {
        return state.daemonName;
    }
    const name = pickFromHash(state.sessionId);
    state.daemonName = name;
    saveSessionState(state);
    return name;
}

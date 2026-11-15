// Shared debug logging utility
// Enable via: DEBUG=palmface-statusline or DEBUG=*
const DEBUG = process.env.DEBUG?.includes('palmface-statusline') || process.env.DEBUG === '*';
/**
 * Create a namespaced debug logger
 * @param namespace - Tag for log messages (e.g., 'config', 'usage')
 */
export function createDebug(namespace) {
    return function debug(msg, ...args) {
        if (DEBUG) {
            console.error(`[palmface-statusline:${namespace}] ${msg}`, ...args);
        }
    };
}

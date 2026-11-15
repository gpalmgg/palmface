const PET_GLYPHS = {
    sleepy: '(-.-)',
    alert: '(o.o)',
    sick: '(x.x)',
    happy: '(^_^)',
};
const IDLE_MS = 45_000;
const HAPPY_AFTER_COMPACT_MS = 120_000;
/**
 * Determine the HUD pet's mood from session health signals.
 * - sick: context% above 85 (overwhelmed, compact would help)
 * - alert: any tool currently running (actively working)
 * - happy: a compact was detected within the last two minutes
 * - sleepy: default / idle
 */
export function getPetMood(transcript, contextPercent, lastCompactAt, now = Date.now()) {
    if (contextPercent >= 85) {
        return 'sick';
    }
    const runningTool = transcript.tools.find(t => t.status === 'running');
    if (runningTool) {
        return 'alert';
    }
    if (lastCompactAt !== null && now - lastCompactAt < HAPPY_AFTER_COMPACT_MS) {
        return 'happy';
    }
    const mostRecentTool = transcript.tools[transcript.tools.length - 1];
    if (mostRecentTool?.endTime && now - mostRecentTool.endTime.getTime() > IDLE_MS) {
        return 'sleepy';
    }
    // No recent tool activity at all
    if (!mostRecentTool) {
        return 'sleepy';
    }
    return 'sleepy';
}
export function renderPet(mood) {
    return PET_GLYPHS[mood];
}

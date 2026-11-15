import { getContextPercent, getBufferedPercent, getTotalTokens, getSessionCost, getCacheRatio, getEfficiencyZone } from '../../stdin.js';
import { coloredBar, label, getContextColor, getEfficiencyColor, RESET } from '../colors.js';
import { getAdaptiveBarWidth } from '../../utils/terminal.js';
import { detectStuckStreak } from '../../stuck.js';
import { getPetMood, renderPet } from '../../pet.js';
import { renderAnimatedPet, petMoodTransition } from '../../vibes.js';
const DEBUG = process.env.DEBUG?.includes('palmface-statusline') || process.env.DEBUG === '*';
export function renderIdentityLine(ctx) {
    const rawPercent = getContextPercent(ctx.stdin);
    const bufferedPercent = getBufferedPercent(ctx.stdin);
    const autocompactMode = ctx.config?.display?.autocompactBuffer ?? 'enabled';
    const percent = autocompactMode === 'disabled' ? rawPercent : bufferedPercent;
    const colors = ctx.config?.colors;
    const display = ctx.config?.display;
    if (DEBUG && autocompactMode === 'disabled') {
        console.error(`[palmface-statusline:context] autocompactBuffer=disabled, showing raw ${rawPercent}% (buffered would be ${bufferedPercent}%)`);
    }
    // Cache and efficiency data
    const cacheRatio = getCacheRatio(ctx.stdin);
    const zone = getEfficiencyZone(percent, cacheRatio);
    const efficiencyColor = getEfficiencyColor(zone, colors);
    // Context bar + percentage (always shown)
    const contextValueMode = display?.contextValue ?? 'percent';
    const contextValue = formatContextValue(ctx, percent, contextValueMode);
    const contextValueDisplay = `${getContextColor(percent, colors)}${contextValue}${RESET}`;
    let line = display?.showContextBar !== false
        ? `${label('Context', colors)} ${coloredBar(percent, getAdaptiveBarWidth(), colors, ctx.config?.display?.gradientBars)} ${contextValueDisplay}`
        : `${label('Context', colors)} ${contextValueDisplay}`;
    // Token count — always appended in parens
    const totalTokens = getTotalTokens(ctx.stdin);
    if (totalTokens > 0) {
        line += label(` (${formatTokens(totalTokens)})`, colors);
    }
    // Session cost
    const cost = getSessionCost(ctx.stdin);
    if (display?.showCost !== false && cost > 0) {
        const costStr = formatCost(cost);
        line += ` │ ${efficiencyColor}${costStr}${RESET}`;
    }
    // Burn rate ($ / hr)
    if (display?.showBurnRate && cost > 0) {
        const burn = computeBurnRate(ctx, cost);
        if (burn !== null) {
            line += ` │ ${efficiencyColor}${formatCost(burn)}/hr${RESET}`;
        }
    }
    // Cache ratio
    if (display?.showCacheRatio !== false && cacheRatio !== null) {
        line += ` │ ${efficiencyColor}${cacheRatio}% cached${RESET}`;
    }
    // Reclaimable estimate (adaptive — only when above threshold)
    if (display?.showReclaimable !== false) {
        const reclaimable = estimateReclaimableTokens(ctx);
        const threshold = display?.reclaimableThreshold ?? 30000;
        if (reclaimable >= threshold) {
            line += ` │ ${efficiencyColor}🧹 ~${formatTokens(reclaimable)} reclaimable${RESET}`;
        }
    }
    // Compact-threshold nudge (L2-2)
    if (display?.showCompactNudge && ctx.compactStats) {
        const avg = ctx.compactStats.avgThreshold;
        const samples = ctx.compactStats.sampleCount;
        if (samples >= 3 && percent > avg) {
            line += ` │ ${efficiencyColor}↘ past avg ${avg}%${RESET}`;
        }
    }
    // Stuck streak whisper (L2-12)
    if (display?.showStuck) {
        const stuck = detectStuckStreak(ctx.transcript);
        if (stuck) {
            line += ` │ ${label(`↻×${stuck.count} ${stuck.file}`, colors)}`;
        }
    }
    // HUD pet (L2-4) — always last, so it floats at the end of the line
    if (display?.showPet) {
        const mood = getPetMood(ctx.transcript, percent, null);
        if (display.showVibes) {
            petMoodTransition(ctx.sessionState?.sessionId, mood, display.vibeSounds);
            line += ` ${renderAnimatedPet(mood)}`;
        }
        else {
            line += ` ${label(renderPet(mood), colors)}`;
        }
    }
    // Legacy token breakdown at >85% (keep backward compat for users who don't enable new features)
    if (display?.showTokenBreakdown !== false && percent >= 85 && display?.showCost === false && display?.showCacheRatio === false) {
        const usage = ctx.stdin.context_window?.current_usage;
        if (usage) {
            const input = formatTokens(usage.input_tokens ?? 0);
            const cache = formatTokens((usage.cache_creation_input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0));
            line += label(` (in: ${input}, cache: ${cache})`, colors);
        }
    }
    return line;
}
function formatTokens(n) {
    if (n >= 1000000) {
        return `${(n / 1000000).toFixed(1)}M`;
    }
    if (n >= 1000) {
        return `${(n / 1000).toFixed(0)}k`;
    }
    return n.toString();
}
function formatCost(usd) {
    if (usd >= 10)
        return `$${usd.toFixed(1)}`;
    if (usd >= 1)
        return `$${usd.toFixed(2)}`;
    return `$${usd.toFixed(3)}`;
}
function formatContextValue(ctx, percent, mode) {
    const totalTokens = getTotalTokens(ctx.stdin);
    const size = ctx.stdin.context_window?.context_window_size ?? 0;
    if (mode === 'tokens') {
        if (size > 0) {
            return `${formatTokens(totalTokens)}/${formatTokens(size)}`;
        }
        return formatTokens(totalTokens);
    }
    if (mode === 'both') {
        if (size > 0) {
            return `${percent}% (${formatTokens(totalTokens)}/${formatTokens(size)})`;
        }
        return `${percent}%`;
    }
    if (mode === 'remaining') {
        return `${Math.max(0, 100 - percent)}%`;
    }
    return `${percent}%`;
}
/**
 * Rough estimate of reclaimable tokens from the transcript.
 * Counts tool_result content for results older than 10 turns
 * that haven't been referenced since. Uses ~4 chars per token.
 */
function estimateReclaimableTokens(ctx) {
    // Use the transcript data we already have — count completed tool results
    // that are likely stale. This is a rough heuristic.
    const tools = ctx.transcript?.tools ?? [];
    const completedTools = tools.filter(t => t.status === 'completed' || t.status === 'error');
    // If we have many completed tools, the older ones are likely reclaimable.
    // Each tool result averages ~2k-5k tokens for file reads, ~500 for small ops.
    // We estimate conservatively: completed tools beyond the most recent 5
    // contribute ~2000 tokens each on average.
    const staleCount = Math.max(0, completedTools.length - 5);
    return staleCount * 2000;
}
/**
 * Session cost divided by elapsed hours. Returns null when the session is too
 * young (< 60s) to produce a stable rate, or when session start is unknown.
 */
function computeBurnRate(ctx, cost) {
    const start = ctx.transcript?.sessionStart;
    if (!start)
        return null;
    const elapsedMs = Date.now() - start.getTime();
    if (elapsedMs < 60_000)
        return null;
    const hours = elapsedMs / 3_600_000;
    return cost / hours;
}

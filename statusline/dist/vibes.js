import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { spawn, spawnSync } from 'node:child_process';
import { getHudPluginDir, ensurePrivateDir, writePrivateFile } from './claude-config-dir.js';
import { sanitize } from './extra-cmd.js';
/**
 * Vibes: the sky line + whisper line of the HUD, plus the animated pet.
 * Everything here is best-effort and must never slow the statusline:
 * network (weather) and subprocess (fortune) results are cached on disk and
 * refreshed in a detached child, so a render only ever reads files.
 *
 * Location is opt-in and has no default. Set these in your shell, or in the "env" block of
 * ~/.claude/settings.json:
 *   PALMFACE_CITY               a city name. Adds its weather to the sky line, fetched from
 *                               wttr.in at most every 30 minutes. This is the statusline's only
 *                               network call, and it never happens while the variable is unset.
 *   PALMFACE_LAT, PALMFACE_LON  decimal degrees. Add sunrise/sunset and golden/blue hour.
 * Without coordinates, night is 19:00 to 07:00 local time (owl by night, cat by day).
 */
function envText(name) {
    const value = process.env[name]?.trim();
    return value ? value : null;
}
function envNumber(name, min, max) {
    const raw = envText(name);
    if (raw === null)
        return null;
    const value = Number(raw);
    return Number.isFinite(value) && value >= min && value <= max ? value : null;
}
const CITY = envText('PALMFACE_CITY');
const LAT = envNumber('PALMFACE_LAT', -90, 90);
const LON = envNumber('PALMFACE_LON', -180, 180);
const NIGHT_FROM_HOUR = 19;
const NIGHT_UNTIL_HOUR = 7;
const WEATHER_TTL_MS = 30 * 60_000;
const FORTUNE_TTL_MS = 60 * 60_000;
const SPARK_SESSIONS = 12;
const STATE_FILE = 'vibes-state.json';
const WEATHER_FILE = 'vibes-weather.txt';
// Rosé Pine names mapped to the terminal's ANSI colour slots (SGR codes), so the statusline
// uses the terminal's own palette and follows a light/dark switch (Palmface's Ghostty config
// swaps Rosé Pine Moon and Dawn with the macOS appearance). Slots: 1 love, 2 pine, 3 gold,
// 4 foam, 5 iris, 6 rose, 8 muted; subtle is the faint default colour.
export const ROSE_PINE = {
    muted: '90',
    subtle: '2',
    text: '39',
    love: '31',
    gold: '33',
    rose: '36',
    pine: '32',
    foam: '34',
    iris: '35',
};
const RESET = '\x1b[0m';
export function paint(sgr, text) {
    return `\x1b[${sgr}m${text}${RESET}`;
}
function stateDir() {
    return getHudPluginDir(os.homedir());
}
function readState() {
    try {
        return JSON.parse(fs.readFileSync(path.join(stateDir(), STATE_FILE), 'utf8'));
    }
    catch {
        return {};
    }
}
function writeState(state) {
    try {
        ensurePrivateDir(stateDir());
        writePrivateFile(path.join(stateDir(), STATE_FILE), JSON.stringify(state));
    }
    catch {
        /* best-effort */
    }
}
// ── moon ─────────────────────────────────────────────────
const SYNODIC_DAYS = 29.530588853;
const KNOWN_NEW_MOON_MS = Date.UTC(2000, 0, 6, 18, 14);
const MOON_GLYPHS = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'];
const MOON_NAMES = ['new', 'waxing', 'first qtr', 'waxing', 'full', 'waning', 'last qtr', 'waning'];
export function moonPhase(now) {
    const days = (now - KNOWN_NEW_MOON_MS) / 86_400_000;
    const age = ((days % SYNODIC_DAYS) + SYNODIC_DAYS) % SYNODIC_DAYS;
    const index = Math.round((age / SYNODIC_DAYS) * 8) % 8;
    return { glyph: MOON_GLYPHS[index], name: MOON_NAMES[index], age: Math.floor(age) };
}
// ── sun (NOAA simplified) ────────────────────────────────
export function sunTimes(now, lat = LAT, lon = LON) {
    if (lat === null || lon === null)
        return null; // no location given: no sun times
    const rad = Math.PI / 180;
    const date = new Date(now);
    // Work on the LOCAL calendar date. The formula gives rise and set in minutes from UTC midnight
    // of that date; far east of Greenwich sunrise comes out negative (the UTC day before), far west
    // sunset comes out past 1440 (the UTC day after), and both still land on the right local day.
    const midnightUtc = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
    const startOfYear = Date.UTC(date.getFullYear(), 0, 1);
    const dayOfYear = Math.round((midnightUtc - startOfYear) / 86_400_000) + 1;
    const gamma = (2 * Math.PI / 365) * (dayOfYear - 1);
    const eqTime = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma)
        - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma));
    const decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma)
        - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma)
        - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
    const cosHa = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl))
        - Math.tan(lat * rad) * Math.tan(decl);
    if (cosHa < -1 || cosHa > 1)
        return null; // polar day / night
    const ha = Math.acos(cosHa) / rad;
    const riseMin = 720 - 4 * (lon + ha) - eqTime;
    const setMin = 720 - 4 * (lon - ha) - eqTime;
    return { rise: midnightUtc + riseMin * 60_000, set: midnightUtc + setMin * 60_000 };
}
export function isNight(now) {
    const sun = sunTimes(now);
    if (sun)
        return now < sun.rise || now > sun.set;
    const hour = new Date(now).getHours();
    return hour >= NIGHT_FROM_HOUR || hour < NIGHT_UNTIL_HOUR;
}
function clock(ms) {
    const d = new Date(ms);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function span(ms) {
    const mins = Math.max(0, Math.round(ms / 60_000));
    if (mins < 60)
        return `${mins}m`;
    return `${Math.floor(mins / 60)}h${String(mins % 60).padStart(2, '0')}`;
}
function sunLabel(now) {
    const sun = sunTimes(now);
    if (!sun)
        return null;
    if (now < sun.rise)
        return `🌅 rises ${clock(sun.rise)} (in ${span(sun.rise - now)})`;
    if (now < sun.set)
        return `☀️ sets ${clock(sun.set)} (in ${span(sun.set - now)})`;
    const tomorrow = sunTimes(now + 86_400_000);
    return tomorrow ? `🌅 rises ${clock(tomorrow.rise)}` : null;
}
// ── time of day ──────────────────────────────────────────
export function timePhrase(now) {
    const sun = sunTimes(now);
    const hour = new Date(now).getHours();
    if (sun) {
        if (now >= sun.set - 60 * 60_000 && now < sun.set)
            return 'golden hour';
        if (now >= sun.set && now < sun.set + 45 * 60_000)
            return 'blue hour';
        if (now >= sun.rise && now < sun.rise + 60 * 60_000)
            return 'first light';
    }
    if (hour >= 23 || hour < 5)
        return 'owl hours';
    if (hour < 9)
        return 'early morning';
    if (hour < 12)
        return 'morning flow';
    if (hour < 14)
        return 'midday';
    if (hour < 18)
        return 'afternoon drift';
    return 'evening';
}
// ── weather (cached, refreshed in a detached curl) ───────
function weatherLabel(now) {
    if (!CITY)
        return null; // opt-in: no city, no weather, no network
    const file = path.join(stateDir(), WEATHER_FILE);
    let text = null;
    let stale = true;
    try {
        const stat = fs.statSync(file);
        stale = now - stat.mtimeMs > WEATHER_TTL_MS;
        // Network text: terminal escapes are stripped before it can reach the screen.
        text = sanitize(fs.readFileSync(file, 'utf8').replace(/\s+/g, ' ').trim());
    }
    catch {
        /* no cache yet */
    }
    if (stale)
        refreshWeather(file, CITY);
    // wttr.in returns an HTML/error page on failure — only accept short answers
    if (!text || text.length > 24 || /unknown|error|<|sorry/i.test(text))
        return null;
    return `${text} ${CITY}`;
}
function refreshWeather(file, city) {
    try {
        ensurePrivateDir(path.dirname(file));
        // Touch first so concurrent renders don't all spawn a curl.
        const fd = fs.openSync(file, 'a', 0o600);
        fs.closeSync(fd);
        fs.utimesSync(file, new Date(), new Date());
        const tmp = `${file}.tmp`;
        const url = `https://wttr.in/${encodeURIComponent(city)}?format=%c%t`;
        // Values go in as positional arguments, never into the script text, so no quoting can break.
        const script = 'umask 077; curl -sfm 5 "$1" > "$2" && [ -s "$2" ] && mv "$2" "$3" || rm -f "$2"';
        const child = spawn('sh', ['-c', script, 'sh', url, tmp, file], {
            detached: true,
            stdio: 'ignore',
        });
        child.unref();
    }
    catch {
        /* best-effort */
    }
}
// ── fortune (cached hourly) ──────────────────────────────
// Calm sources only — the default pool includes zippy (anxious non-sequiturs).
const FORTUNE_FILES = ['wisdom', 'literature', 'songs-poems', 'people'];
function fortuneLabel(state, now) {
    if (state.fortuneAt && now - state.fortuneAt < FORTUNE_TTL_MS) {
        return state.fortune ?? null;
    }
    try {
        const result = spawnSync('fortune', ['-s', '-n', '70', ...FORTUNE_FILES], { encoding: 'utf8', timeout: 800 });
        const text = sanitize((result.stdout ?? '').replace(/\s+/g, ' ').trim());
        if (text && text.length <= 80) {
            state.fortune = text;
            state.fortuneAt = now;
            return text;
        }
    }
    catch {
        /* fortune not installed */
    }
    state.fortuneAt = now; // no fortune this hour (not installed, or too long): don't retry each render
    return state.fortune ?? null;
}
// ── cost sparkline ───────────────────────────────────────
const SPARKS = '▁▂▃▄▅▆▇█';
export function sparkline(values) {
    if (values.length === 0)
        return '';
    const max = Math.max(...values, 0.01);
    return values.map(v => SPARKS[Math.min(7, Math.floor((v / max) * 7.999))]).join('');
}
function costSpark(state, sessionId, cost, now) {
    const costs = state.costs ?? {};
    if (sessionId && cost > 0) {
        costs[sessionId] = { cost, at: costs[sessionId]?.at ?? now };
    }
    const recent = Object.values(costs).sort((a, b) => a.at - b.at).slice(-SPARK_SESSIONS);
    state.costs = Object.fromEntries(Object.entries(costs).sort((a, b) => a[1].at - b[1].at).slice(-SPARK_SESSIONS * 2));
    if (recent.length < 2)
        return null;
    return sparkline(recent.map(r => r.cost));
}
// ── animated pet (cat by day, owl by night) ──────────────
const CAT_FRAMES = {
    sleepy: ['(=-.-=) z', '(=-.-=) zZ', '(=-.-=) zZz', '(=-.-=)'],
    alert: ['(=o.o=)~', '(=o.o=)_/', '(=-.o=)~', '(=o.o=)\\_', '(=o.-=)~'],
    sick: ['(=x.x=)', '(=@.@=);', '(=x.x=);;'],
    happy: ['(=^.^=) ♪', '(=^ω^=) ♫', '(=^.^=)♪♫'],
};
const OWL_FRAMES = {
    sleepy: ['{-,-} z', '{-,-} zZ', '{-,-} zZz', '{-,-}'],
    alert: ['{o,o}', '{O,o}', '{o,O}', '{-,-}', '{o,o}>'],
    sick: ['{x,x}', '{@,@};'],
    happy: ['{^,^} ♪', '{^,^}♪♫'],
};
const PET_COLORS = {
    sleepy: ROSE_PINE.iris,
    alert: ROSE_PINE.foam,
    sick: ROSE_PINE.love,
    happy: ROSE_PINE.gold,
};
/** One frame per statusLine refresh (refreshInterval: 2), padded so the line doesn't jitter. */
export function renderAnimatedPet(mood, now = Date.now()) {
    const frames = (isNight(now) ? OWL_FRAMES : CAT_FRAMES)[mood];
    const width = Math.max(...frames.map(f => [...f].length));
    const frame = frames[Math.floor(now / 2000) % frames.length];
    return paint(PET_COLORS[mood], frame.padEnd(width + frame.length - [...frame].length));
}
// ── sound cues on mood transitions ───────────────────────
const MOOD_SOUNDS = {
    happy: '/System/Library/Sounds/Glass.aiff',
    sick: '/System/Library/Sounds/Submarine.aiff',
};
export function petMoodTransition(sessionId, mood, sounds) {
    if (!sessionId)
        return;
    const state = readState();
    const moods = state.moods ?? {};
    const previous = moods[sessionId];
    if (previous === mood)
        return;
    moods[sessionId] = mood;
    state.moods = Object.fromEntries(Object.entries(moods).slice(-20));
    writeState(state);
    const sound = MOOD_SOUNDS[mood];
    if (sounds && previous !== undefined && sound && process.platform === 'darwin') {
        try {
            spawn('afplay', ['-v', '0.4', sound], { detached: true, stdio: 'ignore' }).unref();
        }
        catch {
            /* best-effort */
        }
    }
}
// ── lines ────────────────────────────────────────────────
export function renderVibeLines(sessionId, cost, now = Date.now()) {
    const state = readState();
    const dot = paint(ROSE_PINE.muted, ' · ');
    const moon = moonPhase(now);
    const sky = [
        paint(ROSE_PINE.iris, `${moon.glyph} ${moon.name} d${moon.age}`),
    ];
    const weather = weatherLabel(now);
    if (weather)
        sky.push(paint(ROSE_PINE.foam, weather));
    const sun = sunLabel(now);
    if (sun)
        sky.push(paint(ROSE_PINE.gold, sun));
    sky.push(paint(ROSE_PINE.rose, `✧ ${timePhrase(now)}`));
    const whisper = [];
    const fortune = fortuneLabel(state, now);
    if (fortune)
        whisper.push(paint(ROSE_PINE.subtle, `❝ ${fortune}`));
    const spark = costSpark(state, sessionId, cost, now);
    if (spark)
        whisper.push(`${paint(ROSE_PINE.muted, 'spend')} ${paint(ROSE_PINE.pine, spark)}`);
    writeState(state);
    const lines = [sky.join(dot)];
    if (whisper.length > 0)
        lines.push(whisper.join(dot));
    return lines;
}
// ── gradient bars ────────────────────────────────────────
const GRADIENT_STOPS = [ROSE_PINE.foam, ROSE_PINE.iris, ROSE_PINE.rose, ROSE_PINE.gold, ROSE_PINE.love];
/** A bar whose cells step foam → iris → rose → gold → love by position, so fuller bars run hotter. */
export function gradientBar(percent, width) {
    const safeWidth = Number.isFinite(width) ? Math.max(0, Math.round(width)) : 0;
    const safePercent = Number.isFinite(percent) ? Math.min(100, Math.max(0, percent)) : 0;
    const filled = Math.round((safePercent / 100) * safeWidth);
    let out = '';
    for (let i = 0; i < filled; i += 1) {
        const stop = safeWidth <= 1 ? 0 : Math.round((i / (safeWidth - 1)) * (GRADIENT_STOPS.length - 1));
        out += `\x1b[${GRADIENT_STOPS[stop]}m█`;
    }
    out += `\x1b[${ROSE_PINE.muted}m${'░'.repeat(safeWidth - filled)}`;
    return `${out}${RESET}`;
}

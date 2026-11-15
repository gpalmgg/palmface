# Palmface statusline

The statusline Palmface puts under Claude Code's prompt. It shows the model, the project and
git branch, context and usage bars, cost and cache, the session's tools, agents and todos, and a
small pet that is a cat by day and an owl by night. A sky line above it shows the moon, the time
of day and, if you ask for them, your city's weather and the sun.

It is a modified copy of [claude-hud](https://github.com/jarrodwatts/claude-hud) by Jarrod
Watts, under the MIT licence (see `LICENSE`).

## How it is wired

`install.sh --claude` copies the built `dist/` and `statusline.sh` to
`~/.claude/palmface/statusline/`, then merges this into `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "/bin/bash \"$HOME/.claude/palmface/statusline/statusline.sh\"" } }
```

It needs `node` 18 or newer at runtime (`brew install node`, the kit's `Brewfile`, or any node
you already manage with nvm, volta or asdf). `statusline.sh` finds node on your PATH or in
Homebrew's folders. Without a usable node it prints a one-line hint.

**If you already have a `statusLine`, yours stays.** Palmface's merge never overwrites a value
you set, so your own `command` wins. To try this one, replace your `statusLine` with the block
above. Uninstall takes out only what Palmface added.

**Animation.** The pet changes frame each time Claude Code redraws the statusline. To keep it
moving while the session is idle, add `"refreshInterval": 2` to your `statusLine`. That runs the
statusline every 2 seconds.

## Settings

Defaults are built in. To change them, create `~/.claude/palmface-local/statusline.json` with
only the keys you want to change. That folder is yours: Palmface never writes there, and
uninstall leaves it alone. For example:

```json
{
  "lineLayout": "compact",
  "display": { "showVibes": false, "showPet": true, "customLine": "ship small" }
}
```

Useful `display` keys (all true or false unless noted):

| Key | Default | What it shows |
|---|---|---|
| `showVibes` | true | the sky line (moon, time of day, weather, sun) and a whisper line (a `fortune` if installed, a cost sparkline) |
| `showPet` | true | the cat/owl, whose mood follows the session |
| `gradientBars` | true | bars that warm up as they fill |
| `showDaemon` | true | a two-word name for the session |
| `showCost`, `showCacheRatio`, `showBurnRate` | true | spend, cache hits, spend per hour |
| `showTools`, `showAgents`, `showTodos` | true | what the session is doing |
| `showStuck` | true | a note when the same file is edited 3+ times in a row |
| `showCompactNudge` | true | when you usually compact, learned from your sessions |
| `vibeSounds` | false | a system sound when the pet's mood changes |
| `customLine` | `""` | any short text (up to 80 characters) |

The other keys and the colour options are in `src/config.ts`.

## Location (opt-in, no default)

Set these in your shell, or in the `env` block of `~/.claude/settings.json`:

| Variable | Effect |
|---|---|
| `PALMFACE_CITY` | adds the city's weather to the sky line, fetched from wttr.in at most every 30 minutes |
| `PALMFACE_LAT`, `PALMFACE_LON` | decimal degrees; add sunrise, sunset and golden/blue hour |

The weather fetch is the statusline's only network call. It never happens while
`PALMFACE_CITY` is unset. Without coordinates, night is 19:00 to 07:00 local time. With them,
the pet turns into an owl at sunset, while `hello` and the critter hook keep the fixed hours.

## Colours

Everything uses your terminal's ANSI colour slots, so it follows your terminal theme. Palmface's
Ghostty config switches between Rosé Pine Moon and Dawn with the macOS appearance.

## Files it writes

Only small caches in `~/.claude/palmface/state/statusline/` (transcript summaries, the session
ledger, the weather). Uninstalling Palmface removes them with the rest of
`~/.claude/palmface/`. It only reads your `~/.claude/palmface-local/statusline.json`.

## Rebuilding

`dist/` is committed, so installing needs no build. After changing `src/`:

```sh
npm install   # TypeScript and Node's types, dev only
npm run build
```

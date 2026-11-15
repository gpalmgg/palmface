# Palmface's hooks

Small scripts Claude Code runs at fixed moments. Each one backs a section of Palmface's
`CLAUDE.md`, and each one is a single switch away from off.

They live in `~/.claude/palmface/hooks/` and are registered in `~/.claude/settings.json` as
`/bin/bash "$HOME/.claude/palmface/hooks/<name>.sh"`. They need nothing beyond stock macOS
(bash, `plutil`, awk, grep): no python, jq or node. Every one exits 0 when something goes
wrong, so a broken hook never stops your session.

## The list

| Hook | When it runs | What it does | Blocks? | Switch |
|---|---|---|---|---|
| `critter-of-the-turn.sh` | each prompt | hands Claude one critter for the reply (owls at night, cats by day) | no | `PALMFACE_CRITTERS=off` |
| `vibe-sound.sh` | turn ends · needs you | a soft macOS system chime | no | `PALMFACE_SOUNDS=off`, or the file `~/.claude/palmface/sounds.off` |
| `judgment-preflight.sh` | each prompt | when you ask for an assessment, reminds Claude to name assumptions, unknowns and risks first | no | `PALMFACE_PREFLIGHT=off` |
| `sycophancy-stop.sh` | turn ends | sends back a reply that leans on agreement or praise instead of substance | once | `PALMFACE_SYCOPHANCY=off` |
| `closing-drip.sh` | each prompt + turn ends | after "are we done?", sends back a reply that hands you a fresh list of open work | once | `PALMFACE_CLOSING=off` |
| `anti-guessing.sh` | turn ends | sends back a reply that ends on a question in prose, or rests on an unasked guess | once | `PALMFACE_GUESSING=off` |
| `context-size.sh` | each prompt | when the context passes 150K, 250K and 400K tokens, asks Claude (once each) to tell you and offer a handoff file | no | `PALMFACE_CONTEXT=off`; first threshold `PALMFACE_CONTEXT_NUDGE` |
| `context-guardian.sh` | before a compaction · right after | saves a snapshot of the session (last request, files edited, git state, plan files), then hands it back to Claude | no | `PALMFACE_GUARDIAN=off` |
| `cost-tracker.sh` | turn ends | keeps a token ledger per session and model; `cost-tracker.sh report` reads it | no | `PALMFACE_COST=off` |

`PALMFACE_HOOKS=off` turns every one of them off at once. (It doesn't touch the statusline. To
remove that, delete `statusLine` from `~/.claude/settings.json`.)

## Setting a switch

Put it in the `env` block of `~/.claude/settings.json`, which every session reads:

```json
{ "env": { "PALMFACE_GUESSING": "off" } }
```

or export it in the shell you start `claude` from.

## How "blocks once" works

A Stop hook that disagrees with a reply exits with code 2 and writes a short note. Claude Code
shows the note to Claude, which then writes a corrected follow-up (the original reply has
already been shown to you). Claude Code marks that follow-up turn, and Palmface's hooks never
block it, so each reply is sent back at most once and nothing can loop.

Words inside code, inside "double quotes" and in `>` blockquotes are ignored, so Claude can
discuss these phrases without tripping anything.

## Quiet on autopilot

`closing-drip`, `anti-guessing` and `context-size` stay quiet when nobody is there to answer:

- while the user has switched autopilot on for the project folder with `/palmface-autopilot`
  (the switch is in `~/.claude/palmface/state/autopilot/`; a `.autopilot/on` file inside a
  project is ignored, so a repository can't quiet them; see `autopilot.md`);
- with `PALMFACE_AUTOPILOT=on` set (handy for `claude -p` and scripted runs);
- when Claude Code marks the run unattended (`CLAUDE_CODE_SESSION_ATTENDED=0`, in versions
  that set it).

They also stay quiet for a turn in which Claude already used `AskUserQuestion`.

## Files they read and write

| Hook | Reads | Writes |
|---|---|---|
| critter-of-the-turn | `~/.claude/palmface/critters.txt`, your `~/.claude/palmface-local/critters.txt` | nothing |
| vibe-sound | `/System/Library/Sounds/` | nothing |
| judgment-preflight, sycophancy-stop | the hook's JSON | nothing |
| anti-guessing | the hook's JSON, the session transcript | nothing |
| closing-drip | the hook's JSON, the session transcript | `~/.claude/palmface/state/closing-drip/` (a flag per session, removed after the reply) |
| context-size | the session transcript | `~/.claude/palmface/state/context-size/` (one number per session) |
| context-guardian | the session transcript, git | `~/.claude/palmface/state/context-guardian/<session>.md` (key-shaped strings in the last request masked; lists only files this session wrote) |
| cost-tracker | the session transcript and its subagents' transcripts | `~/.claude/palmface/state/cost-tracker/sessions.tsv` |

The transcript is the file Claude Code itself names in each hook's input. It is only read.
The hooks write with `umask 077`: state folders are 0700 and files 0600, readable by you alone.
When you uninstall Palmface, the cost ledger, chain logs and anything else made under
`~/.claude/palmface/` after install are moved to `~/.palmface-backup/uninstall-<ts>/kept/`; the
statusline caches and the guardian's snapshots are removed.
Old state is swept as it goes (a day for closing-drip, a week for context-size and the
guardian). The cost ledger is a ledger: it keeps one row per session and model until you delete
it.

## Known limits

- The Stop hooks read prose with patterns. They will sometimes miss, and now and then they
  will send back a reply that was fine. One extra turn is the cost; switch a hook off if it
  keeps misfiring for the way you work.
- In a session without `AskUserQuestion` (some headless setups), `anti-guessing` would ask for
  a tool Claude can't use. Run those with `PALMFACE_AUTOPILOT=on` or `PALMFACE_GUESSING=off`.
- `cost-tracker` counts tokens only. For dollars, write your own
  `~/.claude/palmface-local/prices.tsv` (format in the script's header). Prices change, so
  Palmface ships none. If your Claude Code copies an old conversation into a new session when
  you resume it, the copied replies are counted again under the new session.
- The Stop hooks read Claude's reply from the hook's input, or from the transcript's last
  reply on Claude Code versions that don't send it. The transcript readers follow Claude Code's
  current transcript format; if that format changes, they go quiet rather than break.
- The patterns read English only.

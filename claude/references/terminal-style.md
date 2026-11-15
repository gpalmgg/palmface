# Keeping the terminal alive: ideas and recipes

The point is a working space that feels inhabited. Small, well-timed touches beat constant
decoration.

## What Palmface gives you

| Thing | Where | Notes |
|---|---|---|
| Critter of the turn | the critter hook (UserPromptSubmit) | one owl (19:00–07:00) or cat (by day) per turn, handed to you as context |
| Critter bank | `~/.claude/palmface/critters.txt`, plus the user's `~/.claude/palmface-local/critters.txt` | `@ <owl\|cat> <name>`, the art, a blank line |
| Cows | `~/.config/palmface/cows/{owl,cat,sleepycat}.cow` | with the terminal layer only: `cowsay -f <path> "…"`; in the user's zsh: `owl`, `meow`, `nap` |
| Sounds | the vibe-sound hook | a soft system chime when a turn ends or needs the user |
| Statusline | `~/.claude/palmface/statusline/` | moon, pet, context bar; the user's settings in `~/.claude/palmface-local/statusline.json` |

`figlet`, `cowsay` and `lolcat` are in Palmface's Brewfile, but the user may have skipped them.
Check before you use one, and skip quietly when it is missing:

```bash
command -v figlet > /dev/null && figlet -f small "shipped"
```

## Moments

| Moment | A touch that fits |
|---|---|
| Greeting at the start of a session | `figlet -f small "hello"`, or the critter |
| Starting a big task | a small banner with the task's name |
| A task shipped | `figlet -f slant "DONE"` (through `lolcat` when present) |
| All tests green | `cowsay -f ~/.config/palmface/cows/owl.cow "All green"` |
| Something broke | a cat that shrugs: keep it light, and keep the fix serious |
| Status summary | a box-drawn dashboard, as below |

```
╭─ status ───────────────────╮
│ tests     42 passed        │
│ lint      clean            │
│ next      write the docs   │
╰────────────────────────────╯
```

## Craft notes

- **Tool output may be folded away.** The user doesn't always see what a Bash call prints. If a
  banner is meant to be seen, put it in your reply inside a code block.
- **Narrow is safer.** Keep art and boxes within about 60 columns so they don't wrap in a split
  pane.
- **Use the critter you were given.** The hook rotates them so replies don't all look alike.
- **Never in deliverables.** No art, emoji or colour codes in files, commit messages or code you
  write, unless that is the task.
- **Read the room.** When the user is stressed or the news is bad, one quiet critter is plenty.

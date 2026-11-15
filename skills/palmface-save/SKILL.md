---
name: palmface-save
description: Save one thing worth keeping from the session into the right place - a decision with its reasoning, an insight, a bookmark to a conversation moment (all as dated entries in the project's docs/ folder), or a fact for Claude Code's own memory, checked through the memory quality gate. With no argument it sweeps the session for unsaved decisions and insights. Use when the user says "save this", "log this decision", "remember this", "note that down", "bookmark this", or "save before I clear".
argument-hint: "[decision|insight|bookmark|memory] <text>"
---

# palmface-save

One command, four destinations. Pick the destination, write a small clean entry, confirm in one
line. Nothing is saved without a stated reason; saving everything is a way of keeping nothing.

## Choose the mode

| Input | Mode | Goes to |
|---|---|---|
| `decision "..."` | decision | `docs/decisions.md` |
| `insight "..."` | insight | `docs/insights.md` |
| `bookmark "..."` | bookmark | `docs/bookmarks.md` |
| `memory "..."` | memory | Claude Code's project memory |
| `"text"` with no mode | classify it | see below |
| nothing | sweep | see below |

**Classify.** A choice between options, with a reason, is a decision. A realisation or pattern is
an insight. "Remember this moment of the conversation" is a bookmark. A fact about how the user
works or about the project that a future session needs, and that is written nowhere, is memory. If
two fit, ask with `AskUserQuestion` (recommended option first). On autopilot (the user switched
it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow
`~/.claude/palmface/references/autopilot.md`: choose, log it to `.autopilot/decisions.md`.

All project files go in the project root (the git root of the working directory, else the working
directory). Create the file with a one-line heading if it does not exist. Append; never rewrite or
reorder earlier entries. Use today's date from `date +%F`.

## Decision

Needs a choice, the alternative and the reason. If the text lacks the alternative or the reason,
ask for it; do not invent one. On autopilot, queue the entry in `.autopilot/queue.md` instead of asking.

```
### 2026-01-31: <short title>
**Chose:** <what>
**Over:** <what was rejected>
**Why:** <reasoning>
**Context:** <what prompted it; the plan folder or task if there is one>
```

## Insight

```
### 2026-01-31: <short title>
<one to three sentences: the realisation, in plain words>
Source: <task, file or plan folder it came from>
```

## Bookmark

A pointer to a moment worth finding again, not a transcript. Summarise the last few exchanges on
that topic in 3 to 8 lines.

```
### 2026-01-31: <short title>
**Session:** <name from /rename, or "unnamed">
**Moment:** <what happened or was decided in the conversation>
**Why it matters:** <one sentence>
```

Suggest `/rename` if the session is unnamed, so the bookmark can be traced back with
`/palmface-sessions`.

## Memory

Claude Code's own project memory. Read `~/.claude/palmface/references/memory.md` first and follow
it: where memories live, the four-point quality gate (confidence, derivability, cap, priority), and
what never to store. Then:

1. Run the gate. If the text fails it (project status, something visible in the code or git
   history, a plan summary, a secret), say which check failed and where it belongs instead (a
   `docs/` file, the user's CLAUDE.md, nowhere). Save only if the user overrides.
2. Save it the way Claude Code's auto memory works in this session: the session's own memory
   instructions name the folder and the index file, so follow those rather than a path of your own.
   One fact per entry, with a `Priority:` line, plus its line in the index. Update an existing entry
   on the same topic instead of adding a near-duplicate. Feedback and project memories get a
   **Why:** and a **How to apply:** line.
3. A rule that applies to every project goes in the user's own `~/.claude/CLAUDE.md`, not memory.
   Suggest the line; add it only when the user asks.

If this session has no auto memory (its instructions name no memory folder), say so and offer a
`docs/` entry instead; do not create a memory folder by hand.

## Sweep (no argument)

Scan the conversation for decisions made, insights stated and facts about the user's preferences
that nothing has recorded yet. Propose a short list (at most 6 items, each with its mode) with
`AskUserQuestion` using multi-select, then save the ones approved. On autopilot, save the ones that
pass the gate and log what you saved. If there is nothing, say "nothing unsaved" and stop.

## Confirm

One line per save: what was saved and where (`Saved decision -> docs/decisions.md`). Do not
re-print the entry. Never save credentials, tokens or other people's private details, and do not
commit the file unless the user asks.

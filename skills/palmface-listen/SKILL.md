---
name: palmface-listen
description: Turn a multi-point message into a numbered checklist, confirm it, then address every point in order so nothing is dropped. Use when the user sends a block of feedback with several items, says "a few things" or "several points", reviews a plan in paragraphs, or types /palmface-listen.
argument-hint: "[the feedback, or leave empty to use the last message]"
---

# Listen

Multi-point feedback fails when points are merged, skipped or half-done. This skill makes dropping one impossible.

## When it applies

- The user types `/palmface-listen`.
- A message contains four or more distinct requests or comments, or opens with "a few things", "several points", or is paragraph-form feedback on a plan or draft. In that case say "Parsing your feedback into a numbered list." and start.

## Protocol

### 1. Extract and number

Pull out every distinct point, request or aside, however small. One concern per number; if a sentence holds two asks, split it. Present:

```
I found N points:
1. <point, restated concisely>
2. ...
Confirm this is complete, or add or correct.
```

Say the count out loud ("I see N points") so a miss is visible.

### 2. Confirm

Do not start work until the user confirms or corrects the list. Fold in additions as new numbers; keep existing numbers stable so "point 3" always means point 3. If a point is ambiguous, ask about that number only, using `AskUserQuestion` (recommended reading first, max 4 per round).

### 3. Work in order

Take the points one at a time, in order. For each: name the number, do the work (edit, explain, decide), mark it done. Never combine points, skip one because it looks minor, or reorder.

### 4. Close with the checklist

```
1. <summary> : done
2. <summary> : done
3. <summary> : blocked, <reason>
N/N complete (or N-1/N, blockers listed)
```

A point is "blocked" only if you tried to resolve it (read the files, searched the repo) and still need something only the user knows. Blockers go in one `AskUserQuestion`, not a prose list.

## Rules

- Never start implementing before the list is confirmed.
- If the user adds "and also..." later, it is a new numbered point appended to the list.
- On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: skip the confirmation step, show the list as a record, log any ambiguous reading you chose to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## Tips to give the user when they ask how to write feedback

1. Numbered lists beat bullets beat prose; each point becomes a trackable unit.
2. End with a count: "That's 6 changes. Address all 6."
3. One concern per point; give the reason ("remove the cache, it serves stale data").
4. Say what to do rather than what not to do.
5. When a thread is going in circles after two failed corrections, `/clear` and restate the task in one fresh message.

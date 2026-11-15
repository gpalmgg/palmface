---
name: palmface-start
description: Open a session with a greeting, a status card for the current project (git, autopilot, latest handoff, anything waiting for the user) and a suggested session name. Uses only what Palmface ships - figlet, lolcat and Palmface's cows when they are installed. Use when the user types /palmface-start or asks to start the session.
argument-hint: "[what you're working on]"
disable-model-invocation: true
---

# Start a session

Keep the whole thing to one screen.

## 1. Run the card

From the project folder:

```bash
/bin/bash ~/.claude/skills/palmface-start/start.sh
```

It prints a banner, a cow when Palmface's cows are installed, and the status card, then
`session name: <project>-<date>`. It reads only, and skips quietly whatever isn't installed:
figlet, lolcat, cowsay, the cow files under `~/.config/palmface/cows/` (those come with the
terminal layer), or git. If the user said they want it quiet, add `--plain`.

## 2. Greet

Reply with:
- the critter of the turn, if a hook handed you one, in a code block;
- one short line of greeting with the day and time;
- the card's facts in a few words. Don't repeat the whole card, since the user saw it in the
  tool output. Point at anything that needs them: a queue in `.autopilot/queue.md`, held sends in
  `OUTBOX.md`, a `REVIEW.md` they haven't read, or unpushed commits. Those are status, said once.
- If there is a recent handoff file, name it and offer to pick up from it.

## 3. Name the session

Suggest a name. Use the card's `<project>-<date>` or, if the user said what they are working on
(`$ARGUMENTS`), `<topic>-<date>`, for example `fix-login-nov15`. Tell them to type
`/rename <name>`; you can't run slash commands yourself. A named session is easier to find later
with `/resume`, or with `/palmface-sessions` if that is installed.

## Don't

- Don't change settings, permission modes or anything outside the project. Start only reads.
- Don't ask a question unless the user asked for something that needs one.
- Don't launch into work they haven't asked for. Offer it, and wait.

---
name: palmface-autopilot
description: Turn autopilot on or off for the current project (on | off | status). On autopilot you make the mid-run calls yourself, log each decision, queue what must wait for the user, hold outbound sends in OUTBOX.md and finish with REVIEW.md, while Palmface's question hooks stay quiet. Use only when the user asks for it - "/palmface-autopilot on", "autopilot on", "go auto", "autopilot off", "is autopilot on?" - never on your own initiative.
argument-hint: on | off | status
---

# Autopilot on / off

Autopilot is the user's switch, not yours. Run this skill only when they ask for it, and never
turn autopilot on because a task looks long.

## 1. Flip the switch

Run the script from the project folder, the folder this session started in, which is the one
Palmface's hooks check:

```bash
/bin/bash ~/.claude/skills/palmface-autopilot/autopilot.sh <on|off|status>
```

Pass what the user gave (`$ARGUMENTS`). With no argument, run `status`. If your shell has moved
away from the folder the session started in, add that folder as a second argument
(`autopilot.sh on <project-folder>`), so the switch lands where the hooks look.

The switch lives outside the project, in `~/.claude/palmface/state/autopilot/` (one file per
folder, named by a hash of its path). It is the only thing the script writes, and `off` removes
it again. Never switch autopilot any other way. Nothing inside a project turns autopilot on: a
`.autopilot/on` file there, for example one that came with a cloned repository, is ignored by the
hooks, by `/palmface-start` and by you. If you find one, autopilot is still off until the user
says otherwise.

The run's record (`.autopilot/decisions.md` and `.autopilot/queue.md`) does sit in the project.
It switches nothing, so committing it is safe. If the user would rather keep it out of git, offer
to add `.autopilot/` to `.gitignore` (or to `.git/info/exclude`, which stays local), and do it
only when they say yes.

## 2. Say what happened, in one line

For example: "Autopilot is on for this folder." A small critter is fine. Don't ask anything.

## 3. Then

- **On:** read `~/.claude/palmface/references/autopilot.md` now, follow it for the rest of the
  session, and carry on with whatever was in progress. The short version:
  - make the calls yourself, using the user's stated goals and, if it exists,
    `~/.claude/palmface-local/persona.md`;
  - log every decision as one line in `.autopilot/decisions.md`: what, the choice, why, and your
    confidence;
  - queue what must wait for the user in `.autopilot/queue.md`: outbound actions, irreversible
    loss of data, their own time or hands, and facts only they know. Then keep going;
  - draft outbound actions but don't perform them. Each goes in `OUTBOX.md` with what, where to
    and how to send it;
  - finish the run with `REVIEW.md`, covering built, decisions, outbox and waiting on you.

  These four files sit in the project folder, and you create each one when it first has
  something to say. Apart from the switch itself, autopilot writes no state anywhere else.
- **Off:** the normal asking rules in Palmface's `CLAUDE.md` apply again. If the run made
  decisions or queued anything and there is no `REVIEW.md` yet, write it now so the user has the
  summary in one place. Leave `.autopilot/decisions.md` and `.autopilot/queue.md`, because they
  are the record of the run.
- **Status:** report the script's lines as they are. If the user has `PALMFACE_AUTOPILOT=on` set,
  autopilot is on for the session whatever the folder says, and turning it off means unsetting
  that variable in their shell. You can't do that for them.

## Headless runs

Scripted or chained sessions (`claude -p`) can't type a command. They set
`PALMFACE_AUTOPILOT=on` in the environment instead, and the same rules apply.

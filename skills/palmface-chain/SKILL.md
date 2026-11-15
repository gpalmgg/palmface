---
name: palmface-chain
description: Run a plan's numbered session prompts (docs/plans/<slug>/vN-session-prompt.md) back to back, each in a fresh headless claude -p inside a detached tmux session, stopping at a broken relay (no new commit or no handoff) or at a prompt marked HUMAN GATE. Use when a multi-session build has its prompts on disk and the user wants the remaining sessions run unattended instead of typing /clear between them. Triggers - "chain the sessions", "run the rest of the sessions", "activate the chain", "chain status", "stop the chain".
argument-hint: "[run|status|stop] <prompt-dir> --permission-mode MODE [--from N] [--until N]"
---

# palmface-chain

A relay for multi-session builds. Each session reads a prompt file, does its work, commits, writes
`vN-handoff.md` and the next prompt, then ends. A small script in tmux runs the next prompt in a
fresh context. State lives in files, so no session needs the previous one's conversation.

The script is `~/.claude/skills/palmface-chain/scripts/chain.sh` (bash, needs `git` and `tmux`;
`--help` lists every option). Prompts come from `/palmface-metaplan` or are written by hand.

## Run

1. Find the prompt folder (`docs/plans/<slug>/`) and list its `vN-session-prompt.md` files with
   which already have a `vN-handoff.md`. Say which range will run.
2. Pre-flight. Stop at the first failure and say why in one line:
   - the working tree is clean (the script refuses otherwise; never commit the user's work to
     make it clean);
   - the first prompt's "Before this prompt" git expectation matches `git log`;
   - the plan files and prompts are committed (`/palmface-metaplan` ends by committing them).
     The autopilot record (`.autopilot/`, `OUTBOX.md`, `REVIEW.md`) doesn't count as dirty;
   - any prompt that installs on real data, sends something to other people or spends money has a
     line that starts with `HUMAN GATE` (after any `#`, `>`, `*` or emoji). The chain stops before
     it. If the plan has such a step and the line is missing, add it to that prompt and tell the
     user. Don't start any other line with those words;
   - each prompt tells its subagents to write their findings to a file in the plan folder, so the
     result survives on disk and the session reads only what it needs.
3. **Ask for the permission mode** with `AskUserQuestion`. It has no default and you never choose
   it for the user. In a headless session a tool that isn't allowed is denied, not asked, and
   every session has to edit files, run the tests and `git commit`. If it can't commit, the relay
   breaks after session one. So the real choice is:
   - **(Recommended, for a repository the user trusts)** `acceptEdits` plus allow rules for what
     the sessions must run: the test command, `git add` and `git commit`, for example
     `"permissions": {"allow": ["Bash(git add:*)", "Bash(git commit:*)", "Bash(npm test:*)"]}`.
     Propose them for the project's `.claude/settings.local.json`, which is personal and meant to
     stay out of git, not the committed `.claude/settings.json`, which would hand the same rules
     to everyone who clones the repository. Show the user the rules; they add them, or approve
     you adding them. If `git check-ignore .claude/settings.local.json` prints nothing, offer to
     add it to `.gitignore` too. Edits are allowed; everything else runs only if a rule allows it.
     `dontAsk` works the same way, with edits also under the rules. Tell the user three things
     before they pick:
     - **It is not a sandbox.** With edits allowed, `npm test` and `git commit` run whatever the
       repository's test script and git hooks say, so a session (or text it read and obeyed) can
       change those and run them, unattended. Use it only on a repository whose contents they
       wrote or fully trust, with prompt files they wrote. For anything else, run the chain in a
       container or a VM.
     - **Trust comes first.** Claude Code ignores a project's rules until that folder has been
       trusted, and headless sessions never show the trust prompt. If the user hasn't opened
       Claude Code in this project folder and accepted it, they do that once first, or session
       one can't commit (its `.err` says the rules were ignored).
     - **What trusting enables.** Trusting a folder also turns on that project's own Claude Code
       settings, including any hooks in its `.claude/settings.json`, which are commands Claude
       Code runs on its own. Fine for their own repository; a reason not to trust one they
       didn't write.
   - `bypassPermissions`: every session runs any command with no checks, unattended. Only for a
     throwaway or sandboxed checkout, never for a repo holding anything they can't lose;
   - `plan`, or the default ask-every-time mode: sessions can't make changes. Not useful here.

   `claude --help` lists the modes the user's version has; the script passes the name through.
   On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or
   `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: do not guess a
   riskier mode than the user has already stated; log the choice to `.autopilot/decisions.md`, or
   queue the question in `.autopilot/queue.md` and do not launch.
4. Preview, then launch:

   ```
   ~/.claude/skills/palmface-chain/scripts/chain.sh run <prompt-dir> --permission-mode MODE --dry-run
   ~/.claude/skills/palmface-chain/scripts/chain.sh run <prompt-dir> --permission-mode MODE
   ```

   Useful flags: `--from N`, `--until N`, `--prefix P` (default `v`), `--model M`, `--name NAME`,
   `--timeout SECONDS` (per session, needs `timeout` or `gtimeout`). The script sets
   `PALMFACE_AUTOPILOT=on` for every headless session.
5. Report in one short block: range, permission mode, tmux name (`chain-<name>`), log folder, the
   stop rules, where the human gate is. Then stop. Do not poll.

## The stop rules

After each session the script checks three things: `claude` exited 0, HEAD moved, the handoff file
exists. If any fails it stops (exit 5) and logs `BROKEN RELAY` in `chain.log`. It also stops before
a `HUMAN GATE` prompt (exit 4). Logs and per-session output are in
`~/.claude/palmface/state/palmface-chain/<name>/`; a session's `.out` file stays empty until that
session ends, which is normal.

## Status and stop

- `chain.sh status <prompt-dir>`: tmux state, last log lines, `git log -3`, `git status`. Add one
  sentence: which session is running, which stopped and why.
- `chain.sh stop <prompt-dir>`: kills the loop and its tmux session. Committed work stays;
  uncommitted work stays in the tree. Say so and show `git status --short`.

## When the chain stopped early

Read `chain.log` and the last `.err`. Report the reason in two sentences. Check `git worktree list`
for half-built work. Do not relaunch unless asked; when asked, relaunch with `--from N` once the
tree is clean or the leftovers are committed or discarded by the user. If the interrupted session
left useful work, point the next prompt at it ("the previous run stopped after X; finish the rest").

## Rules

- Never chain a HUMAN GATE prompt; never delete a `HUMAN GATE` line.
- One chain per project at a time. Parallel headless sessions are heavy on a laptop.
- A session with nobody to ask must make its judgement calls from the prompt. If a prompt leaves
  a real decision open, fix the prompt before launching.
- A scheduled "commit everything" job (cron, launch agent) can fool the HEAD-moved check by
  committing half-done work. Mention this if the chain will run through such a job's time.

## Writing a good session prompt

Each prompt must work for a reader with no memory. Shape: where the repo stands (expected top
commit; "if not, say so and stop"), what to build, what to read first in order, the rules (tests,
frozen files, commit format), and what to leave behind (tick `build-spec.md`, write
`vN-handoff.md`, write the next prompt in this same shape, commit).

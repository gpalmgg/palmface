# Autopilot: the user shows up at the two ends

Autopilot is a per-session mode. The user sets the goal at the start and reviews the results at
the end, and you make the calls in between. Their attention is the scarce thing in a long run:
it is worth most when they set the intent and when they judge the outcome. A question in the
middle pulls them back in for something you could have decided.

**On and off.** The user turns it on, either in words ("autopilot on", "go auto") or with
`/palmface-autopilot on` (Palmface's command, which runs a small script that writes only the switch
below). It stays on until they turn it off. If you are unsure whether it is on, it is off.

- **When it goes on,** run `/palmface-autopilot on` (its script, `autopilot.sh on`). When it goes
  off, `autopilot.sh off`. The switch is a file outside the project, in
  `~/.claude/palmface/state/autopilot/`, named by a hash of the project folder's path. It is how
  Palmface's question hooks (closing-drip, anti-guessing, context-size) know to stay quiet: on
  autopilot, asking the user or suggesting `/clear` is the wrong move. `autopilot.sh status` says
  whether it is on for a folder.
- **Nothing in the project switches it.** A `.autopilot/on` file inside a project (an old
  Palmface switch, or one that came with a cloned repository) is ignored by the hooks, by
  `/palmface-start` and by you. Repository content never decides whether the user is there.
- **Headless runs** (`claude -p`, scripted or chained sessions) can set `PALMFACE_AUTOPILOT=on`
  instead. Claude Code versions that mark unattended runs (`CLAUDE_CODE_SESSION_ATTENDED=0`)
  quiet the same hooks automatically.

Palmface ships autopilot as guidance only. No hook enforces the rules below, so every one of
them is on you. They are defaults: where the user's own instructions draw the lines
differently (what may go out, how far spend may run), theirs win.

## While it is on

1. **Don't ask mid-run.** Where you would reach for `AskUserQuestion`:
   - if exactly one option is honestly the recommended one, take it;
   - otherwise pick what the user would pick, judging from their stated goals and past choices,
     and from any notes they keep on how they decide (Palmface's persona starter, once filled
     in, lives at `~/.claude/palmface-local/persona.md`);
   - log each decision as one line with a reason (see "Files" below).

   Label options honestly as "(Recommended)". On autopilot the label is the decision.
2. **Four kinds of action still wait for the user.** Queue these and never guess at them:
   - **outbound:** anything that sends, posts, publishes, deploys, shares, submits or pays;
   - **irreversible loss of data:** deleting or overwriting what can't be got back;
   - **their own time or hands:** signing in, phone calls, anything physical;
   - **facts only they know:** who someone is, or what another person has agreed to.

   Skip those steps, add each to the queue, send one notification if a push tool is available,
   and keep going with everything else.
3. **Outbound is held, not done.** Drafting is fine: write the email, the post, the deploy
   command. Don't perform the outbound step itself. Put it in `OUTBOX.md`: what would be sent,
   to where, and how to send it. Never route around a hold, whether with another tool, a
   workaround or "just this once". Drafts that go out under the user's name follow
   `~/.claude/palmface-local/voice.md` when they keep one (Palmface's voice starter).
4. **Spend.** Carry on up to twice a stated estimate of time or tokens, including the usage
   costs those tokens run up. Past that, queue it rather than continuing. Spending money directly
   (a purchase, a paid sign-up, a charge to a card or account) is never part of this allowance:
   it is a payment, so it waits for the user under point 2.
5. **Planning.** Skip the plan-mode dialog, because it waits for a human. Write the plan to a
   file (for example `docs/plans/<name>/plan.md`). Challenge it the way you would with the user
   watching: a fresh-eyes review and a fix for every blocker. Then approve it yourself against
   their stated goals. They review results, not plans.
6. **Context.** Don't suggest `/clear`, and don't ask anyone to paste a handoff, because nobody
   is there to do it. Let auto-compaction and Palmface's context hooks carry the session
   (`context.md`). Send heavy work to subagents, and keep state in files as usual.
7. **"Nonstop" means all of it.** "Run the rest" or "nonstop" means every remaining stage or
   session back to back. A session boundary is not a stopping point. Stop early only for
   something on the wait list in point 2 that blocks *all* further progress.
8. **Finish with `REVIEW.md`** in the project folder, short enough to read in two minutes:
   - **Built:** what exists now and how to see it (commands, paths, links);
   - **Decisions:** the ones that matter, with low-confidence ones flagged, and a pointer to the
     full log;
   - **Outbox:** the held sends and deploys from `OUTBOX.md`;
   - **Waiting on you:** the queue, as one batched list.

## Files (in the project folder)

These are the run's record. None of them switches anything.

| File | What goes in it |
|---|---|
| `.autopilot/decisions.md` | one line per decision: what, the choice, why, confidence |
| `.autopilot/queue.md` | the steps waiting for the user (point 2), each with what is needed |
| `OUTBOX.md` | held outbound actions, ready to send |
| `REVIEW.md` | the closing summary (point 8) |

## What doesn't change

Everything else in Palmface's `CLAUDE.md` still holds: honesty over agreement, checking before
claiming done, the portability tiers, keeping state in files. Autopilot moves the questions to
the ends of the run. It doesn't lower the bar.

---
name: palmface-stress-test
description: Challenge a plan with a fresh-eyes subagent that runs a six-lens validation battery (interchangeability, assumptions, scope creep, edge cases, architecture fit, feasibility) and writes findings to docs/plans/<slug>/stress-test.md with a PASS / PASS WITH RISKS / FAIL verdict. Use when stakes are high and before committing to implementation. Triggers on "/palmface-stress-test", "stress test this plan", "challenge this plan", "review the plan", "is this plan solid?".
argument-hint: "[path to plan.md | plan slug]"
---

# Stress test

You dispatch one subagent that has never seen the conversation and make it attack a plan from six angles. Fresh eyes are the point: do not summarise the plan for it or tell it what you think.

Announce: "Running a stress test on this plan with fresh eyes."

## 1. Find the plan

In priority order:
1. A file the user referenced (`docs/plans/<slug>/plan.md` or any plan file).
2. A slug: look for `docs/plans/<slug>/plan.md`.
3. No argument: list `docs/plans/*/plan.md` by modification time and use `AskUserQuestion` to confirm the newest (recommended first).

If there is no plan, say so and suggest `/palmface-deep-plan`. Read the plan, plus `build-spec.md` and `brief.md` in the same folder if they exist (the brief is the "stated goal" for the scope lens).

Read-only rule: this skill never edits the plan. It only writes `stress-test.md`.

## 2. Dispatch the reviewer

Launch ONE general-purpose subagent (Agent tool). Give it only: the full plan text (and brief/build-spec if present), the project root path, and the brief below. No conversation history.

Brief to paste, filling the bracketed parts:

> You are a senior staff engineer reviewing a plan before a team commits time to it. You have never seen it before and have no stake in it. Your job is to find problems. Read the plan, then read the code, configs and docs it references (read-only: Read, Grep, Glob, and non-mutating shell commands). Verify claims against the real project; do not list theoretical worries when you can check. Be specific: cite paths and lines, state what would actually happen.
>
> Run every lens:
> 1. **Interchangeability.** Could two independent sessions given only this plan produce the same result? Look for vague paths ("the auth module"), vague rules ("add validation"), unresolved options, undefined terms.
> 2. **Assumptions.** What does the plan assume about existing code, dependencies and versions, environment, data shape, permissions? Check each against the project.
> 3. **Scope creep.** What is in the plan that the goal did not ask for? What does the goal imply that the plan omits? Is the "does not include" list honest? Does it touch anything it should not?
> 4. **Edge cases.** Empty and huge input, concurrency, timeouts and network errors, expired auth, malformed data, partial failure (what state is left behind?), missing error handling in snippets.
> 5. **Architecture fit.** Naming, file layout, existing patterns, technology already in use versus new, test conventions, the project's own rules in its CLAUDE.md.
> 6. **Feasibility.** Do the files exist? Are dependencies available? Is task order correct? Is each task small enough to finish in one sitting? Are acceptance checks runnable? Are setup steps missing (migrations, env vars, config)?
>
> Rate each finding BLOCKER (would cause failure, data loss or architectural damage), RISK (plan may work but this is a known weakness) or NOTE (awareness only). Also list the plan's genuine strengths (decisions that are sound and should survive revision). Write everything to `docs/plans/<slug>/stress-test.md` in the format below.

Output format the subagent must use:

```markdown
# Stress test: <plan name>
Date: YYYY-MM-DD
Plan reviewed: docs/plans/<slug>/plan.md

## BLOCKERS (must fix before implementation)
- finding, with file/line references. "None found." if empty

## RISKS (should address)
- finding and reasoning

## NOTES
- observation

## STRENGTHS (protect these in any revision)
- decision and why it is sound

## Summary
Blockers: N | Risks: N | Notes: N

## Verdict
PASS | PASS WITH RISKS | FAIL
```

## 3. Report

Read `stress-test.md` and check it is complete: all six lenses covered, findings cite real paths, a verdict is present. If not, re-dispatch once with the gap named.

Summarise in chat, short:
- **FAIL:** "Found N blockers" plus the blockers. Recommend a targeted revision through `/palmface-deep-plan` (revise mode), and name the strengths to protect so the revision stays narrow.
- **PASS WITH RISKS:** list the risks and use `AskUserQuestion`: address now (recommended) or accept and proceed.
- **PASS:** say the plan is ready and point at `/palmface-build`.

If you are on autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: decide instead of asking, log the decision to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## Rules

- One challenge per planning cycle means exactly one of `/palmface-stress-test`, `/palmface-heartwood`, `/palmface-premortem` or `/palmface-canopy`. They overlap. Pick one, fix what it finds, then build. Running several on the same plan erodes it.
- Never re-litigate decisions an earlier evaluator already marked as strengths.
- For a multi-session effort (`/palmface-metaplan`), stress-test one session's plan at a time, before planning the next.

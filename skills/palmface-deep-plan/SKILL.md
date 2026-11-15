---
name: palmface-deep-plan
description: Full planning pipeline for one feature, refactor or milestone. Research the codebase with subagents, draft plan.md (architecture, files, milestones) and build-spec.md (tasks with acceptance criteria that test behaviour, not existence), iterate on the user's annotations until approved, validate the artifacts against each other, then hand off to building. Supports --research-first (loop on research before drafting) and --revise (reopen an existing plan). Use when work needs strategic planning before any code is written. Triggers on "deep-plan", "plan this feature", "plan before we build", "draft a plan", "revise the plan".
argument-hint: "\"description\" | @brief.md | --research-first | --revise @docs/plans/<slug>/"
---

# palmface-deep-plan

Research, draft, iterate, validate, hand off. You write plans; you do not write the feature. Nothing gets implemented until the user says "approved", and even then building is a separate step.

Announce: "Using palmface-deep-plan to research the codebase and build a plan."

Autopilot: on autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`. Skip the plan-mode dialog and every question below. Decide, log each decision to `.autopilot/decisions.md`, and queue only what must truly wait in `.autopilot/queue.md`. Do not stop after validation: approve the plan yourself against the user's stated goals (autopilot.md point 5), log that approval to `.autopilot/decisions.md`, append the implementation todo, and continue to the hand-off (section 6). The research check (section 2) and the `--research-first` dig-deeper question (section 2b) are decided the same way: choose, then log. When not on autopilot and plan mode is available, you may run phases 1-3 in plan mode and call ExitPlanMode for approval before writing the files under `docs/plans/`.

Artifacts live in `docs/plans/<slug>/` (kebab-case slug): `research.md`, `plan.md`, `build-spec.md`. Templates are in `~/.claude/skills/palmface-deep-plan/templates.md`; read them before drafting.

## 1. Entry

Check `$ARGUMENTS`, first match wins:
1. `--revise @path/`: revision mode. Go to section 7.
2. A file (`@docs/plans/<slug>/brief.md`, a design doc): use it as the spec. Interview only for gaps.
3. Text: use as starting context and interview to fill the gaps.
4. Nothing: look in `docs/plans/` for a recent brief or design; offer it. Otherwise interview from scratch.
5. `--research-first` may accompany any of these: it turns on the research loop (section 2b).

Interview with `AskUserQuestion`: one topic per round, multiple choice where possible, recommended option first. Dig into the hard parts: architecture constraints, edge cases, what "done" looks like. If the work is clearly bigger than one session, say so and suggest `/palmface-metaplan` first. If it is trivial (one file, a few lines), say so and just do it.

## 2. Research

Dispatch 1-3 general-purpose subagents (Agent tool), each with a written brief: the goal in one paragraph, the specific area to cover, "read deeply, trace every dependency, quote file paths and line ranges", and instructions to write findings to a file (`docs/plans/<slug>/research-<area>.md`), so each result survives on disk and you read only what you need. Suggested areas, as needed: architecture and entry points; the data, dependencies and interfaces the work touches; conventions, test setup and gotchas.

Consolidate into `research.md`: current state, existing patterns the plan must follow, constraints, open questions, and 2-3 candidate approaches. Delete the per-area files afterwards. Summarize in chat and ask: "Research done. Anything missing or wrong before I draft?" Wait for the answer. On autopilot, do not ask: note any gap you see, log it, and draft.

### 2b. Research loop (only with `--research-first`)

After each round, summarize findings, gaps and open questions, then ask whether to dig deeper into a named area or draft (on autopilot: decide, then log; dig deeper only when a gap would make the plan guesswork). A "dig deeper into X" becomes a NEW focused directive (what question does X answer that was not covered?) given to a subagent together with the current `research.md`; append the result under `## Research round N: <topic>`. Never overwrite earlier rounds. After 3 rounds, note that drafting now avoids analysis paralysis; the user may continue regardless.

## 3. Draft

Write both files, then summarize them in chat.

**`plan.md`:** one-sentence goal; the approach (2-3 options including one unconventional wildcard, one recommended with reasons); every file to create or modify by exact path; real code snippets for the tricky parts, not pseudocode; ordering and dependencies; a verification step per milestone; milestones sized to roughly 30 minutes of work; an explicit "Does NOT include" list. Follow conventions found in research rather than inventing new ones.

**`build-spec.md`:** the plan decomposed into tasks. Each task is a checkbox line `- [ ] T<n>: <title>` followed by its files (exact paths), what to do, `Depends on:` and how to run it (inline, one subagent, or parallel subagents). Group independent tasks and mark the group parallelizable. Flag tasks that modify critical existing code as needing a careful review.

**Acceptance criteria are the core of build-spec.md, and they live under their task.** Each criterion is an indented checkbox line `  - [ ] T<n>.AC<k>: <the behaviour that must be true>`, with three indented sub-bullets:
- **Setup:** what must be running or configured first, as literal runnable commands with wait conditions, or `none`.
- **Verify:** something you DO, not something you READ: an action (a command, request or user action sequence) plus the exact expected observable result. "File exists" is not a verification; "running X prints Y" is.
- **Depth:** the edge cases and quality bar a shallow implementation would skip (empty input, errors, limits, concurrency, accessibility).

Every feature and behaviour gets a criterion under the task that delivers it. A behaviour that spans tasks gets its criterion under the task that completes it, or under a final integration task.

Self-ask on every criterion: if someone built this with maximum laziness yet technically satisfied it, would the user be happy? If not, add depth. Add a short list of what cannot be tested automatically (visual judgement, copy, feel); it must exist and be honest.

## 4. Annotation loop

Say: "Plan drafted in `docs/plans/<slug>/` (plan.md, build-spec.md). Edit the files directly or give feedback here. Say 'approved' when satisfied. I will not implement anything until then."

Each iteration:
1. Re-read both files from disk (the user may have edited them).
2. Address every annotation or note, in order; skip none. If a note is ambiguous, ask.
3. Keep the files in sync: a milestone change updates its tasks; a task change updates its criteria; a scope change gets checked in both.
4. Report what changed, briefly, per file. Do not reprint the plan.
5. End with the guard: "Updated. I have not implemented anything. Anything else, or approved?"

No iteration limit. If it passes about six rounds, suggest stepping back to clarify requirements (`/palmface-intake`, or `superpowers:brainstorming` if the superpowers plugin is installed). On "approved", append an `## Implementation todo` to plan.md listing phases and tasks as checkboxes.

## 5. Validate

Before handoff, check and fix (or flag) every item:
- **plan.md:** exact paths everywhere; verification per milestone; scope bounded; follows existing conventions; milestones about 30 minutes.
- **build-spec.md:** every task is `- [ ] T<n>: <title>` with at least one `T<n>.AC<k>` criterion under it; every criterion has Setup, Verify and Depth; every Verify is an action with an expected result; Depth is specific; dependencies explicit; independent tasks grouped; the "cannot be tested automatically" list exists.
- **Across both:** every milestone has tasks; every task has criteria (no task without one); no task touches a file the plan does not mention.

Report as a short checklist with failures called out. Offer to fix before handoff.

## 6. Handoff

```
Plan approved. Artifacts in docs/plans/<slug>/:
  plan.md        architecture and milestones
  build-spec.md  tasks and acceptance criteria
Suggest /clear before building: a fresh context plus the files works best.
Next:
  1. Challenge the plan first, pick ONE of: /palmface-stress-test, /palmface-heartwood
     (--malicious on build-spec.md hunts ambiguous criteria), /palmface-premortem,
     /palmface-canopy
  2. /palmface-build @docs/plans/<slug>/   execute with spec checks
  3. Done for now: plan saved
```

One challenge per planning cycle means exactly one of those four. On autopilot, pick one yourself and log it.

If `/palmface-build` is not installed, build task by task from `build-spec.md`; `superpowers:executing-plans` or `superpowers:subagent-driven-development` fit if the superpowers plugin is installed.

## 7. Revision (`--revise @path/`)

Skip sections 1-6. Require `plan.md` and `build-spec.md` in the path; if one is missing, stop and say which. Read both in full. Show a short dashboard (goal, milestone count, task and criterion counts, criteria ticked). Enter the annotation loop (section 4) with the same sync rules and guard, and list what changed after each round (sections edited, criteria added or removed, tasks added, split or dropped). After each round append to plan.md, never overwriting earlier entries:

```markdown
## Revision history
### Revision N: YYYY-MM-DD
Trigger: <what prompted it>
Changes: <specific, concrete bullets>
Reason: <why>
```

On "approved", rerun validation (section 5) and the handoff (section 6), noting at the top that this is Revision N.

## Does not

Write the feature code, skip the research, or let plan.md and build-spec.md drift apart.

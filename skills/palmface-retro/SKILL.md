---
name: palmface-retro
description: Structured project retrospective. Pulls real data first (git history, plan artifacts in docs/plans/<slug>/, task completion from build-spec.md, a prove report if present), shows it as a dashboard, then interviews the user one category at a time with AskUserQuestion and writes retro.md. Use after finishing a project or build, or when the user says "/palmface-retro", "retro", "retrospective", "postmortem", "what did we learn".
argument-hint: "[slug]"
---

# palmface-retro: pull the data, then ask the user to annotate it

The user should annotate facts, not recite a project from memory. Gather first, show it, then interview.

Announce: "Running palmface-retro. I will pull the data first, then ask you to annotate it."

## Autopilot

On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`) there is no interview. Follow `~/.claude/palmface/references/autopilot.md`: write the dashboard and your own draft observations to `docs/plans/<slug>/retro.md` marked "draft, not yet annotated by the user", log the decision to `.autopilot/decisions.md`, and queue "annotate the retro" in `.autopilot/queue.md`.

## Phase 1: locate and gather

1. **Slug.** Use the argument, else the most recently changed folder in `docs/plans/`. If there is none, ask with `AskUserQuestion` which project or folder the retro is for (on autopilot: log that there is nothing to review and stop).
2. **Plan artifacts** in `docs/plans/<slug>/` (read only, never modify): `brief.md`, `plan.md`, `build-spec.md`, `prove.md`, `qc.md`, `state.json` (phase timestamps, if `/palmface-status` wrote one), `handoff.md` or `vN-handoff.md`.
3. **Git** (if the folder is a repository; otherwise note "git data unavailable"):
   - commit count and date range (`git log --reverse --format=%ad --date=short | head -1`, and the latest), recent subjects (`git log --format='%h %ad %s' --date=short | head -50`)
   - size of change from the first commit: `git diff --shortstat <first>..HEAD`
   - restrict to the work's commits when you can tell them apart (by date range or path).
4. **Task completion** from `build-spec.md`: count the criterion boxes (lines matching `T<n>.AC<k>:`): total, done `- [x]`, open `- [ ]`. Forecast accuracy = done / total criteria. Report task boxes ticked as a side note. If there is no build-spec, say so and do not invent counts.
5. **Phase durations** from `state.json` if it exists; otherwise leave them for the interview.
6. **Prove and QC reports**, if present: use what works, what is broken, what is rough and what could not be tested as interview starters instead of cold questions. They supplement the user's own view; they do not replace it.

## Phase 2: dashboard

Show the data before asking anything: timeline (first and last commit, duration, commits, lines), phase durations, task completion and forecast accuracy, and the prove and qc verdicts. Where data was missing, print one line saying so rather than a blank table. Then ask the user to confirm it looks right and apply corrections.

## Phase 3: interview

One category at a time, using `AskUserQuestion` (max 4 questions per round, recommended option first where choices exist, free text via the "other" route for the substance). Wait for each answer.

- **3a Went well:** 2 to 5 specific items, a named thing, decision or tool, not "it was smooth". Offer candidates from the data (tasks finished early, a prove criterion that passed first time) as options.
- **3b Did not go well:** for each item, what happened, the root cause and the cost in time or quality. Offer candidates from the data (open tasks, failed criteria, long gaps between commits).
- **3c Surprises:** good or bad, separate from 3b.
- **3d Learnings in three buckets:** process (how the work was run), technical (code, architecture, tools), domain (the subject, the people or system the work serves). At least one per bucket, asked as one block.
- **3e Patterns to reuse and to avoid:** concrete actions ("run a spec review before building"), not principles ("communicate more").
- **3f Time and cost:** show the measured durations and ask whether they match; with no data, ask for ballpark hours per phase.

If an answer is vague, probe once with a concrete example from the data; if it is still vague, record it as given and move on.

## Phase 4: memory candidates

Pick 2 to 5 learnings with value beyond this project. List them and ask which to keep. The approved ones go in the "Memory candidates" section of `docs/plans/<slug>/retro.md`, the only default home for lessons. A lessons file shared across projects is the user's call: offer it once (the user names the path; never create one by default, and never write anywhere under `~/.claude`). Guidance on what is worth keeping long term lives in `~/.claude/palmface/references/memory.md`.

## Phase 5: write `retro.md`

Only after the interview is complete. Write `docs/plans/<slug>/retro.md` (if the folder does not exist, ask where to save it):

```
# Retrospective: <slug>
Date, build type, plan folder

## Data
timeline, phase durations, task completion and forecast accuracy, prove / qc verdicts
## What went well        (specific; what and why)
## What did not go well  (what | root cause | cost)
## Surprises             (mark positive or negative)
## Learnings             (process / technical / domain)
## Patterns to reuse     (pattern | when | why)
## Patterns to avoid     (anti-pattern | problem | alternative)
## Memory candidates     (learning | bucket | kept)
```

Finish with a short summary: where it was saved, how many items per section, how many memory candidates were kept.

## Rules

- Never ask the user to recall what a command can tell you.
- Never invent counts, dates or durations; say "not recorded".
- Never merge the three learning buckets.
- Never write `retro.md` before the interview is done (except the marked autopilot draft).
- Never modify build artifacts; the retro only writes `retro.md` (plus a cross-project lessons file only if the user names one).

Position in the flow: `/palmface-build` then `/palmface-qc` then `/palmface-prove`, then `/palmface-retro`. Its learnings feed the next `/palmface-deep-plan`.

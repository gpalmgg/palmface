---
name: palmface-status
description: Detect where a piece of planned work stands from the artifacts in docs/plans/<slug>/ (fragments, brief, research, plan, build-spec checkboxes, stress-test, qc, retro and so on), report the phase, completion and blockers, and name the next step. Optionally keeps a checkpoint in docs/plans/<slug>/state.json. Use when the user asks "where am I", "what's the status", "what's next on this", "what phase is this", when resuming a project after a break, or says "checkpoint this".
argument-hint: "[slug] [--scan | --checkpoint | --reset]"
---

# palmface-status

Reads the plan folder, works out the phase from what exists and what is in it, and says what comes
next. By default it only reads. It is the **only** skill that writes `state.json`.

## Flags

| Flag | Effect |
|---|---|
| none | Scan, read `state.json` if present, write nothing |
| `--scan` | Same as none, stated explicitly |
| `--checkpoint` | Scan, then write `docs/plans/<slug>/state.json` |
| `--reset` | Ask first (`AskUserQuestion`), then delete `state.json` and rebuild it from a scan. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`; see `~/.claude/palmface/references/autopilot.md`) the explicit flag is the consent: log the old blockers to `.autopilot/decisions.md`, then reset |

## 1. Find the work

Look for `docs/plans/` in the working directory, then up to three parent folders. If the user gave
a slug, use that folder. Otherwise list the subfolders: one folder means that one; several means
pick the most recently modified and name the others in one line; a tie or doubt means ask with
`AskUserQuestion`. On autopilot, do not ask: take the most recently modified folder, name the others in one line, and log the choice to `.autopilot/decisions.md`. No `docs/plans/` at all: report "no plan folder" and look at the top level of
the project for the same file names.

## 2. Read the artifacts, not just their names

A file that exists but is empty or only headers does not count. For each, check its content:

| Phase | Artifact | Counts as done when |
|---|---|---|
| 0 Ideas | `fragments.md` | it has body text |
| 1 Brief | `brief.md` | more than about 5 lines of body (goal, scope, success criteria) |
| 2 Research and design | `research.md`, a design or brainstorm doc | sections with body text |
| 3 Plan | `plan.md` and `build-spec.md` | plan has numbered phases or tasks; build-spec has `- [ ] T<n>:` task lines with `T<n>.AC<k>` criterion boxes |
| 3+ Multi-session | `metaplan.md`, `vN-session-prompt.md`, `vN-handoff.md` | prompts exist; a `vN-handoff.md` on disk means session N finished, so the handoff count is the number of sessions done |
| 4 Challenge | `stress-test.md`, `heartwood-<mode>.md`, `premortem.md`, `canopy.md` | a findings or verdict section |
| 5 Build | source changes; `build-spec.md` ticks | count the criterion boxes (lines matching `T<n>.AC<k>:`), `- [x]` against all; any unchecked criterion means not done |
| 6 Verify | `qc.md`, `prove.md` | a verdict or evidence section |
| 7 Retro | `retro.md` | lessons and decisions written |

Compute: criteria ticked / total criteria in `build-spec.md` and the percentage (count the lines matching `^ *- \[[ x]\] T[0-9]+\.AC[0-9]+:` for the total, and those with `\[x\]` for the ticked count; report task boxes ticked as a side note), and the current phase (the highest phase
whose artifact is complete; an incomplete artifact makes that phase "in progress"). Check git as
well: `git log -1 --format=%cr` for last activity, and `git status --short | wc -l` for loose
changes, when the folder is a repo.

## 3. Read the checkpoint, if any

If `state.json` exists, parse it with `jq` (`command -v jq`; otherwise read it by eye). Corrupt
JSON: say so and treat it as missing. Report it if the last checkpoint is more than 7 days old.
The scan wins over the checkpoint when they disagree; say what changed.

## 4. Report

A compact dashboard, then one line of next action:

```
Plan: docs/plans/<slug>/   last activity: 3 days ago
  0 ideas      done     fragments.md
  1 brief      done     brief.md
  2 research   done     research.md
  3 plan       active   plan ok, build-spec 12/20 criteria (60%)
  4 challenge  todo
  5 build      todo
  6 verify     todo
  7 retro      todo
blockers: <from state.json or the scan, else "none seen">
next: finish the remaining build-spec tasks (8 open)
```

Next action by phase (name a skill only if it is installed; otherwise say what to do in words):

| State | Suggest |
|---|---|
| nothing | `/palmface-seedbed` for loose ideas, or `/palmface-intake` for a brief |
| brief, no plan | brainstorm (`superpowers:brainstorming` if installed), then `/palmface-deep-plan` |
| plan, no build-spec | finish planning: the build-spec with acceptance criteria is missing |
| plan and spec, not challenged | `/palmface-stress-test` before building |
| criteria under 100% | continue the build; `/palmface-build` |
| criteria at 100% | `/palmface-qc`, then `/palmface-prove` |
| verified | `/palmface-retro` |
| retro done | finished |

Never call a phase complete from file existence alone; never mark build-spec done while any criterion box is
unchecked; never hide a stale-checkpoint warning.

## 5. Writing `state.json` (only with `--checkpoint` or `--reset`)

Write this shape, and no other file:

```json
{
  "slug": "<slug>",
  "phase": "plan",
  "phases_completed": [{"phase": "brief", "at": "2026-01-31T10:00:00Z"}],
  "build_spec": {"criteria_checked": 12, "criteria_total": 20},
  "blockers": [],
  "last_action": "one line: what was just done",
  "updated": "2026-01-31T10:00:00Z"
}
```

Keep existing `blockers` and earlier `phases_completed` entries unless the user clears them. Use
real UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`). `--scan` and the default never write. Other
skills do not touch this file; they may suggest `/palmface-status --checkpoint` when they finish a
stage.

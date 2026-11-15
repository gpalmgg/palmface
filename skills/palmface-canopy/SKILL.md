---
name: palmface-canopy
description: Temporal reframing of a plan. Three independent subagents write a failure post-mortem, a near-miss success story and a decision review, then a divergence analyst maps where they agree and disagree to separate real risks, hidden dependencies, likely confabulation and plan strengths. Writes docs/plans/<slug>/canopy.md. Use on a finished plan before building when you want to know what is brittle and what is solid. Triggers on "/palmface-canopy", "run canopy", "what survives over time", "failure and success timelines".
argument-hint: "[plan path or slug] [--stakes side-project|client|production|existential]"
---

# Canopy

Looking at a plan from six months ahead shows which parts are brittle and which are sound. Three narrators work in isolation; where they converge you can trust the signal.

Announce: "Running canopy on this plan."

## Input

1. A file path: read it. A slug: read `docs/plans/<slug>/plan.md` (and `brief.md`/`build-spec.md` if present). Inline text: use it.
2. Under one paragraph of input: ask for more detail with `AskUserQuestion` and do not run. On autopilot (see the last paragraph of Output), do not ask: log the gap to `.autopilot/queue.md` and stop.
3. Over roughly 5,000 tokens: first condense to key decisions plus architecture.

Stakes (`--stakes`, default `client`, never guessed from the plan) pick the failure calibration:

| Stakes | Calibration line for the Failure Narrator |
|---|---|
| side-project | You abandoned it after a month. No consequences beyond wasted time. |
| client | The client did not renew. Polite but clear: the deliverable did not meet expectations. |
| production | A multi-hour outage. Postmortem required. No data loss but trust damaged. |
| existential | The initiative was defunded and the organisation pivoted away from this direction entirely. |

## Run

Read `~/.claude/skills/palmface-canopy/agents.md` for the four briefs.

1. **Parallel:** send three Agent tool calls (general-purpose subagents, read-only) in ONE message: Failure Narrator, Success Narrator, Decision Journalist. Inject the plan text as `{INPUT}` and, for the Failure Narrator only, the stakes line as `{STAKES_CALIBRATION}`. They must not see each other's output. Each aims for about 2,000 tokens.
2. **Then one:** after all three return, dispatch the Divergence Analyst with the three outputs as `{FAILURE_OUTPUT}`, `{SUCCESS_OUTPUT}`, `{JOURNALIST_OUTPUT}`.

Validate the analyst's map: at least 3 factors; each match quotes evidence from the narratives; factor names are specific, not "risk 1"; at least 2 plan strengths identified; every narrator cited named parts of the plan. If something is missing, say what and re-run the failing agent once. If one narrator fails, run a two-way divergence on the rest and say which failed; if the analyst fails, show the narratives side by side.

## Output

Write `docs/plans/<slug>/canopy.md`:

```markdown
# Canopy: <plan>
Date / Input / Stakes

## Divergence map
(table from the analyst, with correspondence evidence)

## PLAN STRENGTHS (all timelines agree these work; protect them)
## HIGH-CONFIDENCE RISKS (all timelines agree)
risk, failure version, success mitigation, journalist assessment, recommended action
## CRITICAL UNCERTAINTIES (timelines disagree)
## HIDDEN DEPENDENCIES (only the success story sees them)
## LIKELY CONFABULATION (only the failure story sees them: treat as unreal without outside evidence)
## Decision quality
strongest decisions first, then weakest
## Recommended actions
prioritised; include "protect X" for strengths, not only "fix Y" for risks
## Recommended next step
```

Next step by outcome: few manageable risks, point at `/palmface-build`; minor risks on a strong base, name the targeted fixes and say do not revise the strengths; critical uncertainties, resolve that specific one first (a scoping question, not a quality problem); blockers, return to `/palmface-deep-plan` in revise mode for a named section and list what to protect.

Summarise the map and top risks in chat. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: use `client` stakes if none given, log it to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## Rules

- Never modify the plan. Not for code: use `/palmface-heartwood --adversarial`. Not a feasibility check: that is `/palmface-stress-test`.
- One challenge per planning cycle means exactly one of `/palmface-stress-test`, `/palmface-heartwood`, `/palmface-premortem` or `/palmface-canopy`. If another already ran on this plan, do not stack canopy.
- Strengths are load-bearing output as much as risks. Every "revise" advice must say what to protect so a revision stays narrow.
- A finding only the failure narrator sees defaults to likely confabulation: that narrator was told to assume failure. Escalate it only with a verifiable external dependency behind it.

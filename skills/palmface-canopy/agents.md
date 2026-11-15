# Canopy briefs

Paste into general-purpose subagents (read-only). Replace the `{PLACEHOLDERS}`.

## 1. Failure Narrator
```
It is six months from now. The project below failed. {STAKES_CALIBRATION} Treat that line as the size of the failure: do not soften it or inflate it.
Write the post-mortem, specific and realistic.
Grounding rule: every failure mode must trace to (a) an external dependency outside the team's control, (b) a resource or timeline constraint, or (c) a verifiable assumption that could be wrong. "The team made a bad call" is hindsight bias, not a failure mode.
Cover: what went wrong first (the initial crack), root cause versus proximate cause, warning signs that were ignored, assumptions that proved wrong, the single decision that set the trajectory.
Prefer traceable, concrete failures. Avoid vague ones ("communication was poor"), melodramatic ones that would not really happen, and blaming a decision that was well reasoned given what was known.
You MUST reference specific parts of the plan by name or section.
PROJECT/PLAN: {INPUT}
```

## 2. Success Narrator
```
It is six months from now. The project below succeeded, but it was close: three things nearly derailed it.
For EACH near-miss: what the risk was; how it was caught; what would have happened if it had not been; at what point in the timeline it was caught.
The value is in the near-misses, not the celebration; a success story with no near-misses is fiction. Avoid generic narratives ("the team worked hard"). Prefer near-misses that trace to a specific part of the plan and that mirror a realistic failure.
You MUST reference specific parts of the plan by name or section.
PROJECT/PLAN: {INPUT}
```

## 3. Decision Journalist
```
You write for a decision review board that reads this in six months. You make bold, clear calls that age well; hedging damaged your reputation before.
For each major decision point in the plan: what was decided; the alternatives; what information was and was NOT available; decision quality (STRONG / ADEQUATE / WEAK / INSUFFICIENT INFO); will it age well, and why.
Commit. Keep decision quality separate from outcome quality. Do not miss a decision other reviewers would flag.
You MUST reference specific parts of the plan by name or section.
PROJECT/PLAN: {INPUT}
```

## 4. Divergence Analyst
```
Below are three independent narratives about one project, written without shared context. Your only job is to build the divergence map.
For every risk, factor or decision mentioned by ANY narrative, decide whether the others address it, even in different words ("auth migration broke sessions" and "we caught the session handling issue early" are the same risk).
For every match you MUST give correspondence evidence: quote the text from each narrative you connect. Report correct cross-narrative matches and unique single-narrative factors; do not miss matches and do not force false ones.

Output a table: # | Factor | Failure | Success | Journalist | Signal | Correspondence evidence.
Signals:
- ALL AGREE (risk): HIGH-CONFIDENCE RISK, act on it.
- ALL AGREE (works): PLAN STRENGTH, protect it in any revision.
- FAILURE + JOURNALIST only: REAL RISK that optimism may be hiding.
- ONLY FAILURE: LIKELY CONFABULATION, since that narrator was told to assume failure; escalate only if tied to a verifiable external dependency.
- ONLY SUCCESS: HIDDEN DEPENDENCY, success silently relies on it.
- FAILURE and SUCCESS DISAGREE: CRITICAL UNCERTAINTY, the outcome hinges on it.
- SUCCESS + JOURNALIST: PLAN STRENGTH, the decision is sound and execution is the variable.
You MUST identify at least 2 plan strengths: if all three treat something as working or well decided, it is a strength. Plans have strong parts; find them.
After the table, write a short section per signal category with its factors and a one- or two-sentence reading.

FAILURE NARRATIVE: {FAILURE_OUTPUT}
SUCCESS NARRATIVE: {SUCCESS_OUTPUT}
DECISION REVIEW: {JOURNALIST_OUTPUT}
```

---
name: palmface-heartwood
description: Three-agent evaluation pipeline with adversarial rubrics (an expander, a challenger, a judge, run in sequence). Modes - adversarial (bug-finding in code or a diff), steelman (evaluate a proposal or essay for and against, ending in PROCEED / REVISE / REJECT), malicious (hunt exploitable ambiguity in a spec and return a fixed spec). Writes docs/plans/<slug>/heartwood-<mode>.md. Use for thorough code review, proposal evaluation or spec hardening. Triggers on "/palmface-heartwood", "adversarial review", "steelman this", "find the loopholes in this spec".
argument-hint: "[--adversarial|--steelman|--malicious] [--exhaustive] [file | --staged | --diff | --last-commit | quoted text]"
---

# Heartwood

Three general-purpose subagents run in sequence. Each one's output feeds the next, and each is given a rubric that pushes it hard in one direction so the judge sees both sides.

Announce: "Running heartwood in <mode> mode."

## Mode

Take the flag from the arguments. With none, infer: code, a diff or a PR means `--adversarial`; prose, a proposal or an essay means `--steelman`; words like spec, contract, interface or API mean `--malicious`. If still unclear, ask with `AskUserQuestion` (inferred mode first, labelled recommended).

## Input

- **adversarial:** file paths; or `--staged` (`git diff --staged`), `--diff` (`git diff`), `--last-commit` (`git show HEAD`, which also works on a root commit). With no argument try staged, then unstaged, then ask. Empty input: say "nothing to review" and stop. Store as `CODE_UNDER_REVIEW`.
- **steelman / malicious:** a file reference or quoted text. Store as `INPUT`.
- **Context:** read the nearest CLAUDE.md. For adversarial, also skim imports, types and tests next to the code. Store as `PROJECT_CONTEXT`.

Guard rails: input under 10 lines gets one single-pass review, no pipeline. Over 3,000 lines, warn about cost and suggest splitting. A missing file means report it and stop. This skill never modifies its input.

## Pipeline

Read `~/.claude/skills/palmface-heartwood/modes.md` for the three briefs of the chosen mode. Run the phases sequentially with the Agent tool (general-purpose subagents; read-only work: Read, Grep, Glob, non-mutating shell):

1. **Expander** produces `EXPANDER_REPORT`.
2. **Challenger** receives the input and `EXPANDER_REPORT` and produces `CHALLENGER_REPORT`.
3. **Judge** receives the input and both reports and produces the verdict.

Fill the `{PLACEHOLDERS}` in each brief with the real text. Do not paraphrase the rubrics.

`--exhaustive`: prepend one line to the Expander brief only: "You are penalised for every item you fail to enumerate. When in doubt, include it."

Mode pairs: adversarial is Bug-Finder, Adversary, Referee. Steelman is Advocate, Critic, Decision Journalist. Malicious is Ambiguity Finder, Malicious Implementer, Specification Judge.

## Checks before presenting

1. The Judge cites finding IDs from the earlier phases.
2. Every Expander finding got a Challenger response.
3. The Judge delivered a verdict, not a summary.
4. The statistics are present and add up.
5. Malicious mode: both the verdict and a fixed specification are present.

If a check fails, say what is missing and re-run that phase once. If a phase errors: phase 1 failing means stop and suggest a smaller input; phase 2 failing means present the Expander report as raw, unfiltered findings; phase 3 failing means show both reports and summarise yourself.

## Output

Write the full verdict to `docs/plans/<slug>/heartwood-<mode>.md` (`adversarial`, `steelman` or `malicious`; use the plan's slug, or one you derive from the topic) and show the Judge's output in chat, ending with one line:

- adversarial: `X critical, Y medium, Z minor issues from N initial findings (W% false positives).`
- steelman: `Recommendation: PROCEED | REVISE | REJECT at HIGH | MEDIUM | LOW confidence.`
- malicious: `X exploitable ambiguities, Y false alarms. Fixed spec produced.`

On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: pick the mode yourself, log it to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## One challenge per planning cycle

- One challenge per planning cycle means exactly one of `/palmface-stress-test`, `/palmface-heartwood`, `/palmface-premortem` or `/palmface-canopy`.
- If `stress-test.md`, `premortem.md` or `canopy.md` exists for this work, read it first, including any strengths or "protect these" sections. Do not re-attack settled strengths and do not re-flag a risk the plan already revised.
- Pipeline: plan, then ONE of the four, then a targeted fix, then build. If a plan has already been through one, recommend moving on rather than another loop.
- Every "revise" recommendation must say exactly what to change and what to leave alone.

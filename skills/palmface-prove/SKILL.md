---
name: palmface-prove
description: Acceptance testing of a built system through its real interfaces, the way its user would use it, producing hard evidence (commands run, output captured, screenshots) and an honest verdict. Two independent testers, one with fresh eyes and one who also knows how the build went, each write to their own folder. Use after a build is finished and before handoff or release, or when the user says "/palmface-prove", "prove it works", "acceptance test this", "try it as a user would".
argument-hint: "[slug]"
---

# palmface-prove: does it actually work for the person who will use it?

Goal: the user can pick up the built thing and use it immediately, with no errors, no missing dependencies and no "it works if you first do X". `/palmface-prove` finds out whether that is true.

Principles:
- **Interfaces only.** You test through what a user touches (CLI, URL, UI, API, files produced). You do not read source code to decide whether something works. A system that works with ugly code passes; a system with tidy code that fails when run, fails.
- **Function and breakage, not taste.** For anything visual, check that nothing is broken and hand the look to `/palmface-look`. Report `LOOK: awaiting the user` rather than judging style.
- **"It loads" is not "it works".** Use the feature, then check the result.
- **Evidence or it did not happen.** Every PASS cites a command and its output, or a saved screenshot.
- **No persona.** There is no imagined person to simulate. You work from the spec and the user's stated goals only.

## Inputs

Find the plan folder `docs/plans/<slug>/` (argument, or the most recently changed one). Read:
- `brief.md`: the user's goals. This is the lens for every judgment.
- `build-spec.md`: tasks (`- [ ] T<n>: ...`) with their acceptance criteria as indented `- [ ]` / `- [x]` `T<n>.AC<k>:` lines, each with Setup, Verify and Depth. This is what to test; refer to criteria by their `T<n>.AC<k>` IDs.
- `plan.md`, if present, for how the system is meant to be started and used.

No folder? Use the user's original request as the brief and derive acceptance criteria from it; say so in the report. Write the report to `docs/plans/<slug>/prove.md` (create the folder if needed) and keep captured output in separate folders per tester: `docs/plans/<slug>/prove/fresh/` (tester A) and `docs/plans/<slug>/prove/informed/` (tester B). `prove.md` stays the combined verdict.

## Two testers

Dispatch two general-purpose agents (Agent tool), each with a written brief stating the goal, the inputs, the 7 steps below, its own output folder, and the report format. Each tester writes only inside its own folder, and its report to `<folder>/report.md`. If the system needs an exclusive resource (a port, a database, one browser profile), run the testers one after the other (A, then B) instead of in parallel; otherwise dispatch both in a single turn.

- **Tester A, fresh eyes.** Gets only the brief, the acceptance criteria, how to start the system, and the built system on disk. Mindset: "I have never seen this. I am opening it for the first time." It gets no build logs and no earlier verdicts.
- **Tester B, build-informed.** Gets everything A gets, plus the build-spec checkbox state, any build notes or handoff files, and `git log` for the work. Mindset: "I know what was tricky. I will lean on those areas."

Then you synthesize: read both reports, tag findings `[Fresh Eyes]` and `[Build-Informed]`, and make a divergence map wherever they disagree on a criterion (use the harsher result). **The final verdict is the worse of the two verdicts.** Severity, lowest to highest: WORKS, WORKS WITH ISSUES, BROKEN, WON'T START.

## The 7 steps (each tester does all of them)

1. **Read the brief.** Hold the user's intent as the north star. The criteria decompose it; they do not replace it.
2. **Set up the environment exactly as a newcomer would.** Install, configure, seed, start. Capture stdout and stderr, wait up to 30 seconds for a ready signal, and track background processes so you can stop them at the end, even after failures. If setup fails, that is the most important finding: a system that cannot start cannot be used. Diagnose briefly and test whatever still can be tested.
3. **Use it freely first.** Before touching the criteria, spend real time doing what the brief's user would do first: the main workflow, the main screen, the core command. Write down what you tried and noticed. An empty or one-line section here is a failed run.
   - Web: open each page (a browser-automation tool if you have one, otherwise `open <url>` plus fetching with `curl`), check the console for errors, read the page content, interact with the primary control, verify the outcome. Any console error fails that page. Per page: no console errors, data actually rendered, primary interaction works, you can get there and leave.
   - CLI: `--help`, the golden path, a bad input, a missing argument.
   - Library or API: call it the way its documentation says; try one wrong call.
4. **Capture evidence.** Save command output, response bodies and screenshots under your own folder (`prove/fresh/` or `prove/informed/`). A file that only contains a path is not evidence.
5. **Run the criteria.** For each acceptance criterion (`T<n>.AC<k>`) run its Setup and Verify (or write them) and record pass, fail or could-not-test, with the output. A criterion ticked in the build-spec that you cannot reproduce is a finding, not a pass.
6. **Edge cases.** Empty input, very long input, repeated runs (idempotence), wrong working directory, missing optional dependency, a restart in the middle of use, a second run on a clean machine state. Pick the ones that fit this system.
7. **Report honestly.** Say what you could not test and why. Never claim "all tests pass" beyond what you ran. Do not touch the code to make a test pass.

Never run steps with side effects on real accounts or data (sending messages, charging, deleting, deploying). Use test data, a throwaway directory, or mark the step "could not test: side effects".

## Report (`prove.md`)

```
# Prove report: <slug>

Verdict: WORKS | WORKS WITH ISSUES | BROKEN | WON'T START
Testers: A <verdict>, B <verdict>   Divergences: <n>

## First impression
<what a newcomer meets in the first two minutes>

## Walkthrough
### <feature> (T1.AC1, T1.AC2)
- Did: ...   Saw: ...   Evidence: prove/fresh/<file>   Result: pass | fail

## Criteria table
| ID | Criterion | Result | Evidence | Found by |

## Edge cases
## Divergence map
## What could not be tested, and why
## Fixes needed (ordered, smallest first)
LOOK: awaiting the user (<screens to look at>)   <- only for visual work
```

## After the verdict

- **WORKS:** hand off (`/palmface-retro` is the natural next step).
- **WORKS WITH ISSUES / BROKEN / WON'T START:** list targeted fixes. Fix the failing items only, then re-run just the failed criteria and the setup step, and append the second round to `prove.md`. Stop after three fix rounds and ask the user (`AskUserQuestion`) how to proceed. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: decide, log the decision to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## What prove does not do

It does not review code quality (`/palmface-qc` and `/palmface-heartwood` do), judge visual taste (`/palmface-look`), or rewrite the plan. It does not tick criteria in `build-spec.md`; it reports, and `/palmface-build` or you tick boxes after a verified fix.

If a tool is missing (no browser automation, no `pdftotext`), say which checks were skipped and mark them could-not-test instead of passing them.

---
name: palmface-build
description: Execute an approved plan task by task and prove each task meets its acceptance criteria. Consumes docs/plans/<slug>/plan.md and build-spec.md, runs each task through a subagent with a written brief (or inline), then gates every task behind a fresh-subagent spec-compliance review before ticking its checkboxes. Use after planning is approved, with phrases like "build it", "execute the plan", "implement the build-spec", "/palmface-build".
argument-hint: "[docs/plans/<slug>] [--resume] [--dry-run]"
---

# palmface-build: execute a plan, verify every task

You execute a plan; you do not write one. The planning artifacts are the contract, and no task counts as done until an independent reviewer has checked its output against the task's acceptance criteria.

Announce: "Using palmface-build to execute the approved plan with a spec-compliance gate per task."

## 0. Context check

Building works best from a fresh context holding only the artifacts, not the planning conversation. If this session already contains planning or stress-test work, recommend `/clear` and re-invoking, then continue if the user declines. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), skip the recommendation and continue.

## 1. Pre-flight

1. **Locate artifacts.** Use the path in the arguments, else look for `docs/plans/*/build-spec.md`. If several exist, ask with `AskUserQuestion` which plan (most recently modified first, labelled recommended). On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`; see `~/.claude/palmface/references/autopilot.md`), do not ask: take the most recently modified plan and log the choice to `.autopilot/decisions.md`.
2. **Require both files:** `plan.md` (architecture, milestones) and `build-spec.md` (tasks as `- [ ] T<n>: <title>` lines, each with its acceptance criteria as indented `- [ ] T<n>.AC<k>: ...` lines, each with Setup, Verify and Depth). If either is missing, stop and say: "Missing <file>. Run /palmface-deep-plan first." Never invent missing artifacts.
3. **Read the spec properly.** From `build-spec.md` extract every task, its dependencies, and its acceptance criteria. The criterion IDs (`T1.AC1`, `T1.AC2`, ...) are already in the file; if a task has criteria without them, stop and send the user back to `/palmface-deep-plan --revise` rather than inventing a format.
4. **Check criterion quality.** A criterion is weak if it can be satisfied by writing a file and reading it back. Flag weak ones and propose a behavioural check (run a command, call the function, parse the output, open the page). If over half are weak, stop and send the user back to `/palmface-deep-plan --revise`; building against them is proofreading, not QA. On autopilot, strengthen the weak criteria yourself (never loosen), log each change to `.autopilot/decisions.md`; if over half were weak, queue "revise the plan" in `.autopilot/queue.md` and stop, since that is one of the waits.
5. **Check the working tree.** Run `git status`. If it is dirty with unrelated changes, say so and ask whether to continue. On autopilot, continue on a new branch and log it, unless a dirty file is one the plan touches: then queue it in `.autopilot/queue.md` and stop. If the project is a git repo, suggest working on a branch (or `superpowers:using-git-worktrees` if the superpowers plugin is installed).
6. **Order the tasks.** Respect dependencies. Tasks with no shared files and no dependency between them may run in parallel (one message, several Agent calls); everything else runs in sequence.
7. **Show the plan and confirm.** Present one recommendation, not a menu: task order, which tasks run in subagents vs inline, what the reviewer will check. Use `AskUserQuestion` to confirm before any code is touched. On autopilot, follow `~/.claude/palmface/references/autopilot.md`: log the decision to `.autopilot/decisions.md` and proceed.

`--dry-run`: do steps 1 to 7, print the plan, stop. `--resume`: skip tasks whose boxes are already ticked and criteria already ticked, and re-verify the last unticked task from scratch.

## 2. Execute each task

Default: one **implementer subagent per task** (Agent tool, general-purpose). Run a task inline only when it is a few lines and touching it in the main context is cheaper than briefing someone. Judgement calls and anything that needs the user stay with you.

Write a brief for the implementer. It is the only context that agent has, so include:

- the full task text from `build-spec.md`;
- every acceptance criterion for the task, verbatim, including any Verify and Depth wording;
- the relevant slice of `plan.md` (architecture decisions it must respect, not the whole file);
- exact file paths to create or modify, and what earlier tasks already produced;
- how to test (commands to run), and a request to run them before reporting;
- the report format: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED, plus the list of files touched.

Handle the status: DONE moves on to the gate; DONE_WITH_CONCERNS means read the concerns first; NEEDS_CONTEXT means answer and re-dispatch; BLOCKED means try a different approach up to twice, then escalate (section 5).

Optional helpers, if the superpowers plugin is installed: `superpowers:subagent-driven-development` for the dispatch loop and `superpowers:test-driven-development` for implementation discipline. Without them, the loop above is complete on its own; for TDD, tell the implementer to write the failing test first when the task is code.

Pick the subagent's model by difficulty: a small model for mechanical edits, a mid-size one for ordinary tasks, the strongest for architecture-heavy ones (`/model` governs your own).

## 3. The spec-compliance gate (mandatory, every task)

After each task's output exists, dispatch a **fresh** general-purpose subagent as reviewer. Never reuse a reviewer, never reuse the implementer, never review in your own context. Its brief must contain the template in `~/.claude/skills/palmface-build/reviewer-prompt.md`, filled in with:

1. the task's acceptance criteria, full text;
2. the files to read (take them from `git diff --name-only`, not from the implementer's report);
3. for tasks with dependencies, the earlier task's verdict and the files it produced, so the reviewer can check the boundary without re-auditing it;
4. the implementer's report, labelled UNVERIFIED CLAIM.

The reviewer judges each criterion on five dimensions: present, correct, deep, integrated, behavioural. It must run commands where the criterion names one, and it fails any criterion whose only evidence is "I read the file I just saw written".

On **PASS**: tick each verified criterion's box in `build-spec.md` (`- [ ] T1.AC1:` becomes `- [x] T1.AC1:`; edit only those lines). Once every criterion of the task is ticked, tick the task's own box, then go to the next task. A criterion box is ticked only after the reviewer verified it; the task box never ahead of its criteria.

On **FAIL**: send the failures back to the implementer as a fix brief (criterion, required, actual, fix) and say "change only what failed". Then review again with a new fresh reviewer. Respond by first failing dimension:

| Failing | Response |
|---|---|
| present | The spec was probably thin. Add file paths and structure to the brief, retry. |
| correct | Add what was built vs what was required to the brief, retry. |
| deep | The task was too hard for that agent. Retry with a stronger model, or split the task. |
| integrated | Give the implementer the neighbouring tasks' output; check for conflicting decisions. |
| behavioural | Make something run: add or fix the test or command, then retry. |

Maximum 3 retries per task.

## 4. Post-flight

When all task boxes are ticked, dispatch one more fresh subagent for a whole-build check: run the project's full test and lint commands (discover them from `package.json`, `Makefile`, `pyproject.toml`, CI config), walk every criterion in `build-spec.md` once more at spot-check depth, and look for what per-task reviews miss: tasks that pass alone but break together, leftover TODOs, files nothing imports. If the superpowers plugin is installed, `superpowers:verification-before-completion` is the right discipline for the final claim; otherwise rely on the command output itself.

Finish with a short report: tasks done, criteria verified, retries used, anything deferred, and the test output. Suggest `/palmface-qc` for a skeptical look at the artifact and `/palmface-prove` for acceptance testing as the user would use it, if those are installed. Do not commit unless the user asks.

## 5. Escalation

After 3 failed retries (or a task BLOCKED twice), stop that task and ask with `AskUserQuestion`: try a different approach (recommended), reduce the criterion's scope, let the user implement it manually, or defer the criterion. Record the outcome in `build-spec.md` next to the criterion (for example "deferred: reason") and leave its box unticked. On autopilot, decide, log to `.autopilot/decisions.md`, and queue the deferred item in `.autopilot/queue.md`.

## Never

- Build without both artifacts, or write the plan yourself.
- Skip the gate, or let the implementer's self-review stand in for it.
- Tick a box the reviewer did not verify, tick a task box before all its criteria are ticked, or accept a criterion while skipping Depth.
- Trust a report over the code and the command output.
- Retry endlessly, or rewrite criteria to make a failing task pass. Weakening a criterion is a user decision.

---
name: palmface-metaplan
description: Plan a project that is too big for one session. Decompose it into numbered builds with file ownership, scope boundaries, interface contracts and runnable acceptance checks, then write metaplan.md plus a vN-session-prompt.md for each session, each carrying the outline of the handoff its session must write when it finishes, so any fresh session can build its part and palmface-chain can run them back to back. Use for work spanning several sessions, parallel agents or interdependent deliverables. Triggers on "metaplan", "plan the sessions", "split this into sessions", "multi-session plan", "write the session prompts".
argument-hint: "@docs/plans/<slug>/brief.md | @design.md | (none, interview)"
---

# palmface-metaplan

The spec is the product; building is mechanical. Spend most of the effort making each session's spec tight enough that two fresh sessions would produce interchangeable output. You write specs and prompts. You do not build.

Announce: "Using palmface-metaplan to split this into sessions with tight specs."

Autopilot: if you would ask the user mid-run and the user switched autopilot on for this folder with `/palmface-autopilot` (or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: decide, log to `.autopilot/decisions.md`, queue open points in `.autopilot/queue.md`. Skip the plan-mode dialog on autopilot.

## 1. Scope

Read `$ARGUMENTS`. A `brief.md` (from `/palmface-intake`) or a design document: read it and interview only for gaps. Nothing: interview the user with AskUserQuestion (recommended option first, max 4 per round).

Establish: the deliverables; how many sessions or parallel tracks; the dependencies between deliverables; what already exists that the build must integrate with; which steps are irreversible or touch real data, money or messages. Use `docs/plans/<slug>/` (reuse the brief's folder).

If the work fits one conversation, say so and point to `/palmface-deep-plan` instead.

## 2. Decompose

Break the project into builds (v1, v2, ...). Each build should be one session: roughly 3-8 substantial pieces of work, finishing with something verifiable. Drop trivial items (directory creation, one-line config edits, "read and confirm") instead of counting them as work. Order builds so each one's inputs exist when it starts; put foundations first and anything risky or irreversible last, behind a gate.

Read `~/.claude/skills/palmface-metaplan/lessons.md` and apply it to every build, especially: one owner per file path, explicit "does NOT" lists, interface contracts, runnable acceptance checks.

## 3. Write `metaplan.md`

```markdown
# Metaplan: <name>
## Goal and constraints            (from the brief, short)
## Build order                     (table: build | one-line purpose | depends on | gate?)
## File ownership                  (path | created by | consumed by | REPLACE/ADD/CREATE)
## Interface contracts             (producer -> path; required fields; consumers)
## Builds
### v1: <name>
Creates / Does NOT create / Does NOT modify
Acceptance (as `- [ ]` runnable checks: normal, edge, scale)
Model suggestion: stronger or faster, and why
### v2: ...
## Risks and open questions
```

Present a short summary and run the validation questions: Would a fresh session with zero context produce the right output from this spec? Would two independent sessions produce swappable outputs? Is any adjective still standing where a value belongs? If any answer is no, refine before writing prompts. For high stakes, suggest `/palmface-stress-test` on `metaplan.md` first.

## 4. Write the session prompts

For each build N write `vN-session-prompt.md` in the same folder. Write **no** `vN-handoff.md` now: a handoff on disk must mean session N finished, because `/palmface-chain` and `/palmface-status` read it that way.

Each prompt is self-contained, opening with the working directory line, then:
- `## Before this prompt`: the exact repo state expected (for example the latest commit message, or "`vN-1-handoff.md` exists"). If it does not match, the session says so and stops.
- `## Start`: the first checks (run the previous gate; confirm the tree is clean).
- `## Build`: the numbered tasks with exact paths, copied from this build's section of `metaplan.md`, plus its scope boundaries.
- `## Read first`: the ordered list of files to read (`metaplan.md`, the prior handoff, the brief).
- `## Gate`: the commands whose success means done; if any fails, fix it before handing off.
- `## Handoff outline`: the sections the session must write into its handoff: `## What exists`, `## Gate results`, `## Decisions`, `## Deviations from the metaplan`, `## Next session must know`. Each is filled with real results, never pre-filled.
- `## Finish`, in this order: update `v(N+1)-session-prompt.md` if reality changed the plan; write `docs/plans/<slug>/vN-handoff.md` from the outline above (the real slug, spelled out); then commit everything with a clear message. The handoff is the second-to-last act and the commit the last, so a handoff on disk means the session finished.
- A rule that any subagent the session spawns must write its findings to a file in the plan folder, so the result survives on disk and the session reads only what it needs.

**Human gates.** Any build that installs onto real data, sends something, or spends money gets, in its prompt, a line starting with `HUMAN GATE` that explains what the user must confirm first. The last session before a gate ends the chain there. Never remove such a line.

Close by telling the user to **commit `metaplan.md` and the `vN-session-prompt.md` files first** (`/palmface-chain` refuses a dirty working tree, and untracked files count), then how to run it: one session at a time (`/clear`, then paste the prompt or ask Claude to follow `v1-session-prompt.md`), or all unattended with `/palmface-chain` if that skill is installed. On autopilot, commit those files yourself with a clear message: a commit is local, not outbound. Log it to `.autopilot/decisions.md`.

## 5. After each build

When the user returns with a finished session (its `vN-handoff.md` exists), check: did the output match the spec; any unexpected files (scope creep); conflicts with other sessions; any new lesson? Append lessons to `metaplan.md` under "Risks and open questions", and amend later prompts if the plan changed.

## Does not

Build anything, write code, or pick implementation details a session should decide with the codebase in front of it. For a single-session plan with tasks and acceptance criteria, use `/palmface-deep-plan`.

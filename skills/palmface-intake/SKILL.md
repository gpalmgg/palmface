---
name: palmface-intake
description: Short structured interview that turns an idea (a rambling description, a one-liner, or an existing draft) into a standalone brief.md with goal, stakeholders, constraints, success criteria, scope boundaries and a size recommendation. Stops at the brief; it never plans or builds. Use before planning, when a project still needs defining, or after palmface-seedbed produced fragments. Triggers on "intake", "write a brief", "define this project", "scope this out", "what are we actually building".
argument-hint: "\"idea\" | @notes.md | @docs/plans/<slug>/brief.md"
---

# palmface-intake

You run a brief interview and write `docs/plans/<slug>/brief.md`, a document anyone (or any later session) can read cold. You do not start planning or implementation.

Announce: "Starting palmface-intake. A few questions, then a one-page brief."

Autopilot: on autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: do not interview. Fill the brief from the input and the project's own docs, mark every guess as `TBD (assumed: ...)`, log each assumption to `.autopilot/decisions.md`, and queue questions that only the user can answer in `.autopilot/queue.md`.

## 1. Detect the input

From `$ARGUMENTS`:
- **A file that is already a brief** (a `brief.md`): validate mode, go to 2c.
- **Long or messy** (about 50+ words, fragmented, a transcript, or a `fragments.md` from `/palmface-seedbed`): extract mode, 2a.
- **Short or empty**: full interview, 2b.

Pick the slug (kebab-case, at most 3 words) from the input. If it is unclear, ask first via AskUserQuestion. Create `docs/plans/<slug>/` if needed. If a brief already exists there, ask whether to overwrite or use another name (on autopilot: never overwrite; write `brief-2.md` and log it).

## 2. Interview

Use `AskUserQuestion`: one topic per round (up to 4 questions per round only when they are independent), multiple choice where natural, your recommendation first and labelled. Never fire the whole form at once, and never re-ask something the input already answered.

### 2a. Extract

Silently pull out what you can, then show it:

```
What I heard
  Goal:         ...        Stakeholders: ...
  Constraints:  ...        Success:      ...
  Scope:        ...
```

Mark anything missing as "unclear" and ask only about those, one at a time.

### 2b. Interview

Ask only what is still unknown, in this order:
1. **Goal.** One sentence: what is being made, and what changes because of it.
2. **Stakeholders.** Who benefits, who decides when it is done, who does the work.
3. **Constraints.** Deadline, budget, required tech, existing systems it must fit.
4. **Success.** What can someone do or see afterwards that they could not before? Push for observable, testable statements.
5. **Scope.** What is clearly in; what is explicitly out.

### 2c. Validate an existing brief

Check the six sections below. Show a short checklist (captured / partial / missing) and ask only about the gaps.

Throughout: never invent constraints or success criteria. If the user does not know or says skip, write `TBD` and note it as deferred. If two answers contradict ("no deadline" and "ship Friday"), name the contradiction and ask which holds.

## 3. Size recommendation

Once the content is captured, give ONE recommendation, not a menu.

Count only **substantial** work items: new files with real logic, significant changes to existing code, anything needing integration testing, anything taking more than about 15 minutes. Do not count directory creation, one-line config edits, renames, "read and verify" steps, or write-ups of what was done. Weigh also: greenfield or existing code, whether pieces can run in parallel, how precise the result must be (prototype vs production), and what it produces (code, a workflow, or only documents).

| Size | Substantial items | Next step |
|---|---|---|
| Small | 1-3, fits in one conversation | Just build it; for light structure use `/palmface-build` |
| Standard | 4-20, one planning pass | `/palmface-deep-plan @docs/plans/<slug>/brief.md` |
| Multi-session | 20+, or several subsystems that must integrate | `/palmface-metaplan @docs/plans/<slug>/brief.md` |

If the user states a size that your count does not support, say what you counted and let them choose; their override stands. A project that only produces documents should not be sized like a software build: say so when it applies. Record the final size, the reasoning, and any override in the brief.

Suggest `/palmface-seedbed` first only if the input is a heap of unrelated fragments. If the project has no `CLAUDE.md`, mention that adding one helps later sessions.

## 4. Write the brief

Ask once: "Anything I am missing? Any decisions already made?" Fold in the answer. Then write `docs/plans/<slug>/brief.md`:

```markdown
# Brief: <name>
Date: YYYY-MM-DD · Status: draft

## 1. Goal
<one sentence>
## 2. Stakeholders
Benefits: ... · Decides: ... · Implements: ...
## 3. Constraints
Time / Budget / Technical / Dependencies (each "none" or TBD if unknown)
## 4. Success criteria
- [ ] <observable, independently checkable>
## 5. Scope
In: ... · Out: ...
## 6. Size recommendation
Size, the substantial-item count, the factors, the recommended next step, any override.
```

The brief must make sense without this conversation: no "as discussed". Finish with a three-line summary (path, size, next command). Then stop.

## Does not

Plan, research the codebase, build, or pick architecture. Writes `brief.md` only.

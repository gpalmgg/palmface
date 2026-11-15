# Palmface's skills

Palmface installs 21 skills at `~/.claude/skills/palmface-*/`. Each one is a folder with a
`SKILL.md` that says what it does and when to use it. The user can type `/palmface-<name>`, and
you load one yourself when its description fits the task. The `palmface-` prefix keeps them
apart from the user's own skills and from Claude Code's built-in commands.

## The path a piece of work can take

Use the stages that fit. A small fix needs none of them, and a multi-week build may need most.

```
fragments ─▶ brief ─▶ plan ─▶ challenge ─▶ build ─▶ check ─▶ retro
 seedbed     intake   deep-plan  stress-test   build    qc       retro
                      metaplan   heartwood              prove
                                 premortem              look (visual work)
                                 canopy
```

Every stage writes into one folder per piece of work in the user's project,
`docs/plans/<slug>/`, so the next stage, or a fresh session, can pick it up from disk.

| Skill | Use it to | Writes |
|---|---|---|
| `/palmface-seedbed` | find the structure in messy fragments (notes, transcripts, pasted research) | `fragments.md` |
| `/palmface-intake` | turn an idea into a brief: goal, constraints, success criteria, scope, size | `brief.md` |
| `/palmface-deep-plan` | research the code, then plan one feature or milestone, with acceptance criteria that test behaviour | `research.md`, `plan.md`, `build-spec.md` |
| `/palmface-metaplan` | split work too big for one session into numbered sessions | `metaplan.md`, `vN-session-prompt.md`, `vN-handoff.md` |
| `/palmface-stress-test` | challenge a plan with a fresh-eyes review (PASS / PASS WITH RISKS / FAIL) | `stress-test.md` |
| `/palmface-heartwood` | a three-agent evaluation: bug hunt, steelman, or spec ambiguity | `heartwood-<mode>.md` |
| `/palmface-premortem` | assume it failed; find out why before it does | `premortem.md` |
| `/palmface-canopy` | look at a plan from three future timelines and compare them | `canopy.md` |
| `/palmface-build` | build an approved plan task by task, with every task reviewed against its criteria | ticks in `build-spec.md` |
| `/palmface-qc` | check what was just built, with fresh eyes, before the user looks | `qc.md` |
| `/palmface-prove` | acceptance-test a build through its real interfaces, with evidence | `prove.md` |
| `/palmface-look` | a visual gate: 2–3 directions on a contact sheet, then the user picks | a local `sheet.html` |
| `/palmface-retro` | a retrospective from real data, then a short interview | `retro.md` |

**Run one challenge per planning cycle** (stress-test, heartwood, premortem or canopy): fix what
it finds, then build. Stacking all four mostly costs tokens.

## Judgement and sessions

| Skill | Use it to |
|---|---|
| `/palmface-honest-take` | give a structured, sceptical verdict on an idea or a feasibility question |
| `/palmface-listen` | turn a multi-point message into a numbered checklist and handle every point |
| `/palmface-status` | see where a piece of work stands and what comes next (keeps `state.json`) |
| `/palmface-save` | save a decision, insight or bookmark to the project, or a fact to memory |
| `/palmface-sessions` | find a past session and the command to resume it (read-only) |
| `/palmface-chain` | run a plan's session prompts back to back, headless, stopping at a HUMAN GATE |
| `/palmface-start` | open a session: greeting, status card, a suggested name |
| `/palmface-autopilot` | turn autopilot on or off for the project (`on`, `off`, `status`) |

## From plugins

- **Brainstorming** comes from the superpowers plugin (`superpowers:brainstorming`), not from
  Palmface. Use it before planning something new when it is installed. Palmface's skills name a
  few other superpowers skills too, always as optional and with a fallback. The plugin list and
  its install lines are in `docs/plugins.md` in the Palmface repo.

## The user's own notes, when they keep them

- `~/.claude/palmface-local/persona.md`: how they decide. Autopilot and the skills that need
  their taste read it.
- `~/.claude/palmface-local/voice.md`: how they write. Drafts that go out under their name
  follow it.

Palmface's extras layer ships blank starters for both in `~/.claude/palmface/templates/`. The
user copies them; neither Palmface nor any skill writes into `palmface-local`.

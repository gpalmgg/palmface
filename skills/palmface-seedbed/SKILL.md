---
name: palmface-seedbed
description: Find the structure already hiding in messy fragments (voice-note transcripts, scattered ideas, pasted research) without judging or adding anything. Five constrained passes (decompose, connect, find gaps, propose structures, rank them) run as subagents and write one fragments.md. Use when the user has two or more unstructured pieces of material and wants to see what they add up to before defining a project. Triggers on "seedbed", "make sense of these notes", "find the structure in this", "what do these fragments have in common".
argument-hint: "\"text\" | @file.md | @dir/ | @a.md @b.md"
---

# palmface-seedbed

Messy material usually already contains a shape. Your job is to reveal it, not to invent one. Every pass has one strict constraint on what it may do; that constraint is the mechanism. You never judge quality, never add new ideas, never edit the input files.

Announce: "Using palmface-seedbed to look for the structure in this material."

## Input

Read `$ARGUMENTS`: inline text, one file, several files, or a directory (read every text file in it). Join everything into one input, remembering which file each piece came from. If the input is longer than roughly 5 pages, split it into thematic clusters and run each separately. If nothing was passed, ask the user (AskUserQuestion) what to read.

Pick the slug now, before pass 0 (kebab-case, at most 3 words, from the dominant theme of the input as you first read it). Output goes to `docs/plans/<slug>/fragments.md` in the user's project, and pass files to `docs/plans/<slug>/.seedbed/`.

## The five passes

Run them in order as general-purpose subagents (Agent tool), each with an isolated context: the pass prompt from `~/.claude/skills/palmface-seedbed/passes.md`, with the variables filled in. Cheaper, faster models are fine for passes 0, 2 and 4; use your strongest model for passes 1 and 3 if you can choose. Subagents write their output to a file (`docs/plans/<slug>/.seedbed/passN.md`) as well as returning it, so each result survives on disk and you read only what you need.

| Pass | Name | Constraint | Receives |
|---|---|---|---|
| 0 | Decompose | Split only | raw input |
| 1 | Connect | Annotate links only, each backed by quotes | pass 0 in full |
| 2 | Gaps | Name what is missing, never answer it | pass 0 titles + pass 1 in full |
| 3 | Structures | Propose 2-3 shapes from existing pieces only, every claim cited | pass 0 titles + pass 1 names + pass 2 in full |
| 4 | Rank | Compare the proposed shapes on feasibility, energy, effort, risk | pass 3 in full |

Between passes, build the short summaries the prompts ask for (IDs and titles only), so later passes stay small.

## Validate after every pass

If a check fails, report the broken IDs and offer to re-run that pass.

- **0:** fragment IDs F1, F2... are sequential; at least 2 fragments. Fewer than 2: stop with "Insufficient material: need at least 2 fragments."
- **1:** every connection (C1...) names exactly two real fragments and quotes 5+ words from each. Fewer than 2 connections: stop with "Fragments look unrelated: not enough signal."
- **2:** every gap (G1...) cites real F or C IDs; every question not tagged `[DEEP]` could be answered in 2-3 sentences; at least 1 gap.
- **3:** 2-3 structures; every spine cites real IDs; no claim without an ID citation.
- **4:** every ranked structure maps to a real option; all four dimensions present; the recommendation names one option.

If any pass fails outright, present what completed and say where it stopped, then remove `.seedbed/` (keep nothing but a `fragments.md` you actually wrote).

## Output

Write `docs/plans/<slug>/fragments.md`, then remove `.seedbed/`:

```markdown
# Fragments: <topic>
Date: YYYY-MM-DD · Source: <files or "inline">

## Fragments        (ID | title | source; note "repeated Nx" where it applies)
## Connections      (ID | fragments | name | strength) then the quote pairs as evidence
## Gaps             (grouped: blocking, enriching, [DEEP])
## Proposed structures   (per option: name, form, spine with IDs, arrangement, gaps to fill, energy)
## Ranking          (per option: feasibility, energy, effort, risk, and a GO / CONDITIONAL / NO-GO signal)
## Recommended next step
```

Choose the next step honestly:
- Blocking gaps exist: "Answer G1, G2 before choosing a structure."
- A structure is clear and it is a thing to build: "Run `/palmface-intake` on this file, then `/palmface-deep-plan`." If it needs creative exploration first and the superpowers plugin is installed, `superpowers:brainstorming` fits; without it, talk the options through with the user.
- A structure is clear and it is writing: "Draft from the chosen spine and arrangement."
- Connections are sparse: "Gather more fragments and re-run."

Present a short summary in chat: counts, the recommended structure, the blocking gaps. The ranking pass is a light evaluation of shapes only. It does not replace reviewing a real plan later.

If you notice the material implies a large, multi-session build, say so in one line and point to `/palmface-metaplan`.

## Does not

Judge the quality of the material, modify input files, generate new content, or start planning. Autopilot: this skill does not ask the user anything mid-run except when no input was given; on autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: if there is no input, log the gap to `.autopilot/queue.md` and stop.

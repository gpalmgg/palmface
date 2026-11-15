---
name: palmface-look
description: Visual approval gate. Before any page, UI, restyle, card or document look is called done, make 2 or 3 directions from references the user confirmed, show them on a local contact sheet, and wait for the user's pick and approval. You never judge taste yourself; you only check for breakage. Use for any visual work ("make it look", "redesign", "restyle", a new page or layout) and when the user says "/palmface-look", "look ok" or "look approve".
argument-hint: "[approve | <what to design>]"
---

# palmface-look: nothing visual is done until the user has looked

## The rule

Visual work (page, UI, styling, PDF, artifact, card) is not done, good or shippable until the user has seen it and said yes.
- You check only that it is not broken. You never decide whether it looks right.
- The look comes from the work's look folder (below) and the user's confirmed references. A token file or spec alone never counts.
- Before any direction is drawn, the user confirms the references.
- You never write approval entries in `approvals.jsonl` on your own initiative. An approval is the user's words ("look ok", "/palmface-look approve", a clear yes right after you asked); you record exactly that, with the time and what was approved.
- Never hand a look decision to a persona file, to autopilot, or to `/palmface-qc`.
- Every reply that touches visual work ends with `LOOK: awaiting the user (<what to look at>)` until approved, then `LOOK: approved <id>`.

## The look folder

When the work has a plan folder, the look folder is `docs/plans/<slug>/look/`; otherwise `docs/look/<topic>/`. Below, `look/` means that folder.

```
look/
  LOOK.md                     the look in the user's words + "rejected and why" + quality ledger
  live/                       screenshots of the real product (desktop 1440, phone 390)
  taste/                      examples the user loves or hates; add only when they say so
  directions/<date>-<slug>/   mockups and contact sheets
  approvals.jsonl             one line per approval the user gave
```

`LOOK.md` frontmatter: `truth_urls:` (what visitors really see) and `visual_globs:` (files that count as visual in this project).

## Step 0: references

1. Read `look/LOOK.md`, `look/live/`, `look/taste/`.
2. If `live/` is missing or old, capture fresh screenshots of the truth URLs (a browser-automation tool if you have one; otherwise ask the user to drop screenshots in `live/`, or on autopilot queue that request).
3. No `look/` yet: draft `LOOK.md`, then ask with `AskUserQuestion` for the truth URLs and two taste examples (one loved, one hated). Stop. Draw nothing yet. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`; see `~/.claude/palmface/references/autopilot.md`), do not ask: write the draft `LOOK.md` from what the project shows (existing pages, assets, docs), queue "confirm truth URLs and give a loved and a hated example" in `.autopilot/queue.md`, end the reply with `LOOK: awaiting the user (references)`, and continue with non-visual work only.
4. The truth is the live product, never a spec or a token file.
5. Quality ledger: every quality the user asks for (motion, type, imagery, a map, anything) becomes a row in a `## Quality ledger` table in `LOOK.md` with a concrete bar and a status. Stills miss motion: for animated references, link the live page instead of judging a screenshot.

**Ledger rule, for every step below:** a direction or build that drops, weakens or fakes a ledger quality says so in plain words, on the contact sheet and in the reply. Never a silent downgrade. Only the user can accept one.

## Step 1: directions

Make 2 or 3 directions as real HTML of the actual page, in `look/directions/<date>-<slug>/<n>-<name>/`. Each cites at least one `live/` or `taste/` image by file name ("from live/home-desktop.png"). A CSS file is not a citation.

## Step 2: contact sheet, shown locally

Build one `look/directions/<date>-<slug>/sheet.html`: each direction as a labelled column or card with a screenshot (or an iframe of its `index.html`), its name, the reference it cites, and any ledger downgrade. Then show it: `open look/directions/<date>-<slug>/sheet.html`. Nothing is sent anywhere.

## Step 3: the user's pick

- User present: `AskUserQuestion`, one option per direction, recommended first (a recommendation is about fit with the references, not beauty).
- User away, or on autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`): follow `~/.claude/palmface/references/autopilot.md`. The pick waits for the user. Add an entry to `.autopilot/queue.md` ("pick a direction: <sheet path>"), end the reply with `LOOK: awaiting the user (contact sheet <path>)`, and continue with non-visual work only.

## Step 4: build the pick

Build only the chosen direction. Then do a breakage check and nothing else:
- horizontal overflow
- console errors
- text contrast
- screenshots at 390 and 1440, saved in the direction folder and opened with `open`

Say that nothing is broken. Do not say it looks good, right or on brand.

No browser tool available: open the files with `open`, say plainly which of these checks could not run (screenshots, console errors, contrast, overflow), and leave those checks to the user. Never report a check you did not run as passed.

## Step 5: approval

The user says "look ok", "/palmface-look approve" (optional note), or a plain yes straight after your `LOOK: awaiting` line. Append one JSON line to `look/approvals.jsonl` with the time, the files or direction approved, the current git commit if any, and their note. Only then may you call the visual work done or shippable.

## Limits

This is a discipline, not a lock: you could write any file. It works because you follow it. If a later change touches files matching `visual_globs`, the approval no longer covers them; ask again.

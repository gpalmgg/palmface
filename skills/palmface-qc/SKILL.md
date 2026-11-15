---
name: palmface-qc
description: Post-build verification. Runs or opens what was just built, reviews it with fresh skeptical eyes, checks it against the spec or the user's request, auto-fixes mechanical issues and reports the rest in a short QC report. Use after building anything (code, web page, PDF, document, essay) or when the user says "/palmface-qc", "QC this", "check what you made", "verify this".
argument-hint: "[path ...] [--spec <path>] [--deep]"
---

# palmface-qc: quality control on what you just made

Announce: "Running palmface-qc on {artifact}."

You built it, so you are biased toward calling it done. This skill makes you check it as a stranger would, before the user has to.

## Step 1: find what to check

- If the user passed paths, use those. Otherwise look back through your recent file writes and edits in this session.
- Drop trivial edits (one-line tweaks, ignore files, notes). Group related files into one artifact (five files of one feature = one artifact; a PDF and the script that made it = two).
- Classify each artifact: **web** (.html, .tsx, .jsx, .vue, .svelte), **code** (scripts and source), **pdf**, **writing** (prose of roughly 500+ words), **generic** (anything else: review and spec-check only).
- If nothing is detectable, ask with `AskUserQuestion` for a path. Do not guess. On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: decide, log the decision to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`. Here that means: check the most recently changed artifact and note the choice in the log.

## Step 2: three checks per artifact, in order

### A. Execute: really run or open it

- **code:** run the entry point with realistic input: `--help`, then a real run, the golden path plus one edge case. With no entry point, run the existing tests. If there are none, say "no executable path, relying on review and spec-check".
- **web:** if it needs serving, use the project's dev command, or, only when `command -v python3` succeeds, `python3 -m http.server --bind 127.0.0.1 <port>` from the artifact's folder (never without `--bind`: it would expose the folder to the network). Without python3, just `open` the file. Note the process id and stop it when you are done, even after a failure. Open it (`open <url or file>`) and check it at desktop and phone width. If a browser-automation tool is available, use it for screenshots and console errors; if not, say what you could not check.
- **pdf:** extract text (`pdftotext <file> -` if installed) and render page one into a fresh private folder (`d=$(mktemp -d) && qlmanage -t -s 1600 -o "$d" <file>`, never a fixed path in `/tmp`), then look at the image in `$d`. Pages present? Text cut off? Blank pages?
- **writing / generic:** skip this step; read the file end to end.
- If it will not run, stop and report that. Do not review something that does not run.
- If running would have side effects (sends mail, posts to an API, writes to a production database, deletes data), do not run it. Note "execute skipped: side effects" and carry on with B and C.

### B. Review with fresh eyes

Read it as if you had never seen it. Look for:
- **Everything:** broken references or links, leftover TODO / FIXME / placeholder text, inconsistent naming, copy-paste slips.
- **Writing:** filler openers, stacked hedges, transition-word soup, claims that smell unverified, a voice that drifts partway through.
- **Web:** breakage only (overflow, console errors, low contrast, missing alt text, no focus styles, broken at phone or desktop width). Never give a taste verdict. If the work is visual, end with `LOOK: awaiting the user` and point at `/palmface-look`.
- **Code:** swallowed errors, fallback values that mask bugs, unused code, hardcoded secrets or absolute paths, missing handling at input boundaries, mock data left in.

### C. Spec-check

Find the spec, in this order: `--spec <path>`; a `build-spec.md`, `plan.md` or `brief.md` in the artifact's folder or a parent up to the repo root (the kit's plans live in `docs/plans/<slug>/`); else the user message that asked for the work.

Turn its explicit requirements into a numbered checklist and mark each: met (say where), missing (say the gap), or partial (say what exists versus what was asked). If the spec is ambiguous, quote the line and mark the affected items partial. Where spec and review disagree, the spec wins; raise your objection under "needs the user's call".

## Step 3: fix what you are sure of, report the rest

Fix without asking: typos, broken links and imports, unused variables, placeholder text, swallowed-error patterns, and spec gaps that are mechanical and unambiguous (a named function that is missing, a listed section that is absent). Re-run the relevant check after each fix.

Report, do not fix: anything needing a judgment about meaning or voice, spec gaps that need real new work (more than about 50 lines or a new feature), taste or look questions, anything you are under 80% sure the user wants.

## Output

Write this to the terminal, and also save it to `qc.md` in the plan folder (`docs/plans/<slug>/qc.md`) when the artifact belongs to a plan:

```
QC REPORT: <artifact>

EXECUTE: runs / broken
  <one line on what happened>

REVIEW: <N> issues, <M> fixed
  Fixed:
    - <issue> -> <fix>
  Needs your call:
    - <issue>: <why you did not fix it>

SPEC-CHECK: <X>/<Y> met   (source: <path or "your request">)
  met      <requirement>: <where>
  missing  <requirement>: <gap>
  partial  <requirement>: <state>

VERDICT: ship / hold / broken
```

With several artifacts, repeat the block and add one top-level verdict line.

## Boundaries

- palmface-qc is the post-build check: after you claim done, before the user looks. It does not replace a formal pre-merge review (`/palmface-heartwood --adversarial` for a deeper hunt, or `superpowers:requesting-code-review` if the superpowers plugin is installed) or plan validation (`/palmface-stress-test`).
- With `--deep`, also run `/palmface-heartwood --adversarial` on code artifacts.
- For a full acceptance run of a built system through its interfaces, use `/palmface-prove`.
- Evidence before claims: never write "ship" without having run the check that supports it (`superpowers:verification-before-completion` says the same, if installed).

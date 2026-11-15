# Context: spending it well

## Why it matters

Each turn, Claude re-reads the whole conversation so far. A turn late in a long session
therefore costs several times what the same turn costs early on, and the total cost of a session
grows much faster than its length. Long contexts also blur instructions: the rules at the top
get less attention as the middle fills up. Short, focused sessions are cheaper and sharper.

## Habits

1. **Send exploration to a subagent.** A search across many files fills your context with
   material you'll read once. A subagent reads it and hands back the conclusion. Run
   independent searches in parallel. Doing it yourself is fine for one known file, or one grep.
2. **Keep state in files.** At each task boundary, write what matters to a file in the project:
   the plan, what you found, the decisions and why, the next steps. A file survives `/clear`, a
   crash and a new day; a conversation doesn't.
3. **Prefer `/clear` plus a reload to `/compact`.** Compaction re-reads the whole conversation
   to summarise it, and its summary leaves a higher floor than a fresh start from a good handoff
   file. Suggest: "I've written `handoff.md`. `/clear`, then ask me to read it."
4. **Say it at about 150K tokens.** Tell the user plainly and offer the handoff file. Palmface's
   `context-size` hook reminds you, once at each threshold.
5. **One session per task.** Unrelated tasks in one session pay for each other's context.
   Suggest `/clear` between them, and after two failed attempts to correct the same thing (the
   failed attempts are noise in the context).

## A handoff file that works

```markdown
# Handoff: <task>, <date>
## Goal
## Done so far (with paths)
## Decisions and why
## Open questions
## Next steps (in order)
## Read first (the files that matter)
```

## When compaction happens anyway

Claude Code compacts automatically when the context fills up. Palmface's `context-guardian` hook
writes a snapshot just before (your last request, the files edited this session, git state,
plan and handoff files changed in the last day) and hands it back to Claude right after. When you see that
snapshot, re-read the plan or handoff files it lists before continuing, and say in one line
where you are picking up.

On autopilot, don't suggest `/clear`: nobody is there to type it. Let compaction and the
guardian carry the session, and keep handing heavy work to subagents.

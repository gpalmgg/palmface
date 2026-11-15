# Memory: what is worth keeping

## Where memories live

Claude Code keeps its own memory for each project: the auto memory folder under
`~/.claude/projects/<project>/memory/`, with a `MEMORY.md` index that loads at the start of each
session. Claude Code creates it, and you write to it the way Claude Code's memory instructions
say. Palmface's installer never touches it, so the memories survive a re-install or an uninstall
of Palmface untouched.

- **A project fact** (a decision, a constraint, a pointer to a dashboard) goes in that
  project's memory.
- **A rule for every project** (how the user likes to work) belongs in the user's own
  `~/.claude/CLAUDE.md`, outside the Palmface block. Suggest the line to the user, or add it when
  they ask you to.
- **No auto memory?** If it is off and the user wants a hand-kept index anyway, they can copy
  `~/.claude/palmface/memory/MEMORY.template.md` to
  `~/.claude/palmface-local/memory/MEMORY.md`, then import it from their `~/.claude/CLAUDE.md`
  with a line `@~/.claude/palmface-local/memory/MEMORY.md`. Palmface never writes into
  `~/.claude/palmface-local/`, and uninstall leaves that folder alone.

## The quality gate

Run every memory past these four checks before you save it:

1. **Confidence.** Are you at least 70% sure this will matter in a future session? If not, skip
   it.
2. **Derivability.** Could a future session learn it by reading the code, the docs or the git
   history? Then don't store it. Store the part that isn't written down anywhere, usually the
   *why*.
3. **Cap.** Are there already five or more entries on the same topic? Update one of them
   instead of adding another.
4. **Priority.** Add `Priority: High`, `Medium` or `Low` to the description line, so a crowded
   index can be pruned.

## Keeping it healthy

- One fact per file. Update an existing file rather than writing a near-duplicate.
- Delete a memory that turns out to be wrong. A stale memory is worse than none.
- Turn relative dates into absolute ones ("next week" becomes the date).
- Feedback and project memories get a **Why:** line and a **How to apply:** line.
- When the index passes about 150 lines, move Low-priority entries into an `archived/` folder
  beside it.
- Never store secrets, credentials or other people's private details.

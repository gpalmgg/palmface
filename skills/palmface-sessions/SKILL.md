---
name: palmface-sessions
description: Browse past Claude Code sessions and find the one to resume. Lists sessions newest first with their title (from /rename), the first line of the first prompt, date, working directory and a ready-to-run resume command. Read-only. Use when the user says "show my sessions", "find that conversation", "which session was I in", "list sessions", "resume an old session", or asks how to get back to earlier work.
argument-hint: "[--search WORD] [--named] [--project PART] [--limit N | --all]"
---

# palmface-sessions

Claude Code keeps every session as a transcript under `~/.claude/projects/`. This skill helps the
user find one and get back to it. It never writes there and never shows transcript contents.

## How to run it

1. Check the script is there: `~/.claude/skills/palmface-sessions/scripts/sessions.sh`. It needs
   `jq`; check with `command -v jq`. If jq is missing, say so and suggest `brew install jq`.
2. Turn the user's request into flags and run it:

   ```
   ~/.claude/skills/palmface-sessions/scripts/sessions.sh [flags]
   ```

   | Flag | Use it when |
   |---|---|
   | `--search WORD` | the user remembers a word from the title or the opening prompt |
   | `--named` | they only want sessions they gave a name with `/rename` |
   | `--project PART` | they want one project; PART is any piece of its folder path |
   | `--limit N` / `--all` | the default of 20 is too few or too many |

3. Show the result as a short list: date, title, folder. Do not paste the raw output when it is
   long; pick the likely matches.
4. When the user picks one, give them the resume command from the output. A session can only be
   resumed from its own project folder, so the command starts with `cd`. They run it in a normal
   terminal, or type `/resume` inside Claude Code to get the built-in picker.

## Rules

- **Read-only.** Never edit, move or delete anything under `~/.claude/projects/`.
- **Titles and first lines only.** Search covers the title and the first prompt line, not the
  whole conversation. If that finds nothing, say so. Do not open transcripts to look deeper unless
  the user asks, and even then quote only what they asked for.
- Unnamed sessions show their first prompt line as the label. Suggest `/rename` inside a session
  that matters, so it is easy to find later.
- A session that contains secrets in its first line shows them in the list. If a line looks like
  a credential, do not repeat it back; say the line was hidden.

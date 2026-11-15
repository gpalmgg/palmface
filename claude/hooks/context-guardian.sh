#!/bin/bash
# Palmface hook (PreCompact + SessionStart): keep Claude's footing across a compaction.
# Compaction replaces the conversation with a summary, and the summary can drop what you were
# doing. Just before it, this hook writes a short snapshot of the session; just after, it hands
# the snapshot back to Claude as context. It backs "Spend context carefully" in Palmface's
# CLAUDE.md, the habit of keeping state in files.
#
# Usage, from settings.json:
#   context-guardian.sh save      (PreCompact) write the snapshot
#   context-guardian.sh restore   (SessionStart, matcher "compact") print it for Claude
#
# The snapshot holds: when and why it was taken, the folder, its git branch and number of
# changed files, the user's last request (key-shaped strings masked), and the files written or
# edited this session, with the plan and handoff files among them called out. Files the session
# never wrote are never listed: a plan in a freshly cloned repository is not your plan. It is
# built from the session transcript Claude Code names in the hook JSON, and from git when git is
# really installed (the /usr/bin/git stub without the Command Line Tools is never run, as it
# would open an installer). Both are only read: git runs with --no-optional-locks, so it doesn't
# even refresh your index.
#
# State: ~/.claude/palmface/state/context-guardian/<session>.md (0600), swept after a week.
# Never blocks a compaction.
#
# Off switches:
#   PALMFACE_HOOKS=off       every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_GUARDIAN=off    just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_GUARDIAN:-on}" && exit 0

dir="$KH_STATE/context-guardian"
snap="$dir/$(kh_session).md"

have_git() { # a git that runs without prompting to install anything
  local g
  g=$(command -v git 2> /dev/null) || return 1
  [ "$g" = /usr/bin/git ] || return 0
  /usr/bin/xcode-select -p > /dev/null 2>&1
}

save() {
  local d cwd t trigger branch dirty all files plans req
  d=$(kh_state_dir context-guardian) || return 0
  find "$d" -type f -mtime +7 -delete 2> /dev/null
  cwd=$(kh_get cwd)
  trigger=$(kh_get trigger)
  t=$(kh_transcript) || t=''

  if [ -n "$t" ]; then
    req=$(kh_last_prompt "$t" | kh_mask)
    # Each Write/Edit tool call names its file: every distinct one, newest last.
    all=$(kh_tail 8000000 "$t" | /usr/bin/grep '"type":"tool_use"' |
      /usr/bin/grep -E '"name":"(Write|Edit|MultiEdit|NotebookEdit)"' | /usr/bin/awk '
      match($0, /"(file|notebook)_path":"[^"]*"/) {
        p = substr($0, RSTART, RLENGTH); sub(/^"[a-z]+_path":"/, "", p); sub(/"$/, "", p)
        if (p in seen) { for (i = seen[p]; i < n; i++) { o[i] = o[i + 1]; seen[o[i]] = i } n--; }
        o[++n] = p; seen[p] = n
      }
      END { for (i = 1; i <= n; i++) print "- " o[i] }')
    files=$(printf '%s\n' "$all" | tail -25)
    # Plan and handoff files among them (the same names as *plan*.md and *handoff*.md).
    plans=$(printf '%s\n' "$all" | /usr/bin/awk '{ n = tolower($0); sub(/.*\//, "", n) }
      n ~ /(plan|handoff).*\.md$/ { print }' | tail -10)
  fi

  write_snap() { # the snapshot, with the git line when one is known
    {
      printf '# Palmface context snapshot\n\n'
      printf 'Saved %s, just before a compaction%s.\n' "$(date '+%Y-%m-%d %H:%M')" "${trigger:+ ($trigger)}"
      [ -n "$cwd" ] && printf 'Folder: %s\n' "$cwd"
      [ -n "${branch:-}" ] && printf 'Git: branch %s, %s changed file(s)\n' "$branch" "${dirty:-0}"
      if [ -n "${req:-}" ]; then printf '\n## The last request\n%s\n' "$req"; fi
      if [ -n "${files:-}" ]; then printf '\n## Files written or edited this session (newest last)\n%s\n' "$files"; fi
      if [ -n "${plans:-}" ]; then printf '\n## Plan and handoff files this session wrote or edited\n%s\n' "$plans"; fi
      printf '\n## Picking up\n'
      printf '1. Re-read the plan or handoff files this session wrote (above), if any, before you continue.\n'
      printf '2. Check git status and the diff for work in progress.\n'
      printf '3. Say in one line where you are picking up, then carry on.\n'
    } 2> /dev/null > "$snap.tmp.$$" && mv -f "$snap.tmp.$$" "$snap" 2> /dev/null
    rm -f "$snap.tmp.$$" 2> /dev/null
  }
  # Written first without git, so a slow git in a huge repo (or a hook timeout) can't lose it.
  write_snap
  if [ -n "$cwd" ] && [ -d "$cwd" ] && have_git && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Read-only: no index refresh, and no fsmonitor program from the repo's own config.
    branch=$(git -C "$cwd" -c core.fsmonitor=false rev-parse --abbrev-ref HEAD 2> /dev/null)
    dirty=$(git -C "$cwd" -c core.fsmonitor=false --no-optional-locks status --porcelain 2> /dev/null | wc -l | tr -d ' ')
    [ -n "$branch" ] && write_snap
  fi
}

restore() {
  [ "$(kh_get source)" = compact ] || return 0
  local f newest cwd
  # The snapshot is written seconds before a compaction. One older than 15 minutes is from an
  # earlier compaction whose save this time failed: not worth handing back as current.
  f=$(find "$snap" -type f -mmin -15 2> /dev/null)
  if [ -z "$f" ]; then
    # A new session id after the compaction: take the newest recent snapshot, but only one taken
    # in this same folder (another session's snapshot is not yours).
    cwd=$(kh_get cwd)
    [ -n "$cwd" ] || return 0
    newest=$(find "$dir" -name '*.md' -type f -mmin -15 2> /dev/null | while IFS= read -r p; do
      /usr/bin/grep -qxF "Folder: $cwd" "$p" 2> /dev/null && printf '%s\t%s\n' "$(stat -f %m "$p")" "$p"
    done | sort -rn | head -1 | cut -f2-)
    [ -n "$newest" ] || return 0
    f=$newest
  fi
  printf 'Palmface: the conversation was just compacted. This snapshot was saved right before it:\n\n'
  head -c 6000 "$f" 2> /dev/null
}

case "${1:-}" in
  save) save ;;
  restore) restore ;;
esac
exit 0

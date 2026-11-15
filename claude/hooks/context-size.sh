#!/bin/bash
# Palmface hook (UserPromptSubmit): watch how big the session's context has grown, and when it
# crosses a threshold, tell Claude once to say so and offer a handoff file. It backs "Spend
# context carefully" in Palmface's CLAUDE.md: every turn re-reads the whole context, so a long
# session costs far more per turn and follows instructions less well.
#
# The size is the real token count of the last reply (input plus cache reads and writes), read
# from the session transcript Claude Code names in the hook JSON. Three thresholds, each nudged
# once per session: N, N + 100K and N + 250K tokens, with N = 150000 unless you set
# PALMFACE_CONTEXT_NUDGE. State: one line per session in ~/.claude/palmface/state/context-size/
# (swept after a week). Never blocks. Quiet on autopilot and unattended runs, where nobody can
# start a fresh session.
#
# Off switches:
#   PALMFACE_HOOKS=off       every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_CONTEXT=off     just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_CONTEXT:-on}" && exit 0
kh_unattended && exit 0
# A slash command ("/clear", "/model opus") is not a turn of work; a path ("/tmp/x is full") is.
printf '%s\n' "$(kh_get prompt)" | /usr/bin/grep -Eq '^/[A-Za-z][A-Za-z0-9:_-]*( |$)' && exit 0

t=$(kh_transcript) || exit 0
# The newest main-thread reply that carries real usage. One reply can span several lines, all
# with the same usage, so the last such line is enough. Error and interrupt notices are stored as
# "<synthetic>" replies with zero usage; they say nothing about the context, so skip them.
tokens=$(kh_tail 2000000 "$t" | /usr/bin/grep '"type":"assistant"' | /usr/bin/grep -v '"isSidechain":true' |
  /usr/bin/grep '"usage":{' | /usr/bin/grep -v '"model":"<synthetic>"' | tail -50 | /usr/bin/awk '
  function num(k) { return match($0, "\"" k "\":[0-9]+") ? substr($0, RSTART + length(k) + 3, RLENGTH - length(k) - 3) + 0 : 0 }
  { n = num("input_tokens") + num("cache_creation_input_tokens") + num("cache_read_input_tokens"); if (n > 0) last = n }
  END { if (last > 0) print last }')
[ -n "$tokens" ] || exit 0

n=${PALMFACE_CONTEXT_NUDGE:-150000}
case "$n" in '' | *[!0-9]*) n=150000 ;; esac
if [ "$tokens" -ge $((n + 250000)) ]; then band=3
elif [ "$tokens" -ge $((n + 100000)) ]; then band=2
elif [ "$tokens" -ge "$n" ]; then band=1
else band=0; fi

d=$(kh_state_dir context-size) || exit 0
f="$d/$(kh_session)"
was=$(cat "$f" 2> /dev/null)
case "$was" in '' | *[!0-9]*) was=0 ;; esac
if [ "$band" -eq 0 ]; then
  [ "$was" -eq 0 ] || echo 0 > "$f" # smaller again (after a compaction): arm the nudges again
  exit 0
fi
[ "$band" -gt "$was" ] || exit 0
find "$d" -type f -mtime +7 -delete 2> /dev/null
echo "$band" > "$f"

k=$(((tokens + 500) / 1000))
case "$band" in
  1) printf 'Palmface: this session'\''s context is about %sK tokens. In one line, tell the user, and offer to write a handoff file (plan, findings, next steps) so the next task can start fresh after /clear.\n' "$k" ;;
  2) printf 'Palmface: this session'\''s context is about %sK tokens, which makes every turn expensive. Recommend writing a handoff file and starting fresh with /clear before the next big step.\n' "$k" ;;
  3) printf 'Palmface: this session'\''s context is about %sK tokens. Before anything else, write a handoff file (plan, findings, decisions, next steps), then recommend /clear and reloading from that file.\n' "$k" ;;
esac
exit 0

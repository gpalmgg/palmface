#!/bin/bash
# Palmface hook (UserPromptSubmit + Stop): when the user asks whether the work is finished
# ("are we done?", "can I close this?") and Claude answers with a fresh list of things still
# open, send the reply back once. It backs "Close the loop" in Palmface's CLAUDE.md: the
# answer to "are we done?" is yes, or one AskUserQuestion that finishes it.
#
# Usage, from settings.json:
#   closing-drip.sh prompt   (UserPromptSubmit) notes whether this prompt is a closing question
#   closing-drip.sh stop     (Stop) checks the reply to that prompt
#
# State: one small flag per session in ~/.claude/palmface/state/closing-drip/, removed once the
# reply is checked (flags older than a day are swept). The Stop side blocks by exiting 2 with a
# note on stderr, never twice in a row (stop_hook_active). It stays quiet when Claude already
# used AskUserQuestion in the turn, and on autopilot or unattended runs, where nobody can answer.
#
# Off switches:
#   PALMFACE_HOOKS=off      every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_CLOSING=off    just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_CLOSING:-on}" && exit 0

dir="$KH_STATE/closing-drip"
flag="$dir/$(kh_session)"

case "${1:-}" in
  prompt)
    prompt=$(kh_get prompt | tail -c 600)
    if printf '%s\n' "$prompt" | /usr/bin/grep -Eiq \
      -e "\b(are|r) we (done|finished)\b" \
      -e "\bare we (good|there)( here| now)?[[:space:]]*\?" \
      -e "\bwe('re| are) (done|finished)\b" \
      -e "\b(done|finished) here\b" \
      -e "\bcan (i|we) (close|wrap|finish|stop|end) (this|it|up|here|now|the session)\b" \
      -e "\b(is that|that's) (it|all|everything)[[:space:]]*\?" \
      -e "\b(anything|what's|what is) (else )?(left|remaining|missing|outstanding)\b[^.]*\?" \
      -e "\b(shall|should|can|let's) (we )?wrap (this |it |things )?up\b" \
      -e "\b(all )?(done|finished)[[:space:]]*\?[[:space:]]*$" \
      -e "\bready to (close|ship|wrap|merge)\b[^.]*\?"; then
      d=$(kh_state_dir closing-drip) || exit 0
      find "$d" -type f -mtime +1 -delete 2> /dev/null
      date +%s > "$flag" 2> /dev/null
    else
      rm -f "$flag" 2> /dev/null
    fi
    exit 0
    ;;
  stop) ;;
  *) exit 0 ;;
esac

[ -f "$flag" ] || exit 0
rm -f "$flag" 2> /dev/null
[ "$(kh_get stop_hook_active)" = true ] && exit 0
kh_unattended && exit 0
kh_asked && exit 0

msg=$(kh_reply)
[ -n "$msg" ] || exit 0

# Does the reply hand work back? It must say so twice: two different hand-back phrases
# ("still open", "on your side"), or one plus a weaker sign (a "next steps" list, or a count of
# things still open). Words that only describe finished work ("three things shipped", "the
# remaining work is done") never count. A negation earlier in the same sentence ("nothing is
# left for you to do") cancels a phrase.
verdict=$(printf '%s\n' "$msg" | kh_prose | tr '[:upper:]' '[:lower:]' | /usr/bin/awk '
  function found(re,    s, off, start, from, before) {
    s = t; off = 0
    while (match(s, "(^|[^a-z])" re "([^a-z]|$)")) {
      start = off + RSTART
      from = start - 60; if (from < 1) from = 1
      before = substr(t, from, start - from)
      sub(/.*[.;:!?]/, "", before) # only the same sentence can negate
      if (before !~ neg) { hit = substr(t, start, RLENGTH); return 1 }
      off += RSTART + RLENGTH - 1; s = substr(s, RSTART + RLENGTH)
    }
    return 0
  }
  { t = t " " $0 }
  END {
    neg = "(^|[^a-z])(nothing|none|no|not|never|without)([^a-z]|$)|n\047t([^a-z]|$)"
    n = split("on your (side|plate|end);waiting on you;you(\047ll| will)? (still )?need to;for you to (do|decide|check|review|run|handle|test|confirm);left (for you|to do);(requires|needs) your (call|decision|input|sign-off|review|approval);still (open|outstanding|to do|left|pending);open (items|loops|questions);before (we|you) (can )?(close|wrap|call it)", strong, ";")
    for (i = 1; i <= n; i++) if (found(strong[i])) { hits++; if (first == "") first = hit }
    weak = found("next steps?") || found("(remaining|outstanding) (items|work|tasks|steps)")
    count = (t ~ /(^|[^a-z])(two|three|four|five|six|[2-9]) (more )?(things|items|steps|tasks|loose ends|questions) (are |is )?(still )?(open|left|remaining|outstanding|pending|to do|to go|for you)/ ||
             t ~ /(^|[^a-z])(two|three|four|five|six|[2-9]) (open|outstanding|remaining|pending) (things|items|steps|tasks|questions|loose ends)/)
    if (hits >= 2 || (hits >= 1 && (weak || count))) { gsub(/^[^a-z]+|[^a-z]+$/, "", first); print first }
  }')
[ -n "$verdict" ] || exit 0

# printf, not a here-document: bash writes those to a temp file, outside Palmface's folders.
printf '%s\n' "Palmface (close the loop): the user asked whether the work is finished, and this reply hands" \
  "open work back to them (it says: $verdict). Do the loose ends you can do yourself now. Put what" \
  "truly needs the user into one AskUserQuestion (up to 4 questions). Mention things waiting on" \
  "other people once, as status. Safety facts stay in (unpushed work, a failing build, something" \
  "broken in production): say each once. Then answer plainly: done, or that one question." >&2
exit 2

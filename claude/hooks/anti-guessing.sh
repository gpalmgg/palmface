#!/bin/bash
# Palmface hook (Stop): catch the two ways an open question slips past the user, and send the
# reply back once. It backs "Ask with the tool" in Palmface's CLAUDE.md.
#   1. The reply ends by asking the user something in prose ("Want me to…?", "Should I…?",
#      "Let me know which you prefer"). A question in a paragraph is easy to miss; the
#      AskUserQuestion tool is not.
#   2. The reply states a guess as settled ("I've assumed…", "I'm assuming you…"). A guess the
#      user could have answered is a question that wasn't asked.
#
# Blocks by exiting 2 with a note on stderr, never twice in a row (stop_hook_active). Stays
# quiet when Claude used AskUserQuestion in the turn, and on autopilot or unattended runs, where
# nobody can answer (see ~/.claude/palmface/references/autopilot.md). Code, "quoted" text and
# > blockquotes don't count. Writes nothing.
#
# Off switches:
#   PALMFACE_HOOKS=off       every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_GUESSING=off    just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_GUESSING:-on}" && exit 0
[ "$(kh_get stop_hook_active)" = true ] && exit 0
kh_unattended && exit 0

msg=$(kh_reply)
[ -n "$msg" ] || exit 0
text=$(printf '%s\n' "$msg" | kh_prose)
kh_asked && exit 0

# 1. The last paragraph puts a question to the user.
last=$(printf '%s\n' "$text" | /usr/bin/awk '
  NF { if (blank) { p = ""; blank = 0 } p = (p == "" ? $0 : p " " $0); next }
  { blank = 1 }
  END { print p }')
asked=$(printf '%s\n' "$last" | /usr/bin/grep -Eio \
  -e "\b(should|shall|can|may) i\b[^?]*\?" \
  -e "\b(do|would) you (want|like|prefer)\b[^?]*\?" \
  -e "\bwant me to\b[^?]*\?" \
  -e "\bwhich (one|option|approach|of these|would you|do you)\b[^?]*\?" \
  -e "\b(would you rather|do you prefer)\b[^?]*\?" \
  -e "\blet me know (which|whether|what you('d)? (prefer|want|think)|how you('d)? like)\b[^.?!]*" \
  -e "\b(sound good|ok with you|okay with you|does that work for you)[[:space:]]*\?" \
  -e "\bor (would you|should i|do you)\b[^.?!]*\??" |
  head -1 | cut -c1-120)
# printf, not here-documents: bash writes those to a temp file, outside Palmface's folders.
if [ -n "$asked" ]; then
  printf '%s\n' "Palmface (ask with the tool): this reply ends by asking the user something in prose (it says:" \
    "$asked). If the answer would change what you do, ask it with AskUserQuestion, recommended" \
    "option first. If it was only an offer, drop it and say what you will do next." >&2
  exit 2
fi

# 2. A guess stated as settled.
guess=$(printf '%s\n' "$text" | /usr/bin/grep -Eio \
  -e "\bi('ve| have)? assumed\b[^.]*" \
  -e "\bi('m| am) assuming\b[^.]*" \
  -e "\bi('ve| have)? guessed\b[^.]*" \
  -e "\byou (probably|likely) (want|mean|meant)\b[^.]*" |
  head -1 | cut -c1-120)
if [ -n "$guess" ]; then
  printf '%s\n' "Palmface (ask with the tool): this reply rests on a guess (it says: $guess). If you can check" \
    "it (a file, the repo, memory), check it. If only the user knows, ask with AskUserQuestion" \
    "before building on it. If it doesn't change the work, drop the caveat." >&2
  exit 2
fi
exit 0

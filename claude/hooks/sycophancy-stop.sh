#!/bin/bash
# Palmface hook (Stop): when Claude's reply leans on agreement or praise instead of substance
# ("you're absolutely right", "great question", "totally doable"), send it back once with a
# note to rewrite. It backs "Hold your ground" in Palmface's CLAUDE.md.
#
# Blocks by exiting 2 with the note on stderr; Claude Code shows the note to Claude, which
# continues. It never blocks twice in a row (stop_hook_active), so it can't loop. Words in code,
# in "quotes" and in > blockquotes don't count, so Claude can still talk about these phrases.
# Writes nothing.
#
# Off switches:
#   PALMFACE_HOOKS=off        every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_SYCOPHANCY=off   just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_SYCOPHANCY:-on}" && exit 0
[ "$(kh_get stop_hook_active)" = true ] && exit 0

msg=$(kh_reply)
[ -n "$msg" ] || exit 0
text=$(printf '%s\n' "$msg" | kh_prose)

# Hollow agreement, feasibility hype, and praise in place of an answer.
hit=$(printf '%s\n' "$text" | /usr/bin/grep -Eio \
  -e "\byou('re| are) (absolutely|totally|completely|entirely|so|100%) right\b" \
  -e "\byou('re| are) right,? (i'm |i am )?sorry\b" \
  -e "\b(what a |that's a |such a )?(great|excellent|fantastic|brilliant|wonderful|amazing) (question|point|observation|insight|catch)\b" \
  -e "\bcouldn't agree more\b" \
  -e "\bi (completely|totally|fully|wholeheartedly) agree\b" -e "\b100% agree\b" \
  -e "\byou (nailed|crushed) it\b" \
  -e "\b(that's|you're|is|was) spot on\b" \
  -e "\b(totally|completely|absolutely|entirely|super) (doable|feasible|achievable|realistic)\b" \
  -e "\b(this|that|it) (is|looks|sounds) (like )?(a )?(really |very )?(solid|great|excellent|perfect|brilliant|fantastic) (plan|idea|approach)\b" \
  -e "\b(i )?love (this|that|the|your) (idea|approach|plan|direction|thinking)\b" \
  -e "\bthat's (a )?(really |very |such a )?(smart|clever|elegant|brilliant|beautiful) (approach|solution|idea|design)\b" |
  head -1)

# A first line that is nothing but applause.
if [ -z "$hit" ]; then
  first=$(printf '%s\n' "$text" | /usr/bin/awk 'NF { print; exit }')
  if printf '%s\n' "$first" | /usr/bin/grep -Eiqx "[[:space:]]*(absolutely|exactly|perfect|brilliant|great|love it|love this|totally)[.!]*[[:space:]]*"; then
    hit=$(printf '%s' "$first" | tr -s ' ')
  fi
fi
[ -n "$hit" ] || exit 0

# printf, not a here-document: bash writes those to a temp file, outside Palmface's folders.
printf '%s\n' "Palmface (anti-sycophancy): this reply leans on agreement or praise instead of substance" \
  "(it says: $hit). In your next message, give the corrected version: lead with the substance. If" \
  "you agree, say specifically why. If you changed your position, name what was wrong in your" \
  "earlier reasoning; if nothing was, keep the position and say why." >&2
exit 2

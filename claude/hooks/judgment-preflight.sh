#!/bin/bash
# Palmface hook (UserPromptSubmit): when the user asks for an assessment ("is this feasible?",
# "what do you think?", "should we…?"), hand Claude a short honesty checklist for that turn.
# Silent for every other prompt. Writes nothing, never blocks. It backs "Hold your ground" in
# Palmface's CLAUDE.md: assessments are where agreeable answers do the most harm.
#
# Off switches:
#   PALMFACE_HOOKS=off       every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_PREFLIGHT=off   just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }
kh_read
kh_off "${PALMFACE_PREFLIGHT:-on}" && exit 0

prompt=$(kh_get prompt)
[ "${#prompt}" -ge 10 ] || exit 0

# Four kinds of asking for a judgement: feasibility, opinion, validation, a choice to make.
if printf '%s\n' "$prompt" | /usr/bin/grep -Eiq \
  -e "\b(is|are|would|will) (this|that|it|these|those)( (really|even|actually))? (feasible|realistic|doable|achievable|viable|worth it)\b" \
  -e "\bhow (hard|difficult|realistic|risky|feasible) (is|would|will)\b" \
  -e "\b(feasibility|viability)\b" \
  -e "\bwhat do you (think|reckon|make of)\b" \
  -e "\byour (honest )?(take|opinion|assessment|view|read|thoughts)\b" \
  -e "\bhow does (this|that|it) (look|sound|seem)\b" \
  -e "\bdoes (this|that|it) (make sense|hold up|check out)\b" \
  -e "\bis (this|that|it) a (good|bad|solid|sound|smart|reasonable) (idea|plan|approach|move|call)\b" \
  -e "\bam i (missing something|overthinking|wrong|on the right track)\b" \
  -e "\b(sanity|gut|reality) check\b" \
  -e "\b(honest take|be honest)\b" \
  -e "\bshould (i|we)\b" \
  -e "\bwhich (approach|option|path|direction|way) (is|would|should)\b" \
  -e "\bworth (it|doing|building|pursuing|the effort)\b" \
  -e "\bpros and cons\b"; then
  # printf, not a here-document: bash writes those to a temp file, outside Palmface's folders.
  printf '%s\n' "Palmface: the user is asking for an assessment. Before you answer, name your assumptions and" \
    "what you don't know, give the strongest case against, back any \"this will work\" with specific" \
    "evidence, and lead with the risks. \"I don't know enough to say\" is an acceptable answer."
fi
exit 0

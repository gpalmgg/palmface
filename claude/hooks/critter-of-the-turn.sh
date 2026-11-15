#!/bin/bash
# Palmface hook (UserPromptSubmit): hand Claude one critter from Palmface's bank each turn, so
# the art in replies varies. Owls from 19:00 to 07:00, cats by day, the same rule as `hello` in
# the terminal. What this prints on stdout, Claude Code adds to the turn's context.
#
# The bank is ~/.claude/palmface/critters.txt, plus your own ~/.claude/palmface-local/critters.txt
# (same format, described at the top of the bank; Palmface never writes your file, and uninstall
# leaves it). Writes nothing. With no bank, or an empty one, prints nothing.
#
# Off switches:
#   PALMFACE_HOOKS=off      every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_CRITTERS=off   just this one

[ -t 0 ] || cat > /dev/null # read the hook's JSON so Claude Code never sees a broken pipe
[ "${PALMFACE_HOOKS:-on}" = off ] && exit 0
[ "${PALMFACE_CRITTERS:-on}" = off ] && exit 0

set --
for f in "$HOME/.claude/palmface/critters.txt" "$HOME/.claude/palmface-local/critters.txt"; do
  if [ -r "$f" ]; then set -- "$@" "$f"; fi
done
[ $# -gt 0 ] || exit 0

hour=$(date +%H)
hour=${hour#0}
if [ "${hour:-0}" -ge 19 ] || [ "${hour:-0}" -lt 7 ]; then kind='owl'; else kind='cat'; fi

# Records: a line "@ <kind> <name>", then the art, ended by a blank line (Windows line endings
# are fine). Picks one of the wanted kind at random (any kind if the bank has none of it).
# Prints the label, then the art.
pick=$(/usr/bin/awk -v kind="$kind" -v r="$RANDOM" '
  { sub(/\r$/, "") }     # CRLF files read the same as LF files
  FNR == 1 { inrec = 0 } # a record never runs on into the next file
  /^@ / { n++; k[n] = $2; nm[n] = $0; sub(/^@ [^ ]+ */, "", nm[n]); a[n] = ""; inrec = 1; next }
  inrec && /^[[:space:]]*$/ { inrec = 0; next }
  inrec { a[n] = (a[n] == "" ? $0 : a[n] "\n" $0) }
  END {
    for (i = 1; i <= n; i++) if (k[i] == kind && a[i] != "") s[++m] = i
    if (m == 0) for (i = 1; i <= n; i++) if (a[i] != "") s[++m] = i
    if (m == 0) exit 1
    i = s[r % m + 1]
    print k[i] (nm[i] == "" ? "" : " · " nm[i])
    print a[i]
  }' "$@" 2> /dev/null) || exit 0
[ -n "$pick" ] || exit 0

label=${pick%%$'\n'*}
art=${pick#*$'\n'}
printf 'Critter for this reply (%s). Include it in a code block if the reply has room:\n%s\n' "$label" "$art"
exit 0

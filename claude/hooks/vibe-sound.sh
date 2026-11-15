#!/bin/bash
# Palmface hook: a soft macOS system sound when Claude Code finishes a turn or needs you.
#   Stop          -> Glass   (the turn is done)
#   Notification  -> Tink    (waiting for a permission or for you)
# Usage, from settings.json:  vibe-sound.sh stop | notification
#
# Only macOS's own sounds in /System/Library/Sounds are played. Writes nothing, never blocks:
# the sound plays in the background and the hook exits 0 at once.
#
# Off switches:
#   PALMFACE_HOOKS=off               every Palmface hook (set it in the "env" block of
#                                    ~/.claude/settings.json, or in your shell)
#   PALMFACE_SOUNDS=off              just the sounds
#   touch ~/.claude/palmface/sounds.off   mute now, no restart (delete the file to unmute)
# Unattended runs (claude -p, chained sessions) read the same settings, so each run chimes once
# when it stops. For a quiet batch, run it with PALMFACE_SOUNDS=off or touch the file above.

[ -t 0 ] || cat > /dev/null # read the hook's JSON so Claude Code never sees a broken pipe
[ "${PALMFACE_HOOKS:-on}" = off ] && exit 0
[ "${PALMFACE_SOUNDS:-on}" = off ] && exit 0
[ -e "$HOME/.claude/palmface/sounds.off" ] && exit 0

case "${1:-}" in
  stop) sound=Glass ;;
  notification) sound=Tink ;;
  *) exit 0 ;;
esac
file="/System/Library/Sounds/$sound.aiff"
[ -f "$file" ] || exit 0
command -v afplay > /dev/null 2>&1 || exit 0

(afplay -v 0.35 "$file" > /dev/null 2>&1 < /dev/null &)
exit 0

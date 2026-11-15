#!/bin/bash
# autopilot.sh: turn Palmface's autopilot on or off for one project folder.
#
# Usage: autopilot.sh on|off|status [project-folder]
#
# The project folder defaults to the current directory. The switch lives outside the project, at
# ~/.claude/palmface/state/autopilot/<sha256 of the folder's physical path>, and it is the only
# thing this script writes. Nothing inside the project switches autopilot: a .autopilot/on file
# there (say, one that came with a cloned repository) is ignored. "off" removes the switch and
# leaves the run's record in the project (.autopilot/decisions.md, .autopilot/queue.md).
# Palmface's question hooks check the same switch: see ~/.claude/palmface/references/autopilot.md.
set -u
export LC_ALL=C
umask 077

usage() { printf 'usage: autopilot.sh on|off|status [project-folder]\n'; }

action=${1:-status}
case "$action" in
  on | off | status) ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ $# -le 2 ] || { usage >&2; exit 2; }

dir=${2:-$PWD}
if ! dir=$(cd "$dir" 2> /dev/null && pwd -P); then
  printf 'autopilot: no such folder: %s\n' "${2:-$PWD}" >&2
  exit 2
fi
if [ "$dir" = / ]; then
  printf 'autopilot: refusing to switch autopilot at the filesystem root\n' >&2
  exit 2
fi

[ -n "${HOME:-}" ] && [ "$HOME" != / ] && [ -d "$HOME" ] || { printf 'autopilot: HOME is not a usable folder\n' >&2; exit 2; }
ap="$dir/.autopilot" # the run's record (decisions, queue); never the switch
states="$HOME/.claude/palmface/state/autopilot"
# Same path as kh_autopilot_switch in ~/.claude/palmface/hooks/lib.sh and start.sh.
switch="$states/$(printf '%s' "$dir" | /usr/bin/shasum -a 256 | cut -c1-64)"

lines() { # file, pattern: matching lines, 0 when the file is missing
  if [ -f "$1" ]; then grep -c -E "$2" "$1" 2> /dev/null || true; else echo 0; fi
}

case "$action" in
  on)
    if [ -L "$states" ] || [ -L "$switch" ]; then
      printf 'autopilot: %s is a symlink; not writing through it\n' "$states" >&2
      exit 1
    fi
    mkdir -p "$states" || exit 1
    chmod 700 "$states" 2> /dev/null
    if [ ! -f "$switch" ]; then
      printf 'on since %s\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "$dir" > "$switch" || exit 1
    fi
    printf 'autopilot: on for %s\n' "$dir"
    ;;
  off)
    if [ -L "$switch" ]; then
      printf 'autopilot: %s is a symlink; not touching it\n' "$switch" >&2
      exit 1
    fi
    rm -f "$switch"
    printf 'autopilot: off for %s\n' "$dir"
    ;;
  status)
    state=off
    [ -f "$switch" ] && [ ! -L "$switch" ] && state=on
    printf 'autopilot: %s for %s\n' "$state" "$dir"
    if [ "${PALMFACE_AUTOPILOT:-}" = on ]; then
      printf '  PALMFACE_AUTOPILOT=on: on for this session whatever the folder says\n'
    fi
    if [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 0 ]; then
      printf '  this session is marked unattended: the question hooks stay quiet\n'
    fi
    if [ -e "$ap/on" ]; then
      printf '  %s/on is ignored: only autopilot.sh on switches autopilot\n' "$ap"
    fi
    printf '  decisions logged: %s  queued for you: %s\n' \
      "$(lines "$ap/decisions.md" '^[[:space:]]*[-*0-9|]')" "$(lines "$ap/queue.md" '^[[:space:]]*[-*] ')"
    [ -f "$dir/OUTBOX.md" ] && printf '  OUTBOX.md: held sends are waiting\n'
    [ -f "$dir/REVIEW.md" ] && printf '  REVIEW.md: there is a closing summary\n'
    ;;
esac
exit 0

#!/bin/bash
# start.sh: the greeting and status card for Palmface's start command.
#
# Usage: start.sh [--plain] [project-folder]
#
# Prints a banner (figlet, through lolcat when installed), a cow greeting when Palmface's cows are
# installed, a status card for the project folder (git, autopilot, handoffs, the review queue) and
# a suggested session name. --plain skips the banner and the cow. Reads only; writes nothing.
set -u
export LC_ALL=C

plain=0
dir=$PWD
for a in "$@"; do
  case "$a" in
    --plain) plain=1 ;;
    -h | --help) printf 'usage: start.sh [--plain] [project-folder]\n'; exit 0 ;;
    -*) printf 'usage: start.sh [--plain] [project-folder]\n' >&2; exit 2 ;;
    *) dir=$a ;;
  esac
done
if ! dir=$(cd "$dir" 2> /dev/null && pwd -P); then
  printf 'start: no such folder: %s\n' "$dir" >&2
  exit 2
fi
name=$(basename "$dir")
[ "$dir" = / ] && name=root
have() { command -v "$1" > /dev/null 2>&1; }
# shellcheck disable=SC2088 # the tilde is printed, not expanded
show_path() { # a path with the home folder written as ~
  case "$1" in "$HOME") printf '~' ;; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac
}

# ── greeting ────────────────────────────────────────────────────────────────────────────────
hour=$((10#$(date +%H)))
if [ "$plain" -eq 0 ]; then
  if have figlet; then
    if have lolcat; then figlet -f small "$name" 2> /dev/null | lolcat -f 2> /dev/null; else figlet -f small "$name" 2> /dev/null; fi
  fi
  cow="cat"
  if [ "$hour" -ge 20 ] || [ "$hour" -lt 6 ]; then cow="owl"; fi
  cowfile="$HOME/.config/palmface/cows/$cow.cow"
  if have cowsay && [ -f "$cowfile" ]; then
    lines=("Small fires first. The big ones catch from them."
      "One clear step, then the next."
      "Write it down: the session forgets, the files don't."
      "Check the work before you call it done."
      "Ask early. Rebuilding costs more than asking."
      "A plan is a draft until it survives a fresh pair of eyes."
      "Leave the place tidier than you found it."
      "Good morning, good evening, good whatever-time-it-is.")
    day=$((10#$(date +%j)))
    cowsay -f "$cowfile" "${lines[$((day % ${#lines[@]}))]}" 2> /dev/null
  fi
fi

# ── status card ─────────────────────────────────────────────────────────────────────────────
row() { # label, value; control characters are dropped (commit subjects and file names come from the repo)
  printf '│ %-10s %s\n' "$1" "$(printf '%s' "$2" | tr -d '\000-\037\177')"
}
printf '╭─ %s\n' "$name"
row folder "$(show_path "$dir")"

git_ok=0
if have git; then
  g=$(command -v git)
  if [ "$g" != /usr/bin/git ] || xcode-select -p > /dev/null 2>&1; then git_ok=1; fi # the bare stub pops an installer
fi
if [ "$git_ok" -eq 1 ] && git -C "$dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  G() { git --no-optional-locks -c core.fsmonitor=false -C "$dir" "$@" 2> /dev/null; }
  branch=$(G symbolic-ref --short -q HEAD || G rev-parse --short HEAD)
  changed=$(G status --porcelain | wc -l | tr -d ' ')
  last=$(G log -1 --format='%s (%cr)')
  ahead=$(G rev-list --count '@{upstream}..HEAD')
  info="${branch:-?} · ${changed:-0} changed"
  [ -n "$ahead" ] && [ "$ahead" != 0 ] && info="$info · $ahead not pushed"
  row git "$info"
  [ -n "$last" ] && row last "$(printf '%s' "$last" | cut -c1-70)"
else
  row git "not a git repository"
fi

ap=off
# The user's switch lives outside the project (same path as autopilot.sh and the hooks' lib.sh);
# a .autopilot/on file inside the folder is ignored.
sw="$HOME/.claude/palmface/state/autopilot/$(printf '%s' "$dir" | /usr/bin/shasum -a 256 | cut -c1-64)"
[ -f "$sw" ] && [ ! -L "$sw" ] && ap="on (this folder)"
[ "${PALMFACE_AUTOPILOT:-}" = on ] && ap="on (PALMFACE_AUTOPILOT)"
row autopilot "$ap"
if [ -f "$dir/.autopilot/queue.md" ]; then
  q=$(grep -c -E '^[[:space:]]*[-*] ' "$dir/.autopilot/queue.md" 2> /dev/null || true)
  [ "${q:-0}" != 0 ] && row queue "$q waiting for you in .autopilot/queue.md"
fi
[ -f "$dir/REVIEW.md" ] && row review "REVIEW.md"
[ -f "$dir/OUTBOX.md" ] && row outbox "OUTBOX.md (held sends)"

if [ "$dir" != "$HOME" ] && [ "$dir" != / ]; then
  newest=$(cd "$dir" && find . -maxdepth 4 \( -name node_modules -o -name .git -o -name Library \) -prune -o \
    -type f -name '*handoff*.md' -mtime -7 -print 2> /dev/null | while IFS= read -r f; do
    printf '%s %s\n' "$(stat -f %m "$f" 2> /dev/null || echo 0)" "$f"
  done | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$newest" ] && row handoff "${newest#./}"
fi
row time "$(date '+%a %d %b %H:%M')"

# kit skills that are installed, by stage
panel() { # label, skill names...: one row with the installed ones
  local label=$1 s out=""
  shift
  for s in "$@"; do
    [ -f "$HOME/.claude/skills/palmface-$s/SKILL.md" ] && out="$out /palmface-$s"
  done
  [ -n "$out" ] && row "$label" "${out# }"
}
panel shape seedbed intake deep-plan metaplan
panel challenge stress-test heartwood premortem canopy honest-take
panel make build qc prove look
panel session start status save sessions chain listen retro autopilot
printf '╰─\n'

slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
printf 'session name: %s-%s\n' "${slug:-session}" "$(date '+%b%d' | tr '[:upper:]' '[:lower:]')"
exit 0

#!/bin/bash
# Palmface screensaver. tmux runs it as its lock-command after 30 minutes without a key, and
# vibes.zsh runs it after 10 idle minutes at a bare zsh prompt. Any key returns.
#
# It plays a random toy if one is installed (cbonsai, pipes.sh, cmatrix: see the Brewfile's
# optional section); otherwise a built-in field of drifting stars in Rosé Pine colours.
#
# The built-in stars stop by themselves after 15 minutes, so idle tabs don't animate all night.
#
# Pause:           mkdir -p ~/.cache/palmface && touch ~/.cache/palmface/screensaver.off
# Resume:          rm ~/.cache/palmface/screensaver.off
# Off in a shell:  export PALMFACE_SCREENSAVER=off
# (A per-user path: a shared /tmp would let another user of the Mac plant or point that file.)
set -u

[ -e "${HOME:-/nonexistent}/.cache/palmface/screensaver.off" ] && exit 0
[ "${PALMFACE_SCREENSAVER:-on}" = off ] && exit 0
if [ ! -t 0 ] || [ ! -t 1 ]; then exit 0; fi

have() { command -v "$1" > /dev/null 2>&1; }

toys=()
if have cbonsai; then toys+=("cbonsai -S -L 40 -t 0.04 -w 6"); fi
if have pipes.sh; then toys+=("pipes.sh -t 3 -R -r 4000"); fi
if have cmatrix; then toys+=("cmatrix -s -C magenta -b"); fi

if [ "${#toys[@]}" -gt 0 ] && [ "${PALMFACE_SCREENSAVER:-on}" != stars ]; then
  pick=${toys[$((RANDOM % ${#toys[@]}))]}
  # shellcheck disable=SC2086  # split on purpose: the toy and its flags
  $pick
  exit 0
fi

# ── Built-in: stars appear, twinkle and fade, on the alternate screen (your scrollback stays).
# bash 3.2 has no fractional read timeout, so keys are polled with stty min 0 time 1 + dd.
old_stty=$(stty -g)
restore() { stty "$old_stty"; printf '\033[0m\033[?25h\033[?1049l'; }
trap 'restore; exit 0' EXIT INT TERM HUP
stty -echo -icanon min 0 time 1
printf '\033[?1049h\033[?25l\033[2J'

size=$(stty size 2> /dev/null) # "rows cols", read from the terminal on stdin
rows=${size% *}
cols=${size#* }
case "$rows$cols" in '' | *[!0-9]*) rows=24 cols=80 ;; esac
glyphs=("·" "·" "✦" "*" "+" "." "˚")
colours=("35" "36" "33" "34" "90" "90") # iris, rose, gold, foam, muted (the terminal's own palette)
keep=$((rows * cols / 45))              # how many stars are lit at once
[ "$keep" -lt 12 ] && keep=12
sr=()
sc=()
n=0
ticks=$((15 * 60 * 10)) # about 15 minutes at 10 ticks a second
while [ "$ticks" -gt 0 ]; do
  ticks=$((ticks - 1))
  for _ in 1 2 3; do
    slot=$((n % keep))
    if [ "$n" -ge "$keep" ]; then printf '\033[%d;%dH ' "${sr[$slot]}" "${sc[$slot]}"; fi
    sr[slot]=$((RANDOM % rows + 1))
    sc[slot]=$((RANDOM % cols + 1))
    printf '\033[%d;%dH\033[%sm%s\033[0m' "${sr[$slot]}" "${sc[$slot]}" \
      "${colours[$((RANDOM % ${#colours[@]}))]}" "${glyphs[$((RANDOM % ${#glyphs[@]}))]}"
    n=$((n + 1))
  done
  # dd returns after 0.1 s with nothing, or with the key. The x keeps Enter from being stripped.
  key=$(dd bs=1 count=1 2> /dev/null; echo x)
  [ "$key" != x ] && break
done
# Swallow the rest of a multi-byte key (an arrow is ESC [ A), so it can't land in your prompt.
while [ "$(dd bs=64 count=1 2> /dev/null; echo x)" != x ]; do :; done

#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2088  # check() conditions are eval'd later; descriptions name ~ paths
# smoke-terminal.sh: install the terminal (and extras) layers into fake homes, then use them the
# way a stranger's Mac would: zsh starts clean with and without the brew tools, and Ghostty,
# starship, tmux, git and tmuxinator accept the installed config. Never touches the real home
# (see tests/lib.sh) and never uses the network: the tmux plugin clones come from local repos.
#
# Usage: tests/smoke-terminal.sh
#
# Tools that are not installed are skipped with a note, so this runs on a bare Mac too.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

WORK=$(mktemp -d "$TMP_ROOT/palmface-smoke.XXXXXX")
TSOCK=$(mktemp -u /tmp/palmface-tmux.XXXXXX) # short: a unix socket path must fit in 104 bytes
trap 'rm -rf "$WORK"; rm -f "$TSOCK"' EXIT
ERR="$WORK/stderr"
BARE=/usr/bin:/bin
BREW_BIN=""
for d in /opt/homebrew/bin /usr/local/bin; do
  if [ -x "$d/brew" ]; then BREW_BIN=$d; break; fi
done
FULL="${BREW_BIN:+$BREW_BIN:}$BARE"
tool() { # path of a tool from the brew bin or the bare path, or nothing
  PATH="$FULL" command -v "$1" 2> /dev/null || true
}
GHOSTTY=$(tool ghostty)
if [ -z "$GHOSTTY" ] && [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
  GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
fi
skip() { printf '  skip  %s\n' "$1"; }

zsh_in() { # fake home, PATH, command: an interactive zsh in an empty environment
  guard_home "$1"
  env -i HOME="$1" PATH="$2" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" /bin/zsh -i -c "$3" 2> "$ERR"
}
ghostty_in() { # fake home, args...: Ghostty's CLI, output to $WORK/ghostty.out
  # (Ghostty truncates a redirected stdout, so each run gets its own file.)
  local h=$1
  shift
  guard_home "$h"
  env -i HOME="$h" PATH="$BARE" "$GHOSTTY" "$@" > "$WORK/ghostty.out" 2>&1
}
TG() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=palmface-test \
  -c user.email=test@example.com -c commit.gpgsign=false "$@"; }
mkrepo() { # dir, executable file name, its body: a one-commit repo standing in for a plugin upstream
  mkdir -p "$1"
  printf '#!/bin/bash\n%s\n' "${3:-exit 0}" > "$1/$2"
  chmod 755 "$1/$2"
  TG -C "$1" -c init.defaultBranch=main init -q
  TG -C "$1" add -A
  TG -C "$1" commit -qm init
}
kit_pinned() { # dir, then "repo sha entry" lines: a copy of the kit whose plugins.list pins those
  local d=$1
  shift
  rm -rf "$d" && mkdir -p "$d"
  (cd "$KIT" && tar --exclude ./.git -cf - .) | (cd "$d" && tar -xf -)
  printf '%s\n' "# test pins" "$@" > "$d/terminal/tmux/plugins.list"
}

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "1. terminal layer, no post scripts: a shell that starts clean"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --terminal --no-post 2>&1); rc=$?
check "install --terminal --no-post exits 0" '[ $rc -eq 0 ]' "$out"

out=$(zsh_in "$H" "$BARE" 'echo ok'); rc=$?
check "bare PATH: zsh -i prints only ok" '[ $rc -eq 0 ] && [ "$out" = ok ]' "$out"
check "bare PATH: zsh -i writes nothing to stderr" '[ ! -s "$ERR" ]' "$(cat "$ERR")"
out=$(zsh_in "$H" "$BARE" 'whence -w hello owl meow nap | tr "\n" " "')
check "vibes.zsh loaded: hello/owl/meow/nap are functions" '[ "$out" = "hello: function owl: function meow: function nap: function " ]' "$out"
out=$(zsh_in "$H" "$BARE" 'hello'); rc=$?
check "hello without figlet/lolcat: a critter and a line, no errors" \
  '[ $rc -eq 0 ] && [ ! -s "$ERR" ] && printf "%s" "$out" | grep -qE "o\.o|\{o,o\}"' "$out$(cat "$ERR")"
out=$(zsh_in "$H" "$BARE" 'meow hi'); rc=$?
check "meow without cowsay says so and fails softly" '[ $rc -eq 1 ] && grep -q "cowsay is not installed" "$ERR"' "$out$(cat "$ERR")"
out=$(env -i HOME="$H" PATH="$BARE" /bin/bash "$H/.config/palmface/bin/screensaver.sh" < /dev/null 2>&1); rc=$?
check "screensaver exits at once when not on a terminal" '[ $rc -eq 0 ] && [ -z "$out" ]' "$out"

if [ -n "$BREW_BIN" ]; then
  out=$(zsh_in "$H" "$FULL" 'echo ok'); rc=$?
  check "brew PATH: zsh -i prints only ok" '[ $rc -eq 0 ] && [ "$out" = ok ]' "$out"
  check "brew PATH: zsh -i writes nothing to stderr" '[ ! -s "$ERR" ]' "$(cat "$ERR")"
  out=$(zsh_in "$H" "$FULL" 'hello')
  check "brew PATH: hello runs without errors" '[ ! -s "$ERR" ] && printf "%s" "$out" | grep -qE "o\.o|\{o,o\}"' "$out$(cat "$ERR")"
  if [ -n "$(tool cowsay)" ]; then
    out=$(zsh_in "$H" "$FULL" 'print -r -- $COWPATH')
    check "COWPATH starts with Palmface's cows" '[ "${out%%:*}" = "$H/.config/palmface/cows" ]' "$out"
    out=$(zsh_in "$H" "$FULL" 'owl hoo; meow hi; nap')
    check "owl, meow and nap use Palmface's cowfiles" \
      'printf "%s" "$out" | grep -qF "{o,o}" && printf "%s" "$out" | grep -qF "o.o" && printf "%s" "$out" | grep -qF -e "( -.- )"' "$out$(cat "$ERR")"
  else skip "cowsay not installed"; fi
  if [ -n "$(tool starship)" ]; then
    out=$(zsh_in "$H" "$FULL" 'print -r -- $STARSHIP_CONFIG')
    check "STARSHIP_CONFIG points at Palmface's starship.toml" '[ "$out" = "$H/.config/palmface/starship.toml" ]' "$out"
    env -i HOME="$H" PATH="$FULL" STARSHIP_CONFIG="$H/.config/palmface/starship.toml" STARSHIP_CACHE="$WORK/starship-cache" starship print-config > /dev/null 2> "$ERR"; rc=$?
    check "starship print-config accepts starship.toml" '[ $rc -eq 0 ] && [ ! -s "$ERR" ]' "$(cat "$ERR")"
  else skip "starship not installed"; fi
else skip "no Homebrew: the brew-PATH shell checks"; fi

# A real terminal (a pty from script(1)): the greeting fires once, the zle plugins load, and
# sourcing ~/.zshrc again (a common habit) stays quiet.
T="$WORK/tty.log"
guard_home "$H"
env -i HOME="$H" PATH="$FULL" TERM=xterm-256color COLUMNS=100 STARSHIP_CACHE="$WORK/starship-cache" /usr/bin/script -q "$T" /bin/zsh -i -c \
  'source ~/.zshrc; source ~/.zshrc
   print -r -- "zle=$options[zle] greeted=$PALMFACE_GREETED"
   print -r -- "as=$+functions[_zsh_autosuggest_start] hl=$+functions[_zsh_highlight] fzf=$+functions[fzf-history-widget]"
   print -r -- "ss=$+functions[TRAPALRM]:$TMOUT:$(( TTYIDLE >= 0 )):$(( EPOCHSECONDS > 0 ))"
   echo ok' < /dev/null > /dev/null 2>&1; rc=$?
LC_ALL=C sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$T" | tr -d '\r' > "$T.txt"
greets=$(grep -cE '^ *(\{o,o\}|\( o\.o \)) *$' "$T.txt")
check "in a terminal: zsh starts with zle on and greets exactly once (re-sourced twice)" \
  '[ $rc -eq 0 ] && grep -qx "zle=on greeted=1" "$T.txt" && grep -qx ok "$T.txt" && [ "$greets" = 1 ]' "greets=$greets$(printf "\n"; cat "$T.txt")"
# Real error shapes only (a greeting line may well contain the word "error").
check "in a terminal: no errors from any integration" \
  '! grep -iqE "zsh: |command not found|parse error|bad (option|pattern|substitution)|no such file|can.t change option|unknown (option|theme)|warning: |\(eval\):" "$T.txt"' "$(cat "$T.txt")"
check "in a terminal: the idle screensaver is armed (trap, 2-min check, TTYIDLE, clock)" \
  'grep -qx "ss=1:120:1:1" "$T.txt"' "$(grep "^ss=" "$T.txt")"
want_as=0 want_hl=0 want_fzf=0
for d in /opt/homebrew /usr/local; do
  [ -r "$d/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && want_as=1
  [ -r "$d/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && want_hl=1
done
[ -n "$(tool fzf)" ] && want_fzf=1
check "in a terminal: fzf bindings and the installed zsh plugins load" \
  'grep -qx "as=$want_as hl=$want_hl fzf=$want_fzf" "$T.txt"' "want as=$want_as hl=$want_hl fzf=$want_fzf; got $(grep "^as=" "$T.txt")"

GITC() { env -i HOME="$H" PATH="$BARE" GIT_CONFIG_NOSYSTEM=1 git "$@"; } # --includes: follow [include]
out=$(git config -f "$H/.config/palmface/git/delta.gitconfig" --list 2>&1); rc=$?
check "delta.gitconfig parses" '[ $rc -eq 0 ]' "$out"
pager=$(GITC config --includes --global --get core.pager)
check "~/.gitconfig includes the delta stanza" 'case "$pager" in *delta*) true ;; *) false ;; esac' "$pager"
out=$(printf 'one\ntwo\n' | env -i PATH="$BARE" sh -c "$pager" 2>&1)
check "without delta, git's pager falls back to less" '[ "$out" = "$(printf "one\ntwo")" ]' "$out"
filter=$(GITC config --includes --global --get interactive.diffFilter)
out=$(printf 'one\n' | env -i PATH="$BARE" sh -c "$filter" 2>&1)
check "without delta, git add -p's filter falls back to cat" '[ "$out" = one ]' "$out"
if [ -n "$(tool delta)" ]; then
  DG() { env -i HOME="$H" PATH="$FULL" GIT_CONFIG_NOSYSTEM=1 "$@"; } # delta reads ~/.gitconfig
  printf 'diff --git a/x.sh b/x.sh\n--- a/x.sh\n+++ b/x.sh\n@@ -1 +1 @@\n-echo old\n+echo new\n' |
    DG sh -c "$pager" > "$WORK/delta.out" 2> "$ERR"; rc=$?
  LC_ALL=C sed 's/\x1b\[[0-9;]*m//g' "$WORK/delta.out" > "$WORK/delta.txt"
  check "with delta, git's pager renders a real diff, no warnings" \
    '[ $rc -eq 0 ] && grep -q "echo new" "$WORK/delta.txt" && [ ! -s "$ERR" ]' "rc=$rc $(cat "$ERR" "$WORK/delta.txt")"
  out=$(DG delta --show-config 2>&1)
  check "delta reads Palmface's feature (ansi theme, line numbers, side by side)" \
    'printf "%s\n" "$out" | grep -qiE "^ *syntax-theme += ansi" && printf "%s\n" "$out" | grep -qE "^ *line-numbers += true" && printf "%s\n" "$out" | grep -qE "^ *side-by-side += true"' "$out"
  { printf '[delta]\n\tside-by-side = false\n'; cat "$H/.gitconfig"; } > "$WORK/gitconfig"
  cat "$WORK/gitconfig" > "$H/.gitconfig"
  out=$(DG delta --show-config 2>&1)
  check "your own [delta] settings win over Palmface's feature" 'printf "%s\n" "$out" | grep -qE "^ *side-by-side += false"' "$out"
else skip "delta not installed"; fi

TMUX_BIN=$(tool tmux)
if [ -n "$TMUX_BIN" ]; then
  TM() { env -i HOME="$H" PATH="$BARE" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" "$TMUX_BIN" -S "$TSOCK" "$@"; }
  TM -f /dev/null new-session -d -s smoke
  out=$(TM source-file "$H/.tmux.conf" 2>&1); rc=$?
  check "tmux sources ~/.tmux.conf (palmface block) without errors" '[ $rc -eq 0 ] && [ -z "$out" ]' "$out"
  out=$(TM show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>&1)
  check "Palmface leaves TMUX_PLUGIN_MANAGER_PATH alone (a tpm of yours keeps working)" '[ "$out" != "${out#unknown variable}" ]' "$out"
  out=$(TM show -gv prefix 2>&1)
  check "tmux prefix is C-a" '[ "$out" = C-a ]' "$out"
  out=$(TM show -gv lock-command 2>&1)
  check "tmux lock-command is Palmface's screensaver" '[ "$out" = "~/.config/palmface/bin/screensaver.sh" ]' "$out"
  n1=$(TM show -g terminal-overrides | wc -l)
  TM source-file "$H/.tmux.conf"
  n2=$(TM show -g terminal-overrides | wc -l)
  check "reloading (prefix + r) does not grow terminal-overrides" '[ "$n1" = "$n2" ]' "$n1 -> $n2"
  TM kill-server 2> /dev/null
  printf 'set -g prefix C-Space\n' > "$WORK/user.tmux.conf"
  TM -f "$WORK/user.tmux.conf" new-session -d -s smoke
  TM source-file "$H/.tmux.conf"
  out=$(TM show -gv prefix 2>&1)
  check "a prefix you chose yourself is kept" '[ "$out" = C-Space ]' "$out"
  TM kill-server 2> /dev/null
else skip "tmux not installed"; fi

if [ -n "$GHOSTTY" ]; then
  ghostty_in "$H" +validate-config --config-file="$H/.config/ghostty/config"; rc=$?
  check "ghostty +validate-config accepts the installed config" '[ $rc -eq 0 ] && [ ! -s "$WORK/ghostty.out" ]' "$(cat "$WORK/ghostty.out")"
  ghostty_in "$H" +show-config
  check "Ghostty loads Palmface's file through ~ (theme and font)" \
    'grep -a "^theme = " "$WORK/ghostty.out" | grep -q "dark:Rose Pine Moon" && grep -a "^theme = " "$WORK/ghostty.out" | grep -q "light:Rose Pine Dawn" && grep -aqx "font-family = Maple Mono" "$WORK/ghostty.out"' \
    "$(grep -aE "^(theme|font-family|config-file) " "$WORK/ghostty.out")"
  check "shell integration keeps the block cursor at the prompt (no-cursor)" \
    'grep -a "^shell-integration-features = " "$WORK/ghostty.out" | grep -q "no-cursor"' "$(grep -a "^shell-integration-features" "$WORK/ghostty.out")"
  ghostty_in "$H" +list-themes
  check "both Rose Pine themes exist in this Ghostty" \
    'grep -aq "^Rose Pine Moon " "$WORK/ghostty.out" && grep -aq "^Rose Pine Dawn " "$WORK/ghostty.out"'
  printf 'font-size = 19\n' > "$H/.config/ghostty/overrides" # not 13: show-config hides defaults
  ghostty_in "$H" +show-config
  check "~/.config/ghostty/overrides wins over Palmface's values" 'grep -aqx "font-size = 19" "$WORK/ghostty.out"' \
    "$(grep -a "^font-size" "$WORK/ghostty.out")"
else skip "Ghostty not installed"; fi
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "2. terminal + extras with post scripts (plugins cloned from local repos), then uninstall"
REPOS="$WORK/repos"
# Each stand-in plugin appends its name to a tmux option, so the load order is visible.
mkrepo "$REPOS/rose-pine/tmux" rose-pine.tmux 'tmux set -ga @palmface-test-order "rose-pine "'
mkrepo "$REPOS/tmux-plugins/tmux-resurrect" resurrect.tmux 'tmux set -ga @palmface-test-order "resurrect "'
mkrepo "$REPOS/tmux-plugins/tmux-continuum" continuum.tmux 'tmux set -ga @palmface-test-order "continuum "' 
PIN_RP=$(TG -C "$REPOS/rose-pine/tmux" rev-parse HEAD)
PIN_RS=$(TG -C "$REPOS/tmux-plugins/tmux-resurrect" rev-parse HEAD)
PIN_CT=$(TG -C "$REPOS/tmux-plugins/tmux-continuum" rev-parse HEAD)
# Upstream moves on after the pin: a second commit that a branch-head clone would pick up.
printf '#!/bin/bash\ntmux set -ga @palmface-test-order "UNPINNED "\n' > "$REPOS/rose-pine/tmux/rose-pine.tmux"
TG -C "$REPOS/rose-pine/tmux" commit -qam "moved on"
PIN_RP2=$(TG -C "$REPOS/rose-pine/tmux" rev-parse HEAD)
KITP="$WORK/kit-pinned" # the kit as published, with plugins.list pinning the stand-in repos
kit_pinned "$KITP" "rose-pine/tmux $PIN_RP rose-pine.tmux" "tmux-plugins/tmux-resurrect $PIN_RS resurrect.tmux" \
  "tmux-plugins/tmux-continuum $PIN_CT continuum.tmux"
check "the shipped plugins.list pins every plugin to a 40-character commit" \
  '[ "$(grep -vcE "^(#|$)" "$KIT/terminal/tmux/plugins.list")" = 3 ] && [ -z "$(grep -vE "^(#|$)" "$KIT/terminal/tmux/plugins.list" | grep -vE "^[a-z0-9-]+/[a-z0-9-]+ [0-9a-f]{40} [a-z.-]+$")" ]' \
  "$(cat "$KIT/terminal/tmux/plugins.list")"
H=$(new_home) || exit 2
seed_home "$H"
S0=$(snapshot "$H")
P="$H/.config/palmface/tmux/plugins"
out=$(SHELL=/bin/bash PALMFACE_GIT_BASE="file://$REPOS" kit_run "$KITP" "$H" install.sh --terminal --extras 2>&1); rc=$?
check "install --terminal --extras (posts on) exits 0" '[ $rc -eq 0 ]' "$out"
check "a bash login shell gets the zsh warning exactly once (install up front; shell-check.sh does not repeat it)" \
  '[ "$(printf "%s\n" "$out" | grep -c "your login shell is /bin/bash, not zsh")" = 1 ] && [ "$(printf "%s\n" "$out" | grep -n "not zsh" | head -1 | cut -d: -f1)" = 1 ]' "$out"
check "the three plugins are cloned into the kit folder (no tpm)" \
  '[ -d "$P/tmux/.git" ] && [ -d "$P/tmux-resurrect/.git" ] && [ -d "$P/tmux-continuum/.git" ] && [ ! -e "$P/tpm" ]' "$(ls -la "$P" 2>&1)"
check "each plugin is at its pinned commit, not the branch head that moved on" \
  '[ "$(TG -C "$P/tmux" rev-parse HEAD)" = "$PIN_RP" ] && ! grep -q UNPINNED "$P/tmux/rose-pine.tmux" && [ "$(TG -C "$P/tmux-resurrect" rev-parse HEAD)" = "$PIN_RS" ] && [ "$(TG -C "$P/tmux-continuum" rev-parse HEAD)" = "$PIN_CT" ]' \
  "$out"
check "a seeded Ghostty setting gets the 'overridden' note" \
  'printf "%s" "$out" | grep -q "overrides these settings of yours in ~/.config/ghostty/config: font-size"' "$out"
check "no half-finished clones left behind" '[ -z "$(find "$P" -maxdepth 1 -name ".*palmface-clone*")" ]'
check "nothing written to the old ~/.tmux/plugins" '[ ! -e "$H/.tmux/plugins" ]'
S1=$(snapshot "$H")
out=$(SHELL=/bin/zsh PALMFACE_GIT_BASE="file://$REPOS" kit_run "$KITP" "$H" install.sh --terminal --extras 2>&1); rc=$?
S=$(snapshot "$H")
check "second install (posts on) changes nothing and fetches nothing" \
  '[ $rc -eq 0 ] && [ "$S" = "$S1" ] && ! printf "%s" "$out" | grep -qE "fetched|cloned"' "$out$(snap_diff "$S1" "$S")"
check "a zsh login shell gets no warning, from install or shell-check.sh" '! printf "%s" "$out" | grep -q "not zsh"' "$out"
TMUX_BIN=$(tool tmux)
if [ -n "$TMUX_BIN" ]; then
  # The seeded ~/.tmux.conf is a symlink (skipped by install), so load Palmface's file directly.
  TP() { env -i HOME="$H" PATH="$(dirname "$TMUX_BIN"):$BARE" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" "$TMUX_BIN" -S "$TSOCK" "$@"; }
  TP -f "$H/.config/palmface/tmux/tmux.conf" new-session -d -s smoke
  out=$(TP show -gv @palmface-test-order 2>&1)
  check "tmux runs the plugins from the kit folder, in plugins.list order" '[ "$out" = "rose-pine resurrect continuum " ]' "$out"
  TP kill-server 2> /dev/null
  mkdir -p "$H/.tmux/plugins/tmux-resurrect" # as if your own tpm already had it
  TP -f "$H/.config/palmface/tmux/tmux.conf" new-session -d -s smoke
  out=$(TP show -gv @palmface-test-order 2>&1)
  check "a plugin your own tpm already has is not loaded twice" '[ "$out" = "rose-pine continuum " ]' "$out"
  TP kill-server 2> /dev/null
  rm -rf "$H/.tmux"
else skip "tmux not installed: plugin loading"; fi
# A new pin (a kit update): the clone at the old commit is replaced by the pinned one.
kit_pinned "$WORK/kit-pinned2" "rose-pine/tmux $PIN_RP2 rose-pine.tmux" "tmux-plugins/tmux-resurrect $PIN_RS resurrect.tmux" \
  "tmux-plugins/tmux-continuum $PIN_CT continuum.tmux"
out=$(PALMFACE_GIT_BASE="file://$REPOS" kit_run "$WORK/kit-pinned2" "$H" install.sh --terminal --extras 2>&1); rc=$?
check "a new pin replaces the clone at the old commit, and only that one" \
  '[ $rc -eq 0 ] && [ "$(TG -C "$P/tmux" rev-parse HEAD)" = "$PIN_RP2" ] && [ "$(printf "%s\n" "$out" | grep -c "^palmface: fetched ")" = 1 ] && [ -z "$(find "$P" -maxdepth 1 -name ".*palmface-*")" ]' "$out"
out=$(PALMFACE_GIT_BASE="file://$REPOS" kit_run "$KITP" "$H" install.sh --terminal --extras 2>&1) # back to the first pin
out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
S=$(snapshot "$H")
check "uninstall removes the plugins too and restores the seeded home exactly" \
  '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "2b. the post script refuses what doesn't match its pin"
H=$(new_home) || exit 2
P="$H/.config/palmface/tmux/plugins"
NOPE="$(printf '0123456789abcdef%.0s' 1 2)01234567" # a well-formed pin no repo has (built, so the leak scan passes)
kit_pinned "$WORK/kit-bad" "rose-pine/tmux $NOPE rose-pine.tmux"
post() { # kit copy, extra env...: run its plugin post script straight against the fake home
  local k=$1
  shift
  guard_home "$H"
  env -u XDG_CONFIG_HOME -u ZDOTDIR HOME="$H" PALMFACE_HOME="$H" PALMFACE_LAYER_DIR="$k/terminal" \
    PALMFACE_GIT_BASE="file://$REPOS" "$@" /bin/bash "$k/terminal/post/tmux-plugins.sh" 2>&1
}
out=$(post "$WORK/kit-bad"); rc=$?
check "a pin the upstream doesn't have: one warning, exit 0, nothing on disk" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "could not clone rose-pine/tmux at its pinned commit")" = 1 ] && [ -z "$(ls -A "$P" 2> /dev/null)" ]' "$out$(ls -A "$P" 2>&1)"
kit_pinned "$WORK/kit-bad" "rose-pine/tmux main rose-pine.tmux" "tmux-plugins/tmux-resurrect ${PIN_RS%?} resurrect.tmux"
out=$(post "$WORK/kit-bad"); rc=$?
check "a branch name or a short sha instead of a pin: each skipped with a warning, nothing fetched" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "^palmface: plugins.list: ")" = 2 ] && [ -z "$(ls -A "$P" 2> /dev/null)" ]' "$out"
# A git that reports another HEAD after the fetch (a lying mirror or a broken git): refused.
mkdir -p "$WORK/liar"
LIE=$(printf '1%.0s' {1..40}) # 40 characters, never a commit any stand-in repo has
printf '#!/bin/bash\ncase "$*" in *palmface-clone*rev-parse*) echo %s; exit 0 ;; esac\nexec /usr/bin/git "$@"\n' "$LIE" > "$WORK/liar/git"
chmod 755 "$WORK/liar/git"
out=$(post "$KITP" PATH="$WORK/liar:$PATH"); rc=$?
check "a fetched HEAD that is not the pinned commit: refused, nothing installed for it" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "^palmface: refused ")" = 3 ] && [ -z "$(ls -A "$P" 2> /dev/null)" ]' "$out$(ls -A "$P" 2>&1)"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "3. offline install, shaders and the tmuxinator template"
H=$(new_home) || exit 2
P="$H/.config/palmface/tmux/plugins"
mkdir -p "$H/.config/git" "$H/.config/tmux" # git and tmux kept the XDG way
printf '[user]\n\tname = Someone\n' > "$H/.config/git/config"
printf 'set -g mouse on\n' > "$H/.config/tmux/tmux.conf"
out=$(PALMFACE_GIT_BASE="file://$WORK/no-such-dir" kit_run "$KIT" "$H" install.sh --terminal --extras 2>&1); rc=$?
check "XDG git and tmux users get a note about the new home dotfiles" \
  'printf "%s" "$out" | grep -q "git: your config lives in ~/.config/git/config" && printf "%s" "$out" | grep -q "tmux: Palmface created ~/.tmux.conf"' "$out"
check "offline: install still exits 0" '[ $rc -eq 0 ]' "$out"
check "offline: one warning, and no plugin or partial clone on disk" \
  '[ "$(printf "%s\n" "$out" | grep -c "could not clone")" = 1 ] && [ -z "$(ls -A "$P" 2> /dev/null)" ]' "$out$(ls -A "$P" 2>&1)"
out=$(env -i HOME="$H" PALMFACE_HOME="$H" SHELL=/bin/zsh ZDOTDIR="$H/zdot" /bin/bash "$KIT/terminal/post/shell-check.sh" 2>&1)
check "a ZDOTDIR zsh gets told where to add the source line, .zprofile included" \
  'printf "%s" "$out" | grep -qF "your zsh reads $H/zdot/.zshrc and $H/zdot/.zprofile, not ~/.zshrc and ~/.zprofile" && printf "%s" "$out" | grep -qF "add this line to $H/zdot/.zshrc:  source ~/.config/palmface/zsh/vibes.zsh"' "$out"
if [ -f "$H/.config/palmface/zsh/paths.zsh" ]; then pz=1; else pz=0; fi
check "the .zprofile source line is offered exactly when paths.zsh is installed" \
  '[ "$(printf "%s\n" "$out" | grep -cF "and this one to $H/zdot/.zprofile:  source ~/.config/palmface/zsh/paths.zsh")" = "$pz" ]' "pz=$pz $out"
n=$(find "$H/.config/palmface/ghostty/shaders" -name '*.glsl' | wc -l | tr -d ' ')
check "8 licence-checked shaders installed, with PROVENANCE.md and the MIT text" \
  '[ "$n" = 8 ] && [ -f "$H/.config/palmface/ghostty/shaders/PROVENANCE.md" ] && [ -f "$H/.config/palmface/ghostty/shaders/LICENSE-cursor-shaders" ]' "$n"
active=$(grep -cE '^[[:space:]]*custom-shader' "$H/.config/ghostty/config")
listed=$(grep -cE '^# custom-shader = ~/.config/palmface/ghostty/shaders/' "$H/.config/ghostty/config")
check "every shader line is listed and commented out" '[ "$active" = 0 ] && [ "$listed" = 8 ]' "active=$active listed=$listed"
if [ -n "$GHOSTTY" ]; then
  # What a user does to turn them on: copy the lines below the block, uncommented.
  sed -n 's/^# \(custom-shader = .*\)/\1/p' "$H/.config/ghostty/config" > "$WORK/on"
  cat "$WORK/on" >> "$H/.config/ghostty/config"
  ghostty_in "$H" +validate-config --config-file="$H/.config/ghostty/config"; rc=$?
  check "with all shaders turned on, ghostty +validate-config passes" '[ $rc -eq 0 ] && [ ! -s "$WORK/ghostty.out" ]' "$(cat "$WORK/ghostty.out")"
  ghostty_in "$H" +show-config
  missing=""
  while IFS= read -r f; do [ -f "$f" ] || missing="$missing $f"; done < <(sed -n 's/^custom-shader = //p' "$WORK/ghostty.out")
  n=$(grep -ac '^custom-shader = ' "$WORK/ghostty.out")
  check "Ghostty resolves all 8 ~ shader paths to real files" '[ "$n" = 8 ] && [ -z "$missing" ]' "n=$n missing:$missing"
fi
if [ -n "$(tool tmuxinator)" ]; then
  out=$(env -i HOME="$H" PATH="$FULL" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" tmuxinator debug palmface-example 2>&1); rc=$?
  check "tmuxinator reads palmface-example.yml" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "new-session"' "$out"
else skip "tmuxinator not installed"; fi
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "4. the login shell: one warning up front, and the chsh offer on a terminal (chsh stubbed)"
# The real chsh never runs here. The offer needs $HOME to be the account's home: PALMFACE_REAL_HOME
# stands in for it, and every run that sets it also points PALMFACE_CHSH_CMD at a stub that only
# logs its arguments. A real terminal comes from /usr/bin/expect (spawn/send): script(1) drops
# the first line of input, so it cannot answer the prompt.
STUB="$WORK/stub"
mkdir -p "$STUB"
printf '#!/bin/bash\necho "$@" >> "%s/chsh.log"\nexit ${STUB_RC:-0}\n' "$STUB" > "$STUB/chsh"
chmod 755 "$STUB/chsh"
cat > "$WORK/offer.exp" << 'EXP'
# reply, install args...: install.sh on a pty; answer each [Y/n] with reply ("EOF" sends Ctrl-D)
set timeout 120
set reply [lindex $argv 0]
spawn /bin/bash $env(KIT)/install.sh {*}[lrange $argv 1 end]
expect {
  -re {\[Y/n\] } { if {$reply eq "EOF"} { send -- "\004" } else { send -- "$reply\r" }; exp_continue }
  timeout { puts "\nexpect: timed out"; exit 98 }
  eof
}
catch wait result
exit [lindex $result 3]
EXP
OUT="$WORK/offer.out"
offer() { # reply, install args...: on a pty in a fresh fake home; LOGIN_SHELL, USHELL, REAL, STUB_RC
  rm_home "$H"
  H=$(new_home) || exit 2
  : > "$STUB/chsh.log"
  env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u ZDOTDIR \
    KIT="$KIT" HOME="$H" SHELL="${LOGIN_SHELL:-/bin/bash}" STUB_RC="${STUB_RC:-0}" \
    PALMFACE_REAL_HOME="${REAL-$H}" PALMFACE_USER_SHELL="${USHELL:-/bin/bash}" PALMFACE_CHSH_CMD="$STUB/chsh" \
    /usr/bin/expect -f "$WORK/offer.exp" "$@" > "$OUT" 2>&1
}
prompts() { grep -ac '\[Y/n\]' "$OUT"; }
called() { [ -s "$STUB/chsh.log" ]; }
H=$(new_home) || exit 2

# AC-1: the warning, without a prompt
: > "$STUB/chsh.log"
out=$(SHELL=/bin/bash PALMFACE_CHSH_CMD=$STUB/chsh kit_run "$KIT" "$H" install.sh --terminal --no-post < /dev/null 2>&1); rc=$?
check "AC-1 bash, stdin closed: install exits 0 with the warning exactly once, as its first line" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "your login shell is /bin/bash, not zsh")" = 1 ] && printf "%s\n" "$out" | head -1 | grep -q "not zsh"' "$out"
check "AC-1 bash, stdin closed: no prompt, no chsh call" \
  '! printf "%s" "$out" | grep -q "\[Y/n\]" && ! printf "%s" "$out" | grep -q "switch your login shell" && ! called' "$out"
out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
NOTE1='note: uninstall does not change your shell back; chsh -s /bin/bash if you want'
NOTE2='note: if claude is not found afterwards: echo '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> ~/.zprofile'
check "uninstall says it leaves the shell alone, and how to put claude back on PATH" \
  '[ $rc -eq 0 ] && printf "%s\n" "$out" | grep -qxF "$NOTE1" && printf "%s\n" "$out" | grep -qxF "$NOTE2"' "$out"
rm_home "$H"
H=$(new_home) || exit 2
out=$(SHELL=/bin/bash kit_run "$KIT" "$H" install.sh --claude --no-post < /dev/null 2>&1); rc=$?
check "AC-1 --claude only: no warning, no prompt" \
  '[ $rc -eq 0 ] && ! printf "%s" "$out" | grep -q "not zsh" && ! printf "%s" "$out" | grep -q "\[Y/n\]"' "$out"
rm_home "$H"
H=$(new_home) || exit 2
out=$(SHELL=/bin/zsh kit_run "$KIT" "$H" install.sh --terminal --no-post < /dev/null 2>&1); rc=$?
check "AC-1 zsh login shell: no \"not zsh\" text" '[ $rc -eq 0 ] && ! printf "%s" "$out" | grep -q "not zsh"' "$out"
offer y --terminal --dry-run; rc=$?
check "AC-1 --dry-run on a terminal, every other condition met: no prompt, the chsh stub never called" \
  '[ $rc -eq 0 ] && [ "$(prompts)" = 0 ] && ! called && grep -aq "not zsh" "$OUT"' "rc=$rc $(cat "$OUT" "$STUB/chsh.log")"
REAL='' offer y --terminal --no-post; rc=$?
check "AC-1 a fake HOME without PALMFACE_REAL_HOME, on a terminal: no prompt, no chsh call" \
  '[ $rc -eq 0 ] && [ "$(prompts)" = 0 ] && ! called' "rc=$rc $(cat "$OUT" "$STUB/chsh.log")"
# Post scripts on, ZDOTDIR set (kit_run drops ZDOTDIR, so the env is spelled out), offline.
guard_home "$H"
out=$(env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME HOME="$H" SHELL=/bin/bash \
  ZDOTDIR="$H/zd" PALMFACE_GIT_BASE="file://$WORK/no-such-dir" /bin/bash "$KIT/install.sh" --terminal < /dev/null 2>&1); rc=$?
check "AC-1 posts on: shell-check.sh still prints the ZDOTDIR text, .zprofile included" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -qF "your zsh reads $H/zd/.zshrc and $H/zd/.zprofile" && printf "%s" "$out" | grep -q "run   terminal/post/shell-check.sh"' "$out"
check "AC-1 posts on: the login-shell warning still appears exactly once" \
  '[ "$(printf "%s\n" "$out" | grep -c "not zsh")" = 1 ]' "$out"
SC() { env -i HOME="$H" PALMFACE_HOME="$H" SHELL=/bin/bash ZDOTDIR="$H/zd" "$@" /bin/bash "$KIT/terminal/post/shell-check.sh" 2>&1; }
out=$(SC PALMFACE_SHELL_CHECKED=1); rc=$?
check "shell-check.sh with PALMFACE_SHELL_CHECKED=1: no login-shell part, the ZDOTDIR part stays" \
  '[ $rc -eq 0 ] && ! printf "%s" "$out" | grep -q "not zsh" && printf "%s" "$out" | grep -q "your zsh reads $H/zd/.zshrc"' "$out"
out=$(SC); rc=$?
check "shell-check.sh run on its own still warns about a bash login shell" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "your login shell is /bin/bash, not zsh")" = 1 ]' "$out"

# AC-2: the offer, over a TTY
offer y --terminal --no-post; rc=$?
check "AC-2 y: install exits 0" '[ $rc -eq 0 ]' "$(cat "$OUT")"
check "AC-2 y: one prompt, the stub logged -s /bin/zsh once, and the switched line" \
  '[ "$(prompts)" = 1 ] && [ "$(cat "$STUB/chsh.log")" = "-s /bin/zsh" ] && grep -aq "shell switched: quit and reopen your terminal" "$OUT"' \
  "$(cat "$OUT" "$STUB/chsh.log" 2>&1)"
check "AC-2 the prompt comes after the install's own output" \
  'tr -d "\r" < "$OUT" | grep -anE "^(copy|block)  ~/|\[Y/n\]" | tail -1 | grep -q "\[Y/n\]"' "$(cat "$OUT")"
offer '' --terminal --no-post; rc=$?
check "AC-2 a bare Return runs chsh (the default is yes)" \
  '[ $rc -eq 0 ] && grep -qx -- "-s /bin/zsh" "$STUB/chsh.log"' "$(cat "$OUT" "$STUB/chsh.log" 2>&1)"
offer n --terminal --no-post; rc=$?
check "AC-2 n: no chsh call, and the kept-your-shell line" \
  '[ $rc -eq 0 ] && ! called && grep -aq "kept your shell; to switch later: chsh -s /bin/zsh" "$OUT"' "$(cat "$OUT" "$STUB/chsh.log" 2>&1)"
STUB_RC=1 offer y --terminal --no-post; rc=$?
check "AC-2 chsh exits 1: install still exits 0 and prints the manual chsh line" \
  '[ $rc -eq 0 ] && called && grep -aq "chsh did not run; later: chsh -s /bin/zsh" "$OUT"' "rc=$rc $(cat "$OUT")"
offer EOF --terminal --no-post; rc=$?
check "AC-2 EOF (Ctrl-D) at the prompt: no chsh call, kept your shell" \
  '[ $rc -eq 0 ] && [ "$(prompts)" = 1 ] && ! called && grep -aq "kept your shell" "$OUT"' "rc=$rc $(cat "$OUT" "$STUB/chsh.log" 2>&1)"
rm_home "$H"
H=$(new_home) || exit 2
: > "$STUB/chsh.log"
out=$(SHELL=/bin/bash PALMFACE_REAL_HOME="$H" PALMFACE_USER_SHELL=/bin/bash PALMFACE_CHSH_CMD="$STUB/chsh" \
  kit_run "$KIT" "$H" install.sh --terminal --no-post < /dev/null 2>&1); rc=$?
check "AC-2 stdin /dev/null (not a terminal), every other condition met: no prompt, no chsh call" \
  '[ $rc -eq 0 ] && ! printf "%s" "$out" | grep -q "\[Y/n\]" && ! called' "$out"
USHELL=/bin/zsh offer y --terminal --no-post; rc=$?
check "AC-2 the account shell is already zsh: no prompt, no chsh call" \
  '[ $rc -eq 0 ] && [ "$(prompts)" = 0 ] && ! called' "rc=$rc $(cat "$OUT")"
LOGIN_SHELL=/usr/local/bin/fish USHELL=/usr/local/bin/fish offer y --terminal --no-post; rc=$?
check "AC-2 a fish shell: the warning, but no prompt and no chsh call" \
  '[ $rc -eq 0 ] && grep -aq "your login shell is /usr/local/bin/fish, not zsh" "$OUT" && [ "$(prompts)" = 0 ] && ! called' "rc=$rc $(cat "$OUT")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "5. AC-3: the PATH lines (a real zsh login shell reads ~/.zprofile)"
if [ -x /bin/zsh ]; then
  H=$(new_home) || exit 2
  mkdir -p "$H/.local/bin"
  kit_run "$KIT" "$H" install.sh --terminal --no-post > /dev/null 2>&1
  p=$(env -i HOME="$H" PATH=/usr/bin:/bin /bin/zsh -l -c 'print -r -- $PATH')
  check "AC-3 ~/.local/bin on PATH exactly once" '[ "$(printf "%s" "$p" | tr ":" "\n" | grep -cxF "$H/.local/bin")" = 1 ]' "$p"
  p2=$(env -i HOME="$H" PATH=/usr/bin:/bin /bin/zsh -l -c 'source ~/.config/palmface/zsh/paths.zsh; print -r -- $PATH')
  check "AC-3 re-sourcing keeps one entry" '[ "$(printf "%s" "$p2" | tr ":" "\n" | grep -cxF "$H/.local/bin")" = 1 ]' "$p2"
  check "AC-3 install put paths.zsh and one palmface block in .zprofile" \
    '[ -f "$H/.config/palmface/zsh/paths.zsh" ] && [ "$(grep -c "^# >>> palmface:terminal >>>" "$H/.zprofile")" = 1 ] && grep -qF "zsh/paths.zsh" "$H/.zprofile"' "$(cat "$H/.zprofile" 2>&1)"
  check_manifest "$H"
  kit_run "$KIT" "$H" uninstall.sh > /dev/null 2>&1
  check "AC-3 uninstall with no pre-existing .zprofile: the file is gone" '[ ! -e "$H/.zprofile" ]' "$(ls -A "$H")"
  rm_home "$H"

  H2=$(new_home) || exit 2
  mkdir -p "$H2/.local/bin"
  printf 'eval "$(/opt/homebrew/bin/brew shellenv)"\n' > "$H2/.zprofile"
  S0=$(snapshot "$H2")
  kit_run "$KIT" "$H2" install.sh --terminal --no-post > /dev/null 2>&1
  check "AC-3 pre-existing .zprofile: the Homebrew line stays line 1" 'head -1 "$H2/.zprofile" | grep -q "brew shellenv"' "$(cat "$H2/.zprofile")"
  check "AC-3 pre-existing .zprofile: the palmface block is appended" \
    'grep -q "palmface" "$H2/.zprofile" && grep -q "zsh/paths.zsh" "$H2/.zprofile"' "$(cat "$H2/.zprofile")"
  p=$(env -i HOME="$H2" PATH=/usr/bin:/bin /bin/zsh -l -c 'print -r -- $PATH')
  check "AC-3 pre-existing .zprofile: ~/.local/bin still on PATH exactly once" \
    '[ "$(printf "%s" "$p" | tr ":" "\n" | grep -cxF "$H2/.local/bin")" = 1 ]' "$p"
  check_manifest "$H2"
  kit_run "$KIT" "$H2" uninstall.sh > /dev/null 2>&1
  S=$(snapshot "$H2")
  check "AC-3 uninstall restores .zprofile exactly (home snapshot equal)" '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"
  rm_home "$H2"
else
  echo "  skip  /bin/zsh missing: AC-3 login-shell tests"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "6. the greeting names camp only when camp exists (a real window, so the load order counts)"
cat > "$WORK/greet.exp" << 'EXP'
# zsh -i on a pty: it draws the greeting, reaches its first prompt (precmd runs), the test hook
# in ~/.zshrc runs the command and exits; expect waits for that eof, never for a fixed time.
set timeout 120
spawn /bin/zsh -i
expect {
  timeout { puts "\nexpect: timed out"; exit 98 }
  eof
}
EXP
greet_in() { # fake home, command to run at the first prompt, env...: what a new window shows
  local h=$1 cmd=$2 t="$WORK/greet.log"
  shift 2
  guard_home "$h"
  # A real interactive zsh on a pty that reaches its first prompt (so precmd runs). A hook that
  # ~/.zshrc registers last runs the command there and exits (expect waits for eof), so nothing depends on timing.
  cp "$h/.zshrc" "$h/.zshrc.keep"
  printf '\n_t_hook() { eval "$PALMFACE_T_CMD"; exit 0; }\nprecmd_functions+=(_t_hook)\n' >> "$h/.zshrc"
  env -i HOME="$h" PATH="$FULL" TERM=xterm-256color COLUMNS=100 STARSHIP_CACHE="$WORK/starship-cache" \
    PALMFACE_T_CMD="$cmd" "$@" /usr/bin/expect -f "$WORK/greet.exp" > "$t" 2> /dev/null < /dev/null
  mv "$h/.zshrc.keep" "$h/.zshrc"
  LC_ALL=C sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$t" | tr -d '\r'
}
ncamp() { printf '%s\n' "$1" | grep -cF "camp: your projects"; } # how many camp lines
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --terminal --extras --no-post 2>&1); rc=$?
check "install --terminal --extras --no-post (greeting fixture) exits 0" '[ $rc -eq 0 ]' "$out"
g=$(greet_in "$H" 'echo reached-$((6*7))')
check "greeting shows camp: your projects (exactly once) when the launcher is installed" \
  '[ "$(ncamp "$g")" = 1 ] && printf "%s" "$g" | grep -q "reached-42"' "$g"
g=$(greet_in "$H" 'echo reached-$((6*7))' PALMFACE_LAUNCHER=off)
check "greeting has no camp line with PALMFACE_LAUNCHER=off" \
  '[ "$(ncamp "$g")" = 0 ] && printf "%s" "$g" | grep -q "reached-42"' "$g"
# The user's final .zshrc state decides, not the order of the blocks.
cp "$H/.zshrc" "$WORK/zshrc.installed"
printf '\nexport PALMFACE_LAUNCHER=off\n' >> "$H/.zshrc"
g=$(greet_in "$H" 'echo reached-$((6*7))')
check "PALMFACE_LAUNCHER=off set in .zshrc after the palmface blocks: no camp line" \
  '[ "$(ncamp "$g")" = 0 ] && printf "%s" "$g" | grep -q "reached-42"' "$g"
cp "$WORK/zshrc.installed" "$H/.zshrc"
printf '\ncamp() { echo mine; }\n' >> "$H/.zshrc"
g=$(greet_in "$H" camp)
check "a camp function of the user's own, defined after the blocks: camp line shows and camp prints mine" \
  '[ "$(ncamp "$g")" = 1 ] && printf "%s" "$g" | grep -qx "mine"' "$g"
cp "$WORK/zshrc.installed" "$H/.zshrc"
mkdir -p "$H/bin"
printf '#!/bin/sh\necho mine-on-path\n' > "$H/bin/camp"
chmod 755 "$H/bin/camp"
printf '\nexport PATH=$HOME/bin:$PATH\n' >> "$H/.zshrc"
g=$(greet_in "$H" camp)
check "a user's own ~/bin/camp put on PATH after the blocks: camp line shows and the user's camp runs" \
  '[ "$(ncamp "$g")" = 1 ] && printf "%s" "$g" | grep -qx "mine-on-path"' "$g"
rm_home "$H"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --terminal --no-post 2>&1); rc=$?
check "install --terminal --no-post (greeting fixture) exits 0" '[ $rc -eq 0 ]' "$out"
g=$(greet_in "$H" 'echo reached-$((6*7))')
check "greeting has no camp line on a terminal-only install (no launcher)" \
  '[ "$(ncamp "$g")" = 0 ] && printf "%s" "$g" | grep -q "reached-42"' "$g"
rm_home "$H"

summary "smoke-terminal"

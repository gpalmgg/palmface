#!/bin/bash
# Palmface post script: fetch the tmux plugins in tmux/plugins.list into
# ~/.config/palmface/tmux/plugins/<name>; tmux.conf runs them through load-plugins.sh.
#
# Each plugin is pinned to one commit. The script fetches exactly that commit (a shallow fetch
# by its sha), checks that `git rev-parse HEAD` is that sha, and refuses the plugin otherwise:
# whatever happens upstream later, an install gets the code the kit was checked with.
#
# Idempotent: a plugin already at its pinned commit is left alone, and one at another commit (an
# older install) is replaced by the pinned one. Offline, or without git, it warns and exits 0,
# so the install carries on; tmux works without the plugins, and a later install fetches them.
set -u
home=${PALMFACE_HOME:-$HOME}
layer=${PALMFACE_LAYER_DIR:-$(cd "$(dirname "$0")/.." && pwd -P)}
list="$layer/tmux/plugins.list"
dest="$home/.config/palmface/tmux/plugins"
base=${PALMFACE_GIT_BASE:-https://github.com} # a mirror; the tests point this at local repos

warn() { printf 'palmface: %s\n' "$*" >&2; }

git_ok() { # git exists, and it is not the macOS stub that pops up an installer dialog
  local g
  g=$(command -v git) || return 1
  [ "$g" != /usr/bin/git ] && return 0
  xcode-select -p > /dev/null 2>&1
}

# No prompts, ever: not for https credentials, not for ssh (an insteadOf rule could switch).
# No hooks either, whatever your global git config says.
G() {
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes' \
    git -c core.hooksPath=/dev/null -c advice.detachedHead=false \
    -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 "$@"
}

[ -r "$list" ] || { warn "no plugin list at $list; skipped the tmux plugins."; exit 0; }
if ! git_ok; then
  warn "git is not available (Xcode Command Line Tools: xcode-select --install); skipped the tmux plugins."
  exit 0
fi

mkdir -p "$dest" || { warn "cannot create $dest; skipped the tmux plugins."; exit 0; }
rm -rf "$dest"/.*.palmface-clone.* "$dest"/.*.palmface-old.* # left by an interrupted earlier run
while read -r repo sha entry _ <&3; do
  case "$repo" in '' | '#'*) continue ;; esac
  name=${repo#*/}
  case "$sha" in
    *[!0-9a-f]* | '') warn "plugins.list: $repo has no pinned commit (want a 40-character sha); skipped it."; continue ;;
  esac
  if [ ${#sha} -ne 40 ] || [ -z "$entry" ]; then
    warn "plugins.list: $repo needs <repo> <40-character sha> <file>; skipped it."
    continue
  fi
  old=""
  if [ -d "$dest/$name/.git" ]; then
    [ "$(G -C "$dest/$name" rev-parse -q --verify HEAD 2> /dev/null)" = "$sha" ] && continue # already pinned
    old="$dest/$name" # another commit (an older install): replace it with the pinned one
  elif [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
    warn "$dest/$name exists but is not a git clone; left it alone."
    continue
  fi
  tmp="$dest/.$name.palmface-clone.$$"
  rm -rf "$tmp"
  if mkdir "$tmp" && G -C "$tmp" init -q < /dev/null > /dev/null 2>&1 &&
    G -C "$tmp" fetch --quiet --depth 1 "$base/$repo" "$sha" < /dev/null > /dev/null 2>&1 &&
    G -C "$tmp" checkout --quiet --detach FETCH_HEAD < /dev/null > /dev/null 2>&1; then
    got=$(G -C "$tmp" rev-parse -q --verify HEAD 2> /dev/null)
    if [ "$got" != "$sha" ]; then
      rm -rf "$tmp"
      warn "refused $repo: the fetched commit is ${got:-unknown}, not the pinned $sha. Nothing was installed for it."
      continue
    fi
    if [ -n "$old" ] && ! mv "$old" "$dest/.$name.palmface-old.$$"; then
      rm -rf "$tmp"
      warn "could not move the old $repo aside; left it as it was."
      continue
    fi
    if mv "$tmp" "$dest/$name"; then
      rm -rf "$dest/.$name.palmface-old.$$"
      printf 'palmface: fetched %s at %s\n' "$repo" "$(printf '%s' "$sha" | cut -c1-12)"
    else
      rm -rf "$tmp"
      [ -n "$old" ] && mv "$dest/.$name.palmface-old.$$" "$old"
      warn "could not move the $repo clone into place; skipped it."
    fi
  else
    rm -rf "$tmp"
    warn "could not clone $repo at its pinned commit (offline, or git failed). tmux works without it; re-run the install later."
    exit 0 # one warning is enough: the rest would most likely fail the same way
  fi
done 3< "$list"
exit 0

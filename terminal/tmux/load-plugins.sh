#!/bin/bash
# Palmface: run the tmux plugins in plugins.list, in order. tmux.conf calls this at startup and
# on reload. No tpm: Palmface never sets TMUX_PLUGIN_MANAGER_PATH, so a tpm of your own keeps
# working untouched.
#
# A plugin you already load through your own tpm (~/.tmux/plugins/<name> or
# ~/.config/tmux/plugins/<name>) is skipped, so nothing loads twice. A plugin that is not
# cloned yet (offline install) is skipped quietly.
dir="$HOME/.config/palmface/tmux"
[ -r "$dir/plugins.list" ] || exit 0
while read -r repo _ entry _; do # <repo> <pinned commit> <entry file>
  case "$repo" in '' | '#'*) continue ;; esac
  name=${repo#*/}
  if [ -d "$HOME/.tmux/plugins/$name" ] || [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/$name" ]; then
    continue
  fi
  if [ -x "$dir/plugins/$name/$entry" ]; then "$dir/plugins/$name/$entry" > /dev/null 2>&1; fi
done < "$dir/plugins.list"
exit 0

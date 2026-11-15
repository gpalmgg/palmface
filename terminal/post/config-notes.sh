#!/bin/bash
# Palmface post script: tell people who already had their own config what changed for them.
# Reads files only; writes nothing; always exits 0.
#  - Ghostty: which of your settings Palmface's look now overrides (included files load last).
#  - git and tmux kept in ~/.config: Palmface created ~/.gitconfig or ~/.tmux.conf next to them.
home=${PALMFACE_HOME:-$HOME}
xdg=${XDG_CONFIG_HOME:-$home/.config}
note() { printf 'palmface: %s\n' "$*" >&2; }

only_palmface() { # true when a file holds nothing but palmface blocks (and blank lines)
  awk '/^# >>> palmface:/ { inb = 1; next } /^# <<< palmface:/ { inb = 0; next }
    !inb && NF { found = 1 } END { exit found }' "$1"
}

user="$home/.config/ghostty/config"
kit="$home/.config/palmface/ghostty/config"
if [ -f "$user" ] && [ -f "$kit" ]; then
  keys=$(awk '
    function key(line) { sub(/[[:space:]]*=.*/, "", line); gsub(/[[:space:]]/, "", line); return line }
    NR == FNR { if ($0 !~ /^[[:space:]]*(#|$)/ && index($0, "=")) { k = key($0); if (k != "config-file" && k != "keybind") kitk[k] = 1 } next }
    /^# >>> palmface:/ { inb = 1; next }
    /^# <<< palmface:/ { inb = 0; next }
    !inb && $0 !~ /^[[:space:]]*(#|$)/ && index($0, "=") {
      k = key($0); if ((k in kitk) && !(k in seen)) { seen[k] = 1; printf "%s%s", (n++ ? ", " : ""), k }
    }' "$kit" "$user")
  if [ -n "$keys" ]; then
    note "Ghostty: Palmface's look overrides these settings of yours in ~/.config/ghostty/config: $keys."
    note "to keep yours, move those lines to ~/.config/ghostty/overrides (it loads last)."
  fi
fi

if [ -f "$xdg/git/config" ] && [ -f "$home/.gitconfig" ] && only_palmface "$home/.gitconfig"; then
  note "git: your config lives in ~/.config/git/config; Palmface created ~/.gitconfig with one include."
  note "git now writes 'git config --global' changes to ~/.gitconfig. Uninstall removes it again."
fi
if [ -f "$xdg/tmux/tmux.conf" ] && [ -f "$home/.tmux.conf" ] && only_palmface "$home/.tmux.conf"; then
  note "tmux: Palmface created ~/.tmux.conf; tmux reads it before your ~/.config/tmux/tmux.conf, so your settings still win."
fi
exit 0

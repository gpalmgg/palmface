#!/bin/bash
# Palmface post script: the terminal layer's shell parts (vibes.zsh: aliases, greeting,
# starship prompt, screensaver) are zsh, loaded from ~/.zshrc. Warn when the login shell is
# something else, or when zsh reads its config from a ZDOTDIR instead of ~/.zshrc.
# Writes nothing; always exits 0.
home=${PALMFACE_HOME:-$HOME}
shell=${SHELL:-}
if [ -z "$shell" ]; then
  shell=$(dscl . -read "/Users/$(id -un)" UserShell 2> /dev/null | awk '{ print $2 }')
fi
case "${shell##*/}" in
  zsh) ;;
  *)
    printf 'palmface: your login shell is %s, not zsh. The zsh parts (aliases, greeting, prompt) load only in zsh;\n' "${shell:-unknown}" >&2
    printf 'palmface: Ghostty, tmux and git delta work either way. To switch: chsh -s /bin/zsh\n' >&2
    ;;
esac
if [ -n "${ZDOTDIR:-}" ] && [ "${ZDOTDIR%/}" != "${home%/}" ]; then
  printf 'palmface: your zsh reads %s/.zshrc, not ~/.zshrc, so the palmface block there never runs.\n' "$ZDOTDIR" >&2
  printf 'palmface: add this line to %s/.zshrc:  source ~/.config/palmface/zsh/vibes.zsh\n' "$ZDOTDIR" >&2
fi
exit 0

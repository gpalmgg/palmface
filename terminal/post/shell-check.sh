#!/bin/bash
# Palmface post script: the terminal layer's shell parts (vibes.zsh: aliases, greeting,
# starship prompt, screensaver) are zsh, loaded from ~/.zshrc and ~/.zprofile. Warn when the
# login shell is something else, or when zsh reads its config from a ZDOTDIR instead of ~.
# install.sh already warns about the login shell up front and sets PALMFACE_SHELL_CHECKED=1,
# so then only the ZDOTDIR part runs here. Writes nothing; always exits 0.
home=${PALMFACE_HOME:-$HOME}
if [ "${PALMFACE_SHELL_CHECKED:-}" != 1 ]; then
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
fi
if [ -n "${ZDOTDIR:-}" ] && [ "${ZDOTDIR%/}" != "${home%/}" ]; then
  z=${ZDOTDIR%/}
  printf 'palmface: your zsh reads %s/.zshrc and %s/.zprofile, not ~/.zshrc and ~/.zprofile, so the palmface blocks there never run.\n' "$z" "$z" >&2
  printf 'palmface: add this line to %s/.zshrc:  source ~/.config/palmface/zsh/vibes.zsh\n' "$z" >&2
  if [ -f "$home/.config/palmface/zsh/paths.zsh" ]; then
    printf 'palmface: and this one to %s/.zprofile:  source ~/.config/palmface/zsh/paths.zsh\n' "$z" >&2
  fi
fi
exit 0

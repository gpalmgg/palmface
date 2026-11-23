# Homebrew (Apple Silicon, then Intel), unless brew is already on PATH
if (( ! $+commands[brew] )); then
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
fi
# Claude Code's native installer puts claude in ~/.local/bin
if [[ -d $HOME/.local/bin && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then export PATH="$HOME/.local/bin:$PATH"; fi

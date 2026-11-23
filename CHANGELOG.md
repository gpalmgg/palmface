# Changelog

## v0.1.1

Fixes from a first-time install of v0.1.0.

- **Shell.** A terminal-layer install on a login shell other than zsh warns before it writes
  anything. On a bash account, a successful install offers `chsh -s /bin/zsh` (`[Y/n]`, Return
  is yes). A failed switch is never fatal. Uninstall doesn't change the shell back, and says so.
- **PATH.** The terminal layer adds a `~/.zprofile` block that puts Homebrew and `~/.local/bin`
  (where Claude Code's native installer puts `claude`) on your PATH, once.
- **Voice on by default.** The claude layer merges `voiceEnabled` and `voice.enabled` into
  `~/.claude/settings.json`. `PALMFACE_VOICE=off` skips it.
- **`camp`** lists plain folders too, marked `plain folder`; `w` on one starts without a
  worktree and says so. Your own `camp` program wins even when it comes later on PATH. New
  windows say `camp: your projects`.
- **Brewfile** skips the Ghostty cask when Ghostty was installed by hand.
- **README** for first-timers: Before you start, install in five steps with "It worked if"
  checks, First session, If something's off, Staying safe, After install (optional).

## v0.1.0

First release.

# Security

Palmface runs code on your machine: hooks on every Claude Code turn, a statusline on every
redraw, shell and tmux configuration. A problem in it is worth reporting.

## Reporting a vulnerability

Report it privately, through GitHub's private vulnerability reporting: the **Security** tab of
this repository, then **Report a vulnerability**. Please don't open a public issue or pull
request for a security problem, and don't send one by email or direct message.

Include what you found, how to reproduce it, and what it lets someone do. You will get an answer
in the advisory thread.

Supported version: the latest tagged release.

## How Palmface is never updated

The maintainer never sends updates, patches, fixes or install instructions through issues, pull
requests, comments, email, direct messages or any other repository. Only tagged releases in this
repository count. Anything else that claims to be a Palmface update, including a request to run
`curl … | bash`, is not one. Check a release before you install it: the README says how.

## What runs on your machine

- **`install.sh`**, when you run it: it copies kit files into `~/.config/palmface/`,
  `~/.claude/palmface/` and `~/.claude/skills/palmface-*/`, adds one marked block to a few
  dotfiles, merges hook entries and the voice setting into `~/.claude/settings.json`, and backs
  up every original in `~/.palmface-backup/`. It never uses sudo and never runs Homebrew. On an
  account whose login shell is bash, it then asks whether to switch the login shell to zsh, and
  runs `chsh -s /bin/zsh` only if you say yes. `chsh` asks for your Mac password itself;
  Palmface never sees it.
- **The tmux plugins**, fetched once by the terminal layer's install from GitHub, each at a
  pinned commit that is checked before use. tmux runs them when it starts. tmux-resurrect saves
  each pane's command line every 15 minutes (the tmux config says how to turn that off).
- **The Claude Code hooks**, on events in every session: each prompt, each finished turn, before
  and after a compaction. They are bash, read the hook input and the session transcript, write
  only under `~/.claude/palmface/state/` (files readable by you alone), and make no network calls.
  None approves a tool call or a permission.
- **The statusline**, a node script Claude Code runs on every redraw. It reads the session
  transcript and runs read-only `git` in the project. Its one network call, to wttr.in, happens
  only if you set `PALMFACE_CITY`.
- **The shell layer** (`vibes.zsh`, the `camp` launcher), each time zsh starts, and the
  screensaver, after an idle stretch. No network.
- **The skills**, which are instructions Claude reads. Their scripts run only when a skill or you
  call them: `/palmface-chain` starts headless `claude -p` sessions in tmux, with the permission
  mode you choose.

The README lists every file each layer writes, every switch that turns a part off, and how
uninstall puts things back.

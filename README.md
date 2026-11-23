# Palmface

A kit for working in [Claude Code](https://claude.com/claude-code) on macOS. It gives you a
terminal that feels alive, and a Claude that holds its ground, asks real questions, finishes
what it starts and keeps an eye on its own context. It ships in layers: install the ones you
want, and undo any of it exactly.

```
   ,___,      /\_/\
   {o,o}     ( o.o )     owls by night,
   /)__)      > ^ <      cats by day
  --"-"--
```

## What it is

- **An alive terminal.** Ghostty in Rosé Pine (Moon when macOS is dark, Dawn when light), the
  Maple Mono font, a starship prompt, tmux with a status bar and saved sessions, eza, bat, fzf,
  zoxide and delta. A new window says hello with an owl at night or a cat by day, and an idle
  prompt drifts into a screensaver: a star field, or a toy such as cbonsai if you installed
  one. Under Claude Code's input sits a statusline with your
  context and usage bars, cost, the session's tools and agents, and a small pet whose mood
  follows the session.
- **Discipline, with hooks that enforce it.** A `CLAUDE.md` of working agreements, and small
  hooks that back them. Ask whether a plan will work and Claude is reminded to name its
  assumptions and unknowns first. A reply that leans on agreement or praise instead of
  substance gets sent back once. So does a reply that buries a question in prose instead of
  asking it with the question tool, and one that answers "are we done?" with a fresh list of
  open work. Past 150K tokens of context, Claude tells you and offers a handoff file.
- **Skills.** 21 `palmface-*` skills for the path work takes: fragments, brief, plan,
  challenge, build, check, retro. Plus a few for judgement and sessions.
- **A relational stance.** Claude meets what you bring. If you are angry, it names what it
  hears instead of grovelling. If you are warm, it receives that instead of deflecting. When
  you push back, it re-checks its reasoning and says plainly whether it was wrong or still
  thinks it was right. It tells you when it doesn't know.

**What it feels like.** You open a window and a figlet banner says hello in rainbow colours.
You start Claude Code from `camp`, a menu of your projects. You ask whether an idea is
feasible, and the first thing you get back is what it rests on and what could break it. Each
reply carries one small critter. When you ask "are we done?", the answer is yes, or one
question with options that finishes it.

## Requirements

- macOS (the kit checks). Linux is not supported.
- Claude Code, from its native installer (step 3 below). Voice needs a Claude account login
  (claude.ai), not an API (Console) key.
- zsh for the terminal layer. It is macOS's default shell. If your account still uses bash,
  install offers to switch it; with any other shell it warns.
- [Homebrew](https://brew.sh) for the tools (optional: everything checks a tool exists before
  using it).
- `jq` for merging `settings.json`. macOS 15 and later ship it; the Brewfile has it too.
- `node` 18 or newer for the statusline (the Brewfile has it; nvm, volta or asdf work too).

## Before you start

Never used a terminal? Start here.

**Two places to type.** The terminal is the window where commands run. Its last line ends in
`%` (after Palmface, in `❯`) and waits for you: that is the prompt. Once you type `claude`, you
are talking to Claude Code instead, inside the same window. Install commands go to the
terminal, not to Claude. In Claude? Type `/exit` and press Return to get back.

**How to run a command.** The command boxes below hold one command per line. For each line:

1. Copy it: select it and press Cmd+C.
2. Click in the Ghostty window.
3. Press Cmd+V to paste.
4. Press Return.
5. Wait until the prompt comes back on a new line. Then do the next line.

**Passwords stay invisible.** When the terminal asks for a password, it means your Mac password.
Nothing shows while you type, not even dots. Type it and press Return.

**Check your shell** once Ghostty is open (step 1):

```sh
echo $SHELL
```

`/bin/zsh` is what you want. `/bin/bash` is fine too: install offers to switch (see "Not zsh?"
below).

**Keys that are hard to find.** On a German keyboard, `~` is Option+N, then Space, and `|` is
Option+7. You only need them when you type a command instead of pasting it.

## Install

Five steps. Each ends with **It worked if:**, a check to make before the next step.

### 1. Ghostty

Ghostty is the terminal: the window where you type commands. It runs on Apple Silicon and
Intel Macs, macOS 13 or later.

1. Open [ghostty.org/download](https://ghostty.org/download) and click the macOS download. You
   get `Ghostty.dmg`.
2. Open `Ghostty.dmg` and drag Ghostty into Applications.
3. Open Ghostty from Applications. If macOS asks whether to open an app downloaded from the
   internet, click Open.

**It worked if:** a window opens with a line ending in `%` (or `$` on a bash account) and a
blinking cursor. Now check your shell (above).

### 2. Homebrew

Homebrew installs the tools Palmface uses. This is its install command, from
[brew.sh](https://brew.sh):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

1. Paste it into Ghostty and press Return.
2. Type your Mac password when it asks, and press Return when it asks you to continue. It takes
   a few minutes.
3. If it ends with **Next steps** and commands to run, run them, copied from your own window.
   They are made for your Mac, so never copy them from anywhere else.

**It worked if:** `brew --version` prints `Homebrew` and a version number.

### 3. Claude Code

This is the native install command (not npm), from
[claude.com/claude-code](https://claude.com/claude-code):

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

Paste it into Ghostty and press Return.

You log in at your first session. There, pick **Claude account with subscription**, not
**Anthropic Console account**: the Console is for API keys, and voice doesn't work with one.

**It worked if:** the installer ends without an error. If typing `claude` now says
`command not found`, that's fine: steps 4 and 5 fix it.

### 4. Palmface

Clone a tagged release. Install copies what it needs, so you can delete the clone afterwards.

<!-- tested: install -->
```sh
git clone --branch v0.1.1 https://github.com/gpalmgg/palmface.git ~/palmface
cd ~/palmface
brew bundle --file=Brewfile
./install.sh --all --dry-run
./install.sh --all
```

Run the lines one at a time. What they do:
1. `git clone` copies the release into `~/palmface`, and `cd` moves into it.
2. `brew bundle` installs the tools the layers use. `install.sh` never runs brew itself. If you
   downloaded Ghostty by hand in step 1, it leaves Ghostty alone. (Before this line, you can
   check the release, as below.)
3. `--dry-run` prints every action the install would take, and writes nothing.
4. The last line installs for real. Instead of `--all` you can pick layers: `--terminal`,
   `--claude`, `--extras`. If your account uses bash, it ends with a question: see "Not zsh?"
   below.

**It worked if:** the install prints a line that starts with `done:`, and no error.

### 5. Restart Ghostty

Quit Ghostty with Cmd+Q and open it again, so it loads what Palmface set up. If Claude Code was
running, start it again too.

**It worked if:** the new window greets you with an owl or a cat, with `camp: your projects`
under it, and `claude --version` prints a version number.

**Not zsh?** If `echo $SHELL` printed `/bin/bash` (common on a Mac moved over from an older
one), install warns before it writes anything. At the end it asks:

```
palmface: switch your login shell to zsh now? Your Mac password is needed. [Y/n]
```

Press Return for yes, then type your Mac password (it stays invisible). Then quit and reopen
Ghostty. If the switch fails, install still finishes, and prints `chsh -s /bin/zsh` for you to
run later. With fish or another shell, install only warns: the zsh parts (aliases, greeting,
prompt) load only in zsh, while Ghostty, tmux and git delta work either way.

**Using ChatGPT/Codex instead?** Only `./install.sh --terminal` applies.

**Check the release.** The only official source is this repository, at a tagged release. The
maintainer never sends install or update instructions through issues, pull requests, email or
messages ([`SECURITY.md`](SECURITY.md)). To check that your clone is the release:
`git -C ~/palmface rev-parse HEAD` prints its commit, which should match the commit the
repository's Tags page shows for `v0.1.1`. Releases are not signed yet, so the commit is the
thing to compare. Read what you are about to install, too: it is plain shell, Markdown and one
small node script.

| Flag | What it does |
|---|---|
| `--terminal` | the terminal layer (`terminal/`) |
| `--claude` | Claude Code: `CLAUDE.md`, hooks, settings with voice on (`claude/`), the statusline (`statusline/`) and the skills (`skills/`) |
| `--extras` | the launcher, the persona and voice starters, Ghostty shaders, a tmuxinator template (`extras/`) |
| `--all` | every layer |
| `--dry-run` | print every action and write nothing, not even the backup folder |
| `--no-post` | skip the post scripts: no tmux plugin clones and no setup notes (offline installs, tests) |

Notes:

- **Offline is fine.** The terminal layer fetches three tmux plugins at the end of the install.
  Without a network it warns once and carries on, because tmux works without them. Run
  `./install.sh --terminal` again later to fetch them.
- **Running it twice is safe.** A second run with nothing changed writes nothing. To update,
  check out the newer tag (`git -C ~/palmface fetch --tags`, then
  `git -C ~/palmface checkout <tag>`), check it as above, and run the same `./install.sh` again.
- **The `CLAUDE.md` import.** The claude layer adds one line to your `~/.claude/CLAUDE.md`:
  `@~/.claude/palmface/CLAUDE.md`. Claude Code may ask you once to approve that import; say yes,
  or Palmface's agreements won't load. To check, ask Claude what Palmface's `CLAUDE.md` asks of
  it, or open `/memory`. (Whether the prompt appears for a user-level import depends on your
  Claude Code version, and the kit's tests can't see it.)
- **Your own instructions win.** The import sits at the end of your file, and Palmface's
  `CLAUDE.md` says that where your instructions differ, yours apply.

## First session

Start Claude Code in a folder of its own. Make one, move into it, and start Claude:

```sh
mkdir -p ~/Projects/first && cd ~/Projects/first
claude
```

Next time, type `camp` instead: it lists the folders in `~/Projects` and starts Claude in the
one whose number you type.

The first time, Claude Code shows a few screens. Among them:

1. **The theme** ("Choose the text style"). Match your macOS look: a dark theme if macOS is
   dark, a light one if it is light. A dark theme on a light Mac gives white text on white.
2. **The login.** Pick **Claude account with subscription**. A browser page opens: sign in
   there, then come back to Ghostty.
3. **Trust this folder.** It is the folder you just made: say yes.
4. **The Palmface import.** Claude Code may ask once to approve importing
   `~/.claude/palmface/CLAUDE.md`. Say yes, or Palmface's agreements won't load.

**Voice.** Hold Space and talk; let go when you're done. The first time, macOS asks whether
Ghostty may use the Microphone: allow it. `/voice` switches between hold, tap and off. Voice
needs the Claude account login, not an API key.

**Other pop-ups.** macOS may also ask whether Ghostty may use things such as Music or Photos.
Saying no is fine.

**Check that Palmface loaded.** Ask Claude: `What does Palmface's CLAUDE.md ask of you?`

**It worked if:** Claude names Palmface's working agreements, such as holding its ground,
asking questions with the question tool, and closing the loop.

## If something's off

**`command not found`.** For `brew`, run the Next steps lines from step 2. For `claude`, quit
and reopen Ghostty (step 5). Still not found? Run `echo $SHELL`: if it says bash, see "Not
zsh?". Otherwise, put Claude Code's folder on your PATH, then quit and reopen Ghostty:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
```

**White text you can't read.** Claude Code's theme doesn't match macOS's look. In Claude, type
`/theme` and pick light or dark to match.

**Holding Space does nothing.** Type `/voice` and choose hold. Check that Ghostty is allowed
under Microphone (System Settings, Privacy & Security). Voice needs a Claude account login, not
an API key. As a fallback, macOS Dictation works in any app (System Settings, Keyboard).

## Staying safe

- **Claude Code starts in auto mode:** it runs most steps without asking you first. Shift+Tab
  switches modes.
- **Stop and read** before Claude does anything with money, sends anything, or deletes
  anything, and when it works with files or text from strangers. Text from a stranger can carry
  instructions aimed at Claude.
- **Autopilot and `/palmface-chain` stay off** until you turn them on (see Autopilot).

## After install (optional)

None of these are part of Palmface. Add them when you want them.

- **Claude in Chrome**, so Claude can use web pages. Chrome only: there is no Safari version.
  Install the Claude in Chrome extension and sign in to it, then type `/chrome` in a session.
- **Computer use**, so Claude can use other apps on your Mac. It needs Ghostty allowed under
  Accessibility and under Screen Recording (System Settings, Privacy & Security).
- **Connectors**, so Claude can reach other services you use: on claude.ai, open Settings, then
  Connectors.
- **Remote control**, to follow a session from elsewhere: type `/remote-control` in a session,
  or start one with `claude --remote-control`. Then open it in the Claude app.

## What each layer writes

**The rule for your files:** Palmface never replaces a file of yours. A dotfile gets one
marked block that points at a kit file. `settings.json` gets a merge in which your values
win. Everything Palmface owns lives under `~/.config/palmface/` and `~/.claude/palmface/`, plus
the skill folders Claude Code reads from `~/.claude/skills/` and one tmuxinator template (the
extras table below). Its own record is `~/.palmface-backup/`. Before Palmface first changes or
replaces a file that already exists, it saves the original there. It
never writes through a symlink: if a dotfile is a link into a dotfiles repo, install skips it
and prints the line to add by hand. The same goes for folders: if `~/.config` or `~/.claude` (or
a kit folder inside them) is a symlink, the files under it and the post scripts (the tmux plugin
fetch, the setup notes) are skipped with a warning, so nothing lands in your dotfiles repo.

| Your file | What Palmface does to it | The line it adds |
|---|---|---|
| `~/.zshrc` | a block per layer (terminal, extras) | `source ~/.config/palmface/zsh/vibes.zsh`, and the launcher |
| `~/.zprofile` | a block (terminal) | `source ~/.config/palmface/zsh/paths.zsh`: Homebrew and `~/.local/bin` on your PATH |
| `~/.tmux.conf` | a block | `source-file -q ~/.config/palmface/tmux/tmux.conf` |
| `~/.gitconfig` | a block | `[include] path = ~/.config/palmface/git/delta.gitconfig` |
| `~/.config/ghostty/config` | a block per layer (terminal, extras) | `config-file = ?~/.config/palmface/ghostty/config`, and the shaders (all commented out) |
| `~/.claude/CLAUDE.md` | a block | `@~/.claude/palmface/CLAUDE.md` |
| `~/.claude/settings.json` | a merge: your values win, lists are joined | the hook registrations, the `statusLine`, and voice on: `voiceEnabled` and `voice.enabled` (not with `PALMFACE_VOICE=off`) |

A block sits between `# >>> palmface:terminal >>>` and `# <<< palmface:terminal <<<` (named for
its layer). In a Markdown file such as `CLAUDE.md` the markers are HTML comments:
`<!-- >>> palmface:claude >>> -->` and `<!-- <<< palmface:claude <<< -->`. If you edit outside
a block, your edits stay through re-installs and uninstall.

| Layer | Kit files |
|---|---|
| terminal | `~/.config/palmface/`: `ghostty/config`, `starship.toml`, `tmux/` (config, plugin list, loader, and the plugins once cloned), `zsh/vibes.zsh`, `zsh/paths.zsh`, `bin/screensaver.sh`, `cows/` (owl, cat, sleepycat), `git/delta.gitconfig` |
| claude | `~/.claude/palmface/`: `CLAUDE.md`, `references/` (six guides Claude reads on demand), `hooks/`, `critters.txt`, `memory/MEMORY.template.md`, `statusline/`; and `~/.claude/skills/palmface-*/` |
| extras | `~/.config/palmface/ghostty/shaders/`, `~/.config/palmface/zsh/launcher.zsh`, `~/.claude/palmface/templates/` (persona and voice starters), `~/.config/tmuxinator/palmface-example.yml` |

Things worth knowing about the terminal layer:

- **Your PATH gets Homebrew and Claude Code.** The `~/.zprofile` block loads
  `~/.config/palmface/zsh/paths.zsh`. It puts Homebrew on your PATH (`/opt/homebrew` on Apple
  Silicon, else `/usr/local` on Intel) unless `brew` is there already, and `~/.local/bin`, where
  Claude Code's native installer puts `claude`. Each goes on once.
- **Palmface's Ghostty values win over yours,** because Ghostty reads included files last. To
  keep one of your own, put it in `~/.config/ghostty/overrides`: Palmface's config loads that
  file at its very end. Install names any of your settings it now overrides.
- **The git pager becomes delta** (and falls back to `less` without delta). Your own `[delta]`
  keys still win.
- **The tmux prefix becomes Ctrl-a** only if yours is still the default Ctrl-b.
- **tmux plugins** (rose-pine, resurrect, continuum) are fetched into
  `~/.config/palmface/tmux/plugins/`, as `tmux`, `tmux-resurrect` and `tmux-continuum`, and
  loaded without tpm. Each is pinned to one commit (`~/.config/palmface/tmux/plugins.list`, and
  the notices): install fetches exactly that commit, checks it, and refuses anything else, so a
  later change upstream never reaches you unasked. New pins come with a new Palmface release.
- **tmux-resurrect saves command lines.** Pane contents are not saved, but each pane's running
  command line is, every 15 minutes (continuum), in `~/.local/share/tmux/resurrect/` (or
  `~/.tmux/resurrect/`). A command typed with a password or token in it lands there. To stop the
  automatic saves, add `set -g @continuum-save-interval '0'` after the palmface block in
  `~/.tmux.conf`, and delete the old saves.
- **tmux passes escape sequences through** (`allow-passthrough on`), so terminal images work
  inside tmux. It also lets any program in a pane send sequences straight to Ghostty, past tmux's
  filter. To turn it off: `set -g allow-passthrough off` after the palmface block.
- **Aliases only take free names, and need their tool.** `ll` and `lt` need eza, `cat` needs
  bat, and `zen` needs the optional cbonsai. Each is skipped where you already have that name.

## Switches

Every part can be turned off on its own.

**Claude Code hooks.** Set these in the `env` block of `~/.claude/settings.json`, which every
session reads, or export them in the shell you start `claude` from:

```json
{ "env": { "PALMFACE_GUESSING": "off" } }
```

| Switch | What it turns off or sets |
|---|---|
| `PALMFACE_HOOKS=off` | every Palmface hook at once (not the statusline) |
| `PALMFACE_CRITTERS=off` | the critter handed to Claude each turn |
| `PALMFACE_SOUNDS=off` | the soft chimes when a turn ends or Claude needs you. Without a restart: `touch ~/.claude/palmface/sounds.off` |
| `PALMFACE_PREFLIGHT=off` | the honesty checklist on assessment questions |
| `PALMFACE_SYCOPHANCY=off` | **blocking:** sending back replies that lean on agreement or praise |
| `PALMFACE_CLOSING=off` | **blocking:** sending back a "we're done" reply that hands you open work |
| `PALMFACE_GUESSING=off` | **blocking:** sending back a reply that ends on a prose question or an unasked guess |
| `PALMFACE_CONTEXT=off` | the context-size notes; `PALMFACE_CONTEXT_NUDGE=200000` moves the first one (tokens, default 150000) |
| `PALMFACE_GUARDIAN=off` | the snapshot saved before a compaction and handed back after |
| `PALMFACE_COST=off` | the token ledger |
| `PALMFACE_AUTOPILOT=on` | autopilot for a headless run (see Autopilot) |

**Turning off a blocking hook.** The three blocking hooks send a reply back at most once,
ignore text in code, quotes and blockquotes, and never block the corrected follow-up. They
read prose with patterns, so now and then one sends back a reply that was fine. If one keeps
misfiring for the way you work, set its switch to `off` as above and start a new session.
Every hook, its files and its limits: `~/.claude/palmface/references/hooks.md`.

**The token ledger.** `cost-tracker` keeps a row per session and model. Read it from any
terminal:

<!-- tested: report -->
```sh
bash ~/.claude/palmface/hooks/cost-tracker.sh report
bash ~/.claude/palmface/hooks/cost-tracker.sh report 30
```

The first covers the last 14 days; add a number for any other span. It counts tokens only. For a dollar column, write your own `prices.tsv` (below).

**The statusline** is not a hook, so `PALMFACE_HOOKS=off` leaves it on. To remove it, delete
`statusLine` from `~/.claude/settings.json`. It is opt-in for location:

| Switch | Effect |
|---|---|
| `PALMFACE_CITY` | adds that city's weather to the sky line. This is the statusline's only network call: it asks wttr.in at most every 30 minutes, and never while unset |
| `PALMFACE_LAT`, `PALMFACE_LON` | decimal degrees; add sunrise, sunset and golden hour |

If you already had a `statusLine`, yours stays: the merge never overwrites your value. Its
settings and the idle animation are in `~/.claude/palmface/statusline/README.md`.

**The terminal**, in `~/.zshrc` or your shell:

| Switch | Effect |
|---|---|
| `PALMFACE_GREETING=off` | no hello in new windows (`hello` still works) |
| `PALMFACE_SCREENSAVER=off` | no idle screensaver; `=stars` always picks the built-in star field. Pause: `mkdir -p ~/.cache/palmface && touch ~/.cache/palmface/screensaver.off` (delete it to resume) |
| `PALMFACE_LAUNCHER=off` | no `camp` / `palmface-camp` |
| `PALMFACE_PROJECTS_DIR` | the folders `camp` scans, colon-separated (default `~/Projects`) |
| `PALMFACE_LAUNCH_CMD` | what `camp` starts (default `claude`); also the tests' seam |

**Skills and install:**

| Switch | Effect |
|---|---|
| `PALMFACE_SESSIONS_DIR` | where `/palmface-sessions` looks for past sessions (default `~/.claude/projects`) |
| `PALMFACE_GIT_BASE` | where install clones the tmux plugins from (default `https://github.com`), for a mirror |
| `PALMFACE_VOICE=off` | install leaves voice alone: no `voiceEnabled` or `voice.enabled` in `settings.json`. Set it on the install line: `PALMFACE_VOICE=off ./install.sh --all` |

## The skills

Type `/palmface-<name>` in Claude Code, or let Claude load one when the task fits. Each piece
of work gets one folder in your project, `docs/plans/<slug>/`, so the next stage or a fresh
session picks it up from disk.

```
fragments ─▶ brief ─▶ plan ─▶ challenge ─▶ build ─▶ check ─▶ retro
 seedbed     intake   deep-plan  stress-test   build    qc       retro
                      metaplan   heartwood              prove
                                 premortem              look (visual work)
                                 canopy
```

| Skill | Use it to |
|---|---|
| `/palmface-seedbed` | find the structure in messy fragments: notes, transcripts, pasted research |
| `/palmface-intake` | turn an idea into a brief: goal, constraints, success criteria, scope |
| `/palmface-deep-plan` | research the code, then plan a feature with acceptance criteria that test behaviour |
| `/palmface-metaplan` | split work too big for one session into numbered sessions with their prompts |
| `/palmface-stress-test` | challenge a plan with a fresh-eyes review: PASS, PASS WITH RISKS or FAIL |
| `/palmface-heartwood` | a three-agent evaluation: bug hunt, steelman, or spec ambiguity |
| `/palmface-premortem` | assume it failed, and find out why before it does |
| `/palmface-canopy` | look at a plan from three future timelines |
| `/palmface-build` | build an approved plan task by task, each task reviewed against its criteria |
| `/palmface-qc` | check what was just built, with fresh eyes, before you look |
| `/palmface-prove` | acceptance-test a build through its real interfaces, with evidence |
| `/palmface-look` | a visual gate: two or three directions on a contact sheet, then you pick |
| `/palmface-retro` | a retrospective from real data, then a short interview |
| `/palmface-honest-take` | a structured, sceptical verdict on an idea or a feasibility question |
| `/palmface-listen` | turn a message with many points into a checklist, and handle every point |
| `/palmface-status` | where a piece of work stands, and what comes next |
| `/palmface-save` | save a decision, insight or bookmark to the project, or a fact to memory |
| `/palmface-sessions` | find a past session and the command to resume it (read-only) |
| `/palmface-chain` | run a plan's session prompts back to back, headless, stopping at a gate |
| `/palmface-start` | open a session: greeting, a status card, a suggested name |
| `/palmface-autopilot` | turn autopilot on or off for the project |

Run one challenge per planning cycle (stress-test, heartwood, premortem or canopy), fix what it
finds, then build. The full index, with what each skill writes, is
`~/.claude/palmface/references/skills.md`.

**Why the `palmface-` prefix.** A skill with the same name as one of yours would replace yours
(with a backup). The prefix means that in practice nothing of yours is touched, and Claude
Code's own commands, such as `/status`, stay as they are. The cost is longer names.

**Plugins.** Palmface installs none. Brainstorming comes from the `superpowers` plugin
(`superpowers:brainstorming`), and a few skills mention other superpowers skills, always with a
fallback when the plugin isn't there. [`docs/plugins.md`](docs/plugins.md) lists public plugins
from Anthropic's official marketplace that go well with the kit, with their install lines.

## `camp`

`camp` is the project launcher from the extras layer. It lists the folders one level down in
`~/Projects` (or `PALMFACE_PROJECTS_DIR`), git projects and plain folders alike, and starts
Claude Code in the one you pick. Where a git project shows its branch, a plain folder shows
`plain folder`. Hidden folders are skipped. When `camp` is there, a new window says
`camp: your projects`.

| Command | What it does |
|---|---|
| `camp` | the menu: type a number to start there |
| `camp api` | start straight away in the project named `api`, or else the first whose name contains it |
| `camp api --continue` | the same, with any further words passed to `claude` |
| `camp -l` | list the projects and start nothing |

A folder of git projects inside your projects folder is a group, and its projects are listed
too. In the menu, a number starts that project, or opens or closes a group. Add `w`
for a new git worktree, `r` to continue the last conversation, or `+K` to give Claude project K's
folder too, as in `3r+1`. `w` needs git: on a plain folder, camp starts without a worktree and
says so. `f` searches with fzf. It writes nothing. To hide clutter, list the names in
`~/.claude/palmface-local/projects.ignore`.

**Your own `camp` wins.** If you already have a `camp` (a function, an alias or a program),
Palmface leaves it alone, and its launcher is still there as `palmface-camp`.

## Your own files: `~/.claude/palmface-local/`

This folder is yours. Palmface reads it, never writes into it, and uninstall leaves it alone.
Kit files are replaced on every install; put your changes here instead.

| File | What it is |
|---|---|
| `statusline.json` | statusline settings, only the keys you change (see the statusline README) |
| `critters.txt` | your own critters, drawn alongside Palmface's (format at the top of `~/.claude/palmface/critters.txt`) |
| `prices.tsv` | dollars per million tokens per model, for `cost-tracker.sh report` (format in the script's header) |
| `persona.md` | how you decide. Autopilot and the skills that need your taste read it |
| `voice.md` | how you write. Drafts that go out under your name follow it |
| `projects.ignore` | folders `camp` hides, one name per line (`name` or `group/name`) |
| `memory/` | a hand-kept memory index, if you want one instead of Claude Code's own (see `~/.claude/palmface/references/memory.md`) |

The extras layer ships blank starters for the persona and the voice. Copy them in, then fill
them in:

<!-- tested: starters -->
```sh
mkdir -p ~/.claude/palmface-local
cp -n ~/.claude/palmface/templates/persona.md ~/.claude/palmface/templates/voice.md ~/.claude/palmface-local/
```

(`cp -n` never overwrites a copy you already have.) Ghostty has its own: keep your
overrides in `~/.config/ghostty/overrides`.

## Autopilot

On autopilot you set the goal at the start and review the results at the end, and Claude makes
the calls in between. It logs each decision, holds anything that would go out (a push, a
message, a payment) for you, and ends with a `REVIEW.md`.

- **In a session:** `/palmface-autopilot on`, `off` or `status`. The switch for each project
  folder lives outside it, in `~/.claude/palmface/state/autopilot/`, so a repository can't turn
  autopilot on for you: a `.autopilot/on` file inside a project is ignored (by the hooks,
  `/palmface-start` and Claude). `off` removes the switch and keeps the run's record in the
  project, `.autopilot/decisions.md` and `.autopilot/queue.md`. The record switches nothing; if
  you don't want it committed, add `.autopilot/` to your project's `.gitignore` (Palmface never
  edits it without asking).
- **Headless runs:** set `PALMFACE_AUTOPILOT=on`, for example
  `PALMFACE_AUTOPILOT=on claude -p "…"`. Claude Code versions that mark unattended runs get the
  same behaviour without it.
- **What changes:** the hooks that ask you things (closing, guessing, context size) go quiet,
  because nobody is there to answer. The honesty hooks keep running.

**Chains.** `/palmface-chain` runs a plan's numbered session prompts back to back, each in a
fresh headless session in tmux, on autopilot. It stops on a failed session, a missing handoff, or
a prompt that starts with `HUMAN GATE`. It needs a permission mode, and it has no default, on
purpose:

- **Recommended, on a repository you trust: `acceptEdits` plus allow rules** for what each
  session must run: your test command, `git add` and `git commit`. Put them in the project's
  `.claude/settings.local.json`, your personal settings that stay out of git, not in the
  committed `.claude/settings.json`, which would hand the same rules to everyone who clones the
  repository: `"permissions": {"allow": ["Bash(git add:*)", "Bash(git commit:*)", "Bash(npm test:*)"]}`.
  (If `git check-ignore .claude/settings.local.json` prints nothing, add it to `.gitignore`.)
  Headless, anything the rules don't allow is refused, not asked.
  - **This is not a sandbox.** With edits allowed, `npm test` and `git commit` run whatever the
    repository's test script and git hooks say, and a session can change those first, unattended.
    Use it only on a repository whose contents you wrote or fully trust, with session prompts you
    wrote. For anything else, run the chain in a container or a VM.
  - **Trust the folder first.** Claude Code ignores a project's allow rules until you have trusted
    that folder, and a headless session never shows the trust prompt. So open Claude Code in the
    project once and accept the prompt before the first chain (if you planned the work there, you
    already have). Otherwise the first session can't commit, and the chain stops after it.
  - **What trusting enables.** Trusting a folder also turns on that project's own Claude Code
    settings, including hooks in its `.claude/settings.json`: commands Claude Code runs by
    itself. That is fine for your own repository, and a reason not to trust one you didn't write.

  This route was checked with a real two-session chain on a scratch repository (Claude Code 2.1,
  with the rules in `.claude/settings.json`); try yours on one first too.
- **`bypassPermissions`** runs any command with no checks, unattended, for hours. Use it only in
  a throwaway or sandboxed checkout, never in a repository holding anything you can't lose.

The chain refuses to start on a dirty working tree, and `/palmface-chain stop` ends it.

## Uninstall

<!-- tested: uninstall -->
```sh
cd ~/palmface
./uninstall.sh --dry-run
./uninstall.sh
```

The dry run prints what it would restore and changes nothing. At the end, uninstall prints two
notes:

- It doesn't change your shell back. If you want bash again: `chsh -s /bin/bash`.
- With Palmface's `~/.zprofile` block gone, `claude` may not be found any more. If so, put
  Claude Code's folder back on your PATH, then quit and reopen the terminal:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
```

Deleted the clone? Install keeps a copy of the uninstaller:

<!-- tested: uninstall-no-clone -->
```sh
~/.palmface-backup/uninstall.sh
```

Every file Palmface touched goes back to how it was, byte for byte, and every file it created
is removed. Where you edited a file after installing, your edits stay: a dotfile loses only
Palmface's block, `settings.json` loses only what Palmface added, and a changed kit file is
saved under `~/.palmface-backup/` first. Files made inside `~/.config/palmface/` and
`~/.claude/palmface/` after install, such as the token ledger, chain logs or anything you put
there, are not deleted: they move to `~/.palmface-backup/uninstall-<ts>/kept/`, and
`--dry-run` lists them. Only what the kit rebuilds is deleted: the tmux plugins, the statusline
and hook caches, the context snapshots and the autopilot switches. When everything came back
exactly and nothing was kept, `~/.palmface-backup/` is removed too. Otherwise it stays,
uninstall says why, and the folder holds the backups and a record of the run. Add
`--keep-backups` to keep it anyway.

One common case: if `~/.claude/` didn't exist before you installed, Palmface created it, and
uninstall removes it only when it is empty. Your `palmface-local` folder, or Claude Code's own
files, keep it from being empty, so it stays, along with `~/.palmface-backup/`. Delete
`~/.palmface-backup/` yourself once you've looked.

What uninstall leaves, because it is yours: `~/.claude/palmface-local/`, the files the skills
wrote in your projects (`docs/plans/`, `.autopilot/`), and the tools' own data: tmux-resurrect
saves, the zoxide database, the starship cache and `~/.cache/palmface/`. It doesn't
remove Homebrew packages: the `Brewfile` lists what the kit asked for, so `brew uninstall` the
ones you don't use elsewhere.

## Known limits

- macOS only, and the terminal layer is zsh only.
- The hooks read English, with patterns: they sometimes miss and sometimes send back a fine
  reply (one extra turn).
- A relocated Claude config (`CLAUDE_CONFIG_DIR`) isn't followed: install writes to `~/.claude`.
- The tmux status bar is always Rosé Pine Moon (the tmux config says how to pick Dawn).
- Nerd Font symbols in the prompt rely on Ghostty's built-in symbols and show as boxes in other
  terminals.
- Palmface's CLAUDE.md import approval and chained headless runs are not covered by the tests
  (see above).
- If `~/.claude/settings.json` already has `"voiceEnabled": false` but no `voice` key (written
  by an older Claude Code), install still turns voice on, because Claude Code reads
  `voice.enabled` first. To turn it off again, type `/voice` in a session and choose off.
- `PALMFACE_VOICE=off` on a re-install doesn't remove the voice keys an earlier install added.
  Use `/voice` to turn voice off.

## Development

| Command | What it checks |
|---|---|
| `tests/framework.sh` | the installer's mechanics, against fixture layers |
| `tests/fresh-home.sh --all` | the real layers: install, reinstall, uninstall, in throwaway homes |
| `tests/smoke-terminal.sh` | the terminal layer, used the way a stranger's Mac would use it |
| `tests/smoke-claude.sh` | the hooks, statusline and settings, called the way Claude Code calls them |
| `tests/smoke-skills.sh` | the skills, their scripts and the launcher |
| `tests/integration.sh` | this README's own install and uninstall steps, pasted as written |
| `tests/leak-scan-selftest.sh` | the leak scanner itself |
| `scripts/leak-scan.sh --no-denylist` | the tree, for secrets and machine paths; add your own `scripts/denylist.txt` (and `scripts/leak-allow.local.txt` for your own scoped exemptions) to go further |

Every test runs in throwaway fake homes under `$TMPDIR` and refuses to touch your real home.
None uses the network. The installer's contract (layer files, modes, the manifest, uninstall)
is in [`docs/contracts.md`](docs/contracts.md). To add something to a layer, add a line to its
`layer.tsv`.

Three variables are test seams, not switches; leave them unset. In the installer's login-shell
checks, `PALMFACE_REAL_HOME` stands in for your account's home, `PALMFACE_USER_SHELL` for
its login shell, and `PALMFACE_CHSH_CMD` for `chsh` (the tests' stub).

## Credits

Palmface stands on other people's work:

- the statusline is a modified copy of [claude-hud](https://github.com/jarrodwatts/claude-hud)
  by Jarrod Watts (MIT);
- the cursor shaders are by Sahaj Bhatt (MIT), and the CRT shader is Timothy Lottes' public
  domain CRTS, adapted for Ghostty by Qwerasd (Unlicense);
- the colours are [Rosé Pine](https://rosepinetheme.com) (MIT), through Ghostty's bundled themes
  and the rose-pine tmux plugin;
- the font is [Maple Mono](https://github.com/subframe7536/maple-font) (SIL OFL 1.1), installed by
  Homebrew;
- tmux-resurrect and tmux-continuum are by Bruno Sutic (MIT);
- and the tools the Brewfile installs belong to their authors.

Details and licence texts: [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

## Security

How to report a problem privately, how releases are (and are never) delivered, and what runs on
your machine: [`SECURITY.md`](SECURITY.md).

## Licence

MIT. See [`LICENSE`](LICENSE).

Made by Gustaf Palm ([gpalmgg](https://github.com/gpalmgg)).

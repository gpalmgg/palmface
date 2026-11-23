# Contracts

The two specs the scripts implement. Layers add lines to their `layer.tsv`; they never change
the installer's logic. The tests (`tests/framework.sh`, `tests/fresh-home.sh`) prove both.

## Install contract
- `install.sh` / `uninstall.sh` at the repo root: `#!/bin/bash`, bash 3.2-clean (no `declare -A`, `mapfile`, `${x,,}`), shellcheck-clean, macOS-only guard. They write only under `$HOME` (the one exception, the login shell, is below). Every write goes through one code path that `--dry-run` turns into a printed line; dry-run creates nothing, not even the state dir.
- Flags: `--terminal` → `terminal/` · `--claude` → `claude/ statusline/ skills/` · `--extras` → `extras/` · `--all` → all five · `--dry-run` · `--no-post` (skip post scripts, e.g. offline tests). Layers always run in the order terminal, claude, statusline, skills, extras. No layer flag → usage, exit 2.
- **Layer contract.** A layer dir holds `layer.tsv`; install.sh only reads these files: adding to a layer means adding lines, never installer logic. Line = `mode<TAB>src<TAB>dest`, `#` comments allowed. `src` is relative to the layer dir. `dest` is relative to `$HOME` (no leading `/` or `~`, no `..`). Modes:
  - `copy`: a kit-owned file, copied (never symlinked, so the clone can be deleted). A different pre-existing file is backed up once, then replaced.
  - `tree`: `src` is a directory, expanded into one `copy` per file under it.
  - `block`: the `src` snippet is placed between `# >>> palmface:<layer> >>>` and `# <<< palmface:<layer> <<<` (`<!-- … -->` markers for `.md` dests), appended to `dest` (created if absent). Re-install replaces the block in place. Markers match even if an editor turned the file CRLF. Each layer gets at most one block per file; several layers may each have one.
  - `json`: `src` is deep-merged into `dest` with jq. Objects merge recursively, the user's existing scalars win, arrays are unioned with the user's items first. jq is required only when a json line is present. A json line may carry one option as a 4th column, `drop-if:VAR=VAL:k1,k2`: when the environment variable `VAR` equals `VAL`, the top-level keys `k1`, `k2` are left out of what is merged (and out of what uninstall later removes). Any other 4th column, a 5th column, or `drop-if` naming a key the source lacks stops the install with `<layer>/layer.tsv:<line>`.
  - `post`: `src` is a script run after the layer's files, with `dest` set to `-`. It may write only under the kit-owned roots `~/.config/palmface/` and `~/.claude/palmface/`. It must be idempotent: a re-run changes nothing. When it needs the network and the network is down, it warns and exits 0, so the install continues. It is skipped under `--no-post` and only printed under `--dry-run`. It is also skipped, with a warning, when a kit root or any directory between `$HOME` and it is a symlink. Code it fetches is pinned: the terminal layer's plugin script fetches each tmux plugin at the 40-character commit in `terminal/tmux/plugins.list`, checks `git rev-parse HEAD` against it, and refuses the plugin on a mismatch.
- **Per-target policy.** User files are never replaced wholesale; they only get `block` or `json` lines. All kit content lives in kit-owned files under `~/.config/palmface/` or `~/.claude/palmface/` (or at Claude Code's fixed paths such as `~/.claude/skills/<name>/`, as `copy`), and blocks only point at it:

  | Target | Mode | Block content |
  |---|---|---|
  | `~/.zshrc` | block | `source ~/.config/palmface/zsh/vibes.zsh` |
  | `~/.zprofile` | block | `source ~/.config/palmface/zsh/paths.zsh` (Homebrew and `~/.local/bin` on PATH, once) |
  | `~/.tmux.conf` | block | `source-file ~/.config/palmface/tmux/tmux.conf` |
  | `~/.gitconfig` | block | `[include] path = ~/.config/palmface/git/delta.gitconfig` |
  | `~/.config/ghostty/config` | block | `config-file = ~/.config/palmface/ghostty/config` |
  | `~/.claude/CLAUDE.md` | block | `@~/.claude/palmface/CLAUDE.md` import |
  | `~/.claude/settings.json` | json | from `claude/settings.template.json` (hooks; `voiceEnabled` and `voice.enabled`, left out with `PALMFACE_VOICE=off`) and `statusline/settings.json` (statusLine) |
  | starship | none | `vibes.zsh` exports `STARSHIP_CONFIG=~/.config/palmface/starship.toml` |
  | skills, hooks, scripts | copy/tree | n/a |

  Install never writes through a symlink (dotfile repos). That covers a dest that is a symlink, a dest under a symlinked directory below `$HOME`, and a post script whose kit root sits under one. It skips the entry and prints the lines to add by hand. Install refuses to run as root.
- **The one exception: the login shell.** Install may run `chsh -s /bin/zsh`, and only after an explicit yes at its `[Y/n]` prompt (Return takes the default, yes). It asks once, at the end of a successful install, only when all of these hold: not `--dry-run`; the terminal layer is selected; stdin is a terminal; `$HOME` is the account's own home (`dscl` `NFSHomeDirectory`); the account's shell (`dscl` `UserShell`) ends in `/bash`; `/bin/zsh` is listed in `/etc/shells`. EOF or no terminal means no. A failed `chsh` is never fatal: install still exits 0 and prints the command to run later. A terminal-layer install sets `PALMFACE_SHELL_CHECKED=1`, so `terminal/post/shell-check.sh` skips its login-shell part, and on a login shell other than zsh it prints one warning before anything is written. Uninstall never changes the shell back; it says so. `PALMFACE_REAL_HOME`, `PALMFACE_USER_SHELL` and `PALMFACE_CHSH_CMD` are test seams standing in for the home, the account shell and `chsh`.
- **State.** `~/.palmface-backup/` holds:
  - `manifest.tsv`, append-only and write-ahead;
  - `<ts>/` dirs (`date +%Y%m%d-%H%M%S`, created only when something needs saving), holding:
    - original files under `files/<dest>`;
    - stashed user edits under `edited/<dest>`;
    - the json fragments Palmface merged, under `kit/<layer>/<dest>`;
  - a copy of `uninstall.sh`, placed when the state dir is first created, so it is there even if install fails.

  Manifest lines are TAB-separated:
  - `mkdir <dir>`, written before install creates a directory;
  - `touch <dest> <mode> <pre:absent|file> <backup|-> <backup-sha|-> <ts>`, written after the original is backed up and before `dest` is first written. A dest gets exactly one `touch` line ever, so originals are captured once, at first sight, and later runs never overwrite them.
  - `kit <dest> <fragment path> <sha>`, written before a json write, once per distinct fragment;
  - `edited <dest>`, written when install finds the user changed a dest since its last `done` and is about to rewrite it;
  - `done <dest> <sha256>`, written after each write. If a crash lost it and no `done` was ever recorded for that dest, the next install records it.

  Writes are atomic: a temp file in the same dir is renamed over `dest`.
- **Idempotency.** A re-run with unchanged sources writes nothing: no manifest lines, no `<ts>` dir. When a dest was edited by the user since its last `done`:
  - a `copy` file's edit is stashed to `<ts>/edited/` before it is replaced;
  - `block` and `json` carry the edit into the new content.

  Either way an `edited` line is recorded.
- **Uninstall.** It reads the manifest and handles each dest in reverse order. A manifest path that is not a clean relative path (a leading `/` or `~`, a `.` or `..` part, an empty part) is never acted on: it is skipped with a warning, and uninstall exits 1.
  - Current sha equals the last `done` and the dest is not flagged `edited`: restore the original byte-for-byte with its mode, or delete the dest if `pre=absent`.
  - No `done` line (install crashed): stash the current file if it differs from the original, then restore.
  - Changed or `edited` after install. Every file is stashed to `uninstall-<ts>/kept/` before it is rewritten, then:
    - `copy`: restore the original.
    - `block`: strip every palmface block and keep the user's other edits. Unbalanced markers mean the file is left alone, with a warning.
    - `json`: unmerge with jq using the stored fragments. That removes keys Palmface added whose value is still Palmface's, and array items Palmface added that were not there before (so no dangling hooks). Everything else stays. If jq or the fragments are missing, the file is left alone and the backup path printed.
  - Directories: `mkdir`-recorded dirs go in reverse. The two kit-owned roots are removed recursively, but first every regular file in them that install never wrote (the token ledger, chain logs, anything the user put there) is moved to `uninstall-<ts>/kept/<path>`, and `--dry-run` lists each one. Only the caches the kit rebuilds are deleted with the roots: `~/.config/palmface/tmux/plugins/`, and `statusline/`, `context-guardian/`, `context-size/`, `closing-drip/` and `autopilot/` under `~/.claude/palmface/state/`. Other dirs are removed only if empty.

  `~/.palmface-backup/` is deleted, leaving the home byte-identical to before install, only when three things hold: everything restored exactly, nothing was kept by this run, and nothing worth keeping is on disk (`edited/`, `kept/`, earlier `manifest.uninstalled-*`). Otherwise the dir is kept, with the manifest renamed `manifest.uninstalled-<ts>.tsv`, and the kept items are listed. Uninstall also takes `--dry-run` and `--keep-backups`.
- **Tests.**
  - `tests/fresh-home.sh <install flags>` runs the real layers twice: once on an empty fake home, once on a fake home seeded with typical dotfiles (a `.zshrc` without a trailing newline, `settings.json`, a symlinked dotfile, a path with spaces). Each pass checks that dry-run leaves the tree unchanged, that every manifest dest exists with its `done` sha, that a second install changes nothing, and that uninstall gets back to the pre-install snapshot (sorted `find` with type, mode and sha256).
  - `tests/framework.sh` builds fixture layers and covers every mode, re-install, a changed kit source, user edits after install (also across a kit update), partial failure (an unwritable dir mid-run), a lost `done`, symlinked files and dirs, CRLF and unbalanced markers, stash survival, bad layer lines and uninstall with no manifest.
  - Both get the real home from `dscl . -read /Users/$(id -un) NFSHomeDirectory` and abort unless the fake home is a fresh dir under `$TMPDIR`.

## Leak-scan contract
- `scripts/leak-scan.sh [--no-denylist] [--history [REF]]`. Exit codes: 0 clean, 1 hits, 2 config error. It prints `path:line: rule-id` and never the matched text.
- Default scope is the publishable tree: `git ls-files -co --exclude-standard` (tracked plus untracked-not-ignored). It scans file contents, file paths, symlink targets, and binary files (via `strings`).
- `scripts/denylist.txt` is your own local list (gitignored, never committed), one entry per line:
  - default: case-insensitive whole-word match;
  - `sub:` prefix: substring;
  - `re:` prefix: an ERE;
  - `#` comments.

  A missing denylist is exit 2 unless `--no-denylist`.
- Allowlists hold fixed strings blanked out (case-insensitive) before matching, longer entries first:
  - `scripts/leak-allow.txt` (committed): the neutral noreply address, upstream credit addresses, `round-robin`, the kit's name, and GitHub noreply addresses in commit metadata. Nothing identifying.
  - `scripts/leak-allow.local.txt` (gitignored, read when present): your own strings, such as a credit line or a commit identity.

  Each entry is scoped:
  - plain: exempt everywhere;
  - `file:<path>:<string>`: exempt only in that file (its contents and path, in the tree and in `--history`);
  - `meta:<string>`: exempt only in commit author, committer and message lines.

  A `file:` entry without a string is exit 2. In `--history`, a blob is scanned once per path, so a `file:` entry never covers the same content at another path.
- Key shapes always run: `sk-…`, GitHub `gh?_`/`github_pat_`, Slack `xox?-`, AWS `AKIA`/`ASIA`, PEM `BEGIN` blocks, Google `AIza`, Stripe `_live_`, JWTs, Telegram bot tokens, hex runs of 32 or more, emails not allowlisted, and absolute `/Users/<name>` paths.
- `--history REF` also scans every blob reachable from REF plus commit author, committer and message.

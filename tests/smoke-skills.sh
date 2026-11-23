#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2088  # check() conditions are eval'd later; descriptions name ~ paths
# smoke-skills.sh: install the skills (claude layer) and the extras into fake homes, then use them
# the way a user and Claude Code would: check every skill's frontmatter, path and cross-references,
# run the skills' scripts (autopilot, start, chain, sessions) and the project launcher against fake
# projects, and uninstall back to the exact home. Never touches the real home (see tests/lib.sh) and
# never uses the network: claude, tmux, figlet, lolcat, cowsay and date are stubs on PATH.
#
# Usage: tests/smoke-skills.sh
#
# Writes are confined with sandbox-exec (stock macOS), usually to nothing at all: a script that
# claims to only read is run with no writable folder, so a write fails instead of slipping by.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

WORK=$(mktemp -d "$TMP_ROOT/palmface-smoke.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
ERR="$WORK/stderr"
LOGS="$WORK/logs" # where the stubs record their calls (the only writable place outside a home)
mkdir -p "$LOGS"
BARE=/usr/bin:/bin
BREW_BIN=""
for d in /opt/homebrew/bin /usr/local/bin; do
  if [ -x "$d/brew" ]; then BREW_BIN=$d; break; fi
done
FULL="${BREW_BIN:+$BREW_BIN:}$BARE"
SBX=$(command -v sandbox-exec 2> /dev/null || true)
skip() { printf '  skip  %s\n' "$1"; }
[ -n "$SBX" ] || skip "sandbox-exec not found: writes are checked by snapshot only"
GIT() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=kit -c user.email=t@example.com "$@"; }

# Stubs. Each records its arguments in $LOGS.
STUB="$WORK/stub"
mkdir -p "$STUB"
for t in claude tmux; do
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s/%s.log"\n[ "${1:-}" != has-session ]\n' "$LOGS" "$t" > "$STUB/$t"
done
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s/figlet.log"\nprintf "FIGLET %%s\\n" "${*: -1}"\n' "$LOGS" > "$STUB/figlet"
printf '#!/bin/bash\nsed "s/^/LOL /"\n' > "$STUB/lolcat"
printf '#!/bin/bash\nprintf "COW %%s: %%s\\n" "$(basename "$2" .cow)" "$3"\n' > "$STUB/cowsay"
printf '#!/bin/bash\nprintf "cwd=%%s args=%%s\\n" "$PWD" "$*" >> "%s/launch.log"\n' "$LOGS" > "$STUB/launch"
chmod 755 "$STUB"/*
hour_stub() { # HH: a dir whose date answers +%%H with HH
  mkdir -p "$WORK/h$1"
  printf '#!/bin/bash\nif [ "${1:-}" = +%%H ]; then echo %s; else exec /bin/date "$@"; fi\n' "$1" > "$WORK/h$1/date"
  chmod 755 "$WORK/h$1/date"
  printf '%s\n' "$WORK/h$1"
}
calls() { if [ -f "$LOGS/$1.log" ]; then wc -l < "$LOGS/$1.log" | tr -d ' '; else echo 0; fi; }

sealed() { # writable dir ("-" for none), fake home, env assignments and command...: HOME=<fake>
  local w=$1 h=$2 allow
  shift 2
  guard_home "$h"
  allow="(subpath \"$LOGS\")"
  [ "$w" = - ] || allow="$allow (subpath \"$w\")"
  if [ -n "$SBX" ]; then
    "$SBX" -p "(version 1)(allow default)
      (deny file-write* (require-not (require-any $allow
        (literal \"/dev/null\") (literal \"/dev/tty\") (regex #\"^/dev/fd/\"))))" \
      env -i HOME="$h" TERM=xterm-256color STARSHIP_CACHE="$LOGS/starship-cache" "$@"
  else
    env -i HOME="$h" TERM=xterm-256color STARSHIP_CACHE="$LOGS/starship-cache" "$@"
  fi
}
fm() { # SKILL.md: its frontmatter lines; fails when the --- fences are missing
  awk 'NR == 1 { if ($0 != "---") { bad = 1; exit } next } $0 == "---" { closed = 1; exit } { print }
    END { exit (bad || !closed) }' "$1"
}
SKILLS=""
for d in "$KIT"/skills/palmface-*/; do d=${d%/}; SKILLS="$SKILLS${SKILLS:+ }${d##*/}"; done
NSKILLS=$(printf '%s' "$SKILLS" | wc -w | tr -d ' ')
is_skill() { case " $SKILLS " in *" $1 "*) return 0 ;; esac; return 1; }

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "1. the skills land whole at Claude Code's fixed path, one folder per skill"
lines=$(grep -v '^#' "$KIT/skills/layer.tsv" | grep -v '^[[:space:]]*$')
want=$(for s in $SKILLS; do printf 'tree\t%s\t.claude/skills/%s\n' "$s" "$s"; done)
check "layer.tsv has exactly one tree line per skill folder ($NSKILLS), each to ~/.claude/skills/<name>" \
  '[ "$lines" = "$want" ]' "$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$lines"))"
check "the curated set is about twenty skills" '[ "$NSKILLS" -ge 15 ] && [ "$NSKILLS" -le 25 ]' "$NSKILLS"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1); rc=$?
check "install --claude --no-post exits 0" '[ $rc -eq 0 ]' "$out"
missing="" differ="" fmbad="" namebad="" descbad="" keybad="" scripts=0 scriptbad=""
for s in $SKILLS; do
  f="$H/.claude/skills/$s/SKILL.md"
  [ -f "$f" ] || { missing="$missing $s"; continue; }
  while IFS= read -r p; do
    d="$H/.claude/skills/$s/$p"
    if ! cmp -s "$KIT/skills/$s/$p" "$d" || [ "$(stat -f %Lp "$KIT/skills/$s/$p")" != "$(stat -f %Lp "$d")" ]; then
      differ="$differ $s/$p"
    fi
    case "$p" in *.sh)
      scripts=$((scripts + 1))
      { [ -x "$d" ] && /bin/bash -n "$d" 2> /dev/null; } || scriptbad="$scriptbad $s/$p" ;;
    esac
  done < <(cd "$KIT/skills/$s" && find . -type f | sed 's|^\./||')
  if ! front=$(fm "$f"); then fmbad="$fmbad $s"; continue; fi
  [ "$(printf '%s\n' "$front" | sed -n 's/^name: *//p')" = "$s" ] || namebad="$namebad $s"
  desc=$(printf '%s\n' "$front" | sed -n 's/^description: *//p')
  [ -n "$desc" ] && [ ${#desc} -lt 1024 ] || descbad="$descbad $s(${#desc})"
  extra=$(printf '%s\n' "$front" | grep -vE '^(name|description|argument-hint|disable-model-invocation): ')
  [ -z "$extra" ] || keybad="$keybad $s:[$extra]"
done
check "every skill's SKILL.md is installed at ~/.claude/skills/<name>/" '[ -z "$missing" ]' "missing:$missing"
check "every file of every skill is installed byte-identical, with its mode" '[ -z "$differ" ]' "differ:$differ"
check "every skill has --- fenced frontmatter" '[ -z "$fmbad" ]' "bad:$fmbad"
check "every frontmatter name equals its folder name" '[ -z "$namebad" ]' "bad:$namebad"
check "every description is there and under 1024 characters" '[ -z "$descbad" ]' "bad:$descbad"
check "frontmatter holds only name, description, argument-hint, disable-model-invocation (no tools, model, hooks or permissions)" \
  '[ -z "$keybad" ]' "$keybad"
check "the skills' $scripts scripts are executable and parse under bash 3.2" '[ "$scripts" -ge 4 ] && [ -z "$scriptbad" ]' "bad:$scriptbad"
check "only palmface-* skills were installed" \
  '[ "$(ls "$H/.claude/skills" | grep -cv "^palmface-")" = 0 ] && [ "$(ls "$H/.claude/skills" | wc -l | tr -d " ")" = "$NSKILLS" ]' "$(ls "$H/.claude/skills")"
S=$(snapshot "$H")
out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
check "uninstall exits 0 and removes every skill, and ~/.claude/skills with them" \
  '[ $rc -eq 0 ] && [ ! -e "$H/.claude/skills" ] && [ -z "$(find "$H" -mindepth 1 2> /dev/null)" ]' "$out
$(find "$H" -mindepth 1 | head -20)"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "2. cross-references: every skill, command, plugin skill and path the shipped text names exists"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --all --no-post 2>&1); rc=$?
check "install --all --no-post exits 0" '[ $rc -eq 0 ]' "$out"
FILES="$WORK/shipped-files"
{
  find "$H/.claude/skills" -type f
  find "$H/.claude/palmface/references" "$H/.claude/palmface/templates" -type f
  printf '%s\n' "$H/.claude/palmface/CLAUDE.md"
} > "$FILES"
check "the scan covers every skill, CLAUDE.md, the references and the templates" '[ "$(wc -l < "$FILES")" -gt "$NSKILLS" ]'
alltext() { while IFS= read -r f; do cat "$f"; printf '\n'; done < "$FILES"; }
TEXT="$WORK/shipped-text"
alltext > "$TEXT"
bad=""
while IFS= read -r n; do
  is_skill "$n" || [ "$n" = palmface-local ] || [ "$n" = palmface-backup ] || bad="$bad $n"
done < <(grep -oE 'palmface-[a-z]+(-[a-z]+)*' "$TEXT" | sort -u)
check "every palmface-<name> named is a shipped skill (or the palmface-local or .palmface-backup folder)" '[ -z "$bad" ]' "dangling:$bad"
SUPERPOWERS=" brainstorming writing-plans executing-plans test-driven-development systematic-debugging verification-before-completion requesting-code-review receiving-code-review subagent-driven-development dispatching-parallel-agents using-git-worktrees finishing-a-development-branch writing-skills "
bad=""
for t in $(grep -oE '`[a-z][a-z0-9-]*:[a-z][a-z0-9-]*`|superpowers:[a-z-]+' "$TEXT" | tr -d '`' | sort -u); do
  ns=${t%%:*} sk=${t#*:}
  case "$ns" in
    superpowers) case "$SUPERPOWERS" in *" $sk "*) ;; *) bad="$bad $t" ;; esac ;;
    *) bad="$bad $t" ;;
  esac
done
check "every plugin skill named is a known superpowers skill; no other plugin is assumed" '[ -z "$bad" ]' "dangling:$bad"
BUILTIN=" clear compact rename resume model plugin help config hooks memory init review agents permissions status cost context mcp login doctor export add-dir ide "
PATHROOT=" tmp dev usr bin opt etc "
bad=""
while IFS= read -r t; do
  is_skill "$t" && continue
  case "$BUILTIN$PATHROOT" in *" $t "*) continue ;; esac
  bad="$bad /$t"
done < <(grep -oE '(^|[[:space:]`("'"'"'])/[a-z][a-z0-9-]*(:[a-z0-9-]+)?($|[[:space:]`).,;'"'"'"!?])' "$TEXT" |
  sed -E 's/^[[:space:]`("'"'"']*\///; s/[[:space:]`).,;'"'"'"!?]*$//' | sort -u)
check "every /command named is a shipped skill or a Claude Code built-in" '[ -z "$bad" ]' "dangling:$bad"
bad=""
while IFS= read -r p; do
  p=$(printf '%s' "$p" | sed -E 's/[.,:;)]+$//')
  case "$p" in
    *'<'* | *'*'* | *'$'*) concrete=0 ;;
    *) concrete=1 ;;
  esac
  case "$p" in
    "~/.claude" | "~/.claude/" | "~/.claude/CLAUDE.md" | "~/.claude/settings.json" | "~/.claude/skills" | "~/.claude/skills/") ;;
    "~/.claude/projects" | "~/.claude/projects/"*) ;;
    "~/.claude/palmface-local" | "~/.claude/palmface-local/"*) ;;
    "~/.claude/palmface/state" | "~/.claude/palmface/state/"* | "~/.claude/palmface/sounds.off") ;; # runtime state; the mute flag the user touches
    "~/.claude/skills/palmface-"* | "~/.claude/palmface/"* | "~/.config/palmface/"*)
      if [ "$concrete" = 1 ] && [ ! -e "$H/${p#\~/}" ]; then bad="$bad $p"; fi
      case "$p" in "~/.claude/skills/"*)
        s=${p#\~/.claude/skills/}
        s=${s%%/*}
        [ "$concrete" = 0 ] || is_skill "$s" || bad="$bad $p" ;;
      esac ;;
    *) bad="$bad $p" ;;
  esac
done < <(grep -oE '~/\.(claude|config/palmface)[^][:space:]`'"'"'"(){}|,]*' "$TEXT" | sort -u)
check "every ~/.claude or ~/.config/palmface path named is installed, the user's own, or Claude Code's" '[ -z "$bad" ]' "dangling:$bad"
script_paths=$(grep -ohE '~/\.claude/skills/palmface-[a-z-]+/[A-Za-z0-9_./-]+\.sh' "$TEXT" | sort -u | tr '\n' ' ')
check "the skills name their scripts by installed path ($(printf '%s' "$script_paths" | wc -w | tr -d ' ') of them)" \
  '[ "$(printf "%s" "$script_paths" | wc -w | tr -d " ")" -ge 4 ]' "$script_paths"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "3. your own skills: a plain-named one is untouched; a same-named one is replaced, then restored exactly"
H=$(new_home) || exit 2
mkdir -p "$H/.claude/skills/qc" "$H/.claude/skills/palmface-qc" "$H/my-skills/look"
printf -- '---\nname: qc\ndescription: my own qc\n---\nMine.\n' > "$H/.claude/skills/qc/SKILL.md"
printf -- '---\nname: palmface-qc\ndescription: my own, same name\n---\nAlso mine.\n' > "$H/.claude/skills/palmface-qc/SKILL.md"
printf 'my notes\n' > "$H/.claude/skills/palmface-qc/notes.md"
printf 'linked\n' > "$H/my-skills/look/SKILL.md"
ln -s ../../my-skills/look "$H/.claude/skills/palmface-look"
S0=$(snapshot "$H")
QC0=$(shasum -a 256 < "$H/.claude/skills/palmface-qc/SKILL.md")
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1); rc=$?
check "install over your skills exits 0" '[ $rc -eq 0 ]' "$out"
check "your plain-named ~/.claude/skills/qc is untouched" '[ "$(cat "$H/.claude/skills/qc/SKILL.md")" = "$(printf -- "---\nname: qc\ndescription: my own qc\n---\nMine.")" ]'
check "your same-named palmface-qc/SKILL.md is backed up once and replaced by Palmface's" \
  'cmp -s "$KIT/skills/palmface-qc/SKILL.md" "$H/.claude/skills/palmface-qc/SKILL.md" && [ "$(grep -c "^touch	.claude/skills/palmface-qc/SKILL.md	" "$H/.palmface-backup/manifest.tsv")" = 1 ]'
check "your extra file in that folder stays" '[ "$(cat "$H/.claude/skills/palmface-qc/notes.md")" = "my notes" ]'
check "a skill folder that is a symlink (a dotfiles repo) is skipped with a note, its target untouched" \
  'printf "%s" "$out" | grep -q "palmface-look" && [ "$(cat "$H/my-skills/look/SKILL.md")" = linked ] && [ "$(ls "$H/my-skills/look")" = SKILL.md ]' "$out"
out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
check "uninstall exits 0" '[ $rc -eq 0 ]' "$out"
check "your palmface-qc/SKILL.md is back byte-identical" '[ "$(shasum -a 256 < "$H/.claude/skills/palmface-qc/SKILL.md")" = "$QC0" ]'
S=$(snapshot "$H")
check "the whole home is back exactly: your skills, the symlink, nothing of Palmface's left" '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "4. /palmface-autopilot keeps its switch outside the project, the hooks hear it, a repo can't flip it"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1) || bad "install --claude --no-post" "$out"
P="$H/work/my project"
mkdir -p "$P"
AP="$H/.claude/skills/palmface-autopilot/autopilot.sh"
APS="$H/.claude/palmface/state" # the only writable place for the script in these checks
ap() { (cd "$P" && sealed "$APS" "$H" PATH="$BARE" "$@" /bin/bash "$AP" "${APARGS[@]}") 2> "$ERR"; }
SW="$APS/autopilot/$(printf '%s' "$P" | shasum -a 256 | cut -c1-64)" # sha256 of the folder's path
GUESS=$(jq -r '.hooks.Stop[]? | .hooks[] | select(.command | contains("/anti-guessing.sh")) | .command' "$H/.claude/settings.json")
asks() { # run the anti-guessing hook on a reply that ends on a prose question, in folder $1 (default $P)
  jq -nc --arg c "${1:-$P}" '{session_id:"smoke-s", hook_event_name:"Stop", cwd:$c, transcript_path:($c + "/none.jsonl"),
    stop_hook_active:false, last_assistant_message:"The refactor is done.\n\nWant me to also add tests?"}' |
    sealed - "$H" PATH="$BARE" /bin/sh -c "$GUESS" > /dev/null 2>&1
  echo $?
}
check "before: the anti-guessing hook sends back a closing prose question (exit 2)" '[ "$(asks)" = 2 ]'
P0=$(snapshot "$P")
APARGS=(on); out=$(ap); rc=$?
check "on: exit 0, one line, no stderr" '[ $rc -eq 0 ] && [ "$out" = "autopilot: on for $P" ] && [ ! -s "$ERR" ]' "rc=$rc $out $(cat "$ERR")"
check "on: the project is untouched; the switch is one file in ~/.claude/palmface/state/autopilot/" \
  '[ "$(snapshot "$P")" = "$P0" ] && [ -f "$SW" ] && [ "$(ls "$APS/autopilot")" = "${SW##*/}" ]' \
  "$(snap_diff "$P0" "$(snapshot "$P")") $(ls -la "$APS/autopilot" 2>&1)"
check "on: the switch is private (folder 0700, file 0600)" \
  '[ "$(stat -f %Lp "$APS/autopilot")" = 700 ] && [ "$(stat -f %Lp "$SW")" = 600 ]' "$(ls -la "$APS/autopilot")"
check "on: the question hook now stays quiet in that project (exit 0)" '[ "$(asks)" = 0 ]'
mkdir -p "$P/.autopilot"
printf -- '- chose the small schema: fits the brief (high)\n- kept the old flag: reversible (medium)\n' > "$P/.autopilot/decisions.md"
printf -- '- send the release note (outbound)\n' > "$P/.autopilot/queue.md"
APARGS=(status); out=$(ap PALMFACE_AUTOPILOT=on); rc=$?
check "status: on, the counts, and the PALMFACE_AUTOPILOT note" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "^autopilot: on for " && printf "%s" "$out" | grep -q "decisions logged: 2  queued for you: 1" && printf "%s" "$out" | grep -q PALMFACE_AUTOPILOT=on' "$out"
APARGS=(off); out=$(ap); rc=$?
check "off: the switch is gone, the run's record is kept" \
  '[ $rc -eq 0 ] && [ ! -e "$SW" ] && [ -s "$P/.autopilot/decisions.md" ] && [ -s "$P/.autopilot/queue.md" ]' "rc=$rc $out"
check "off: the question hook asks again (exit 2)" '[ "$(asks)" = 2 ]'
rm -rf "$P/.autopilot"
APARGS=(on); ap > /dev/null; APARGS=(off); ap > /dev/null
check "on then off leaves the project exactly as it was" '[ "$(snapshot "$P")" = "$P0" ]' "$(snap_diff "$P0" "$(snapshot "$P")")"
APARGS=(sideways); ap > /dev/null; rc=$?
check "an unknown argument exits 2" '[ $rc -eq 2 ]'
APARGS=(on /); ap > /dev/null; rc=$?
check "it refuses the filesystem root" '[ $rc -eq 2 ] && grep -q refusing "$ERR"' "$(cat "$ERR")"
mkdir -p "$APS/elsewhere"
rm -rf "$APS/autopilot" && ln -s elsewhere "$APS/autopilot"
APARGS=(on); ap > /dev/null; rc=$?
check "it never writes through a symlinked switch folder" '[ $rc -eq 1 ] && [ -z "$(ls "$APS/elsewhere")" ]' "rc=$rc $(cat "$ERR")"
rm -f "$APS/autopilot"
# A repository that ships the old in-project switch, committed, as a clone would bring it.
R="$H/work/cloned repo"
mkdir -p "$R/.autopilot"
: > "$R/.autopilot/on"
GIT -C "$R" -c init.defaultBranch=main init -q && GIT -C "$R" add -A && GIT -C "$R" commit -qm "ships .autopilot/on"
check "a cloned repo that commits .autopilot/on: the question hook still sends the reply back (exit 2)" \
  '[ "$(asks "$R")" = 2 ]'
out=$( (cd "$R" && sealed - "$H" PATH="$BARE" /bin/bash "$AP" status) 2> "$ERR"); rc=$?
check "...and autopilot.sh status says off, and that the file is ignored" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "^autopilot: off for " && printf "%s" "$out" | grep -q "/on is ignored"' "$out$(cat "$ERR")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "5. /palmface-start reads only, and skips what isn't installed"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1) || bad "install --claude --no-post" "$out"
P="$H/proj"
mkdir -p "$P/docs/plans/x"
GIT -C "$P" -c init.defaultBranch=main init -q
printf 'hi\n' > "$P/README.md"
GIT -C "$P" add README.md && GIT -C "$P" commit -qm "first steps"
printf 'n\n' > "$P/docs/plans/x/v1-handoff.md"
ST="$H/.claude/skills/palmface-start/start.sh"
GITDIR=$(dirname "$(PATH="$FULL" command -v git)")
git_real=0
if [ "$GITDIR" != /usr/bin ] || xcode-select -p > /dev/null 2>&1; then git_real=1; fi
start() { (cd "$P" && sealed - "$H" "$@" /bin/bash "$ST") 2> "$ERR"; }
HS0=$(snapshot "$H")
out=$(start PATH="$STUB:$(hour_stub 13):$GITDIR:$BARE"); rc=$?
check "start: exit 0 with nothing on stderr, writing nothing (no writable folder at all)" '[ $rc -eq 0 ] && [ ! -s "$ERR" ]' "rc=$rc $(cat "$ERR")"
check "start: the banner is figlet through lolcat" 'printf "%s" "$out" | grep -q "^LOL FIGLET proj$"' "$out"
check "start: no cow while Palmface's cows are not installed" '! printf "%s" "$out" | grep -q "^COW"' "$out"
check "start: the card names the folder as ~/proj, the time and a session name" \
  'printf "%s" "$out" | grep -q "^│ folder     ~/proj$" && printf "%s" "$out" | grep -q "^│ time " && printf "%s" "$out" | grep -qE "^session name: proj-[a-z]{3}[0-9]{2}$"' "$out"
if [ "$git_real" = 1 ]; then
  check "start: git branch, changed count and the last commit" \
    'printf "%s" "$out" | grep -q "^│ git        main · 1 changed" && printf "%s" "$out" | grep -q "^│ last       first steps ("' "$out"
else
  skip "git needs the Command Line Tools here: the git rows are not checked"
fi
check "start: the newest handoff and autopilot off" \
  'printf "%s" "$out" | grep -q "^│ handoff    docs/plans/x/v1-handoff.md$" && printf "%s" "$out" | grep -q "^│ autopilot  off$"' "$out"
check "start: the skill panel lists the installed skills" \
  'printf "%s" "$out" | grep -q "^│ shape      /palmface-seedbed /palmface-intake /palmface-deep-plan /palmface-metaplan$" && printf "%s" "$out" | grep -q "/palmface-autopilot$"' "$out"
mkdir -p "$H/.config/palmface/cows" "$P/.autopilot"
printf 'cow\n' > "$H/.config/palmface/cows/owl.cow"
printf 'cow\n' > "$H/.config/palmface/cows/cat.cow"
: > "$P/.autopilot/on" # the old in-project switch, as a cloned repository might ship it
printf -- '- sign in to the store\n' > "$P/.autopilot/queue.md"
out=$(start PATH="$STUB:$GITDIR:$BARE"); rc=$?
check "start: a .autopilot/on inside the project is ignored (autopilot off)" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "^│ autopilot  off$"' "$out"
(cd "$P" && sealed "$H/.claude/palmface/state" "$H" PATH="$BARE" /bin/bash "$H/.claude/skills/palmface-autopilot/autopilot.sh" on) > /dev/null 2>&1
HS0=$(snapshot "$H")
out=$(start PATH="$STUB:$(hour_stub 03):$GITDIR:$BARE"); rc=$?
check "start at night with the cows installed: an owl" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "^COW owl: "' "$out"
out=$(start PATH="$STUB:$(hour_stub 13):$GITDIR:$BARE"); rc=$?
check "start by day: a cat" 'printf "%s" "$out" | grep -q "^COW cat: "' "$out"
check "start: autopilot on for this folder, with the queue" \
  'printf "%s" "$out" | grep -q "^│ autopilot  on (this folder)$" && printf "%s" "$out" | grep -q "^│ queue      1 waiting for you"' "$out"
out=$(start PATH="$STUB:$GITDIR:$BARE" PALMFACE_AUTOPILOT=on); rc=$?
check "start: PALMFACE_AUTOPILOT=on is shown as the reason" 'printf "%s" "$out" | grep -q "^│ autopilot  on (PALMFACE_AUTOPILOT)$"' "$out"
out=$( (cd "$P" && sealed - "$H" PATH="$STUB:$GITDIR:$BARE" /bin/bash "$ST" --plain) 2> "$ERR"); rc=$?
check "start --plain: no banner and no cow, the card still there" \
  '[ $rc -eq 0 ] && ! printf "%s" "$out" | grep -qE "^(LOL|FIGLET|COW)" && printf "%s" "$out" | grep -q "^╭─ proj$"' "$out"
out=$(start PATH="$BARE"); rc=$?
check "start on a bare PATH (no figlet, lolcat or cowsay): exit 0, quiet stderr, the card" \
  '[ $rc -eq 0 ] && [ ! -s "$ERR" ] && printf "%s" "$out" | grep -q "^╰─$"' "rc=$rc $(cat "$ERR")"
mkdir -p "$H/plain dir"
HS0=$(snapshot "$H")
out=$( (cd "$H/plain dir" && sealed - "$H" PATH="$GITDIR:$BARE" /bin/bash "$ST" --plain) 2> "$ERR"); rc=$?
check "start outside a repository says so" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "^│ git        not a git repository$" && printf "%s" "$out" | grep -q "^session name: plain-dir-"' "$out"
check "start wrote nothing anywhere in the home" '[ "$(snapshot "$H")" = "$HS0" ]' "$(snap_diff "$HS0" "$(snapshot "$H")")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "6. /palmface-chain: needs a permission mode, stops at a HUMAN GATE, and a dry run starts nothing"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1) || bad "install --claude --no-post" "$out"
R="$H/work/repo"
D="$R/docs/plans/demo"
mkdir -p "$D"
GIT -C "$R" -c init.defaultBranch=main init -q
printf '# Session 1\nBuild the thing.\n' > "$D/v1-session-prompt.md"
printf '# Session 2\nBuild more.\n' > "$D/v2-session-prompt.md"
printf '# Session 3\n\n## ⚠️ HUMAN GATE: publish\nWait for the owner.\n' > "$D/v3-session-prompt.md"
printf 'done\n' > "$D/v1-handoff.md"
GIT -C "$R" add -A && GIT -C "$R" commit -qm plan
CH="$H/.claude/skills/palmface-chain/scripts/chain.sh"
chain() { sealed - "$H" PATH="$STUB:$GITDIR:$BARE" /bin/bash "$CH" "$@" 2> "$ERR"; }
HS0=$(snapshot "$H")
out=$(chain run "$D" --dry-run); rc=$?
check "run without --permission-mode refuses (exit 2) and says why" '[ $rc -eq 2 ] && grep -q "permission-mode is required" "$ERR"' "rc=$rc $(cat "$ERR")"
out=$(chain run "$D" --permission-mode acceptEdits --dry-run); rc=$?
check "dry run: exit 0, from the first prompt without a handoff (v2), stopping before the gate (v3)" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "sessions v2..v2" && printf "%s" "$out" | grep -q "v3 is a HUMAN GATE"' "rc=$rc $out $(cat "$ERR")"
check "dry run: each session runs headless with PALMFACE_AUTOPILOT=on and the chosen mode, never a bypass flag" \
  'printf "%s" "$out" | grep "^would run (session" | grep -q "PALMFACE_AUTOPILOT=on .* -p .*--permission-mode acceptEdits" && ! printf "%s" "$out" | grep -q dangerously' "$out"
check "dry run: neither tmux nor claude was started, and nothing was written" \
  '[ "$(calls tmux)" = 0 ] && [ "$(calls claude)" = 0 ] && [ "$(snapshot "$H")" = "$HS0" ]' "$(snap_diff "$HS0" "$(snapshot "$H")")"
mkdir -p "$R/.autopilot"
printf -- '- a decision\n' > "$R/.autopilot/decisions.md"
: > "$R/REVIEW.md"
out=$(chain run "$D" --permission-mode acceptEdits --dry-run); rc=$?
check "the autopilot record (.autopilot/, REVIEW.md) does not count as a dirty tree" '[ $rc -eq 0 ]' "rc=$rc $(cat "$ERR")"
printf 'wip\n' > "$R/wip.txt"
out=$(chain run "$D" --permission-mode acceptEdits --dry-run); rc=$?
check "other uncommitted work refuses the run (exit 69)" '[ $rc -eq 69 ] && grep -q "not clean" "$ERR"' "rc=$rc $(cat "$ERR")"
rm -f "$R/wip.txt"
out=$(chain run "$D" --permission-mode acceptEdits --name ../../escape --dry-run); rc=$?
check "a chain name that could leave the state folder is refused" '[ $rc -eq 2 ]' "rc=$rc $(cat "$ERR")"
out=$(chain run "$D" --permission-mode 'x;rm' --dry-run); rc=$?
check "a permission mode that isn't a word is refused" '[ $rc -eq 2 ]' "rc=$rc $(cat "$ERR")"
out=$(chain run "$D" --from 3 --permission-mode acceptEdits --dry-run); rc=$?
check "starting at a HUMAN GATE prompt is refused" '[ $rc -eq 71 ]' "rc=$rc $(cat "$ERR")"
out=$(chain status "$D"); rc=$?
check "status works with no tmux server and no log" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "not running"' "rc=$rc $out"
check "the chain script has no permission-bypass default anywhere" '! grep -q -- "--dangerously-skip-permissions" "$CH"'
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "7. /palmface-sessions lists titles and first lines, read-only, and nothing more"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --claude --no-post 2>&1) || bad "install --claude --no-post" "$out"
T="$H/.claude/projects/-work-app"
mkdir -p "$T/s-new/subagents"
{
  printf '%s\n' '{"type":"user","cwd":"/work/my app","isSidechain":false,"message":{"role":"user","content":"fix the login form with key sk-test-aaaaaaaaaaaa please"}}'
  printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"PRIVATE-REPLY-BODY"}]}}'
  printf '%s\n' '{"type":"custom-title","customTitle":"login-fix-nov15","sessionId":"s-new"}'
} > "$T/s-new.jsonl"
printf '%s\n' '{"type":"user","cwd":"/work/x","message":{"role":"user","content":"SUBAGENT-PROMPT"}}' > "$T/s-new/subagents/agent-1.jsonl"
printf '%s\n' '{"type":"user","cwd":"/work/o\"$(id)","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"tidy the readme\nsecond line"}]}}' > "$T/s-old.jsonl"
touch -t 202601010101 "$T/s-old.jsonl"
SE="$H/.claude/skills/palmface-sessions/scripts/sessions.sh"
sess() { sealed - "$H" PATH="$FULL" /bin/bash "$SE" "$@" 2> "$ERR"; }
HS0=$(snapshot "$H")
out=$(sess); rc=$?
check "sessions: exit 0, newest first, the /rename title, then the first line of an unnamed one" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -v "^    in:" | sed -E "s/^[0-9-]+ [0-9:]+  //")" = "$(printf "s-new  login-fix-nov15\ns-old  tidy the readme")" ]' "rc=$rc $out $(cat "$ERR")"
check "sessions: no reply text, no later lines, no subagent transcripts" \
  '! printf "%s" "$out" | grep -qE "PRIVATE-REPLY-BODY|second line|SUBAGENT-PROMPT"' "$out"
check "sessions: the resume line quotes a folder name safely" \
  'printf "%s" "$out" | grep -qF "resume: cd /work/o\\\"\\\$\\(id\\) && claude --resume s-old"' "$out"
out=$(sess --search login); rc=$?
check "sessions --search shows a key-shaped word as [hidden], never the key" \
  '[ $rc -eq 0 ] && [ "$(printf "%s\n" "$out" | grep -c "^[0-9]")" = 1 ]' "$out"
printf '%s\n' '{"type":"user","cwd":"/work/z","message":{"role":"user","content":"deploy with sk-test-bbbbbbbbbbbbbbbb now"}}' > "$T/s-key.jsonl"
HS0=$(snapshot "$H")
out=$(sess --search deploy); rc=$?
check "sessions: a key in the first prompt is hidden" 'printf "%s" "$out" | grep -q "deploy with \[hidden\] now" && ! printf "%s" "$out" | grep -q bbbbbbbb' "$out"
out=$(sess --named); rc=$?
check "sessions --named keeps only named ones" '[ "$(printf "%s\n" "$out" | grep -c "^[0-9]")" = 1 ] && printf "%s" "$out" | grep -q login-fix' "$out"
NOJQ="$WORK/nojq"
mkdir -p "$NOJQ"
for t in bash sh grep tail head date stat basename ls tr sed cat; do ln -sf "$(PATH=$BARE command -v "$t")" "$NOJQ/$t"; done
out=$(sealed - "$H" PATH="$NOJQ" /bin/bash "$SE" 2> "$ERR"); rc=$?
check "sessions without jq exits 3 and says what to install" '[ $rc -eq 3 ] && grep -q "jq is required" "$ERR"' "rc=$rc $(cat "$ERR")"
check "sessions wrote nothing" '[ "$(snapshot "$H")" = "$HS0" ]' "$(snap_diff "$HS0" "$(snapshot "$H")")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "8. extras: the launcher (camp) against a fake projects folder, and the persona and voice starters"
H=$(new_home) || exit 2
S0=$(snapshot "$H")
out=$(kit_run "$KIT" "$H" install.sh --extras --no-post 2>&1); rc=$?
check "install --extras --no-post exits 0" '[ $rc -eq 0 ]' "$out"
check "the launcher and its ~/.zshrc block land" \
  '[ -s "$H/.config/palmface/zsh/launcher.zsh" ] && [ "$(cat "$H/.zshrc")" = "$(printf "# >>> palmface:extras >>>\n%s\n# <<< palmface:extras <<<" "$(cat "$KIT/extras/zsh/zshrc.block")")" ]' "$(cat "$H/.zshrc")"
check "the persona and voice starters land in ~/.claude/palmface/templates" \
  '[ "$(ls "$H/.claude/palmface/templates" | tr "\n" " ")" = "persona.md voice.md " ]'
check "~/.claude/palmface-local is not created (it is the user's)" '[ ! -e "$H/.claude/palmface-local" ]'
blank=""
for t in persona voice; do
  f="$H/.claude/palmface/templates/$t.md"
  grep -q "cp ~/.claude/palmface/templates/$t.md ~/.claude/palmface-local/$t.md" "$f" || blank="$blank $t:no-copy-line"
  rest=$(awk '/<!--/ { c = 1 } !c { print } /-->/ { c = 0 }' "$f" | grep -vE '^(#.*|- *|- I (never )?use: *|[[:space:]]*)$')
  [ -z "$rest" ] || blank="$blank $t:[$rest]"
done
check "both starters are blank: headings, empty bullets and guidance comments only, with the copy line" '[ -z "$blank" ]' "$blank"
mkdir -p "$H/Projects/alpha/.git" "$H/Projects/beta/api/.git" "$H/Projects/beta/web/.git" "$H/Projects/notes" \
  "$H/Projects/old/.git" "$H/Projects/.hidden/.git" "$H/My Code/zeta/.git" \
  "$H/Projects/plaingroup/sub" "$H/Projects/scratch" "$H/Projects/.plainhidden" "$H/Vacant"
printf 'ref: refs/heads/main\n' > "$H/Projects/alpha/.git/HEAD"
printf 'ref: refs/heads/dev\n' > "$H/Projects/beta/api/.git/HEAD"
mkdir -p "$WORK/fzf" # an fzf that picks the notes line out of what camp hands it
printf '#!/bin/bash\nexec awk -F "\\t" '\''$1 == "notes"'\''\n' > "$WORK/fzf/fzf"
chmod 755 "$WORK/fzf/fzf"
camp() { # stdin, env..., zsh code: run code in a zsh that read the installed ~/.zshrc, writing nothing
  local code
  code=${*: -1}
  sealed - "$H" PATH="$BARE" PALMFACE_LAUNCH_CMD="$STUB/launch" "${@:1:$#-1}" /bin/zsh -f -c "source ~/.zshrc; $code" 2> "$ERR"
}
HS0=$(snapshot "$H")
out=$(camp 'camp --list'); rc=$?
check "camp --list: every folder in ~/Projects by name, plain ones like notes too, a folder of repos as a group; no hidden (git or plain) or other folders" \
  '[ $rc -eq 0 ] && [ "$out" = "$(printf "alpha\t%s\nbeta/\t%s\nbeta/api\t%s\nbeta/web\t%s\nnotes\t%s\nold\t%s\nplaingroup\t%s\nscratch\t%s" "$H/Projects/alpha" "$H/Projects/beta" "$H/Projects/beta/api" "$H/Projects/beta/web" "$H/Projects/notes" "$H/Projects/old" "$H/Projects/plaingroup" "$H/Projects/scratch")" ]' "rc=$rc $out $(cat "$ERR")"
check "camp --list stays name TAB folder: two columns on every line, no plain-folder marker in a name" \
  '[ -z "$(printf "%s\n" "$out" | awk -F "\t" "NF != 2")" ] && ! printf "%s" "$out" | grep -q "plain folder"' "$out"
mkdir -p "$H/.claude/palmface-local"
printf '# hidden from the menu\nold\nbeta/web\nscratch\n' > "$H/.claude/palmface-local/projects.ignore"
HS0=$(snapshot "$H")
out=$(camp PALMFACE_PROJECTS_DIR="$H/Projects:$H/My Code" 'camp --list'); rc=$?
check "camp: your ignore list hides names, plain folders too (scratch), and group/name; PALMFACE_PROJECTS_DIR scans several folders, spaces and all" \
  '[ "$(printf "%s\n" "$out" | cut -f1 | tr "\n" " ")" = "alpha beta/ beta/api notes plaingroup zeta " ]' "$out"
out=$(camp 'camp -p ap'); rc=$?
check "camp -p: the first match's folder, starting nothing" '[ $rc -eq 0 ] && [ "$out" = "$H/Projects/beta/api" ] && [ "$(calls launch)" = 0 ]' "rc=$rc $out"
out=$(camp 'camp alp --model opus'); rc=$?
check "camp <query> [args]: starts in that project with the args" \
  '[ $rc -eq 0 ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/alpha args=--model opus" ]' "rc=$rc $out $(cat "$ERR")"
out=$(printf '2\n2.1r+1\n' | camp 'camp'); rc=$?
check "the menu: 2 opens the group; 2.1r+1 starts in beta/api with --continue and --add-dir for alpha" \
  '[ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/beta/api args=--continue --add-dir $H/Projects/alpha" ] && printf "%s" "$out" | grep -q "2.1.*api.*dev"' "$out $(cat "$ERR")"
out=$(printf '1w\n' | camp 'camp --model haiku'); rc=$?
check "the menu: leading claude flags pass through; w asks for a worktree" \
  '[ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/alpha args=--worktree --model haiku" ]' "$(tail -1 "$LOGS/launch.log")"
# With the ignore list on, the menu is: 1 alpha, 2 beta (a group: api), 3 notes, 4 plaingroup.
menu=$(printf 'q\n' | camp 'camp'); rc=$?
plain=$(printf '%s\n' "$menu" | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g')
dim_b=$(printf '%s\n' "$menu" | LC_ALL=C sed -n 's/.* alpha *\(\x1b\[[0-9;]*m\)main.*/\1/p')
dim_p=$(printf '%s\n' "$menu" | LC_ALL=C sed -n 's/.* notes *\(\x1b\[[0-9;]*m\)plain folder.*/\1/p')
check "the menu marks notes (and plaingroup) with a dim plain folder where a git project shows its branch" \
  '[ $rc -eq 0 ] && printf "%s\n" "$plain" | grep -qE " notes +plain folder$" && printf "%s\n" "$plain" | grep -qE " plaingroup +plain folder$" && printf "%s\n" "$plain" | grep -qE " alpha +main$" && [ "$(printf "%s\n" "$plain" | grep -c "plain folder")" = 2 ] && [ -n "$dim_b" ] && [ "$dim_p" = "$dim_b" ]' "$plain"
NOTICE="is not a git project; starting without a worktree"
n=$(calls launch)
out=$(printf '3w\n' | camp 'camp'); rc=$?
check "the menu: Nw on notes (no .git) starts there without --worktree and prints the notice" \
  '[ "$(calls launch)" = $((n + 1)) ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/notes args=" ] && printf "%s\n" "$out" | grep -qxF "camp: notes $NOTICE"' "$out $(cat "$ERR") $(tail -1 "$LOGS/launch.log")"
n=$(calls launch)
out=$(printf '2.0w\n' | camp 'camp'); rc=$?
check "the menu: N.0w on a group folder without .git (beta) starts there without --worktree and prints the notice" \
  '[ "$(calls launch)" = $((n + 1)) ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/beta args=" ] && printf "%s\n" "$out" | grep -qxF "camp: beta $NOTICE"' "$out $(cat "$ERR") $(tail -1 "$LOGS/launch.log")"
n=$(calls launch)
out=$(printf '4.0wr\n' | camp 'camp'); rc=$?
check "the menu: N.0wr on plaingroup (only plain subfolders, so not a group) starts with --continue only and prints the notice" \
  '[ "$(calls launch)" = $((n + 1)) ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/plaingroup args=--continue" ] && printf "%s\n" "$out" | grep -qxF "camp: plaingroup $NOTICE"' "$out $(cat "$ERR") $(tail -1 "$LOGS/launch.log")"
out=$(printf '2.1w\n' | camp 'camp'); rc=$?
check "the menu: N.Mw inside a group still asks for a worktree, with no notice" \
  '[ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/beta/api args=--worktree" ] && ! printf "%s" "$out" | grep -qF "$NOTICE"' "$out $(cat "$ERR")"
n=$(calls launch)
out=$(printf 'f\n' | camp PATH="$WORK/fzf:$BARE" 'camp'); rc=$?
check "the menu: f hands the name TAB folder lines to fzf and starts in the picked plain folder (notes)" \
  '[ "$(calls launch)" = $((n + 1)) ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/notes args=" ]' "$out $(cat "$ERR")"
n=$(calls launch)
out=$(camp 'camp -p not'); rc=$?
out2=$(camp 'camp plaing --model opus'); rc2=$?
check "camp -p and camp <query> reach plain folders like any project (notes, plaingroup)" \
  '[ $rc -eq 0 ] && [ "$out" = "$H/Projects/notes" ] && [ $rc2 -eq 0 ] && [ "$(calls launch)" = $((n + 1)) ] && [ "$(tail -1 "$LOGS/launch.log")" = "cwd=$H/Projects/plaingroup args=--model opus" ]' "rc=$rc $out rc2=$rc2 $out2 $(cat "$ERR")"
n=$(calls launch)
out=$(printf 'zz\n9\nq\n' | camp 'camp'); rc=$?
check "the menu: a bad choice is explained, q leaves, nothing starts" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "isn.t a choice" && printf "%s" "$out" | grep -q "there is no 9" && [ "$(calls launch)" = "$n" ]' "$out"
out=$(camp 'camp() { echo mine; }; source ~/.config/palmface/zsh/launcher.zsh; camp'); rc=$?
check "your own camp wins; palmface-camp is always there" '[ "$out" = mine ]' "$out"
mkdir -p "$WORK/lateprog"
printf '#!/bin/sh\necho mine-late\n' > "$WORK/lateprog/camp"
chmod 755 "$WORK/lateprog/camp"
out=$(camp 'source ~/.config/palmface/zsh/launcher.zsh; path=('"$WORK"'/lateprog $path); camp; palmface-camp --list | head -1 | cut -f1'); rc=$?
check "a camp program put on PATH after the launcher is sourced runs instead; palmface-camp --list still works" \
  '[ "$(printf "%s\n" "$out" | sed -n 1p)" = mine-late ] && [ -n "$(printf "%s\n" "$out" | sed -n 2p)" ]' "$out $(cat "$ERR")"
out=$(camp PALMFACE_LAUNCHER=off 'whence -w palmface-camp camp'); rc=$?
check "PALMFACE_LAUNCHER=off defines nothing" '[ $rc -ne 0 ] && printf "%s" "$out" | grep -q "camp: none"' "$out"
out=$(camp PALMFACE_PROJECTS_DIR="$H/empty" 'camp'); rc=$?
check "no projects: exit 1 and a hint to set PALMFACE_PROJECTS_DIR" '[ $rc -eq 1 ] && grep -q PALMFACE_PROJECTS_DIR "$ERR"' "rc=$rc $(cat "$ERR")"
out=$(camp PALMFACE_PROJECTS_DIR="$H/Vacant" 'camp --list; r=$?; camp; print -r -- $r $?'); rc=$?
check "an empty projects folder: camp --list and camp both say no projects and exit 1" \
  '[ "$out" = "1 1" ] && [ "$(grep -cxF "camp: no projects in $H/Vacant. Set PALMFACE_PROJECTS_DIR to the folder(s) that hold them." "$ERR")" = 2 ]' "$out $(cat "$ERR")"
check "the launcher wrote nothing" '[ "$(snapshot "$H")" = "$HS0" ]' "$(snap_diff "$HS0" "$(snapshot "$H")")"
# A repository's own .git/HEAD (OSC 52) and a folder name (CSI) carrying terminal escapes.
ESC=$(printf '\033') BEL=$(printf '\007')
mkdir -p "$H/Esc/pl/.git" "$H/Esc/r${ESC}[31mx/.git"
printf 'ref: refs/heads/ma%s]52;c;aGk=%sin\n' "$ESC" "$BEL" > "$H/Esc/pl/.git/HEAD"
menu=$(printf 'q\n' | camp PALMFACE_PROJECTS_DIR="$H/Esc" 'camp')
lst=$(camp PALMFACE_PROJECTS_DIR="$H/Esc" 'camp --list')
raw_left=$(printf '%s%s' "$menu" "$lst" | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g' | LC_ALL=C tr -cd '\033\007' | wc -c | tr -d ' ')
check "camp shows escapes from .git/HEAD and folder names as ?, in the menu and in --list" \
  '[ "$raw_left" = 0 ] && printf "%s" "$menu" | grep -qF "ma?]52;c;aGk=?in" && printf "%s" "$lst" | grep -qF "r?[31mx" && printf "%s" "$menu" | grep -qF "r?[31mx"' "$menu$lst"
rm -rf "$H/Esc"
rm -rf "$H/Projects" "$H/My Code" "$H/Vacant" "$H/.claude/palmface-local"
out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
S=$(snapshot "$H")
check "uninstall exits 0 and the home is back exactly" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out
$(snap_diff "$S0" "$S")"
rm_home "$H"

# ─────────────────────────────────────────────────────────────────────────────────────────
echo
echo "9. what lands points at no one's machine, and the plugin list names only the public marketplace"
H=$(new_home) || exit 2
out=$(kit_run "$KIT" "$H" install.sh --all --no-post 2>&1) || bad "install --all --no-post" "$out"
n=$(find "$H/.claude/skills" "$H/.claude/palmface/templates" "$H/.config/palmface/zsh/launcher.zsh" -type f | wc -l | tr -d ' ')
hits=$(grep -rIlE -e "/Users/|/var/folders/|/private/(var|tmp)/" \
  -e "(~|\\\$HOME|\\\$\\{HOME\\})/\\.claude/(hooks|checkpoints|references|scripts|agents|commands|metrics)(/|\$)" \
  "$H/.claude/skills" "$H/.claude/palmface/templates" "$H/.config/palmface/zsh/launcher.zsh" 2> /dev/null)
hits="$hits$(grep -rIlF -e "$H" -e "$REAL_HOME/" -e "$TMP_ROOT" "$H/.claude/skills" "$H/.claude/palmface/templates" "$H/.config/palmface/zsh" 2> /dev/null)"
check "no installed skill, starter or launcher file ($n of them) holds an absolute home path or a path into another setup" \
  '[ "$n" -gt "$NSKILLS" ] && [ -z "$hits" ]' "$hits"
rm_home "$H"
PL="$KIT/docs/plugins.md"
check "docs/plugins.md installs only from claude-plugins-official and adds only its public repo" \
  '[ -s "$PL" ] && [ -z "$(grep -oE "@[A-Za-z0-9_.-]+" "$PL" | grep -v "^@claude-plugins-official$")" ] && [ -z "$(grep -E "marketplace add" "$PL" | grep -v "marketplace add anthropics/claude-plugins-official$")" ]' \
  "$(grep -nE "@|marketplace add" "$PL")"
check "docs/plugins.md names superpowers, which the skills point at" 'grep -q "^| \`superpowers\` |" "$PL"'

summary "smoke-skills"

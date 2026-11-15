#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2088  # check() conditions are eval'd later; descriptions name ~ paths
# integration.sh: the README's own steps, run exactly as written, by a stranger who cloned the
# published tree (this tree minus docs/plans/ and REVIEW.md), in throwaway fake homes. Then
# checks that the README, the notices and the code agree with each other. Never touches the
# real home (see tests/lib.sh) and never uses the network.
#
# Usage: tests/integration.sh
#
# Every README block marked <!-- tested: NAME --> is typed line by line into an interactive zsh,
# the way a user pastes it. Only git and brew are stubs: "git clone" unpacks the published tree, and brew only
# checks that its Brewfile is there. Each line runs under sandbox-exec (stock macOS), with
# writes allowed only into the fake home and this test's work folder, and no outbound network,
# so the post scripts meet a real offline install.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

README="$KIT/README.md"
NOTICES="$KIT/THIRD-PARTY-NOTICES.md"
WORK=$(mktemp -d "$TMP_ROOT/palmface-integration.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
LOGS="$WORK/logs" STUB="$WORK/stub" TMPW="$WORK/tmp"
mkdir -p "$LOGS" "$STUB" "$TMPW"
BREW_BIN=""
for d in /opt/homebrew/bin /usr/local/bin; do
  if [ -x "$d/brew" ]; then BREW_BIN=$d; break; fi
done
SBX=$(command -v sandbox-exec 2> /dev/null || true)
skip() { printf '  skip  %s\n' "$1"; }
[ -n "$SBX" ] || skip "sandbox-exec not found: writes are checked by snapshot only, and offline is simulated"

# The published tree, as a stranger's clone would have it.
(cd "$KIT" && git ls-files -co --exclude-standard | grep -vE '^(docs/plans/|REVIEW\.md$)' |
  while IFS= read -r f; do if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\n' "$f"; fi; done) > "$WORK/public.list"
tar -cf "$WORK/public.tar" -C "$KIT" -T "$WORK/public.list" 2> /dev/null || die "cannot pack the published tree"

# Stubs. git clone <url> <dir> unpacks the published tree into <dir>; any other git is the real one.
printf '#!/bin/bash\nif [ "${1:-}" = clone ]; then\n  printf "%%s\\n" "$*" >> "%s/git.log"\n  d=${@: -1}\n  mkdir -p "$d" && exec tar -xf "%s/public.tar" -C "$d"\nfi\nexec /usr/bin/git "$@"\n' \
  "$LOGS" "$WORK" > "$STUB/git"
printf '#!/bin/bash\nprintf "cwd=%%s args=%%s\\n" "$PWD" "$*" >> "%s/brew.log"\nfor a in "$@"; do\n  case $a in --file=*) [ -f "${a#--file=}" ] || { echo "brew (stub): no ${a#--file=} here" >&2; exit 1; } ;; esac\ndone\n' \
  "$LOGS" > "$STUB/brew"
chmod 755 "$STUB"/*

sealed() { # fake home, command...: a clean env with HOME=<fake>; writes only to the home and $WORK; no network
  local h=$1
  shift
  guard_home "$h"
  if [ -n "$SBX" ]; then
    "$SBX" -p "(version 1)(allow default)
      (deny network-outbound (remote ip))
      (deny file-write* (require-not (require-any (subpath \"$h\") (subpath \"$WORK\")
        (literal \"/dev/null\") (literal \"/dev/tty\") (regex #\"^/dev/fd/\"))))" \
      env -i HOME="$h" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" "$@"
  else
    env -i HOME="$h" TERM=xterm-256color STARSHIP_CACHE="$WORK/starship-cache" PALMFACE_GIT_BASE="file://$WORK/offline" "$@"
  fi
}

block() { # name: the lines of the fenced block right after <!-- tested: name --> in the README
  awk -v want="<!-- tested: $1 -->" '
    state == 0 && $0 == want { state = 1; next }
    state == 1 { if ($0 ~ /^```/) { state = 2; next } if (NF) exit; next }
    state == 2 { if ($0 ~ /^```/) exit; print }' "$README"
}

CWD="" OUT="" RC=0 CLONED=""
run_line() { # fake home, block name, line: one README line typed into an interactive zsh in $CWD; sets OUT, RC, CWD
  # Interactive, from stdin, as a paste is: with zsh's defaults a "#" is an argument there, not
  # a comment, so a README line that only works as a script fails here too.
  local h=$1 name=$2 line=$3
  rm -f "$WORK/rc" "$WORK/cwd"
  OUT=$(printf '%s\n' 'cd -- "$KCWD" || exit 99' "$line" 'print -r -- $? > "$KRC"; pwd > "$KPWD"; exit' |
    sealed "$h" PATH="$STUB:${BREW_BIN:+$BREW_BIN:}/usr/bin:/bin:/usr/sbin:/sbin" SHELL=/bin/zsh \
      USER="$(id -un)" LANG=en_US.UTF-8 TMPDIR="$TMPW" PS1= PS2= PROMPT_EOL_MARK= \
      KCWD="$CWD" KRC="$WORK/rc" KPWD="$WORK/cwd" /bin/zsh -f -i 2>&1)
  RC=98 # zsh never reached the line after it
  if [ -f "$WORK/rc" ]; then RC=$(cat "$WORK/rc"); fi
  if [ -f "$WORK/cwd" ]; then CWD=$(cat "$WORK/cwd"); fi
  printf '$ %s\n%s\n[exit %s]\n' "$line" "$OUT" "$RC" >> "$LOGS/session.$name.log"
}

run_block() { # fake home, block name: every line of a tested block, in order, each checked
  local h=$1 name=$2 code line cmd first before after
  code=$(block "$name")
  check "the README has the tested block \"$name\"" '[ -n "$code" ]'
  while IFS= read -r line <&3; do
    case "$line" in '' | '#'*) continue ;; esac
    cmd=$(printf '%s' "$line" | sed -E 's/[[:space:]]+#.*$//')
    first=${cmd%% *}
    case "$first" in
      git | cd | brew | ./install.sh | ./uninstall.sh | '~/.palmface-backup/uninstall.sh' | mkdir | cp | bash) ;;
      *)
        bad "[$name] \"$first\" is a command this test doesn't know yet: teach tests/integration.sh"
        continue
        ;;
    esac
    case "$cmd" in *--dry-run* | *' report'*) before=$(snapshot "$h") ;; esac
    run_line "$h" "$name" "$line"
    check "[$name] \$ $cmd" '[ $RC -eq 0 ]' "$OUT"
    case "$cmd" in
      *--dry-run* | *' report'*)
        after=$(snapshot "$h")
        check "[$name]   ...and it wrote nothing" '[ "$after" = "$before" ]' "$(snap_diff "$before" "$after")"
        ;;
    esac
    if [ "$first" = git ]; then CLONED=$(snapshot "$h"); fi
  done 3< <(printf '%s\n' "$code")
}

clone_dir() { if [ -f "$LOGS/git.log" ]; then tail -1 "$LOGS/git.log" | awk '{ print $NF }'; fi; }
not_local() { grep -v -e ' \./\.claude/palmface-local' -e '^D [0-9]* \./\.claude$'; } # snapshot minus the user's folder

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "1. the README's install, the starters, the report and the uninstall, as written"
for seed in empty seeded; do
  echo "== $seed home"
  rm -f "$LOGS"/*.log
  H=$(new_home) || exit 2
  if [ "$seed" = seeded ]; then seed_home "$H"; fi
  S0=$(snapshot "$H")
  CWD=$H CLONED=""
  run_block "$H" install
  C=$(clone_dir)
  check "the clone line cloned a .git URL into the home" \
    '[ -n "$C" ] && case "$C" in "$H"/*) true ;; *) false ;; esac && [ -x "$C/install.sh" ] && tail -1 "$LOGS/git.log" | grep -qE "\.git [^ ]+$"' \
    "$(cat "$LOGS/git.log" 2> /dev/null)"
  check "brew ran once, from the clone, and found its Brewfile there" \
    '[ "$(wc -l < "$LOGS/brew.log" | tr -d " ")" = 1 ] && grep -qF "cwd=$C args=bundle --file=" "$LOGS/brew.log"' \
    "$(cat "$LOGS/brew.log" 2> /dev/null)"
  check "install printed the same brew bundle line the README gives" \
    'grep -qF "brew bundle --file=" "$LOGS/session.install.log" && block install | grep -q "^brew bundle --file="'
  check "offline: the plugin post script warned once and the install went on" \
    '[ "$(grep -cE "palmface: (could not clone|git is not available)" "$LOGS/session.install.log")" = 1 ]' \
    "$(grep -i 'palmface:' "$LOGS/session.install.log")"
  check "offline: no plugin and no partial clone on disk" \
    '[ -z "$(ls -A "$H/.config/palmface/tmux/plugins" 2> /dev/null)" ]' "$(ls -A "$H/.config/palmface/tmux/plugins" 2> /dev/null)"
  check_manifest "$H"
  S1=$(snapshot "$H")

  again=$(block install | sed -E 's/[[:space:]]+#.*$//' | grep '^\./install\.sh' | grep -v -- '--dry-run' | tail -1)
  run_line "$H" install "$again"
  S=$(snapshot "$H")
  check "running \"$again\" again exits 0 and changes nothing" '[ $RC -eq 0 ] && [ "$S" = "$S1" ]' "$OUT$(snap_diff "$S1" "$S")"

  missing=""
  while IFS= read -r p; do
    case "$p" in '~/.claude/palmface/sounds.off') continue ;; esac # the README asks you to create it
    case "$p" in '~/.claude/palmface/state/'*) continue ;; esac # made at run time, by hooks and skills
    case "$p" in '~/.config/palmface/tmux/plugins/'?*) continue ;; esac # cloned online; this test is offline
    [ -e "$H/${p#\~/}" ] || missing="$missing $p"
  done < <(grep -oE '~/\.(claude|config)/palmface/[A-Za-z0-9._/<>-]*|~/\.claude/skills/palmface-[a-z-]+' "$README" |
    sed -E 's/[.,]+$//' | grep -v '<' | sort -u)
  check "every kit path the README names is installed by --all" '[ -z "$missing" ]' "missing:$missing"

  run_block "$H" starters
  check "the starters landed in palmface-local, unchanged" \
    'cmp -s "$H/.claude/palmface-local/persona.md" "$H/.claude/palmface/templates/persona.md" &&
     cmp -s "$H/.claude/palmface-local/voice.md" "$H/.claude/palmface/templates/voice.md"'
  L0=$(snapshot "$H/.claude/palmface-local")
  run_block "$H" report
  check "the report says there is no usage yet" 'printf "%s" "$OUT" | grep -q "No usage recorded yet"' "$OUT"

  run_block "$H" uninstall
  S=$(snapshot "$H")
  L=$(snapshot "$H/.claude/palmface-local")
  check "palmface-local is left exactly as it was" '[ -n "$L0" ] && [ "$L" = "$L0" ]' "$(snap_diff "$L0" "$L")"
  if printf '%s\n' "$S0" | grep -q '^D [0-9]* \./\.claude$'; then
    check "uninstall restores the cloned home exactly, apart from palmface-local" \
      '[ "$(printf "%s\n" "$S" | not_local)" = "$(printf "%s\n" "$CLONED" | not_local)" ]' \
      "$(snap_diff "$(printf '%s\n' "$CLONED" | not_local)" "$(printf '%s\n' "$S" | not_local)")"
    check "the backup folder is gone" '[ ! -e "$H/.palmface-backup" ]' "$(ls -A "$H/.palmface-backup" 2> /dev/null)"
  else # Palmface made ~/.claude, and palmface-local keeps it: the case the README's Uninstall section names
    check "uninstall says ~/.claude stays, and keeps its record in ~/.palmface-backup (as the README says)" \
      'grep -qF ".claude/ is not empty, so it stays" "$LOGS/session.uninstall.log" &&
       ls "$H/.palmface-backup"/manifest.uninstalled-*.tsv > /dev/null 2>&1' "$(cat "$LOGS/session.uninstall.log")"
    check "everything else comes back exactly" \
      '[ "$(printf "%s\n" "$S" | not_local | grep -v " \./\.palmface-backup")" = "$(printf "%s\n" "$CLONED" | not_local)" ]' \
      "$(snap_diff "$(printf '%s\n' "$CLONED" | not_local)" "$(printf '%s\n' "$S" | not_local | grep -v ' \./\.palmface-backup')")"
  fi
  rm_home "$H"

  echo "== $seed home, clone deleted before uninstall"
  rm -f "$LOGS"/*.log
  H=$(new_home) || exit 2
  if [ "$seed" = seeded ]; then seed_home "$H"; fi
  S0=$(snapshot "$H")
  CWD=$H CLONED=""
  run_block "$H" install
  C=$(clone_dir)
  case "$C" in "$H"/?*) rm -rf "$C" ;; *) die "clone dir '$C' is not inside the fake home" ;; esac
  CWD=$H
  run_block "$H" uninstall-no-clone
  S=$(snapshot "$H")
  check "with the clone gone, ~/.palmface-backup/uninstall.sh restores the home exactly" \
    '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"
  rm_home "$H"
done

# ─────────────────────────────────────────────────────────────────────────────────────────
echo "2. the README, the notices and the code agree"
commented=$(awk '/^```/ { if (open) { open = 0; sh = 0 } else { open = 1; sh = ($0 ~ /^```(sh|bash|zsh)$/) } next }
  open && sh && /(^|[[:space:]])#/ { print NR ": " $0 }' "$README")
check "no README shell block holds a # (pasted into zsh, it would be an argument, not a comment)" \
  '[ -z "$commented" ]' "$commented"
DOCS='^(README\.md|REVIEW\.md|SECURITY\.md|THIRD-PARTY-NOTICES\.md|docs/|tests/)'
code_files() { grep -vE "$DOCS" "$WORK/public.list" | sed "s|^|$KIT/|"; }
code_sw=$(code_files | tr '\n' '\0' | xargs -0 grep -ohE 'PALMFACE_[A-Z_]+' 2> /dev/null | sort -u |
  grep -vxE 'PALMFACE_(HOME|LAYER_DIR|KIT_DIR|GREETED)') # the installer's post-script env, and an internal flag
doc_sw=$(grep -oE 'PALMFACE_[A-Z_]+' "$README" | sort -u)
check "every switch the code reads is in the README" '[ -z "$(comm -23 <(echo "$code_sw") <(echo "$doc_sw"))" ]' \
  "undocumented: $(comm -23 <(echo "$code_sw") <(echo "$doc_sw") | tr '\n' ' ')"
check "every switch the README names is read by the code" '[ -z "$(comm -13 <(echo "$code_sw") <(echo "$doc_sw"))" ]' \
  "stale: $(comm -13 <(echo "$code_sw") <(echo "$doc_sw") | tr '\n' ' ')"

shipped=$(for d in "$KIT"/skills/palmface-*/; do d=${d%/}; echo "${d##*/}"; done | sort)
named=$(grep -oE '`/palmface-[a-z-]+' "$README" | sed 's|^`/||' | sort -u) # written as `/palmface-name`
check "the README's skill list is exactly the shipped skills" '[ "$shipped" = "$named" ]' "$(diff <(echo "$shipped") <(echo "$named"))"

own=$(awk '/^## Your own files/ { on = 1; next } on && /^## / { exit } on && /^\| `/ { split($0, c, "`"); print c[2] }' "$README" |
  sed 's|/$||' | sort -u)
used=$(code_files | tr '\n' '\0' | xargs -0 grep -ohE 'palmface-local/[A-Za-z0-9._-]+' 2> /dev/null |
  sed -e 's|^palmface-local/||' -e 's|\.$||' | sort -u)
check "the README's palmface-local table is exactly the files the kit reads there" '[ -n "$own" ] && [ "$own" = "$used" ]' \
  "$(diff <(echo "$used") <(echo "$own"))"

broken=""
for doc in README.md THIRD-PARTY-NOTICES.md docs/plugins.md docs/contracts.md; do
  while IFS= read -r target; do
    rel=$(dirname "$doc")/$target
    rel=${rel#./}
    grep -qxF "$rel" "$WORK/public.list" || broken="$broken $doc->$target"
  done < <(grep -oE '\]\([^)#]+' "$KIT/$doc" | sed 's/^](//' | grep -vE '^(https?|mailto):')
done
check "every relative link in the public docs points at a published file" '[ -z "$broken" ]' "broken:$broken"
private=$(grep -vxF .gitignore "$WORK/public.list" | sed "s|^|$KIT/|" | tr '\n' '\0' |
  xargs -0 grep -lE 'docs/plans/[k]it|[.]handoff/' 2> /dev/null | sed "s|^$KIT/||")
check "no published file points at the private plan folder or the local handoff folder" '[ -z "$private" ]' "$private"

nomiss=""
for f in "$KIT"/extras/ghostty/shaders/*.glsl; do grep -qF "${f##*/}" "$NOTICES" || nomiss="$nomiss ${f##*/}"; done
while read -r repo _; do
  case "$repo" in '' | '#'*) continue ;; esac
  grep -qF "$repo" "$NOTICES" || nomiss="$nomiss $repo"
done < "$KIT/terminal/tmux/plugins.list"
for lic in statusline/LICENSE extras/ghostty/shaders/LICENSE-cursor-shaders; do
  while IFS= read -r c; do grep -qF "$c" "$NOTICES" || nomiss="$nomiss [$c]"; done < <(grep -oE '^Copyright \([cC]\) [0-9]{4} [^(]*[^ (]' "$KIT/$lic" | grep -v Palmface)
done
check "the notices name every shader, every tmux plugin and each vendored copyright line" '[ -z "$nomiss" ]' "missing:$nomiss"

summary "integration"

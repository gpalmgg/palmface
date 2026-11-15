#!/bin/bash
# shellcheck disable=SC2088  # "~/..." in messages is display text for the user, not a path
# install.sh: install Palmface layers into your home directory, reversibly.
#
# Usage: ./install.sh <layers>... [--dry-run] [--no-post]
#   --terminal   terminal/                      --extras   extras/
#   --claude     claude/ statusline/ skills/    --all      every layer
#   --dry-run    print every action and write nothing (not even ~/.palmface-backup)
#   --no-post    skip layer post scripts (offline installs, tests)
#
# Your files are never replaced wholesale. Dotfiles get one marked block, settings.json is
# merged (your values win), and every original is backed up once, under ~/.palmface-backup/,
# before its first change. Undo with ./uninstall.sh (also copied to ~/.palmface-backup/).
# Contract: "Install contract" in docs/contracts.md.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH" # stock tools first, brew tools still found

ALL_LAYERS="terminal claude statusline skills extras"
KIT_ROOTS=".config/palmface .claude/palmface" # wholly kit-owned; post scripts write only here
TAB=$(printf '\t')
DRY_RUN=0
NO_POST=0
CHANGED=0
UNCHANGED=0
SKIPPED=0
TMPFILE=""
WORK=""

say()  { printf '%s\n' "$*"; }
warn() { printf 'palmface: warning: %s\n' "$*" >&2; }
die()  { printf 'palmface: error: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '5,14p' "$0" | sed 's/^# \{0,1\}//'; }

cleanup() {
  if [ -n "$TMPFILE" ]; then rm -f "$TMPFILE"; fi
  if [ -n "$WORK" ]; then rm -rf "$WORK"; fi
}

sha_of() { # sha256 of a regular file, "-" if absent
  if [ -f "$1" ]; then shasum -a 256 < "$1" | cut -d' ' -f1; else printf -- '-'; fi
}

no_trailing_newline() { # true if $1 is non-empty and does not end in a newline
  [ -s "$1" ] && [ "$(tail -c1 "$1" | wc -l | tr -d ' ')" = 0 ]
}

valid_rel() { # dest relative to $HOME: no leading / or ~, no . or .. parts, no empty parts
  case "$1" in '' | /* | '~'* | -) return 1 ;; esac
  case "/$1/" in */../* | */./* | *//*) return 1 ;; esac
  return 0
}

# --- manifest --------------------------------------------------------------------------

ensure_state() { # the state dir and its uninstaller exist from the first write on
  if [ ! -d "$STATE_DIR" ]; then mkdir -p "$STATE_DIR"; fi
  if [ ! -f "$STATE_DIR/uninstall.sh" ]; then install_uninstaller; fi
}
record() { ensure_state; printf '%s\n' "$1" >> "$MANIFEST"; }

touched() { # has this dest ever been recorded?
  [ -f "$MANIFEST" ] || return 1
  D="$1" awk -F'\t' '$1 == "touch" && $2 == ENVIRON["D"] { f = 1 } END { exit !f }' "$MANIFEST"
}

last_done() { # sha recorded after the most recent write to this dest ("" if none)
  [ -f "$MANIFEST" ] || return 0
  D="$1" awk -F'\t' '$1 == "done" && $2 == ENVIRON["D"] { s = $3 } END { print s }' "$MANIFEST"
}

ensure_dir() { # create a dir relative to $HOME, recording each component install creates
  local rest=$1 part acc=""
  [ "$rest" = . ] && return 0
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    if [ "$part" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    acc=${acc:+$acc/}$part
    [ -d "$HOME/$acc" ] && continue
    [ -e "$HOME/$acc" ] && die "~/$acc exists and is not a directory"
    record "mkdir${TAB}${acc}"
    mkdir "$HOME/$acc"
  done
}

# --- plan ------------------------------------------------------------------------------

build_plan() { # expand every selected layer.tsv into $PLAN: layer, mode, abs src, dest
  local layer dir tsv lineno line mode src dest extra where posts f
  posts="$WORK/posts.tsv"
  : > "$PLAN"
  for layer in $LAYERS; do
    dir="$KIT_DIR/$layer"
    tsv="$dir/layer.tsv"
    [ -f "$tsv" ] || continue
    : > "$posts"
    lineno=0
    while IFS= read -r line <&3 || [ -n "$line" ]; do
      lineno=$((lineno + 1))
      case "$line" in '' | '#'*) continue ;; esac
      where="$layer/layer.tsv:$lineno"
      mode="" src="" dest="" extra=""
      IFS="$TAB" read -r mode src dest extra <<< "$line"
      if [ -z "$mode" ] || [ -z "$src" ] || [ -z "$dest" ] || [ -n "$extra" ]; then
        die "$where: want mode<TAB>src<TAB>dest"
      fi
      case "$mode" in copy | tree | block | json | post) ;; *) die "$where: unknown mode '$mode'" ;; esac
      valid_rel "$src" || die "$where: src must be a clean path relative to $layer/"
      if [ "$mode" = post ]; then
        [ "$dest" = - ] || die "$where: post takes '-' as its dest"
        [ -f "$dir/$src" ] || die "$where: no such file: $layer/$src"
        printf '%s\tpost\t%s\t-\n' "$layer" "$dir/$src" >> "$posts"
        continue
      fi
      valid_rel "$dest" || die "$where: dest must be relative to \$HOME, without ~, . or .. parts or a leading /"
      case "$mode" in
        tree)
          [ -d "$dir/$src" ] || die "$where: no such directory: $layer/$src"
          find "$dir/$src" -type f ! -name .DS_Store | LC_ALL=C sort | while IFS= read -r f; do
            printf '%s\tcopy\t%s\t%s\n' "$layer" "$f" "$dest/${f#"$dir/$src"/}"
          done >> "$PLAN"
          ;;
        block)
          [ -f "$dir/$src" ] || die "$where: no such file: $layer/$src"
          case "$dest" in *.json) die "$where: a block cannot go into JSON; use a json line" ;; esac
          printf '%s\tblock\t%s\t%s\n' "$layer" "$dir/$src" "$dest" >> "$PLAN"
          ;;
        json)
          [ -f "$dir/$src" ] || die "$where: no such file: $layer/$src"
          command -v jq > /dev/null || die "jq is needed for $where (macOS 15+ ships /usr/bin/jq; otherwise: brew install jq)"
          jq -e 'type == "object"' "$dir/$src" > /dev/null 2>&1 || die "$where: $layer/$src is not a JSON object"
          printf '%s\tjson\t%s\t%s\n' "$layer" "$dir/$src" "$dest" >> "$PLAN"
          ;;
        copy)
          [ -f "$dir/$src" ] || die "$where: no such file: $layer/$src"
          printf '%s\tcopy\t%s\t%s\n' "$layer" "$dir/$src" "$dest" >> "$PLAN"
          ;;
      esac
    done 3< "$tsv"
    cat "$posts" >> "$PLAN" # a layer's post scripts run after its files
  done
  local dup
  dup=$(awk -F'\t' '$2 != "post" { n[$4]++; if ($2 == "copy") c[$4]++ }
    END { for (d in n) if (c[d] > 0 && n[d] > 1) { print d; exit } }' "$PLAN")
  [ -z "$dup" ] || die "two entries write ~/$dup (only block and json entries may share a dest)"
  dup=$(awk -F'\t' '$2 == "block" { k = $1 "\t" $4; if (k in b) { print "the " $1 " layer has two blocks for ~/" $4; exit } b[k] = 1 }' "$PLAN")
  [ -z "$dup" ] || die "$dup (one block per layer per file: merge the snippets)"
}

# --- renderers: compute the new content of a dest -------------------------------------

markers() { # $1 layer, $2 dest -> OPEN, CLOSE
  case "$2" in
    *.md | *.MD) OPEN="<!-- >>> palmface:$1 >>> -->"; CLOSE="<!-- <<< palmface:$1 <<< -->" ;;
    *) OPEN="# >>> palmface:$1 >>>"; CLOSE="# <<< palmface:$1 <<<" ;;
  esac
}

render_block() { # layer, snippet, dest path, dest rel -> stdout
  local layer=$1 src=$2 dest=$3 rel=$4
  markers "$layer" "$rel"
  # Marker lines are compared without a trailing CR, so a file an editor turned CRLF still matches.
  if [ -f "$dest" ] && O="$OPEN" awk '{ sub(/\r$/, "") } $0 == ENVIRON["O"] { f = 1; exit } END { exit !f }' "$dest"; then
    O="$OPEN" C="$CLOSE" S="$src" awk '
      { l = $0; sub(/\r$/, "", l) }
      l == ENVIRON["O"] { print; while ((getline s < ENVIRON["S"]) > 0) print s; close(ENVIRON["S"]); inblk = 1; next }
      inblk && l == ENVIRON["C"] { print; inblk = 0; next }
      !inblk { print }
      END { if (inblk) exit 3 }' "$dest" || die "~/$rel has '$OPEN' without '$CLOSE'; fix the file and re-run"
  else
    if [ -f "$dest" ]; then
      cat "$dest"
      if no_trailing_newline "$dest"; then printf '\n'; fi
    fi
    printf '%s\n' "$OPEN"
    cat "$src"
    if no_trailing_newline "$src"; then printf '\n'; fi
    printf '%s\n' "$CLOSE"
  fi
}

# Deep merge: objects recurse, the user's existing scalars win, arrays union (user's first).
# shellcheck disable=SC2016  # a jq program, not shell
JQ_MERGE='
def m($k; $u):
  if ($k | type) == "object" and ($u | type) == "object" then
    reduce ($k | keys_unsorted[]) as $key ($u;
      .[$key] = (if ($u | has($key)) then m($k[$key]; $u[$key]) else $k[$key] end))
  elif ($k | type) == "array" and ($u | type) == "array" then
    $u + [ $k[] | select(. as $x | ($u | any(.[]; . == $x)) | not) ]
  else $u end;
m($kit[0]; .)'

render_json() { # kit json, dest path, dest rel -> stdout
  local src=$1 dest=$2 rel=$3
  if [ -s "$dest" ]; then
    jq -e 'type == "object"' "$dest" > /dev/null 2>&1 || die "~/$rel is not a JSON object; fix it and re-run"
    jq --slurpfile kit "$src" "$JQ_MERGE" "$dest"
  else
    printf '{}' | jq --slurpfile kit "$src" "$JQ_MERGE"
  fi
}

# --- writers ---------------------------------------------------------------------------

write_atomic() { # new content, dest, mode, kit src: temp file in the dest dir, then rename
  local new=$1 dest=$2 mode=$3 src=$4 perm
  TMPFILE="$dest.palmface-tmp.$$"
  if [ "$mode" = copy ]; then
    cp -p "$src" "$TMPFILE" # keeps the kit file's mode (scripts stay executable)
  else
    cp "$new" "$TMPFILE"
    if [ -f "$dest" ]; then perm=$(stat -f %Lp "$dest"); else perm=644; fi
    chmod "$perm" "$TMPFILE"
  fi
  mv -f "$TMPFILE" "$dest"
  TMPFILE=""
}

symlinked_ancestor() { # print the first existing dir between $HOME and dest $1 that is a symlink
  local rest acc="" part
  rest=$(dirname "$1")
  [ "$rest" = . ] && return 0
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    if [ "$part" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    acc=${acc:+$acc/}$part
    if [ -L "$HOME/$acc" ]; then printf '%s' "$acc"; return 0; fi
    [ -e "$HOME/$acc" ] || return 0
  done
}

skip_symlink() { # layer, mode, src, dest rel, the symlinked path
  SKIPPED=$((SKIPPED + 1))
  warn "skipped ~/$4: ~/$5 is a symlink, and Palmface never writes through symlinks (dotfile repos stay yours)."
  if [ "$2" = block ]; then
    markers "$1" "$4"
    warn "to wire it by hand, add these lines to ~/$4:"
    {
      printf '%s\n' "$OPEN"
      cat "$3"
      if no_trailing_newline "$3"; then printf '\n'; fi
      printf '%s\n' "$CLOSE"
    } | sed 's/^/    /' >&2
  fi
}

store_fragment() { # layer, kit json, dest rel: keep what Palmface merged, so uninstall can take it out
  local layer=$1 src=$2 rel=$3 sha path
  sha=$(sha_of "$src")
  if [ -f "$MANIFEST" ] && D="$rel" S="$sha" awk -F'\t' '$1 == "kit" && $2 == ENVIRON["D"] && $4 == ENVIRON["S"] { f = 1 } END { exit !f }' "$MANIFEST"; then
    return 0
  fi
  path="$TS/kit/$layer/$rel"
  ensure_state
  mkdir -p "$(dirname "$STATE_DIR/$path")"
  cp "$src" "$STATE_DIR/$path"
  record "kit${TAB}${rel}${TAB}${path}${TAB}${sha}"
}

apply() { # layer, mode, abs src, dest rel
  local layer=$1 mode=$2 src=$3 rel=$4 dest new cur new_sha pre backup bsha last link
  dest="$HOME/$rel"
  if [ -L "$dest" ]; then skip_symlink "$layer" "$mode" "$src" "$rel" "$rel"; return 0; fi
  link=$(symlinked_ancestor "$rel")
  if [ -n "$link" ]; then skip_symlink "$layer" "$mode" "$src" "$rel" "$link"; return 0; fi
  if [ -e "$dest" ] && [ ! -f "$dest" ]; then die "~/$rel exists and is not a regular file"; fi

  new="$WORK/new"
  case "$mode" in
    copy) cp "$src" "$new" ;;
    block) render_block "$layer" "$src" "$dest" "$rel" > "$new" ;;
    json) render_json "$src" "$dest" "$rel" > "$new" ;;
  esac
  cur=$(sha_of "$dest")
  new_sha=$(sha_of "$new")
  if [ "$cur" = "$new_sha" ]; then
    UNCHANGED=$((UNCHANGED + 1))
    # A crash between write and record leaves a touched dest with no "done": repair it. Only then:
    # a recorded "done" that differs from the file means the user edited it, and must stay so.
    if [ "$DRY_RUN" -eq 0 ] && touched "$rel" && [ -z "$(last_done "$rel")" ]; then
      record "done${TAB}${rel}${TAB}${cur}"
    fi
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    say "would $mode  ~/$rel"
    CHANGED=$((CHANGED + 1))
    return 0
  fi

  if ! touched "$rel"; then # first sight: back up the original once, then record (write-ahead)
    if [ -f "$dest" ]; then
      pre="file"
      backup="$TS/files/$rel"
      ensure_state
      mkdir -p "$(dirname "$STATE_DIR/$backup")"
      cp -p "$dest" "$STATE_DIR/$backup"
      bsha=$(sha_of "$STATE_DIR/$backup")
    else
      pre=absent backup=- bsha=-
    fi
    record "touch${TAB}${rel}${TAB}${mode}${TAB}${pre}${TAB}${backup}${TAB}${bsha}${TAB}${TS}"
  else
    last=$(last_done "$rel")
    if [ -n "$last" ] && [ "$cur" != "$last" ] && [ "$cur" != - ]; then
      # Edited by the user since Palmface last wrote it. block/json carry the edit into the new
      # content; "edited" tells uninstall not to restore the original over it.
      record "edited${TAB}${rel}"
      if [ "$mode" = copy ]; then
        mkdir -p "$(dirname "$STATE_DIR/$TS/edited/$rel")"
        cp -p "$dest" "$STATE_DIR/$TS/edited/$rel"
        warn "~/$rel was edited after install; your version is saved at ~/.palmface-backup/$TS/edited/$rel"
      fi
    fi
  fi
  if [ "$mode" = json ]; then store_fragment "$layer" "$src" "$rel"; fi

  ensure_dir "$(dirname "$rel")"
  write_atomic "$new" "$dest" "$mode" "$src"
  record "done${TAB}${rel}${TAB}${new_sha}"
  say "$mode  ~/$rel"
  CHANGED=$((CHANGED + 1))
}

run_post() { # layer, abs script
  local layer=$1 script=$2 name r link
  name=${script#"$KIT_DIR"/}
  if [ "$NO_POST" -eq 1 ]; then say "skip  $name (--no-post)"; return 0; fi
  # Post scripts write under the kit roots. Like every file, they never go through a symlink: a
  # linked ~/.config (a dotfiles repo, say) would put plugin clones into that repo.
  for r in $KIT_ROOTS; do
    link=$(symlinked_ancestor "$r/.")
    if [ -n "$link" ]; then
      SKIPPED=$((SKIPPED + 1))
      warn "skipped $name: ~/$link is a symlink, and Palmface never writes through symlinks (dotfile repos stay yours)."
      return 0
    fi
  done
  if [ "$DRY_RUN" -eq 1 ]; then say "would run  $name"; return 0; fi
  for r in $KIT_ROOTS; do ensure_dir "$r"; done
  say "run   $name"
  PALMFACE_HOME="$HOME" PALMFACE_KIT_DIR="$KIT_DIR" PALMFACE_LAYER_DIR="$KIT_DIR/$layer" \
    /bin/bash "$script" < /dev/null || die "post script failed: $name"
}

run_plan() {
  local layer mode src rel
  while IFS="$TAB" read -r layer mode src rel <&3; do
    if [ "$mode" = post ]; then run_post "$layer" "$src"; else apply "$layer" "$mode" "$src" "$rel"; fi
  done 3< "$PLAN"
}

install_uninstaller() { # so uninstall works after the clone is deleted
  if ! cmp -s "$KIT_DIR/uninstall.sh" "$STATE_DIR/uninstall.sh"; then
    cp "$KIT_DIR/uninstall.sh" "$STATE_DIR/uninstall.sh"
    chmod 755 "$STATE_DIR/uninstall.sh"
  fi
}

main() {
  local want="" arg l
  if [ $# -eq 0 ]; then usage; exit 2; fi
  for arg in "$@"; do
    case "$arg" in
      --terminal) want="$want terminal" ;;
      --claude) want="$want claude statusline skills" ;;
      --extras) want="$want extras" ;;
      --all) want="$want $ALL_LAYERS" ;;
      --dry-run) DRY_RUN=1 ;;
      --no-post) NO_POST=1 ;;
      -h | --help) usage; exit 0 ;;
      *) printf 'palmface: unknown option: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
  done
  if [ -z "$want" ]; then printf 'palmface: pick at least one layer\n\n' >&2; usage >&2; exit 2; fi
  LAYERS=""
  for l in $ALL_LAYERS; do
    case " $want " in *" $l "*) LAYERS="$LAYERS $l" ;; esac
  done

  [ "$(uname -s)" = Darwin ] || die "Palmface is macOS-only"
  [ "$(id -u)" -ne 0 ] || die "do not run as root (sudo): run it as yourself, so your files stay yours"
  if [ -z "${HOME:-}" ] || [ "$HOME" = / ] || [ ! -d "$HOME" ]; then die "HOME is not a usable directory"; fi
  KIT_DIR=$(cd "$(dirname "$0")" && pwd -P)
  STATE_DIR="$HOME/.palmface-backup"
  MANIFEST="$STATE_DIR/manifest.tsv"
  TS=$(date +%Y%m%d-%H%M%S)
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/palmface.XXXXXX")
  PLAN="$WORK/plan.tsv"
  trap cleanup EXIT

  build_plan
  if [ ! -s "$PLAN" ]; then
    say "nothing to install: the selected layers (${LAYERS# }) are empty"
    exit 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then say "dry run: nothing will be written"; fi
  run_plan
  if [ "$DRY_RUN" -eq 0 ] && [ -d "$STATE_DIR" ]; then install_uninstaller; fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "dry run: $CHANGED to write, $UNCHANGED already up to date, $SKIPPED skipped"
  else
    say "done: $CHANGED written, $UNCHANGED already up to date, $SKIPPED skipped"
    if [ -d "$STATE_DIR" ]; then say "undo any time: ~/.palmface-backup/uninstall.sh"; fi
  fi
  if [ -f "$KIT_DIR/Brewfile" ]; then say "dependencies: brew bundle --file=\"$KIT_DIR/Brewfile\""; fi
}

main "$@"

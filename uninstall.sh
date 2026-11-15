#!/bin/bash
# shellcheck disable=SC2088  # "~/..." in messages is display text for the user, not a path
# uninstall.sh: undo every Palmface install and put your files back the way they were.
#
# Usage: ./uninstall.sh [--dry-run] [--keep-backups]
#   --dry-run        print what would happen, change nothing
#   --keep-backups   keep ~/.palmface-backup/ even when everything restored exactly
#
# A file untouched since install is restored byte for byte (or removed if Palmface created
# it). A file you edited after install keeps your edits: a dotfile loses only the Palmface
# block, settings.json loses only what Palmface added, and an edited kit file is saved under
# ~/.palmface-backup/uninstall-<ts>/kept/ (as is every file before it is rewritten). Files made
# in the kit folders after install (the token ledger, chain logs, your own) are moved there too;
# only caches the kit rebuilds are deleted.
# Also installed as ~/.palmface-backup/uninstall.sh, so it works after the clone is deleted.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

KIT_ROOTS=".config/palmface .claude/palmface" # wholly kit-owned: removed recursively
# Inside them, what the kit rebuilds or needs no more once uninstalled: deleted, not kept.
CACHES=".config/palmface/tmux/plugins .claude/palmface/state/statusline .claude/palmface/state/context-guardian
  .claude/palmface/state/context-size .claude/palmface/state/closing-drip .claude/palmface/state/autopilot"
TAB=$(printf '\t')
DRY_RUN=0
KEEP=0
RESTORED=0
KEPT=0
NONEXACT=0
PROBLEMS=0
WORK=""

say()  { printf '%s\n' "$*"; }
warn() { printf 'palmface: warning: %s\n' "$*" >&2; }
die()  { printf 'palmface: error: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//'; }
cleanup() { if [ -n "$WORK" ]; then rm -rf "$WORK"; fi; }

sha_of() { if [ -f "$1" ]; then shasum -a 256 < "$1" | cut -d' ' -f1; else printf -- '-'; fi; }

valid_rel() { # a manifest path: relative (to $HOME or the backup dir), no . or .. parts, no empty parts
  case "$1" in '' | /* | '~'* | -) return 1 ;; esac
  case "/$1/" in */../* | */./* | *//*) return 1 ;; esac
  return 0
}

bad_entry() { # the manifest names a path outside $HOME (or with ..): never act on it
  warn "the manifest has a path that is not a clean path inside your home ($1); skipped it"
  PROBLEMS=$((PROBLEMS + 1))
}

last_done() {
  D="$1" awk -F'\t' '$1 == "done" && $2 == ENVIRON["D"] { s = $3 } END { print s }' "$MANIFEST"
}

is_edited() { # did install see the user edit this dest after an earlier write?
  D="$1" awk -F'\t' '$1 == "edited" && $2 == ENVIRON["D"] { f = 1 } END { exit !f }' "$MANIFEST"
}

has_keepsakes() { # stashed edits, kept files or earlier uninstall records on disk
  [ -n "$(find "$STATE_DIR" \( -path '*/edited/*' -o -path '*/kept/*' -o -name 'manifest.uninstalled-*' \) -type f 2> /dev/null | head -n1)" ]
}

write_over() { # content file, rel: atomic replace keeping the dest's mode
  local dest="$HOME/$2" tmp="$HOME/$2.palmface-tmp.$$"
  cp "$1" "$tmp"
  chmod "$(stat -f %Lp "$dest")" "$tmp"
  mv -f "$tmp" "$dest"
}

restore() { # rel, pre, backup: put the pre-install state back
  local rel=$1 pre=$2 backup=$3 dest="$HOME/$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$pre" = file ]; then say "would restore  ~/$rel"; else say "would remove   ~/$rel"; fi
    return 0
  fi
  if [ "$pre" = file ]; then
    mkdir -p "$(dirname "$dest")"
    cp -p "$STATE_DIR/$backup" "$dest.palmface-tmp.$$"
    mv -f "$dest.palmface-tmp.$$" "$dest"
    say "restored  ~/$rel"
  else
    rm -f "$dest"
    say "removed   ~/$rel"
  fi
  RESTORED=$((RESTORED + 1))
}

stash() { # rel: save the current file before replacing or rewriting it
  local rel=$1
  if [ "$DRY_RUN" -eq 1 ]; then say "would keep     ~/$rel (edited after install)"; return 0; fi
  mkdir -p "$(dirname "$KEPT_DIR/$rel")"
  cp -p "$HOME/$rel" "$KEPT_DIR/$rel"
  say "kept      ~/$rel -> ~/.palmface-backup/uninstall-$UTS/kept/$rel"
  KEPT=$((KEPT + 1))
}

# Marker lines are matched without a trailing CR (files an editor turned CRLF).
# shellcheck disable=SC2016  # an awk program, not shell
MARK_AWK='
  function opener(s) { return s ~ /^# >>> palmface:[^ ]+ >>>$/ || s ~ /^<!-- >>> palmface:[^ ]+ >>> -->$/ }
  function closer(s) { return s ~ /^# <<< palmface:[^ ]+ <<<$/ || s ~ /^<!-- <<< palmface:[^ ]+ <<< -->$/ }
  { l = $0; sub(/\r$/, "", l) }'

strip_blocks() { # rel, pre: remove every Palmface block, keep everything else
  local rel=$1 pre=$2 dest="$HOME/$1" rc=0
  NONEXACT=$((NONEXACT + 1))
  # 0 = balanced blocks present, 1 = unbalanced markers, 2 = no blocks left
  awk "$MARK_AWK"'
    opener(l) { if (open) bad = 1; open = 1; n++ }
    closer(l) { if (!open) bad = 1; open = 0 }
    END { if (bad || open) exit 1; if (!n) exit 2 }' "$dest" || rc=$?
  if [ "$rc" -eq 2 ]; then say "no Palmface block left in ~/$rel (you edited it after install); left as is"; return 0; fi
  if [ "$rc" -ne 0 ]; then
    warn "~/$rel has an unbalanced Palmface marker (edited after install), so it was left as is; remove the palmface lines by hand"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then say "would strip    the Palmface block from ~/$rel (edited after install)"; return 0; fi
  stash "$rel"
  awk "$MARK_AWK"'
    opener(l) { skip = 1; next }
    skip && closer(l) { skip = 0; next }
    !skip { print }' "$dest" > "$WORK/stripped"
  write_over "$WORK/stripped" "$rel"
  if [ "$pre" = absent ] && [ ! -s "$dest" ]; then rm -f "$dest"; fi
  say "stripped  the Palmface block from ~/$rel (you edited it after install; your edits stay)"
}

# Reverse of install's merge, given the pre-install file ($o), one kit fragment ($k) and the
# current file ($c): drop keys Palmface added whose value is still Palmface's, and array items
# Palmface added that were not there before. Anything the user changed stays.
# shellcheck disable=SC2016  # a jq program, not shell
JQ_UNMERGE='
def has_key($obj; $key): if ($obj | type) == "object" then ($obj | has($key)) else false end;
def in_arr($arr; $x): if ($arr | type) == "array" then ($arr | any(.[]; . == $x)) else false end;
def container: type == "object" or type == "array";
def um($o; $k; $c):
  if ($k | type) == "object" and ($c | type) == "object" then
    reduce ($k | keys_unsorted[]) as $key ($c;
      if has($key) | not then .
      elif has_key($o; $key) then .[$key] = um($o[$key]; $k[$key]; .[$key])
      elif .[$key] == $k[$key] then del(.[$key])
      elif (.[$key] | container) and (.[$key] | type) == ($k[$key] | type) then
        .[$key] = um(null; $k[$key]; .[$key])
        | if .[$key] == {} or .[$key] == [] then del(.[$key]) else . end
      else . end)
  elif ($k | type) == "array" and ($c | type) == "array" then
    [ $c[] | select(. as $x | (in_arr($k; $x) and (in_arr($o; $x) | not)) | not) ]
  else $c end;
um($o[0]; $k[0]; $c[0])'

unmerge() { # rel, pre, backup: take Palmface's json fragments back out; 1 if not possible
  local rel=$1 pre=$2 backup=$3 dest="$HOME/$1" orig frags f
  command -v jq > /dev/null || return 1
  frags=$(D="$rel" awk -F'\t' '$1 == "kit" && $2 == ENVIRON["D"] { print $3 }' "$MANIFEST")
  [ -n "$frags" ] || return 1
  jq -e 'type == "object"' "$dest" > /dev/null 2>&1 || return 1
  if [ "$pre" = file ]; then orig="$STATE_DIR/$backup"; else orig="$WORK/null.json"; echo null > "$orig"; fi
  cp "$dest" "$WORK/cur.json" || return 1
  while IFS= read -r f; do
    valid_rel "$f" || return 1
    [ -f "$STATE_DIR/$f" ] || return 1
    jq -n --slurpfile o "$orig" --slurpfile k "$STATE_DIR/$f" --slurpfile c "$WORK/cur.json" "$JQ_UNMERGE" > "$WORK/next.json" || return 1
    mv "$WORK/next.json" "$WORK/cur.json" || return 1
  done <<< "$frags"
  if [ "$DRY_RUN" -eq 1 ]; then say "would clean    ~/$rel: remove what Palmface added, keep your changes"; return 0; fi
  stash "$rel"
  if [ "$pre" = absent ] && [ "$(jq -c . "$WORK/cur.json")" = "{}" ]; then
    rm -f "$dest"
    say "removed   ~/$rel (only Palmface's settings were left in it)"
  else
    write_over "$WORK/cur.json" "$rel" || return 1
    say "cleaned   ~/$rel: removed what Palmface added, kept your changes"
  fi
}

undo_one() { # rel, mode, pre, backup, backup sha
  local rel=$1 mode=$2 pre=$3 backup=$4 bsha=$5 dest cur last edited=0
  dest="$HOME/$rel"
  if [ -L "$dest" ]; then
    warn "~/$rel is a symlink now; left alone"
    NONEXACT=$((NONEXACT + 1))
    return 0
  fi
  cur=$(sha_of "$dest")
  if [ "$pre" = file ]; then
    if [ ! -f "$STATE_DIR/$backup" ] || [ "$(sha_of "$STATE_DIR/$backup")" != "$bsha" ]; then
      warn "the backup of ~/$rel is missing or damaged (~/.palmface-backup/$backup); left ~/$rel as is"
      PROBLEMS=$((PROBLEMS + 1))
      return 0
    fi
    [ "$cur" = "$bsha" ] && return 0 # already the original
  else
    [ "$cur" = - ] && return 0 # already absent
  fi
  last=$(last_done "$rel")
  if is_edited "$rel"; then edited=1; fi

  if [ -n "$last" ] && [ "$cur" = "$last" ] && [ "$edited" -eq 0 ]; then # untouched since install
    restore "$rel" "$pre" "$backup"
    return 0
  fi
  if [ -z "$last" ]; then # install stopped before finishing this file
    if [ "$cur" != - ]; then stash "$rel"; fi
    restore "$rel" "$pre" "$backup"
    return 0
  fi
  if [ "$cur" = - ]; then # deleted after install: bring the original back
    if [ "$pre" = file ]; then restore "$rel" "$pre" "$backup"; fi
    return 0
  fi
  case "$mode" in # the user edited it after install
    copy)
      # An edit install already saved (edited/) needs no second copy; a newer one does.
      if [ "$cur" != "$last" ]; then stash "$rel"; fi
      restore "$rel" "$pre" "$backup"
      ;;
    block)
      strip_blocks "$rel" "$pre"
      ;;
    json)
      NONEXACT=$((NONEXACT + 1))
      if ! unmerge "$rel" "$pre" "$backup"; then
        if [ "$pre" = file ]; then
          warn "~/$rel changed after install and could not be cleaned, so it was left as is; its pre-install copy is ~/.palmface-backup/$backup"
        else
          warn "~/$rel changed after install and could not be cleaned, so it was left as is; it did not exist before Palmface"
        fi
      fi
      ;;
  esac
}

is_cache() { # rel: inside one of the CACHES folders?
  local c
  for c in $CACHES; do case "$1" in "$c"/*) return 0 ;; esac; done
  return 1
}

keep_untracked() { # kit root rel: move the files install never wrote there (ledger, logs, yours) to the backup
  local root=$1 f rel n=0
  while IFS= read -r -d '' f; do
    rel=${f#"$HOME"/}
    is_cache "$rel" && continue
    if [ "$DRY_RUN" -eq 1 ]; then
      say "would keep     ~/$rel (made after install) -> ~/.palmface-backup/uninstall-<ts>/kept/"
      n=$((n + 1))
      continue
    fi
    mkdir -p "$(dirname "$KEPT_DIR/$rel")" && mv "$f" "$KEPT_DIR/$rel" && n=$((n + 1))
  done < <(find "$HOME/$root" -type f -print0 2> /dev/null)
  if [ "$DRY_RUN" -eq 0 ] && [ "$n" -gt 0 ]; then
    say "kept      $n file(s) made in ~/$root/ after install -> ~/.palmface-backup/uninstall-$UTS/kept/$root/"
    KEPT=$((KEPT + n))
  fi
}

undo_dir() { # dir rel recorded by install
  local d=$1 path="$HOME/$1" r
  if [ ! -d "$path" ] || [ -L "$path" ]; then return 0; fi
  for r in $KIT_ROOTS; do
    if [ "$d" = "$r" ]; then
      keep_untracked "$d"
      if [ "$DRY_RUN" -eq 1 ]; then say "would remove   ~/$d/"; else rm -rf "$path"; say "removed   ~/$d/"; fi
      return 0
    fi
    case "$d" in "$r"/*) # inside a kit root: the root's removal takes care of leftovers
      if [ "$DRY_RUN" -eq 0 ]; then rmdir "$path" 2> /dev/null || true; fi
      return 0 ;;
    esac
  done
  if [ "$DRY_RUN" -eq 1 ]; then say "would remove   ~/$d/ (if empty)"; return 0; fi
  if rmdir "$path" 2> /dev/null; then
    say "removed   ~/$d/"
  else
    warn "~/$d/ is not empty, so it stays"
    NONEXACT=$((NONEXACT + 1))
  fi
}

main() {
  local arg rel mode pre backup bsha d
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --keep-backups) KEEP=1 ;;
      -h | --help) usage; exit 0 ;;
      *) printf 'palmface: unknown option: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
  done
  if [ -z "${HOME:-}" ] || [ "$HOME" = / ] || [ ! -d "$HOME" ]; then die "HOME is not a usable directory"; fi
  STATE_DIR="$HOME/.palmface-backup"
  MANIFEST="$STATE_DIR/manifest.tsv"
  if [ ! -f "$MANIFEST" ]; then say "nothing to uninstall: no ~/.palmface-backup/manifest.tsv"; exit 0; fi
  UTS=$(date +%Y%m%d-%H%M%S)
  KEPT_DIR="$STATE_DIR/uninstall-$UTS/kept"
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/palmface.XXXXXX")
  trap cleanup EXIT
  if [ "$DRY_RUN" -eq 1 ]; then say "dry run: nothing will be changed"; fi

  # Files: newest first. Each dest has one touch line (its pre-install state).
  awk -F'\t' '$1 == "touch" && !seen[$2]++' "$MANIFEST" | tail -r > "$WORK/touches"
  while IFS="$TAB" read -r _ rel mode pre backup bsha _ <&3; do
    if ! valid_rel "$rel" || { [ "$backup" != - ] && ! valid_rel "$backup"; }; then bad_entry "$rel"; continue; fi
    undo_one "$rel" "$mode" "$pre" "$backup" "$bsha"
  done 3< "$WORK/touches"

  # Directories install created: deepest (newest) first.
  awk -F'\t' '$1 == "mkdir" { print $2 }' "$MANIFEST" | tail -r > "$WORK/dirs"
  while IFS= read -r d <&3; do
    if valid_rel "$d"; then undo_dir "$d"; else bad_entry "$d"; fi
  done 3< "$WORK/dirs"

  if [ "$DRY_RUN" -eq 1 ]; then say "dry run: nothing was changed"; exit 0; fi
  if [ "$PROBLEMS" -eq 0 ] && [ "$NONEXACT" -eq 0 ] && [ "$KEPT" -eq 0 ] && [ "$KEEP" -eq 0 ] && ! has_keepsakes; then
    rm -rf "$STATE_DIR"
    say "uninstalled: $RESTORED files put back; your home is as it was before Palmface"
  else
    mv "$MANIFEST" "$STATE_DIR/manifest.uninstalled-$UTS.tsv"
    say "uninstalled: $RESTORED files put back. Backups and anything kept are in ~/.palmface-backup/"
  fi
  [ "$PROBLEMS" -eq 0 ] || exit 1
}

main "$@"

# shellcheck shell=bash disable=SC2016,SC2034  # check() evals its condition later; KIT is used by the sourcing script
# Shared helpers for the fake-home tests. Sourced, not run.
#
# Safety: every home these tests write to is a fresh mktemp dir under $TMPDIR named
# palmface-home.*, checked against the real home read from the directory service (not $HOME,
# which a caller could have changed). Child processes get HOME=<fake> and no XDG/ZDOTDIR
# variables, so nothing can resolve back to the real home through them.

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ORIG_HOME=${HOME:-}
REAL_HOME=$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2> /dev/null | awk '{ print $2 }')
TMP_ROOT=$(cd "${TMPDIR:-/tmp}" && pwd -P)
PASS=0
FAIL=0

die() { printf 'test: %s\n' "$*" >&2; exit 2; }
ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() {
  FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | sed 's/^/        /'; fi
}
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; } # desc, condition, detail
summary() { echo; echo "$1: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

[ -n "$REAL_HOME" ] || die "cannot read the real home from the directory service; refusing to run"

guard_home() { # abort unless $1 is a fresh palmface-home.* dir under $TMPDIR and not a real home
  local h=$1
  case "$h" in "$REAL_HOME" | "$REAL_HOME"/*) die "refusing: $h is the real home or inside it" ;; esac
  if [ -n "$ORIG_HOME" ]; then
    case "$h" in "$ORIG_HOME" | "$ORIG_HOME"/*) die "refusing: $h is \$HOME or inside it" ;; esac
  fi
  case "$h" in "$TMP_ROOT"/palmface-home.*) ;; *) die "refusing: $h is not a fresh palmface-home dir under \$TMPDIR" ;; esac
  case "$h" in */../* | */..) die "refusing: $h has .. in it" ;; esac
}

new_home() { # create, resolve and guard a fake home; print its path
  local h
  h=$(mktemp -d "$TMP_ROOT/palmface-home.XXXXXX") || die "mktemp failed"
  h=$(cd "$h" && pwd -P)
  guard_home "$h"
  printf '%s\n' "$h"
}

rm_home() { guard_home "$1"; chmod -R u+w "$1" 2> /dev/null; rm -rf "$1"; }

kit_run() { # kit dir, fake home, script, args...: run a kit script against a fake home only
  local kit=$1 home=$2 script=$3
  shift 3
  guard_home "$home"
  env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u ZDOTDIR \
    HOME="$home" /bin/bash "$kit/$script" "$@"
}

snapshot() { # every path under a home: type, mode, sha256 / symlink target
  (
    cd "$1" || exit 1
    find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then
        printf 'L %s -> %s\n' "$p" "$(readlink "$p")"
      elif [ -d "$p" ]; then
        printf 'D %s %s\n' "$(stat -f %Lp "$p")" "$p"
      else
        printf 'F %s %s %s\n' "$(stat -f %Lp "$p")" "$(shasum -a 256 < "$p" | cut -d' ' -f1)" "$p"
      fi
    done
  )
}

snap_diff() { # two snapshot strings -> unified diff
  local a b
  a=$(mktemp) b=$(mktemp)
  printf '%s\n' "$1" > "$a"
  printf '%s\n' "$2" > "$b"
  diff -u "$a" "$b" | tail -n +3
  rm -f "$a" "$b"
}

seed_home() { # a stranger's typical dotfiles, including the awkward cases
  local h=$1
  mkdir -p "$h/.claude/agents" "$h/.config/ghostty" "$h/dotfiles" "$h/Library/Application Support/Some App"
  printf '# my zshrc\nexport EDITOR=vim\nalias ll="ls -l"' > "$h/.zshrc" # no trailing newline
  chmod 600 "$h/.zshrc"
  printf 'set -g mouse on\n' > "$h/dotfiles/tmux.conf"
  ln -s dotfiles/tmux.conf "$h/.tmux.conf" # dotfile managed by a symlink
  printf '[user]\n\tname = Someone\n' > "$h/.gitconfig"
  printf '{\n  "model": "sonnet",\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$h/.claude/settings.json"
  printf '# my rules\n\nBe brief.\n' > "$h/.claude/CLAUDE.md"
  printf 'my own helper\n' > "$h/.claude/agents/helper.md"
  printf 'font-size = 14\n' > "$h/.config/ghostty/config"
  printf 'keep me\n' > "$h/Library/Application Support/Some App/prefs.txt"
}

check_manifest() { # every dest in the manifest exists with its last recorded sha; one touch each
  local h=$1 m="$1/.palmface-backup/manifest.tsv" rel want got dups
  if [ ! -f "$m" ]; then ok "no manifest (nothing was written)"; return 0; fi
  local missing=""
  while IFS="$(printf '\t')" read -r rel want; do
    got=$(if [ -f "$h/$rel" ]; then shasum -a 256 < "$h/$rel" | cut -d' ' -f1; else echo -; fi)
    [ "$got" = "$want" ] || missing="$missing ~/$rel"
  done < <(awk -F'\t' '$1 == "done" { s[$2] = $3; if (!($2 in o)) { o[$2] = ++n; k[n] = $2 } }
    END { for (i = 1; i <= n; i++) printf "%s\t%s\n", k[i], s[k[i]] }' "$m")
  check "every manifest dest exists with its recorded sha" '[ -z "$missing" ]' "mismatch:$missing"
  dups=$(awk -F'\t' '$1 == "touch" { c[$2]++ } END { for (d in c) if (c[d] > 1) print d }' "$m")
  check "each dest was backed up at most once" '[ -z "$dups" ]' "$dups"
}

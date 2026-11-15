#!/bin/bash
# sessions.sh: list past Claude Code sessions (title, date, project, id). Read-only.
# Prints only titles and the first line of the first user prompt, never transcript bodies.
set -u

ROOT="${PALMFACE_SESSIONS_DIR:-$HOME/.claude/projects}"
SEARCH=""
NAMED=0
LIMIT=20
PROJ=""

usage() {
  echo "usage: sessions.sh [--search WORD] [--named] [--project PART] [--limit N] [--all]"
  echo "  --search WORD   keep sessions whose title or first prompt contains WORD (case-insensitive)"
  echo "  --named         only sessions that were named with /rename"
  echo "  --project PART  only sessions whose working directory contains PART"
  echo "  --limit N       show at most N sessions (default 20)"
  echo "  --all           no limit"
  echo "Reads ~/.claude/projects (override: PALMFACE_SESSIONS_DIR). Never writes. Needs jq."
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --search) SEARCH="${2:-}"; shift ;;
    --named) NAMED=1 ;;
    --project) PROJ="${2:-}"; shift ;;
    --limit) LIMIT="${2:-20}"; shift ;;
    --all) LIMIT=0 ;;
    *) echo "sessions.sh: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || { echo "sessions.sh: jq is required (brew install jq)" >&2; exit 3; }
[ -d "$ROOT" ] || { echo "sessions.sh: no sessions folder at $ROOT" >&2; exit 4; }
case "$LIMIT" in ''|*[!0-9]*) echo "sessions.sh: --limit needs a number" >&2; exit 2 ;; esac

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
# Hide anything shaped like a key or token before it is printed (the first prompt is the user's text).
mask() {
  printf '%s' "$1" | LC_ALL=C sed -E \
    -e 's/(sk|pk|rk)-[A-Za-z0-9_-]{8,}/[hidden]/g' -e 's/gh[pousr]_[A-Za-z0-9]{16,}/[hidden]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{16,}/[hidden]/g' -e 's/xox[abprs]-[A-Za-z0-9-]{8,}/[hidden]/g' \
    -e 's/A(KIA|SIA)[0-9A-Z]{16}/[hidden]/g' -e 's/AIza[0-9A-Za-z_-]{20,}/[hidden]/g' \
    -e 's/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(\.[A-Za-z0-9_-]+)?/[hidden]/g' \
    -e 's/[0-9a-fA-F]{32,}/[hidden]/g'
}
SEARCH_L=$(lower "$SEARCH")
SHOWN=0

# Top-level transcripts only (subagent transcripts live in subfolders). Newest first.
while IFS= read -r f; do
  id=$(basename "$f" .jsonl)
  title=$(grep -m 20 '"type":"custom-title"' "$f" 2>/dev/null | tail -1 | jq -r '.customTitle // empty' 2>/dev/null)
  [ "$NAMED" -eq 1 ] && [ -z "$title" ] && continue
  first=$(grep -m 12 '"type":"user"' "$f" 2>/dev/null | jq -r '
    select((.isSidechain // false) | not)
    | (.message.content // "") | if type == "array" then (map(.text? // "") | join(" ")) else . end
    | select(startswith("<") | not) | split("\n")[0] | .[0:100]' 2>/dev/null | head -1)
  cwd=$(grep -m 12 '"type":"user"' "$f" 2>/dev/null | jq -r '.cwd // empty' 2>/dev/null | head -1)
  if [ -n "$PROJ" ]; then
    case "$cwd" in *"$PROJ"*) ;; *) continue ;; esac
  fi
  if [ -n "$SEARCH" ]; then
    hay=$(lower "$title $first")
    case "$hay" in *"$SEARCH_L"*) ;; *) continue ;; esac
  fi
  when=$(date -r "$(stat -f %m "$f")" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
  label=$(mask "${title:-$first}")
  [ -z "$label" ] && label="(no title, no prompt)"
  echo "$when  $id  $label"
  [ -n "$cwd" ] && printf '    in: %s   resume: cd %q && claude --resume %q\n' "$cwd" "$cwd" "$id"
  SHOWN=$((SHOWN + 1))
  if [ "$LIMIT" -gt 0 ] && [ "$SHOWN" -ge "$LIMIT" ]; then break; fi
done < <(ls -t "$ROOT"/*/*.jsonl 2>/dev/null)

[ "$SHOWN" -eq 0 ] && echo "no matching sessions"
exit 0

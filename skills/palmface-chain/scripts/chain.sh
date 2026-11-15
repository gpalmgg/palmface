#!/bin/bash
# chain.sh: run numbered session prompts back to back, each in a fresh headless `claude -p`,
# inside a detached tmux session. Stops on a broken relay or a HUMAN GATE prompt.
# Bash 3.2 clean. State and logs: ~/.claude/palmface/state/palmface-chain/<name>/
set -u
umask 077 # the logs hold whole headless sessions: yours alone

usage() {
  echo "usage:"
  echo "  chain.sh run    <prompt-dir> --permission-mode MODE [options]"
  echo "  chain.sh status <prompt-dir> [--name NAME]"
  echo "  chain.sh stop   <prompt-dir> [--name NAME]"
  echo "options:"
  echo "  --permission-mode MODE  REQUIRED for run. Passed to claude -p --permission-mode"
  echo "                          ('claude --help' lists your version's modes). No default: you choose"
  echo "                          how much the headless sessions may do. In print mode a tool that is"
  echo "                          not allowed is denied, not asked, and every session must edit, run"
  echo "                          your tests and git commit. 'acceptEdits' covers edits only, so it"
  echo "                          also needs allow rules for your test and git commands in your own"
  echo "                          settings ('dontAsk' likewise runs only what your rules allow)."
  echo "                          Put the rules in .claude/settings.local.json (kept out of git), not"
  echo "                          the committed .claude/settings.json. A project's rules count only once"
  echo "                          that folder is trusted: open Claude Code there once and accept its"
  echo "                          prompt. Not a sandbox: npm test and git commit run whatever the repo's"
  echo "                          test script and git hooks say. Chain only repositories you trust;"
  echo "                          otherwise run it in a container or a VM."
  echo "                          'bypassPermissions' runs any command unattended: use it only in a"
  echo "                          throwaway or sandboxed checkout."
  echo "  --project DIR           repo root (default: git root of the prompt dir)"
  echo "  --from N  --until N     session range (default: first session without a handoff .. last)"
  echo "  --prefix P              file prefix (default v: vN-session-prompt.md, vN-handoff.md)"
  echo "  --model M               pass --model M to claude (default: claude's own)"
  echo "  --name NAME             tmux session chain-NAME (default: prompt dir basename)"
  echo "  --timeout S             wall clock per session in seconds, needs timeout/gtimeout (default 14400)"
  echo "  --dry-run               print what would run; start no tmux and no claude"
  echo "Stops: a prompt line starting with HUMAN GATE, no handoff or no new commit after a session,"
  echo "claude exiting non-zero, or a dirty working tree at launch. Sets PALMFACE_AUTOPILOT=on."
}

CMD="${1:-}"
[ -n "$CMD" ] && shift
case "$CMD" in
  run|status|stop|_loop) ;;
  -h|--help|help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

PROMPTDIR=""; PROJECT=""; FROM=""; UNTIL=""; PREFIX="v"; MODEL=""; NAME=""
PERM=""; TIMEOUT=14400; DRY=0; CLAUDE_BIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --permission-mode) PERM="${2:-}"; shift ;;
    --project) PROJECT="${2:-}"; shift ;;
    --from) FROM="${2:-}"; shift ;;
    --until) UNTIL="${2:-}"; shift ;;
    --prefix) PREFIX="${2:-}"; shift ;;
    --model) MODEL="${2:-}"; shift ;;
    --name) NAME="${2:-}"; shift ;;
    --timeout) TIMEOUT="${2:-}"; shift ;;
    --claude-bin) CLAUDE_BIN="${2:-}"; shift ;;
    --dry-run) DRY=1 ;;
    -*) echo "chain.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) if [ -z "$PROMPTDIR" ]; then PROMPTDIR="$1"; else echo "chain.sh: extra argument: $1" >&2; exit 2; fi ;;
  esac
  shift
done

[ -n "$PROMPTDIR" ] || { echo "chain.sh: a prompt dir is required" >&2; usage >&2; exit 2; }
[ -d "$PROMPTDIR" ] || { echo "chain.sh: no such dir: $PROMPTDIR" >&2; exit 66; }
PROMPTDIR=$(cd "$PROMPTDIR" && pwd)
[ -n "$PROJECT" ] || PROJECT=$(cd "$PROMPTDIR" && git rev-parse --show-toplevel 2>/dev/null)
[ -n "$PROJECT" ] || { echo "chain.sh: not inside a git repo; pass --project" >&2; exit 66; }
[ -n "$NAME" ] || NAME=$(basename "$PROMPTDIR")
case "$NAME" in
  '' | .* | *[!A-Za-z0-9._-]*)
    echo "chain.sh: the chain name may hold only letters, digits, '.', '_' and '-' (and not start with '.'): pass --name" >&2
    exit 2 ;;
esac
TN="chain-$NAME"
STATE="$HOME/.claude/palmface/state/palmface-chain/$NAME"
case "$TIMEOUT" in ''|*[!0-9]*) echo "chain.sh: --timeout needs a number" >&2; exit 2 ;; esac

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"; fi

pfile() { echo "$PROMPTDIR/${PREFIX}$1-session-prompt.md"; }
hfile() { echo "$PROMPTDIR/${PREFIX}$1-handoff.md"; }
is_gate() { grep -qE '^[^[:alnum:]]*HUMAN GATE' "$1" 2>/dev/null; }
# Uncommitted changes, apart from the autopilot record (.autopilot/, OUTBOX.md, REVIEW.md), which
# the headless sessions themselves write and which a chain must not trip over.
dirty() { git -C "$PROJECT" status --porcelain 2>/dev/null | grep -vE '^.. "?(\.autopilot/|OUTBOX\.md"?$|REVIEW\.md"?$)'; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$STATE/chain.log"; }

last_prompt_number() {
  local n=1 last=0
  while [ "$n" -le 99 ]; do
    [ -f "$(pfile "$n")" ] && last=$n
    n=$((n + 1))
  done
  echo "$last"
}

if [ "$CMD" = "status" ]; then
  if tmux has-session -t "=$TN" 2>/dev/null; then echo "tmux $TN: running"; else echo "tmux $TN: not running"; fi
  [ -f "$STATE/running" ] && echo "marker: $(cat "$STATE/running")"
  echo "--- chain.log (last 8)"
  tail -8 "$STATE/chain.log" 2>/dev/null || echo "(no log)"
  echo "--- git log -3"; git -C "$PROJECT" log --oneline -3
  echo "--- git status --short"; git -C "$PROJECT" status --short
  exit 0
fi

if [ "$CMD" = "stop" ]; then
  if [ -f "$STATE/loop.pid" ]; then
    PID=$(cat "$STATE/loop.pid")
    pkill -TERM -P "$PID" 2>/dev/null
    kill -TERM "$PID" 2>/dev/null
  fi
  tmux kill-session -t "=$TN" 2>/dev/null && echo "stopped $TN" || echo "$TN not running"
  rm -f "$STATE/running" "$STATE/loop.pid"
  echo "committed work stays; uncommitted work stays in the tree:"
  git -C "$PROJECT" status --short
  exit 0
fi

LAST=$(last_prompt_number)
[ "$LAST" -gt 0 ] || { echo "chain.sh: no ${PREFIX}N-session-prompt.md files in $PROMPTDIR" >&2; exit 67; }
if [ -z "$FROM" ]; then
  n=1
  while [ "$n" -le "$LAST" ]; do
    if [ -f "$(pfile "$n")" ] && [ ! -f "$(hfile "$n")" ]; then FROM=$n; break; fi
    n=$((n + 1))
  done
  [ -n "$FROM" ] || { echo "nothing to run: every prompt already has a handoff"; exit 67; }
fi
[ -n "$UNTIL" ] || UNTIL=$LAST
case "$FROM$UNTIL" in *[!0-9]*) echo "chain.sh: --from/--until need numbers" >&2; exit 2 ;; esac

if [ -z "$CLAUDE_BIN" ]; then CLAUDE_BIN=$(command -v claude 2>/dev/null || true); fi
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# Build the per-session claude command as text (used by dry-run and by the loop).
claude_cmd() {  # $1 = prompt file
  local c
  c="PALMFACE_AUTOPILOT=on $(printf '%q' "$CLAUDE_BIN") -p \"\$(cat $(printf '%q' "$1"))\" --permission-mode $(printf '%q' "$PERM")"
  [ -n "$MODEL" ] && c="$c --model $(printf '%q' "$MODEL")"
  echo "$c"
}

if [ "$CMD" = "run" ]; then
  [ -n "$PERM" ] || { echo "chain.sh: --permission-mode is required (see --help for the risk of each mode)" >&2; exit 2; }
  case "$PERM" in
    acceptEdits | auto | bypassPermissions | default | dontAsk | manual | plan) ;;
    *[!A-Za-z]*) echo "chain.sh: '$PERM' is not a permission mode" >&2; exit 2 ;;
    *) echo "note: '$PERM' is not a mode this script knows; passing it to claude as it is" >&2 ;;
  esac
  [ -f "$(pfile "$FROM")" ] || { echo "chain.sh: no $(pfile "$FROM")" >&2; exit 70; }
  n=$FROM
  while [ "$n" -le "$UNTIL" ]; do
    if [ -f "$(pfile "$n")" ] && is_gate "$(pfile "$n")"; then
      if [ "$n" -eq "$FROM" ]; then echo "chain.sh: ${PREFIX}$n is a HUMAN GATE; not chaining it" >&2; exit 71; fi
      echo "note: ${PREFIX}$n is a HUMAN GATE; the chain will stop before it"
      UNTIL=$((n - 1)); break
    fi
    n=$((n + 1))
  done
  if [ -n "$(dirty)" ]; then echo "chain.sh: working tree not clean:" >&2; dirty >&2; exit 69; fi
  if [ "$DRY" -eq 0 ]; then
    command -v tmux >/dev/null 2>&1 || { echo "chain.sh: tmux is required" >&2; exit 3; }
    command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { echo "chain.sh: claude not found" >&2; exit 3; }
    if tmux has-session -t "=$TN" 2>/dev/null; then echo "chain.sh: $TN already running; use status or stop" >&2; exit 68; fi
  fi
  [ -z "$TIMEOUT_BIN" ] && echo "note: no timeout/gtimeout found; sessions run without a wall clock"
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  LOOP="bash $(printf '%q' "$SELF") _loop $(printf '%q' "$PROMPTDIR") --project $(printf '%q' "$PROJECT") --from $FROM --until $UNTIL --prefix $(printf '%q' "$PREFIX") --name $(printf '%q' "$NAME") --permission-mode $(printf '%q' "$PERM") --timeout $TIMEOUT --claude-bin $(printf '%q' "$CLAUDE_BIN")"
  [ -n "$MODEL" ] && LOOP="$LOOP --model $(printf '%q' "$MODEL")"
  if [ "$DRY" -eq 1 ]; then
    echo "dry run: sessions ${PREFIX}$FROM..${PREFIX}$UNTIL of $PROMPTDIR, permission mode $PERM"
    echo "would run: tmux new-session -d -s $TN -c $PROJECT '$LOOP'"
    n=$FROM
    while [ "$n" -le "$UNTIL" ]; do
      echo "would run (session $n, in $PROJECT, up to ${TIMEOUT}s): $(claude_cmd "$(pfile "$n")")"
      n=$((n + 1))
    done
    echo "logs would go to $STATE"
    exit 0
  fi
  mkdir -p "$STATE"
  echo "launching $TN: ${PREFIX}$FROM..${PREFIX}$UNTIL, permission mode $PERM, logs $STATE"
  tmux new-session -d -s "$TN" -c "$PROJECT" "$LOOP; echo \"chain exited \$?\" >> $(printf '%q' "$STATE/chain.log")"
  exit 0
fi

# ---- _loop: runs inside tmux ----
mkdir -p "$STATE"
echo "$$" > "$STATE/loop.pid"
echo "since $(date '+%Y-%m-%d %H:%M:%S') ${PREFIX}$FROM..${PREFIX}$UNTIL" > "$STATE/running"
trap 'rm -f "$STATE/running" "$STATE/loop.pid"' EXIT
cd "$PROJECT" || exit 66
N=$FROM
while [ "$N" -le "$UNTIL" ]; do
  P=$(pfile "$N")
  [ -f "$P" ] || { log "no prompt $P; chain finished"; exit 0; }
  if is_gate "$P"; then log "${PREFIX}$N is a HUMAN GATE; stopping before it"; exit 4; fi
  BEFORE=$(git rev-parse HEAD 2>/dev/null)
  log "start ${PREFIX}$N"
  ARGS=(-p "$(cat "$P")" --permission-mode "$PERM")
  [ -n "$MODEL" ] && ARGS+=(--model "$MODEL")
  if [ -n "$TIMEOUT_BIN" ] && [ "$TIMEOUT" -gt 0 ]; then
    PALMFACE_AUTOPILOT=on "$TIMEOUT_BIN" -k 60 "$TIMEOUT" "$CLAUDE_BIN" "${ARGS[@]}" > "$STATE/${PREFIX}$N.out" 2> "$STATE/${PREFIX}$N.err"
  else
    PALMFACE_AUTOPILOT=on "$CLAUDE_BIN" "${ARGS[@]}" > "$STATE/${PREFIX}$N.out" 2> "$STATE/${PREFIX}$N.err"
  fi
  RC=$?
  AFTER=$(git rev-parse HEAD 2>/dev/null)
  if [ "$RC" -ne 0 ]; then log "BROKEN RELAY at ${PREFIX}$N: claude exited $RC (see ${PREFIX}$N.err)"; exit 5; fi
  if [ "$BEFORE" = "$AFTER" ]; then log "BROKEN RELAY at ${PREFIX}$N: no new commit"; exit 5; fi
  if [ ! -f "$(hfile "$N")" ]; then log "BROKEN RELAY at ${PREFIX}$N: no $(basename "$(hfile "$N")")"; exit 5; fi
  log "done ${PREFIX}$N at $AFTER"
  N=$((N + 1))
done
log "chain finished: ${PREFIX}$FROM..${PREFIX}$UNTIL"
exit 0

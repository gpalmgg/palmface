#!/bin/bash
# shellcheck disable=SC2094  # number_lines/printable_runs take a label string, not a file to write
# leak-scan.sh: keep identity strings and secrets out of the publishable tree.
#
# Usage: scripts/leak-scan.sh [--no-denylist] [--history [REF]]
#   (default)       scan every file git would publish: tracked + untracked-not-ignored
#                   (contents, file paths, symlink targets; binary files via printable runs)
#   --history REF   also scan every blob reachable from REF (default HEAD) plus each
#                   commit's author, committer and message. Used on the publish branch.
#   --no-denylist   run the key-shape rules only (scripts/denylist.txt is local-only)
#
# Allowlists: scripts/leak-allow.txt (committed) and scripts/leak-allow.local.txt (gitignored,
# read when present). A plain entry is exempt everywhere; "file:<path>:<string>" only in that
# file; "meta:<string>" only in commit author, committer and message lines (--history).
#
# Exit: 0 clean, 1 hits, 2 configuration error.
# Output names where and which rule ("path:line: denylist#12"), never the matched text.
# Contract: "Leak-scan contract" in docs/contracts.md.
set -u

NO_DENY=0
HISTORY=0
REF=HEAD
while [ $# -gt 0 ]; do
  case "$1" in
    --no-denylist) NO_DENY=1 ;;
    --history)
      HISTORY=1
      if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then REF=$2; shift; fi ;;
    -h|--help) sed -n '3,18p' "$0"; exit 0 ;;
    *) echo "leak-scan: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "leak-scan: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2

# Stock macOS tools, whatever happens to be first on PATH.
AWK=/usr/bin/awk
GREP=/usr/bin/grep

DENY=scripts/denylist.txt
ALLOW=scripts/leak-allow.txt
ALLOW_LOCAL=scripts/leak-allow.local.txt # your own scoped exemptions (gitignored), read when present
if [ "$NO_DENY" -eq 1 ]; then
  DENY=/dev/null
elif [ ! -f "$DENY" ]; then
  echo "leak-scan: $DENY is missing. It is local-only (gitignored): build it, or pass --no-denylist for key shapes only." >&2
  exit 2
fi
[ -f "$ALLOW" ] || ALLOW=/dev/null
[ -f "$ALLOW_LOCAL" ] || ALLOW_LOCAL=/dev/null

if [ "$HISTORY" -eq 1 ] && ! git rev-parse --verify -q "$REF^{commit}" >/dev/null; then
  echo "leak-scan: unknown ref: $REF" >&2
  exit 2
fi

# --- producers: one record per line, "where<TAB>scope<TAB>text" ------------------------
# scope is "f:<path>" for a file's contents, path and link target, "m:" for commit metadata.

# shellcheck disable=SC2016  # awk program in single quotes
number_lines() { # $1 = label prefix, $2 = line tag ("" for text, "bin" for binary runs), $3 = scope
  W="$1" T="$2" S="$3" LC_ALL=C $AWK '{ printf "%s:%s%d\t%s\t%s\n", ENVIRON["W"], ENVIRON["T"], NR, ENVIRON["S"], $0 }'
}

printable_runs() { # binary on stdin -> printable runs of 6+ chars, one per line
  LC_ALL=C tr -c '[:print:]\t' '\n' | LC_ALL=C $GREP -E '.{6,}'
}

emit_tree() {
  git ls-files -z -co --exclude-standard | while IFS= read -r -d '' f; do
    printf '%s:path\tf:%s\t%s\n' "$f" "$f" "$f"
    if [ -L "$f" ]; then
      printf '%s:link\tf:%s\t%s\n' "$f" "$f" "$(readlink "$f")"
    elif [ ! -f "$f" ]; then
      continue # tracked but deleted in the working tree
    elif LC_ALL=C $GREP -Iq '' "$f" 2>/dev/null; then
      number_lines "$f" "" "f:$f" < "$f"
    else
      printable_runs < "$f" | number_lines "$f" "bin" "f:$f"
    fi
  done
}

emit_history() {
  local seen c short entry meta path mode type sha
  seen=$(mktemp)
  git rev-list "$REF" | while read -r c; do
    short=$(printf '%s' "$c" | cut -c1-7)
    git log -1 --format='%an <%ae>%n%cn <%ce>%n%B' "$c" | number_lines "commit $short" "meta" "m:"
    git ls-tree -r -z "$c" | while IFS= read -r -d '' entry; do
      meta=${entry%%$'\t'*}
      path=${entry#*$'\t'}
      mode=$(printf '%s' "$meta" | cut -d' ' -f1)
      type=$(printf '%s' "$meta" | cut -d' ' -f2)
      sha=$(printf '%s' "$meta" | cut -d' ' -f3)
      [ "$type" = blob ] || continue
      printf 'commit %s:%s:path\tf:%s\t%s\n' "$short" "$path" "$path" "$path"
      # Once per blob and path: a file-scoped allow entry must not cover the same blob elsewhere.
      if $GREP -qxF "$sha $path" "$seen"; then continue; fi
      printf '%s %s\n' "$sha" "$path" >> "$seen"
      if [ "$mode" = 120000 ]; then
        printf 'commit %s:%s:link\tf:%s\t%s\n' "$short" "$path" "$path" "$(git cat-file -p "$sha")"
      elif git cat-file -p "$sha" | LC_ALL=C $GREP -Iq ''; then
        git cat-file -p "$sha" | number_lines "commit $short:$path" "" "f:$path"
      else
        git cat-file -p "$sha" | printable_runs | number_lines "commit $short:$path" "bin" "f:$path"
      fi
    done
  done
  rm -f "$seen"
}

# --- scanner -------------------------------------------------------------------------

# shellcheck disable=SC2016  # awk program: $0 etc. are awk's, not the shell's
PROG='
function report(where, rule) { print where ": " rule; hits++ }

function wordhit(s, w,    p, off, lw, b, a) {
  lw = length(w); off = 0
  while ((p = index(substr(s, off + 1), w)) > 0) {
    p += off
    b = (p == 1) ? "" : substr(s, p - 1, 1)
    a = substr(s, p + lw, 1)
    if (b !~ /[a-z0-9_]/ && a !~ /[a-z0-9_]/) return 1
    off = p
  }
  return 0
}

function readallow(file,    line, sc, rest, c) {
  while ((getline line < file) > 0) {
    sub(/\r$/, "", line)
    if (line ~ /^[ \t]*(#|$)/) continue
    sc = ""
    if (substr(line, 1, 5) == "meta:") { sc = "m:"; line = substr(line, 6) }
    else if (substr(line, 1, 5) == "file:") {
      rest = substr(line, 6); c = index(rest, ":")
      if (c < 2) { printf "leak-scan: %s: \"file:\" needs file:<path>:<string>\n", file > "/dev/stderr"; cfgerr = 1; exit 2 }
      sc = "f:" substr(rest, 1, c - 1); line = substr(rest, c + 1)
    }
    if (line == "") continue
    na++; ap[na] = tolower(line); as[na] = sc
  }
  close(file)
}

function keyscan(where, s,    m) {
  if (match(s, /(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{32,}/)) {
    m = substr(s, RSTART, RLENGTH)
    if (m ~ /[0-9]/ && m ~ /[A-Z]/) report(where, "key:sk")
  }
  if (s ~ /(^|[^A-Za-z0-9_])(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}/) report(where, "key:github")
  if (s ~ /github_pat_[A-Za-z0-9_]{30,}/)                         report(where, "key:github-pat")
  if (s ~ /(^|[^A-Za-z0-9_])xox[abposr]-[A-Za-z0-9-]{10,}/)        report(where, "key:slack")
  if (s ~ /(^|[^A-Z0-9])(AKIA|ASIA)[A-Z0-9]{16}([^A-Z0-9]|$)/)    report(where, "key:aws")
  if (s ~ /-{5}BEGIN/)                                             report(where, "key:pem-block")
  if (s ~ /AIza[0-9A-Za-z_-]{35}/)                                 report(where, "key:google")
  if (s ~ /(sk|rk|pk)_live_[0-9A-Za-z]{10,}/)                      report(where, "key:stripe")
  if (s ~ /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}/)          report(where, "key:jwt")
  if (s ~ /(^|[^0-9])[0-9]{8,10}:[A-Za-z0-9_-]{35}/)               report(where, "key:telegram-bot")
  if (s ~ /(^|[^0-9A-Za-z])[0-9a-fA-F]{32,}([^0-9A-Za-z]|$)/)      report(where, "key:long-hex")
  if (s ~ /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z][A-Za-z]+/) report(where, "email")
  if (s ~ /\/Users\/[A-Za-z]/)                                     report(where, "abs-home-path")
}

BEGIN {
  nd = 0; ln = 0
  while ((getline line < DENY) > 0) {
    ln++
    sub(/\r$/, "", line)
    if (line ~ /^[ \t]*(#|$)/) continue
    kind = "w"; pat = line
    if (substr(line, 1, 4) == "sub:")     { kind = "s"; pat = substr(line, 5) }
    else if (substr(line, 1, 3) == "re:") { kind = "r"; pat = substr(line, 4) }
    if (pat == "") continue
    nd++; dk[nd] = kind; dp[nd] = tolower(pat); dn[nd] = ln
  }
  na = 0
  readallow(ALLOW); readallow(ALLOW_LOCAL)
  for (i = 2; i <= na; i++) {               # longest first, so an entry holding another wins
    a = ap[i]; sc = as[i]
    for (j = i - 1; j >= 1 && length(ap[j]) < length(a); j--) { ap[j + 1] = ap[j]; as[j + 1] = as[j] }
    ap[j + 1] = a; as[j + 1] = sc
  }
  hits = 0; records = 0
}

{
  t = index($0, "\t"); if (t == 0) next
  rest = substr($0, t + 1); u = index(rest, "\t"); if (u == 0) next
  records++
  where = substr($0, 1, t - 1); scope = substr(rest, 1, u - 1); text = substr(rest, u + 1); low = tolower(text)
  for (i = 1; i <= na; i++) {               # blank allowlisted spans, keeping byte positions
    if (as[i] != "" && as[i] != scope) continue # a scoped entry, somewhere else
    a = ap[i]; la = length(a)
    while ((p = index(low, a)) > 0) {
      pad = sprintf("%" la "s", "")
      low = substr(low, 1, p - 1) pad substr(low, p + la)
      text = substr(text, 1, p - 1) pad substr(text, p + la)
    }
  }
  for (i = 1; i <= nd; i++) {
    if (dk[i] == "s")      { if (index(low, dp[i]) > 0) report(where, "denylist#" dn[i]) }
    else if (dk[i] == "r") { if (low ~ dp[i])           report(where, "denylist#" dn[i]) }
    else if (wordhit(low, dp[i]))                       report(where, "denylist#" dn[i])
  }
  keyscan(where, text)
}

END {
  if (cfgerr) exit 2
  if (hits > 0) { printf "leak-scan: %d hit(s) in %d records\n", hits, records > "/dev/stderr"; exit 1 }
  printf "leak-scan: clean (%d records, %d denylist entries)\n", records, nd > "/dev/stderr"
}
'

if [ "$HISTORY" -eq 1 ]; then
  { emit_tree; emit_history; }
else
  emit_tree
fi | LC_ALL=C $AWK -v DENY="$DENY" -v ALLOW="$ALLOW" -v ALLOW_LOCAL="$ALLOW_LOCAL" "$PROG"

#!/bin/bash
# Palmface hook (Stop): keep a token ledger, one row per session and model, so you can see
# where your usage goes across days and projects. It backs "Spend context carefully" in
# Palmface's CLAUDE.md with numbers.
#
# Counts the session transcript Claude Code names in the hook JSON (read-only), plus its
# subagents' transcripts beside it. A reply that spans several transcript lines is counted once.
# Tokens only: Palmface ships no price list, because prices change. Writes
# ~/.claude/palmface/state/cost-tracker/sessions.tsv (tab-separated, header on line 1). Never
# blocks, prints nothing as a hook.
#
# Read the ledger from a terminal:
#   bash ~/.claude/palmface/hooks/cost-tracker.sh report [days]      (default: 14 days)
# For a dollar estimate, write your own ~/.claude/palmface-local/prices.tsv, one line per model:
#   <part of the model id><TAB><input><TAB><cache write><TAB><cache read><TAB><output>
# in US dollars per million tokens, more specific names first. Palmface only ever reads it.
#
# Off switches:
#   PALMFACE_HOOKS=off      every Palmface hook (the "env" block of ~/.claude/settings.json)
#   PALMFACE_COST=off       just this one

# shellcheck source=claude/hooks/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2> /dev/null || { [ -t 0 ] || cat > /dev/null; exit 0; }

ledger="$KH_STATE/cost-tracker/sessions.tsv"
TAB=$(printf '\t')

if [ "${1:-}" = report ]; then
  days=${2:-14}
  case "$days" in '' | *[!0-9]*) days=14 ;; esac
  [ -s "$ledger" ] || { echo "No usage recorded yet ($ledger)."; exit 0; }
  since=$(date -v-"$((days > 0 ? days - 1 : 0))"d +%Y-%m-%d)
  prices="$HOME/.claude/palmface-local/prices.tsv"
  [ -r "$prices" ] || prices=/dev/null
  /usr/bin/awk -F'\t' -v since="$since" -v days="$days" -v pf="$prices" '
    BEGIN {
      while ((getline line < pf) > 0) {
        sub(/\r$/, "", line)
        if (line ~ /^#/ || split(line, f, "\t") < 5) continue
        np++; pm[np] = f[1]; pi[np] = f[2]; pw[np] = f[3]; pr[np] = f[4]; po[np] = f[5]
      }
    }
    FNR == 1 || /^#/ { next }
    substr($1, 1, 10) < since { next }
    {
      day = substr($1, 1, 10); k = day "\t" $4
      if (!(k in R)) ord[++nk] = k
      R[k] += $5; I[k] += $6; W[k] += $7; C[k] += $8; O[k] += $9
      cost = -1
      for (j = 1; j <= np; j++) if (index($4, pm[j])) { cost = ($6 * pi[j] + $7 * pw[j] + $8 * pr[j] + $9 * po[j]) / 1e6; break }
      if (cost >= 0) { D[k] += cost; priced = 1 } else unpriced[k] = 1
      ti += $6; tw += $7; tc += $8; to += $9
    }
    function k_(n) { return n >= 1e6 ? sprintf("%.1fM", n / 1e6) : n >= 1e3 ? sprintf("%.0fK", n / 1e3) : n }
    END {
      printf "Token usage, last %s day(s)\n\n", days
      printf "%-10s  %-28s %7s %9s %9s %9s %9s%s\n", "day", "model", "replies", "input", "cache-w", "cache-r", "output", priced ? "      usd" : ""
      for (i = 1; i <= nk; i++) {
        k = ord[i]; split(k, a, "\t")
        printf "%-10s  %-28s %7d %9s %9s %9s %9s", a[1], substr(a[2], 1, 28), R[k], k_(I[k]), k_(W[k]), k_(C[k]), k_(O[k])
        if (priced && (k in unpriced)) printf "        ?"
        else if (priced) printf " %8.2f", D[k]
        printf "\n"; tot += D[k]
      }
      printf "\n%-10s  %-28s %7s %9s %9s %9s %9s", "total", "", "", k_(ti), k_(tw), k_(tc), k_(to)
      if (priced) printf " %8.2f", tot
      printf "\n"
      if (!priced) printf "\nNo prices: add ~/.claude/palmface-local/prices.tsv for a dollar estimate.\n"
    }' "$ledger"
  exit 0
fi

kh_read
kh_off "${PALMFACE_COST:-on}" && exit 0
t=$(kh_transcript) || exit 0
sid=$(kh_session)
cwd=$(kh_get cwd)
project=$(basename "${cwd:-unknown}" | tr -d '\t')

set -- "$t"
for f in "${t%.jsonl}"/subagents/*.jsonl; do
  [ -f "$f" ] && set -- "$@" "$f"
done

# One reply = one message id, however many lines it spans; sum per model.
rows=$(cat "$@" 2> /dev/null | /usr/bin/grep '"type":"assistant"' | /usr/bin/grep '"usage":{' | /usr/bin/awk -v OFS='\t' '
  function num(k) { return match($0, "\"" k "\":[0-9]+") ? substr($0, RSTART + length(k) + 3, RLENGTH - length(k) - 3) + 0 : 0 }
  {
    id = match($0, /"id":"msg_[A-Za-z0-9_]+"/) ? substr($0, RSTART, RLENGTH) : "line" NR
    m = match($0, /"model":"[^"]+"/) ? substr($0, RSTART + 9, RLENGTH - 10) : "unknown"
    if (m == "<synthetic>") next
    M[id] = m; I[id] = num("input_tokens"); W[id] = num("cache_creation_input_tokens")
    C[id] = num("cache_read_input_tokens"); O[id] = num("output_tokens")
  }
  END {
    for (id in M) { k = M[id]; R[k]++; SI[k] += I[id]; SW[k] += W[id]; SC[k] += C[id]; SO[k] += O[id] }
    for (k in R) print k, R[k], SI[k], SW[k], SC[k], SO[k]
  }')
[ -n "$rows" ] || exit 0

d=$(kh_state_dir cost-tracker) || exit 0
now=$(date '+%Y-%m-%d %H:%M')

# Two sessions can stop at the same moment: take a lock (a directory, created atomically) for the
# read-modify-write. A lock left by a killed run is stale after a minute. No lock within about
# two seconds: skip this turn; the next one rewrites the session's rows anyway.
lock="$d/.lock"
find "$lock" -maxdepth 0 -type d -mmin +1 -exec rmdir {} \; 2> /dev/null
i=0
until mkdir "$lock" 2> /dev/null; do
  i=$((i + 1))
  [ "$i" -le 20 ] || exit 0
  sleep 0.1
done
trap 'rmdir "$lock" 2> /dev/null' EXIT
tmp="$d/sessions.tsv.tmp.$$"
{
  printf '# updated\tsession\tproject\tmodel\treplies\tinput\tcache_write\tcache_read\toutput\n'
  [ -f "$ledger" ] && /usr/bin/awk -F'\t' -v s="$sid" 'FNR > 1 && $2 != s' "$ledger"
  printf '%s\n' "$rows" | while IFS="$TAB" read -r model rest; do
    printf '%s\t%s\t%s\t%s\t%s\n' "$now" "$sid" "$project" "$model" "$rest"
  done
} 2> /dev/null > "$tmp" && mv -f "$tmp" "$ledger" 2> /dev/null
rm -f "$tmp" 2> /dev/null
exit 0

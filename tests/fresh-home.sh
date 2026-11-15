#!/bin/bash
# shellcheck disable=SC2016,SC2034  # check() conditions are single-quoted on purpose: eval'd later
# fresh-home.sh: install the real layers into throwaway fake homes, then prove that uninstall
# puts each home back exactly. Never touches the real home (see tests/lib.sh).
#
# Usage: tests/fresh-home.sh <install flags>     e.g.  --all   |   --terminal --no-post
#
# Two passes, each in a fresh fake home: "empty" (a new Mac) and "seeded" (typical dotfiles,
# a symlinked dotfile, a path with spaces). In each: dry-run writes nothing, install succeeds,
# every manifest dest matches, a second install changes nothing, uninstall == pre-install.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

if [ $# -eq 0 ]; then sed -n '6p' "$0" | sed 's/^# //' >&2; exit 2; fi

for seed in empty seeded; do
  echo "== $seed home: install.sh $*"
  H=$(new_home) || exit 2
  if [ "$seed" = seeded ]; then seed_home "$H"; fi
  S0=$(snapshot "$H")

  out=$(kit_run "$KIT" "$H" install.sh "$@" --dry-run 2>&1); rc=$?
  check "dry-run exits 0" '[ $rc -eq 0 ]' "$out"
  S=$(snapshot "$H")
  check "dry-run writes nothing" '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"

  out=$(kit_run "$KIT" "$H" install.sh "$@" 2>&1); rc=$?
  check "install exits 0" '[ $rc -eq 0 ]' "$out"
  check_manifest "$H"
  S1=$(snapshot "$H")

  out=$(kit_run "$KIT" "$H" install.sh "$@" 2>&1); rc=$?
  check "second install exits 0" '[ $rc -eq 0 ]' "$out"
  S=$(snapshot "$H")
  check "second install changes nothing" '[ "$S" = "$S1" ]' "$(snap_diff "$S1" "$S")"

  out=$(kit_run "$KIT" "$H" uninstall.sh 2>&1); rc=$?
  check "uninstall exits 0" '[ $rc -eq 0 ]' "$out"
  S=$(snapshot "$H")
  check "uninstall restores the pre-install home exactly" '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"

  rm_home "$H"
done

summary "fresh-home $*"

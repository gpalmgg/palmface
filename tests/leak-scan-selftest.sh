#!/bin/bash
# leak-scan-selftest.sh: prove scripts/leak-scan.sh catches what it must and nothing it must not.
# Builds a throwaway git repo under $TMPDIR with a fake denylist; never reads the real one.
# Fixture secrets are assembled at runtime so this file itself passes the real scan.
set -u

KIT=$(cd "$(dirname "$0")/.." && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/palmface-leak.XXXXXX")
trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; }
rep() { printf "%${2}s" "" | tr ' ' "$1"; }

OUT=""; RC=0
scan() { OUT=$(cd "$T" && /bin/bash scripts/leak-scan.sh "$@" 2>&1); RC=$?; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok "$1"; else bad "$1 (exit $RC, want $2)" "$OUT"; fi; }
expect_hit() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok "$1"; else bad "$1 (no '$2')" "$OUT"; fi; }
expect_no()  { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1 (unexpected '$2')" "$OUT"; else ok "$1"; fi; }

# --- fixture repo -----------------------------------------------------------------------
cd "$T" || exit 1
git init -q
git config user.name tester
git config user.email tester@example.com
mkdir scripts
cp "$KIT/scripts/leak-scan.sh" "$KIT/scripts/leak-allow.txt" scripts/
printf 'scripts/denylist.txt\nscripts/leak-allow.local.txt\nignored/\n' > .gitignore
cat > scripts/denylist.txt <<'EOF'
# fake identity for the self-test
zorblax
sub:quuxcorp
re:fo+bar
EOF
echo "hello world" > clean.txt
git add -A && git commit -qm init

echo "1. baseline"
scan;                 expect_rc "clean repo exits 0" 0
mv scripts/denylist.txt scripts/denylist.off
scan;                 expect_rc "missing denylist exits 2" 2
scan --no-denylist;   expect_rc "--no-denylist runs key shapes only" 0
mv scripts/denylist.off scripts/denylist.txt
scan --bogus;         expect_rc "unknown flag exits 2" 2

echo "2. denylist matching"
printf 'line one\nmeet Zorblax today\n' > a.txt
scan; expect_rc "whole word hits" 1; expect_hit "reports path:line and entry" "a.txt:2: denylist#2"
expect_no "never prints the matched text" "Zorblax"
printf 'zorblaxian and xzorblax\n' > a.txt
scan; expect_rc "whole word ignores longer words" 0
printf 'the myquuxcorpthing\n' > a.txt
scan; expect_hit "sub: matches inside words" "a.txt:1: denylist#3"
printf 'a fooooobar b\n' > a.txt
scan; expect_hit "re: matches" "a.txt:1: denylist#4"
printf 'pre-zorblax is fine\n' > a.txt
echo "pre-zorblax" >> scripts/leak-allow.txt
scan; expect_rc "allowlisted span is blanked" 0
printf 'pre-zorblax but zorblax\n' > a.txt
scan; expect_rc "allowlist does not hide a second occurrence" 1
rm a.txt

echo "2b. scoped entries and the local allowlist"
L=scripts/leak-allow.local.txt
printf 'credit: Zorblax Person\n' > README.md
printf 'credit: Zorblax Person\n' > other.md
printf 'file:README.md:Zorblax Person\n' > "$L"
scan; expect_no "a file: entry exempts the file it names" "README.md:1:"
expect_hit "a file: entry does not exempt any other file" "other.md:1: denylist#2"
rm other.md
scan; expect_rc "the local allowlist is read when present" 0
mv "$L" "$L.off"
scan; expect_rc "without the local allowlist its entries are gone" 1
mv "$L.off" "$L"
printf 'meta:Zorblax Person\n' >> "$L"
printf 'Zorblax Person\n' > m.txt
scan; expect_hit "a meta: entry never exempts file contents" "m.txt:1: denylist#2"
rm m.txt
printf 'by acme zorblax\n' > o.txt
printf 'acme\nacme zorblax\n' >> "$L"
scan; expect_rc "longer entries are blanked first, whatever the file order" 0
rm o.txt
cp "$L" "$L.keep"
printf 'file:README.md\n' >> "$L"
scan; expect_rc "a file: entry without a string is a configuration error" 2
mv "$L.keep" "$L"
rm README.md "$L"

echo "3. scope"
mkdir -p ignored sub
echo "zorblax" > ignored/x.txt
scan; expect_rc "gitignored files are not scanned" 0
echo "fine" > "sub/zorblax notes.txt"
scan; expect_hit "file paths are scanned (spaces ok)" "sub/zorblax notes.txt:path: denylist#2"
rm "sub/zorblax notes.txt"
ln -s "/tmp/quuxcorp" sub/link
scan; expect_hit "symlink targets are scanned" "sub/link:link: denylist#3"
rm sub/link
printf 'abc\000\001\002quuxcorp-binary\000\003' > sub/blob.bin
scan; expect_hit "binary files are scanned" "sub/blob.bin:bin"
rm sub/blob.bin

echo "4. key shapes (and near misses)"
check_key() { # rule, secret
  printf 'x = "%s"\n' "$2" > k.txt
  scan; expect_hit "$1 detected" "k.txt:1: $1"; expect_no "$1 value not printed" "$2"
  rm k.txt
}
check_key key:sk          "s""k-$(rep A 20)$(rep 1 20)"
check_key key:github      "gh""p_$(rep a 36)"
check_key key:github-pat  "github""_pat_$(rep a 40)"
check_key key:slack       "xo""xb-$(rep 1 12)"
check_key key:aws         "AK""IA$(rep A 16)"
check_key key:pem-block   "$(rep - 5)BEGIN RSA PRIVATE KEY"
check_key key:google      "AI""za$(rep a 35)"
check_key key:stripe      "sk""_live_$(rep a 12)"
check_key key:jwt         "ey""J$(rep a 12).ey""J$(rep a 12)"
check_key key:telegram-bot "$(rep 1 9):$(rep a 35)"
check_key key:long-hex    "$(rep f 40)"
u=someone; d=mailhost.org
check_key email           "$u@$d"
check_key abs-home-path   "/Us""ers/someone/notes"
printf '%s\n' "productivity:task-management-and-other-very-long-skill-names" \
  "commit abc1234 and 0123abc" "write to you@example.com" "author kit@users.noreply.github.com" \
  "path ~/Projects and \$HOME/.config" "/Users/<you>/x" "round-robin" > near.txt
scan; expect_rc "near misses stay clean" 0
rm near.txt

echo "5. history"
git add -A && git commit -qm "add allow entry"
echo "zorblax was here" > leak.txt
git add leak.txt && git commit -qm "oops"
git rm -q leak.txt && git commit -qm "remove"
scan;           expect_rc "working tree is clean after removal" 0
scan --history; expect_rc "--history finds the removed file" 1
expect_hit "history names the commit and path" ":leak.txt:1: denylist#2"
git -c user.name="Zorblax Person" commit -q --allow-empty -m "empty"
scan --history HEAD; expect_hit "history scans author names" ":meta1: denylist#2"
printf 'meta:Zorblax Person <tester@example.com>\n' > scripts/leak-allow.local.txt
scan --history HEAD; expect_no "a meta: entry exempts that identity in commit metadata" ":meta1: denylist#2"
expect_hit "...and the removed file is still found" ":leak.txt:1: denylist#2"
rm scripts/leak-allow.local.txt
nu=123+someone; nd=users.noreply.github.com # assembled, so this file passes the real scan
git -c user.name=Someone -c user.email="$nu@$nd" commit -q --allow-empty -m "noreply"
scan --no-denylist --history HEAD; expect_no "a GitHub noreply address in commit metadata is not an email hit" ":meta1: email"
printf 'mail %s@%s\n' "$nu" "$nd" > n.txt
scan --no-denylist; expect_hit "...but the same address in a file is" "n.txt:1: email"
rm n.txt
printf 'credit: Zorblax Person\n' > README.md
cp README.md copy.md
git add README.md copy.md && git commit -qm "same blob at two paths"
git rm -q README.md copy.md && git commit -qm "gone"
printf 'file:README.md:Zorblax Person\n' > scripts/leak-allow.local.txt
scan --history HEAD; expect_no "history: a file: entry exempts its own path" ":README.md:1: denylist#2"
expect_hit "history: the same blob at another path is still scanned" ":copy.md:1: denylist#2"
rm scripts/leak-allow.local.txt
scan --history nosuchref; expect_rc "unknown ref exits 2" 2

echo
echo "leak-scan selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

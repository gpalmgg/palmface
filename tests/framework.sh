#!/bin/bash
# shellcheck disable=SC2016,SC2034  # check() conditions are single-quoted on purpose: eval'd later
# framework.sh: prove the install/uninstall mechanics against fixture layers, independent of
# what the real layers contain. Never touches the real home (see tests/lib.sh).
#
# Covers every mode (copy, tree, block, json, post), dry-run, re-install, a changed kit
# source, user edits after install, a crash mid-install, a lost "done" record, symlinked
# dotfiles, paths with spaces, bad layer lines, and uninstall with no manifest.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# --- fixture kit: the real scripts plus synthetic layers ---------------------------------
FIX=$(mktemp -d "$TMP_ROOT/palmface-kit.XXXXXX")
trap 'rm -rf "$FIX"' EXIT
cp "$KIT/install.sh" "$KIT/uninstall.sh" "$FIX/"
T="$FIX/terminal/files"
C="$FIX/claude/files"
mkdir -p "$T/tree/sub dir" "$C" "$FIX/extras"
printf 'echo vibes\n' > "$T/vibes.zsh"
printf '#!/bin/bash\necho hi\n' > "$T/tool.sh"
chmod 755 "$T/tool.sh"
printf 'a\n' > "$T/tree/a.txt"
printf 'b\n' > "$T/tree/sub dir/b c.txt"
printf 'source ~/.config/palmface/zsh/vibes.zsh\n' > "$T/zshrc.block"
printf 'source-file ~/.config/palmface/tmux/tmux.conf' > "$T/tmux.block" # no trailing newline
printf 'd="$PALMFACE_HOME/.config/palmface/tmux/plugins"; f="$d/post-made.txt"\nmkdir -p "$d"; [ -f "$f" ] || echo made > "$f"\n' > "$T/post.sh" # where the real post script writes: a cache
printf 'kit note\n' > "$T/note.txt"
printf 'kit rules\n' > "$C/CLAUDE.md"
printf '@~/.claude/palmface/CLAUDE.md\n' > "$C/claude.block"
printf 'kit helper\n' > "$C/helper.md"
printf '{"model":"opus","statusLine":{"type":"command","command":"x"},"permissions":{"allow":["Bash(ls:*)","Read"]}}\n' > "$C/settings.json"
{
  printf '# fixture terminal layer\n'
  printf 'post\tfiles/post.sh\t-\n' # listed first on purpose: posts still run after the files
  printf 'copy\tfiles/vibes.zsh\t.config/palmface/zsh/vibes.zsh\n'
  printf 'copy\tfiles/tool.sh\t.config/palmface/bin/tool.sh\n'
  printf 'tree\tfiles/tree\t.config/palmface/tree\n'
  printf 'block\tfiles/zshrc.block\t.zshrc\n'
  printf 'block\tfiles/tmux.block\t.tmux.conf\n'
  printf 'copy\tfiles/note.txt\tLibrary/Application Support/Some App/palmface.txt\n'
  printf 'copy\tfiles/note.txt\tlinked/note.txt\n' # a symlinked dir in the seeded home
} > "$FIX/terminal/layer.tsv"
{
  printf 'copy\tfiles/CLAUDE.md\t.claude/palmface/CLAUDE.md\n'
  printf 'block\tfiles/claude.block\t.claude/CLAUDE.md\n'
  printf 'json\tfiles/settings.json\t.claude/settings.json\n'
  printf 'copy\tfiles/helper.md\t.claude/agents/helper.md\n'
} > "$FIX/claude/layer.tsv"

inst()   { kit_run "$FIX" "$H" install.sh "$@" 2>&1; }
uninst() { kit_run "$FIX" "$H" uninstall.sh "$@" 2>&1; }
count()  { grep -cxF -- "$2" "$1" 2> /dev/null || true; } # exact-line count
MAN() { printf '%s' "$H/.palmface-backup/manifest.tsv"; }

echo "1. empty home"
H=$(new_home) || exit 2
S0=$(snapshot "$H")
out=$(inst --all --dry-run); rc=$?
check "dry-run exits 0" '[ $rc -eq 0 ]' "$out"
check "dry-run lists actions" 'printf "%s" "$out" | grep -q "would copy  ~/.config/palmface/zsh/vibes.zsh"' "$out"
S=$(snapshot "$H")
check "dry-run writes nothing" '[ "$S" = "$S0" ]' "$(snap_diff "$S0" "$S")"
out=$(inst --all); rc=$?
check "install exits 0" '[ $rc -eq 0 ]' "$out"
check_manifest "$H"
check "block written with markers" '[ "$(cat "$H/.zshrc")" = "$(printf "# >>> palmface:terminal >>>\nsource ~/.config/palmface/zsh/vibes.zsh\n# <<< palmface:terminal <<<")" ]' "$(cat "$H/.zshrc")"
check "snippet without trailing newline still closes the block" '[ "$(tail -n1 "$H/.tmux.conf")" = "# <<< palmface:terminal <<<" ]'
check "markdown dests get comment markers" 'grep -qxF "<!-- >>> palmface:claude >>> -->" "$H/.claude/CLAUDE.md"'
check "json into an absent file = kit json" 'jq -e ".model == \"opus\" and .statusLine.command == \"x\"" "$H/.claude/settings.json" >/dev/null'
check "copy keeps the executable bit" '[ "$(stat -f %Lp "$H/.config/palmface/bin/tool.sh")" = 755 ]'
check "tree copies nested paths with spaces" '[ -f "$H/.config/palmface/tree/sub dir/b c.txt" ]'
last_file=$(printf '%s\n' "$out" | grep -n 'palmface.txt' | head -n1 | cut -d: -f1)
post_line=$(printf '%s\n' "$out" | grep -n 'run   terminal/files/post.sh' | head -n1 | cut -d: -f1)
check "post script ran, after the layer's files" '[ -f "$H/.config/palmface/tmux/plugins/post-made.txt" ] && [ "${post_line:-0}" -gt "${last_file:-99}" ]' "$out"
check "uninstaller copied into the state dir" '[ -x "$H/.palmface-backup/uninstall.sh" ]'
S1=$(snapshot "$H")
out=$(inst --all); rc=$?
S=$(snapshot "$H")
check "second install exits 0 and changes nothing" '[ $rc -eq 0 ] && [ "$S" = "$S1" ]' "$out$(snap_diff "$S1" "$S")"
out=$(uninst --dry-run)
S=$(snapshot "$H")
check "uninstall --dry-run changes nothing" '[ "$S" = "$S1" ]' "$out"
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "uninstall restores the empty home exactly (state dir gone)" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
rm_home "$H"

echo "1b. files made in the kit folders after install are kept, caches are not"
H=$(new_home) || exit 2
S0=$(snapshot "$H")
inst --all > /dev/null
mkdir -p "$H/.claude/palmface/state/cost-tracker" "$H/.claude/palmface/state/statusline" "$H/.config/palmface/mine"
printf 'a ledger row\n' > "$H/.claude/palmface/state/cost-tracker/sessions.tsv"
printf 'my notes\n' > "$H/.config/palmface/mine/notes with space.txt"
printf '{}\n' > "$H/.claude/palmface/state/statusline/cache.json"
out=$(uninst --dry-run)
check "uninstall --dry-run lists the files it would keep, and not the caches" \
  'printf "%s" "$out" | grep -qF "would keep     ~/.claude/palmface/state/cost-tracker/sessions.tsv" && printf "%s" "$out" | grep -qF "would keep     ~/.config/palmface/mine/notes with space.txt" && ! printf "%s" "$out" | grep -q "cache.json"' "$out"
out=$(uninst); rc=$?
K=$(find "$H/.palmface-backup" -maxdepth 2 -type d -path '*/uninstall-*/kept' | head -n1)
check "uninstall moves them to ~/.palmface-backup/uninstall-<ts>/kept/ instead of deleting them" \
  '[ $rc -eq 0 ] && [ "$(cat "$K/.claude/palmface/state/cost-tracker/sessions.tsv")" = "a ledger row" ] && [ "$(cat "$K/.config/palmface/mine/notes with space.txt")" = "my notes" ] && printf "%s" "$out" | grep -q "kept      1 file(s) made in ~/.claude/palmface/"' "$out"
check "the caches and the kit folders are gone, and the backup stays (something was kept)" \
  '[ ! -e "$H/.claude/palmface" ] && [ ! -e "$H/.config/palmface" ] && [ ! -e "$K/.claude/palmface/state/statusline" ] && ls "$H/.palmface-backup"/manifest.uninstalled-*.tsv > /dev/null 2>&1' "$(find "$H/.palmface-backup" 2>&1 | head -40)"
S=$(snapshot "$H")
check "everything else comes back exactly" '[ "$(printf "%s\n" "$S" | grep -v " \./\.palmface-backup")" = "$S0" ]' "$(snap_diff "$S0" "$(printf "%s\n" "$S" | grep -v " \./\.palmface-backup")")"
rm_home "$H"

echo "1b2. a symlinked ~/.config: the post script is skipped, nothing lands in the dotfiles repo"
H=$(new_home) || exit 2
mkdir -p "$H/dotfiles/config"
ln -s dotfiles/config "$H/.config"
out=$(inst --all --dry-run)
check "dry run: the post script is reported as skipped" 'printf "%s" "$out" | grep -q "skipped terminal/files/post.sh: ~/.config is a symlink"' "$out"
out=$(inst --all); rc=$?
check "install exits 0 and warns that it skipped the post script" \
  '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "skipped terminal/files/post.sh: ~/.config is a symlink" && ! printf "%s" "$out" | grep -q "run   terminal/files/post.sh"' "$out"
check "nothing was written into the dotfiles repo" '[ -z "$(ls -A "$H/dotfiles/config")" ]' "$(find "$H/dotfiles")"
rm_home "$H"

echo "1c. uninstall acts only on clean manifest paths inside the home"
H=$(new_home) || exit 2
inst --all > /dev/null
mkdir -p "$H/../palmface-outside.$$" && printf 'keep\n' > "$H/../palmface-outside.$$/victim.txt"
printf 'touch\t../palmface-outside.%s/victim.txt\tcopy\tabsent\t-\t-\tx\nmkdir\t../palmface-outside.%s\n' $$ $$ >> "$(MAN)"
printf 'touch\t/etc/hosts\tcopy\tabsent\t-\t-\tx\n' >> "$(MAN)"
out=$(uninst); rc=$?
check "a manifest path with .. or a leading / is refused with a warning, and nothing outside the home is touched" \
  '[ $rc -eq 1 ] && [ "$(cat "$H/../palmface-outside.$$/victim.txt")" = keep ] && [ "$(printf "%s" "$out" | grep -c "not a clean path inside your home")" = 3 ]' "$out"
rm -rf "$H/../palmface-outside.$$"
rm_home "$H"

echo "2. seeded home"
H=$(new_home) || exit 2
seed_home "$H"
mkdir -p "$H/dotfiles/linkdir"
ln -s dotfiles/linkdir "$H/linked" # a directory managed by a symlink
S0=$(snapshot "$H")
ZSHRC0=$(cat "$H/.zshrc")
out=$(inst --all); rc=$?
check "install exits 0" '[ $rc -eq 0 ]' "$out"
check_manifest "$H"
check "symlinked dotfile is left alone" '[ -L "$H/.tmux.conf" ] && [ "$(cat "$H/dotfiles/tmux.conf")" = "set -g mouse on" ]'
check "symlink skip prints the manual lines, markers on their own lines" 'printf "%s" "$out" | grep -q "skipped ~/.tmux.conf: ~/.tmux.conf is a symlink" && printf "%s\n" "$out" | grep -qx "    # <<< palmface:terminal <<<"' "$out"
check "nothing is written through a symlinked parent dir" '[ ! -e "$H/dotfiles/linkdir/note.txt" ] && printf "%s" "$out" | grep -q "skipped ~/linked/note.txt: ~/linked is a symlink"' "$out"
check "user zshrc kept, newline added, block appended once" '[ "$(head -n3 "$H/.zshrc")" = "$ZSHRC0" ] && [ "$(count "$H/.zshrc" "# >>> palmface:terminal >>>")" = 1 ]' "$(cat "$H/.zshrc")"
check "json merge: user scalar wins" 'jq -e ".model == \"sonnet\"" "$H/.claude/settings.json" >/dev/null'
check "json merge: kit key added" 'jq -e ".statusLine.type == \"command\"" "$H/.claude/settings.json" >/dev/null'
check "json merge: arrays unioned, no duplicates" 'jq -e ".permissions.allow == [\"Bash(ls:*)\", \"Read\"]" "$H/.claude/settings.json" >/dev/null' "$(cat "$H/.claude/settings.json")"
BK=$(awk -F'\t' '$1 == "touch" && $2 == ".claude/agents/helper.md" { print $5 }' "$(MAN)")
check "replaced user file backed up byte-exact" '[ -n "$BK" ] && [ "$(cat "$H/.palmface-backup/$BK")" = "my own helper" ]'
check "write into a dir with spaces" '[ -f "$H/Library/Application Support/Some App/palmface.txt" ]'
S1=$(snapshot "$H")
out=$(inst --all)
S=$(snapshot "$H")
check "second install changes nothing" '[ "$S" = "$S1" ]' "$(snap_diff "$S1" "$S")"
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "uninstall restores the seeded home exactly (modes too)" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
rm_home "$H"

echo "3. kit source changes between installs"
H=$(new_home) || exit 2
seed_home "$H"
S0=$(snapshot "$H")
inst --all > /dev/null
cp "$T/vibes.zsh" "$FIX/vibes.orig"; cp "$T/zshrc.block" "$FIX/block.orig"
printf 'echo vibes v2\n' > "$T/vibes.zsh"
printf 'source ~/.config/palmface/zsh/vibes.zsh  # v2\n' > "$T/zshrc.block"
out=$(inst --all); rc=$?
check "re-install with new sources exits 0" '[ $rc -eq 0 ]' "$out"
check "kit file updated" '[ "$(cat "$H/.config/palmface/zsh/vibes.zsh")" = "echo vibes v2" ]'
check "block replaced in place, still once" '[ "$(count "$H/.zshrc" "# >>> palmface:terminal >>>")" = 1 ] && grep -q "# v2" "$H/.zshrc"' "$(cat "$H/.zshrc")"
check_manifest "$H"
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "uninstall still restores the originals exactly" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
mv "$FIX/vibes.orig" "$T/vibes.zsh"; mv "$FIX/block.orig" "$T/zshrc.block"
rm_home "$H"

echo "4. user edits after install"
H=$(new_home) || exit 2
seed_home "$H"
inst --all > /dev/null
printf 'my tweak\n' >> "$H/.config/palmface/zsh/vibes.zsh"
out=$(inst --all)
check "re-install stashes an edited kit file first" 'f=$(ls "$H"/.palmface-backup/*/edited/.config/palmface/zsh/vibes.zsh 2>/dev/null) && grep -q "my tweak" "$f"' "$out"
check "re-install then restores the kit version" '[ "$(cat "$H/.config/palmface/zsh/vibes.zsh")" = "echo vibes" ]'
printf 'my tweak again\n' >> "$H/.config/palmface/zsh/vibes.zsh"
printf "alias gs='git status'\n" >> "$H/.zshrc"
jq '.theme = "dark"' "$H/.claude/settings.json" > "$H/s.tmp" && mv "$H/s.tmp" "$H/.claude/settings.json"
out=$(uninst); rc=$?
check "uninstall exits 0" '[ $rc -eq 0 ]' "$out"
check "dotfile keeps the user's later edit, loses the block" 'grep -qxF "alias gs='"'"'git status'"'"'" "$H/.zshrc" && ! grep -q "palmface:" "$H/.zshrc" && [ "$(head -n1 "$H/.zshrc")" = "# my zshrc" ]' "$(cat "$H/.zshrc")"
check "edited kit file saved under kept/ and removed" '[ ! -e "$H/.config/palmface" ] && grep -q "my tweak again" "$H"/.palmface-backup/uninstall-*/kept/.config/palmface/zsh/vibes.zsh'
check "edited settings.json loses only what Palmface added" 'jq -e ".theme == \"dark\" and .model == \"sonnet\" and (has(\"statusLine\") | not) and .permissions.allow == [\"Bash(ls:*)\"]" "$H/.claude/settings.json" >/dev/null' "$out$(cat "$H/.claude/settings.json")"
check "the settings.json it rewrote is kept first" 'jq -e ".statusLine" "$H"/.palmface-backup/uninstall-*/kept/.claude/settings.json >/dev/null'
check "state dir kept, manifest retired" '[ -d "$H/.palmface-backup" ] && [ ! -f "$(MAN)" ] && ls "$H"/.palmface-backup/manifest.uninstalled-*.tsv >/dev/null 2>&1'
out=$(uninst); rc=$?
check "a second uninstall has nothing to do" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "nothing to uninstall"' "$out"
rm_home "$H"

echo "5. crash mid-install"
H=$(new_home) || exit 2
seed_home "$H"
chmod 555 "$H/Library/Application Support/Some App" # the 7th terminal entry cannot be written
S0=$(snapshot "$H")
out=$(inst --all); rc=$?
check "install fails" '[ $rc -ne 0 ]' "$out"
check "some files were written before the failure" '[ -f "$H/.config/palmface/zsh/vibes.zsh" ]'
check "the uninstaller is in place even though install failed" '[ -x "$H/.palmface-backup/uninstall.sh" ]'
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "uninstall after a crash restores the pre-install home" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
rm_home "$H"

echo "6. written but never recorded done (crash between write and record)"
H=$(new_home) || exit 2
seed_home "$H"
ZSHRC_SHA=$(shasum -a 256 < "$H/.zshrc")
inst --all > /dev/null
grep -v "^done$(printf '\t').zshrc$(printf '\t')" "$(MAN)" > "$H/m.tmp"; mv "$H/m.tmp" "$(MAN)"
out=$(uninst); rc=$?
check "the original comes back" '[ $rc -eq 0 ] && [ "$(shasum -a 256 < "$H/.zshrc")" = "$ZSHRC_SHA" ]' "$out"
check "the unrecorded version is kept, not lost" 'grep -q "palmface:terminal" "$H"/.palmface-backup/uninstall-*/kept/.zshrc'
rm_home "$H"

echo "6b. a lost done is repaired by the next install"
H=$(new_home) || exit 2
seed_home "$H"
S0=$(snapshot "$H")
inst --all > /dev/null
grep -v "^done$(printf '\t').zshrc$(printf '\t')" "$(MAN)" > "$H/m.tmp"; mv "$H/m.tmp" "$(MAN)"
inst --all > /dev/null
n_done=$(awk -F'\t' '$1 == "done" && $2 == ".zshrc"' "$(MAN)" | wc -l | tr -d ' ')
check "the next install records it again" '[ "$n_done" = 1 ]'
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "and uninstall is exact again" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
rm_home "$H"

echo "7. bad input"
H=$(new_home) || exit 2
S0=$(snapshot "$H")
bad_line() { # description, layer.tsv line
  printf '%s\n' "$2" > "$FIX/extras/layer.tsv"
  out=$(inst --extras); rc=$?
  S=$(snapshot "$H")
  check "rejects $1, writes nothing" '[ $rc -ne 0 ] && [ "$S" = "$S0" ]' "$out"
}
printf 'x\n' > "$FIX/extras/x.txt"
bad_line "an absolute dest"     "$(printf 'copy\tx.txt\t/etc/x')"
bad_line "a ~ dest"             "$(printf 'copy\tx.txt\t~/x')"
bad_line "a .. dest"            "$(printf 'copy\tx.txt\t.config/../../x')"
bad_line "a .. src"             "$(printf 'copy\t../install.sh\t.x')"
bad_line "an unknown mode"      "$(printf 'link\tx.txt\t.x')"
bad_line "a missing src"        "$(printf 'copy\tnope.txt\t.x')"
bad_line "a two-field line"     "$(printf 'copy\tx.txt')"
bad_line "a block into JSON"    "$(printf 'block\tx.txt\t.claude/settings.json')"
bad_line "a non-object json"    "$(printf 'json\tx.txt\t.claude/settings.json')"
bad_line "a post with a dest"   "$(printf 'post\tx.txt\t.x')"
bad_line "two copies to one dest" "$(printf 'copy\tx.txt\t.x\ncopy\tx.txt\t.x')"
bad_line "two blocks from one layer into one file" "$(printf 'block\tx.txt\t.zshrc\nblock\tx.txt\t.zshrc')"
printf '# empty\n' > "$FIX/extras/layer.tsv"
out=$(inst --extras); rc=$?
check "an empty layer is a no-op" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "nothing to install"' "$out"
out=$(inst); rc=$?
check "no flags exits 2" '[ $rc -eq 2 ]'
out=$(inst --bogus); rc=$?
check "unknown flag exits 2" '[ $rc -eq 2 ]'
out=$(inst --dry-run); rc=$?
check "dry-run without a layer exits 2" '[ $rc -eq 2 ]'
out=$(uninst); rc=$?
S=$(snapshot "$H")
check "uninstall with no manifest is a no-op" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out"
rm_home "$H"

echo "9. user edits, then a kit update, then uninstall"
H=$(new_home) || exit 2
seed_home "$H"
inst --all > /dev/null
printf "alias gs='git status'\n" >> "$H/.zshrc"
jq '.theme = "dark"' "$H/.claude/settings.json" > "$H/s.tmp" && mv "$H/s.tmp" "$H/.claude/settings.json"
cp "$T/zshrc.block" "$FIX/block.orig"; cp "$C/settings.json" "$FIX/settings.orig"
printf 'source ~/.config/palmface/zsh/vibes.zsh  # v2\n' > "$T/zshrc.block"
jq -c '.env = {"PALMFACE": "1"}' "$FIX/settings.orig" > "$C/settings.json"
out=$(inst --all); rc=$?
check "re-install with new kit content exits 0" '[ $rc -eq 0 ]' "$out"
n_edit=$(awk -F'\t' '$1 == "edited" && ($2 == ".zshrc" || $2 == ".claude/settings.json")' "$(MAN)" | wc -l | tr -d ' ')
check "re-install records that the user edited both files" '[ "$n_edit" = 2 ]'
out=$(uninst); rc=$?
check "the dotfile edit survives a kit update + uninstall" '[ $rc -eq 0 ] && grep -qxF "alias gs='"'"'git status'"'"'" "$H/.zshrc" && ! grep -q "palmface:" "$H/.zshrc"' "$out$(cat "$H/.zshrc")"
check "the settings edit survives; old and new Palmface keys are gone" 'jq -e ".theme == \"dark\" and .model == \"sonnet\" and (has(\"statusLine\") | not) and (has(\"env\") | not) and .permissions.allow == [\"Bash(ls:*)\"]" "$H/.claude/settings.json" >/dev/null' "$out$(cat "$H/.claude/settings.json")"
mv "$FIX/block.orig" "$T/zshrc.block"; mv "$FIX/settings.orig" "$C/settings.json"
rm_home "$H"

echo "10. stashes survive an otherwise exact uninstall"
H=$(new_home) || exit 2
seed_home "$H"
S0=$(snapshot "$H" | grep -v '\./\.palmface-backup')
inst --all > /dev/null
printf 'my tweak\n' >> "$H/.config/palmface/zsh/vibes.zsh"
inst --all > /dev/null # stashes the tweak under edited/, puts the kit version back
out=$(uninst); rc=$?
S=$(snapshot "$H" | grep -v '\./\.palmface-backup')
check "everything outside the state dir is back exactly" '[ $rc -eq 0 ] && [ "$S" = "$S0" ]' "$out$(snap_diff "$S0" "$S")"
check "the edit install stashed is still there" 'grep -q "my tweak" "$H"/.palmface-backup/*/edited/.config/palmface/zsh/vibes.zsh' "$out"
inst --all > /dev/null
out=$(uninst); rc=$?
check "a later exact uninstall keeps the earlier stash and records" '[ $rc -eq 0 ] && grep -q "my tweak" "$H"/.palmface-backup/*/edited/.config/palmface/zsh/vibes.zsh && ls "$H"/.palmface-backup/manifest.uninstalled-*.tsv >/dev/null 2>&1' "$out"
rm_home "$H"

echo "11. damaged and CRLF blocks"
H=$(new_home) || exit 2
seed_home "$H"
inst --all > /dev/null
grep -v '^# <<< palmface:terminal <<<$' "$H/.zshrc" > "$H/z.tmp"; cat "$H/z.tmp" > "$H/.zshrc"; rm "$H/z.tmp"
Z=$(shasum -a 256 < "$H/.zshrc")
out=$(uninst); rc=$?
check "a block missing its close marker is left alone, with a warning" '[ "$(shasum -a 256 < "$H/.zshrc")" = "$Z" ] && printf "%s" "$out" | grep -q "unbalanced Palmface marker"' "$out"
rm_home "$H"
H=$(new_home) || exit 2
seed_home "$H"
inst --all > /dev/null
awk '{ printf "%s\r\n", $0 }' "$H/.zshrc" > "$H/z.tmp"; cat "$H/z.tmp" > "$H/.zshrc"; rm "$H/z.tmp"
out=$(inst --all); rc=$?
check "re-install finds a CRLF block instead of adding a second one" '[ $rc -eq 0 ] && [ "$(grep -c "palmface:terminal >>>" "$H/.zshrc")" = 1 ]' "$out$(cat -v "$H/.zshrc")"
out=$(uninst); rc=$?
check "uninstall strips CRLF blocks and keeps the rest" '[ $rc -eq 0 ] && ! grep -q "palmface:" "$H/.zshrc" && grep -q "alias ll" "$H/.zshrc"' "$out$(cat -v "$H/.zshrc")"
check "the pre-strip file is kept" 'ls "$H"/.palmface-backup/uninstall-*/kept/.zshrc >/dev/null 2>&1'
rm_home "$H"

echo "12. settings created by Palmface, then edited"
H=$(new_home) || exit 2
inst --claude > /dev/null
jq '.theme = "dark"' "$H/.claude/settings.json" > "$H/s.tmp" && mv "$H/s.tmp" "$H/.claude/settings.json"
out=$(uninst); rc=$?
check "only the user's own key is left" '[ $rc -eq 0 ] && jq -e ". == {\"theme\": \"dark\"}" "$H/.claude/settings.json" >/dev/null' "$out$(cat "$H/.claude/settings.json" 2>&1)"
rm_home "$H"

echo "8. the guard"
( guard_home "$REAL_HOME" ) 2> /dev/null; rc=$?
check "refuses the real home" '[ $rc -ne 0 ]'
( guard_home "$REAL_HOME/Projects" ) 2> /dev/null; rc=$?
check "refuses a dir inside the real home" '[ $rc -ne 0 ]'
( guard_home "/tmp/elsewhere" ) 2> /dev/null; rc=$?
check "refuses a dir outside \$TMPDIR" '[ $rc -ne 0 ]'
( guard_home "$TMP_ROOT/not-a-palmface-home" ) 2> /dev/null; rc=$?
check "refuses a \$TMPDIR dir it did not create" '[ $rc -ne 0 ]'

summary "framework"

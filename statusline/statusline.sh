#!/bin/bash
# Palmface statusline. Claude Code pipes its status JSON to this script on stdin, and prints
# whatever it writes to stdout under the prompt.
#
# It finds node on PATH first, then in Homebrew's two prefixes, because an app started from the
# Dock may not have Homebrew on its PATH. Without node, or with a node too old to load it (it
# needs 18 or newer), it prints a one-line hint, so the status area never shows an error.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
node=$(command -v node 2> /dev/null)
if [ -z "$node" ]; then
  for d in /opt/homebrew/bin /usr/local/bin; do
    if [ -x "$d/node" ]; then node=$d/node; break; fi
  done
fi
if [ -z "$node" ]; then
  cat > /dev/null # read the status JSON so Claude Code never sees a broken pipe
  printf 'statusline: node not found (brew install node)\n'
  exit 0
fi
# The statusline itself always exits 0; a failure here means node could not load it at all.
"$node" "$dir/dist/index.js" || printf 'statusline: needs node 18 or newer (brew install node)\n'
exit 0

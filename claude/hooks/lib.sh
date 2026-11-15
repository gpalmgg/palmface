# shellcheck shell=bash
# Palmface hook helpers. Sourced by the hooks beside it, never run on its own.
#
# Stock macOS only: bash 3.2, /usr/bin/plutil (it reads JSON), awk, grep, tail. No python, jq or
# node, so the hooks work when Claude Code is started from the Dock with a bare PATH.
# Every helper fails quietly: a hook that can't read something does nothing and exits 0.

# Byte semantics everywhere. Every pattern here is ASCII, and macOS awk aborts on a byte
# sequence that isn't valid UTF-8 (a transcript cut mid-character, a window that starts inside
# an emoji) when the locale is UTF-8. Text passes through unchanged either way.
export LC_ALL=C
# Hook state can hold prompt text: new files and folders are yours alone (0600 / 0700).
umask 077

KH_STATE="${HOME:+$HOME/.claude/palmface/state}"
KH_INPUT=''

kh_read() { # read the hook's JSON from stdin (Claude Code always sends one); no HOME, no hook
  if [ -t 0 ]; then KH_INPUT=''; else KH_INPUT=$(cat); fi
  [ -n "${HOME:-}" ] || exit 0
}

kh_off() { # this hook's switch value: true when it, or every Palmface hook, is switched off
  [ "${PALMFACE_HOOKS:-on}" = off ] || [ "${1:-on}" = off ]
}

kh_get() { # key: a top-level field of the hook JSON as text ("" when absent, or not JSON)
  [ -n "$KH_INPUT" ] || return 0
  printf '%s' "$KH_INPUT" | /usr/bin/plutil -extract "$1" raw -o - - 2> /dev/null || true
}

kh_session() { # the session id, made safe for a file name
  local s
  s=$(kh_get session_id | tr -cd 'A-Za-z0-9_-' | cut -c1-80)
  printf '%s\n' "${s:-default}"
}

kh_state_dir() { # hook name: its state dir under ~/.claude/palmface/state (created), or fail
  [ -n "$KH_STATE" ] || return 1
  local d="$KH_STATE/$1"
  mkdir -p "$d" 2> /dev/null && [ -w "$d" ] || return 1
  chmod 700 "$KH_STATE" "$d" 2> /dev/null # folders an older version made with the default umask
  printf '%s\n' "$d"
}

kh_autopilot_switch() { # project folder: its autopilot switch, which lives outside the project
  # ~/.claude/palmface/state/autopilot/<sha256 of the folder's physical path>. Written only by
  # the palmface-autopilot skill's autopilot.sh; start.sh computes the same path. Never a file
  # inside the project, so a repository can't switch autopilot on by shipping one.
  local d
  [ -n "$KH_STATE" ] || return 1
  d=$(cd "$1" 2> /dev/null && pwd -P) || return 1
  printf '%s/autopilot/%s\n' "$KH_STATE" "$(printf '%s' "$d" | /usr/bin/shasum -a 256 | cut -c1-64)"
}

kh_unattended() { # true when nobody is there to answer a question
  # Autopilot (see ~/.claude/palmface/references/autopilot.md): PALMFACE_AUTOPILOT=on, or the
  # user's switch for the session's folder (kh_autopilot_switch). A .autopilot/ folder inside a
  # project is ignored. Claude Code also marks runs nobody watches (claude -p) with
  # CLAUDE_CODE_SESSION_ATTENDED=0 in the versions that set it.
  [ "${PALMFACE_AUTOPILOT:-off}" = on ] && return 0
  [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 0 ] && return 0
  local cwd sw
  cwd=$(kh_get cwd)
  [ -n "$cwd" ] && sw=$(kh_autopilot_switch "$cwd") && [ -f "$sw" ] && [ ! -L "$sw" ]
}

kh_mask() { # stdin -> stdout with key-shaped strings replaced by [hidden] (before anything is saved)
  /usr/bin/sed -E \
    -e 's/(^|[^A-Za-z0-9_-])(sk|pk|rk)-[A-Za-z0-9_-]{16,}/\1[hidden]/g' \
    -e 's/(^|[^A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{16,}/\1[hidden]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{16,}/[hidden]/g' \
    -e 's/(^|[^A-Za-z0-9_])xox[abposr]-[A-Za-z0-9-]{8,}/\1[hidden]/g' \
    -e 's/(AKIA|ASIA)[0-9A-Z]{16}/[hidden]/g' \
    -e 's/AIza[0-9A-Za-z_-]{20,}/[hidden]/g' \
    -e 's/(sk|rk|pk)_live_[0-9A-Za-z]{10,}/[hidden]/g' \
    -e 's/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(\.[A-Za-z0-9_-]+)?/[hidden]/g' \
    -e 's/[0-9a-fA-F]{32,}/[hidden]/g'
}

kh_prose() { # stdin -> Claude's own words: no code, quoted text or blockquotes; ’ “ ” made plain
  # shellcheck disable=SC1112  # the curly quotes are what this filter turns into plain ones
  /usr/bin/awk '
    { gsub(/\r/, "") }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^[ \t]*>/ { next }
    {
      gsub(/“|”/, "\""); gsub(/‘|’/, "\047")
      gsub(/`[^`]*`/, ""); gsub(/"[^"]*"/, "")
      print
    }'
}

kh_transcript() { # the session transcript's path, when it is a readable file
  local t
  t=$(kh_get transcript_path)
  [ -n "$t" ] && [ -f "$t" ] && [ -r "$t" ] && printf '%s\n' "$t"
}

kh_tail() { # bytes, file: the file's last whole lines within that many bytes
  local size
  size=$(stat -f %z "$2" 2> /dev/null) || return 0
  if [ "${size:-0}" -gt "$1" ]; then
    tail -c "$1" "$2" 2> /dev/null | sed 1d # the first line is cut part-way: drop it
  else
    cat "$2" 2> /dev/null
  fi
}

# Transcript lines are compact JSON. A typed prompt is a "user" line that is not a tool result
# and not hook feedback (isMeta); text that merely mentions those keys is escaped, so it never
# matches.
KH_TYPED='/"type":"user"/ && !/"tool_result"/ && !/"isMeta":true/'

kh_asked() { # true when Claude used AskUserQuestion since the user's last prompt (best effort)
  local t
  t=$(kh_transcript) || return 1
  kh_tail 2000000 "$t" | /usr/bin/awk "
    $KH_TYPED { asked = 0; next }
    /\"type\":\"tool_use\"/ && /\"name\":\"AskUserQuestion\"/ { asked = 1 }
    END { exit !asked }"
}

kh_reply() { # Claude's final reply this turn: the Stop hook's field, else the transcript's
  local m t line
  m=$(kh_get last_assistant_message)
  if [ -z "$m" ] && t=$(kh_transcript); then
    # The last assistant text block after the user's last prompt (older Claude Code versions
    # don't send last_assistant_message).
    line=$(kh_tail 4000000 "$t" | /usr/bin/awk "
      $KH_TYPED { last = \"\"; next }
      /\"type\":\"assistant\"/ && /\"type\":\"text\"/ { last = \$0 }
      END { if (last != \"\") print last }")
    [ -n "$line" ] && m=$(printf '%s' "$line" | /usr/bin/plutil -extract message.content.0.text raw -o - - 2> /dev/null)
  fi
  printf '%s' "$m"
}

kh_last_prompt() { # transcript: the user's last typed request (best effort, first 800 bytes)
  local line c i
  # Newest first; skip slash-command records and compaction summaries, which are stored as user
  # lines too.
  kh_tail 4000000 "$1" | /usr/bin/grep '"type":"user"' | /usr/bin/grep -v '"tool_result"' |
    /usr/bin/grep -v '"isMeta":true' | tail -20 | tail -r | while IFS= read -r line; do
    # content is a string, or a list of blocks (text, images). "raw" on a list prints its
    # length, so ask for the JSON form first: plutil writes it for a list, not for a string.
    c=''
    case "$(printf '%s' "$line" | /usr/bin/plutil -extract message.content json -o - - 2> /dev/null)" in
      '['*)
        for i in 0 1 2 3; do
          c=$(printf '%s' "$line" | /usr/bin/plutil -extract "message.content.$i.text" raw -o - - 2> /dev/null) && break
        done
        ;;
      *) c=$(printf '%s' "$line" | /usr/bin/plutil -extract message.content raw -o - - 2> /dev/null) ;;
    esac
    case "$c" in '' | '<command-'* | '<local-command'* | 'This session is being continued'*) continue ;; esac
    printf '%s' "$c" | head -c 800
    printf '\n'
    break
  done
}

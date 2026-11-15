# Palmface: vibes.zsh, the alive terminal for zsh.
# Rosé Pine colours, friendlier everyday tools, a few toys, a hello greeting, an idle screensaver.
#
# Sourced from a palmface block at the end of ~/.zshrc. Kit-owned: a re-install replaces this
# file, so change things in ~/.zshrc AFTER the palmface block (or comment the block out).
# Every tool is optional: each part checks that its tool exists, so a bare Mac sees no errors.
# Install the tools with: brew bundle --file=<the kit>/Brewfile
# It defers to you: an alias or function you already have keeps its name, and a tool with its
# own config file (starship, bat, fzf) keeps using yours.
#
# Switches (export them, or set them in ~/.zshrc before the palmface block):
#   PALMFACE_GREETING=off      no hello greeting in new windows (`hello` still works)
#   PALMFACE_SCREENSAVER=off   no idle screensaver at a bare prompt

[[ -o interactive ]] || return 0

typeset -g _palmface_dir="$HOME/.config/palmface"
_palmface_have() { (( $+commands[$1] )); }
_palmface_alias() { (( $+aliases[$1] || $+functions[$1] )) || alias -- "$1=$2"; } # yours win

# ── Functions first, so the aliases further down never leak into them ──────────────────────

# Fresh lines for the greeting and the critters (when fortune is not installed).
typeset -ga _palmface_lines=(
  "the kettle's on. what are we making today?"
  "one thing at a time, all the way through."
  "the terminal is awake. so are you."
  "make it work, then make it kind."
  "read the error message twice. it's trying to help."
  "small commits, warm hands."
  "leave the code a little better than you found it."
  "breathe out. then type."
  "write it down: future you is listening."
  "nothing here is urgent except curiosity."
  "good tools, quiet mind."
  "if it's hard to explain, it's probably two things."
  "the tests are a letter to tomorrow."
  "ask the question you're avoiding first."
  "a clear name is worth ten comments."
  "done is a feeling. finished is a checklist."
)
_palmface_line() { emulate -L zsh; print -r -- "${_palmface_lines[RANDOM % ${#_palmface_lines} + 1]}"; }

# print text centred in the window (colour codes don't count toward the width)
_palmface_center() {
  emulate -L zsh
  setopt extendedglob
  local line plain pad
  for line in "${(@f)1}"; do
    plain=${line//$'\e'\[[0-9;]#m/}
    pad=$(( (COLUMNS - ${#plain}) / 2 ))
    (( pad < 0 )) && pad=0
    print -r -- "${(l:$pad:: :)}$line"
  done
}

# One critter of a kind (owl|cat) from Palmface's critter bank, which the claude layer installs
# at ~/.claude/palmface/critters.txt, plus your own ~/.claude/palmface-local/critters.txt. Every
# line is padded to the same width. Prints nothing without a bank or a critter of that kind.
_palmface_critter() {
  emulate -L zsh
  local f row art w=0
  local -a banks
  for f in $HOME/.claude/palmface/critters.txt $HOME/.claude/palmface-local/critters.txt; do
    [[ -r $f ]] && banks+=($f)
  done
  (( $#banks )) || return 1
  art=$(/usr/bin/awk -v kind="$1" -v r="$RANDOM" '
    { sub(/\r$/, "") }
    FNR == 1 { inrec = 0 }
    /^@ / { n++; k[n] = $2; a[n] = ""; inrec = 1; next }
    inrec && /^[[:space:]]*$/ { inrec = 0; next }
    inrec { a[n] = (a[n] == "" ? $0 : a[n] "\n" $0) }
    END {
      for (i = 1; i <= n; i++) if (k[i] == kind && a[i] != "") s[++m] = i
      if (m) print a[s[r % m + 1]]
    }' $banks 2> /dev/null)
  [[ -n $art ]] || return 1
  for row in "${(@f)art}"; do (( ${#row} > w )) && w=${#row}; done
  for row in "${(@f)art}"; do print -r -- "${(r:w:: :)row}"; done
}

# hello: a banner, a critter (owl by night, cat by day) and a line. Runs once per new window.
# The critter comes from the bank when the claude layer is installed, else one of these two.
hello() {
  emulate -L zsh
  local iris=$'\e[35m' muted=$'\e[90m' off=$'\e[0m' hour kind critter
  hour=$(date +%H)
  if (( 10#$hour >= 19 || 10#$hour < 7 )); then kind=owl; else kind=cat; fi
  critter=$(_palmface_critter $kind)
  if [[ -z $critter && $kind == owl ]]; then
    critter=$'  {o,o}  \n  |)__)  \n  -"-"-  '
  elif [[ -z $critter ]]; then
    critter=$' /\\_/\\ \n( o.o )\n > ^ < '
  fi
  print
  if _palmface_have figlet; then
    if _palmface_have lolcat; then
      figlet -f small -c -w "$COLUMNS" hello | lolcat
    else
      print -r -- "$iris$(figlet -f small -c -w "$COLUMNS" hello)$off"
    fi
  fi
  _palmface_center "$(print -r -- "$critter" | sed "s/^/${iris}/;s/\$/${off}/")"
  _palmface_center "${muted}$(_palmface_line)${off}"
  print
}

# critters with something to say: owl, meow (a cat), nap (a sleepy cat)
_palmface_cow() {
  emulate -L zsh
  local cow=$1 msg
  shift
  _palmface_have cowsay || { print -u2 "cowsay is not installed (brew install cowsay)"; return 1; }
  if (( $# )); then
    msg="$*"
  elif _palmface_have fortune; then
    msg=$(fortune -s)
  else
    msg=$(_palmface_line)
  fi
  if _palmface_have lolcat; then
    cowsay -f "$cow" -- "$msg" | lolcat
  else
    cowsay -f "$cow" -- "$msg"
  fi
}
owl()  { _palmface_cow owl "$@"; }
meow() { _palmface_cow cat "$@"; }
nap()  { _palmface_cow sleepycat "${@:-zzz... the terminal dreams in Rosé Pine}"; }

# ── Cows: Palmface's owl, cat and sleepycat, ahead of cowsay's own ──────────────────────────
if [[ -d $_palmface_dir/cows && :${COWPATH-}: != *:$_palmface_dir/cows:* ]]; then
  export COWPATH="$_palmface_dir/cows${COWPATH:+:$COWPATH}"
fi

# ── Listing: eza with icons and git status. New names, so ls itself keeps its usual flags ──
if _palmface_have eza; then
  _palmface_alias ll 'eza -la --icons=auto --group-directories-first --git --time-style=relative'
  _palmface_alias la 'eza -a --icons=auto --group-directories-first'
  _palmface_alias lt 'eza -T --icons=auto -L 2 --git-ignore'
fi

# ── Reading: bat (the alias is for you; scripts still get the real cat) ─────────────────────
if _palmface_have bat; then
  # ansi = your terminal's colours (follows Moon/Dawn), unless you set a theme yourself
  [[ -n ${BAT_THEME-} || -f ${BAT_CONFIG_PATH:-$HOME/.config/bat/config} ]] || export BAT_THEME=ansi
  _palmface_alias cat 'bat --paging=never --style=plain'
  [[ -n ${MANPAGER-} ]] || export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
_palmface_have glow && _palmface_alias md 'glow'                   # render markdown
_palmface_have chafa && _palmface_alias show 'chafa --format=kitty' # an image as real pixels in Ghostty

# ── fzf in Rosé Pine (ANSI slots, so it follows light/dark), with bat/eza previews ──────────
if _palmface_have fzf; then
  if [[ -z ${FZF_DEFAULT_OPTS-} && -z ${FZF_DEFAULT_OPTS_FILE-} ]]; then
    export FZF_DEFAULT_OPTS="
      --color=fg:-1,bg:-1,hl:6,fg+:7,bg+:0,hl+:6
      --color=border:8,header:2,gutter:-1,spinner:3,info:4
      --color=pointer:5,marker:1,prompt:8
      --border=rounded --pointer='❯' --marker='✦' --prompt='∷ '"
  fi
  [[ -n ${FZF_CTRL_T_OPTS-} ]] || export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || eza -T --icons=always -L 2 {} 2>/dev/null || ls {}'"
  [[ -n ${FZF_ALT_C_OPTS-} ]] || export FZF_ALT_C_OPTS="--preview 'eza -T --icons=always -L 2 {} 2>/dev/null || ls {}'"
  # Ctrl-T files, Ctrl-R history, Alt-C directories (fzf 0.48+). Key bindings need the line
  # editor, so they load only with a terminal on stdin (not in `zsh -i -c` run from a script).
  if [[ -o zle && -t 0 ]] && fzf --zsh > /dev/null 2>&1; then source <(fzf --zsh); fi
fi

# ── Jumping: zoxide (z <part of a dir name>, zi = pick interactively) ───────────────────────
_palmface_have zoxide && eval "$(zoxide init zsh)"

# ── tmux layouts: mux <name> starts ~/.config/tmuxinator/<name>.yml ─────────────────────────
_palmface_have tmuxinator && _palmface_alias mux 'tmuxinator'

# ── Toys ────────────────────────────────────────────────────────────────────────────────────
if _palmface_have cbonsai; then
  _palmface_alias zen 'cbonsai -l -i -L 40 -t 0.06'
  _palmface_alias bonsai 'cbonsai -p -L 32'
fi
_palmface_have asciiquarium && _palmface_alias aquarium 'asciiquarium'
_palmface_have pipes.sh && _palmface_alias pipes 'pipes.sh -t 3 -R -r 4000'
_palmface_have cmatrix && _palmface_alias matrix 'cmatrix -C magenta -b'
_palmface_have nyancat && _palmface_alias nyan 'nyancat'
_palmface_alias screensaver '~/.config/palmface/bin/screensaver.sh'
_palmface_alias stars 'PALMFACE_SCREENSAVER=stars ~/.config/palmface/bin/screensaver.sh'

# ── Prompt: starship with Palmface's Rosé Pine config. Steps aside for your own starship.toml
#    or STARSHIP_CONFIG, and for a prompt theme you already run (powerlevel10k, pure, oh-my-zsh). ──
if _palmface_have starship \
  && [[ -z ${ZSH_THEME-} ]] \
  && (( ! $+functions[p10k] && ! $+functions[prompt_powerlevel10k_setup] && ! $+functions[prompt_pure_setup] )); then
  [[ -n ${STARSHIP_CONFIG-} || -f $HOME/.config/starship.toml ]] \
    || export STARSHIP_CONFIG="$_palmface_dir/starship.toml"
  (( $+functions[prompt_starship_precmd] )) || eval "$(starship init zsh)"
fi

# ── Greeting: once per new terminal window (not in tmux panes, not in nested shells, and not
#    under powerlevel10k's instant prompt, which forbids output while ~/.zshrc loads) ─────────
if [[ ${PALMFACE_GREETING:-on} != off && -z ${TMUX-} && -z ${PALMFACE_GREETED-} && -t 1 \
  && -z ${__p9k_instant_prompt_active-} ]]; then
  export PALMFACE_GREETED=1
  hello
fi

# ── Idle screensaver at a bare prompt (tmux has its own: see tmux.conf) ─────────────────────
# After 10 minutes without a key in this terminal a toy covers the screen; any key returns. It
# fires once per idle stretch, and never replaces a TMOUT or TRAPALRM you set yourself.
# How: zsh calls TRAPALRM every TMOUT seconds at the prompt; TTYIDLE says how long since your
# last key. (If you remove the trap by hand, also `unset TMOUT`, or zsh logs out when idle.)
if [[ ${PALMFACE_SCREENSAVER:-on} != off && -z ${TMUX-} && -x $_palmface_dir/bin/screensaver.sh ]] \
  && (( ${TMOUT:-0} == 0 && ! $+functions[TRAPALRM] )) \
  && zmodload -F zsh/datetime p:EPOCHSECONDS 2> /dev/null; then
  typeset -gi _palmface_ss_fired=0
  TMOUT=120
  TRAPALRM() {
    if (( TTYIDLE >= 600 && EPOCHSECONDS - TTYIDLE > _palmface_ss_fired )) \
      && [[ -x ~/.config/palmface/bin/screensaver.sh ]]; then
      _palmface_ss_fired=$EPOCHSECONDS
      ~/.config/palmface/bin/screensaver.sh
      zle && zle reset-prompt
    fi
    return 0
  }
fi

# ── Typing feedback: autosuggestions + syntax highlighting (must load last) ─────────────────
# Sourced at top level, not inside a function, so the plugins' own variables stay global.
# Both live in the line editor, so they load only with a terminal on stdin.
typeset -g _palmface_brew=${HOMEBREW_PREFIX:-}
if [[ -z $_palmface_brew ]]; then
  if [[ -d /opt/homebrew ]]; then _palmface_brew=/opt/homebrew; else _palmface_brew=/usr/local; fi
fi
if [[ -o zle && -t 0 && -r $_palmface_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && (( ! $+functions[_zsh_autosuggest_start] )); then
  source "$_palmface_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
fi
if [[ -o zle && -t 0 && -r $_palmface_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && (( ! $+functions[_zsh_highlight] )); then
  source "$_palmface_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_STYLES[command]='fg=4'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=5'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=4'
  ZSH_HIGHLIGHT_STYLES[function]='fg=6'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=1'
  ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=2'
  ZSH_HIGHLIGHT_STYLES[path]='underline'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=3'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=3'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
fi
unset _palmface_brew

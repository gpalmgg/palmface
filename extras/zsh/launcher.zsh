# launcher.zsh: Palmface's project launcher. Sourced from ~/.zshrc by the extras layer.
#
#   palmface-camp                 a menu of the projects in your projects folder; pick one and
#   (camp, when the name is free)  Claude Code starts there
#   camp <query> [claude args]    start straight away in the first project whose name has <query>
#   camp --model opus             any leading claude flags: menu first, then claude with them
#   camp -l | --list              print the projects (name, TAB, folder) and start nothing
#   camp -p | --print <query>     print the matching project's folder and start nothing
#   camp -h | --help
#
# In the menu:
#   N       start in project N, or open/close group N (a folder that holds projects)
#   N.M     start in project M inside group N;  N.0 starts in the group folder itself
#   suffixes, combinable:  w  in a new git worktree (--worktree); a folder without .git
#                             starts without one, and camp says so
#                          r  continue the last conversation there (--continue)
#                          +K also give Claude project K's folder (--add-dir), e.g. 3r+1.2
#   f       search everything with fzf (when installed);  q or Enter  quit
#
# Settings, all optional:
#   PALMFACE_PROJECTS_DIR   the folders to scan, colon-separated (default ~/Projects)
#   ~/.claude/palmface-local/projects.ignore
#                           names to hide, one per line ("name" or "group/name"); the file is yours,
#                           and Palmface never writes it
#   PALMFACE_LAUNCH_CMD     what to start (default claude)
#   PALMFACE_LAUNCHER=off   don't define any of this
#
# Every folder in a projects folder is listed, git or not; hidden ones (.name) are skipped. A plain
# folder (no .git) shows "plain folder" where a git project shows its branch. Only subfolders
# with a .git make a folder a group.
#
# Nothing here writes a file: groups you open stay open until you leave the menu.

[[ ${PALMFACE_LAUNCHER:-on} == off ]] && return 0

_palmface_camp_scan() { # fill the _kcamp_* arrays from the projects folders
  emulate -L zsh
  typeset -ga _kcamp_name _kcamp_path _kcamp_group _kcamp_git _kcamp_cname _kcamp_cpath _kcamp_cpar
  _kcamp_name=() _kcamp_path=() _kcamp_group=() _kcamp_git=() _kcamp_cname=() _kcamp_cpath=() _kcamp_cpar=()
  local -a roots ign kids
  local root d c base i g line
  roots=(${(s.:.)${PALMFACE_PROJECTS_DIR:-$HOME/Projects}})
  if [[ -r $HOME/.claude/palmface-local/projects.ignore ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      line=${${line%%\#*}//[[:space:]]/}
      [[ -n $line ]] && ign+=($line)
    done < $HOME/.claude/palmface-local/projects.ignore
  fi
  for root in $roots; do
    [[ $root == '~'* ]] && root=$HOME${root#\~}
    [[ -d $root ]] || continue
    for d in $root/*(N-/on); do
      base=${d:t}
      (( ${ign[(Ie)$base]} )) && continue
      kids=()
      for c in $d/*(N-/on); do
        [[ -e $c/.git ]] || continue
        (( ${ign[(Ie)$base/${c:t}]} )) && continue
        kids+=($c)
      done
      g=0 # every visible folder stays, git or plain; the glob above never matches a hidden one
      [[ -e $d/.git ]] && g=1
      _kcamp_name+=($base) _kcamp_path+=($d) _kcamp_group+=($(( $#kids > 0 ))) _kcamp_git+=($g)
      i=$#_kcamp_name
      for c in $kids; do
        _kcamp_cname+=(${c:t}) _kcamp_cpath+=($c) _kcamp_cpar+=($i)
      done
    done
  done
}

_palmface_camp_branch() { # folder: the branch (or short commit) from .git/HEAD, without running git
  emulate -L zsh
  local head
  [[ -f $1/.git/HEAD ]] || return 0
  head=$(<$1/.git/HEAD)
  head=${head//[[:cntrl:]]/?} # a repo's own file: no escape sequence reaches your terminal
  if [[ $head == 'ref: refs/heads/'* ]]; then print -r -- ${head#ref: refs/heads/}; else print -r -- ${head[1,7]}; fi
}

_palmface_camp_list() { # name TAB folder, for every entry, in menu order
  emulate -L zsh
  local i j
  for i in {1..$#_kcamp_name}; do
    if (( _kcamp_group[i] )); then
      print -r -- "${_kcamp_name[i]}/	${_kcamp_path[i]}"
      for j in {1..$#_kcamp_cname}; do
        (( _kcamp_cpar[j] == i )) && print -r -- "${_kcamp_name[i]}/${_kcamp_cname[j]}	${_kcamp_cpath[j]}"
      done
    else
      print -r -- "${_kcamp_name[i]}	${_kcamp_path[i]}"
    fi
  done
}

_palmface_camp_find() { # query: the folder of the best match (exact name first, then a substring)
  emulate -L zsh
  local q=${(L)1} name dir hit=""
  while IFS=$'\t' read -r name dir; do
    name=${(L)name%/}
    if [[ $name == "$q" || ${name:t} == "$q" ]]; then print -r -- $dir; return 0; fi
    [[ -z $hit && $name == *"$q"* ]] && hit=$dir
  done < <(_palmface_camp_list)
  [[ -n $hit ]] && { print -r -- $hit; return 0; }
  return 1
}

_palmface_camp_at() { # id (N, N.0 or N.M): that entry's folder
  emulate -L zsh
  local n=${1%%.*} m j k=0
  [[ $1 == *.* ]] && m=${1#*.}
  (( n >= 1 && n <= $#_kcamp_name )) || return 1
  if [[ -z $m || $m == 0 ]]; then print -r -- ${_kcamp_path[n]}; return 0; fi
  for j in {1..$#_kcamp_cname}; do
    (( _kcamp_cpar[j] == n )) || continue
    (( ++k == m )) && { print -r -- ${_kcamp_cpath[j]}; return 0; }
  done
  return 1
}

_palmface_camp_show() { # open group numbers...: draw the menu
  emulate -L zsh
  local -a open=("$@")
  local i j k w=8 b where n
  for i in {1..$#_kcamp_name}; do (( ${#_kcamp_name[i]} + 2 > w )) && w=$(( ${#_kcamp_name[i]} + 2 )); done
  (( w > 32 )) && w=32
  where=${${PALMFACE_PROJECTS_DIR:-$HOME/Projects}//$HOME/\~}
  print -rP -- "%F{6}╭─%f camp · $#_kcamp_name in ${${where//[[:cntrl:]]/?}//\%/%%}"
  for i in {1..$#_kcamp_name}; do
    n=${${_kcamp_name[i]//[[:cntrl:]]/?}//\%/%%} # folder names: control characters shown as ?
    if (( _kcamp_group[i] )); then
      k=0
      for j in {1..$#_kcamp_cname}; do (( _kcamp_cpar[j] == i )) && (( k++ )); done
      if (( ${open[(Ie)$i]} )); then
        print -rP -- "%F{6}│%f %F{3}${(l:3:)i}%f  %F{5}▾%f $n"
        print -rP -- "%F{6}│%f      %F{3}$i.0%f  %F{8}(the folder itself)%f"
        k=0
        for j in {1..$#_kcamp_cname}; do
          (( _kcamp_cpar[j] == i )) || continue
          (( k++ ))
          b=$(_palmface_camp_branch ${_kcamp_cpath[j]})
          print -rP -- "%F{6}│%f      %F{3}$i.$k%f  ${(r:$((w - 2)):)${${_kcamp_cname[j]//[[:cntrl:]]/?}//\%/%%}} %F{8}${b//\%/%%}%f"
        done
      else
        print -rP -- "%F{6}│%f %F{3}${(l:3:)i}%f  %F{5}▸%f ${(r:$((w - 2)):)n} %F{8}($k)%f"
      fi
    elif (( _kcamp_git[i] )); then
      b=$(_palmface_camp_branch ${_kcamp_path[i]})
      print -rP -- "%F{6}│%f %F{3}${(l:3:)i}%f  ${(r:$w:)n} %F{8}${b//\%/%%}%f"
    else
      print -rP -- "%F{6}│%f %F{3}${(l:3:)i}%f  ${(r:$w:)n} %F{8}plain folder%f"
    fi
  done
  print -rP -- "%F{6}╰─%f %F{8}N start · N.M in a group · w worktree · r continue · +K add a folder · f find · q quit%f"
}

_palmface_camp_go() { # folder, claude args...: cd there and start
  emulate -L zsh
  local dir=$1
  shift
  cd -- $dir || return 1
  print -rP -- "%F{8}→ ${${${dir//$HOME/~}//[[:cntrl:]]/?}//\%/%%}%f"
  ${=${PALMFACE_LAUNCH_CMD:-claude}} "$@"
}

palmface-camp() {
  emulate -L zsh
  local -a pass open flags
  local reply id sfx adds add k dir
  case ${1:-} in
    -h | --help)
      print -r -- "usage: camp [query] [claude args...] | camp --list | camp --print <query>"
      print -r -- "Scans ${PALMFACE_PROJECTS_DIR:-~/Projects} for projects. Details: the top of ~/.config/palmface/zsh/launcher.zsh"
      return 0 ;;
  esac
  _palmface_camp_scan
  if (( ! $#_kcamp_name )); then
    print -r -- "camp: no projects in ${PALMFACE_PROJECTS_DIR:-~/Projects}. Set PALMFACE_PROJECTS_DIR to the folder(s) that hold them." >&2
    return 1
  fi
  case ${1:-} in
    -l | --list) # names and folders as text on screen: control characters shown as ?
      local a b
      _palmface_camp_list | while IFS=$'\t' read -r a b; do
        print -r -- "${a//[[:cntrl:]]/?}"$'\t'"${b//[[:cntrl:]]/?}"
      done
      return 0 ;;
    -p | --print)
      [[ -n ${2:-} ]] || { print -r -- "camp: --print needs a query" >&2; return 2; }
      _palmface_camp_find $2 || { print -r -- "camp: nothing matches '$2'" >&2; return 1; }
      return 0 ;;
    -* | '') pass=("$@") ;;
    *)
      dir=$(_palmface_camp_find $1) || { print -r -- "camp: nothing matches '$1'" >&2; return 1; }
      shift
      _palmface_camp_go $dir "$@"
      return ;;
  esac

  while true; do
    _palmface_camp_show $open
    reply=""
    read -r "reply?› " || return 1
    reply=${reply//[[:space:]]/}
    case $reply in
      '' | q | Q) return 0 ;;
      f | F)
        if ! (( $+commands[fzf] )); then print -r -- "camp: fzf isn't installed (brew install fzf)"; continue; fi
        dir=$(_palmface_camp_list | fzf --delimiter=$'\t' --with-nth=1 --height=40% --reverse --prompt='camp › ' | cut -f2)
        [[ -n $dir ]] && { _palmface_camp_go $dir $pass; return; }
        continue ;;
    esac
    if [[ ! $reply =~ '^([0-9]+(\.[0-9]+)?)([wr]*)((\+[0-9]+(\.[0-9]+)?)*)$' ]]; then
      print -r -- "camp: '$reply' isn't a choice (try 3, 2.1, 3r, 2.1w+4 or f)"
      continue
    fi
    id=$match[1] sfx=$match[3] adds=$match[4]
    if [[ $id != *.* ]] && (( id >= 1 && id <= $#_kcamp_name )) && (( _kcamp_group[id] )) && [[ -z $sfx$adds ]]; then
      if (( ${open[(Ie)$id]} )); then open=(${open:#$id}); else open+=($id); fi
      continue
    fi
    if ! dir=$(_palmface_camp_at $id); then print -r -- "camp: there is no $id"; continue; fi
    flags=()
    if [[ $sfx == *w* ]]; then # N.M (M > 0) is always a git project; N and N.0 have _kcamp_git
      if [[ $id == *.* && ${id#*.} != 0 ]] || (( _kcamp_git[${id%%.*}] )); then
        flags+=(--worktree)
      else
        print -r -- "camp: ${_kcamp_name[${id%%.*}]//[[:cntrl:]]/?} is not a git project; starting without a worktree"
      fi
    fi
    [[ $sfx == *r* ]] && flags+=(--continue)
    for k in ${(s:+:)adds}; do
      [[ -n $k ]] || continue
      if ! add=$(_palmface_camp_at $k); then print -r -- "camp: there is no $k to add"; continue 2; fi
      flags+=(--add-dir $add)
    done
    _palmface_camp_go $dir $flags $pass
    return
  done
}

# yours win: not defined when you already have a camp; and a camp program that lands on PATH
# later in ~/.zshrc is run instead, checked at call time. palmface-camp is always available.
(( $+aliases[camp] || $+functions[camp] || $+commands[camp] )) || camp() {
  if (( $+commands[camp] )); then command camp "$@"; return; fi
  palmface-camp "$@"
}

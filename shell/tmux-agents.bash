# tmux-agents.bash: tmux session helpers for bash. Source it from ~/.bashrc:
#
#   . /path/to/tmux-agents.bash
#   tmux_autostart main      # optional: interactive terminals start in tmux
#
#   t [-p] [NAME]      switch to session NAME (inside tmux) or attach to it,
#                      creating it if needed; no NAME: a new session with a
#                      free adjective-noun name (from `tls new-name`); -p: a
#                      new session gets the preset layout (`tls preset`)
#   trm NAME...        kill sessions
#   tmv [OLD] NEW      rename session OLD, or this one, to NEW
#   tt [-v|-h] [-f]    ttop: live list of the sessions and their agents,
#                      vertical or horizontal by the window's shape, or as -v
#                      or -h says; -f: ttop fits its tmux pane to the list
#   tmux-doctor        tmux client and server versions, when tmux misbehaves
#   tmux-cache-clean   drop cached tmux clients that no server needs any more
#
# Session names always match exactly ("=NAME"). On its own, tmux takes `-t foo`
# for a session "foobar" when there's no "foo": `t foo` then opened foobar,
# `trm foo` killed it, and `tmv x foo` said that foo already existed.
#
# t and tmv take only names of ASCII letters, digits, _ and -, with no - first.
# A name with - first reads as an option (an old t made a session "-p" of
# `t -p`), a tmux target reads . and : as separators, and other symbols break
# scripts. trm takes any name, so it can remove a bad one.

alias tt='ttop'

# _tmux_name_ok CMD NAME: true if NAME is a good session name; else CMD says why.
_tmux_name_ok() {
    local LC_ALL=C   # else [A-Za-z] also takes é, in en_US.UTF-8
    [[ $2 =~ ^[A-Za-z0-9_][A-Za-z0-9_-]*$ ]] && return 0
    echo "$1: bad session name '$2': use only letters, digits, _ and -, and do not start with -" >&2
    return 1
}

# t [-p] [NAME]: switch to or attach to session NAME, creating it if needed;
# with -p, a new session gets the preset layout.
t() {
    local preset= name= arg w h
    for arg; do
        case $arg in
            -p|--preset) preset=1 ;;   # alias t='t -p' can add a second one
            -*) echo "t: unknown option '$arg'; usage: t [-p] [NAME]" >&2; return 1 ;;
            *) if [ -n "$name" ]; then echo "t: more than one NAME; usage: t [-p] [NAME]" >&2; return 1; fi
               name=$arg ;;
        esac
    done
    if [ -n "$name" ]; then
        _tmux_name_ok t "$name" || return
    else
        name=$(command -v tls >/dev/null && tls new-name 2>/dev/null)
    fi
    if [ -z "$name" ] || ! tmux has-session -t "=$name" 2>/dev/null; then
        if [ -n "$preset" ]; then  # made at the size it gets here, so that showing it resizes nothing
            if [ -n "$TMUX" ]; then
                read -r w h <<< "$(tmux display -p '#{window_width} #{window_height}')"
            else
                w=$(tput cols 2>/dev/null || echo 80) h=$(tput lines 2>/dev/null || echo 24)
            fi
            name=$(tmux new-session -d -P -F '#{session_name}' ${name:+-s "$name"} -x "$w" -y "$h") || return
            tls preset "=$name:"
        elif [ -n "$TMUX" ]; then
            name=$(tmux new-session -d -P -F '#{session_name}' ${name:+-s "$name"}) || return
        fi
    fi
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "=$name"
    else
        "$(_tmux_client_for_server)" new-session -A ${name:+-s "$name"}
    fi
}

# trm NAME...: kill sessions. Any name, so that it can remove a bad one.
trm() {
    local s rc=0
    for s in "$@"; do
        tmux kill-session -t "=$s" || rc=1
    done
    return $rc
}

# tmv [OLD] NEW: rename session OLD (default: this one) to NEW, unless NEW is taken.
tmv() {
    local old new
    case $# in
        1) old=$(tmux display-message -p '#S' 2>/dev/null) new=$1 ;;
        2) old=$1 new=$2 ;;
        *) echo "Usage: tmv NEW (renames this session) or tmv OLD NEW" >&2; return 1 ;;
    esac
    _tmux_name_ok tmv "$new" || return
    if [ "$old" = "$new" ]; then
        echo "Already named '$new'"
        return 0
    fi
    if tmux has-session -t "=$new" 2>/dev/null; then
        echo "Session '$new' already exists" >&2
        return 1
    fi
    tmux rename-session -t "=$old" "$new"
}

# Tab completion of session names.
_tmux_sessions() {
    local sessions
    sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    COMPREPLY=($(compgen -W "$sessions" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F _tmux_sessions t trm tmv

# --------------------------------------------------------------------------
# Tmux upgrade resilience
#
# An in-place tmux upgrade (dnf/yum/apt, brew) swaps out the tmux binary while
# the running tmux server keeps executing the old, now-deleted binary. A newer
# client cannot finish the attach handshake with an older server, so every new
# attach fails with "open terminal failed: not a terminal" -- and paired with
# `exec` that takes the whole login down.
#
# Fix: cache a copy of the server's own binary keyed by version, and attach with
# a matching client. On Linux that binary stays readable through /proc even
# after the file is deleted; macOS has no /proc, so there the copy works only
# while the old binary is still on disk.
# Heals with no manual step and stops engaging once the versions agree again.
# --------------------------------------------------------------------------
TMUX_CLIENT_CACHE="${TMUX_CLIENT_CACHE:-$HOME/.local/share/tmux-clients}"

_tmux_server_pid() {
    tmux display-message -p '#{pid}' 2>/dev/null
}

# A file that reads as the binary of the server with pid $1: on Linux
# /proc/PID/exe, which still reads after the file is deleted; elsewhere the file
# the server runs from, as lsof names it.
_tmux_server_exe() {
    if [ -r "/proc/$1/exe" ]; then
        printf '/proc/%s/exe' "$1"
    else
        lsof -a -p "$1" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
    fi
}

# Cache the running server's own binary under its version, if not already saved.
_tmux_cache_server_binary() {
    local ver=$1 pid exe tmp
    [ -n "$ver" ] || return 1
    [ -x "$TMUX_CLIENT_CACHE/tmux-$ver" ] && return 0
    pid=$(_tmux_server_pid)
    [ -n "$pid" ] && exe=$(_tmux_server_exe "$pid") && [ -r "$exe" ] || return 1
    mkdir -p "$TMUX_CLIENT_CACHE" 2>/dev/null || return 1
    tmp="$TMUX_CLIENT_CACHE/.tmux-$ver.$$"
    if cp "$exe" "$tmp" 2>/dev/null && chmod +x "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$TMUX_CLIENT_CACHE/tmux-$ver" 2>/dev/null && return 0
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# Print a tmux client binary matching the server we are about to attach to.
_tmux_client_for_server() {
    local srv cli
    srv=$(tmux display-message -p '#{version}' 2>/dev/null)
    cli=$(tmux -V 2>/dev/null | awk '{print $2}')
    # No server running yet, or versions already agree: the normal binary is right.
    if [ -z "$srv" ] || [ "$srv" = "$cli" ]; then
        printf 'tmux'
        return 0
    fi
    _tmux_cache_server_binary "$srv"
    if [ -x "$TMUX_CLIENT_CACHE/tmux-$srv" ]; then
        printf '%s' "$TMUX_CLIENT_CACHE/tmux-$srv"
    else
        # Warn only on a real terminal; stray output here breaks remote bootstraps.
        [ -t 2 ] && printf 'tmux: server %s vs client %s, no matching client recoverable; run `tmux kill-server` once your sessions are saved.\n' "$srv" "$cli" >&2
        printf 'tmux'
    fi
}

# Show tmux client/server state; run this first when tmux starts misbehaving.
tmux-doctor() {
    local srv cli pid exe
    cli=$(tmux -V 2>/dev/null | awk '{print $2}')
    srv=$(tmux display-message -p '#{version}' 2>/dev/null)
    pid=$(_tmux_server_pid)
    printf 'client binary : %s (%s)\n' "${cli:-<none>}" "$(command -v tmux || echo 'not installed')"
    printf 'running server: %s%s\n' "${srv:-<none running>}" "${pid:+ (pid $pid)}"
    [ -n "$pid" ] && exe=$(_tmux_server_exe "$pid") \
        && printf 'server exe    : %s\n' "$(readlink "$exe" 2>/dev/null || printf '%s' "$exe")"
    if [ -n "$srv" ] && [ "$srv" != "$cli" ]; then
        printf 'status        : MISMATCH -> would attach using %s\n' "$(_tmux_client_for_server)"
    else
        printf 'status        : ok\n'
    fi
    printf 'cached clients: %s\n' "$(ls "$TMUX_CLIENT_CACHE" 2>/dev/null | tr '\n' ' ')"
}

# Drop cached clients that no longer correspond to a running server.
tmux-cache-clean() {
    local srv
    srv=$(tmux display-message -p '#{version}' 2>/dev/null)
    [ -d "$TMUX_CLIENT_CACHE" ] || { echo "no cache dir"; return 0; }
    local f
    for f in "$TMUX_CLIENT_CACHE"/tmux-*; do
        [ -e "$f" ] || continue
        if [ -n "$srv" ] && [ "$(basename "$f")" = "tmux-$srv" ]; then
            echo "keep   $f (server running)"
        else
            rm -f "$f" && echo "remove $f"
        fi
    done
}

# tmux_autostart [NAME]: on an interactive terminal outside tmux, attach to
# session NAME (default main), creating it if needed, and exit the shell when
# tmux exits or detaches. Needs a real tty: remote bootstraps (VS Code's runs
# `bash -ilc` on pipes) have no terminal for tmux to open.
tmux_autostart() {
    command -v tmux &>/dev/null && [[ $- == *i* ]] && [ -t 0 ] && [ -t 1 ] \
        && [ "$TERM" != dumb ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] \
        && [ -z "$TMUX" ] || return 0
    # Deliberately not `exec`: if tmux cannot start for any reason, fall through
    # to a plain shell rather than dropping the login. An `exec` here means one
    # broken tmux locks you out of the machine entirely.
    "$(_tmux_client_for_server)" new-session -A -s "${1:-main}" && exit
}

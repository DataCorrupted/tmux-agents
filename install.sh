#!/usr/bin/env bash
# Install tmux-agents into a bin directory:
#   ./install.sh [--bin DIR] [--tmux-conf] [--no-setup]
#   --bin DIR     where to put the files (default: ~/.local/bin)
#   --tmux-conf   also install config/tmux.conf as ~/.tmux.conf (a changed old one is backed up)
#   --no-setup    skip `tls setup` (Claude Code hooks in ~/.claude/settings.json, tmux hooks)
# The files go in as regular files, not symlinks, so dotfile syncers copy them too.
# The settings file goes to ~/.config/tmux-agents/tls.conf, if there is none yet.
set -euo pipefail
src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin=$HOME/.local/bin conf=0 setup=1
while [ $# -gt 0 ]; do
    case $1 in
        --bin) bin=${2:?--bin needs a directory}; shift 2 ;;
        --tmux-conf) conf=1; shift ;;
        --no-setup) setup=0; shift ;;
        -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown option $1 (try --help)" >&2; exit 2 ;;
    esac
done

mkdir -p "$bin"
put() {  # put SRC MODE NAME: copy, then rename into place, so a running hook never sees half a file
    install -m "$2" "$1" "$bin/.$3.tmp" && mv -f "$bin/.$3.tmp" "$bin/$3"
}
for f in tls ttop ttv tls-test; do
    put "$src/bin/$f" 755 "$f"
done
put "$src/shell/tmux-agents.bash" 644 tmux-agents.bash
echo "installed tls, ttop, ttv, tls-test and tmux-agents.bash in $bin"
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/tmux-agents
if [ -e "$cfg/tls.conf" ]; then  # yours: never overwritten
    echo "kept your settings in $cfg/tls.conf (tls config shows them)"
else
    mkdir -p "$cfg" && install -m 644 "$src/config/tls.conf" "$cfg/tls.conf" &&
        echo "installed $cfg/tls.conf: every setting at its default, commented out"
fi

if [ "$conf" = 1 ]; then
    if [ -e ~/.tmux.conf ] && ! cmp -s "$src/config/tmux.conf" ~/.tmux.conf; then
        cp -p ~/.tmux.conf ~/.tmux.conf.bak-"$(date +%Y%m%d-%H%M%S)"
    fi
    install -m 644 "$src/config/tmux.conf" ~/.tmux.conf
    echo "installed ~/.tmux.conf"
fi

case ":$PATH:" in
    *":$bin:"*) ;;
    *) echo "note: $bin isn't on your PATH" ;;
esac
if ! grep -qs 'tmux-agents.bash' ~/.bashrc; then
    cat <<EOF
For t, trm, tmv and tt, add to ~/.bashrc:
    . $bin/tmux-agents.bash
    tmux_autostart main    # optional: interactive terminals start in tmux session "main"
EOF
fi
if [ "$setup" = 1 ]; then
    "$bin/tls" setup
fi

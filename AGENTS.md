# Install tmux-agents on a new machine

This file is for AI agents that install tmux-agents for a user. People can read
[README.md](README.md) instead.

Do the steps in sequence. Each step has a check. If a check fails, stop and tell the user
what you saw.

## Rules

1. **Do not touch the user's tmux server.** If `$TMUX` is set, your shell runs inside the
   user's tmux. Then each plain `tmux` command goes to that live server, with all the
   user's sessions.
   - Never send `kill-server`, `kill-session`, `kill-pane` or `detach-client` to it.
   - For a test, start your own server with `tmux -L <socket name>`, and give the same
     `-L` to each command. A different `TMUX_TMPDIR` does not help, because `$TMUX`
     overrides it.
   - After the test, stop your server with `tmux -L <socket name> kill-server`. Then
     delete its socket file, `/tmp/tmux-$(id -u)/<socket name>`.
2. **Ask before you change a file outside the clone.** Each step names the files that it
   changes. Tell the user the change, and wait for an OK.
3. **Ask before you use `sudo`** or install a package.
4. **Do not install `config/tmux.conf`** unless the user asks for it. It is the tmux config
   of the author, and tls does not need it. It takes the keys Ctrl+W, Ctrl+V, Ctrl+H and
   Ctrl+Q away from all programs: Ctrl+W closes a pane with no question. Its copy keys send
   text to `pbcopy`, a macOS command.
5. **Do not add `tmux_autostart`** unless the user asks for it. With it, each interactive
   terminal opens in tmux, and a detach closes the shell.

## 1. Check the machine

```sh
uname -s                            # must print Linux: tls reads /proc
tmux -V                             # 3.0 or newer
/usr/bin/python3 --version          # 3.7 or newer; tls starts with #!/usr/bin/python3
bash --version | head -n 1          # the shell helpers need bash
git --version
command -v claude; ls -d ~/.claude  # does the user use Claude Code?
echo "TMUX=$TMUX"                   # if set, your shell runs inside the user's tmux (rule 1)
```

- If `uname -s` prints `Darwin` (macOS), stop. tls works only on Linux.
- If a tool is not available or is too old, ask the user. Then install it with the package
  manager, for example `sudo apt-get install tmux python3 git` (Debian, Ubuntu) or
  `sudo dnf install tmux python3 git` (Fedora, RHEL).
- If Python 3 is on the machine, but not at `/usr/bin/python3`, stop and tell the user. tls
  cannot start without it.

## 2. Get the code

Ask the user where to put the clone. The steps below use `~/tmux-agents`.

```sh
git clone <repo URL> ~/tmux-agents
cd ~/tmux-agents
```

If the user gives you a copy, such as a directory or an archive, use that copy. Do all
later steps in the clone.

## 3. Choose the bin directory

The installer copies five files into one directory. The default is `~/.local/bin`. This
directory must be on `PATH`:

```sh
case ":$PATH:" in *":$HOME/.local/bin:"*) echo "on PATH" ;; *) echo "not on PATH" ;; esac
```

If it is not on `PATH`, use a directory that is on `PATH` (`--bin DIR` in step 4). Or ask
the user, and add this line to `~/.bashrc`. Also run the line in your shell, for the checks
below:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Use the installer. Do not make symlinks to the clone instead, because some dotfile syncers
do not copy symlinks.

## 4. Run the installer

At the end, the installer runs `tls setup`. Setup changes these files outside the clone.
Tell the user about them before you start the installer.

| File | Change | Backup |
| --- | --- | --- |
| `~/.claude/settings.json` | Adds the command `<bin>/tls hook` for nine Claude Code hook events. Makes the file if it does not exist. | `~/.claude/settings.json.bak-tls-<time>` |
| `~/.bashrc`, `~/.bash_aliases`, `~/.zshrc` | Comments out a line `alias tls=...`, because the alias hides the `tls` command. | `<file>.bak-tls-<time>` |
| The tmux server, if one runs | Adds seven hooks at index `[42]`, and the window options `@tls-base` and `@tls-size` to each window with splits. tmux forgets them when the server stops. | None |

Then run one of these commands:

```sh
./install.sh                  # into ~/.local/bin, then setup
./install.sh --bin ~/bin      # into a different directory, then setup
./install.sh --no-setup       # no setup: for a user without Claude Code
```

Without setup, tmux gets its hooks when the first agent reports from a tmux pane.

Check the output:

- The first line is `installed tls, ttop, ttv, tls-test and tmux-agents.bash in <dir>`.
- If `~/.bashrc` does not load the helpers yet, the installer prints the lines for step 5.
- Setup prints one line for each change, and then the list of tmux sessions.
- If the output has a `note` line, the bin directory is not on `PATH`, or a different
  `tls` comes first. Go back to step 3.

## 5. Add the shell helpers

The helpers `t`, `trm`, `tmv` and `tt` need bash. For a different shell, skip this step:
`tls`, `ttop` and `ttv` work in all shells.

Ask the user, and then add this line to `~/.bashrc`. Use the directory from step 4:

```sh
. ~/.local/bin/tmux-agents.bash
```

Add `tmux_autostart main` on the next line only if the user asks for it (rule 5).

Check:

```sh
grep -n 'tmux-agents.bash' ~/.bashrc                            # shows the line
bash -c '. ~/.local/bin/tmux-agents.bash && type -t t trm tmv'  # prints "function" 3 times
```

Do not check with `bash -i`. If your shell has a terminal, `bash -i` can run
`tmux_autostart`, which attaches to tmux, and the command does not return.

## 6. Test

Run the installed self-test. It takes about 30 seconds.

```sh
~/.local/bin/tls-test
```

The last line must be `all passed`. The test uses throwaway tmux servers, a temporary state
directory and a fake `$HOME`. It does not touch the user's tmux server, settings or state.

Then run `tls`. It prints the tmux sessions once. With no tmux server, it prints
`no tmux server` and `(no tmux sessions)`. This is correct.

Do not start `ttop` yourself: it needs a terminal and a person at the keyboard.

## 7. Connect the agents

- **Claude Code:** setup added the hooks in step 4. Ask the user to restart the Claude Code
  sessions that already run, so that they load the hooks. New sessions show up in `tls` at
  once.
- **Other agents:** only Claude Code has an adapter. A different agent shows up when its
  hooks, or a wrapper script, run `tls report`. [docs/interface.md](docs/interface.md)
  tells how. If the user asks for an adapter, write it from that file. Give it a `resume`
  command, so that ttop can bring the agent back.

## 8. Tell the user

- the clone and the bin directory,
- each file that changed, and its backup,
- the result of the test,
- what to do now: open a new shell, restart the Claude Code sessions, and run `ttop` (or
  `tt`).

## Update

```sh
git -C ~/tmux-agents pull
~/tmux-agents/install.sh --bin <the same directory>
```

Setup is safe to run again: it adds only what is not there. A `ttop` that runs keeps the old
code, so tell the user to quit it with `q` and start it again.

## Uninstall

1. Delete `tls`, `ttop`, `ttv`, `tls-test` and `tmux-agents.bash` from the bin directory. If the
   user put a `tmux-agent-classify` there, ask before you delete it.
2. In `~/.claude/settings.json`, delete each hook whose command ends in `tls hook`. Do not
   restore the backup instead, because it does not have the later changes.
3. In `~/.bashrc`, delete the `tmux-agents.bash` line and the `tmux_autostart` line. If
   setup commented out an `alias tls=...` line, restore it from the comment.
4. If the user agrees, delete the records in `~/.local/state/agent-tls/` and the copies of
   tmux clients in `~/.local/share/tmux-clients/`.
5. tmux forgets the seven hooks when its server stops. To remove them now, run this loop. It
   goes to the user's live server, but it removes only the hooks of tls:

   ```sh
   for h in client-attached client-session-changed session-window-changed after-select-pane pane-focus-in \
            window-layout-changed window-resized; do
       tmux set-hook -gu "$h[42]"
   done
   ```

## Problems

| Symptom | Cause and fix |
| --- | --- |
| `tls: command not found` | The bin directory is not on `PATH`. See step 3. |
| `tls` prints plain `tmux list-sessions` lines | An old `alias tls=...` is active in this shell. Run `unalias tls`, or open a new shell. |
| `bad interpreter: /usr/bin/python3` | Python 3 is not at `/usr/bin/python3`. See step 1. |
| A Claude Code session does not show up | Restart the session. Make sure that `~/.claude/settings.json` has `tls hook` entries. Read `~/.local/state/agent-tls/errors.log`. tls ignores headless `claude -p` runs. |
| `open terminal failed: not a terminal` after a tmux upgrade | The tmux client and the old server have different versions. Run `tmux-doctor`. |

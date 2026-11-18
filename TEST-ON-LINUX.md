# Check the macOS port on Linux

This file is for an AI agent on a Linux machine. Branch `dev` makes tmux-agents run on macOS
too. All 156 checks of the self-test pass on macOS 27.2 (tmux 3.6a). This file checks that
the branch still works on Linux, and does not change the user's setup. Do the steps in
sequence, then fill in the report at the end, and give it to the user.

Delete this file before `dev` goes into `main`. It is in its own commit, the last one on
`dev`.

## Rules

1. **Do not touch the user's tmux server.** Each tmux command in this file names its own
   socket with `-L`. Do not type a plain `tmux` command.
2. **Do not change the user's clone.** No checkout, stash, reset or pull in it. The steps
   use two worktrees in `/tmp`.
3. **Do not install** before step 7, and in step 7 only when the user says yes.
4. **Do not fix anything.** If a step fails, copy its output into the report, and go on with
   the next step.
5. Your shell does not keep variables from one call to the next. So each block starts with
   the same line, which sets `B` (the test directory), `R` (the user's clone) and `S` (a
   tmux socket name). Run each block whole, in one call. If the clone is not in
   `~/tmux-agents`, change `R` in each block.

## What the branch changes on Linux

- `bin/tls`: `boot_id`, `proc_start` and the new `proc_info` are in a platform section. On
  Linux they read the same `/proc` files as before. `agent_pid`, which walks up the process
  tree from a hook to the agent, now gets each process's parent, name and arguments from
  `proc_info`.
- `shell/tmux-agents.bash`: `_tmux_server_pid` asks the server for `#{pid}`. Before, it took
  the first process named `tmux: server` from `ps`. The new `_tmux_server_exe` names the
  server's binary: `/proc/PID/exe` on Linux (it reads even after an upgrade deletes the
  file), else the file that `lsof` names. `tmux-doctor` and the client cache use it.
- `bin/tls-test`: 2 awk helpers get a value with newlines through `ENVIRON`, not `-v`. The
  check of the walk to the nearest process named claude now has `sh` between the stand-in
  and the hook. 2 new checks, for `tmux-doctor` and the client cache: 156 checks on `dev`,
  154 on `main`.

## 1. The machine

```sh
uname -sr; tmux -V; /usr/bin/python3 --version; bash --version | head -n 1
awk --version 2>/dev/null | head -n 1 || awk -W version 2>&1 | head -n 1
echo "TMUX=${TMUX:-unset}"
```

## 2. Two worktrees: main and dev

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
rm -rf "$B"; git -C "$R" worktree prune; mkdir -p "$B/sock"
git -C "$R" fetch origin main dev &&
  git -C "$R" worktree add --detach "$B/main" origin/main &&
  git -C "$R" worktree add --detach "$B/dev" origin/dev &&
  git -C "$R" rev-parse --short origin/main origin/dev &&
  git -C "$R" log --oneline origin/main..origin/dev
```

The log shows 2 commits: `Run on macOS too: ...` and the commit of this file. If there is no
clone, clone the repository into `$B/src`, and use `R=$B/src` in each block.

## 3. The self-test, on main and on dev

Both runs are outside the user's tmux (`TMUX` unset), with the sockets of their throwaway
servers in `$B/sock`. Together they take 1 to 5 minutes, so give the call a long timeout.

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
for b in main dev; do
  s=$(date +%s)
  ( cd "$B/$b" && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$B/sock" bin/tls-test ) > "$B/test-$b.log" 2>&1
  echo "$b: exit $?, $(grep -c '^PASS' "$B/test-$b.log") PASS, $(grep -c '^FAIL' "$B/test-$b.log") FAIL," \
    "$(( $(date +%s) - s ))s, last line: $(grep -v Terminated "$B/test-$b.log" | tail -n 1)"
done
grep -H '^FAIL' "$B"/test-*.log
```

Expected: `main` 154 PASS, `dev` 156 PASS, 0 FAIL, and the last line `all passed` for both.
Ignore the `Terminated ... sleep 600` lines: they come from the test's cleanup. If a check
fails, run that branch once more (some checks wait for tmux), and report both runs.

## 4. The platform section, from Python

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
cd "$B/dev" && /usr/bin/python3 -IS - "$PWD/bin/tls" <<'EOF'
import os, runpy, subprocess, sys
t = runpy.run_path(sys.argv[1], run_name="tls")   # tls runs main() only as __main__
child = subprocess.Popen(["sleep", "30"])
try:
    stat = open("/proc/%d/stat" % child.pid).read().rsplit(")", 1)[1].split()
    print("boot_id   ", t["boot_id"]() == open("/proc/sys/kernel/random/boot_id").read().strip())
    print("proc_start", t["proc_start"](child.pid) == int(stat[19]))
    print("proc_info ", t["proc_info"](child.pid) == (os.getpid(), "sleep", ["sleep", "30", ""]))
    print("gone      ", t["proc_info"](4206649) == (None, "", [""]) and t["proc_start"](4206649) is None)
finally:
    child.kill()
p = os.getppid()   # the processes above this one, as agent_pid sees them
for _ in range(8):
    if not p or p <= 1:
        break
    ppid, comm, argv = t["proc_info"](p)
    print("  up      ", p, comm, [a[:60] for a in argv[:2]])
    p = ppid
print("agent_pid ", t["agent_pid"]("claude"))
EOF
```

Expected: 4 lines that end in `True`. Then the `up` lines: this shell, and the processes
above it. If you are Claude Code, `agent_pid` is the pid of the first `up` line whose name
is `claude`, or whose first argument is or ends in `/claude`. Otherwise it is `None`.

## 5. The client cache, with a deleted server binary

After an in-place tmux upgrade, the old server runs a binary that is no longer on disk. On
Linux, the helpers copy it through `/proc/PID/exe`, and attach with that copy. This block
makes the same case on two servers of its own: it copies the real tmux binary (also when
`tmux` is a wrapper script), starts a server from the copy, and deletes the copy.

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
cd "$B/dev" || exit 1
tmux -L ${S}_cp -f /dev/null new-session -d "sleep 600"
cp "/proc/$(tmux -L ${S}_cp display -p '#{pid}')/exe" "$B/tmux-old"
tmux -L ${S}_cp kill-server
"$B/tmux-old" -L $S -f /dev/null new-session -d "sleep 600" || echo "tmux-old did not start"
rm "$B/tmux-old"
ls -l "/proc/$(tmux -L $S display -p '#{pid}')/exe"
TMUX_CLIENT_CACHE="$B/clients" bash --norc --noprofile -c \
  "tmux() { command tmux -L $S \"\$@\"; }; . shell/tmux-agents.bash; tmux-doctor; _tmux_cache_server_binary \"\$(tmux display -p '#{version}')\"; echo cache=\$?"
echo "cached copy: $("$B"/clients/tmux-* -V)   system: $(tmux -V)"
tmux -L $S kill-server
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$S" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/${S}_cp"
```

Expected: the `ls -l` line ends in `tmux-old (deleted)`, `tmux-doctor` shows
`server exe    : /tmp/tls-check-.../tmux-old (deleted)`, then `cache=0`, and the cached copy
has the same version as the system tmux. If `tmux-old did not start`, `/tmp` can be
mounted `noexec`: do the block again with the copy in a directory under `$HOME`.

## 6. The real agents, read-only

This step runs the `tls` of `main` and of `dev` against the user's tmux server and agent
records. `tls` can delete old records and saves the window layout in its state directory,
so each run gets its own copy of the records. The first line of the output has the clock,
so the diff starts at line 2.

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
L=${TLS_STATE_DIR:-$HOME/.local/state/agent-tls}
[ -d "$L" ] || { echo "no $L: tmux-agents is not in use here, skip step 6"; exit 0; }
cp -a "$L" "$B/state"
for b in main dev; do
  cp -a "$B/state" "$B/state-$b"
  TLS_STATE_DIR="$B/state-$b" "$B/$b/bin/tls" > "$B/live-$b.txt" 2>&1
done
diff <(tail -n +2 "$B/live-main.txt") <(tail -n +2 "$B/live-dev.txt") && echo SAME
cat "$B/live-dev.txt"
```

Expected: `SAME`, and `dev`'s list shows the live agents in their states (`busy`, `idle`,
`done` and so on), not as dead. If the only difference is an age that went up by one (such
as `4m` and `5m`), run the block again.

## 7. Optional: install dev

Do this step only if steps 3 to 6 passed, and the user says yes. The installer replaces
`tls`, `ttop`, `ttv`, `tls-test` and `tmux-agents.bash` in the bin directory of the current
install. From the next hook on, each Claude Code session runs the new `tls hook`.

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
BIN=$(dirname "$(command -v tls)")
wc -l < "${TLS_STATE_DIR:-$HOME/.local/state/agent-tls}/errors.log" 2>/dev/null
cd "$B/dev" && ./install.sh --bin "$BIN"
```

Then, in a new shell call (your own hooks run between calls), run `tls`, and count the lines
of `errors.log` again. Expected: your own session shows as busy, in the right tmux session,
and `errors.log` has no new lines. To go back, run `./install.sh --bin "$BIN"` in `$B/main`
before step 8.

## 8. Clean up

```sh
B=/tmp/tls-check-$(id -u) R=~/tmux-agents S=tlscheck
tmux -L $S kill-server 2>/dev/null; tmux -L ${S}_cp kill-server 2>/dev/null
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$S" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/${S}_cp"
git -C "$R" worktree remove --force "$B/main"; git -C "$R" worktree remove --force "$B/dev"
rm -rf "$B"; git -C "$R" worktree prune
```

## Report

Give the user this report. Copy outputs as they are; do not shorten error messages.

```text
Linux check of tmux-agents dev
machine:  <uname -sr> | <tmux -V> | <python3 --version> | bash <version> | <awk name and version>
commits:  main <hash>, dev <hash>
step 3:   main <n> PASS <n> FAIL <s>s | dev <n> PASS <n> FAIL <s>s
          FAIL lines: <each one, or none>
step 4:   <the whole output>
step 5:   <the whole output>
step 6:   SAME | <the diff>; dev's list: <the whole list> | skipped: <why>
step 7:   skipped | <tls row of your session; errors.log lines before and after>
other:    <anything else that you saw, or nothing>
```
